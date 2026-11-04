extends SceneTree
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0
var scene
var canvas: Control
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)
func _initialize() -> void:
 run.call_deferred()
func screenshot(path: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func new_canvas() -> void:
 if is_instance_valid(canvas):
  root.remove_child(canvas)
  canvas.queue_free()
 canvas = Control.new()
 root.add_child(canvas)
func text_at(text: String, at: Vector2, size: Vector2) -> void:
 var node = Label.new()
 node.text = text
 node.position = at
 node.size = size
 node.add_theme_font_size_override("font_size",16)
 node.add_theme_color_override("font_color",Color.WHITE)
 canvas.add_child(node)
func picture(path: String, bounds: Rect2, frame: int = -1) -> void:
 var texture: Texture2D = load(path)
 if frame >= 0:
  var atlas = AtlasTexture.new()
  atlas.atlas = texture
  if texture.get_width() > texture.get_height()*8:
   atlas.region = Rect2(frame*64,0,64,64)
  else:
   var cell = Vector2(texture.get_width()/6.0,texture.get_height()/4.0)
   atlas.region = Rect2(Vector2(frame%6,frame/6)*cell,cell)
  texture = atlas
 var node = TextureRect.new()
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.texture = texture
 node.position = bounds.position
 node.size = bounds.size
 node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 canvas.add_child(node)
func run() -> void:
 scene = load("res://main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 check(scene.sim.width == 100 and scene.sim.world_mode == "malton","Normal launch starts on the original city")
 await screenshot("res://tests/malton-start-preview.png")
 scene.open_modal("restart")
 check(scene.overlay.get_node("WorldMode").item_count == 3,"New Game offers original, random and legacy worlds")
 scene.new_world_mode = "random"
 scene.refresh()
 check(scene.overlay.get_node("GenerationCounts").find_children("Count_*","SpinBox",true,false).size() == 20,"Random setup exposes every ordinary resource/building count")
 check(scene.overlay.get_node("GenerationSettings").find_children("Config_*","SpinBox",true,false).size() == 11,"Random setup exposes dimensions, all complexes and population")
 var hospital_count = scene.overlay.find_child("Count_hospital",true,false)
 hospital_count.value = 13
 scene.refresh()
 check(scene.new_world_config.counts.hospital == 13 and scene.overlay.find_child("Count_hospital",true,false).value == 13,"Generation edits survive UI rebuilds")
 await screenshot("res://tests/world-setup-preview.png")
 scene.modal = ""
 var p = scene.sim.player()
 p.x = 97
 p.y = 0
 p.inside = false
 p.human_skills.clear()
 p.human = true
 scene.sim.reindex()
 scene.refresh()
 var b = scene.sim.current_block(p)
 var office = b.duplicate()
 office.type = "office"
 check(scene.map_art(b) == scene.map_art(office),"Office and lab map art share exactly the same texture")
 check(not scene.page.get_node("MapTile_97").has_node("NecroTechLogo_97"),"Untrained survivor sees no NecroTech map logo")
 var outside = scene.page.get_children().filter(func(n): return n is TextureRect and n.texture != null and n.texture.resource_path.ends_with("office_outside.png"))
 check(outside.size() == 1,"Hidden lab exterior uses the exact office scene")
 p.human = false
 scene.refresh()
 check(not scene.page.get_node("MapTile_97").has_node("NecroTechLogo_97"),"Untrained zombie also sees no logo")
 p.human_skills.append("necro_employment")
 scene.refresh()
 check(scene.page.get_node("MapTile_97").has_node("NecroTechLogo_97"),"Employment reveals the rooftop NT after death")
 check(scene.page.get_node("MapTile_97/NecroTechLogo_97").get_child(0).text == "NT","The NecroTech logo uses NT rather than N")
 await screenshot("res://tests/necrotech-recognition-preview.png")
 scene.open_modal("map")
 scene.city_overview = true
 scene.refresh()
 check(scene.overlay.find_children("*","Button",true,false).size() >= 107,"City overview provides all one hundred suburb selectors")
 await screenshot("res://tests/malton-city-preview.png")
 scene.modal = ""
 p.x = 92
 p.y = 7
 p.human = true
 p.inside = true
 scene.sim.reindex()
 scene.refresh()
 var top_left: AtlasTexture = scene.map_art(scene.sim.block_at(92,7))
 var top_right: AtlasTexture = scene.map_art(scene.sim.block_at(93,7))
 var bottom_right: AtlasTexture = scene.map_art(scene.sim.block_at(93,8))
 check(top_left.atlas == top_right.atlas and top_left.region.end.x == top_right.region.position.x and top_left.region.position.y == top_right.region.position.y,"Adjacent mall squares crop continuous regions of one building image")
 check(top_right.region.end.y == bottom_right.region.position.y and top_right.region.position.x == bottom_right.region.position.x,"Mall roof connects vertically as well as horizontally")
 check(scene.sim.complex_bounds["Lumber Mall"].size == Vector2i(1,2) and scene.sim.complex_bounds["Pole Mall"].size == Vector2i(2,2),"Shared art respects irregular original mall footprints")
 await screenshot("res://tests/connected-mall-preview.png")
 scene.sim.start()
 scene.feed.reset(scene.sim.messages)
 var jobs = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse"]
 for i in range(jobs.size()):
  var a = scene.sim.actors[i+1]
  a.job = jobs[i]
  a.x = 4
  a.y = 4
  a.inside = true
  a.human = true
  a.down = false
 scene.sim.reindex()
 scene.selected_actor = -1
 scene.refresh()
 var sheets = {}
 for job in jobs:
  var key = C.occupation_sheet(job,true)
  var texture: Texture2D = load("res://assets/sprite_sheets/"+key+"_sprite_sheet.png")
  check(texture != null and texture.get_width()*2 == texture.get_height()*3,"Occupation has a dedicated 6×4 animation atlas: "+job)
  sheets[key] = true
 check(sheets.size() == 9,"All nine human/revived occupation appearances are distinct")
 await screenshot("res://tests/occupation-crowd-preview.png")
 root.remove_child(scene)
 scene.queue_free()
 root.size = Vector2i(1440,960)
 var old_types = C.NORMAL_BUILDINGS+["street","park","cemetery","monument","carpark"]
 for page in range(2):
  new_canvas()
  for i in range(page*16,mini(old_types.size(),(page+1)*16)):
   var kind = old_types[i]
   var origin = Vector2(12+((i-page*16)%4)*356,12+((i-page*16)/4)*232)
   text_at(C.pretty(kind),origin,Vector2(344,24))
   picture("res://assets/blocks/"+("streets" if kind == "street" else kind)+".png",Rect2(origin+Vector2(0,30),Vector2(104,104)))
   picture("res://assets/settings/"+kind+"_outside.png",Rect2(origin+Vector2(108,28),Vector2(236,98)))
   if kind in C.BUILDINGS: picture("res://assets/settings/"+kind+"_inside.png",Rect2(origin+Vector2(108,130),Vector2(236,98)))
  await screenshot("res://tests/refreshed-locations-%d.png" % (page+1))
 new_canvas()
 var frames = [0,4,8,12,15,18,20,21,23]
 for i in range(jobs.size()):
  var key = C.occupation_sheet(jobs[i],true)
  text_at(jobs[i],Vector2(12,20+i*104),Vector2(240,70))
  for j in range(frames.size()):
   picture("res://assets/sprite_sheets/"+key+"_sprite_sheet.png",Rect2(Vector2(260+j*128,12+i*104),Vector2(100,100)),frames[j])
 await screenshot("res://tests/occupation-animation-gallery.png")
 new_canvas()
 var zombie: Texture2D = load("res://assets/sprite_sheets/zombie_sprite_sheet.png")
 check(zombie.get_width() == 1536 and zombie.get_height() == 1024,"The replacement zombie has a complete 6 by 4 atlas")
 check(FileAccess.get_file_as_bytes("res://assets/blocks/streets.png") == FileAccess.get_file_as_bytes("res://.art-backup/blocks/streets.png"),"Street minimap art is the exact original asset")
 var titles = ["Slow stagger", "Claw strike", "Collapse", "Corpse", "Recoil"]
 var sample_frames = [[0,2,4,7],[8,10,12,14],[15,16,17,19],[20,20,20,20],[21,22,23,21]]
 for row in range(titles.size()):
  text_at(titles[row],Vector2(20,30+row*180),Vector2(220,30))
  for col in range(4):
   picture("res://assets/sprite_sheets/zombie_sprite_sheet.png",Rect2(260+col*240,row*180,180,180),sample_frames[row][col])
 await screenshot("res://tests/zombie-animation-preview.png")
 print("STYLE/UI CHECKS: ",checks," FAILURES: ",failures,"; 80 refreshed assets rendered")
 quit(0 if failures == 0 else 1)
