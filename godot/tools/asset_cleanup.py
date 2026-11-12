"""Shared project scanning and reversible changes for the asset pipeline."""

import argparse
import base64
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from hashlib import md5
import json
import os
from pathlib import Path
import posixpath
import re
from tempfile import NamedTemporaryFile
from uuid import uuid4


ART_EXTENSIONS = {".png", ".webp", ".svg", ".jpg", ".jpeg"}
RESOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot", ".gdshader", ".gdshaderinc"}
TEXT_EXTENSIONS = RESOURCE_EXTENSIONS | {
    ".cfg", ".csv", ".json", ".md", ".ps1", ".py", ".svg", ".txt",
}
EXCLUDED = {".godot", ".git", "_archive", "archive", "__pycache__"}
RES_PATH = re.compile(
    r"""(?:(?<=")|(?<="\*))res://(?:\\.|[^"\\\r\n])*|(?<=')res://(?:\\.|[^'\\\r\n])*"""
    r"""|res://[^\s"'<>\[\](){},;`]+"""
)
UID = re.compile(r"uid://[a-z0-9]+\b")
UID_FIELD = re.compile(r'\buid\s*=\s*"(uid://[a-z0-9]+)"')
FORMAT_FIELD = re.compile(r"%(?:\d+)?[a-zA-Z]")
CONCATENATION = re.compile(r"""["']\s*\+""")
PATH_JOIN = re.compile(r"""["']\.path_join\s*\(""")
RELATIVE_SUFFIX = re.compile(r"""\+\s*["'](_[\w.-]+)["']""")


def res(path):
    return "res://" + path.as_posix()


def sidecars(path):
    for suffix in (".import", ".uid"):
        yield path.with_name(path.name + suffix)


def snake_case(name):
    name = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    name = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    result = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    if not result:
        raise ValueError(f"Supply an explicit snake_case name for {name!r}")
    return result


def project_relative(value):
    path = Path(value)
    if path.anchor or ".." in path.parts or path == Path(".") or ":" in value:
        raise ValueError(f"Expected a project-relative path, got {value!r}")
    return path


def archive_location(root):
    if (root / "_archive").is_dir():
        return root / "_archive"
    if (root.parent / "archive" / root.name).is_dir():
        return root.parent / "archive" / root.name
    for path in (root / "archive", root.parent / "archive"):
        if path.is_dir():
            return path
    return root / "_archive"


def parser(description):
    result = argparse.ArgumentParser(description=description)
    result.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    result.add_argument("--archive", type=Path, help="Override the archive directory")
    result.add_argument("--apply", action="store_true", help="Write the proposed changes")
    return result


def locations(args):
    root = args.project.resolve()
    archive = (args.archive or archive_location(root)).resolve()
    if not (root / "project.godot").is_file():
        raise ValueError(f"project.godot is missing from {root}")
    if root.is_relative_to(archive) or (archive / "project.godot").exists():
        raise ValueError(f"Archive must be separate from the active project root: {archive}")
    if any(part.casefold() in {".git", ".godot"} for part in archive.parts):
        raise ValueError(f"Archive cannot be placed in a Git or Godot cache directory: {archive}")
    if (archive.is_relative_to(root) and archive.is_dir() and any(archive.iterdir())
            and archive.name.casefold() not in {"archive", "_archive"}
            and not (archive / ".gdignore").is_file()):
        raise ValueError(f"Choose an archive directory outside active project content: {archive}")
    return root, archive


def is_link(path):
    return path.is_symlink() or getattr(path, "is_junction", lambda: False)()


def project_tree(root, archive):
    """Return relative files and directories, excluding ignored subtrees and links."""
    files, folders = [], []

    def fail(error):
        raise error

    for current, directories, names in os.walk(root, onerror=fail):
        parent = Path(current)
        directories[:] = sorted(
            name for name in directories
            if name.casefold() not in EXCLUDED and not name.startswith(".")
            and (parent / name) != archive and not is_link(parent / name)
            and not (parent / name / ".gdignore").is_file()
            and not (parent / name / "project.godot").is_file()
        )
        folders.extend((parent / name).relative_to(root) for name in directories)
        files.extend(
            (parent / name).relative_to(root) for name in sorted(names)
            if not is_link(parent / name)
        )
    return files, folders


