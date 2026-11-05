extends Control
## A single clipped city scene. All terrain is below all cast shadows; roofs,
## neighboring squares and elevated perimeter segments are ordered by depth.
const Ground = preload("res://scripts/minimap_ground.gd")
const Shadow = preload("res://scripts/minimap_shadow.gd")
var sim
var artwork
var footprint: Rect2i
var cell = 106.0
var discovered_only = false
var tiles: Dictionary = {}

func projected_rect(b: Dictionary) -> Rect2:
 var plot: Rect2i = artwork.footprint_for(sim,b)
 var property: Dictionary = artwork.property_info(sim,b)
 var full = Rect2(Vector2(plot.position-footprint.position)*cell,Vector2(plot.size)*cell)
 if not property.is_empty():
  full = full.grow(-cell*0.045)
 else:
  var tall = b.type in ["tower","hotel"]
  var rise = cell*(0.14 if tall else 0.045)
  full.position += Vector2(cell*0.055,-rise)
  full.size += Vector2(-cell*0.11,rise-cell*0.055)
  if b.type in ["street","carpark","park","cemetery","wasteland","exercise_yard","training_ground","zoo_ground"]:
   full = Rect2(Vector2(plot.position-footprint.position)*cell+Vector2.ONE*cell*0.025,Vector2(plot.size)*cell-Vector2.ONE*cell*0.05)
 var offset = Vector2(Vector2i(b.x,b.y)-plot.position)/Vector2(plot.size)
 return Rect2(full.position+offset*full.size,full.size/Vector2(plot.size))

func build() -> void:
 clip_contents = true
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 size = Vector2(footprint.size)*cell
 # Include a one-square halo: a building outside the view can still project its
 # roof or shadow into a visible street. The viewport alone clips the scene.
 var view = footprint.grow(1).intersection(Rect2i(0,0,sim.width,sim.height))
 var shadowed = {}
 for y in range(view.position.y,view.end.y):
  for x in range(view.position.x,view.end.x):
   var b = sim.block_at(x,y)
   if discovered_only and not b.known: continue
   var at = Vector2(Vector2i(x,y)-footprint.position)*cell
   var ground = Ground.new()
   ground.sim = sim
   ground.block = b
   ground.position = at
   ground.size = Vector2.ONE*cell
   ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
   add_child(ground)
   var tile = Control.new()
   tile.name = "Plot_%d" % b.id
   tile.position = at
   tile.size = Vector2.ONE*cell
   tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
   add_child(tile)
   tiles[b.id] = tile
   var bounds = projected_rect(b)
   var art = TextureRect.new()
   art.name = "MapArt"
   art.texture = artwork.texture_for(sim,b)
   art.material = artwork.material_for(sim,b)
   art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   art.stretch_mode = TextureRect.STRETCH_SCALE
   art.position = bounds.position-at
   art.size = bounds.size
   art.mouse_filter = Control.MOUSE_FILTER_IGNORE
   art.z_index = 100+(y-view.position.y)*20+10
   tile.add_child(art)
   var property: Dictionary = artwork.property_info(sim,b)
   if property.is_empty() and b.type not in ["street","wasteland","carpark","exercise_yard","training_ground","zoo_ground"]:
    var plot: Rect2i = artwork.footprint_for(sim,b)
    var key = str(plot)
    if not shadowed.has(key):
     shadowed[key] = true
     var texture: AtlasTexture = artwork.texture_for(sim,b,0)
     var shadow = Shadow.new()
     shadow.texture = texture.atlas
     var part_size = bounds.size
     shadow.position = bounds.position-Vector2(Vector2i(x,y)-plot.position)*part_size
     shadow.size = part_size*Vector2(plot.size)
     shadow.z_index = 5
     shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
     add_child(shadow)
   if not b.fort.is_empty() or not b.zoo.is_empty():
    for front in [false,true]:
     var wall = Ground.new()
     wall.sim = sim
     wall.block = b
     wall.foreground = true
     wall.front_faces = front
     wall.position = at
     wall.size = Vector2.ONE*cell
     wall.z_index = 100+(y-view.position.y)*20+(19 if front else 1)
     wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
     add_child(wall)
