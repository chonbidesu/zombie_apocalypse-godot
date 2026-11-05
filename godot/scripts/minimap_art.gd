extends RefCounted
## Shared, padded architectural models. Complexes sample one model in world space;
## state selection belongs to each square, never to the whole complex.
const GROUPS = [
 ["fire_station","police_department","hospital","library","church","warehouse"],
 ["auto_repair","factory","school","office","junkyard","museum"],
 ["nightclub","pub","bank","cinema","hotel","railway_station"],
 ["tower","cathedral","mansion","power_station","stadium","mall"],
 ["armoury","barracks","gatehouse","infirmary","storehouse","vehicle_depot"],
 ["aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]
]
const OUTDOORS = ["park","cemetery","monument","carpark","wasteland","exercise_yard","training_ground","zoo_ground"]
var models: Dictionary = {}
var regions: Dictionary = {}
var sheets: Dictionary = {}
var materials: Dictionary = {}
var property_regions: Dictionary = {}
var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/complex-plans.json")).plans

func property_info(sim, b: Dictionary) -> Dictionary:
 if b.fort.is_empty() and b.zoo.is_empty(): return {}
 var identity: String = b.fort if not b.fort.is_empty() else b.zoo
 var key = "%s:%d:%d:%d:%s:%s" % [sim.world_mode,sim.world_seed,sim.width,sim.height,identity,sim.blocks[0].name]
 if property_regions.has(key): return property_regions[key]
 var cells = {}
 var pending = [Vector2i(b.x,b.y)]
 var at_min = Vector2i(b.x,b.y)
 var at_max = at_min
 while not pending.is_empty():
  var at: Vector2i = pending.pop_back()
  if cells.has(at) or at.x < 0 or at.y < 0 or at.x >= sim.width or at.y >= sim.height: continue
  var other = sim.block_at(at.x,at.y)
  if (other.fort if not b.fort.is_empty() else other.zoo) != identity: continue
  cells[at] = other.type
  at_min = at_min.min(at)
  at_max = at_max.max(at)
  for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]: pending.append(at+direction)
 var footprint = Rect2i(at_min,at_max-at_min+Vector2i.ONE)
 var result = {}
 var category: Array = plans.forts if not b.fort.is_empty() else plans.zoos
 for i in range(category.size()):
  var plan: Dictionary = category[i]
  if cells.size() != plan.cells.size() or footprint.size != Vector2i(plan.width,plan.height): continue
  var matches = true
  for part in plan.cells:
   if cells.get(at_min+Vector2i(part.x,part.y),"") != part.type: matches = false
  if matches:
   result = {"kind":"fort_property" if not b.fort.is_empty() else "zoo_property","variant":i,"footprint":footprint}
   break
 property_regions[key] = result
 return result

func footprint_for(sim, b: Dictionary) -> Rect2i:
 var property = property_info(sim,b)
 if not property.is_empty(): return property.footprint
 if not b.complex.is_empty() and b.zoo.is_empty() and sim.complex_bounds.has(b.complex): return sim.complex_bounds[b.complex]
 return Rect2i(Vector2i(b.x,b.y),Vector2i.ONE)

static func stable_variant(value: String, count: int) -> int:
 return int(value.hash() % count)

static func state(sim, b: Dictionary) -> int:
 return 2 if b.ruin >= 3 else (1 if sim.powered(b) else 0)

func source(kind: String, variant: int = 0) -> Dictionary:
 if kind == "fort_property": return {"file":"fort-properties-v4","grid":Vector2i(3,2),"at":Vector2i(0,variant)}
 if kind == "zoo_property": return {"file":"zoo-property-v2","grid":Vector2i(3,1),"at":Vector2i.ZERO}
 if kind == "mall_l": return {"file":"mall-l","grid":Vector2i(3,1),"at":Vector2i.ZERO}
 for i in range(GROUPS.size()):
  if kind in GROUPS[i]:
   if kind == "mall" and variant > 0: return {"file":"malls","grid":Vector2i(3,3),"at":Vector2i(0,variant-1)}
   return {"file":"buildings-%d" % (i+1),"grid":Vector2i(3,6),"at":Vector2i(0,GROUPS[i].find(kind))}
 if kind == "street": return {"file":"streets-v2","grid":Vector2i(3,2),"at":Vector2i(variant%3,variant/3)}
 return {"file":"outdoors","grid":Vector2i(3,3),"at":Vector2i(OUTDOORS.find(kind)%3,OUTDOORS.find(kind)/3)}

