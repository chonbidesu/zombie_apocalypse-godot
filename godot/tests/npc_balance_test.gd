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
 s.give_item(p,"length_of_pipe")
 ready(s,p)
 check(s.reason(p,"barricade").is_empty(),"Baseline barricading is available without Construction")
 for attempt in range(40):
  if b.barricade > 0: break
  s.execute(p,"barricade")
 check(b.barricade == 1 and b.doors,"The first successful barricade automatically closes normal doors")
 check(not s.item_kind(p,"length_of_pipe").is_empty(),"Baseline construction uses building materials")
 ready(s,p)
 s.set_barricade_strength(b,7)
 for attempt in range(40):
  if s.barricade_strength(b) > 7: break
  ready(s,p)
  s.act("barricade")
 check(s.barricade_strength(b) == 8 and s.barricade_description(b) == "strongly barricaded","Untrained survivors can build to Strongly Barricaded")
 ready(s,p)
 check(not s.act("barricade").ok and p.ap == 50,"Construction is required to build past Strongly Barricaded")
 p.human_skills = ["construction"]
 check(s.reason(p,"barricade").is_empty(),"Construction permits the next reinforcement")
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
  s._npc_turn(zombie)
  check(zombie.memory == (s.current_block(human).id if skilled else -1),"Zombie NPC pursues a survivor only with Scent Trail")
