extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const AI = preload("res://scripts/npc_ai.gd")
var s
var p: Dictionary
var checks = 0
var failures = 0

func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(text)

func place(site: Dictionary, inside: bool = false, human: bool = true, runner: bool = false) -> void:
 p.x = site.x; p.y = site.y; p.inside = inside; p.human = human
 p.down = false; p.hp = 50; p.infected = false
 p.human_skills = ["free_running"] if runner else []
 p.zombie_skills = ["lurching_gait"]
 p.busy_until = s.now(); p.ap = 50
 s.reindex()

func move(site: Dictionary, options: Dictionary = {}) -> Dictionary:
 p.busy_until = s.now()
 var data = {"dx":site.x-p.x,"dy":site.y-p.y}
 data.merge(options,true)
 return s.act("move",-1,data)

func _initialize() -> void:
 s = Sim.new()
 check(s.start(44,"Volunteer",{"mode":"malton","survivors":2,"zombies":2}).is_empty(),"Load original fort plans")
 p = s.player()
 for name in ["Fort Creedy","Fort Perryn"]: fort_cases(name)
 # The no-trapping rule also holds for normal buildings and NPCs.
 var site = s.block_at(50,50)
 site.type = "office"; site.fort = ""; site.complex = ""; site.doors = false
 var target = s.block_at(51,50)
 target.type = "street"; target.fort = ""; target.complex = ""
 for human in [true,false]:
  place(site,true,human)
  s.set_barricade_strength(site,21)
  check(not s.act("leave").ok and p.ap == 50,"EHB Leave button rejects without AP loss")
  check(s.action_feedback(p,"leave",-1,{},true).is_empty(),"Leave remains a visible attempt with explanatory feedback")
  check(move(target).ok and not p.inside,"Map-click exit cannot trap a building occupant")
 place(site,true,false)
 s.rebuild_geography_index()
 p.route = []; p.route_goal = -1
 check(AI.go(s,p,target) and p.x == target.x and not p.inside,"NPC uses a map exit when barricades block Leave")
 print("FORT RULE CHECKS: %d FAILURES: %d" % [checks,failures])
 quit(1 if failures else 0)

func fort_cases(name: String) -> void:
 var gate: Dictionary = s.fort_gatehouse(name)
 var east = name == "Fort Creedy"
 var outside = s.block_at(gate.x+(1 if east else 0),gate.y+(0 if east else 1))
 var inner = s.block_at(gate.x-(1 if east else 0),gate.y-(0 if east else 1))
 var other = s.block_at(inner.x-1,inner.y)
 if other.fort != name: other = s.block_at(inner.x,inner.y-1)
 var wall_target = s.block_at(outside.x+(0 if east else 1),outside.y+(-1 if east else 0))
 wall_target.type = "office"; wall_target.ruin = 0
 outside.type = "office"; outside.ruin = 0
 s.set_barricade_strength(gate,0)
 place(outside,false)
 check(move(gate).ok and not p.inside,"Approach gatehouse exterior: "+name)
 check(not move(inner).ok and p.ap == 49,"Exterior gatehouse cannot shortcut into compound")
 p.busy_until = s.now()
 check(s.act("enter").ok and p.inside,"Must enter gatehouse first")
 p.human_skills = ["free_running"]
 check(move(inner).ok and not p.inside,"Leaving gatehouse into compound lands outside target")
 place(wall_target,true,true,true)
 var through_wall = s.block_at(wall_target.x-(1 if east else 0),wall_target.y-(0 if east else 1))
 check(not move(through_wall).ok and p.ap == 50,"No outside Free Running through perimeter")
 check(s.navigation.are_points_connected(through_wall.id,wall_target.id,false) and not s.navigation.are_points_connected(wall_target.id,through_wall.id,false),"NPC perimeter edge permits exit and forbids entry")
 for human in [true,false]:
  for indoors in [false,true]:
   place(through_wall,indoors,human,true)
   check(move(wall_target).ok and not p.inside,"Every perimeter square permits human/zombie map exits")
 place(through_wall,true,true,true)
 check(not move(wall_target,{"free_run":true}).ok and p.ap == 50,"Perimeter exit does not permit Free Running through the wall")
 place(outside,true,true,true)
 check(not move(gate).ok and p.ap == 50,"No outside Free Running into low gatehouse entrance")
 check(move(gate,{"free_run":false}).ok and not p.inside,"Ground approach remains possible from an outside building")
 # Internal buildings may be crossed on foot, or traversed indoors by Free Running.
 var armoury: Dictionary = s.blocks.filter(func(b): return b.fort == name and b.type == "armoury")[0]
 var adjacent: Dictionary = s.block_at(armoury.x-1,armoury.y)
 var next: Dictionary = s.block_at(armoury.x-1,armoury.y-1)
 for runner in [false,true]:
  place(adjacent,true,true,runner)
  check(move(next).ok and p.inside == runner,"Internal Free Running differs from walking")
 place(adjacent,true,true,true)
 check(move(armoury).ok and not p.inside,"Armoury entry requires its ground door")
 place(armoury,true,true,true)
 check(move(adjacent).ok and p.inside,"Free Running out of Armoury is allowed")
 for strength in [10,11,21]:
  s.set_barricade_strength(gate,strength)
  place(gate,true,true,true)
  check(move(outside).ok and p.inside == (strength <= 10),"Automatic gate exit uses ground above VSB")
  place(gate,true,true,true)
  var attempt = move(outside,{"free_run":true})
  check(attempt.ok == (strength <= 10) and p.ap == (49 if strength <= 10 else 50),"Explicit Free Running respects gate barricades")
  for human in [true,false]:
   place(inner,false,human)
   check(move(gate).ok and p.inside,"Internal gate entry ignores exterior barricades")
   check(move(outside).ok and not p.inside,"Human/zombie map exit is never trapped by gate barricades")
  place(gate,false,true)
  p.busy_until = s.now()
  check(s.act("enter").ok == (strength <= 10),"Getting back into fort still respects entry barricades")
 # Dumping from a building or the yard relocates actor and body through the gate.
 var body: Dictionary = s.actors[1]
 for indoors in [true,false]:
  var origin: Dictionary = adjacent if indoors else s.blocks.filter(func(b): return b.fort == name and b.type == "exercise_yard")[0]
  place(origin,indoors)
  body.x = p.x; body.y = p.y; body.inside = indoors
  body.human = false; body.down = true; body.hp = 0; body.dormant = true
  p.scout_site = origin.id; p.scout_used = 0; p.scout_day = s.minute/1440
  s.reindex()
  check(s.cost(p,"dump") == 5,"Fort dump costs exactly five AP")
  p.ap = 0
  check(not s.act("dump",body.id).ok and p.x == origin.x and body.x == origin.x,"Unaffordable dump has no relocation effects")
  p.ap = 50
  check(s.act("dump",body.id).ok and p.ap == 45,"Fort dump spends exactly five AP")
  check(p.x == gate.x and p.y == gate.y and p.inside,"Dumper ends inside gatehouse")
  check(body.x == gate.x and body.y == gate.y and not body.inside and body.dormant,"Body is outside gatehouse and remains dormant")
  p.busy_until = s.now()
  check(not s.act("dump",body.id).ok,"Body outside gatehouse cannot be dumped twice")