func model(kind: String, status: int, variant: int) -> Texture2D:
 var key = "%s:%d:%d" % [kind,status,variant]
 if models.has(key): return models[key]
 var info = source(kind,variant)
 var path = "res://assets/minimap/"+info.file+".png"
 if not sheets.has(path): sheets[path] = load(path) as Texture2D
 var sheet: Texture2D = sheets[path]
 if sheet == null: return null
 var at: Vector2i = info.at
 if kind not in OUTDOORS and kind != "street": at.x = status
 var cell = Vector2(sheet.get_size())/Vector2(info.grid)
 var start = Vector2i(Vector2(at)*cell)
 var end = Vector2i(Vector2(at+Vector2i.ONE)*cell)
 var image = sheet.get_image().get_region(Rect2i(start,end-start))
 # Architecture fills the plot. Height, setbacks and clipping belong to the
 # shared scene, rather than transparent padding inside each gameplay square.
 if kind not in ["fort_property","zoo_property"]:
  var used = image.get_used_rect()
  if status > 0 and kind not in OUTDOORS and kind != "street":
   used = sheet.get_image().get_region(Rect2i(0,start.y,int(cell.x),end.y-start.y)).get_used_rect().intersection(Rect2i(Vector2i.ZERO,image.get_size()))
  if used.has_area(): image = image.get_region(used)
 image.resize(768,768,Image.INTERPOLATE_LANCZOS)
 models[key] = ImageTexture.create_from_image(image)
 return models[key]

func texture_for(sim, b: Dictionary, state_override: int = -1) -> Texture2D:
 var kind: String = "office" if b.type == "necrotech_lab" else b.type
 var variant = stable_variant(b.complex if not b.complex.is_empty() else b.name,4) if kind == "mall" else (stable_variant("%d,%d" % [b.x,b.y],6) if kind == "street" else 0)
 var footprint = footprint_for(sim,b)
 var property = property_info(sim,b)
 if not property.is_empty():
  kind = property.kind
  variant = property.variant
 if kind == "mall" and footprint.size == Vector2i(2,2) and sim.block_at(footprint.position.x,footprint.position.y+1).complex != b.complex:
  kind = "mall_l"
  variant = 0
 var status = state(sim,b) if b.type not in OUTDOORS else 0
 if state_override >= 0: status = state_override
 var texture = model(kind,status,variant)
 if texture == null: return null
 var offset = Vector2i(b.x,b.y)-footprint.position
 var key = "%s:%d:%d:%d,%d:%d,%d" % [kind,status,variant,footprint.size.x,footprint.size.y,offset.x,offset.y]
 if regions.has(key): return regions[key]
 var region = AtlasTexture.new()
 region.atlas = texture
 var cell = texture.get_size()/Vector2(footprint.size)
 region.region = Rect2(Vector2(offset)*cell,cell)
 region.filter_clip = true
 regions[key] = region
 return region

func material_for(sim, b: Dictionary) -> ShaderMaterial:
 if b.type in OUTDOORS or state(sim,b) == 0: return null
 var texture: AtlasTexture = texture_for(sim,b)
 var intact: AtlasTexture = texture_for(sim,b,0)
 var edges = Vector4.ZERO
 if not b.complex.is_empty() or not b.fort.is_empty():
  var directions = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
  for i in range(4):
   var at = Vector2i(b.x,b.y)+directions[i]
   if at.x >= 0 and at.x < sim.width and at.y >= 0 and at.y < sim.height:
    var other = sim.block_at(at.x,at.y)
    if (not b.fort.is_empty() and other.fort == b.fort) or (not b.complex.is_empty() and other.complex == b.complex): edges[i] = 1.0
 var key = "%d:%s" % [texture.get_instance_id(),str(edges)]
 if materials.has(key): return materials[key]
 var material = ShaderMaterial.new()
 material.shader = preload("res://scripts/minimap_state.gdshader")
 material.set_shader_parameter("intact_model",intact.atlas)
 var bounds = texture.region
 material.set_shader_parameter("region",Vector4(bounds.position.x/768.0,bounds.position.y/768.0,bounds.size.x/768.0,bounds.size.y/768.0))
 material.set_shader_parameter("joined_edges",edges)
 material.set_shader_parameter("ruined",state(sim,b) == 2)
 materials[key] = material
 return material
