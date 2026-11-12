"""Pack sprite folders into a power-of-two PNG and Godot textures or a JSON map."""

from dataclasses import dataclass
from io import BytesIO
import json
from tempfile import TemporaryDirectory
from pathlib import Path

from PIL import Image

from asset_cleanup import (
    References, archive_changes, batch_path, commit, locations, parser,
    project_relative, project_tree, require_vacant, res, snake_case,
)


RASTER_EXTENSIONS = {".png", ".webp", ".jpg", ".jpeg"}


@dataclass
class Sprite:
    name: str
    image: Image.Image


def load_sprites(root, sources):
    sprites = []
    names = set()
    for path in sources:
        name = snake_case(path.stem)
        if name in names:
            raise ValueError(f"Duplicate sprite name after normalization: {name} ({path})")
        names.add(name)
        with Image.open(root / path) as image:
            if getattr(image, "is_animated", False):
                raise ValueError(f"Select single-frame images: {path}")
            sprites.append(Sprite(name, image.convert("RGBA")))
    return sorted(sprites, key=lambda sprite: (-sprite.image.height, -sprite.image.width, sprite.name))


def power_of_two(size):
    return 1 << (size - 1).bit_length()


def shelves(sprites, width, padding):
    x, y, row_height = 0, 0, 0
    regions = {}
    for sprite in sprites:
        w, h = sprite.image.size
        if x + w + 2 * padding > width:
            x, y, row_height = 0, y + row_height, 0
        regions[sprite.name] = (x + padding, y + padding, w, h)
        x += w + 2 * padding
        row_height = max(row_height, h + 2 * padding)
    return power_of_two(y + row_height), regions


def pack(sprites, padding, limit):
    width = power_of_two(max(sprite.image.width for sprite in sprites) + 2 * padding)
    candidates = []
    while width <= limit:
        height, regions = shelves(sprites, width, padding)
        if height <= limit:
            candidates.append((width * height, abs(width - height), width, height, regions))
        width *= 2
    if not candidates:
        raise ValueError(f"Sprites exceed a {limit} x {limit} atlas. Split the group or raise --max-size.")
    _, _, width, height, regions = min(candidates)
    return (width, height), regions


def paste_sprite(sheet, image, region, padding):
    x, y, w, h = region
    sheet.paste(image, (x, y))
    if not padding:
        return
    # Copy edge and corner pixels into the gutter to limit filtering bleed.
    horizontal = [(0, x - padding), (w - 1, x + w)]
    vertical = [(0, y - padding), (h - 1, y + h)]
    for edge, position in horizontal:
        sheet.paste(image.crop((edge, 0, edge + 1, h)).resize((padding, h)), (position, y))
    for edge, position in vertical:
        sheet.paste(image.crop((0, edge, w, edge + 1)).resize((w, padding)), (x, position))
    for column, left in horizontal:
        for row, top in vertical:
            sheet.paste(image.getpixel((column, row)), (left, top, left + padding, top + padding))


def render(sprites, size, regions, padding, output, format_name):
    with Image.new("RGBA", size) as sheet, BytesIO() as buffer:
        for sprite in sprites:
            paste_sprite(sheet, sprite.image, regions[sprite.name], padding)
        sheet.save(buffer, format="PNG")
        files = {"sheet.png": buffer.getvalue()}
    if format_name == "json":
        manifest = {"texture": "sheet.png", "size": size, "regions": regions}
        files["regions.json"] = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    else:
        for name, region in regions.items():
            rect = ", ".join(map(str, region))
            files[f"{name}.tres"] = (
                '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                f'[ext_resource type="Texture2D" path="{res(output / "sheet.png")}" id="1"]\n\n'
                '[resource]\natlas = ExtResource("1")\n'
                f'region = Rect2({rect})\nfilter_clip = true\n'
            ).encode("utf-8")
    return files


def save_output(destination, files, apply):
    if destination.is_dir():
        for name, data in files.items():
            path = destination / name
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError(f"Existing output differs from the proposed atlas: {path}")
        return
    require_vacant(destination)
    if apply:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(dir=destination.parent, prefix=".atlas_") as stage:
            staged = Path(stage) / destination.name
            staged.mkdir()
            for name, data in files.items():
                (staged / name).write_bytes(data)
            require_vacant(destination)
            staged.rename(destination)


def main():
    cli = parser(__doc__)
    cli.add_argument("sources", nargs="+", help="Project-relative sprite folders, searched recursively")
    cli.add_argument("--output", required=True, help="New project-relative output folder for this group")
    cli.add_argument("--format", choices=("godot", "json"), default="godot")
    cli.add_argument("--padding", type=int, default=2)
    cli.add_argument("--max-size", type=int, default=4096)
    cli.add_argument("--archive-originals", action="store_true",
                     help="Archive originals after the atlas is written and references have been migrated")
    cli.add_argument("--reviewed-dynamic", action="store_true",
                     help="Confirm that the listed dynamic readers no longer load the originals")
    args = cli.parse_args()
    try:
        root, archive = locations(args)
        files, folders = project_tree(root, archive)
        sources = {project_relative(path) for path in args.sources}
        output = project_relative(args.output)
        if sources - set(folders):
            raise ValueError("Each source must be an active project subfolder")
        if any(output.is_relative_to(source) or source.is_relative_to(output) for source in sources):
            raise ValueError("Use an output folder outside the source folders")
        if (root / output).resolve() != root / output:
            raise ValueError("The atlas output cannot go through a linked directory")
        for parent in (*output.parents, output):
            if parent != Path(".") and (parent.name != snake_case(parent.name)
                                       or ((root / parent).exists() and parent not in folders)):
                raise ValueError(f"Use an active snake_case output folder: {output}")
        if args.padding < 0 or args.max_size <= 0 or args.max_size & (args.max_size - 1):
            raise ValueError("Padding must be nonnegative and --max-size must be a positive power of two")
        originals = [path for path in files if path.suffix.lower() in RASTER_EXTENSIONS
                     and any(path.is_relative_to(source) for source in sources)]
        if not originals:
            raise ValueError("No raster sprites found in the selected folders")
        sprites = load_sprites(root, originals)
        size, regions = pack(sprites, args.padding, args.max_size)
        print(f"{len(sprites)} sprites -> {res(output / 'sheet.png')} ({size[0]} x {size[1]})")
        if args.archive_originals:
            references = References(root, files, originals)
            used = [path for path in originals if references.directly_used(path)]
            if used:
                raise ValueError("Migrate references before archiving: " + ", ".join(path.as_posix() for path in used))
            dynamic = {reader for path in originals for reader in references.dynamic_readers(path)}
            for path in sorted(dynamic):
                print(f"Review runtime path construction in {path.as_posix()}")
            if dynamic and not args.reviewed_dynamic:
                raise ValueError("Verify the dynamic readers before archiving with --reviewed-dynamic")
        outputs = render(sprites, size, regions, args.padding, output, args.format)
        save_output(root / output, outputs, args.apply)
        if args.apply and args.archive_originals:
            batch = batch_path(archive, "atlas_originals")
            commit(root, archive, "atlas_originals", archive_changes(root, batch, originals), batch)
        if not args.apply:
            print("Dry run. Pass --apply to write the atlas.")
    except (OSError, ValueError) as error:
        cli.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
