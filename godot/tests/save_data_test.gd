extends SceneTree

const Data = preload("res://scripts/save_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func write_file(path: String, text: String) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 file.store_string(text)

func _initialize() -> void:
 call_deferred("run_tests")

func run_tests() -> void:
 var base := ProjectSettings.globalize_path("user://save-migration-test")
 var legacy := base.path_join("legacy")
 var target := base.path_join("target")
 DirAccess.make_dir_recursive_absolute(legacy)
 DirAccess.make_dir_recursive_absolute(target)
 for filename in Data.FILES: write_file(legacy.path_join(filename), "old:" + filename)
 write_file(legacy.path_join("npc-planner-save.json"), "test fixture")
 write_file(target.path_join(Data.FILES[1]), "newer save")
 check(Data.migrate(legacy, target) == OK, "Legacy migration succeeds")
 for filename in Data.FILES:
  check(FileAccess.get_file_as_string(legacy.path_join(filename)) == "old:" + filename, "Original remains: " + filename)
  var expected: String = "newer save" if filename == Data.FILES[1] else "old:" + filename
  check(FileAccess.get_file_as_string(target.path_join(filename)) == expected, "Player file copied without overwriting: " + filename)
 check(not FileAccess.file_exists(target.path_join("npc-planner-save.json")), "Test saves are not migrated")
 DirAccess.remove_absolute(target.path_join(Data.FILES[0]))
 check(Data.migrate(legacy, target) == OK and not FileAccess.file_exists(target.path_join(Data.FILES[0])), "Later launches do not resurrect deleted saves")
 var empty := base.path_join("empty")
 check(Data.migrate(base.path_join("missing"), empty) == OK, "New installation needs no prototype folder")
 var blocked := base.path_join("blocked")
 write_file(blocked, "file instead of directory")
 check(Data.migrate(legacy, blocked) != OK, "Unwritable destination reports failure")
 check(not FileAccess.file_exists(blocked.path_join(Data.MARKER)), "Failed migration does not record completion")
 DirAccess.remove_absolute(blocked)
 check(Data.migrate(legacy, blocked) == OK and FileAccess.get_file_as_string(blocked.path_join("settings.cfg")) == "old:settings.cfg", "Failed migration can be retried after the destination is fixed")
 check(ProjectSettings.get_setting("application/config/use_custom_user_dir") and ProjectSettings.get_setting("application/config/custom_user_dir_name") == "Malton Reborn", "Save directory remains independent of display name")
 for folder in [legacy, target, empty, blocked]:
  for filename in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(filename))
  DirAccess.remove_absolute(folder)
 DirAccess.remove_absolute(base)
 print("SAVE DATA CHECKS: %d FAILURES: %d" % [checks, failures])
 quit(0 if failures == 0 else 1)
