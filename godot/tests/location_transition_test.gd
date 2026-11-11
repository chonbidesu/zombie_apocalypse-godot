extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.initial_world_mode = "sandbox"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 var sim = scene.sim
 var p = sim.player()
 p.human = true; p.down = false; p.inside = false; p.x = 4; p.y = 4; p.ap = 50; p.busy_until = 0.0
 sim.reindex()
 scene.refresh()
 scene.dispatch("move",-1,{"dx":1,"dy":-1})
 var transition = scene.scene_transition
 check(not transition.is_empty() and transition.command == "move" and transition.mask.clip_contents,"Adjacent movement starts a clipped scene transition")
 check(transition.previous.position == Vector2.ZERO and transition.next.position == Vector2(scene.ENVIRONMENT_RECT.size.x,-scene.ENVIRONMENT_RECT.size.y),"The new scene enters from the travel direction while the old scene stays still")
 scene.animation_time += 0.13
 scene._animate_scene_transition()
 check(transition.previous.position == Vector2.ZERO and transition.next.position.is_equal_approx(Vector2(scene.ENVIRONMENT_RECT.size.x,-scene.ENVIRONMENT_RECT.size.y)*0.5),"The old scene remains stationary halfway through a diagonal move")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://location-transition-preview.png")
 scene.animation_time += 0.2
 scene._animate_scene_transition()
 check(scene.scene_transition.is_empty(),"The movement transition clears after completion")
 p.ap = 0; p.busy_until = 0.0
 scene.dispatch("move",-1,{"dx":1,"dy":0})
 check(scene.scene_transition.is_empty(),"Rejected movement does not animate")
 var b = sim.current_block(p)
 b.type = "hospital"; b.barricade = 0; b.ruin = 0
 p.ap = 50; p.busy_until = 0.0; p.inside = false
 scene.refresh()
 scene.dispatch("enter")
 transition = scene.scene_transition
 var old_art = transition.previous.get_node("EnvironmentArt/Artwork")
 var new_art = transition.next.get_node("EnvironmentArt/Artwork")
 check(p.inside and transition.command == "enter" and old_art.scale == Vector2.ONE,"Entering begins from an unzoomed exterior")
 scene.animation_time += 0.095
 scene._animate_scene_transition()
 check(old_art.scale.x > 1.0 and new_art.scale.x > 1.0 and transition.previous.modulate.a < 1.0,"Entering pushes in and fades toward the interior")
 scene.animation_time += 0.4
 scene._animate_scene_transition()
 check(scene.page.get_node("EnvironmentArt/Artwork").scale == Vector2.ONE*scene.INTERIOR_ZOOM,"Interior art remains cropped at the resting zoom")
 p.ap = 50; p.busy_until = 0.0
 scene.dispatch("leave")
 transition = scene.scene_transition
 old_art = transition.previous.get_node("EnvironmentArt/Artwork")
 check(not p.inside and old_art.scale == Vector2.ONE*scene.INTERIOR_ZOOM,"Exiting begins at the interior zoom")
 scene.animation_time += 0.19
 scene._animate_scene_transition()
 check(old_art.scale.x > 1.0 and old_art.scale.x < scene.INTERIOR_ZOOM,"Exiting pulls back without shrinking below the setting frame")
 scene.animation_time += 0.3
 scene._animate_scene_transition()
 check(scene.scene_transition.is_empty() and scene.page.get_node("EnvironmentArt/Artwork").scale == Vector2.ONE,"The exterior returns to its normal scale")
 print("LOCATION TRANSITION CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
