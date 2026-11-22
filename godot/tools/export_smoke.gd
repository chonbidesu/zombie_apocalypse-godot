extends SceneTree
## Run externally against an exported EXE; all res:// loads then come from its PCK.

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 print("EXPORT ENGINE: ", Engine.get_version_info().string)
 print("EXPORT RELEASE: ", not OS.is_debug_build())
 print("EXPORT USER DIRECTORY: ", OS.get_user_data_dir())
 if OS.get_environment("VERIFY_MIGRATION") == "1":
  check(FileAccess.file_exists("user://prototype-save.json") and FileAccess.file_exists("user://.prototype-data-migrated"), "Packaged startup migrates the legacy player save")
  check(root.get_node("PlayerSettings").volume_percent(&"Master") == 37, "Packaged settings load after migration")
 check(not OS.has_feature("editor"), "Checks run in the exported executable")
 check(not OS.is_debug_build(), "The executable uses the release template")
 audit_resources("res://assets/")
 var kernel_script = load("res://scripts/NpcQueryKernel.cs")
 check(kernel_script != null and kernel_script.can_instantiate(), "Packaged C# kernel can instantiate")
 if kernel_script == null or not kernel_script.can_instantiate():
  finish()
  return
 var sim_script = load("res://scripts/simulation.gd")
 var sim = sim_script.new()
 var error: String = sim.start(4815, "Private", {"mode":"malton", "survivors":2000, "zombies":2000})
 check(error.is_empty() and sim.blocks.size() == 10000 and sim.actors.size() == 4001, "Packaged Malton map creates 2,000 humans and 2,000 zombies")
 if not error.is_empty():
  finish()
  return
 var world = load("res://scripts/world_builder.gd")
 var generated = sim_script.new()
 var config: Dictionary = world.defaults(100, 100)
 config.survivors = 20
 config.zombies = 20
 check(generated.start(19, "Doctor", config).is_empty() and generated.blocks.size() == 10000, "Packaged complex plans and tables generate a random city")
 var raw_tables := ["actor_frame_bounds.json", "character_names.json", "descriptions.json", "search_tables.json"]
 for filename in raw_tables:
  check(JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/" + filename)) is Dictionary, "Raw runtime table available: " + filename)
 check(not sim._read_names().is_empty(), "Raw block-name CSV is available")
 # Loading fills the deterministic prose cache for undiscovered locations.
 # Populate it before comparing complete dictionaries, as the source tests do.
 for site in sim.blocks: sim.ensure_descriptions(site)
 check(sim.save_to("user://release-verification.json") == OK, "Packaged game saves")
 var loaded = sim_script.new()
 var load_error: String = loaded.load_from("user://release-verification.json")
 var actors_equal: bool = JSON.stringify(loaded.actors) == JSON.stringify(sim.actors)
 var blocks_equal: bool = JSON.stringify(loaded.blocks) == JSON.stringify(sim.blocks)
 check(load_error.is_empty() and actors_equal and blocks_equal, "Packaged game loads an identical world")
 if not load_error.is_empty() or not actors_equal or not blocks_equal:
  print("LOAD DIAGNOSTIC: ", load_error, " actors=", actors_equal, " blocks=", blocks_equal)
  for pair in [[sim.actors, loaded.actors], [sim.blocks, loaded.blocks]]:
   for id in range(mini(pair[0].size(), pair[1].size())):
    if JSON.stringify(pair[0][id]) == JSON.stringify(pair[1][id]): continue
    for key in pair[0][id]:
     if JSON.stringify(pair[0][id][key]) != JSON.stringify(pair[1][id].get(key)):
      print("LOAD FIELD: ", id, "/", key, " before=", JSON.stringify(pair[0][id][key]), " after=", JSON.stringify(pair[1][id].get(key)))
    break
 sim.player().ap = 49
 sim.begin_sleep()
 sim.managed_queries.planner_mode = 1
 sim.managed_queries.begin(sim)
 check(sim.managed_queries.active and sim.managed_queries.planning_active, "Managed planner and navigation queries activate in the export")
 sim.managed_queries.finish_tick(0)
 sim.stop_rest("Verification setup")
 var game = load("res://main.tscn").instantiate()
 game.sim = sim
 root.add_child(game)
 game.set_process(false)
 await process_frame
 check(game.player_portrait.texture != null and game.local_map != null, "Packaged dashboard and dynamic portraits load")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("user://release-dashboard.png") == OK, "Packaged dashboard renders a screenshot")
 game.begin_sleep()
 game._advance_session(0.016)
 check(game._sleep_sim.is_started() and not game.local_map.is_visible_in_tree(), "Packaged sleep starts the worker and hides perception")
 var deadline := Time.get_ticks_msec() + 60000
 while sim.sleeping and Time.get_ticks_msec() < deadline:
  await create_timer(0.005).timeout
  game._advance_session(0.0)
 check(not sim.sleeping and sim.player().ap == 50 and not game._sleep_sim.is_started() and game.local_map.is_visible_in_tree(), "Natural wake at 50 AP restores the packaged dashboard")
 for wake_input in ["Wake", "Escape"]:
  sim.player().ap = 20
  game.begin_sleep()
  game._advance_session(0.016)
  await create_timer(0.03).timeout
  if wake_input == "Wake": game.rest_button.pressed.emit()
  else:
   var escape := InputEventKey.new()
   escape.keycode = KEY_ESCAPE
   escape.pressed = true
   game._unhandled_key_input(escape)
  check(not sim.sleeping and not game._sleep_sim.is_started() and game.simulation_backlog == 0.0 and game.local_map.is_visible_in_tree(), wake_input + " joins the packaged worker and restores normal play")
 game.queue_free()
 await process_frame
 var title = load("res://start_screen.tscn").instantiate()
 root.add_child(title)
 await process_frame
 check(title.buttons.size() > 0 and title.music.stream != null, "Packaged title and music load")
 if OS.get_environment("VERIFY_TITLE_EXIT") == "1":
  print("EXPORT SMOKE CHECKS: %d FAILURES: %d" % [checks, failures])
  if failures > 0:
   quit(1)
   return
  title.buttons.filter(func(button): return button.text == "QUIT")[0].pressed.emit()
  return
 title.queue_free()
 await process_frame
 finish()

func finish() -> void:
 print("EXPORT SMOKE CHECKS: %d FAILURES: %d" % [checks, failures])
 quit(0 if failures == 0 else 1)

func audit_resources(directory: String) -> void:
 for name in ResourceLoader.list_directory(directory):
  var path := directory.path_join(name)
  if name.ends_with("/"): audit_resources(path)
  elif name.get_extension() in ["png", "svg", "webp", "ttf", "mp3", "ogg", "wav", "tscn", "tres"]:
   check(load(path) != null, "Packaged resource loads: " + path)
