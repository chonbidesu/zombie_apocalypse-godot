extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 var s = Sim.new(); s.start(311)
 var p = s.player(); p.human_skills = []
 var b = s.current_block(p)
 var report = {"reviewed":"2026-11-04","provenance":"search_provenance.json","rates":"Calculated per-search probabilities for this prototype, not authenticated historical Urban Dead odds.","items":{},"locations":{}}
 for kind in C.ITEMS: report.items[kind] = {"name":C.ITEMS[kind].name,"locations":[]}
 for location in C.BUILDINGS+C.OUTDOORS:
  b.type = location; b.ruin = 0
  b.generator = true; b.generator_hp = C.GENERATOR_HP; b.fuel_until = s.minute+100
  p.inside = location in C.BUILDINGS
  var distribution = s.search_distribution(b,p)
  check(not distribution.is_empty(),"Search table exists: "+location)
  report.locations[location] = {"mode":"interior" if p.inside else "shared outdoors","items":{}}
  for kind in distribution:
   check(C.ITEMS.has(kind) and float(distribution[kind]) > 0,"Valid weighted item: "+location+"/"+kind)
   var powered_rate = s.item_search_chance(b,kind,p)
   b.fuel_until = 0
   var unpowered_rate = s.item_search_chance(b,kind,p)
   b.ruin = 3
   var ruined_rate = s.item_search_chance(b,kind,p)
   b.fuel_until = s.minute+100
   var powered_ruin_rate = s.item_search_chance(b,kind,p)
   b.ruin = 0
   var rates = {"unpowered":unpowered_rate,"powered":powered_rate if s.can_host_generator(b) else null,"ransacked_or_ruined":ruined_rate if s.can_be_ransacked(b) else null,"powered_ruin":powered_ruin_rate if s.can_be_ransacked(b) and s.can_host_generator(b) else null}
   report.locations[location].items[kind] = rates
   report.items[kind].locations.append({"type":location,"rates":rates})
 for kind in C.ITEMS: check(not report.items[kind].locations.is_empty(),"Every catalog item is obtainable through searches: "+kind)
 b.type = "mall"; p.inside = true; p.human_skills = ["shopping"]
 report["mall_stores"] = {}
 for store in C.MALL_STORES:
  var rates = {}
  for kind in s.search_distribution(b,p,store): rates[kind] = s.item_search_chance(b,kind,p,store)
  report.mall_stores[store] = {"powered_shopping":rates,"bargain_hunting":"Double intact powered odds; no bonus to ransacked/ruined or pitch-black rooms."}
 var file = FileAccess.open("res://assets/tables/search_coverage.json",FileAccess.WRITE)
 check(file != null,"Coverage report can be written")
 if file: file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
 print("SEARCH COVERAGE CHECKS: ",checks," FAILURES: ",failures," / ",report.items.size()," items, ",report.locations.size()," location types")
 quit(0 if failures == 0 else 1)
