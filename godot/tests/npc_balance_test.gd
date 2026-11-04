extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const AI = preload("res://scripts/npc_ai.gd")
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
 check(s.reason(p,"barricade").is_empty(),"A pipe allows crude barricading without Construction")
 for attempt in range(40):
  if b.barricade > 0: break
  s.execute(p,"barricade")
 check(b.barricade == 1 and b.doors,"The first successful barricade closes normal doors")
 check(s.item_kind(p,"length_of_pipe").is_empty(),"A successful crude barricade consumes its pipe")
 check(not s.reason(p,"barricade").is_empty(),"Further barricading requires Construction")
 p.human_skills = ["construction"]
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
 check(p.xp == xp+1,"Building repairs earn XP")
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
