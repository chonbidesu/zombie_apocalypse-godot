extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const AI = preload("res://scripts/npc_ai.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool,message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func fresh():
 var s = Sim.new()
 s.start(23)
 for a in s.actors:
  if a.id > 0:
   a.down = true
   a.human = false
   a.dormant = false
   a.x = 0
   a.y = 0
   a.inside = false
   a.ready_at = 999999
 s.reindex()
 return s
func ready(s,a):
 a.ap = 50
 a.busy_until = s.now()
func _initialize():
 combat_choices()
 scent_pursuit()
 undead_preference()
 live_planner_rules()
 var s = fresh()
 var a = s.actors[1]
 a.human = true
 a.down = false
 a.x = 4
 a.y = 4
 a.inside = false
 a.ap = 1
 a.busy_until = s.now()
 s.reindex()
 check(AI.retreat(s,a,true),"An exhausted survivor can use the local entrance")
 check(a.inside and a.x == 4 and a.y == 4,"Retreat enters the safe building rather than walking past it")
 check(a.ap == 0,"Retreat pays the regular entry AP")
 ready(s,a)
 a.hp = 40
 check(not AI.retreat(s,a,true),"Safe indoor survivors do not flee unnecessarily")
 var p = s.player()
 p.human_skills = ["first_aid","construction","lab_experience","body_building"]
 p.inventory.clear()
 p.xp = 0
 s.give_item(p,"first_aid_kit")
 s.execute(p,"heal",a.id)
 check(a.hp == 50 and p.xp == 5,"Healing another character awards 5 XP")
 p.hp = 40
 s.give_item(p,"first_aid_kit")
 s.execute(p,"heal",p.id)
 check(p.xp == 5,"Self healing does not award XP")
 a.hp = 50
 a.infected = true
 s.give_item(p,"first_aid_kit")
 s.execute(p,"heal",a.id)
 check(not a.infected and p.xp == 5,"Curing infection alone awards no healing XP")
 s.die(a)
 check(a.wants_revive and not a.human,"A former survivor can seek revival after death")
 check(not s.player().wants_revive,"NPC revival preferences never control the player")
 a.human_skills = ["body_building"]
 a.ready_at = s.minute
 s.give_item(p,"syringe")
 s.execute(p,"revive",a.id)
 check(a.human and not a.wants_revive,"Revival clears the request and changes form")
 ready(s,a)
 s.execute(a,"stand")
 check(a.hp == 30,"Revived Body Building characters stand with half their maximum HP")
 var b = s.current_block(p)
 a.human = false
 a.down = false
 a.inside = false
 a.wants_revive = true
 a.ap = 50
 s.player().home = b.id
 s.reindex()
 AI.seek_revival(s,a)
 check(not a.inside and a.ap == 50,"A zombie already at a clinic waits outside without spending AP")
 b.barricade = 0
 b.doors = false
 p.human_skills = []
 ready(s,p)
 check(not s.act("barricade").ok and p.ap == 50,"Loose barricade requires Construction or a carried pipe")
 s.give_item(p,"length_of_pipe")
 for attempt in range(40):
  if b.barricade > 0: break
  ready(s,p)
  s.act("barricade")
 check(s.barricade_strength(b) == 1 and b.doors and s.item_kind(p,"length_of_pipe").is_empty(),"A successful pipe barricade closes the doors and consumes the pipe")
 s.give_item(p,"length_of_pipe")
 ready(s,p)
 check(not s.act("barricade").ok and p.ap == 50 and not s.item_kind(p,"length_of_pipe").is_empty(),"A second pipe cannot reinforce an existing barricade")
 p.human_skills = ["construction"]
 check(s.reason(p,"barricade").is_empty(),"Construction permits reinforcement")
 s.give_item(p,"toolbox")
 b.ruin = 1
 b.generator = false
 a.inside = true
 s.reindex()
 ready(s,p)
 check(not s.reason(p,"repair").is_empty(),"Standing zombies prevent building repair")
 a.inside = false
 s.reindex()
 check(s.reason(p,"repair").is_empty(),"A cleared building can be repaired with the required tools")
 var xp = p.xp
 s.execute(p,"repair")
 check(p.xp == xp,"Basic ransack cleanup does not earn structural repair XP")
 b.generator = true
 b.generator_hp = 3
 xp = p.xp
 s.execute(p,"repair_generator")
 check(p.xp == xp+1 and b.generator_hp == 5,"Generator repairs earn XP and restore damage")
 b.radio = true
 b.radio_hp = 3
 xp = p.xp
 s.execute(p,"repair_radio")
 check(p.xp == xp+1 and b.radio_hp == 6,"Radio repairs earn XP")
 a.inside = true
 a.xp = 0
 b.radio_hp = 2
 s.execute(a,"destroy_radio")
 check(a.xp == 0 and b.radio,"Partial radio damage does not farm destruction XP")
 s.execute(a,"destroy_radio")
 check(a.xp == 5 and not b.radio,"Destroying a radio awards 5 XP once")
 b.generator_hp = 1
 for attempt in range(40):
  if not b.generator: break
  s.execute(a,"destroy_generator")
 check(a.xp == 10 and not b.generator,"Destroying a generator awards 5 XP once")
 var trip = fresh()
 var worker = trip.actors[1]
 worker.human = true
 worker.down = false
 worker.x = 5
 worker.y = 5
 worker.inside = true
 worker.home = 44
 worker.supply_goal = 55
 worker.supply_kind = "fuel_can"
 worker.inventory.clear()
 worker.hp = 50
 worker.ap = 13
 worker.busy_until = trip.now()
 trip.reindex()
 trip._npc_turn(worker)
 check(worker.supply_goal == 44 and worker.supply_kind.is_empty(),"A fruitless expedition reserves AP and turns home")
 check(not worker.inside and worker.ap == 12,"Returning from a search pays the normal exit cost")
 worker.x = 4
 worker.y = 4
 worker.inside = true
 worker.supply_goal = -1
 worker.human_skills = ["construction"]
 var shelter = trip.current_block(worker)
 shelter.generator = true
 shelter.generator_hp = 6
 shelter.fuel_until = trip.minute+1200
 shelter.barricade = 4
 trip.give_item(worker,"fuel_can")
 trip.reindex()
 ready(trip,worker)
 trip._npc_turn(worker)
 check(not trip.item_kind(worker,"fuel_can").is_empty() and shelter.fuel_until == trip.minute+1200,"NPCs conserve fuel when the generator is already well supplied")
 var graph = s.navigation
 var fort = s.blocks.filter(func(site): return not site.fort.is_empty() and site.type != "gatehouse")
 if not fort.is_empty():
  var path = graph.get_id_path(0,fort[0].id)
  check(not path.is_empty(),"The fort can be reached through navigation")
  var legal = true
  for i in range(1,path.size()):
   var one = s.blocks[path[i-1]]
   var two = s.blocks[path[i]]
   if one.fort != two.fort and one.type != "gatehouse" and two.type != "gatehouse": legal = false
  check(legal,"NPC routes cross fort walls only at a gatehouse")
 print("NPC BALANCE CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)

func combat_choices() -> void:
 var s = fresh()
 var a = s.actors[1]
 var t = s.actors[2]
 var p = s.player()
 a.human = true
 a.down = false
 a.hp = 50
 a.xp = 0
 a.x = p.x
 a.y = p.y
 a.inside = p.inside
 t.x = p.x
 t.y = p.y
 t.inside = p.inside
 t.down = false
 t.hp = 50
 t.wants_revive = false
 t.inventory.clear()
 t.zombie_skills = []
 a.inventory.clear()
 a.equipped = -1
 s.reindex()
 var full_skills = ["firearms","pistol_training","advanced_pistol","shotgun_training","advanced_shotgun","hand_to_hand","knife_combat","axe_proficiency"]
 for trained in [false,true]:
  a.human_skills = full_skills.duplicate() if trained else []
  p.human_skills = a.human_skills.duplicate()
  for kind in ["flare_gun","hockey_stick","fire_axe","knife","pistol","shotgun"]:
   check(s.attack_stats(a,t,"attack",{"kind":kind}) == s.attack_stats(p,t,"attack",{"kind":kind}),"NPC and player share weapon stats and skill bonuses: %s trained=%s" % [kind,trained])
  check(s.attack_stats(a,t,"attack") == s.attack_stats(p,t,"attack"),"NPC and player fists use identical stats")
 a.human_skills = []
 for kind in ["baseball_bat","hockey_stick","flare_gun","knife"]: s.give_item(a,kind)
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "flare_gun","Untrained NPC considers the flare's expected damage alongside melee")
 a.human_skills = ["hand_to_hand"]
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "hockey_stick","Hand-to-hand-trained NPC chooses the three-damage hockey stick")
 a.human_skills.append("knife_combat")
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "knife","Knife Combat changes the NPC's best weapon")
 s.give_item(a,"fire_axe")
 a.human_skills.append("axe_proficiency")
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "fire_axe","Fully trained axe beats trained knife in expected damage")
 s.give_item(a,"pistol")
 s.give_item(a,"shotgun")
 a.human_skills = full_skills.duplicate()
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "shotgun","Fully trained NPC selects a loaded shotgun")
 for item in a.inventory:
  if C.ITEMS[item.kind].has("capacity"): item.ammo = 0
 a.inventory = a.inventory.filter(func(item): return item.kind != "flare_gun")
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "fire_axe","Empty guns without matching ammunition lose to an available melee weapon")
 a.inventory.clear()
 s.give_item(a,"pistol")
 s.item_kind(a,"pistol").ammo = 0
 s.give_item(a,"pistol_clip")
 s.give_item(a,"fire_axe")
 a.equipped = -1
 a.human_skills = ["firearms","hand_to_hand","axe_proficiency"]
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "pistol","Reload selection uses six pistol shots per reload rather than an arbitrary discount")
 s.execute(a,"reload")
 check(s.item_kind(a,"pistol").ammo == 6,"NPC reload uses the same magazine capacity and action as the player")
 s.item_kind(a,"pistol").ammo = 0
 s.give_item(a,"pistol_clip")
 ready(s,a)
 a.ap = 1
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "fire_axe","NPC with one AP chooses an immediately usable attack rather than reload plus attack")
 a.inventory.clear()
 s.give_item(a,"knife")
 a.equipped = a.inventory.back().uid
 s.give_item(a,"shotgun")
 a.human_skills = []
 s.give_item(t,"flak_jacket")
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "shotgun" and s.attack_damage(t,s.attack_stats(a,t,"attack",s.item_by_uid(a,a.equipped))) == 8,"NPC compares damage after armour when choosing a weapon")
 t.inventory.clear()
 ready(s,a)
 AI.equip_best(s,a,t)
 check(s.item_by_uid(a,a.equipped).kind == "shotgun","Without armour the same NPC prefers the loaded shotgun")
 a.inventory.clear()
 s.give_item(a,"flare_gun")
 a.equipped = a.inventory.back().uid
 a.human_skills = ["firearms"]
 p.human = true
 p.hp = 50
 t.hp = 1000
 ready(s,a)
 s._npc_turn(a)
 check(a.last_action == "attack" and s.item_kind(a,"flare_gun").is_empty(),"NPC turn uses the shared single-use flare attack")
 a.human = false
 a.wants_revive = false
 a.inventory.clear()
 a.equipped = -1
 a.hp = 50
 a.zombie_skills = []
 t.human = true
 t.infected = false
 check(AI.zombie_attack(s,a,t) == "attack","Untrained zombie chooses claws: 0.5 expected damage beats a 0.4 bite")
 a.zombie_skills = ["vigour_mortis"]
 check(AI.zombie_attack(s,a,t) == "attack","Vigour Mortis alone leaves Bite locked")
 a.zombie_skills.append_array(["death_grip","rend_flesh","neck_lurch"])
 check(AI.zombie_attack(s,a,t) == "bite","Rend Flesh makes Bite the higher-damage option")
 a.zombie_skills.append("digestion")
 a.hp = 40
 check(AI.zombie_attack(s,a,t) == "bite","Wounded zombie values Digestion healing when choosing a bite")
 a.hp = s.max_hp(a)
 check(AI.zombie_attack(s,a,t) == "bite","Full-health zombie still uses the higher expected damage")
 t.infected = true
 t.hp = 1
 check(AI.zombie_attack(s,a,t) == "attack","Claws have a better chance to finish prey at one HP")
 t.hp = 1000
 a.zombie_skills.erase("neck_lurch")
 s.give_item(a,"baseball_bat")
 a.equipped = a.inventory.back().uid
 p.human = false
 p.down = true
 p.zombie_skills = a.zombie_skills.duplicate()
 check(s.attack_stats(a,t,"attack") == s.attack_stats(p,t,"attack") and s.attack_stats(a,t,"bite") == s.attack_stats(p,t,"bite"),"Player and NPC zombies use identical biological stats and bonuses")
 s.reindex()
 var claws_used = false
 for attempt in range(100):
  ready(s,a)
  a.xp = 0
  var hp = t.hp
  s._npc_turn(a)
  if t.hp < hp:
   claws_used = a.last_action == "attack" and hp-t.hp == 2
   break
 check(claws_used,"Zombie NPC actually deals trained claw damage while an inferior bat is equipped")

