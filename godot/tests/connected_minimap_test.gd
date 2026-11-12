extends SceneTree
const Interface = preload("res://scripts/interface.gd")
const C = preload("res://scripts/catalog.gd")
const Art = preload("res://scripts/minimap_art.gd")
const Ground = preload("res://scripts/minimap_ground.gd")
var scene
var failures = 0

func check(ok: bool, message: String) -> void:
 if ok: print("PASS: "+message)
 else: failures += 1; push_error(message)

func _initialize() -> void:
 call_deferred("run")

func screenshot(path: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)

func run() -> void:
 root.size = Vector2i(1920,1080)
 scene = Interface.new()
 root.add_child(scene)
 scene.set_process(false)
 var sim = scene.sim
 var rng_state = sim.rng.state
 var catalog = scene.minimap_artwork
 for kind in C.BUILDINGS:
  var key = "office" if kind == "necrotech_lab" else kind
  for state in range(3):
   check(catalog.model(key,state,0) != null,"Architectural state exists: %s/%d" % [kind,state])
 for kind in C.OUTDOORS:
  check(catalog.model(kind,0,0) != null,"Outdoor art exists: "+kind)
 var streets = {}
 for variant in range(6):
  var street: Texture2D = catalog.model("street",0,variant)
  streets[street] = true
  check(street.get_image().get_pixel(384,384).a < 0.01,"Street corridor has genuine empty alpha: %d" % variant)
 check(streets.size() == 6,"Six independent street variants")
 var malls = {}
 for variant in range(4): malls[catalog.model("mall",0,variant)] = true
 check(malls.size() == 4,"Four independent mall designs")
 var mall = sim.block_at(92,7)
 var adjacent = sim.block_at(93,7)
 for b in [mall,adjacent]: b.ruin = 0; b.generator = false
 var left: AtlasTexture = scene.map_art(mall)
 var right: AtlasTexture = scene.map_art(adjacent)
 check(left.atlas == right.atlas and left.region.end.x == right.region.position.x,"Multi-block roof crops meet without a gutter")
 mall.generator = true
 mall.fuel_until = sim.minute+500
 var lit = scene.map_art(mall)
 check(lit.atlas != left.atlas and scene.map_art(adjacent) == right,"Power changes only one complex square")
 mall.ruin = 3
 check(scene.map_art(mall).atlas != lit.atlas and scene.map_art(adjacent) == right,"Ruin changes only one complex square and overrides light")
 var ground = Ground.new()
 ground.sim = sim
 ground.block = adjacent
 check(ground.joined(Vector2i.LEFT) and not ground.joined(Vector2i.UP),"Only internal complex boundaries suppress roads")
 ground.free()
 check(sim.rng.state == rng_state,"Map art and variants do not consume simulation randomness")
 # Keep a mixed-state example for the visual gallery.
 mall.ruin = 0
 var ruined_section = sim.block_at(93,8)
 ruined_section.ruin = 3
 var old_position = Vector2i(sim.player().x,sim.player().y)
 scene.refresh()
 var local_map = scene.page.get_node("CityMinimap")
 check(local_map.get_node("MapTile_%d" % sim.current_block(sim.player()).id).size == Vector2(106,106),"Minimap hit regions touch at their full stride")
 var building_rect: Rect2 = local_map.projected_rect(sim.current_block(sim.player()))
 check(building_rect.position.y < 106 and building_rect.size.x > 106*0.85,"Building fills its plot and projects north across its gameplay square")
 check(local_map.clip_contents and not local_map.tiles[sim.current_block(sim.player()).id].clip_contents,"Only the whole map clips roofs and shadows")
 var zoo = sim.blocks.filter(func(b): return not b.zoo.is_empty())
 var first_zoo: AtlasTexture = scene.map_art(zoo[0])
 var second_zoo: AtlasTexture = scene.map_art(zoo[1])
 check(first_zoo.atlas == second_zoo.atlas and first_zoo.region != second_zoo.region,"Zoo grounds sample different continuous regions of one complete landscape")
 for fort_name in ["Fort Creedy","Fort Perryn"]:
  var sections = sim.blocks.filter(func(b): return b.fort == fort_name)
  var first: AtlasTexture = scene.map_art(sections[0])
  var second: AtlasTexture = scene.map_art(sections[1])
  check(first.atlas == second.atlas,"Fort sections share one property composition: "+fort_name)
  var gate: Dictionary = sections.filter(func(b): return b.type == "gatehouse")[0]
  var property: Dictionary = catalog.property_info(sim,gate)
  var offset = Vector2i(gate.x,gate.y)-property.footprint.position
  check(offset == (Vector2i(2,1) if fort_name == "Fort Creedy" else Vector2i(1,2)),"Gatehouse joins the correct perimeter side: "+fort_name)
 await screenshot("res://tests/connected_minimap_game.png")
 scene.open_modal("help")
 check(scene.overlay.z_index > 1000,"Modal dialogs cover the map's depth and interaction layers")
 scene.modal = ""
 scene.refresh()
 root.remove_child(scene)
 var canvas = Control.new()
 root.add_child(canvas)
 canvas.theme = scene.theme
 scene.rect(canvas,Rect2(0,0,1440,960),Color("101b18"))
 scene.label(canvas,"CONNECTED CITY MINIMAP",Rect2(24,8,1390,36),29,Color("d8b76b"))
 panel(canvas,"City blocks",Vector2(24,62),Rect2i(old_position-Vector2i.ONE,Vector2i(3,3)),100)
 # A deterministic demonstration using real world squares and runtime art.
 var street_position = Vector2i(5,5)
 var snapshots: Array = []
 for dy in range(3):
  for dx in range(3):
   var b = sim.block_at(street_position.x+dx,street_position.y+dy)
   snapshots.append(b.duplicate(true))
   b.type = "street"; b.complex = ""; b.fort = ""; b.zoo = ""
 panel(canvas,"Street variations",Vector2(378,62),Rect2i(street_position,Vector2i(3,3)),100)
 for b in snapshots: sim.blocks[b.id] = b
 panel(canvas,"Mall: lit / unlit / ruined",Vector2(732,62),Rect2i(92,7,2,2),150)
 var pole: Rect2i = sim.complex_bounds["Pole Mall"]
 panel(canvas,"Pole Mall: original L footprint",Vector2(1086,62),pole,150)
 for item in [["Fort Creedy",Vector2(24,466)],["Fort Perryn",Vector2(378,466)]]:
  var sites: Array = sim.blocks.filter(func(b): return b.fort == item[0])
  var at = Vector2i(100,100)
  for b in sites: at = at.min(Vector2i(b.x,b.y))
  panel(canvas,item[0]+" · raised walls",item[1],Rect2i(at-Vector2i.ONE,Vector2i(5,5)),60)
 panel(canvas,"Malton Zoo · original 5 × 4",Vector2(732,466),sim.complex_bounds["Malton Zoo"],60)
 var cathedral: Dictionary = sim.blocks.filter(func(b): return b.type == "cathedral")[0]
 panel(canvas,"Cathedral · shared roof",Vector2(1086,466),sim.complex_bounds[cathedral.complex],150)
 scene.label(canvas,"Warm windows: powered    Broken roofs: ruined    All sections keep their own state",Rect2(24,898,1390,32),22,Color("a8b6a5"))
 await screenshot("res://tests/connected_minimap_gallery.png")
 root.remove_child(canvas)
 canvas.queue_free()
 await depth_preview()
 scene.free()
 # Original templates must survive relocation, including all exceptional plans.
 var generated = preload("res://scripts/world_builder.gd").build({"mode":"random","width":40,"height":40,"malls":20,"forts":2,"zoos":1,"power_stations":2,"counts":{}},771,{})
 check(not generated.has("error"),"All original special footprints fit a generated city")
 if not generated.has("error"):
  var sites: Array = generated.blocks
  check(sites.filter(func(b): return b.type == "mall").size() == 77,"Random city preserves 77 squares across twenty Malton mall plans")
  check(sites.filter(func(b): return b.get("zoo","") == "Malton Zoo").size() == 20,"Random zoo uses original twenty-square footprint")
  check(sites.filter(func(b): return b.type == "power_station").size() == 6,"Random power stations use original two- and four-square plans")
  for fort in ["Fort Creedy","Fort Perryn"]:
   check(sites.filter(func(b): return b.get("fort","") == fort).size() == 9,"Generated city preserves "+fort)
 print("Connected minimap failures: %d" % failures)
 quit(1 if failures else 0)

