extends Control
## Roads are drawn at a fixed position on both sides of every shared edge.
## Interior complex edges become continuous roofs/grounds, never roads.
var sim
var block: Dictionary
var foreground = false
var front_faces = true
static var surfaces: Array = []
const DIRS = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

func _init() -> void:
 texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

static func surface(index: int) -> Texture2D:
 if surfaces.is_empty():
  var image = (load("res://assets/minimap/materials.png") as Texture2D).get_image()
  var cell = Vector2(image.get_size())/Vector2(3,2)
  for i in range(6):
   var start = Vector2i(Vector2(i%3,i/3)*cell)
   var end = Vector2i(Vector2(i%3+1,i/3+1)*cell)
   var part = image.get_region(Rect2i(start,end-start))
   part.resize(256,256,Image.INTERPOLATE_LANCZOS)
   surfaces.append(ImageTexture.create_from_image(part))
 return surfaces[index]

func plot_polygon(inset: float = 0.0) -> PackedVector2Array:
 var exposed: Array[bool] = []
 for direction in DIRS: exposed.append(not joined(direction))
 var left = 12.0+inset if exposed[3] else 0.0
 var top = 12.0+inset if exposed[0] else 0.0
 var right = 244.0-inset if exposed[1] else 256.0
 var bottom = 244.0-inset if exposed[2] else 256.0
 var corners = [Vector2(left,top),Vector2(right,top),Vector2(right,bottom),Vector2(left,bottom)]
 var points = PackedVector2Array()
 for i in range(4):
  var radius = 15.0-inset if exposed[i] and exposed[(i+3)%4] else 0.0
  if radius == 0:
   points.append(corners[i])
   continue
  var center: Vector2 = corners[i]+[Vector2(radius,radius),Vector2(-radius,radius),Vector2(-radius,-radius),Vector2(radius,-radius)][i]
  for step in range(9):
   var angle = deg_to_rad(180+i*90+step*90.0/8)
   points.append(center+Vector2(cos(angle),sin(angle))*radius)
 return points

func textured_polygon(points: PackedVector2Array, texture: Texture2D) -> void:
 var uv = PackedVector2Array()
 for point in points: uv.append(point/64.0)
 draw_polygon(points,PackedColorArray([Color.WHITE]),uv,texture)

func neighbor(direction: Vector2i) -> Dictionary:
 var x = int(block.x)+direction.x
 var y = int(block.y)+direction.y
 if x < 0 or y < 0 or x >= sim.width or y >= sim.height: return {}
 return sim.block_at(x,y)

func joined(direction: Vector2i) -> bool:
 var other = neighbor(direction)
 if other.is_empty(): return false
 if not block.fort.is_empty(): return block.fort == other.fort
 return not block.complex.is_empty() and block.complex == other.complex

func _draw() -> void:
 if block.is_empty(): return
 draw_set_transform(Vector2.ZERO,0,size/Vector2(256,256))
 if foreground:
  _perimeter()
  return
 var zoo = not block.zoo.is_empty()
 var fort = not block.fort.is_empty()
 draw_texture_rect(surface(0),Rect2(0,0,256,256),false,Color(1.10,1.08,1.03))
 draw_colored_polygon(plot_polygon(),Color("9d967e"))
 var terrain = 2 if zoo or block.type in ["park","cemetery"] else (3 if fort else (5 if block.type == "wasteland" else 1))
 textured_polygon(plot_polygon(1.3),surface(terrain))
 # Sidewalks have one continuous curb; corners meet at the road intersection.
 for side in range(4):
  if joined(DIRS[side]): continue
  if side in [1,2]: continue
  for step in range(38,224,30):
   var horizontal = side%2 == 0
   var at = Vector2(step,0) if horizontal else Vector2(0,step)
   draw_rect(Rect2(at,Vector2(13,2.4) if horizontal else Vector2(2.4,13)),Color("b5ac91"))
 if zoo or fort:
  # Walkways meet exactly at the middle of every neighboring compound square.
  var path_color = Color("8b8465") if zoo else Color("777565")
  draw_rect(Rect2(121,28,14,200),path_color)
  draw_rect(Rect2(28,121,200,14),path_color)
  for side in range(4):
   if joined(DIRS[side]):
    match side:
     0: draw_rect(Rect2(121,0,14,40),path_color)
     1: draw_rect(Rect2(216,121,40,14),path_color)
     2: draw_rect(Rect2(121,216,14,40),path_color)
     3: draw_rect(Rect2(0,121,40,14),path_color)
 if block.type == "street":
  var variant = int(("%d,%d" % [block.x,block.y]).hash()%6)
  textured_polygon(PackedVector2Array([Vector2(0,105),Vector2(256,105),Vector2(256,151),Vector2(0,151)]),surface(0))
  draw_line(Vector2(0,103),Vector2(256,103),Color("aaa58b"),3)
  draw_line(Vector2(0,153),Vector2(256,153),Color("aaa58b"),3)
  for x in range(24,240,30): draw_line(Vector2(x,128),Vector2(x+13,128),Color("b5b09a"),2)
  if variant in [2,3,5]:
   draw_rect(Rect2(108,0,40,256 if variant == 5 else 128),Color("42453f"))

