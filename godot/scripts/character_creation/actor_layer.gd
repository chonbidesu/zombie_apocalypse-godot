extends Node2D
## Registered idle and confirmation drawings, with a matching projected shadow.
var visual: AnimatedSprite2D
var group: int
var slot: int
var idle_time: float = 0.0
var action_time: float = -1.0
# Alpha bitmaps are only for hit testing and shadow contacts, never art repair.
var masks: Array[BitMap] = []
const ContactShadow = preload("res://scripts/character_creation/contact_shadow.gd")
var shadow: ContactShadow
var registered_offset: Vector2
const STRUGGLE = [0,0,0,1,2,1,3,0,0,2,1,3]
const BREATHE = [0,1,2,3,2,1]
const ACTION_HOLDS = [
 [0.25,0.35,0.55,0.40,0.20,0.09,0.15,0.70],
 [0.30,0.25,0.25,0.20,0.40,0.25,0.30,0.80],
 [0.30,0.30,0.30,0.30,0.20,0.20,0.30,0.80],
 [0.30,0.30,0.30,0.20,0.25,0.30,0.35,0.70],
 [0.35,0.35,0.35,0.30,0.40,0.15,0.25,0.60],
 [0.30,0.35,0.10,0.08,0.10,0.12,0.20,0.80],
 [0.30,0.30,0.25,0.15,0.35,0.30,0.30,0.70],
 [0.30,0.30,0.25,0.20,0.15,0.25,0.30,0.75],
 [0.40,0.45,0.40,0.40,0.30,0.30,0.40,0.80]
]

func setup(sheet: Texture2D, bounds: Rect2, group_index: int, index: int, shadow_parent: Node2D) -> void:
 group = group_index
 slot = index
 visual = AnimatedSprite2D.new()
 visual.centered = false
 add_child(visual)
 set_sheet(sheet)
 var cell := Vector2(sheet.get_width()/4.0,sheet.get_height()/3.0)
 registered_offset = Vector2(-cell.x/2.0,-mask_bottom(masks[0]))
 position = bounds.position+Vector2(bounds.size.x/2.0,bounds.size.y)
 scale = Vector2.ONE*(bounds.size.x/cell.x if slot == 8 else bounds.size.y/cell.y)
 visual.position = registered_offset
 shadow = ContactShadow.new()
 shadow.setup(slot,group,position,scale,registered_offset)
 shadow_parent.add_child(shadow)

func set_sheet(sheet: Texture2D) -> void:
 # Swap drawings and hit masks together, preserving the room's registered
 # placement, animation timings and existing shadow node.
 var cell := Vector2(sheet.get_width()/4.0,sheet.get_height()/3.0)
 masks.clear()
 var frames := SpriteFrames.new()
 frames.remove_animation("default")
 frames.add_animation("idle")
 frames.add_animation("choice")
 frames.set_animation_loop("choice",false)
 var pixels := sheet.get_image()
 for i in range(12):
  var atlas := AtlasTexture.new()
  atlas.atlas = sheet
  atlas.region = Rect2(Vector2(i%4,i/4)*cell,cell)
  atlas.filter_clip = true
  var mask := BitMap.new()
  mask.create_from_image_alpha(pixels.get_region(Rect2i(atlas.region)),0.45)
  masks.append(mask)
  frames.add_frame("idle" if i < 4 else "choice",atlas)
 visual.sprite_frames = frames
 if is_instance_valid(shadow):
  shadow.last_frame = null
 reset()

func tick(delta: float, intensity: float) -> void:
 visual.modulate = Color(0.045,0.055,0.07).lerp(Color(1.10,1.02,0.87),intensity)
 if action_time >= 0.0:
  action_time += delta
  visual.animation = "choice"
  visual.frame = choice_frame(action_time)
 elif intensity>0.1:
  idle_time += delta
  visual.animation = "idle"
  if slot==8:
   # A sudden kick, a second shove, and a long motionless hold.
   visual.frame = STRUGGLE[int(idle_time*6.0)%STRUGGLE.size()]
  else:
   visual.frame = BREATHE[int(idle_time*2.4+slot)%BREATHE.size()]
 else:
  visual.animation = "idle"
  visual.frame = 0

 var index := visual.frame+(4 if action_time>=0 else 0)
 if intensity>0.01:
  var shadow_frame := visual.sprite_frames.get_frame_texture(visual.animation,visual.frame) as AtlasTexture
  shadow.set_pose(shadow_frame,masks[index])
 shadow.modulate.a = intensity
 shadow.visible = intensity>0.01

func begin_choice() -> void:
 action_time = 0.0

func reset() -> void:
 action_time = -1.0
 idle_time = 0.0
 visual.animation = "idle"
 visual.frame = 0

func choice_frame(time: float) -> int:
 var boundary: float = 0.0
 for i in range(8):
  boundary += ACTION_HOLDS[slot][i]
  if time < boundary: return i
 return 7

func contains_point(point: Vector2) -> bool:
 var local := transform.affine_inverse()*point-visual.position
 var absolute_frame := visual.frame+(4 if visual.animation=="choice" else 0)
 var mask := masks[absolute_frame]
 var pixel := Vector2i(local)
 return local.x>=0 and local.y>=0 and pixel.x<mask.get_size().x and pixel.y<mask.get_size().y and mask.get_bitv(pixel)

func mask_bottom(mask: BitMap) -> int:
 for y in range(mask.get_size().y-1,-1,-1):
  for x in range(mask.get_size().x):
   if mask.get_bit(x,y): return y+1
 return mask.get_size().y