func undead_preference() -> void:
 var s = fresh()
 var p = s.player()
 var npc = s.actors[16]
 npc.x = p.x; npc.y = p.y; npc.inside = p.inside; npc.down = false; npc.hp = 30
 var source = s.current_block(p)
 var hotel = s.block_at(p.x+1,p.y)
 source.type = "hospital"
 hotel.type = "hotel"
 hotel.fort = ""; hotel.complex = ""
 s.set_barricade_strength(source,0)
 s.set_barricade_strength(hotel,0)
 s.rebuild_geography_index()
 s.reindex()
 ready(s,p)
 check(npc.prefers_undead and s.act("revive",npc.id).ok and npc.human and npc.down,"An originally undead NPC keeps their preference after revival")
 npc.ready_at = s.minute
 for step in range(6):
  ready(s,npc)
  s._npc_turn(npc)
  if not npc.human: break
 check(npc.x == hotel.x and npc.y == hotel.y and not npc.inside and npc.down and not npc.human and npc.last_action == "jump","Revived NPC walks to an accessible tall building and jumps")
 npc.ready_at = s.minute
 ready(s,npc)
 s._npc_turn(npc)
 check(not npc.down and not npc.human and npc.ap == 40,"NPC pays standing AP to return to play as a zombie")

func scent_pursuit() -> void:
 for skilled in [false,true]:
  var s = fresh()
  for site in s.blocks: site.generator = false
  var human = s.player()
  human.inside = false
  var zombie = s.actors[1]
  zombie.x = human.x-1
  zombie.y = human.y
  zombie.down = false
  zombie.hp = 50
  zombie.wants_revive = false
  zombie.memory = -1
  zombie.xp = 0
  zombie.zombie_skills = ["scent_trail"] if skilled else []
  ready(s,zombie)
  s.reindex()
  if skilled: s.start_scent_trail(zombie,human)
  s._npc_turn(zombie)
  check(zombie.memory == (s.current_block(human).id if skilled else -1),"Zombie NPC remembers a survivor from an active Scent Trail")

