extends SceneTree
const C = preload("res://scripts/catalog.gd")
const JOBS = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse"]
var canvas: Control

func _initialize() -> void:
 run.call_deferred()

func label_at(value: String, at: Vector2, font_size: int = 17) -> void:
 var label = Label.new()
 label.text = value
 label.position = at
 label.add_theme_font_size_override("font_size",font_size)
 canvas.add_child(label)

func frame_at(path: String, columns: int, rows: int, frame: int, at: Vector2, size: Vector2) -> void:
 var source: Texture2D = load(path)
 var cell = Vector2(source.get_width()/float(columns),source.get_height()/float(rows))
 var atlas = AtlasTexture.new()
 atlas.atlas = source
 atlas.region = Rect2(Vector2(frame%columns,frame/columns)*cell,cell)
 var sprite = TextureRect.new()
 sprite.texture = atlas
 sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 sprite.position = at
 sprite.size = size
 sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 canvas.add_child(sprite)

func run() -> void:
 root.size = Vector2i(1600,1150)
 root.content_scale_size = Vector2i(1600,1150)
 canvas = Control.new()
 root.add_child(canvas)
 label_at("NPC cast — both sexes in every occupation",Vector2(24,8),25)
 label_at("MALE: portrait / walk / attack / fallen",Vector2(300,43))
 label_at("FEMALE: portrait / walk / attack / fallen",Vector2(940,43))
 for i in JOBS.size():
  var job: String = JOBS[i]
  var y = 82+i*116
  label_at(job,Vector2(18,y+38),16)
  for index in 2:
   var sex = ["male","female"][index]
   var x = 265+index*650
   frame_at("res://assets/portraits/"+C.occupation_portrait(job,sex)+".png",5,5,0,Vector2(x,y),Vector2(100,100))
   var sheet = "res://assets/sprite_sheets/"+C.occupation_sheet(job,job != "Corpse",sex)+"_sprite_sheet.png"
   for pose in 3:
    frame_at(sheet,6,4,[0,10,20][pose],Vector2(x+120+pose*140,y-4),Vector2(112,112))
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/npc-sex-gallery.png")
 print("Saved NPC sex art gallery")
 quit()
