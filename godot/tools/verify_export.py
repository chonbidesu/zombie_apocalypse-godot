"""Audit a Godot 4.7 PCK; optionally make a separate instrumented smoke-test copy."""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path


def read_index(pack):
    with pack.open('rb') as stream:
        magic, version, major, minor, patch, flags = struct.unpack('<6I', stream.read(24))
        if magic != 0x43504447 or version not in (3, 4) or flags != 2:
            raise ValueError('Expected an unencrypted, nonsparse Godot v3/v4 PCK')
        base, directory = struct.unpack('<2Q', stream.read(16))
        stream.seek(directory)
        entries = []
        for _ in range(struct.unpack('<I', stream.read(4))[0]):
            length = struct.unpack('<I', stream.read(4))[0]
            name = stream.read(length).rstrip(b'\0').decode('utf-8')
            offset, size = struct.unpack('<2Q', stream.read(16))
            digest = stream.read(16)
            entry_flags = struct.unpack('<I', stream.read(4))[0]
            if entry_flags:
                raise ValueError('Encrypted or delta entry is not supported')
            entries.append(dict(path=name, offset=base + offset, size=size, md5=digest.hex()))
    return entries, (version, major, minor, patch)


def main_scene(settings, scene):
    result = bytearray(settings[:8])
    cursor = 8
    changed = False
    for _ in range(struct.unpack_from('<I', settings, 4)[0]):
        length = struct.unpack_from('<I', settings, cursor)[0]
        key = settings[cursor + 4:cursor + 4 + length]
        result += settings[cursor:cursor + 4 + length]
        cursor += 4 + length
        size = struct.unpack_from('<I', settings, cursor)[0]
        value = settings[cursor + 4:cursor + 4 + size]
        cursor += 4 + size
        if key == b'application/run/main_scene':
            raw = scene.encode()
            value = struct.pack('<2I', 4, len(raw)) + raw
            value += b'\0' * (-len(raw) % 4)
            changed = True
        result += struct.pack('<I', len(value)) + value
    if not changed:
        raise ValueError('Missing main scene setting')
    return bytes(result)


def instrument(source, destination, script):
    if destination.exists():
        raise ValueError('Use a fresh instrumentation directory')
    shutil.copytree(source, destination)
    pack = source / 'MaltonReborn.pck'
    entries, version = read_index(pack)
    harness = script.read_text(encoding='utf-8')
    harness = harness.replace('extends SceneTree', 'extends Node')
    harness = harness.replace('func _initialize()', 'func _ready()')
    harness = harness.replace('root.add_child(', 'get_tree().root.add_child(')
    harness = harness.replace('root.get_node(', 'get_tree().root.get_node(')
    harness = harness.replace('root.get_texture()', 'get_tree().root.get_texture()')
    harness = harness.replace('await process_frame', 'await get_tree().process_frame')
    harness = harness.replace('await create_timer(', 'await get_tree().create_timer(')
    harness = harness.replace(' quit(', ' get_tree().quit(')
    additions = {
        'release_smoke.gd': harness.encode(),
        'release_smoke.tscn': b'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://release_smoke.gd" id="1"]\n[node name="ReleaseSmoke" type="Node"]\nscript = ExtResource("1")\n',
    }
    with pack.open('rb') as original, (destination / pack.name).open('wb') as output:
        output.write(struct.pack('<6I2Q', 0x43504447, *version, 2, 112, 0))
        output.write(b'\0' * (112 - output.tell()))
        directory_entries = []
        for item in entries + [dict(path=name) for name in additions]:
            name = item['path']
            if name in additions:
                data = additions[name]
            else:
                original.seek(item['offset'])
                data = original.read(item['size'])
            if name == 'project.binary':
                data = main_scene(data, 'res://release_smoke.tscn')
            offset = output.tell() - 112
            output.write(data)
            output.write(b'\0' * (-output.tell() % 16))
            raw_name = name.encode()
            raw_name += b'\0' * (-len(raw_name) % 4)
            directory_entries.append(struct.pack('<I', len(raw_name)) + raw_name +
                                     struct.pack('<2Q', offset, len(data)) + hashlib.md5(data).digest() + struct.pack('<I', 0))
        directory = output.tell()
        output.write(struct.pack('<I', len(directory_entries)))
        for item in directory_entries:
            output.write(item)
        output.seek(32)
        output.write(struct.pack('<Q', directory))


def audit(folder):
    pack = folder / 'MaltonReborn.pck'
    entries, version = read_index(pack)
    failures = []
    with pack.open('rb') as stream:
        for entry in entries:
            stream.seek(entry['offset'])
            if hashlib.md5(stream.read(entry['size'])).hexdigest() != entry['md5']:
                failures.append(entry['path'])
    names = [item['path'] for item in entries]
    forbidden = ('tests/', 'tools/', 'docs/', 'reports/', 'assets/blocks/', 'assets/generated/')
    report = dict(engine=list(version[1:]), pck_files=len(entries), hash_failures=failures,
                  development_files=[name for name in names if name.startswith(forbidden) or name.endswith(('.pdb', '.csproj', '.sln', '.translation'))],
                  raw_data=[name for name in names if name.endswith(('.json', '.csv'))],
                  save_migration='scripts/save_data.gdc' in names)
    report['runtime'] = [json.loads(path.read_text()) for path in folder.rglob('*.runtimeconfig.json')]
    report['file_count'] = sum(path.is_file() for path in folder.rglob('*'))
    report['bytes'] = sum(path.stat().st_size for path in folder.rglob('*') if path.is_file())
    print(json.dumps(report, indent=2))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--instrument', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    report = audit(args.folder)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2), encoding='utf-8')
    if args.instrument:
        instrument(args.folder, args.instrument, Path(__file__).with_name('export_smoke.gd'))
    if report['hash_failures'] or report['development_files']:
        raise SystemExit(1)