func live_planner_rules() -> void:
 var s = fresh()
 var p = s.player()
 p.inside = false
 var b = s.current_block(p)
 s.give_item(p,"spray_can")
 ready(s,p)
 check(s.act("tag",-1,{"text":" Revive point "}).ok and s.revive_sites.has(b.id),"Exterior spray marks a shared revive point")
 check(s.save_to("user://npc-planner-save.json") == OK,"Revive point saves")
 var loaded = Sim.new()
 check(loaded.load_from("user://npc-planner-save.json").is_empty() and loaded.revive_sites.has(b.id),"Revive point is indexed after loading")
 s.set_graffiti(b,"Out of service",true)
 check(not s.revive_sites.has(b.id),"Replacing the graffiti clears the point")

 var medic = s.actors[3]
 medic.human = true; medic.down = false; medic.x = p.x; medic.y = p.y; medic.inside = false
 medic.inventory.clear()
 s.give_item(medic,"dna_extractor")
 s.give_item(medic,"syringe")
 var patient = s.actors[1]
 patient.x = p.x; patient.y = p.y; patient.down = false; patient.hp = 50
 patient.wants_revive = true
 s.reindex()
 ready(s,medic)
 patient.zombie_skills = ["brain_rot"]
 s._npc_turn(medic)
 check(not patient.human and not s.item_kind(medic,"syringe").is_empty(),"Field medic keeps their syringe when screening detects Brain Rot")
 patient.zombie_skills = ["lurching_gait","ankle_grab"]
 medic.x = patient.x; medic.y = patient.y; medic.inside = patient.inside
 s.reindex()
 ready(s,medic)
 s._npc_turn(medic)
 check(medic.last_action == "extract" and patient.tagged_until > s.minute and not s.item_kind(medic,"syringe").is_empty(),"Medic screens a standing patient before injecting")
 check(s.dna_profile(patient).contains("Ankle Grab") and s.location_description(medic).contains("DNA:"),"DNA tag reveals the sampled zombie skills")
 patient.zombie_skills.append("death_grip")
 check(not s.dna_profile(patient).contains("Death Grip"),"DNA profile reports the sampled skills without live updates")
 ready(s,medic)
 s._npc_turn(medic)
 check(patient.human and patient.down and s.item_kind(medic,"syringe").is_empty(),"Screened patient is revived on the next action")
 check(s.cost(patient,"stand") == 1,"Ankle Grab reduces the cost of standing after revival")
 s.die(patient)
 patient.zombie_skills = ["lurching_gait"]
 patient.xp = 100
 patient.ap = 1
 s._schedule_npc(patient,s.clock_step+1)
 s.advance(1)
 check(patient.down and patient.wants_revive and patient.zombie_skills.has("ankle_grab") and patient.last_action == "learn","Human-origin zombies can buy Ankle Grab before standing")

 s = fresh()
 p = s.player()
 p.inside = false
 var caller = s.actors[15]
 caller.x = p.x; caller.y = p.y; caller.down = false; caller.dormant = false
 caller.zombie_skills = ["memories","bellow","scent_trail"]
 var recruit = s.actors[16]
 recruit.x = p.x+1; recruit.y = p.y; recruit.down = false; recruit.dormant = false
 s.reindex()
 ready(s,caller)
 s._npc_turn(caller)
 check(caller.last_action == "bellow" and recruit.memory == s.current_block(p).id and recruit.npc_signal == "groan","Bellow gives nearby zombies a shared hunt target")
 s.clock_step += 9
 check(not s._try(caller,"attack",p.id,{"unarmed":true}),"NPC action is blocked before the one-second boundary")
 s.clock_step += 1
 check(s._try(caller,"attack",p.id,{"unarmed":true}) and caller.trail_from == p.id,"Attack at the recovery boundary establishes Scent Trail from contact")

 s = fresh()
 p = s.player()
 b = s.current_block(p)
 p.down = true
 var engineer = s.actors[2]
 engineer.x = p.x; engineer.y = p.y; engineer.inside = true; engineer.human = true; engineer.down = false
 b.generator = true
 s.set_barricade_strength(b,10)
 s.give_item(engineer,"fuel_can")
 for id in range(15,19):
  var zombie = s.actors[id]
  zombie.x = p.x; zombie.y = p.y; zombie.down = false; zombie.dormant = false
 s.reindex()
 ready(s,engineer)
 s._npc_turn(engineer)
 check(not s.powered(b) and not s.item_kind(engineer,"fuel_can").is_empty(),"Lone maintainer keeps the lights off during a siege")
 for id in range(15,19): s.actors[id].down = true
 ready(s,engineer)
 s._npc_turn(engineer)
 check(s.powered(b),"Maintainer restores power once the entrance is safe")

 s = fresh()
 p = s.player()
 b = s.current_block(p)
 for site in s.blocks: site.generator = false
 s.set_barricade_strength(b,10)
 b.generator = true; b.fuel_until = s.minute+1440
 var walker = s.actors[15]
 walker.x = p.x-1; walker.y = p.y; walker.down = false; walker.inside = false
 s.reindex()
 ready(s,walker)
 s._npc_turn(walker)
 check(walker.x == p.x and walker.y == p.y and not walker.inside,"Visible light draws a zombie to a barricaded shelter")
 ready(s,walker)
 s._npc_turn(walker)
 check(walker.last_action == "break","Zombie attacks the lit shelter's barricades")

 s = fresh()
 engineer = s.actors[2]
 s.player().down = true
 engineer.x = 4; engineer.y = 4; engineer.inside = true; engineer.human = true; engineer.down = false
 engineer.human_skills = ["construction","free_running"]
 b = s.current_block(engineer)
 for y in range(3,6):
  for x in range(3,6): s.set_barricade_strength(s.block_at(x,y),21)
 s.set_barricade_strength(b,10)
 var entry = s.blocks[45]
 s.set_barricade_strength(entry,10)
 s.reindex()
 check(s.npc_planner._shelter_target(s,engineer,b,[engineer]) == 21 and b.npc_entry == entry.id,"Free Runners assign a legal VSB entrance before raising a shelter to EHB")
 check(entry.npc_ingress and s.npc_planner._shelter_target(s,engineer,entry,[engineer]) == 10,"The shared entry stays capped at VSB")
 s.set_barricade_strength(entry,8)
 check(s.npc_planner._shelter_target(s,engineer,b,[engineer]) == 10,"The entry is restored to VSB before raising the refuge")
 entry.ruin = 3
 check(s.npc_planner._shelter_target(s,engineer,b,[engineer]) == 10,"A collapsed route blocks further EHB work")

 s = fresh()
 p = s.player()
 p.human_skills.append("radio_operation")
 b = s.current_block(p)
 b.generator = true; b.fuel_until = s.minute+1440
 b.radio = true; b.radio_hp = 6; b.frequency = 29.0
 s.set_barricade_strength(b,10)
 engineer = s.actors[2]
 engineer.x = 5; engineer.y = 4; engineer.inside = true; engineer.human = true; engineer.down = false
 var station = s.current_block(engineer)
 station.radio = true; station.radio_hp = 6; station.frequency = 29.0
 s.reindex()
 ready(s,p)
 check(s.act("broadcast",-1,{"text":"Defend"}).ok and s.heard_defense_call(engineer).get("site",-1) == b.id,"Matching powered transmitter receives a defense call")
 station.frequency = 27.0
 check(s.heard_defense_call(engineer).is_empty(),"A mismatched frequency receives no call")
 s.give_item(engineer,"radio")
 ready(s,engineer)
 check(s._try(engineer,"tune",-1,{"frequency":29.0}),"NPC tunes its handheld radio to the station's frequency")
 check(s.heard_defense_call(engineer).get("site",-1) == b.id,"Matching handheld radio receives the same call")
 ready(s,engineer)
 check(s.npc_planner._respond_to_radio(s,engineer,station,0,0) and engineer.home == b.id,"A tuned builder travels to reinforce a defensible site")

 s = fresh()
 s.player().down = true
 b = s.blocks[45]
 medic = s.actors[3]
 medic.human = true; medic.down = false; medic.x = b.x; medic.y = b.y; medic.inside = true
 patient = s.actors[1]
 patient.down = false; patient.x = b.x; patient.y = b.y; patient.inside = true
 patient.tagged_until = s.minute+1440
 patient.tagged_skills = ["death_grip","infectious_bite"]
 s.reindex()
 ready(s,medic)
 s._npc_turn(medic)
 check(not patient.human and not s.item_kind(medic,"syringe").is_empty(),"A hostile DNA profile rules out opportunistic revival")
 patient.tagged_skills = ["ankle_grab"]
 ready(s,medic)
 s._npc_turn(medic)
 check(patient.human and patient.down,"A low-risk DNA profile permits revival at the lab")

 walker = s.actors[15]
 walker.x = b.x; walker.y = b.y; walker.inside = true; walker.down = false
 b.generator = false
 s.reindex()
 ready(s,walker)
 check(not s.reason(walker,"ransack").is_empty(),"A standing survivor blocks ransacking")
 medic.down = true
 check(s.reason(walker,"ransack").is_empty(),"Ransack becomes legal once no survivor is standing inside")
