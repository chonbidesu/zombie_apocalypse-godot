extends SceneTree

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 change_scene_to_file("res://start_screen.tscn")
 await scene_changed
 var menu = current_scene
 menu.buttons[0].pressed.emit()
 var credits = menu.attribution
 assert(credits != null and credits.page == 0 and menu.creation == null)
 credits._process(0.6)
 assert(credits.content.modulate.a > 0.0 and credits.content.modulate.a < 1.0)
 credits._process(4.5)
 assert(credits.content.modulate.a > 0.0 and credits.content.modulate.a < 1.0)
 credits._process(1.0)
 assert(credits.page == 1 and credits.tribute.visible)
 credits._process(1.2)
 assert(is_equal_approx(credits.content.modulate.a, 1.0))
 credits._process(9.6)
 assert(credits.content.modulate.a > 0.0 and credits.content.modulate.a < 1.0)
 credits._process(1.0)
 assert(menu.attribution == null and menu.creation != null and menu.creation.visible)
 menu.creation.back.pressed.emit()
 assert(menu.title_page.visible and menu.creation == null)
 print("Attribution flow passed")
 current_scene.queue_free()
 await process_frame
 await create_timer(0.1).timeout
 quit()
