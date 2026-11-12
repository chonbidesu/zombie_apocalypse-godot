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
 s.start(482)
 for a in s.actors:
  if a.id > 0:
   a.x = 0
   a.y = 0
   a.down = true
   a.ready_at = 999999
 s.reindex()
 return s

func ready(s, a) -> void:
 a.busy_until = s.now()
 a.ap = 50

func _initialize() -> void:
 entrance_rules()
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 b.barricade = 4
 b.barricade_damage = 0
 var hits = 0
 var attempts = 0
 var invariant = true
 while b.barricade == 4 and attempts < 100:
  var before_damage = b.barricade_damage
  s.execute(p,"break")
  if b.barricade_damage != before_damage or b.barricade < 4: hits += 1
  invariant = invariant and b.barricade_damage >= 0 and b.barricade_damage < 3
  attempts += 1
 check(b.barricade == 3 and hits == 3 and attempts >= 3 and invariant,"A barricade level needs three successful probabilistic hits")
 b.barricade = 7
 b.barricade_damage = 2
 ready(s,p)
 check(s.reason(p,"barricade").is_empty(),"Maximum barricades can still be repaired")
 for i in range(50):
  if b.barricade_damage == 0: break
  s.execute(p,"barricade")
 check(b.barricade == 7 and b.barricade_damage == 0,"Re-cading restores damaged sublevels before raising level")
 var zombie = s.actors[15]
 zombie.zombie_skills.append_array(["memories","ransack"])
 zombie.x = p.x
 zombie.y = p.y
 zombie.down = false
 zombie.inside = false
 b.barricade = 4
 s.reindex()
 s.execute(zombie,"break")
 check(not s.location_description(p).contains("Pounding fists and scraping claws"),"Visual description omits audible breach attempts")
 check(s.messages.back().text.contains("Pounding fists") and not s.messages.back().text.contains(s.display_name(zombie)),"Inside attack feedback describes sound without identifying unseen attacker")
 ready(s,p)
 b.doors = true
 check(not s.location_description(p).contains("doors are closed"),"Closed doors omitted behind barricades")
 b.barricade = 0
 check(s.location_description(p).contains("doors have been secured"),"Unbarricaded closed doors are described")
 b.ruin = 3
 b.generator = true
 b.generator_hp = C.GENERATOR_HP
 b.fuel_until = s.minute+200
 p.inside = false
 check(s.location_description(p).contains("has been ruined") and not s.location_description(p).contains("portable generator"),"Closed exterior shows structural ruin while hiding equipment")
 b.doors = false
 check(s.location_description(p).contains("has been ruined") and not s.location_description(p).contains("portable generator"),"Exterior ruin clues do not reveal generator equipment")
 p.inside = true
 b.ruin = 0
 var text = s.location_description(p)
 check(text.contains("A portable generator has been set up here. It is running.") and not text.contains("lights are on"),"Interior uses the running generator sentence")
 zombie.inside = true
 ready(s,zombie)
 check(s.reason(zombie,"ransack").contains("generator"),"Installed generator prevents ransacking")
 b.generator_hp = 5
 check(s.generator_condition(b) == "dented","First generator damage is a dent")
 s.give_item(p,"fuel_can")
 ready(s,p)
 var inventory_before = p.inventory.size()
 check(not s.act("fuel").ok and p.inventory.size() == inventory_before,"Damaged generator cannot be refueled or consume fuel")
 check(s.act("repair_generator").ok and b.generator_hp == C.GENERATOR_HP,"Toolbox repairs generator")
 ready(s,p)
 var old_expiry = b.fuel_until
 check(s.act("fuel").ok and b.fuel_until == s.minute+C.FUEL_MINUTES and b.fuel_until > old_expiry,"Running generator is topped off to capacity")
 check(s.messages.back().text.contains("wasted"),"Fuel top-off explains waste")
 b.ruin = 0
 for i in range(100):
  if not b.generator: break
  ready(s,zombie)
  s.execute(zombie,"destroy_generator")
 check(not b.generator and b.generator_hp == 0 and b.fuel_until == 0 and not s.powered(b),"Destroying generator removes it and extinguishes light")
 p.inside = false
 ready(s,zombie)
 s.reindex()
 check(s.reason(zombie,"ransack").is_empty(),"Zombie can ransack after generator and defenders are removed")
 p.inside = true
 zombie.down = true
 zombie.dormant = true
 zombie.hp = 0
 s.reindex()
 ready(s,p)
 check(s.act("dump",zombie.id).ok and not zombie.inside and zombie.dormant,"Dumping moves a dormant body outside without waking it")
 ready(s,p)
 check(not s.act("dump",zombie.id).ok,"Outside bodies cannot be dumped twice")
 b.ruin = 0
 b.generator = true
 b.generator_hp = C.GENERATOR_HP
 b.fuel_until = s.minute+100
 var lit_chance = s.search_chance(b)
 b.fuel_until = 0
 check(lit_chance > s.search_chance(b),"Working lights improve search odds")
 var outcomes = {}
 var successes = 0
 for i in range(2000):
  p.inventory.clear()
  var outcome = s._search(p,b,"You")
  outcomes[outcome] = true
  if "Against the odds" in outcome: successes += 1
 check(outcomes.size() > 8 and successes > 0 and successes < 600,"Dark searches vary and sometimes celebrate a usable find")
 b.fuel_until = s.minute+100
 var lit_successes = 0
 for i in range(2000):
  p.inventory.clear()
  if "At last:" in s._search(p,b,"You"): lit_successes += 1
 check(lit_successes > successes,"Seeded lit searches find substantially more items")
 for site in s.blocks:
  if site.id != b.id: site.fuel_until = 0
 var outsider = {"x":b.x+2,"y":b.y}
 check(s.nearby_light(outsider).id == b.id,"Light attracts zombies beyond the immediately adjacent squares")
 s = isolated()
 p = s.player()
 p.ap = 20
 s.begin_rest(10)
 var minute_before = s.minute
 s.elapse(1.0)
 check(s.minute == minute_before+16,"Rest is twice the previous eightfold speed")
 s = isolated()
 p = s.player()
 p.ap = 0
 s.die(p)
 check(s.time_speed() == 32,"Death accelerates recovery automatically")
 s.elapse(1.0)
 check(s.minute >= 510 and s.time_speed() == 1,"Death acceleration stops once positive AP permits an indebted stand")
 s.elapse(12.0)
 check(p.down and p.ap >= 1 and s.time_speed() == 1,"Death acceleration stops when standing is affordable and ready")
 s = Sim.new()
 s.start(4815)
 var dormant = s.actors.filter(func(a): return a.get("dormant",false))
 check(dormant.size() == 15 and dormant.filter(func(a): return a.inside).size() > 0,"New games start with most zombies dormant and some indoors")
 var small_groups = true
 for a in s.actors:
  if not a.human: continue
  var allies = s.occupants(s.current_block(a),true).filter(func(other): return other.human and not other.down)
  small_groups = small_groups and allies.size() >= 2 and allies.size() <= 3
 check(small_groups,"Opening survivors work in groups of two or three")
 s.reanimate_bodies()
 var remaining = s.actors.filter(func(a): return a.get("dormant",false)).size()
 check(remaining > 0 and remaining < 15,"Daily reanimation wakes a seeded fraction rather than every body")
 var hidden_damage = s.blocks[44]
 hidden_damage.barricade_damage = 2
 hidden_damage.generator_hp = 3
 hidden_damage.last_pounding = s.minute
 check(s.save_to("user://test-survival-save.json") == OK,"New survival state saves")
 var loaded = Sim.new()
 check(loaded.load_from("user://test-survival-save.json").is_empty(),"New survival state loads")
 check(loaded.blocks[44].barricade_damage == 2 and loaded.blocks[44].generator_hp == 3 and JSON.stringify(loaded.actors) == JSON.stringify(s.actors),"Hidden damage, body schedule and NPC trip state survive loading")
 s.advance(1440)
 loaded.advance(1440)
 check(JSON.stringify(s.actors) == JSON.stringify(loaded.actors) and JSON.stringify(s.blocks) == JSON.stringify(loaded.blocks),"Daily waking and survivor trips replay exactly after save/load")
 s = isolated()
 var engineer = s.actors[2]
 engineer.human_skills = ["construction"]
 engineer.x = 4
 engineer.y = 4
 engineer.inside = true
 engineer.down = false
 engineer.next_trip = s.minute
 b = s.blocks[44]
 b.barricade = 4
 b.doors = true
 s.reindex()
 s._reset_npc_runtime()
 # Use the real scheduler so equipment preparation, trip retries and action
 # recovery elapse before checking travel. AP is recovered by the simulation.
 var trip_started: bool = false
 for _step in range(90*C.CLOCK_STEPS_PER_MINUTE):
  s.advance_steps(1)
  if engineer.supply_kind == "portable_generator" and engineer.supply_goal >= 0 and not engineer.inside:
   trip_started = true
   break
 check(trip_started,"Engineer plans a generator supply trip and leaves shelter")
 var supply_site: int = engineer.supply_goal
 var origin = Vector2i(engineer.x,engineer.y)
 var travelled: bool = false
 for _step in range(15*C.CLOCK_STEPS_PER_MINUTE):
  s.advance_steps(1)
  if Vector2i(engineer.x,engineer.y) != origin:
   travelled = true
   break
 check(travelled,"Survivor travels toward a resource site")
 # Isolate travel and installation policy from rare-item sampling, tested separately.
 if trip_started:
  s.search_tables[s.blocks[supply_site].type] = {"portable_generator":1.0}
 var completed = false
 for _step in range(180*C.CLOCK_STEPS_PER_MINUTE):
  s.advance_steps(1)
  if s.blocks[44].generator:
   completed = true
   break
 check(completed,"Engineer searches, returns home and installs a found generator")
 # The same maintainer can absorb isolated pressure, while a horde overwhelms them.
 var levels = []
 for attackers in [1,12]:
  var defense = isolated()
  var defender = defense.player()
  var shelter = defense.current_block(defender)
  var attacker = defense.actors[15]
  attacker.x = defender.x
  attacker.y = defender.y
  attacker.inside = false
  attacker.down = false
  shelter.barricade = 4
  defense.rng.seed = 909
  for round_index in range(60):
   for attack_index in range(attackers):
    if shelter.barricade == 0: break
    ready(defense,attacker)
    defense.execute(attacker,"break")
   if shelter.barricade == 0: break
   if shelter.barricade < 7 or shelter.barricade_damage > 0:
    ready(defense,defender)
    defense.execute(defender,"barricade")
  levels.append(shelter.barricade)
 check(levels[0] >= 4 and levels[1] == 0,"Repeated maintenance holds off a lone attacker but loses to twelve")
 s = isolated()
 engineer = s.actors[2]
 var doctor = s.actors[1]
 for ally in [engineer,doctor]:
  ally.x = 4
  ally.y = 4
  ally.inside = true
  ally.down = false
 b = s.blocks[44]
 b.barricade = 4
 b.doors = true
 b.generator = true
 b.generator_hp = C.GENERATOR_HP
 b.fuel_until = s.minute+1440
 doctor.inventory.clear()
 s.give_item(engineer,"first_aid_kit")
 s.reindex()
 s._npc_turn(engineer)
 check(not s.item_kind(doctor,"first_aid_kit").is_empty() and s.item_kind(engineer,"first_aid_kit").is_empty(),"Survivors share spare medical supplies with the group doctor")
 var standardized = true
 for kind in s.description_pools:
  for side in s.description_pools[kind]:
   for position in s.description_pools[kind][side]:
    if kind == "necrotech_lab" and side == "inside" and position in ["third","powered_third"]: continue
    for sentence in s.description_pools[kind][side][position]:
     standardized = standardized and sentence.length() >= 65 and sentence.length() <= 110
 check(standardized,"Runtime sentence choices have standardized lengths")
 s = isolated()
 p = s.player()
 doctor = s.actors[1]
 doctor.x = p.x
 doctor.y = p.y
 doctor.inside = p.inside
 doctor.down = false
 doctor.next_speech = s.now()
 s.next_dialogue = s.now()
 s.reindex()
 var ap_before = doctor.ap
 var recovery_before = doctor.busy_until
 var rng_before = s.rng.state
 s._maybe_speak(doctor)
 check(not doctor.speech.is_empty() and doctor.speech_until == s.now()+6,"Nearby NPC emits a timed speech line")
 check(s.messages.back().action == "speech" and s.messages.back().text.contains(doctor.speech),"NPC utterance appears in observed chat")
 check(doctor.ap == ap_before and doctor.busy_until == recovery_before and s.rng.state == rng_before,"Speech costs no energy or recovery and leaves gameplay RNG unchanged")
 var message_count = s.messages.size()
 s._maybe_speak(doctor)
 check(s.messages.size() == message_count,"Speech cooldown prevents chatter spam")
 engineer = s.actors[2]
 engineer.x = p.x
 engineer.y = p.y
 engineer.inside = p.inside
 engineer.down = false
 engineer.next_speech = s.now()
 s._maybe_speak(engineer)
 check(s.messages.size() == message_count,"Location cooldown spaces different NPC speakers")
 p.hp = 20
 var medical = s.speech_options(doctor)
 check("Hold still. I will take a look." in medical,"Doctor dialogue responds to an injured companion")
 p.hp = 50
 doctor.inside = not p.inside
 check(not s.speak(doctor,"You should not hear this."),"Speech does not pass through a closed location boundary")
 doctor.inside = p.inside
 zombie = s.actors[15]
 zombie.x = p.x
 zombie.y = p.y
 zombie.inside = p.inside
 zombie.down = false
 s.reindex()
 var monster_lines = s.speech_options(zombie)
 check("Grrrhh..." in monster_lines and not "Clean dressings are worth their weight in gold." in monster_lines,"Zombie dialogue uses noises instead of occupation speech")
 check(s.speak(zombie,"Mrrrraah...") and s.messages.back().category == "ENEMY","Zombie vocalization is identified in chat")
 var feed = preload("res://scripts/event_feed.gd").new()
 feed.reset()
 for i in range(6):
  s.log_event("Routine work.","ALLY",2,"repair")
 feed.ingest(s.messages)
 check(feed.rows.any(func(event): return event.action == "speech" and event.text.contains("Mrrrraah")),"NPC speech remains explicit in the activity feed")
 s.log_event("Pounding fists and scraping claws batter the barricades outside.","ENEMY",zombie.id,"breach_noise")
 feed.ingest(s.messages)
 check(feed.rows.back().action == "breach_noise" and feed.pending.is_empty(),"Breach sounds appear directly in chat instead of a routine summary")
 s.save_to("user://test-survival-save.json")
 loaded = Sim.new()
 var speech_load = loaded.load_from("user://test-survival-save.json")
 check(speech_load.is_empty() and loaded.actors[1].speech == doctor.speech and is_equal_approx(loaded.actors[1].speech_until,doctor.speech_until) and is_equal_approx(loaded.next_dialogue,s.next_dialogue),"Speech and cooldowns survive loading")
 s.die(p)
 check(not s.speak(zombie,"Hrrrngh...") and not s.speak(doctor,"Can you hear me?"),"Downed players cannot observe NPC chatter")
 print("SURVIVAL CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)

func entrance_rules() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 s.set_barricade_strength(b,9)
 for i in range(30):
  ready(s,p)
  s.act("barricade")
  if s.barricade_strength(b) == 10: break
 check(s.barricade_strength(b) == 10 and s.messages.back().text.contains("any further barricading will prevent survivors from climbing in"),"Very strongly barricaded warns about the outside entry limit")
 for item in p.inventory.duplicate():
  if item.kind == "toolbox": s.consume(p,item)
 b.ruin = 3
 ready(s,p)
 var before = p.ap
 check(not s.act("repair").ok and p.ap == before and b.ruin == 3 and s.reason(p,"repair").contains("toolbox"),"Building repairs require a toolbox and failed attempts spend nothing")
 b.ruin = 0
 b.generator = true
 b.generator_hp = 4
 check(not s.act("repair_generator").ok and b.generator_hp == 4 and p.ap == before,"Generator repairs also require a toolbox")
 s.give_item(p,"toolbox")
 check(s.act("repair_generator").ok and b.generator_hp == 6,"A carried toolbox enables generator repairs")
 b.type = "junkyard"
 b.barricade = 0
 b.doors = true
 p.human = false
 p.zombie_skills = []
 p.inside = false
 ready(s,p)
 check(s.act("enter").ok and p.inside,"Zombie without Memories of Life climbs through unbarricaded junkyard opening")
 b.doors = true
 ready(s,p)
 check(s.act("leave").ok and not p.inside,"Doorless junkyard exit needs no door-opening skill")
 b.barricade = 1
 ready(s,p)
 check(not s.act("enter").ok and not p.inside,"Junkyard barricades still block zombie entry")
 p.human = true
 p.inside = true
 b.barricade = 0
 b.doors = false
 check(s.reason(p,"close").contains("hole in the fence"),"Junkyard has no Close doors action")
 var description = s.location_description(p)
 check(description.contains("hole cut in the fence") and not description.contains("doors"),"Junkyard description identifies the fence opening rather than doors")
 b.doors = true
 s.save_to("user://test-survival-save.json")
 var loaded = Sim.new()
 check(loaded.load_from("user://test-survival-save.json").is_empty() and not loaded.blocks[b.id].doors,"Older junkyard door flags are cleared on load")
 b.type = "hospital"
 p.human = false
 p.inside = false
 ready(s,p)
 check(s.reason(p,"enter").contains("Memories of Life"),"Normal buildings retain the door skill requirement")
