extends SceneTree

const TEST_SAVE = "user://start-screen-test.json"
const Menu = preload("res://scripts/start_screen.gd")
const Game = preload("res://scripts/interface.gd")
const GameMusic = preload("res://scripts/game_music.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func open_title() -> Menu:
 change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
 await scene_changed
 return current_scene as Menu

func capture(path: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)

func run() -> void:
 root.size = Vector2i(1536,864)
 var menu := await open_title()
 await process_frame
 var corpse_intro = (load("res://intro.tscn") as PackedScene).instantiate()
 corpse_intro.occupation = "Corpse"
 menu.add_child(corpse_intro)
 corpse_intro.set_process(false)
 corpse_intro._show_page(1)
 await process_frame
 check(is_equal_approx(corpse_intro.line_times[1] - corpse_intro.line_times[0] - corpse_intro.line_streams[0].get_length(), 1.0), "Narration recordings have a one-second pause")
 check(corpse_intro.line_labels[0].size.x >= 1400.0 and corpse_intro.line_labels[1].position.y > corpse_intro.line_labels[0].position.y, "Narration lines have full-width horizontal layouts")
 corpse_intro.elapsed = corpse_intro.line_times[0]
 corpse_intro._process(0.7)
 check(corpse_intro.line_labels[0].modulate.a > 0.0 and corpse_intro.line_labels[0].modulate.a < 1.0 and corpse_intro.line_labels[1].modulate.a == 0.0, "Black-screen narration fades in one line at a time")
 corpse_intro._advance()
 check(corpse_intro.narration_index == 1 and is_equal_approx(corpse_intro.line_times[1], corpse_intro.elapsed), "Advancing skips directly to the next line")
 corpse_intro._advance()
 check(corpse_intro.page == 2, "Advancing the last line opens the next screen")
 corpse_intro._show_page(3)
 check(corpse_intro.specimen.visible and corpse_intro.layers.size() == 1 and (corpse_intro.specimen.get_node("Contents") as AnimatedSprite2D).is_playing(), "NecroTech uses the animated single specimen")
 var contents := corpse_intro.specimen.get_node("Contents") as AnimatedSprite2D
 check(contents.material == null and contents.sprite_frames.resource_path.ends_with("specimen_body_frames-transparent-v3.tres"), "Specimen uses the transparent frames without a masking shader")
 corpse_intro._show_page(0)
 corpse_intro.elapsed = 0.0
 var roof: Rect2 = corpse_intro._opening_facade_rect()
 check(roof.position.y > 1080.0 and is_equal_approx(roof.size.y / roof.size.x, 1862.0 / 845.0), "Opening starts above the tall facade without stretching it")
 corpse_intro.elapsed = 9.3
 var window: Rect2 = corpse_intro._opening_facade_rect()
 check(is_equal_approx(window.position.y, -1983.0) and corpse_intro._opening_light() == 0.0, "The camera settles at a dark lab window")
 corpse_intro.elapsed = 10.5
 check(corpse_intro._opening_light() == 0.0, "Lab lights flicker off after their first flash")
 corpse_intro.elapsed = 18.3
 var final_frame: Rect2 = corpse_intro._opening_facade_rect()
 check(corpse_intro._opening_light() == 1.0 and final_frame.size.x > window.size.x, "The lab lights stay on and the camera finishes its zoom")
 corpse_intro.elapsed = 20.0
 check(corpse_intro._opening_facade_rect() == final_frame, "Opening camera holds its final position")
 corpse_intro.elapsed = 0.0
 var distant_line: Rect2 = corpse_intro._quarantine_rect(1)
 var distant_people: Rect2 = corpse_intro._quarantine_rect(2)
 corpse_intro.elapsed = 8.0
 var close_line: Rect2 = corpse_intro._quarantine_rect(1)
 check(close_line.size.x > distant_line.size.x and is_equal_approx(close_line.end.y, distant_line.end.y) and is_equal_approx(close_line.size.x / close_line.size.y, distant_line.size.x / distant_line.size.y) and corpse_intro._quarantine_rect(2).size.x > distant_people.size.x * 3.0, "Checkpoint advances with the security line planted and undistorted")
 corpse_intro._skip_intro()
 check(corpse_intro.page == 4 and not corpse_intro.eyes.visible, "Skipping a corpse intro still presents the closed-eyed origin")
 check(corpse_intro.line_labels[1].text.ends_with("It's time to claim Malton.") and corpse_intro.title.text.is_empty(), "Corpse text uses the revised line without a heading")
 check(corpse_intro.line_streams.size() == 3 and corpse_intro.narration_end > 1.0, "Corpse origin queues its narrated passages and Rise")
 var feet: Rect2 = corpse_intro._corpse_rect()
 corpse_intro.elapsed = 14.0
 var head: Rect2 = corpse_intro._corpse_rect()
 check(head.position.x < feet.position.x, "Corpse camera pans from the feet towards the head")
 corpse_intro._advance()
 corpse_intro._advance()
 corpse_intro._advance()
 var rise := InputEventKey.new()
 rise.keycode = KEY_A
 rise.pressed = true
 corpse_intro._input(rise)
 check(corpse_intro.ending and corpse_intro.eyes.visible, "A key opens the corpse's eyes")
 check(corpse_intro.narration.stream.resource_path.ends_with("Malton RISE.mp3") and corpse_intro.narration.playing, "Eye opening plays the Rise sound")
 corpse_intro._process(1.9)
 check(corpse_intro.curtain.color.a == 0.0, "Corpse awakening holds before fading")
 corpse_intro._process(0.7)
 check(corpse_intro.curtain.color.a > 0.0 and corpse_intro.curtain.color.a < 1.0, "Corpse scene fades after the hold")
 corpse_intro.queue_free()
 check(menu.title_page.visible and menu.creation == null,"Launch opens the title without generating a world")
 check(menu.buttons[0].has_focus(),"New Game has keyboard focus")
 check(menu.parallax.LAYERS.size() == 5 and menu.music.playing,"Original five layers and music are active")
 menu.parallax.set_process(false)
 menu.parallax.offsets.fill(0.0)
 menu.parallax._process(1.0)
 check(menu.parallax.offsets == [6.0,15.0,30.0,60.0,90.0],"Parallax preserves the original relative speeds")
 menu.parallax._process(10000.0)
 for i in range(5):
  var layer: Texture2D = menu.parallax.LAYERS[i]
  check(menu.parallax.offsets[i] >= 0 and menu.parallax.offsets[i] < layer.get_width()*800.0/layer.get_height(),"Parallax wraps after long frames")
 menu.parallax.offsets.fill(0.0)
 await capture("user://start-screen.png")
 menu.save_path = "user://start-screen-intentionally-missing.json"
 menu.buttons[1].pressed.emit()
 check(menu.title_page.visible and current_scene == menu and menu.status.text.contains("No saved game"),"Missing save stays on title with useful feedback")
 menu.save_path = TEST_SAVE
 var file := FileAccess.open(TEST_SAVE,FileAccess.WRITE)
 file.store_string("{}")
 file.close()
 menu.buttons[1].pressed.emit()
 check(menu.title_page.visible and current_scene == menu and menu.status.text.contains("Could not load"),"Incompatible save does not start a new game")
 var original_mode := root.mode
 menu.buttons[0].pressed.emit()
 await process_frame
 check(menu.creation.visible and menu.creation.back.visible and not menu.creation.confirm.visible,"New Game enters character creation directly")
 check(not menu.title_page.visible and root.mode == original_mode,"Creation respects the existing window mode")
 menu.creation.back.pressed.emit()
 await process_frame
 check(menu.creation == null and menu.title_page.visible,"Back returns to the parallax title")
 menu.buttons[0].pressed.emit()
 await process_frame
 var creation := menu.creation
 creation.set_process(false)
 creation.select_character(7)
 creation._process(0.8)
 await capture("user://start-character-creation.png")
 creation.confirm.pressed.emit()
 creation.advance_cinematic(5.4)
 await process_frame
 check(is_instance_valid(menu.intro) and menu.intro.occupation == "Firefighter", "Confirmation opens the intro with the selected occupation")
 menu.intro._skip_intro()
 menu.intro._process(1.3)
 await process_frame
 var game := current_scene as Game
 game.set_process(false)
 var playlist := game.get_node("GameMusic") as GameMusic
 check(playlist.playing and playlist.track_index in [0,1],"Gameplay starts one of the original two tracks")
 check(is_equal_approx(db_to_linear(playlist.volume_db),0.3),"Gameplay music uses the original 30% volume")
 var first_track := playlist.track_index
 playlist.next_track()
 check(playlist.playing and playlist.track_index != first_track,"The playlist advances when a song ends")
 check(game.scene_file_path == "res://main.tscn" and game.sim.player().job == "Firefighter","Confirmation launches the selected occupation")
 check(game.sim.world_mode == "malton" and game.sim.width == 100,"New Game starts original Malton")
 check(game.sim.has_skill(game.sim.player(),"axe_proficiency"),"Selected occupation has its starting skill")
 check(FileAccess.get_file_as_string(TEST_SAVE) == "{}","New Game does not overwrite the existing save")
 check(not is_instance_valid(menu),"Gameplay replaces the menu")
 game.sim.player().xp = 123
 game._save()
 check(game.notice.begins_with("Saved to ") and game.save_path == TEST_SAVE,"Gameplay saves to the same slot used by the title")
 var saved_actor := game.sim.player().duplicate(true)
 var saved_minute := game.sim.minute
 menu = await open_title()
 menu.save_path = TEST_SAVE
 menu.buttons[1].pressed.emit()
 await scene_changed
 game = current_scene as Game
 game.set_process(false)
 check((game.get_node("GameMusic") as GameMusic).playing,"Loading a saved game starts the gameplay playlist")
 check(game.sim.player() == saved_actor and game.sim.minute == saved_minute,"Load Game preserves saved character and time without starting a new world")
 check(game.notice == "Loaded your neighbourhood.","Loaded game shows confirmation")
 await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
 print("Start screen: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
