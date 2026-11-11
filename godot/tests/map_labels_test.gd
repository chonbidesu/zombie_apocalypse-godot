extends SceneTree
func _initialize():
 run.call_deferred()
func run():
 var scene = load("res://main.tscn").instantiate()
 scene.initial_world_mode = "sandbox"
 root.add_child(scene)
 await process_frame
 var sample = "St. Bartholomew's Metropolitan Police Department"
 var l = scene.map_name_label(scene, sample, Rect2(0,0,55,24), 10)
 assert(l.text.replace("\n", " ") == sample)
 var f = l.get_theme_font("font")
 var sz = l.get_theme_font_size("font_size")
 assert(l.text.split("\n").size() * f.get_height(sz) <= 24)
 for line in l.text.split("\n"): assert(f.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,sz).x <= 55)
 scene.open_city_map()
 assert(scene.overlay.get_node("Neighbourhood_0_0/MapName").text != "")
 scene.overlay.get_node("Neighbourhood_0_0").pressed.emit()
 assert(not scene.overlay.find_children("MapName","Label",true,false).is_empty())
 var sim = scene.sim
 assert(sim.start(42,"Private",{"mode":"malton","survivors":0,"zombies":0}).is_empty())
 var p = sim.player()
 p.inventory.clear()
 var bx = 0 if p.x >= 10 else 10
 var by = 0 if p.y >= 10 else 10
 var target = sim.block_at(bx,by)
 assert(not target.known and not sim.neighbourhood_visited(bx,by))
 scene.open_city_map()
 var tile = scene.overlay.get_node("Neighbourhood_%d_%d" % [bx,by])
 assert(tile.get_node("MapName").text == "Unknown")
 sim.give_item(p,"map")
 scene.refresh()
 tile = scene.overlay.get_node("Neighbourhood_%d_%d" % [bx,by])
 assert(tile.get_node("MapName").text.replace("\n"," ") == target.suburb)
 tile.pressed.emit()
 assert(scene.overlay.find_children("MapName","Label",true,false).size() == 100)
 assert(not target.known)
 sim.consume(p,sim.item_kind(p,"map"))
 scene.refresh()
 assert(scene.overlay.find_children("MapName","Label",true,false).is_empty())
 sim.give_item(p,"gps_unit")
 scene.open_city_map()
 var marker = scene.overlay.find_children("GPSNeighbourhood","Panel",true,false)[0]
 assert(marker.get_theme_stylebox("panel").border_color == Color.RED)
 scene.animation_time = 0.0
 scene._animate_scene(0.1)
 assert(marker.visible)
 scene._animate_scene(0.5)
 assert(not marker.visible)
 scene.overlay.get_node("FindMe").pressed.emit()
 marker = scene.overlay.find_children("GPSSquare","Panel",true,false)[0]
 assert(marker.get_theme_stylebox("panel").border_color == Color.RED)
 scene._animate_scene(0.5)
 assert(marker.visible)
 p.x = bx; p.y = by
 sim.discover()
 assert(sim.neighbourhood_visited(bx,by))
 assert(sim.save_to("user://map-discovery-test.json") == OK)
 var restored = load("res://scripts/simulation.gd").new()
 assert(restored.load_from("user://map-discovery-test.json").is_empty())
 assert(restored.neighbourhood_visited(bx,by))
 scene.open_city_map()
 assert(scene.overlay.get_node("Neighbourhood_%d_%d/MapName" % [bx,by]).text.replace("\n"," ") == target.suburb)
 print("Map labels fit and are visible")
 quit()
