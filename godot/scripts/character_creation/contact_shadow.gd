extends MeshInstance2D
## Project each atlas silhouette onto the floor from its group's point light.
## The foot profile interpolates the actual shoe, chair-leg and wheel contacts.
const SUPPORTS = [
 [0.40,0.56,0.74],[0.21,0.43,0.68],[0.32,0.48,0.76],
 [0.43,0.74],[0.18,0.25,0.80],[0.11,0.29,0.85],[0.22,0.57,0.80],
 [0.43,0.58],[0.09,0.24,0.83]
]
# Visible sole and wheel contacts. Rear wheels sit higher in the drawing than
# front wheels; sampling only the globally lowest row misses them entirely.
const CONTACTS = [
 [0.42,0.52], [0.42,0.50], [], [0.43,0.51], [0.18,0.25,0.80],
 [0.11,0.29,0.85], [0.52,0.77], [0.42,0.58], [0.09,0.24,0.83]
]
# The fourth caster is hidden behind each frame, so it has no opaque pixels
# to sample. Its floor position follows the perspective of the visible three.
const HIDDEN_WHEEL = {4: Vector2(.73,.81), 8: Vector2(.68,.56)}
const LIGHT_FLOOR = [Vector2(385,350),Vector2(836,360),Vector2(1388,350),Vector2(1137,645)]
const LAMP_HEIGHT = 950.0
var last_frame: AtlasTexture
var origin: Vector2
var sprite_scale: Vector2
var offset: Vector2
var slot: int
var group: int
const FloorContacts = preload("res://scripts/character_creation/floor_contacts.gd")
var contacts: FloorContacts

func setup(index: int, light_group: int, floor_origin: Vector2, sprite_factor: Vector2, sprite_offset: Vector2) -> void:
 slot = index
 group = light_group
 origin = floor_origin
 sprite_scale = sprite_factor
 offset = sprite_offset
 z_index = -1
 material = ShaderMaterial.new()
 material.shader = preload("res://scripts/character_creation/cast_shadow.gdshader")
 contacts = FloorContacts.new()
 add_child(contacts)

func set_pose(frame: AtlasTexture, mask: BitMap) -> void:
 if frame == last_frame: return
 last_frame = frame
 var size := Vector2(mask.get_size())
 var columns: Array[Vector2] = []
 var points: Array[Vector2] = []
 for fraction in CONTACTS[slot]:
  var x := int(size.x*fraction)
  for y in range(int(size.y)-1,-1,-1):
   if mask.get_bit(x,y):
    var heel_lift := size.y*.018 if slot in [0,1,3,6,7] else 0.0
    points.append(origin+(offset+Vector2(x,y+1-heel_lift))*sprite_scale)
    break
 if HIDDEN_WHEEL.has(slot):
  points.append(origin+(offset+HIDDEN_WHEEL[slot]*size)*sprite_scale)
 contacts.set_contacts(points, sprite_scale.x*size.x*(.032 if slot in [4,8] else .045))
 for fraction in SUPPORTS[slot]:
  var x := int(size.x*fraction)
  for y in range(int(size.y)-1,-1,-1):
   if mask.get_bit(x,y):
    var heel_lift := size.y*.018 if slot in [0,1,3,6,7] else 0.0
    columns.append(Vector2(x,y+1-heel_lift))
    break
 if HIDDEN_WHEEL.has(slot):
  # Also anchor the projected mesh there, not just the soft contact patch.
  columns.append(HIDDEN_WHEEL[slot]*size)
  columns.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
 if columns.is_empty(): return
 columns.push_front(Vector2(0,columns[0].y))
 columns.append(Vector2(size.x,columns.back().y))
 var verts := PackedVector3Array()
 var uvs := PackedVector2Array()
 var indices := PackedInt32Array()
 # Ground height varies across a three-quarter-view chair or stretcher. A
 # single flipped sprite can only attach to one wheel; this mesh pins them all.
 for col in range(columns.size()):
  var support := columns[col]
  var foot := origin+(offset+support)*sprite_scale
  for row in range(9):
   var sy := lerpf(0.0,support.y,row/8.0)
   var h := (support.y-sy)*sprite_scale.y
   var lamp: Vector2 = LIGHT_FLOOR[group]
   var point := foot+(foot-lamp)*h/(LAMP_HEIGHT-h)
   verts.append(Vector3(point.x,point.y,0))
   uvs.append((frame.region.position+Vector2(support.x,sy))/Vector2(frame.atlas.get_size()))
   if col>0 and row>0:
    var i := verts.size()-1
    indices.append_array([i-10,i-9,i,i-10,i,i-1])
 var arrays = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = verts
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 arrays[Mesh.ARRAY_INDEX] = indices
 var shape := ArrayMesh.new()
 shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh = shape
 texture = frame.atlas