def read_text(path):
    # Reading bytes preserves BOMs and CRLF in files we rewrite.
    return path.read_bytes().decode("utf-8")


def resource_key(uri):
    return posixpath.normpath(uri.removeprefix("res://").replace(r'\"', '"').replace(r"\'", "'"))


class References:
    def __init__(self, root, files, assets):
        self.used = set()
        self.relative = set()
        self.dynamic = {}
        asset_paths = {}
        for asset in assets:
            asset_paths.setdefault(asset.as_posix().casefold(), set()).add(asset)
        asset_names = {p.name.casefold() for p in assets}
        asset_uids = {}
        for asset in assets:
            import_path, uid_path = (root / p for p in sidecars(asset))
            if import_path.is_file() and not is_link(import_path):
                match = UID_FIELD.search(read_text(import_path))
                if match:
                    asset_uids.setdefault(match[1], set()).add(asset)
            if uid_path.is_file() and not is_link(uid_path):
                uid = read_text(uid_path).strip()
                asset_uids.setdefault(uid, set()).add(asset)

        basenames = "|".join(re.escape(name) for name in sorted(asset_names, key=lambda n: (-len(n), n)))
        name_pattern = re.compile(rf"(?<![\w.-])(?:{basenames})(?![\w.-])", re.IGNORECASE) if basenames else None
        for path in files:
            if path.suffix.lower() not in TEXT_EXTENSIONS:
                continue
            contents = read_text(root / path)
            for match in RES_PATH.finditer(contents):
                uri = match[0]
                self.used.update(asset_paths.get(resource_key(uri).casefold(), ()))
                if path.suffix.lower() in RESOURCE_EXTENSIONS:
                    if (uri.endswith("/") or FORMAT_FIELD.search(uri)
                            or CONCATENATION.match(contents, match.end())):
                        self.dynamic.setdefault(path, set()).add(uri)
                    elif PATH_JOIN.match(contents, match.end()):
                        self.dynamic.setdefault(path, set()).add(uri + "/")
            for uid in UID.findall(contents):
                self.used.update(asset_uids.get(uid, ()))
            if name_pattern:
                relative_text = RES_PATH.sub("", contents)
                self.relative.update(match[0].casefold() for match in name_pattern.finditer(relative_text))
                for suffix in RELATIVE_SUFFIX.findall(relative_text):
                    self.relative.update(name for name in asset_names if name.endswith(suffix.casefold()))

    def dynamic_readers(self, asset):
        uri = res(asset).casefold()
        for path, patterns in self.dynamic.items():
            for pattern in patterns:
                field = FORMAT_FIELD.search(pattern)
                if field:
                    parts = FORMAT_FIELD.split(pattern.casefold())
                    expression = ".+".join(re.escape(part) for part in parts)
                    if re.fullmatch(expression, uri):
                        yield path
                        break
                elif uri.startswith(pattern.casefold()):
                    yield path
                    break

    def directly_used(self, asset):
        return asset in self.used or asset.name.casefold() in self.relative


def update_paths(contents, files, folders):
    file_lookup = {old.casefold(): new for old, new in files.items()}
    folder_lookup = sorted(folders.items(), key=lambda pair: pair[0].count("/"), reverse=True)

    def replace(match):
        uri = match[0]
        key = resource_key(uri)
        if key.casefold() in file_lookup:
            new = file_lookup[key.casefold()]
            if match.start() > 0 and contents[match.start() - 1] in {'"', "'"}:
                quote = contents[match.start() - 1]
                new = new.replace(quote, "\\" + quote)
            return "res://" + new
        for old, new in folder_lookup:
            if uri == f"res://{old}":
                return f"res://{new}"
            if uri.startswith(f"res://{old}/"):
                return f"res://{new}/" + uri.removeprefix(f"res://{old}/")
        return uri

    return RES_PATH.sub(replace, contents)


def update_import(contents, old, new):
    def cache_base(path):
        digest = md5(res(path).encode("utf-8"), usedforsecurity=False).hexdigest()
        return f"res://.godot/imported/{path.name}-{digest}"

    return contents.replace(cache_base(old), cache_base(new))


@dataclass
class Change:
    path: str
    destination: str | None = None
    before: str | None = None
    after: str | None = None


