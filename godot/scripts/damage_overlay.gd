extends Control
## Cosmetic effects use their own RNG and never affect the simulation.
const LIFETIME = 4.5
var rng := RandomNumberGenerator.new()
var splashes: Array[Dictionary] = []

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 rng.randomize()

func add_damage(amount: int, human: bool) -> void:
 var spots: Array = []
 for i in range(clampi(5+amount/3,5,12)):
  var center = Vector2(rng.randf_range(0.04,0.96),rng.randf_range(0.05,0.95))
  var radius = rng.randf_range(9.0,37.0) * (1.0 if i > 1 else 1.6)
  var points = PackedVector2Array()
  var count = rng.randi_range(11,19)
  var stretch = Vector2(rng.randf_range(0.65,1.5),rng.randf_range(0.65,1.5))
  for j in range(count):
   var angle = TAU*j/count
   var length = radius*rng.randf_range(0.55,1.35)
   points.append(Vector2(cos(angle)*stretch.x,sin(angle)*stretch.y)*length)
  var drops: Array = []
  for j in range(rng.randi_range(3,8)):
   var angle = rng.randf_range(0,TAU)
   drops.append({"offset":Vector2(cos(angle),sin(angle))*rng.randf_range(radius*0.8,radius*2.2),"radius":rng.randf_range(2.0,8.0)})
  spots.append({"center":center,"points":points,"drops":drops})
 splashes.append({"spots":spots,"age":0.0,"human":human})
 if splashes.size() > 8: splashes.pop_front()
 queue_redraw()

func _process(delta: float) -> void:
 if splashes.is_empty(): return
 for splash in splashes: splash.age += delta
 splashes = splashes.filter(func(splash): return splash.age < LIFETIME)
 queue_redraw()

func _draw() -> void:
 for splash in splashes:
  var alpha = 0.72*pow(1.0-clampf(splash.age/LIFETIME,0.0,1.0),1.3)
  var color = Color(0.55,0.025,0.018,alpha) if splash.human else Color(0.19,0.008,0.012,alpha)
  for spot in splash.spots:
   var center = spot.center*size
   var polygon = PackedVector2Array()
   for point in spot.points: polygon.append(center+point)
   draw_colored_polygon(polygon,color)
   for drop in spot.drops: draw_circle(center+drop.offset,drop.radius,color)
