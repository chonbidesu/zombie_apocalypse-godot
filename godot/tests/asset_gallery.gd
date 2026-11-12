extends SceneTree
const C = preload("res://scripts/catalog.gd")
var canvas: Control
func _initialize() -> void:
 run.call_deferred()
func label_at(text: String, at: Vector2, size: Vector2) -> void:
 var node = Label.new()
 node.text = text
 node.position = at
 node.size = size
 node.add_theme_font_size_override("font_size",17)
 node.add_theme_color_override("font_color",Color.WHITE)
 canvas.add_child(node)
func image_at(path: String, bounds: Rect2) -> void:
 var node = TextureRect.new()
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.texture = load(path)
 node.position = bounds.position
 node.size = bounds.size
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 canvas.add_child(node)
func new_canvas() -> void:
 if canvas != null:
  root.remove_child(canvas)
  canvas.queue_free()
 canvas = Control.new()
 root.add_child(canvas)
func run() -> void:
 root.size = Vector2i(1440,960)
 new_canvas()
 var buildings = ["cathedral","mansion","power_station","stadium","armoury","barracks","gatehouse","infirmary","storehouse","vehicle_depot","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]
 for i in range(buildings.size()):
  var key = buildings[i]
  var origin = Vector2(12+(i%4)*356,12+(i/4)*232)
  label_at(C.pretty(key),origin,Vector2(344,24))
  image_at("res://assets/blocks/"+key+".png",Rect2(origin+Vector2(0,30),Vector2(104,104)))
  image_at("res://assets/settings/"+key+"_outside.png",Rect2(origin+Vector2(108,28),Vector2(236,98)))
  image_at("res://assets/settings/"+key+"_inside.png",Rect2(origin+Vector2(108,130),Vector2(236,98)))
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/building_art_gallery.png")
 new_canvas()
 var outdoors = ["wasteland","exercise_yard","training_ground","zoo_ground"]
 for index in range(outdoors.size()):
  var key = outdoors[index]
  var origin = Vector2(18,18+index*230)
  label_at(C.pretty(key),origin,Vector2(250,28))
  image_at("res://assets/blocks/"+key+".png",Rect2(origin+Vector2(0,32),Vector2(180,180)))
  image_at("res://assets/settings/"+key+"_outside.png",Rect2(origin+Vector2(280,0),Vector2(1050,215)))
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/outdoor_art_gallery.png")
 new_canvas()
 var portraits = ["private","medic","scout","necro","doctor","police","firefighter","consumer","corpse"]
 for i in range(portraits.size()):
  var key = portraits[i]
  label_at(C.pretty(key),Vector2(20,18+i*104),Vector2(180,94))
  var texture = load("res://assets/portraits/"+key+".png")
  var cell = Vector2(texture.get_width()/5.0,texture.get_height()/5.0)
  var frames = [0,5,10,15,16,20,24]
  for j in range(frames.size()):
   var frame = frames[j]
   var atlas = AtlasTexture.new()
   atlas.atlas = texture
   atlas.region = Rect2(Vector2(frame%5,frame/5)*cell,cell)
   var view = TextureRect.new()
   view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   view.texture = atlas
   view.position = Vector2(210+j*154,14+i*104)
   view.size = Vector2(100,100)
   view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
   view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   canvas.add_child(view)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/portrait_art_gallery.png")
 new_canvas()
 var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/content-expansion-manifest.json"))
 var i = 0
 for asset in manifest.assets:
  if asset.type != "item": continue
  var origin = Vector2(16+(i%8)*176,16+(i/8)*218)
  image_at("res://assets/items/"+asset.key+".png",Rect2(origin,Vector2(150,160)))
  label_at(C.pretty(asset.key),origin+Vector2(0,164),Vector2(176,48))
  i += 1
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/item_art_gallery.png")
 print("ASSET GALLERY: 90 generated assets rendered")
 quit()