def move(source, target):
    return Change(str(source), destination=str(target))


def write(path, data):
    def encode(value):
        return base64.b64encode(value).decode("ascii")

    return Change(str(path), before=encode(path.read_bytes()) if path.exists() else None,
                  after=encode(data))


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        temp_path = Path(temporary.name)
        try:
            temporary.write(data)
            temporary.close()
            temp_path.replace(path)
        finally:
            temp_path.unlink(missing_ok=True)


def require_vacant(path):
    if path.parent.exists() and any(p.name.casefold() == path.name.casefold() for p in path.parent.iterdir()):
        raise ValueError(f"Destination already exists: {path}")


def relocate(source, target):
    if source.parent == target.parent and source.name.casefold() == target.name.casefold():
        # Windows can treat both names as the same path during a case-only rename.
        intermediate = source.with_name(".rename_" + uuid4().hex)
        source.rename(intermediate)
        try:
            require_vacant(target)
            intermediate.rename(target)
        except BaseException:
            intermediate.rename(source)
            raise
    else:
        require_vacant(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        source.rename(target)


def execute(change, undo=False):
    path = Path(change.path)
    if change.destination:
        target = Path(change.destination)
        relocate(target, path) if undo else relocate(path, target)
        return
    expected, desired = (change.after, change.before) if undo else (change.before, change.after)
    actual = path.read_bytes() if path.exists() else None
    if actual != (base64.b64decode(expected) if expected is not None else None):
        raise ValueError(f"File changed since the plan was recorded: {path}")
    if desired is None:
        path.unlink()
    else:
        atomic_write(path, base64.b64decode(desired))


def run_changes(changes, undo=False):
    completed = []
    try:
        for change in changes:
            execute(change, undo)
            completed.append(change)
    except BaseException:
        for change in reversed(completed):
            execute(change, not undo)
        raise


def batch_path(archive, label):
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    return archive / f"{label}_{timestamp}_{uuid4().hex[:8]}"


def archive_changes(root, batch, assets):
    changes = []
    for asset in assets:
        for path in (asset, *sidecars(asset)):
            source = root / path
            if is_link(source):
                raise ValueError(f"Linked asset or sidecar requires manual review: {path}")
            if source.is_file():
                changes.append(move(source, batch / path))
    return changes


def commit(root, archive, label, changes, batch=None):
    if not changes:
        return
    batch = batch or batch_path(archive, label)
    log = batch / "rollback.json"
    require_vacant(log)
    for directory in (archive, batch):
        marker = directory / ".gdignore"
        if not marker.exists():
            atomic_write(marker, b"")
    data = {"project": str(root), "archive": str(archive), "status": "planned",
            "changes": [asdict(change) for change in changes]}

    def save():
        atomic_write(log, (json.dumps(data, indent=2) + "\n").encode("utf-8"))

    save()
    try:
        run_changes(changes)
        data["status"] = "applied"
        try:
            save()
        except OSError:
            run_changes(reversed(changes), undo=True)
            raise
    except BaseException:
        print(f"Change failed. Recovery log: {log}", flush=True)
        raise
    print(f"Rollback log: {log}")


def rollback(root, archive, log, apply):
    data = json.loads(read_text(log))
    if data["project"] != str(root) or data["archive"] != str(archive) or data["status"] != "applied":
        raise ValueError("Expected an applied log for this project and archive")
    changes = [Change(**entry) for entry in reversed(data["changes"])]
    for change in changes:
        for entry in filter(None, (change.path, change.destination)):
            path = Path(entry).resolve()
            if not (path.is_relative_to(root) or path.is_relative_to(archive)):
                raise ValueError(f"Rollback path is outside the project and archive: {path}")
            if any(part.casefold() in {".git", ".godot"} for part in path.parts):
                raise ValueError(f"Rollback path is inside a Git or Godot cache directory: {path}")
    print(f"{'Undoing' if apply else 'Would undo'} {len(changes)} operations from {log}")
    if apply:
        run_changes(changes, undo=True)
        data["status"] = "rolled_back"
        try:
            atomic_write(log, (json.dumps(data, indent=2) + "\n").encode("utf-8"))
        except OSError:
            run_changes(reversed(changes))
            raise