func _perimeter() -> void:
 if block.fort.is_empty() and block.zoo.is_empty(): return
 var fort = not block.fort.is_empty()
 var creedy = "Creedy" in block.fort
 for side in range(4):
  if joined(DIRS[side]): continue
  if fort and block.type == "gatehouse" and side == 1:
   # The rear/north jamb is behind the gatehouse; the south jamb is in front.
   # No visible arch: the east-west passage is occluded by the foreground tower.
   _wall_segment(side,224 if front_faces else 0,256 if front_faces else 160,44.0,creedy,true)
   _east_gate_return(front_faces,creedy)
   continue
  if (side == 0) == front_faces: continue
  var gate = fort and block.type == "gatehouse"
  # East-facing doors project down from their roof footprint in this camera.
  # Match the passage at ground level, rather than centering a slit on its roof.
  var opening = Vector2(160,224) if side == 1 else Vector2(96,160)
  var spans = [Vector2(0,opening.x),Vector2(opening.y,256)] if gate else [Vector2(0,256)]
  for span in spans:
   _wall_segment(side,span.x,span.y,44.0 if fort else 9.0,creedy,fort)
  if gate:
   _gatehouse_jambs(side,creedy)

func _east_gate_return(front: bool, creedy: bool) -> void:
 var y = 224.0 if front else 160.0
 var color = Color("686c63") if creedy else Color("78614b")
 var cap = Color("b1ad96") if creedy else Color("b29c77")
 draw_colored_polygon(PackedVector2Array([Vector2(214,y-44),Vector2(241,y-44),Vector2(241,y),Vector2(214,y)]),color)
 draw_colored_polygon(PackedVector2Array([Vector2(214,y-44),Vector2(241,y-44),Vector2(238,y-50),Vector2(211,y-50)]),cap)
 for row in range(6,44,6): draw_line(Vector2(214,y-row),Vector2(241,y-row),color.darkened(0.2),1)

func _gatehouse_jambs(side: int, creedy: bool) -> void:
 # Short bonded returns join the perimeter to the gatehouse's actual doorway
 # jambs. The corridor ends inside the gatehouse rather than beside it.
 var color = Color("74776b") if creedy else Color("8b7154")
 var cap = Color("aaa58e") if creedy else Color("b39b76")
 if side == 2 or side == 0:
  var y = 241.0 if side == 2 else 15.0
  for x in [96.0,160.0]:
   draw_rect(Rect2(x-2,y-60,4,60),color)
   draw_rect(Rect2(x-3,y-60,6,16),cap)
 elif side == 1 or side == 3:
  var x = 241.0 if side == 1 else 15.0
  for y in ([160.0,224.0] if side == 1 else [96.0,160.0]):
   draw_rect(Rect2(x-6,y-44,6,44),color)
   draw_rect(Rect2(x-6,y-47,6,3),cap)

func _wall_segment(side: int, start: float, finish: float, height: float, creedy: bool, fort: bool) -> void:
 var color = Color("686c63") if creedy else Color("78614b")
 var cap = Color("b1ad96") if creedy else Color("b29c77")
 if not fort: color = Color("3c4934"); cap = Color("85856b")
 var width = 6.0 if fort else 2.0
 if side%2 == 0:
  var y = 15.0 if side == 0 else 241.0
  if start == 0 and not joined(Vector2i.LEFT): start = 15
  if finish == 256 and not joined(Vector2i.RIGHT): finish = 241
  var face = Rect2(start,y-height,finish-start,height)
  draw_colored_polygon(PackedVector2Array([Vector2(start,y),Vector2(finish,y),Vector2(finish+18,y+7),Vector2(start+18,y+7)]),Color(0,0,0,0.27))
  draw_rect(face,color)
  if fort:
   for row in range(6,int(height),6):
    draw_line(Vector2(start,y-row),Vector2(finish,y-row),color.darkened(0.23),1)
    for x in range(int(start)+((row/6)%2)*10,int(finish),20): draw_line(Vector2(x,y-row),Vector2(x,y-row+5),color.darkened(0.2),1)
  draw_colored_polygon(PackedVector2Array([Vector2(start,y-height),Vector2(finish,y-height),Vector2(finish-3,y-height-width),Vector2(start-3,y-height-width)]),cap)
  draw_line(Vector2(start,y-height-width),Vector2(finish,y-height-width),cap.lightened(0.12),1.2)
  for x in range(int(start)+6,int(finish),22 if creedy else 28):
   draw_rect(Rect2(x,y-height-3,3,height+3),color.lightened(0.1))
   if fort:
    draw_line(Vector2(x,y-height-7),Vector2(x+13,y-height-5),Color("535c4b"),1)
    draw_line(Vector2(x+6,y-height-8),Vector2(x+8,y-height-3),Color("8e947d"),1)
 else:
  var x = 15.0 if side == 3 else 241.0
  if start == 0 and not joined(Vector2i.UP): start = 15
  if finish == 256 and not joined(Vector2i.DOWN): finish = 241
  draw_colored_polygon(PackedVector2Array([Vector2(x,start),Vector2(x,finish),Vector2(x+17,finish+7),Vector2(x+17,start+7)]),Color(0,0,0,0.25))
  draw_colored_polygon(PackedVector2Array([Vector2(x+width,start-height),Vector2(x+width,finish-height),Vector2(x+width+4,finish),Vector2(x+width+4,start)]),color.darkened(0.12))
  draw_rect(Rect2(x,start-height,width,finish-start),cap)
  for y in range(int(start)+4,int(finish),22 if creedy else 28):
   draw_rect(Rect2(x-1,y-height, width+2,3),cap.lightened(0.12))
   if fort: draw_line(Vector2(x+2,y-height-4),Vector2(x+3,y-height+8),Color("545e4d"),1)
