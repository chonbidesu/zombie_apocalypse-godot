# Godot asset cleanup

Run these commands from the repository root with Python 3.11 or newer. Install Pillow for the atlas builder with `python -m pip install Pillow`. Close the Godot editor before applying or rolling back a batch, then run an editor import before testing the project.

## Audit and archive unused art

```powershell
python -B godot/tools/archive_unused_art.py
python -B godot/tools/archive_unused_art.py --apply
```

The audit checks literal `res://` and `uid://` references. It reads UIDs from art sidecars and checks common relative references in scripts, manifests, and docs. It keeps candidates that match a detected runtime path pattern. Pass `--reviewed assets/path/to/sprite.png` for each such sprite after verifying its consumers. The audit is a text scan. Binary resources and arbitrary path construction require manual review.

This project's batches go into `archive/godot`. The script keeps the original relative paths and moves the artwork and sidecars together. Both the archive and its batches have a `.gdignore`. Use `--archive PATH` for a different archive.

## Standardize names and references

```powershell
python -B godot/tools/standardize_assets.py
python -B godot/tools/standardize_assets.py --rules path/to/rules.json --apply --reviewed-dynamic
```

The renamer defaults to `DRY_RUN = True`. It normalizes filenames and folders, removes trailing `revised` and version suffixes, and reports collisions before writing. Scripts with a PascalCase `class_name` use the snake_case form of that name. Update any nonconforming class declaration and its symbol references together.

Full resource paths and import paths are rewritten automatically. UID values and import settings are preserved. For relative or computed paths, use a rules file with destination basenames and scoped literal replacements. Every listed replacement must match its source file. Review the proposed changes and any dynamic readers before applying.

```json
{
  "names": {
    "assets/example/runner-revised.png": "runner_idle.png"
  },
  "replacements": {
    "scripts/example.gd": {
      "\"runner-revised\"": "\"runner_idle\""
    }
  }
}
```

To undo an applied batch, pass its `rollback.json` to `--rollback` and add `--apply`. The archive tool can also undo an atlas originals batch. Undo renames in reverse order. Rollback verifies the edited text against the applied log before restoring it.

## Build a texture atlas

```powershell
python -B godot/tools/build_texture_atlas.py assets/path/to/sprites --output assets/atlases/example --apply
```

Pass one or more source folders per atlas. The builder reads PNG, WebP and JPEG sprites recursively and writes a power-of-two PNG and an editor-ready `AtlasTexture` resource for each sprite. Use `--format json` for a coordinate map with `[x, y, width, height]` regions. `--padding` controls edge extrusion and `--max-size` sets the dimension limit.

After migrating existing texture consumers to the generated atlas, repeat the command with `--archive-originals` to move the source sprites and their sidecars. Use `--reviewed-dynamic` after checking any listed computed paths. Check consumers that require standalone textures, such as tiled `Sprite2D` or `TextureRect` nodes, before replacing their textures.
