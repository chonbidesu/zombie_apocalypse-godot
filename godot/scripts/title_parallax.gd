extends Control
## Original Python layers and 60 FPS speeds, now driven by elapsed seconds.
const REFERENCE_HEIGHT = 800.0
const SPEEDS: Array[float] = [6.0, 15.0, 30.0, 60.0, 90.0]
const LAYERS: Array[Texture2D] = [
 preload("res://assets/parallax/title_layer_1.png"),
 preload("res://assets/parallax/title_layer_2.png"),
 preload("res://assets/parallax/title_layer_3.png"),
 preload("res://assets/parallax/title_layer_4.png"),
 preload("res://assets/parallax/title_layer_5.png")
]
var offsets: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var layer_widths: Array[float] = []

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 for layer in LAYERS:
  layer_widths.append(layer.get_width()*REFERENCE_HEIGHT/layer.get_height())
 resized.connect(queue_redraw)

func _process(delta: float) -> void:
 for i in range(LAYERS.size()):
  # Store travel in the Python screen's 800-pixel height coordinate system.
  offsets[i] = fposmod(offsets[i]+SPEEDS[i]*delta,layer_widths[i])
 queue_redraw()

func _draw() -> void:
 if size.y <= 0: return
 var zoom := size.y/REFERENCE_HEIGHT
 for i in range(LAYERS.size()):
  var width := layer_widths[i]*zoom
  var x := -offsets[i]*zoom
  while x < size.x:
   draw_texture_rect(LAYERS[i],Rect2(x,0,width,size.y),false)
   x += width
