extends SceneTree
const Architecture = preload("res://scripts/location_architecture.gd")
const Art = preload("res://scripts/minimap_art.gd")
const MapCanvas = preload("res://scripts/minimap_canvas.gd")
const Sim = preload("res://scripts/simulation.gd")
var canvas: Control
var sim = Sim.new()
var artwork = Art.new()
var locations = Architecture.new()

func _initialize() -> void:
 run.call_deferred()

func label_at(value: String, at: Vector2, font_size: int = 20) -> void:
 var label = Label.new()
 label.text = value
 label.position = at
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("eee2c6"))
 canvas.add_child(label)

func picture(texture: Texture2D, bounds: Rect2, keep_aspect: bool = false) -> void:
 var node = TextureRect.new()
 node.texture = texture
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
 node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 node.position = bounds.position
 node.size = bounds.size
 canvas.add_child(node)

func background() -> void:
 if is_instance_valid(canvas):
  root.remove_child(canvas)
  canvas.queue_free()
 canvas = Control.new()
 root.add_child(canvas)
 var fill = ColorRect.new()
 fill.color = Color("172823")
 fill.size = Vector2(1920,1080)
 canvas.add_child(fill)

func capture(path: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)

func run() -> void:
 root.size = Vector2i(1920,1080)
 sim.start(1729,"Volunteer",{"mode":"malton","survivors":0,"zombies":0})
 var samples = {}
 for b in sim.blocks:
  if Architecture.eligible(b): samples[Architecture.variant_for(sim,b)] = b
 background()
 label_at("THREE ARCHITECTURAL FAMILIES / FOUR BUILDING STATES",Vector2(24,12),30)
 for variant in range(3):
  var x = 24+variant*632
  label_at(Architecture.STYLES[variant].to_upper(),Vector2(x,60),25)
  for status in range(4):
   label_at(["Unlit","Lit","Ruined","Lit ruin"][status],Vector2(x+status*150,97),18)
  for row in range(3):
   var kind = ["hospital","police_department","fire_station"][row]
   for status in range(4):
    picture(artwork.model(kind,status,variant),Rect2(x+status*150,127+row*155,146,146))
  var b: Dictionary = samples[variant].duplicate()
  b.type = "hospital"
  label_at("HOSPITAL / exterior and ward",Vector2(x,600),19)
  for inside in [false,true]:
   picture(locations.setting_for(sim,b,inside),Rect2(x+(302 if inside else 0),632,296,174),true)
  b.type = "police_department"
  label_at("POLICE / exterior and station interior",Vector2(x,825),19)
  for inside in [false,true]:
   picture(locations.setting_for(sim,b,inside),Rect2(x+(302 if inside else 0),857,296,174),true)
 await capture("res://tests/architecture-resource-gallery.png")
 background()
 label_at("MALTON / SEED 1729 / NEIGHBOURHOOD ARCHITECTURE",Vector2(24,12),30)
 var map = MapCanvas.new()
 map.sim = sim
 map.artwork = artwork
 map.footprint = Rect2i(20,20,18,14)
 map.cell = 68
 map.position = Vector2(24,85)
 canvas.add_child(map)
 map.build()
 label_at("Style distribution / same city coordinates",Vector2(1275,90),23)
 var colors = [Color("a5a5a0"),Color("bb7550"),Color("52a8ad")]
 for y in range(14):
  for x in range(18):
   var b = sim.block_at(20+x,20+y)
   var square = ColorRect.new()
   square.position = Vector2(1275+x*32,145+y*32)
   square.size = Vector2(30,30)
   square.color = colors[Architecture.variant_for(sim,b)] if Architecture.eligible(b) else Color("3b453d")
   canvas.add_child(square)
 for i in range(3): label_at(Architecture.STYLES[i],Vector2(1275,640+i*35),22)
 label_at("Small districts with occasional infill buildings.\nResource colours stay consistent in every family.\nUnique properties keep their existing designs.",Vector2(1275,795),20)
 await capture("res://tests/architecture-neighbourhood-gallery.png")
 quit()
