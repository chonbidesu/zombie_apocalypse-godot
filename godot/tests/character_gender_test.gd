extends SceneTree
const Creation = preload("res://scripts/character_creation/character_creation.gd")
const C = preload("res://scripts/catalog.gd")
const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/interface.gd")
var failures := 0
var checks := 0

class CaptureMenu extends "res://scripts/start_screen.gd":
 var captured: Sim
 func enter_game(simulation: Sim, _message: String) -> void:
  captured = simulation

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func _initialize() -> void:
 run.call_deferred()

func screenshot(path: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(path) == OK,"Rendered review image saved: "+path)

func click(button: Button) -> void:
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = true
 event.position = button.get_global_rect().get_center()
 root.push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event,true)

func run() -> void:
 root.size = Vector2i(1536,864)
 var scene := load("res://character_creation.tscn").instantiate() as Creation
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 check(scene.sex_buttons.all(func(b): return not b.visible),"Gender controls hidden until a character is selected")
 var emitted: Array = []
 scene.character_confirmed.connect(func(job): emitted.append([job,scene.selected_sex()]))
 for index in scene.JOBS.size():
  var job: String = scene.JOBS[index][0]
  var default_sex := C.occupation_sex(job)
  var alternate := "female" if default_sex == "male" else "male"
  var button_index := 1 if alternate == "female" else 0
  var actor = scene.actors[index]
  var original_frames = actor.visual.sprite_frames
  var origin: Vector2 = actor.position
  var scale_before: Vector2 = actor.scale
  var offset: Vector2 = actor.visual.position
  var shadow = actor.shadow
  scene.select_character(index)
  check(scene.selected_sex() == default_sex,"Original gender is default: "+job)
  check(scene.sex_buttons[1-button_index].button_pressed,"Default gender button selected: "+job)
  check(scene.sex_buttons.all(func(b): return scene.info_panel.get_rect().encloses(b.get_rect()) and b.position.x > scene.details.get_rect().end.x),"Gender buttons sit on the right inside the description panel")
  click(scene.sex_buttons[button_index])
  check(scene.selected == index and scene.selected_sex() == alternate,"Physical gender button changes identity without selecting the actor underneath: "+job)
  check(scene.sex_buttons[button_index].button_pressed and not scene.sex_buttons[1-button_index].button_pressed,"Only current gender is pressed")
  check(scene.over_interface(scene.sex_buttons[button_index].get_rect().get_center()/scene.ROOM_SIZE),"Gender controls exclude room hover")
  var frames = actor.visual.sprite_frames
  var atlas: AtlasTexture = frames.get_frame_texture("idle",0)
  check(atlas.atlas.resource_path.ends_with(scene.ALTERNATE_SHEETS[index]+".png"),"Alternate room atlas: "+job)
  check(frames.get_frame_count("idle") == 4 and frames.get_frame_count("choice") == 8 and actor.masks.size() == 12,"All animation frames and hit masks retained")
  var expected_scale := scale_before
  check(actor.position == origin and actor.scale.is_equal_approx(expected_scale) and actor.visual.position == offset and actor.shadow == shadow and shadow.sprite_scale.is_equal_approx(expected_scale),"Switch preserves floor anchor and matches character and shadow scale")
  if index == 8: check(frames == original_frames,"Corpse reuses the original body-bag artwork")
  check(actor.visual.material == null and atlas.atlas.resource_path.begins_with("res://assets/character_creation/corrected/"),"Gender uses complete corrected artwork without overlays")
  scene.select_sex(alternate)
  check(actor.visual.sprite_frames == frames,"Clicking current gender does not rebuild the atlas")
  actor.tick(0.8,1.0)
  check(actor.shadow.last_frame == frames.get_frame_texture("idle",actor.visual.frame),"Shadow uses selected identity")
  scene.confirm_selection()
  check(scene.sex_buttons.all(func(b): return not b.visible),"Gender controls hide during confirmation")
  scene.select_sex(default_sex)
  check(scene.selected_sex() == alternate,"Gender is locked during confirmation")
  scene.advance_cinematic(0.5)
  actor.tick(3.2,1.0)
  check(actor.visual.animation == "choice" and actor.visual.frame == 7,"Alternate reaches the same final confirmation action")
  scene.advance_cinematic(5.0)
  check(emitted.back() == [job,alternate],"Confirmed occupation retains selected gender")
  scene.deselect_character()
  scene.select_character(index)
  check(scene.selected_sex() == default_sex,"Cancelling restores the default gender")
  scene.select_sex(default_sex)
  check(actor.scale.is_equal_approx(scale_before),"Original gender restores its scale")
  check((actor.visual.sprite_frames.get_frame_texture("idle",0) as AtlasTexture).atlas.resource_path.ends_with(scene.JOBS[index][3]+".png"),"Original atlas can be restored")
  check(actor.masks.size() == 12 and actor.get_child_count() == 1,"Repeated switches do not accumulate masks or nodes")
  if index == 3: check(actor.visual.material == null,"Doctor face and light are part of the PNG")
  scene.deselect_character()
  for cancel_path in range(3):
   scene.select_character(index)
   scene.select_sex(alternate)
   if cancel_path == 0:
    click(scene.cancel)
   elif cancel_path == 1:
    var right_click := InputEventMouseButton.new()
    right_click.button_index = MOUSE_BUTTON_RIGHT
    right_click.pressed = true
    root.push_input(right_click,true)
   else:
    scene.confirm_selection()
    scene.advance_cinematic(0.5)
    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    root.push_input(escape,true)
   check(scene.selected == -1 and scene.sexes[index] == default_sex,"Cancel button, right-click and cinematic Escape restore default identity: "+job)
   scene.select_character(index)
   check(scene.sex_buttons[1-button_index].button_pressed and (actor.visual.sprite_frames.get_frame_texture("idle",0) as AtlasTexture).atlas.resource_path.ends_with(scene.JOBS[index][3]+".png"),"Reopening a cancelled choice shows its default button and artwork")
   scene.deselect_character()
 # Moving to another occupation discards only the previous selection's edit.
 for index in scene.JOBS.size():
  scene.select_character(index)
  var default_sex := C.occupation_sex(scene.JOBS[index][0])
  var alternate := "female" if default_sex == "male" else "male"
  scene.select_sex(alternate)
  scene.select_character(index)
  check(scene.selected_sex() == alternate,"Clicking the same occupation preserves its gender")
  var next_index := (index+1)%scene.JOBS.size()
  scene.select_character(next_index)
  var atlas := scene.actors[index].visual.sprite_frames.get_frame_texture("idle",0) as AtlasTexture
  check(scene.sexes[index] == default_sex and atlas.atlas.resource_path.ends_with(scene.JOBS[index][3]+".png"),"Switching occupation resets previous gender and artwork")
  var next_default := C.occupation_sex(scene.JOBS[next_index][0])
  check(scene.selected_sex() == next_default and scene.sex_buttons[0 if next_default == "male" else 1].button_pressed,"New occupation shows its default gender button")
  scene.select_character(index)
  check(scene.selected_sex() == default_sex,"Returning to the previous occupation keeps its restored default")
 scene.deselect_character()
 # Render actual selection behaviour: only the selected occupation is alternate.
 scene.lighting = Vector4.ONE
 scene.material_room.set_shader_parameter("lights",Vector4.ONE)
 for actor in scene.actors: actor.tick(0.0,1.0)
 scene.select_character(0)
 scene.select_sex("female")
 await screenshot("user://character-gender-room.png")
 scene.select_character(6)
 scene.select_sex("female")
 scene.confirm_selection()
 scene.advance_cinematic(0.5)
 scene.actors[6].tick(3.2,1.0)
 scene.advance_cinematic(3.5)
 await screenshot("user://police-female-aim-preview.png")
 scene.queue_free()
 await process_frame
 # Use the actual title -> naming -> intro handoff and new-game construction.
 for index in Creation.JOBS.size():
  var menu := CaptureMenu.new()
  root.add_child(menu)
  await process_frame
  menu.open_creation()
  menu.creation.set_process(false)
  menu.creation.select_character(index)
  var job: String = Creation.JOBS[index][0]
  var sex := "female" if C.occupation_sex(job) == "male" else "male"
  menu.creation.select_sex(sex)
  menu.creation.confirm_selection()
  menu.creation.advance_cinematic(5.4)
  check(menu.chosen_sex == sex and is_instance_valid(menu.naming),"Selection reaches naming: "+job)
  menu.show_intro({"first":"Jamie","last":"Rivera","adjective":"Ashen"})
  menu.start_new_game(job)
  check(menu.captured.player().sex == sex and menu.captured.player().job == job,"New player uses selected gender: "+job)
  check(menu.captured.save_to("user://character-gender-test.json") == OK,"Save selected player")
  var restored := Sim.new()
  check(restored.load_from("user://character-gender-test.json").is_empty() and restored.player().sex == sex,"Selected gender survives save/load")
  var game := Game.new()
  game.sim = restored
  var portrait := game.portrait_texture(restored.player())
  check(portrait.resource_path == "res://assets/portraits/"+C.occupation_portrait(job,sex)+".png","Loaded player's portrait matches selected gender")
  game.free()
  menu.queue_free()
  await process_frame
 print("Character gender: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
