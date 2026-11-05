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
func ready(s,p) -> void:
 p.ap = 50
 p.busy_until = s.now()
func _initialize() -> void:
 var s = Sim.new()
 s.start(1818)
 for actor in s.actors:
  if actor.id > 0: actor.down = true
 var p = s.player()
 var b = s.current_block(p)
 p.inventory.clear()
 p.inside = true
 p.human_skills = []
 for kind in C.BUILDINGS:
  b.type = kind
  b.ruin = 0
  b.generator = false
  check(is_equal_approx(s.search_chance(b,p),0.01 if kind in C.DARK_SEARCH_BUILDINGS else 0.2),"Unlit state odds: "+kind)
  b.generator = true
  b.fuel_until = s.minute+100
  var lit = (0.26 if kind == "mall" else (0.28 if kind == "necrotech_lab" else 0.3)) if s.can_host_generator(b) else 0.2
  check(is_equal_approx(s.search_chance(b,p),lit),"Lit state odds: "+kind)
  var total = 0.0
  for item in s.search_distribution(b,p): total += s.item_search_chance(b,item,p)
  check(is_equal_approx(total,lit),"Conditional item probabilities sum to global find odds: "+kind)
  for ruin in [1,2,3]:
   b.ruin = ruin
   check(is_equal_approx(s.search_chance(b,p),0.1),"Partial and complete ruins override light and type: "+kind)
  p.inside = false
  ready(s,p)
  check(is_equal_approx(s.search_chance(b,p),0.05) and s.reason(p,"search").is_empty(),"Outside searches available at every building: "+kind)
  check(s.search_distribution(b,p) == C.OUTSIDE_SEARCH_WEIGHTS,"Every building exterior uses the shared street table: "+kind)
  p.inside = true
 for kind in C.OUTDOORS:
  b.type = kind
  check(is_equal_approx(s.search_chance(b,p),0.05) and not s.search_distribution(b,p).is_empty(),"Every outdoor square has five percent find odds and loot: "+kind)
  check(s.search_distribution(b,p) == C.OUTSIDE_SEARCH_WEIGHTS and s.search_loot(kind) == C.OUTSIDE_SEARCH_WEIGHTS.keys(),"Open ground uses the same street table and metadata: "+kind)
 for kind in ["fire_axe","crowbar","knife","length_of_pipe","baseball_bat","fuel_can","spray_can","flashlight","binoculars","newspaper"]:
  check(C.ITEMS.has(kind) and C.OUTSIDE_SEARCH_WEIGHTS.get(kind,0.0) > 0.0,"Street loot includes supported item: "+kind)
 var no_restricted = true
 for kind in C.OUTSIDE_SEARCH_WEIGHTS:
  no_restricted = no_restricted and kind != "syringe" and not C.ITEMS[kind].has("capacity") and not C.ITEMS[kind].has("ammo_kind") and not C.ITEMS[kind].get("ranged",false) and kind not in ["pistol_clip","shotgun_shell"]
 check(no_restricted,"No syringe, firearm, flare gun or ammunition appears in street loot")
 p.inside = false
 var street_counts = {}
 b.type = "hospital"
 s.rng.seed = 701
 for attempt in range(60000):
  var found = s.roll_search(b,p)
  street_counts[found] = street_counts.get(found,0)+1
 var total_finds = 60000-int(street_counts.get("",0))
 check(absf(float(total_finds)/60000-0.05) < 0.004,"Sampled exterior find rate remains flat at five percent")
 check(C.OUTSIDE_SEARCH_WEIGHTS.keys().all(func(kind): return street_counts.get(kind,0) > 0) and street_counts.size() == C.OUTSIDE_SEARCH_WEIGHTS.size()+1,"Street sample finds the full grab bag with no disallowed items")
 s.rng.seed = 333
 var exterior_rolls = []
 for attempt in range(1000): exterior_rolls.append(s.roll_search(b,p))
 b.type = "street"
 s.rng.seed = 333
 var same_rolls = true
 for attempt in range(1000): same_rolls = same_rolls and exterior_rolls[attempt] == s.roll_search(b,p)
 check(same_rolls,"Building exteriors and street squares produce identical seeded loot")
 p.inside = true
 b.type = "hospital"
 b.ruin = 0
 b.generator = false
 check(is_equal_approx(s.item_search_chance(b,"first_aid_kit",p),0.17),"Unlit hospitals yield first aid kits at seventeen percent")
 b.type = "necrotech_lab"
 check(is_equal_approx(s.item_search_chance(b,"syringe",p),0.125),"Unlit NT syringe rate is twelve and a half percent")
 b.generator = true
 check(is_equal_approx(s.item_search_chance(b,"syringe",p),0.175),"Lit NT syringe rate is seventeen and a half percent")
 b.type = "mall"
 var untargeted = s.search_distribution(b,p,"drugstore")
 check(untargeted.has("shotgun"),"Without Shopping a store choice cannot target loot")
 p.human_skills = ["shopping"]
 var pharmacy_rate = s.item_search_chance(b,"first_aid_kit",p,"drugstore")
 check(s.item_search_chance(b,"shotgun",p,"drugstore") == 0 and pharmacy_rate > 0,"Shopping restricts finds to the chosen store")
 p.human_skills.append("bargain_hunting")
 check(is_equal_approx(s.item_search_chance(b,"first_aid_kit",p,"drugstore"),pharmacy_rate*2),"Bargain Hunting doubles mall yield")
 check(is_equal_approx(s.search_chance(b,p,"gun_store"),0.52) and absf(s.item_search_chance(b,"pistol_clip",p,"gun_store")-0.17) < 0.001,"Boosted lit mall gun store: fifty-two percent total, seventeen percent pistol magazines")
 check(absf(s.item_search_chance(b,"shotgun_shell",p,"gun_store")-0.17) < 0.001 and s.item_search_chance(b,"flak_jacket",p,"gun_store") == 0 and s.item_search_chance(b,"flare_gun",p,"gun_store") == 0,"Mall gun stores provide ammunition without police-only equipment")
 b.ruin = 1
 check(is_equal_approx(s.search_chance(b,p,"gun_store"),0.1),"Ruin overrides Bargain Hunting and darkness")
 p.inside = false
 check(is_equal_approx(s.search_chance(b,p,"gun_store"),0.05) and not s.search_distribution(b,p,"gun_store").has("shotgun"),"Outside a mall uses outdoor odds and loot without store or skill bonuses")
 p.inside = true
 b.type = "hospital"
 b.ruin = 0
 b.generator = false
 check(is_equal_approx(s.search_chance(b,p),0.2),"Bargain Hunting never improves non-mall searches")
 # Adding or scaling table entries changes distribution, never the global find rate.
 var hospital = s.search_tables.hospital.duplicate()
 s.search_tables.hospital = {"book":1.0,"newspaper":3.0}
 check(is_equal_approx(s.item_search_chance(b,"book",p),0.05) and is_equal_approx(s.item_search_chance(b,"newspaper",p),0.15),"Normalized table weights split a fixed twenty percent total")
 s.search_tables.hospital = {"book":100.0,"newspaper":300.0}
 check(is_equal_approx(s.item_search_chance(b,"book",p),0.05),"Weight scale cannot change global or relative odds")
 var books = 0
 var papers = 0
 var empty = 0
 for attempt in range(40000):
  var found = s.roll_search(b,p)
  if found == "book": books += 1
  elif found == "newspaper": papers += 1
  else: empty += 1
 check(absf(float(books)/40000-0.05) < 0.008 and absf(float(papers)/40000-0.15) < 0.008 and absf(float(empty)/40000-0.8) < 0.008,"Sampled two-stage searches match total and conditional loot odds")
 var probe = RandomNumberGenerator.new()
 var stages_correct = true
 for attempt in range(200):
  probe.state = s.rng.state
  var success = probe.randf() < s.search_chance(b,p)
  if success: probe.randf()
  var found = s.roll_search(b,p)
  stages_correct = stages_correct and s.rng.state == probe.state and found.is_empty() != success
 check(stages_correct,"Failed search uses one roll; a successful search uses a separate loot roll")
 s.search_tables.hospital = hospital
 # Search cap blocks before random generation, costs and recovery.
 for i in range(100): s.give_item(p,"candy")
 ready(s,p)
 var before = JSON.stringify([s.actors,s.rng.state])
 check(not s.act("search").ok and s.reason(p,"search").contains("100 items") and JSON.stringify([s.actors,s.rng.state]) == before,"One hundred items block searching without spending AP or RNG")
 s._search(p,b,"You")
 check(JSON.stringify([s.actors,s.rng.state]) == before,"Internal search cannot generate items above the hard cap either")
 s.execute(p,"drop",-1,{"uid":p.inventory.back().uid})
 ready(s,p)
 check(s.reason(p,"search").is_empty(),"Dropping below one hundred items enables searching again")
 # Found guns are usually partially loaded, never overfilled, and describe ammo.
 p.inventory.clear()
 b.type = "police_department"
 b.generator = true
 s.search_tables.police_department = {"pistol":1.0}
 var loaded = 0
 var found_guns = 0
 var bounded = true
 for attempt in range(2000):
  p.inventory.clear()
  var text = s._search(p,b,"You")
  if p.inventory.is_empty(): continue
  found_guns += 1
  var ammo = p.inventory.back().ammo
  if ammo > 0: loaded += 1
  bounded = bounded and ammo >= 0 and ammo < 6 and (text.contains("holds") if ammo > 0 else text.contains("needs ammunition"))
 check(found_guns > 400 and bounded and float(loaded)/found_guns > 0.68 and float(loaded)/found_guns < 0.82,"Found guns are partially loaded about seventy-five percent of the time with accurate narration")
 p.inventory.clear()
 s.give_item(p,"flashlight")
 ready(s,p)
 var flashlight_uid = p.inventory.back().uid
 check(s.reason(p,"inspect",-1,{"uid":flashlight_uid}).is_empty(),"Scavenged flashlights support the standard Inspect action")
 s.execute(p,"inspect",-1,{"uid":flashlight_uid})
 check(p.inventory.size() == 1 and s.messages.back().text == "You inspect Flashlight." and ResourceLoader.exists("res://assets/items/flashlight.png"),"Flashlight remains in inventory after inspection and has imported item art")
 print("SEARCH CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