func panel(parent: Control, title: String, at: Vector2, footprint: Rect2i, cell: float) -> void:
 scene.label(parent,title,Rect2(at,Vector2(330,28)),18,Color("d8b76b"))
 scene.map_region(parent,footprint,at+Vector2(0,34),cell)

func depth_preview() -> void:
 var viewport = SubViewport.new()
 viewport.size = Vector2i(1600,1160)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var canvas = Control.new()
 canvas.theme = scene.theme
 viewport.add_child(canvas)
 scene.rect(canvas,Rect2(0,0,1600,1160),Color("101b18"))
 scene.label(canvas,"CITY DEPTH / SHARED PROPERTIES",Rect2(24,6,1500,40),30,Color("d8b76b"))
 var original: Array = []
 var kinds = ["warehouse","fire_station","mall","police_department","street","necrotech_lab","carpark","tower","warehouse"]
 for i in range(9):
  var b = scene.sim.block_at(5+i%3,5+i/3)
  original.append(b)
  var replacement = b.duplicate(true)
  replacement.type = kinds[i]
  replacement.complex = ""; replacement.fort = ""; replacement.zoo = ""
  replacement.name = "Dulston Mall" if kinds[i] == "mall" else kinds[i]
  replacement.ruin = 0; replacement.generator = false
  scene.sim.blocks[b.id] = replacement
 panel(canvas,"City · roofs and directional shadows",Vector2(24,56),Rect2i(5,5,3,3),160)
 for b in original: scene.sim.blocks[b.id] = b
 var fort_positions = {}
 for name in ["Fort Creedy","Fort Perryn"]:
  var at = Vector2i(100,100)
  for b in scene.sim.blocks:
   if b.fort == name: at = at.min(Vector2i(b.x,b.y))
  fort_positions[name] = at
 panel(canvas,"Fort Creedy · raised perimeter",Vector2(552,56),Rect2i(fort_positions["Fort Creedy"]-Vector2i.ONE,Vector2i(5,5)),96)
 var zoo: Rect2i = scene.sim.complex_bounds["Malton Zoo"]
 panel(canvas,"Zoo · continuous landscape",Vector2(1080,56),zoo.grow(1),480.0/7.0)
 panel(canvas,"Fort Perryn · south gatehouse",Vector2(24,610),Rect2i(fort_positions["Fort Perryn"]-Vector2i.ONE,Vector2i(5,5)),96)
 panel(canvas,"Mall · independent section states",Vector2(552,610),Rect2i(92,7,2,2),240)
 panel(canvas,"Pole Mall · inner courtyard",Vector2(1080,610),scene.sim.complex_bounds["Pole Mall"],240)
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 check(viewport.get_texture().get_image().save_png("res://tests/minimap_depth_preview.png") == OK,"Depth preview renders at full size without desktop clipping")
 root.remove_child(viewport)
 viewport.queue_free()
 await gate_preview()

func gate_preview() -> void:
 var viewport = SubViewport.new()
 viewport.size = Vector2i(1000,590)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var canvas = Control.new()
 canvas.theme = scene.theme
 viewport.add_child(canvas)
 scene.rect(canvas,Rect2(0,0,1000,590),Color("101b18"))
 scene.label(canvas,"FORT ENTRY / THROUGH THE GATEHOUSE",Rect2(24,8,950,36),26,Color("d8b76b"))
 for i in range(2):
  var name = ["Fort Creedy","Fort Perryn"][i]
  var gate: Dictionary = scene.sim.blocks.filter(func(b): return b.fort == name and b.type == "gatehouse")[0]
  panel(canvas,name+ (" · EAST entrance" if i == 0 else " · SOUTH entrance"),Vector2(24+i*500,62),Rect2i(gate.x-1,gate.y-1,3,3),150)
 scene.label(canvas,"Walls turn into the tower jambs. Entry uses the gatehouse; map exits remain possible.",Rect2(24,558,960,26),18,Color("a8b6a5"))
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 check(viewport.get_texture().get_image().save_png("res://tests/fort_gatehouse_preview.png") == OK,"Gatehouse connection preview renders")
 root.remove_child(viewport)
 viewport.queue_free()
