extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const AI = preload("res://scripts/npc_ai.gd")
class ControlledFall extends Sim:
 var fall = false
 var rolls = 0
 func roll_free_run_fall() -> bool:
  rolls += 1
  return fall

var s
var p: Dictionary
var checks = 0
var failures = 0

func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(text)

func place(site: Dictionary, inside: bool, hp: int = 50, human: bool = true, runner: bool = true) -> void:
 p.x = site.x; p.y = site.y; p.inside = inside; p.hp = hp
 p.human = human; p.down = false; p.infected = false; p.ap = 50
 p.human_skills = ["free_running"] if runner else []
 p.zombie_skills = ["lurching_gait","ransack"]
 p.scout_site = -1
 p.busy_until = s.now()
 s.reindex()

func move(target: Dictionary, data: Dictionary = {}) -> Dictionary:
 data = data.duplicate()
 data.dx = target.x-p.x; data.dy = target.y-p.y
 return s.act("move",-1,data)

func _initialize() -> void:
 s = ControlledFall.new()
 s.start(662)
 for a in s.actors:
  if a.id != 0: a.x = 0; a.y = 0; a.inside = false; a.down = true
 p = s.player()
 var origin = s.block_at(4,4)
 var target = s.block_at(5,4)
 for b in [origin,target]:
  b.type = "office"; b.complex = ""; b.fort = ""; b.zoo = ""; b.generator = false; b.doors = false
 origin.ruin = 0; target.ruin = 3
 s.set_barricade_strength(target,21)
 for fall in [false,true]:
  s.fall = fall
  place(origin,true)
  var rolls = s.rolls
  check(move(target).ok and p.x == target.x and not p.inside and p.ap == 49,"Ruin Free Run reaches exterior for one AP")
  check(s.rolls == rolls+1 and p.hp == (45 if fall else 50),"Fall roll governs exactly five HP injury")
  check(s.messages.back().text.contains("You find your route blocked by a collapsed wall, and are forced to street level."),"Collapsed-wall notification is explicit")
  check(s.messages.back().text.contains("You lose your footing on the ruined building, and fall to the street below, injuring yourself.") == fall,"Fall notification appears only with injury")
 for hp in range(1,7):
  s.fall = true
  place(origin,true,hp)
  check(move(target).ok and p.hp == maxi(1,hp-5) and p.human and not p.down,"Fall cannot kill even at low HP")
 # Street walking, non-runners and undead do not attempt a roof crossing.
 for values in [[false,true,true],[true,true,false],[true,false,true]]:
  place(origin,values[0],50,values[1],values[2])
  var rolls = s.rolls
  check(move(target).ok and p.hp == 50 and s.rolls == rolls,"Walking to a ruin does not trigger fall damage")
 place(origin,true)
 var rolls = s.rolls
 check(move(target,{"free_run":false}).ok and p.hp == 50 and s.rolls == rolls,"Explicit ground move avoids a roof attempt")
 # Ruin only blocks the destination, not the starting roof.
 place(target,true)
 rolls = s.rolls
 check(move(origin).ok and p.inside and p.hp == 50 and p.ap == 49 and s.rolls == rolls,"Free Running out of a ruin is safe")
 # One building envelope remains internally connected, including ruined corners.
 for kind in ["mall","cathedral","mansion","power_station","stadium"]:
  for b in [origin,target]: b.type = kind; b.complex = "Same "+kind
  for human in [true,false]:
   place(origin,true,50,human,false)
   rolls = s.rolls
   check(move(target).ok and p.inside and p.hp == 50 and s.rolls == rolls,"Shared building interior avoids ruin drop: "+kind)
 origin.type = "mall"; target.type = "mall"; origin.complex = "Mall A"; target.complex = "Mall A"
 place(origin,true,50,true,false)
 p.route = []; p.route_goal = -1
 s.rebuild_geography_index()
 rolls = s.rolls
 check(AI.go(s,p,target) and p.inside and s.rolls == rolls,"NPC stays inside a ruined corner of the same mall")
 # Different mall identities are separate roofs and do trigger the exception.
 target.complex = "Mall B"
 place(origin,true)
 check(move(target).ok and not p.inside and p.hp == 45,"Different mall envelopes are not safe internal links")
 # Ransacking from inside can coexist with EHB; normalization must preserve it.
 target.ruin = 0; target.type = "office"; target.complex = ""
 place(target,true,50,false,false)
 for i in range(5):
  p.busy_until = s.now()
  check(s.act("ransack").ok,"Inside zombie may ransack with intact barricades")
 p.busy_until = s.now()
 check(s.act("ruin").ok,"Sixth hit ruins the building")
 s.initialize_block(target)
 check(target.ruin == 3 and s.barricade_strength(target) == 21,"EHB and ruin coexist after normalization")
 # Check the real chance separately from the controlled injury branches.
 var real = Sim.new()
 real.rng.seed = 2201
 var falls = 0
 for i in range(10000):
  if real.roll_free_run_fall(): falls += 1
 check(falls > 1850 and falls < 2150,"Seeded fall rate is twenty percent over ten thousand attempts")
 print("FREE RUNNING CHECKS: %d FAILURES: %d" % [checks,failures])
 quit(1 if failures else 0)
