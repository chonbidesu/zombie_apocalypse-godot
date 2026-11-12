"""Rename Godot files and directories and rewrite their resource paths."""

import json
import os.path
from pathlib import Path
import re

from asset_cleanup import (
    ART_EXTENSIONS, References, TEXT_EXTENSIONS, commit, is_link, locations, move,
    parser, project_relative, project_tree, read_text, require_vacant, rollback,
    sidecars, snake_case, update_import, update_paths, write,
)


DRY_RUN = True
EXTENSIONS = ART_EXTENSIONS | {".gd", ".tscn", ".tres"}
CLASS_NAME = re.compile(r"^\ufeff?[ \t]*class_name[ \t]+(\w+)", re.MULTILINE)
PASCAL_CASE = re.compile(r"[A-Z][A-Za-z0-9]*")
REVISION = re.compile(r"_(?:revised|v[0-9]+)$")
SNAKE_CASE = re.compile(r"[a-z0-9]+(?:_[a-z0-9]+)*")


def preferred_name(path, folder, contents):
    if folder:
        return snake_case(path.name)
    declaration = CLASS_NAME.search(contents) if path.suffix.lower() == ".gd" else None
    if declaration:
        if not PASCAL_CASE.fullmatch(declaration[1]):
            raise ValueError(f"{path.as_posix()} declares {declaration[1]}. Update the class and its callers to PascalCase.")
        stem = snake_case(declaration[1])
    else:
        stem = snake_case(path.stem)
        while match := REVISION.search(stem):
            stem = stem[:match.start()]
    return stem + path.suffix.lower()


def validate_name(path, name, folder):
    stem, suffix = (name, "") if folder else (Path(name).stem, Path(name).suffix)
    if not SNAKE_CASE.fullmatch(stem) or suffix != ("" if folder else path.suffix.lower()):
        raise ValueError(f"Expected a snake_case name with the original extension for {path}: {name}")
    reserved = getattr(os.path, "isreserved", lambda value: Path(value).is_reserved())
    if Path(name).name != name or reserved(name):
        raise ValueError(f"Invalid destination name for {path}: {name}")


def prepare(root, archive, rules):
    files, folders = project_tree(root, archive)
    text = {p: read_text(root / p) for p in files if p.suffix.lower() in TEXT_EXTENSIONS}
    names = {project_relative(p): n for p, n in rules.get("names", {}).items()}
    edits = {project_relative(p): pairs for p, pairs in rules.get("replacements", {}).items()}
    targets = [p for p in files if p.suffix.lower() in EXTENSIONS]
    if names.keys() - set(targets + folders) or edits.keys() - text.keys():
        raise ValueError("A rules entry points to an excluded, missing or unsupported path")

    edited = text.copy()
    for path, pairs in edits.items():
        if not pairs or any(not old or old not in text[path] for old in pairs):
            raise ValueError(f"Replacement rule does not match {path.as_posix()}")
        # One pass prevents a replacement from triggering a second rule.
        pattern = re.compile("|".join(re.escape(key) for key in sorted(pairs, key=len, reverse=True)))
        edited[path] = pattern.sub(lambda match: pairs[match[0]], text[path])

    folder_names = {}
    for path in folders:
        name = names.get(path, preferred_name(path, True, ""))
        validate_name(path, name, True)
        folder_names[path] = name
    file_names = {}
    for path in targets:
        preferred = preferred_name(path, False, edited.get(path, ""))
        name = names.get(path, preferred)
        validate_name(path, name, False)
        if path.suffix.lower() == ".gd" and CLASS_NAME.search(edited[path]) and name != preferred:
            raise ValueError(f"{path.as_posix()} must match its class name: {preferred}")
        if name != path.name:
            file_names[path] = name
            for sidecar in sidecars(path):
                if (root / sidecar).is_file():
                    file_names[sidecar] = name + sidecar.suffix
                if is_link(root / sidecar):
                    raise ValueError(f"Linked sidecar requires manual review: {sidecar}")

    def final_path(path):
        parents = [folder_names.get(p, p.name) for p in reversed(path.parents) if p != Path(".")]
        return Path(*parents, file_names.get(path, folder_names.get(path, path.name)))

    folder_map = {p.as_posix(): final_path(p).as_posix() for p in folders
                  if final_path(p).as_posix() != p.as_posix()}
    file_map = {p.as_posix(): final_path(p).as_posix() for p in files
                if final_path(p).as_posix() != p.as_posix()}
    direct_moves = {p: p.with_name(name) for p, name in file_names.items()}
    direct_moves.update({p: p.with_name(n) for p, n in reversed(list(folder_names.items())) if p.name != n})
    moving_folders = {p for p in folder_names if p in direct_moves}
    if moving_folders:
        for folder in folders:
            if any(folder.is_relative_to(parent) for parent in moving_folders):
                for child in (root / folder).iterdir():
                    if child.is_dir() and child.relative_to(root) not in folder_names and child.name != "__pycache__":
                        raise ValueError(f"Renaming {folder} would also move an excluded directory: {child.name}")
    destinations = set()
    for old, new in direct_moves.items():
        key = new.as_posix().casefold()
        if key in destinations:
            raise ValueError(f"Rename collision at {new.as_posix()}. Supply distinct names in --rules.")
        destinations.add(key)
        if old.as_posix().casefold() != key:
            require_vacant(root / new)

    changes = []
    for path in files:
        contents = edited.get(path)
        original = text.get(path)
        if path.suffix == ".import":
            original = contents = read_text(root / path)
            source = path.with_suffix("")
            new_source = file_map.get(source.as_posix())
            if new_source:
                contents = update_import(contents, source, Path(new_source))
        if contents is not None:
            updated = update_paths(contents, file_map, folder_map)
            if updated != original:
                changes.append(write(root / path, updated.encode("utf-8")))
    for old, new in direct_moves.items():
        changes.append(move(root / old, root / new))

    references = References(root, files, [])
    dynamic = {reader for path in file_map for reader in references.dynamic_readers(Path(path))}
    return changes, file_map, folder_map, dynamic


def main():
    cli = parser(__doc__)
    cli.add_argument("--rules", type=Path, help="JSON with optional names and scoped literal replacements")
    cli.add_argument("--reviewed-dynamic", action="store_true",
                     help="Apply after verifying or updating the listed dynamic readers")
    cli.add_argument("--rollback", type=Path, metavar="LOG")
    args = cli.parse_args()
    apply = args.apply or not DRY_RUN
    try:
        root, archive = locations(args)
        if args.rollback:
            rollback(root, archive, args.rollback, apply)
            return
        rules = json.loads(read_text(args.rules)) if args.rules else {}
        changes, files, folders, dynamic = prepare(root, archive, rules)
        for old, new in sorted((files | folders).items()):
            print(f"{old} -> {new}")
        for path in sorted(dynamic):
            print(f"Review runtime path construction in {path.as_posix()}")
        edits = sum(change.destination is None for change in changes)
        print(f"{len(files)} file paths, {len(folders)} directory paths and {edits} text edits.")
        if apply:
            if dynamic and not args.reviewed_dynamic:
                raise ValueError("Review the dynamic readers before applying with --reviewed-dynamic")
            commit(root, archive, "standardize_assets", changes)
        elif changes:
            print("Dry run. Pass --apply to write this plan.")
    except (OSError, ValueError) as error:
        cli.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
