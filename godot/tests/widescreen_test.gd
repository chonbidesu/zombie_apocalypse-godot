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
 check(scene.page.has_node("FullscreenToggle") and scene.page.get_node("SleepButton").text == "Sleep","Full-screen and Sleep controls are exposed")
 for entry in scene.action_controls:
  if entry.node.position.x >= 400: check(entry.node.position.y >= description.get_rect().end.y,"Scene action follows description")
 var initial_mode = DisplayServer.window_get_mode()
 scene.toggle_fullscreen()
 check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Full-screen mode can be entered")
 scene.toggle_fullscreen()
 check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,"Full-screen mode can be exited")
 DisplayServer.window_set_mode(initial_mode)
 await capture(viewport,"res://tests/widescreen-game-preview.png")
 p.ap = 12; p.busy_until = scene.sim.now()
 scene.begin_sleep()
 check(scene.page.has_node("DarkEnvironment") and scene.page.has_node("DarkMinimap") and scene.page.has_node("DarkDialogue"),"Sleep blacks out all perception panels")
 check(not scene.page.has_node("SceneActors") and not scene.log_view.visible and scene.log_view.text.is_empty(),"Sleep hides characters and chat updates")
 check(scene.action_controls.is_empty(),"Sleep hides inventory and action controls")
 await capture(viewport,"res://tests/sleep-preview.png")
 var esc = InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
 scene._unhandled_key_input(esc)
 check(not scene.sim.sleeping and scene.page.has_node("EnvironmentArt") and scene.log_view.visible,"Escape wakes the player and restores perception")
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
 await capture(viewport,"res://tests/powered-ruin-gallery.png")
 viewport.queue_free()
 print("WIDESCREEN / SLEEP / ART CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
