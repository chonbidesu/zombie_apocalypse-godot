extends RefCounted
## Static geography and seeded random-city generation, independent of actor state.
const C = preload("res://scripts/catalog.gd")

static func defaults(width: int = 100, height: int = 100) -> Dictionary:
 var counts = {}
 for kind in C.NORMAL_BUILDINGS:
  if kind != "mall": counts[kind] = maxi(1,int(width*height*(0.012 if kind in ["hospital","necrotech_lab","police_department","fire_station","auto_repair","factory","warehouse"] else 0.025)))
 return {"mode":"random","width":width,"height":height,"malls":20,"forts":2,"zoos":1,"cathedrals":5,"mansions":5,"power_stations":2,"stadiums":3,"counts":counts,"survivors":300,"zombies":600}

static func build(config: Dictionary, seed_value: int, names: Dictionary) -> Dictionary:
 if config.get("mode","random") == "malton":
  var file = FileAccess.open("res://assets/maps/malton.json",FileAccess.READ)
  if file == null: return {"error":"The Malton map data is missing."}
  var data = JSON.parse_string(file.get_as_text())
  if not data is Dictionary or data.get("blocks",[]).size() != 10000: return {"error":"The Malton map data is incomplete."}
  return {"width":100,"height":100,"blocks":data.blocks.duplicate(true),"title":"Malton","mode":"malton","source":data.get("source",{})}
 var width = int(config.get("width",100))
 var height = int(config.get("height",100))
 if width < 10 or width > 100 or height < 10 or height > 100: return {"error":"Map dimensions must be between 10 and 100."}
 var counts = config.get("counts",defaults(width,height).counts)
 if not counts is Dictionary: return {"error":"Building counts must be a dictionary."}
 var special = {"malls":int(config.get("malls",20)),"forts":int(config.get("forts",1)),"zoos":int(config.get("zoos",1))}
 for category in ["cathedrals","mansions","power_stations","stadiums"]: special[category] = int(config.get(category,0))
 var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/complex-plans.json")).plans
 var required = 0
 for category in special:
  for number in range(maxi(0,special[category])):
   required += plans[category][number%plans[category].size()].cells.size()
 for value in special.values():
  if value < 0: return {"error":"Complex counts cannot be negative."}
 for kind in counts:
  if kind not in C.NORMAL_BUILDINGS or kind == "mall" or int(counts[kind]) < 0: return {"error":"Invalid building count: "+str(kind)}
  required += int(counts[kind])
 if required > width*height: return {"error":"Requested buildings need %d squares; this map has %d." % [required,width*height]}
 var rng = RandomNumberGenerator.new()
 rng.seed = seed_value
 var blocks: Array = []
 for id in range(width*height):
  blocks.append({"id":id,"x":id%width,"y":id/width,"type":"street","name":"Street %d" % (id+1),"suburb":"District %02d-%02d" % [(id%width)/10+1,(id/width)/10+1]})
 var reserved = {}
 # Largest footprints first; never silently reduce a requested count.
 for category in ["zoos","forts","malls","cathedrals","mansions","power_stations","stadiums"]:
  for number in range(special[category]):
   var plan: Dictionary = plans[category][number%plans[category].size()]
   var candidates: Array[Vector2i] = []
   for y in range(height-int(plan.height)+1):
    for x in range(width-int(plan.width)+1):
     var fits = true
     for cell in plan.cells:
      if reserved.has((y+int(cell.y))*width+x+int(cell.x)): fits = false
     if fits: candidates.append(Vector2i(x,y))
   if candidates.is_empty(): return {"error":"The requested complexes cannot fit without overlapping. Reduce their counts or increase map size."}
   var at = candidates[rng.randi_range(0,candidates.size()-1)]
   var title: String = plan.name+ (" %d" % (number/plans[category].size()+1) if number >= plans[category].size() else "")
   for cell in plan.cells:
     var dx = int(cell.x)
     var dy = int(cell.y)
     var id = (at.y+dy)*width+at.x+dx
     reserved[id] = true
     var b = blocks[id]
     if category == "zoos":
      b.type = cell.type
      b.zoo = title
      b.complex = title
      b.unbarricadable = b.type in C.OUTDOORS
      b.name = title+" "+C.pretty(b.type)
     elif category == "forts":
      b.type = cell.type
      b.fort = title
      b.name = title+" "+C.pretty(b.type)
     else:
      b.type = cell.type
      b.name = title
      b.complex = title
 var free: Array[int] = []
 for b in blocks:
  if not reserved.has(b.id): free.append(b.id)
 for i in range(free.size()-1,0,-1):
  var j = rng.randi_range(0,i)
  var value = free[i]
  free[i] = free[j]
  free[j] = value
 var next = 0
 for kind in counts:
  for i in range(int(counts[kind])):
   var b = blocks[free[next]]
   next += 1
   b.type = kind
   var choices = names.get(kind.to_upper(),[C.pretty(kind)])
   b.name = choices[rng.randi_range(0,choices.size()-1)]
 var districts = {}
 for b in blocks:
  if b.type in C.OUTDOORS or b.has("fort") or b.has("zoo"): continue
  if not districts.has(b.suburb): districts[b.suburb] = []
  districts[b.suburb].append(b)
 for district in districts:
  var candidates = districts[district].filter(func(b): return b.type == "tower")
  if candidates.is_empty(): candidates = districts[district]
  candidates[rng.randi_range(0,candidates.size()-1)].mast = true
 return {"width":width,"height":height,"blocks":blocks,"title":"Generated City","mode":"random","source":{}}
