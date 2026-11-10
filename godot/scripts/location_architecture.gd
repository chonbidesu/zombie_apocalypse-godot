extends RefCounted
## Cosmetic, seed-stable neighbourhoods. Never consumes the simulation RNG.
const GROUPS = [
 ["fire_station","police_department","hospital"],
 ["library","church","warehouse"],
 ["auto_repair","factory","school"],
 ["office","junkyard","museum"],
 ["nightclub","pub","bank"],
 ["cinema","hotel","railway_station"],
 ["tower","park","cemetery"],
 ["monument","carpark","wasteland"]
]
const STYLES = ["Stone civic","Brick heritage","Deco and modern"]
const OPEN_GROUND = ["park","cemetery","monument","carpark","wasteland","street"]
var textures: Dictionary = {}
var scenes: Dictionary = {}

static func canonical_kind(kind: String) -> String:
 return "office" if kind == "necrotech_lab" else kind

static func group_for(kind: String) -> int:
 kind = canonical_kind(kind)
 for i in range(GROUPS.size()):
  if kind in GROUPS[i]: return i
 return -1

static func eligible(b: Dictionary) -> bool:
 return (group_for(b.type) >= 0 or b.type == "street") and b.get("complex","").is_empty() and b.get("fort","").is_empty() and b.get("zoo","").is_empty()

static func noise(seed_value: int, x: int, y: int, salt: String) -> int:
 # Avalanche the string hash so consecutive coordinates do not create stripes
 # or diagonal lines of infill when reduced modulo the three style choices.
 var value = int(("%d:%d:%d:%s" % [seed_value,x,y,salt]).hash())
 value = ((value ^ (value >> 16))*0x45d9f3b) & 0xffffffff
 value = ((value ^ (value >> 16))*0x45d9f3b) & 0xffffffff
 return value ^ (value >> 16)

static func district_style(seed_value: int, x: int, y: int) -> int:
 # Jittered six-block Voronoi districts avoid rigid checkerboard boundaries.
 var cell = Vector2i(floori(x/6.0),floori(y/6.0))
 var nearest = INF
 var result = 0
 for dy in range(-1,2):
  for dx in range(-1,2):
   var at = cell+Vector2i(dx,dy)
   var center = Vector2(at*6)+Vector2(1+noise(seed_value,at.x,at.y,"cx")%4,1+noise(seed_value,at.x,at.y,"cy")%4)
   var distance = center.distance_squared_to(Vector2(x,y))
   if distance < nearest:
    nearest = distance
    result = noise(seed_value,at.x,at.y,"style")%3
 return result

static func variant_for(sim, b: Dictionary) -> int:
 if not eligible(b): return 0
 var style = district_style(sim.world_seed,b.x,b.y)
 # A small number of infill/redevelopment sites break up uniform districts.
 var local = noise(sim.world_seed,b.x,b.y,"infill")
 if local%11 == 0: style = (style+1+local%2)%3
 return style

static func map_source(kind: String, variant: int, status: int) -> Dictionary:
 var group = group_for(kind)
 if group < 0 or (variant == 0 and group != 0): return {}
 return {"file":"../architecture/map-%d-%d" % [variant,group],"grid":Vector2i(4,3),"at":Vector2i(status,GROUPS[group].find(canonical_kind(kind))),"architecture":true}

func setting_for(sim, b: Dictionary, inside: bool) -> Texture2D:
 if b.type in OPEN_GROUND: inside = false
 var variant = variant_for(sim,b)
 if variant > 0 and ((b.type == "necrotech_lab" and inside) or b.type == "street"):
  var special_key = "%s:%d" % [b.type,variant]
  if scenes.has(special_key): return scenes[special_key]
  var special_path = "res://assets/architecture/settings-%d-extra.png" % variant
  if not textures.has(special_path): textures[special_path] = load(special_path)
  var special = AtlasTexture.new()
  special.atlas = textures[special_path]
  var special_cell = Vector2(special.atlas.get_size())/Vector2(1,2)
  special.region = Rect2(Vector2(0,1 if b.type == "street" else 0)*special_cell,special_cell)
  special.filter_clip = true
  scenes[special_key] = special
  return special
 var kind: String = canonical_kind(b.type)
 var group = group_for(kind)
 if (variant == 0 and group != 0) or group < 0:
  var legacy_kind: String = b.type if inside else kind
  if legacy_kind in OPEN_GROUND: inside = false
  var path = "res://assets/settings/%s_%s.png" % [legacy_kind,"inside" if inside else "outside"]
  if not textures.has(path): textures[path] = load(path)
  return textures[path]
 var key = "%s:%d:%s" % [kind,variant,str(inside)]
 if scenes.has(key): return scenes[key]
 var path = "res://assets/architecture/settings-%d-%d.png" % [variant,group]
 if not textures.has(path): textures[path] = load(path)
 var atlas = AtlasTexture.new()
 atlas.atlas = textures[path]
 var cell = Vector2(atlas.atlas.get_size())/Vector2(2,3)
 atlas.region = Rect2(Vector2(1 if inside else 0,GROUPS[group].find(kind))*cell,cell)
 atlas.filter_clip = true
 scenes[key] = atlas
 return atlas
