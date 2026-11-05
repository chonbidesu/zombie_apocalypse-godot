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
func capture(path: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.initial_world_mode = "sandbox"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 var p = scene.sim.player()
 var art = scene.page.get_node("EnvironmentArt")
 check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and art.size.y == 572,"Full-height environment art is fitted without cropping")
 check(scene.page.get_node("PlayerHealth").get_visible_line_count() == 1 and scene.page.get_node("PlayerEnergy").get_visible_line_count() == 1,"Personal HP/XP and AP values remain visible")
 var floor_ok = true
 scene.paused = true
 for step in range(60):
  scene._process(0.1)
  for entry in scene.actor_buttons:
   var bottom = scene.foot_bounds[entry.sheet][scene.actor_frame(scene.sim.actors[entry.id])].bottom
   var feet = entry.node.position.y+entry.node.size.y*bottom
   floor_ok = floor_ok and absf(feet-entry.ground) < 0.01
 check(floor_ok,"Visible feet remain on their ground line through animated frames")
 var first = scene.actor_buttons[0]
 var standing_feet = first.node.get_parent().position.y+first.ground
 check(standing_feet >= scene.ENVIRONMENT_RECT.end.y-30 and standing_feet < scene.ENVIRONMENT_RECT.end.y,"Sprites stand on the foreground near the bottom of the full image")
 check(scene.actions_bottom <= 1040 and scene.log_view.position.x >= 1440 and scene.log_view.position.y+scene.log_view.size.y <= 1034,"Actions fit below the description with a separate full-height activity feed")
 scene.paused = false
 p.inventory.clear()
 p.equipped = -1
 for i in range(23): scene.sim.give_item(p,"first_aid_kit")
 scene.inventory_page = 0
 scene.refresh()
 check(scene.page.find_children("InventoryItem_*","Button",true,false).size() == 10,"First page shows ten items without capping inventory")
 check(not scene.page.get_node("InventoryNext").disabled and scene.page.get_node("InventoryPrevious").disabled,"Pagination enables the correct direction")
 scene.selected_item = p.inventory[0].uid
 scene.page.get_node("InventoryNext").pressed.emit()
 check(scene.inventory_page == 1 and scene.selected_item == -1 and scene.page.has_node("InventoryItem_%d" % p.inventory[10].uid),"Next page reveals later items and clears hidden selection")
 scene.page.get_node("InventoryNext").pressed.emit()
 check(scene.inventory_page == 2 and scene.page.find_children("InventoryItem_*","Button",true,false).size() == 3,"Final partial page exposes every remaining item")
 var item = p.inventory.back()
 scene.page.get_node("InventoryItem_%d" % item.uid).pressed.emit()
 check(scene.selected_item == item.uid and scene.action_controls.any(func(e): return e.command == "drop"),"Items beyond the original ten remain selectable and usable")
 var load_before = scene.sim.encumbrance(p)
 p.busy_until = scene.sim.now()
 scene.dispatch("drop",-1,{"uid":item.uid})
 check(p.inventory.size() == 22 and scene.sim.encumbrance(p) == load_before-2,"Dropping from a later page immediately updates load")
 p.inventory.resize(10)
 scene.refresh()
 check(scene.inventory_page == 0 and scene.page.get_node("InventoryNext").disabled,"Shrinking inventory clamps an obsolete final page")
 for i in range(13): scene.sim.give_item(p,"first_aid_kit")
 scene.inventory_page = 1
 scene.refresh()
 await capture("res://tests/encumbrance-inventory-preview.png")
 var b = scene.sim.current_block(p)
 b.type = "aquarium"
 b.barricade = 0
 b.ruin = 0
 b.generator = false
 scene.sim.initialize_block(b)
 p.human_skills = ["construction"]
 p.inside = true
 scene.refresh()
 check(scene.action_controls.any(func(e): return e.command == "barricade") and not scene.action_controls.any(func(e): return e.command == "close"),"Zoo enclosure UI offers barricading and omits nonexistent doors")
 b.type = "zoo_ground"
 p.inside = false
 scene.sim.initialize_block(b)
 scene.refresh()
 check(not scene.action_controls.any(func(e): return e.command in ["enter","barricade","close"]),"Open zoo ground has no shelter or barricade actions")
 p.down = true
 p.hp = 0
 scene.refresh()
 check(scene.page.has_node("DarkEnvironment") and not scene.page.has_node("EnvironmentArt") and scene.action_controls.any(func(e): return e.command == "stand"),"Expanded darkness still hides the world while leaving standing available")
 await capture("res://tests/full-height-downed-preview.png")
 print("ENVIRONMENT/INVENTORY UI CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
