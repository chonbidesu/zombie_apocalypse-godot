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

func ready(s, a) -> void:
 a.ap = 50
 a.busy_until = s.now()

func _initialize() -> void:
 var s = Sim.new()
 s.start(3344)
 var p = s.player()
 for a in s.actors:
  if a.id > 0: a.down = true
 var b = s.current_block(p)
 s.reindex()
 construction_rules(s,p,b)
 # Every strength and visible band, including both edge bands.
 var levels = [0,1,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7,7,7,7]
 for strength in range(22):
  s.set_barricade_strength(b,strength)
  check(b.barricade == levels[strength] and s.barricade_strength(b) == strength,"Strength maps to correct band: %d" % strength)
  p.inside = false
  ready(s,p)
  check(s.reason(p,"enter").is_empty() == (strength <= 10),"Outside entry boundary: %d" % strength)
 p.inside = true
 s.set_barricade_strength(b,0)
 var build_correct = true
 for strength in range(1,22):
  var attempts = 0
  while s.barricade_strength(b) < strength and attempts < 100:
   ready(s,p)
   s.execute(p,"barricade")
   attempts += 1
  build_correct = build_correct and s.barricade_strength(b) == strength and b.barricade == levels[strength]
 check(build_correct,"Successful construction restores exactly one of 21 strength points")
 ready(s,p)
 check(not s.reason(p,"barricade").is_empty(),"Only strength 21 is maximum")
 # Player accuracy includes relevant human skills, never firearm/knife bonuses.
 p.inventory.clear()
 p.equipped = -1
 p.human_skills = []
 check(s.barricade_attack_stats(p).hit == 10 and s.barricade_attack_stats(p).structural == 0.5,"Untrained fists: 10% accuracy, then structural penalty")
 p.human_skills = ["hand_to_hand","axe_proficiency","knife_combat","firearms","advanced_pistol"]
 check(s.barricade_attack_stats(p).hit == 25,"Hand-to-hand training also improves fists")
 for kind in ["pistol","shotgun","flare_gun","knife","fuel_can"]:
  s.give_item(p,kind)
  p.equipped = p.inventory.back().uid
  ready(s,p)
  var before = s.barricade_strength(b)
  check(s.barricade_attack_stats(p).hit == 0 and not s.reason(p,"break").is_empty(),"Ineffective barricade weapon: "+kind)
  s.execute(p,"break")
  check(s.barricade_strength(b) == before,"Ineffective weapon does no structural damage: "+kind)
 for kind in C.ITEMS:
  var def = C.ITEMS[kind]
  if not def.has("damage") or def.has("capacity") or def.get("ranged",false) or kind == "knife": continue
  s.give_item(p,kind)
  p.equipped = p.inventory.back().uid
  var stats = s.barricade_attack_stats(p)
  check(stats.hit == def.hit+15+(15 if kind == "fire_axe" else 0) and stats.structural == (1.0 if kind == "crowbar" else 0.5),"Melee barricade accuracy and penalty: "+kind)
 # Count distinct outcomes and exact player flavour at deterministic seeds.
 for profile in [[true,"crowbar",20,1.0],[true,"fire_axe",40,0.5],[true,"",25,0.5],[false,"",50,0.5],[false,"baseball_bat",10,0.5]]:
  p.human = profile[0]
  p.zombie_skills = ["vigour_mortis","death_grip","rend_flesh","tangling_grasp","neck_lurch"]
  p.equipped = -1
  if not profile[1].is_empty():
   s.give_item(p,profile[1])
   p.equipped = p.inventory.back().uid
  var stats = s.barricade_attack_stats(p)
  check(stats.hit == profile[2] and stats.structural == profile[3],"Expected attack profile: "+str(profile))
  var damaged = 0
  var creaks = 0
  var misses = 0
  var exact_text = true
  var weapon_name = C.ITEMS[profile[1]].name.to_lower() if not profile[1].is_empty() else "fists"
  for attempt in range(6000):
   p.ap = 50
   s.set_barricade_strength(b,21)
   s.execute(p,"break")
   var text = s.messages.back().text
   if s.barricade_strength(b) == 20:
    damaged += 1
    exact_text = exact_text and text == ("You hit the barricade with your %s, damaging it." % weapon_name if p.human else "You smash at the barricade, damaging it.")
   elif text.ends_with("it creaks."):
    creaks += 1
    exact_text = exact_text and text == ("You hit the barricade with your %s; it creaks." % weapon_name if p.human else "You smash at the barricade; it creaks.")
   else:
    misses += 1
    exact_text = exact_text and text == ("You swing your %s at the barricade." % weapon_name if p.human else "You swipe at the barricade.")
  var chance = float(profile[2])/100.0*profile[3]
  check(absf(float(damaged)/6000-chance) < 0.025,"Observed structural damage chance: "+str(profile))
  check(exact_text and misses > 0 and (creaks > 0 if profile[3] < 1.0 else creaks == 0),"Exact text distinguishes hit, structural failure and miss: "+str(profile))
 # Destruction traverses every threshold, removing exactly 21 points.
 p.human = true
 s.give_item(p,"crowbar")
 p.equipped = p.inventory.back().uid
 s.set_barricade_strength(b,21)
 var damage_steps = 0
 var descent_correct = true
 for attempt in range(2000):
  var before = s.barricade_strength(b)
  s.execute(p,"break")
  var after = s.barricade_strength(b)
  if after < before:
   damage_steps += 1
   descent_correct = descent_correct and after == before-1 and b.barricade == levels[after]
  if after == 0: break
 check(descent_correct and damage_steps == 21 and b.barricade == 0,"Exactly 21 damaging hits remove EHB through every visible band")
 s.set_barricade_strength(b,21)
 p.human = false
 p.equipped = -1
 p.zombie_skills = []
 check(s.barricade_attack_stats(p).hit == 25,"Untrained zombie claws use 25% base accuracy before structural roll")
 p.zombie_skills = ["vigour_mortis"]
 check(s.barricade_attack_stats(p).hit == 35,"Vigour Mortis improves barricade claw accuracy")
 p.zombie_skills.append("death_grip")
 # Grasp never improves structural attacks; bites cannot damage structures.
 p.human = false
 p.equipped = -1
 p.grasp_target = 1
 s.actors[1].grasped_by = p.id
 check(s.barricade_attack_stats(p).hit == 50,"Tangling Grasp cannot boost barricade accuracy")
 ready(s,p)
 check(s.barricade_attack_stats(p,{"attack":"bite"}).hit == 0 and not s.reason(p,"break",-1,{"attack":"bite"}).is_empty(),"Bites are completely ineffective against barricades")
 # NPCs explicitly use claws even if holding an unusable or inferior item.
 s.give_item(p,"baseball_bat")
 p.equipped = p.inventory.back().uid
 ready(s,p)
 s.set_barricade_strength(b,21)
 check(s._try(p,"break"),"Zombie AI can attack barricades using claws while holding a tool")
 # New partial bands and legacy loose damage normalize through save/load.
 s.clear_grasp(p)
 ready(s,p)
 s.set_barricade_strength(b,17)
 check(b.barricade == 7 and b.barricade_damage == 4,"EHB includes five strength points")
 var path = "user://barricade-test.json"
 check(s.save_to(path) == OK,"Partial barricades save")
 var loaded = Sim.new()
 check(loaded.load_from(path).is_empty() and loaded.barricade_strength(loaded.current_block(loaded.player())) == 17,"Partial EHB survives save/load")
 var legacy = {"barricade":1,"barricade_damage":2}
 s.set_barricade_strength(legacy,s.barricade_strength(legacy))
 check(legacy.barricade == 1 and legacy.barricade_damage == 0,"Legacy damaged loose barricades normalize to one hit")
 print("BARRICADE CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)

func construction_rules(s, p, b) -> void:
 p.inside = true
 p.human_skills = ["construction"]
 p.inventory.clear()
 p.equipped = -1
 s.set_barricade_strength(b,0)
 b.doors = false
 ready(s,p)
 check(s.reason(p,"barricade").is_empty() and s.action_feedback(p,"barricade",-1,{},true).is_empty(),"Open doors allow barricading without a separate Close action")
 check(s.act("barricade").ok,"Construction needs no carried weapon, tool or material")
 check(s.barricade_strength(b) == 1 and b.doors and p.ap == 49 and p.inventory.is_empty() and s.messages.back().text == "You barricade the building.","First build closes doors, adds one strength point and spends exactly one AP")
 # Exact chance for every strength, with independent environmental modifiers.
 var z1 = s.actors[1]
 var z2 = s.actors[2]
 for z in [z1,z2]:
  z.x = p.x
  z.y = p.y
  z.inside = true
  z.human = false
  z.hp = 50
  z.down = false
 s.reindex()
 var expected = [1.0,0.995,0.99,0.99,0.99,0.978,0.978,0.978,0.851,0.851,0.851,0.615,0.615,0.615,0.38,0.38,0.38,0.205,0.205,0.205,0.205,0.0]
 b.type = "bank"
 b.generator = false
 for strength in range(22):
  s.set_barricade_strength(b,strength)
  z1.down = true
  z2.down = true
  b.generator = true
  b.fuel_until = s.minute+1000
  check(is_equal_approx(s.barricade_build_chance(b),expected[strength]),"Lit build rate for strength %d" % strength)
  b.generator = false
  check(is_equal_approx(s.barricade_build_chance(b),expected[strength]*0.5),"Darkness halves build odds at strength %d" % strength)
  z1.down = false
  b.generator = true
  check(is_equal_approx(s.barricade_build_chance(b),expected[strength]),"One standing zombie does not interfere at strength %d" % strength)
  z2.down = false
  check(is_equal_approx(s.barricade_build_chance(b),expected[strength]*0.5),"Two standing zombies halve build odds at strength %d" % strength)
  b.generator = false
  check(is_equal_approx(s.barricade_build_chance(b),expected[strength]*0.25),"Darkness and interference stack at strength %d" % strength)
 # Only standing, alive zombies inside this site count.
 s.set_barricade_strength(b,11)
 z2.hp = 0
 check(not s.barricade_interference(b),"Zero-HP zombie does not interfere")
 z2.hp = 50
 z2.inside = false
 s.reindex()
 check(not s.barricade_interference(b),"Outside zombies do not interfere")
 z2.inside = true
 s.reindex()
 for site_type in ["cinema","warehouse","mall","bank","nightclub","armoury","hospital"]:
  b.type = site_type
  z1.down = true
  z2.down = true
  check(is_equal_approx(s.barricade_build_chance(b),0.615*(0.5 if site_type in C.DARK_BUILDINGS else 1.0)),"Darkness classification: "+site_type)
 b.type = "bank"
 # Seeded clicks verify actual transactions, flavour and stacked penalties.
 for dark in [false,true]:
  for interference in [false,true]:
   b.generator = not dark
   z1.down = not interference
   z2.down = not interference
   s.set_barricade_strength(b,11)
   ready(s,p)
   check(s.reason(p,"barricade").is_empty(),"Intruders penalize construction rather than prohibiting it")
   var chance = s.barricade_build_chance(b)
   var successes = 0
   var correct = true
   for attempt in range(4000):
    s.set_barricade_strength(b,11)
    ready(s,p)
    s.act("barricade")
    var text = s.messages.back().text
    var success = s.barricade_strength(b) == 12
    if success: successes += 1
    correct = correct and p.ap == 49 and p.inventory.is_empty()
    if interference:
     correct = correct and (text.begins_with("Dragging ") and text.ends_with(" past the zombies, you reinforce the barricade.") if success else text.begins_with("You drag ") and text.ends_with(" towards the doors, but the zombies lurch into your way."))
    else:
     correct = correct and text == ("You barricade the building." if success else "You look around for something to barricade the building with.")
   check(absf(float(successes)/4000.0-chance) < 0.025 and correct,"Actual clicks apply odds, AP and exact flavour: dark=%s interference=%s" % [dark,interference])
 z1.down = true
 z2.down = true
 b.type = "hospital"
 b.generator = false
 s.set_barricade_strength(b,9)
 for attempt in range(100):
  ready(s,p)
  s.act("barricade")
  if s.barricade_strength(b) == 10: break
 check(s.messages.back().text.begins_with("Using ") and s.messages.back().text.ends_with("It's looking very strong, now - any further barricading will prevent survivors from climbing in."),"Strength ten prints the exact entry warning with a material")
 s.set_barricade_strength(b,21)
 ready(s,p)
 p.ap = 0
 var cap_state = JSON.stringify([s.actors,s.blocks,s.rng.state])
 var result = s.act("barricade")
 check(not result.ok and result.message == "The barricade cannot be built any higher." and JSON.stringify([s.actors,s.blocks,s.rng.state]) == cap_state,"Maximum strength rejects construction with exact message, no AP/recovery/state changes")
 check(s.action_feedback(p,"barricade").is_empty(),"Maximum strength remains clickable for no-cost feedback even with zero AP")
 ready(s,p)
 for site_type in ["church","junkyard","bear_pit"]:
  b.type = site_type
  b.doors = false
  s.set_barricade_strength(b,0)
  check(s.reason(p,"barricade").is_empty(),"Doorless buildings remain barricadable: "+site_type)
 b.type = "hospital"
 b.doors = true
 s.set_barricade_strength(b,0)
 s.reindex()
