extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)

func isolated():
 var s = Sim.new()
 s.start(442)
 for a in s.actors:
  if a.id > 0:
   a.x = 0
   a.y = 0
   a.down = true
   a.next_think = 999999.0
 s.reindex()
 return s

func ready(s, a) -> void:
 a.ap = 50
 a.busy_until = s.now()

func _initialize() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 s.give_item(p,"portable_generator")
 b.ruin = 3
 var inventory_before = p.inventory.size()
 check(not s.act("generator").ok and p.inventory.size() == inventory_before and not b.generator,"Ruined building blocks installation without consuming generator")
 b.generator = true
 b.fuel_until = s.minute+1440
 check(not s.powered(b),"Even inconsistent old state cannot light a ruin")
 check(s.search_chance(b) > 0 and s.search_chance(b) < 0.005,"Ruins have near-zero but nonzero loot odds")
 b.ruin = 0
 b.generator = false
 check(s.act("generator").ok and b.generator,"Generator installs after complete repair")
 var sane = true
 for building in C.BUILDINGS:
  b.type = building
  b.fuel_until = s.minute+1440
  var total = s.search_chance(b)
  sane = sane and total > 0 and total < 1
 check(sane,"Every supported building has a valid per-item probability table")
 b.type = "church"
 check(s.item_search_chance(b,"portable_generator") == 0 and s.item_search_chance(b,"fuel_can") == 0,"Churches never yield generators or fuel")
 var fuel_sources = []
 for building in C.BUILDINGS:
  b.type = building
  if s.item_search_chance(b,"fuel_can") > 0: fuel_sources.append(building)
 check(fuel_sources.size() == 6 and "auto_repair" in fuel_sources and "junkyard" in fuel_sources and "factory" in fuel_sources and "power_station" in fuel_sources and "storehouse" in fuel_sources and "vehicle_depot" in fuel_sources,"Fuel is restricted to plausible repair, industry and military supply sites")
 b.type = "auto_repair"
 var auto_fuel = s.item_search_chance(b,"fuel_can")
 b.type = "junkyard"
 var junk_fuel = s.item_search_chance(b,"fuel_can")
 b.type = "factory"
 check(auto_fuel > junk_fuel and junk_fuel > s.item_search_chance(b,"fuel_can"),"Auto shops have the highest fuel chance")
 var factory_generator = s.item_search_chance(b,"portable_generator")
 b.type = "warehouse"
 var warehouse_generator = s.item_search_chance(b,"portable_generator")
 b.type = "hospital"
 check(factory_generator > warehouse_generator and warehouse_generator > s.item_search_chance(b,"portable_generator"),"Generators favor factories then warehouses then rare hospital finds")
 var hospital_fak = s.item_search_chance(b,"first_aid_kit")
 b.type = "fire_station"
 var fire_fak = s.item_search_chance(b,"first_aid_kit")
 var fire_axe = s.item_search_chance(b,"fire_axe")
 b.type = "police_department"
 check(hospital_fak > fire_fak and fire_fak > s.item_search_chance(b,"first_aid_kit"),"Medical supplies favor hospitals then fire then police stations")
 b.type = "school"
 check(s.item_search_chance(b,"baseball_bat") > fire_axe and fire_axe < 0.05,"Common sports weapons are easier to find than the best melee weapon")
 b.type = "fire_station"
 var lit_axe = s.item_search_chance(b,"fire_axe")
 b.fuel_until = 0
 check(is_equal_approx(s.item_search_chance(b,"fire_axe"),lit_axe*C.DARK_SEARCH_MULTIPLIER),"Lighting modifies each individual item chance")
 b.type = "auto_repair"
 b.fuel_until = s.minute+1440
 var counts = {}
 s.rng.seed = 9001
 for i in range(20000):
  var found = s.roll_search(b)
  counts[found] = counts.get(found,0)+1
 check(absf(float(counts.get("fuel_can",0))/20000-0.08) < 0.01 and absf(float(counts.get("toolbox",0))/20000-0.055) < 0.01,"Sampled loot frequencies match the separate item probabilities")
 check(not counts.has("pistol") and not counts.has("first_aid_kit"),"Search never produces items missing from a building table")
 b.type = "hospital"
 b.generator = false
 b.ruin = 3
 var ruin_finds = 0
 for i in range(20000):
  if not s.roll_search(b).is_empty(): ruin_finds += 1
 check(ruin_finds > 0 and ruin_finds < 100,"Rare ruin finds occur without becoming a viable supply source")
 b.type = "police_department"
 b.ruin = 0
 b.generator = true
 b.fuel_until = s.minute+1440
 var found_gun = false
 for i in range(2000):
  var before = s.rng.state
  var found = s.roll_search(b)
  if found in ["pistol","shotgun"]:
   s.rng.state = before
   var text = s._search(p,b,"You")
   found_gun = p.inventory.back().kind == found and p.inventory.back().ammo == 0 and text.contains("needs ammunition")
   break
 check(found_gun,"Found firearms are empty and the player's narration explains ammunition")
 var npc = s.actors[2]
 npc.x = p.x
 npc.y = p.y
 npc.inside = p.inside
 npc.down = false
 s.reindex()
 check(s._search(npc,b,s.display_name(npc)) == "%s searches the area for supplies." % s.display_name(npc),"NPC search feedback is concise and reveals no detailed loot narration")
 s = isolated()
 p = s.player()
 s.give_item(p,"shotgun")
 s.give_item(p,"shotgun_shell")
 s.give_item(p,"shotgun_shell")
 s.give_item(p,"shotgun_shell")
 var gun = s.item_kind(p,"shotgun")
 gun.ammo = 0
 p.equipped = gun.uid
 var shells_before = p.inventory.filter(func(item): return item.kind == "shotgun_shell").size()
 check(s.act("reload").ok and gun.ammo == 1 and p.inventory.filter(func(item): return item.kind == "shotgun_shell").size() == shells_before-1,"One shotgun shell loads exactly one shot")
 ready(s,p)
 check(s.act("reload").ok and gun.ammo == 2,"Shotgun holds two individually loaded shells")
 ready(s,p)
 var before_ap = p.ap
 check(not s.act("reload").ok and p.ap == before_ap and not s.item_kind(p,"shotgun_shell").is_empty(),"Full shotgun rejects reload without consuming its spare shell")
 var target = s.actors[15]
 target.x = p.x
 target.y = p.y
 target.inside = p.inside
 target.down = false
 target.hp = 50
 s.reindex()
 check(s.act("attack",target.id).ok and gun.ammo == 1,"Shotgun attack consumes one shell even on a miss")
 var hit = false
 for i in range(30):
  ready(s,p)
  target.hp = 50
  target.down = false
  gun.ammo = 2
  s.act("attack",target.id)
  if target.hp == 40: hit = true
 check(hit and C.ITEMS.shotgun.damage > C.ITEMS.pistol.damage and C.ITEMS.pistol.damage > C.ITEMS.fire_axe.damage,"Shotgun deals the highest damage, with pistol above melee")
 s.give_item(p,"pistol")
 s.give_item(p,"pistol_clip")
 gun = s.item_kind(p,"pistol")
 gun.ammo = 0
 p.equipped = gun.uid
 ready(s,p)
 check(s.act("reload").ok and gun.ammo == 6 and s.item_kind(p,"pistol_clip").is_empty(),"A handgun magazine supplies six shots")
 s = isolated()
 p = s.player()
 npc = s.actors[1]
 npc.x = p.x
 npc.y = p.y
 npc.inside = true
 npc.down = false
 s.reindex()
 inventory_before = p.inventory.size()
 check(s.act("request",npc.id).ok and p.inventory.size() == inventory_before and s.messages.back().text.contains("refuses"),"An untrusted request gets a real refusal instead of free supplies")
 check(npc.speech.contains("Help us first"),"Refusal also appears as a short NPC reply")
 ready(s,p)
 npc.hp = 30
 s.act("heal",npc.id)
 var earned = s.trust_level(npc,p)
 check(earned == 10,"Healing another survivor earns their individual trust")
 ready(s,p)
 s.give_item(p,"first_aid_kit")
 p.hp = 30
 s.act("heal",p.id)
 check(s.trust_level(npc,p) == earned,"Self-healing does not farm NPC trust")
 b = s.current_block(p)
 b.barricade_damage = 2
 var reinforced = false
 for i in range(30):
  ready(s,p)
  s.act("barricade")
  if b.barricade_damage == 0:
   reinforced = true
   break
 check(reinforced and s.trust_level(npc,p) == earned+3,"Successful shelter work earns trust from witnesses")
 var value = s.trust_level(npc,p)
 b.barricade = 7
 b.barricade_damage = 0
 ready(s,p)
 check(not s.act("barricade").ok and s.trust_level(npc,p) == value,"No-op reinforcement cannot farm trust")
 ready(s,p)
 s.act("break")
 check(s.trust_level(npc,p) == maxi(0,value-5),"Damaging the group's defenses reduces trust")
 npc.trust[str(p.id)] = 100
 var successful_requests = 0
 for i in range(15):
  s.minute += 10
  ready(s,p)
  var count_before = p.inventory.size()
  s.act("request",npc.id)
  if p.inventory.size() > count_before: successful_requests += 1
 check(successful_requests == 2 and npc.inventory.size() == 1 and npc.inventory[0].kind == "first_aid_kit","A trusted doctor shares spare kits while keeping the last medical kit")
 check(s.trust_level(npc,p) == 80,"Successful favors draw down trust rather than enabling unlimited begging")
 ready(s,p)
 var reply = s.request_supplies(p,npc)
 check(reply.contains("already answered"),"Repeated immediate requests are discouraged")
 var engineer = s.actors[2]
 engineer.inventory.clear()
 s.give_item(engineer,"toolbox")
 engineer.trust[str(p.id)] = 100
 check(s._spare_item(engineer,p).is_empty(),"Engineers retain their last toolbox even at high trust")
 var donor = s.actors[4]
 donor.inventory.clear()
 s.give_item(donor,"portable_generator")
 donor.trust[str(p.id)] = 35
 check(s._spare_item(donor,p).is_empty(),"Rare supplies require deeper trust")
 donor.trust[str(p.id)] = 80
 check(s._spare_item(donor,p).kind == "portable_generator","High trust makes an unneeded rare item shareable")
 check(s.save_to("res://test-loot-trust-save.json") == OK,"Loot and relationship state saves")
 var loaded = Sim.new()
 check(loaded.load_from("res://test-loot-trust-save.json").is_empty() and loaded.trust_level(loaded.actors[1],loaded.player()) == 80,"Individual trust persists through loading")
 check(loaded.actors[1].request_after == npc.request_after,"Request cooldowns persist through loading")
 print("LOOT/TRUST CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
