"""Audit unreferenced Godot artwork and archive it with its sidecars."""

from pathlib import Path

from asset_cleanup import (
    ART_EXTENSIONS, References, archive_changes, batch_path, commit, locations,
    parser, project_relative, project_tree, rollback,
)


def main():
    cli = parser(__doc__)
    cli.add_argument("--reviewed", action="append", default=[], metavar="PATH",
                     help="Allow a specific path after checking its dynamic loaders")
    cli.add_argument("--rollback", type=Path, metavar="LOG")
    args = cli.parse_args()
    try:
        root, archive = locations(args)
        if args.rollback:
            rollback(root, archive, args.rollback, args.apply)
            return
        files, _ = project_tree(root, archive)
        art = [path for path in files if path.suffix.lower() in ART_EXTENSIONS]
        reviewed = {project_relative(path) for path in args.reviewed}
        if reviewed - set(art):
            raise ValueError(f"Reviewed paths must be active art: {sorted(reviewed - set(art))}")
        references = References(root, files, art)
        unused, retained, protected = [], 0, 0
        for asset in art:
            if references.directly_used(asset):
                retained += 1
                continue
            readers = sorted(references.dynamic_readers(asset))
            if readers and asset not in reviewed:
                protected += 1
                print(f"Review {asset.as_posix()} ({', '.join(p.as_posix() for p in readers)})")
                continue
            unused.append(asset)
            print(f"{'Archive' if args.apply else 'Would archive'} {asset.as_posix()}")
        print(f"{len(art)} art files: {retained} referenced, {protected} held for dynamic-path review, "
              f"{len(unused)} archive candidates.")
        if args.apply and unused:
            batch = batch_path(archive, "unused_art")
            commit(root, archive, "unused_art", archive_changes(root, batch, unused), batch)
    except (OSError, ValueError) as error:
        cli.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
