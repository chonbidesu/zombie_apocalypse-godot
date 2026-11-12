extends SceneTree
const Interface = preload("res://scripts/interface.gd")
const C = preload("res://scripts/catalog.gd")
var failures = 0
var checks = 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 run.call_deferred()
func capture(viewport: SubViewport, path: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 check(viewport.get_texture().get_image().save_png(path) == OK,"Preview saved: "+path)
func run() -> void:
 var viewport = SubViewport.new()
 viewport.size = Vector2i(1920,1080)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var scene = Interface.new()
 scene.initial_world_mode = "sandbox"
 viewport.add_child(scene)
 await process_frame
 scene.set_process(false)
 var p = scene.sim.player()
 var description = scene.page.get_node("LocationDescription")
 var art = scene.page.get_node("EnvironmentArt")
 check(description.position.y > art.get_rect().end.y,"Description sits entirely below the environment image")
 check(description.get_rect().end.y <= 935 and scene.actions_bottom <= 1040,"Description and actions fit above the footer")
 check(scene.log_view.position.x >= art.get_rect().end.x+20 and scene.log_view.size.y >= 840,"Dialogue occupies its own narrow full-height right column")
 check(scene.page.has_node("SettingsButton") and scene.page.get_node("SleepButton").text == "Sleep","Settings and Sleep controls are exposed")
 for entry in scene.action_controls:
  if entry.node.position.x >= 400: check(entry.node.position.y >= description.get_rect().end.y,"Scene action follows description")
 var settings = root.get_node("PlayerSettings")
 settings.config_path = "user://widescreen-test-settings.cfg"
 var initial_mode := root.mode
 var esc := InputEventKey.new()
 esc.keycode = KEY_ESCAPE
 esc.pressed = true
 var space := InputEventKey.new()
 space.keycode = KEY_SPACE
 space.pressed = true
 viewport.push_input(esc, true)
 check(scene.modal == "settings" and not scene.paused,"Escape opens Settings during play")
 var minute: int = scene.sim.minute
 scene._process(3.0)
 check(scene.sim.minute == minute,"Settings suspends simulation while it is open")
 var screen: OptionButton = scene.overlay.find_child("ScreenMode",true,false)
 screen.item_selected.emit(1)
 check(root.mode == Window.MODE_FULLSCREEN and screen.selected == 1,"Settings enters Full Screen")
 screen.item_selected.emit(0)
 check(root.mode == Window.MODE_WINDOWED and screen.selected == 0,"Settings returns to Windowed")
 root.mode = initial_mode
 var master: HSlider = scene.overlay.find_child("MasterVolume",true,false)
 var music: HSlider = scene.overlay.find_child("MusicVolume",true,false)
 var effects: HSlider = scene.overlay.find_child("SFXVolume",true,false)
 master.value = 52
 music.value = 37
 effects.value = 0
 check(is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(0.52)),"Master applies live gain")
 check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")),linear_to_db(0.37)),"Music applies independent gain")
 check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"Sound effects mute at zero")
 scene.game_sounds.play_effect("footsteps")
 check(scene.game_sounds.get_child(0).bus == &"SFX","Gameplay effects play through the sound effects bus")
 var saved := ConfigFile.new()
 check(saved.load(settings.config_path) == OK and saved.get_value("audio","master") == 52 and saved.get_value("audio","music") == 37 and saved.get_value("audio","sfx") == 0 and saved.get_value("screen","fullscreen") == false,"Screen and audio choices are saved")
 viewport.push_input(esc, true)
 check(scene.modal.is_empty() and not scene.paused,"Escape closes Settings and resumes play")
 viewport.push_input(space, true)
 check(scene.paused,"Space pauses the simulation")
 scene.page.get_node("SettingsButton").pressed.emit()
 check(scene.modal == "settings" and scene.overlay.find_child("MusicVolume",true,false).value == 37,"Settings button opens the menu with current preferences")
 scene.overlay.find_child("SettingsDone",true,false).pressed.emit()
 check(scene.paused and scene.modal.is_empty(),"Closing Settings preserves a Space pause")
 viewport.push_input(space, true)
 check(not scene.paused,"Space resumes the simulation")
 DirAccess.remove_absolute(settings.config_path)
 await capture(viewport,"res://tests/widescreen_game_preview.png")
 p.ap = 12; p.busy_until = scene.sim.now()
 art = scene.page.get_node("EnvironmentArt")
 var people: Control = scene.page.get_node("SceneActors")
 var sleep_control: Button = scene.page.get_node("SleepButton")
 scene.begin_sleep()
 check(scene.page.has_node("DarkEnvironment") and scene.page.has_node("DarkMinimap") and scene.page.has_node("DarkDialogue"),"Sleep blacks out all perception panels")
 check(not people.is_visible_in_tree() and not scene.log_view.visible and scene.log_view.text.is_empty(),"Sleep hides characters and chat updates")
 check(scene.action_controls.all(func(entry): return not entry.node.is_visible_in_tree()),"Sleep hides inventory and action controls")
 await capture(viewport,"res://tests/sleep_preview.png")
 scene._unhandled_key_input(esc)
 check(not scene.sim.sleeping and scene.page.get_node("EnvironmentArt") == art and people.is_visible_in_tree()
  and scene.log_view.visible and scene.page.get_node("SleepButton") == sleep_control,"Escape wakes the player and restores the existing dashboard")
 # Each eligible building has a distinct, nonempty powered-ruin texture.
 var b = scene.sim.current_block(p)
 for kind in C.BUILDINGS:
  b.type = kind
  if not scene.sim.can_host_generator(b) or not scene.sim.can_be_ransacked(b): continue
  var art_kind = "office" if kind == "necrotech_lab" else kind
  var texture = scene.minimap_artwork.model(art_kind,3,0)
  check(texture != null and texture.get_image().get_used_rect().has_area() and texture != scene.minimap_artwork.model(art_kind,2,0),"New powered-ruin artwork: "+kind)
 for variant in range(4): check(scene.minimap_artwork.model("mall",3,variant) != null,"Powered-ruin mall style: %d" % variant)
 check(scene.minimap_artwork.model("mall_l",3,0) != null,"Powered-ruin L-shaped mall")
 for variant in range(2): check(scene.minimap_artwork.model("fort_property",3,variant) != null,"Powered-ruin fort property: %d" % variant)
 for state in [1,2,3]: check(scene.minimap_artwork.model("junkyard",state,0) == scene.minimap_artwork.model("junkyard",0,0),"Unused junkyard state discarded: %d" % state)
 for kind in ["aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]:
  check(scene.minimap_artwork.model(kind,2,0) == scene.minimap_artwork.model(kind,0,0),"Zoo enclosure ruin art discarded: "+kind)
 scene.visible = false
 var canvas = Control.new()
 canvas.theme = scene.theme
 viewport.add_child(canvas)
 scene.rect(canvas,Rect2(0,0,1920,1080),Color("101b18"))
 scene.label(canvas,"POWERED RUINS / SURVIVING LIGHTS IN BROKEN BUILDINGS",Rect2(20,4,1880,36),26,scene.GOLD)
 var examples = []
 for kind in C.BUILDINGS:
  b.type = kind
  if scene.sim.can_host_generator(b) and scene.sim.can_be_ransacked(b) and kind != "necrotech_lab": examples.append([kind,0,C.pretty(kind)])
 for variant in range(1,4): examples.append(["mall",variant,"Mall style %d" % (variant+1)])
 examples.append(["mall_l",0,"L-shaped mall"])
 examples.append(["fort_property",0,"Fort Creedy property"])
 examples.append(["fort_property",1,"Fort Perryn property"])
 for i in range(examples.size()):
  var at = Vector2(14+(i%6)*318,46+(i/6)*170)
  scene.label(canvas,examples[i][2],Rect2(at,Vector2(308,25)),18,scene.CREAM)
  var sprite = scene.picture(canvas,scene.minimap_artwork.model(examples[i][0],3,examples[i][1]),Rect2(at+Vector2(0,26),Vector2(308,140)))
  sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 await capture(viewport,"res://tests/powered_ruin_gallery.png")
 viewport.queue_free()
 print("WIDESCREEN / SLEEP / ART CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
