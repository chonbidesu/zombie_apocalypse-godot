extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const W = preload("res://scripts/world_builder.gd")
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)
func ready(s,a) -> void:
 a.ap = 50
 a.busy_until = s.now()
func _initialize() -> void:
 var s = Sim.new()
 check(s.start(42,"Private",{"mode":"malton","survivors":6,"zombies":12}).is_empty(),"Original Malton loads offline")
 check(s.width == 100 and s.height == 100 and s.blocks.size() == 10000,"All ten thousand original squares loaded")
 check(s.block_at(0,0).name == "Bird Boulevard" and s.block_at(96,2).name == "Anne General Hospital","Original named coordinate anchors preserved")
 check(s.block_at(97,0).type == "necrotech_lab" and s.block_at(94,4).mast,"Hidden NecroTech and original phone mast markers imported")
 var suburbs = {}
 var malls = {}
 var forts = {}
 var zoo = []
 var positions_valid = true
 for b in s.blocks:
  suburbs[b.suburb] = true
  if b.type == "mall": malls[b.complex] = int(malls.get(b.complex,0))+1
  if not b.fort.is_empty(): forts[b.fort] = int(forts.get(b.fort,0))+1
  if not b.zoo.is_empty(): zoo.append(b)
  positions_valid = positions_valid and b.id == b.y*s.width+b.x and not b.name.is_empty()
 check(suburbs.size() == 100 and positions_valid,"Every block has a name, suburb and row-major coordinate")
 check(malls.size() == 20 and malls["Lumber Mall"] == 2 and malls["Pole Mall"] == 3,"All original named malls retain exceptional footprints")
 check(forts == {"Fort Creedy":9,"Fort Perryn":9},"Both original three-by-three forts retained")
 check(zoo.size() == 20 and zoo.filter(func(b): return b.unbarricadable).size() == 14,"Only the fourteen open zoo squares are unbarricadable")
 check(s.mast_sites.size() == 100,"Original map has one verified phone mast per suburb")
 var p = s.player()
 p.human_skills.clear()
 p.x = 92
 p.y = 7
 p.inside = true
 s.block_at(93,7).barricade = 7
 s.reindex()
 ready(s,p)
 check(s.act("move",-1,{"dx":1,"dy":0}).ok and p.inside,"Humans walk within mall interiors without Free Running")
 p.human = false
 ready(s,p)
 check(s.act("move",-1,{"dx":0,"dy":1}).ok and p.inside,"Zombies walk through connected mall interior squares")
 p.x = 41
 p.y = 30
 p.human = true
 p.inside = true
 p.human_skills = ["construction"]
 s.reindex()
 ready(s,p)
 check(not s.reason(p,"barricade").is_empty(),"Even Construction cannot barricade the zoo")
 p.x = 42
 p.y = 30
 ready(s,p)
 s.act("move",-1,{"dx":1,"dy":0})
 check(not p.inside,"Leaving an open zoo enclosure for grounds does not invent an interior")
 p.x = 84
 p.y = 89
 p.inside = true
 p.human_skills.append("free_running")
 s.reindex()
 ready(s,p)
 check(not s.reason(p,"move",-1,{"dx":-1,"dy":0}).is_empty(),"Free Running cannot cross fort perimeter walls")
 p.x = 85
 p.y = 92
 p.inside = false
 ready(s,p)
 check(s.act("move",-1,{"dx":0,"dy":-1}).ok and not p.inside,"Approach the gatehouse from outside the compound")
 ready(s,p)
 check(not s.reason(p,"move",-1,{"dx":0,"dy":-1}).is_empty(),"Outside gatehouse square is not a shortcut into the fort")
 s.block_at(p.x,p.y).barricade = 0
 ready(s,p)
 check(s.act("enter").ok,"Enter through the gatehouse")
 ready(s,p)
 check(s.act("move",-1,{"dx":0,"dy":-1}).ok,"Gatehouse interior connects to the fort courtyard")
 p.x = 9
 p.y = 40
 p.inside = false
 ready(s,p)
 check(s.act("move",-1,{"dx":1,"dy":0}).ok and p.x == 10,"Suburb boundaries do not block city movement")
 p.x = 99
 p.y = 99
 ready(s,p)
 check(not s.act("move",-1,{"dx":1,"dy":0}).ok,"Only the outer city edge blocks movement")
 p.x = 97
 p.y = 0
 p.inside = false
 p.human_skills.clear()
 var lab = s.current_block(p)
 check(s.visible_type(lab,p) == "office","Untrained humans cannot identify a NecroTech exterior")
 p.human = false
 check(s.visible_type(lab,p) == "office","Untrained zombies cannot identify a NecroTech exterior")
 p.human_skills.append("necro_employment")
 check(s.visible_type(lab,p) == "necrotech_lab","NecroTech Employment still recognises the lab after death")
 var before = s.current_block(p).name
 s.reindex()
 check(s.save_to("user://world-test.json") == OK,"Full city saves successfully")
 var restored = Sim.new()
 check(restored.load_from("user://world-test.json").is_empty() and restored.width == 100 and restored.current_block(restored.player()).name == before,"Full city dimensions, names and position survive save/load")
 var bad = {"mode":"random","width":10,"height":10,"malls":30,"forts":0,"zoos":0,"counts":{}}
 check(not restored.start(2,"Private",bad).is_empty() and restored.width == 100,"Invalid generator requests preserve the running game")
 var config = {"mode":"random","width":30,"height":20,"malls":4,"forts":1,"zoos":1,"cathedrals":1,"mansions":1,"power_stations":1,"stadiums":1,"counts":{"hospital":7,"necrotech_lab":5,"fire_station":3,"police_department":9,"warehouse":4},"survivors":9,"zombies":18}
 var one = W.build(config,765,{})
 var two = W.build(config,765,{})
 var three = W.build(config,766,{})
 check(not one.has("error") and one.blocks == two.blocks and one.blocks != three.blocks,"Random generation is repeatable and responds to seed changes")
 var counts = {}
 var complex_counts = {}
 for b in one.blocks:
  counts[b.type] = int(counts.get(b.type,0))+1
  if b.has("complex"): complex_counts[b.complex] = int(complex_counts.get(b.complex,0))+1
 for kind in config.counts: check(counts[kind] == config.counts[kind],"Exact custom resource count: "+kind)
 check(counts.mall == 16 and counts.gatehouse == 1 and counts.power_station == 4,"Random complexes reserve complete footprints")
 check(one.blocks.filter(func(b): return b.get("unbarricadable",false)).size() == 10,"Random zoo reserves ten open squares around six barricadable enclosures")
 check(s.start(765,"Doctor",config).is_empty() and s.width == 30 and s.height == 20 and s.actors.size() == 28,"Random city starts with requested dimensions and population")
 var full = W.defaults()
 var started = Time.get_ticks_msec()
 check(s.start(4815,"Private",full).is_empty() and s.actors.size() == 901,"Default generated city supports the configured population")
 var build_ms = Time.get_ticks_msec()-started
 started = Time.get_ticks_msec()
 s.elapse(3.0)
 print("CITY TIMING: build ",build_ms," ms; three simulated minutes ",Time.get_ticks_msec()-started," ms")
 check(s.actors.all(func(a): return a.x >= 0 and a.x < s.width and a.y >= 0 and a.y < s.height and a.ap >= 0 and a.ap <= 50),"City NPC activity preserves bounds and AP invariants")
 print("WORLD CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
