extends Node

const LEGACY_NAME := "Malton • Neighbourhood Prototype"
const FILES := ["prototype-save.json", "prototype-save-slot-2.json", "prototype-save-slot-3.json", "settings.cfg"]
const MARKER := ".prototype-data-migrated"

func _ready() -> void:
 var godot_dir := "Godot" if OS.get_name() in ["Windows", "macOS"] else "godot"
 var legacy := OS.get_data_dir().path_join(godot_dir).path_join("app_userdata").path_join(LEGACY_NAME)
 var error := migrate(legacy, ProjectSettings.globalize_path("user://"))
 if error != OK: push_warning("Could not copy prototype saves/settings: %s. Original files are unchanged." % error_string(error))

# Copy only player data, once, before PlayerSettings loads. Keep existing files
# and legacy originals; a failed copy can be retried on the next launch.
static func migrate(legacy: String, destination: String) -> Error:
 if FileAccess.file_exists(destination): return ERR_ALREADY_EXISTS
 if FileAccess.file_exists(destination.path_join(MARKER)): return OK
 var error := DirAccess.make_dir_recursive_absolute(destination)
 if error != OK: return error
 for filename in FILES:
  var source := legacy.path_join(filename)
  var target := destination.path_join(filename)
  if not FileAccess.file_exists(source) or FileAccess.file_exists(target): continue
  var temporary := target + ".migration-tmp"
  error = DirAccess.copy_absolute(source, temporary)
  if error != OK: return error
  error = DirAccess.rename_absolute(temporary, target)
  if error != OK: return error
 var marker := FileAccess.open(destination.path_join(MARKER), FileAccess.WRITE)
 if marker == null: return FileAccess.get_open_error()
 marker.store_string("Prototype save/settings copy completed.\n")
 marker.flush()
 return marker.get_error()
