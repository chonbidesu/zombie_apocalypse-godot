extends RefCounted
const C = preload("res://scripts/catalog.gd")
const Memory = preload("res://scripts/npc_utility/location_memory.gd")

class Routes extends AStar2D:
 func _compute_cost(_from_id: int,_to_id: int) -> float: return 1.0
 func _estimate_cost(from_id: int,to_id: int) -> float:
  var delta = (get_point_position(from_id)-get_point_position(to_id)).abs()
  return maxf(delta.x,delta.y)

static func build_navigation(s) -> AStar2D:
 var graph = Routes.new()
 for b in s.blocks: graph.add_point(b.id,Vector2(b.x,b.y))
 for b in s.blocks:
  for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
   var x = b.x+delta.x
   var y = b.y+delta.y
   if x < 0 or x >= s.width or y < 0 or y >= s.height: continue
   var other = s.block_at(x,y)
   # Fort walls allow one-way ground exits, while every incoming edge still
   # terminates at a gatehouse. Never turn a legal exit into an entry shortcut.
   if b.fort == other.fort or other.fort.is_empty() or other.type == "gatehouse": graph.connect_points(b.id,other.id,false)
   if b.fort == other.fort or b.fort.is_empty() or b.type == "gatehouse": graph.connect_points(other.id,b.id,false)
 return graph

static func go(s,a: Dictionary,goal: Dictionary) -> bool:
 var b = s.current_block(a)
 if b.id == goal.id: return false
 if a.route_goal != goal.id or a.route.is_empty():
  a.route = Array(s.query_route(b.id,goal.id))
  a.route_goal = goal.id
  if not a.route.is_empty(): a.route.pop_front()
 if a.route.is_empty(): return false
 var next = s.blocks[int(a.route[0])]
 if a.human and not a.inside and next.id != goal.id and s.occupants(next,false).any(func(t): return not t.human and not t.down):
  var avoided: Array[int] = []
  for y in range(maxi(0,a.y-1),mini(s.height,a.y+2)):
   for x in range(maxi(0,a.x-1),mini(s.width,a.x+2)):
    var site = s.block_at(x,y)
    if site.id in [b.id,goal.id]: continue
    if s.occupants(site,false).any(func(t): return not t.human and not t.down):
     s.navigation.set_point_disabled(site.id,true)
     avoided.append(site.id)
  var safer = Array(s.query_route(b.id,goal.id))
  for id in avoided: s.navigation.set_point_disabled(id,false)
  if safer.size() > 1:
   safer.pop_front()
   a.route = safer
   next = s.blocks[int(a.route[0])]
 if maxi(absi(next.x-a.x),absi(next.y-a.y)) != 1:
  a.route.clear()
  return false
 if b.type == "gatehouse" and not b.fort.is_empty() and not a.inside and next.fort == b.fort:
  return s._try(a,"enter")
 var free_run = s.can_free_run_between(a,b,next)
 if a.inside and b.type != "gatehouse" and not free_run and not s.shared_building_interior(b,next):
  if s._try(a,"leave"): return true
  # Barricades cannot trap an occupant: a blocked Leave button still permits a
  # map-click ground exit, for NPCs as well as the player.
 var moved = s._try(a,"move",-1,{"dx":next.x-a.x,"dy":next.y-a.y,"free_run":free_run})
 if moved: a.route.pop_front()
 else: a.route.clear()
 return moved

static func shelter_worker(s,a: Dictionary) -> bool:
 return s.has_skill(a,"construction") or a.job in ["Engineer","Scientist","Firefighter","Consumer","NecroTech Lab Assistant"]

static func return_to_undeath(s,a: Dictionary) -> bool:
 var here = s.current_block(a)
 if here.type in C.TALL_BUILDINGS:
  if a.inside: return s._try(a,"jump")
  if s._try(a,"enter"): return true
 if not a.route.is_empty() and a.route_goal in range(s.blocks.size()):
  var goal = s.blocks[a.route_goal]
  if goal.type in C.TALL_BUILDINGS and goal.barricade <= 4 and go(s,a,goal): return true

 var candidates: Array = []
 for kind in C.TALL_BUILDINGS:
  for site in s.sites_by_type.get(kind,[]):
   if site.id != here.id and site.barricade <= 4:
    candidates.append({"site":site,"distance":maxi(absi(site.x-a.x),absi(site.y-a.y))})
 candidates.sort_custom(func(left,right):
  if left.distance != right.distance: return left.distance < right.distance
  return left.site.id < right.site.id)
 var best: Dictionary = {}
 var best_path: Array = []
 for candidate in candidates:
  if not best_path.is_empty() and candidate.distance >= best_path.size()-1: break
  var path = Array(s.query_route(here.id,candidate.site.id))
  if not path.is_empty() and (best_path.is_empty() or path.size() < best_path.size()):
   best = candidate.site
   best_path = path
 if best.is_empty(): return false
 best_path.pop_front()
 a.route = best_path
 a.route_goal = best.id
 return go(s,a,best)

static func keeper(s,a: Dictionary) -> bool:
 if not s.has_skill(a,"construction"): return false
 if not s.actors.any(func(t): return t.id != a.id and t.human and not t.down and t.home == a.home): return false
 for other in s.actors:
  if other.id == a.id: break
  if other.human and not other.down and other.home == a.home and s.has_skill(other,"construction"): return false
 return true

static func regroup(s,a: Dictionary) -> bool:
 if s.actors.any(func(t): return t.id != a.id and t.human and not t.down and t.home == a.home): return false
 var here = s.current_block(a)
 var closest: Dictionary = {}
 var distance = 13
 for id in s.spatial:
  var site = s.blocks[id]
  var d = maxi(absi(site.x-a.x),absi(site.y-a.y))
  # Ties use actor order so rebuilding the spatial index after a load is deterministic.
  if d > distance or (d == distance and (closest.is_empty() or s.spatial[id][0] >= s.spatial[closest.id][0])): continue
  if d+2 > a.ap or not s.is_building(site) or site.ruin > 0 or site.barricade > 4: continue
  if site.fort != here.fort: continue
  var others = s.occupants(site,true)
  if others.any(func(t): return not t.human and not t.down): continue
  var friends = others.filter(func(t): return t.id != a.id and t.human and not t.down).size()
  if friends < 1 or friends > 2: continue
  closest = site
  distance = d
 if closest.is_empty(): return false
 a.home = closest.id
 a.supply_goal = closest.id
 a.supply_kind = ""
 if closest.id == here.id: return false
 return go(s,a,closest)

static func group_need(s,a: Dictionary) -> String:
 var home = s.blocks[a.home]
 var allies = s.actors.filter(func(t): return t.human and not t.down and t.home == a.home and t.id != a.id)
 if allies.is_empty(): return ""
 var need = "portable_generator" if not home.generator else ("fuel_can" if home.fuel_until-s.minute < 360 else "")
 if need.is_empty(): return ""
 if allies.any(func(t): return not s.item_kind(t,need).is_empty() or t.supply_kind == need): return ""
 return need

static func retreat(s,a: Dictionary,forced: bool = false, siege: bool = false) -> bool:
 if not forced and a.ap > 8: return false
 var here = s.current_block(a)
 var hostiles = s.occupants(here,a.inside).any(func(t): return not t.human and not t.down)
 if a.inside and not hostiles and not siege: return false
 if not a.inside and s.is_building(here) and here.ruin == 0 and here.barricade <= 4 and (not hostiles or here.barricade >= 2) and not s.occupants(here,true).any(func(t): return not t.human and not t.down):
  a.home = here.id
  a.supply_goal = -1
  a.supply_kind = ""
  return s._try(a,"enter")
 var best: Dictionary = {}
 var best_score = INF
 var radius = mini(8,maxi(1,a.ap-1))
 for y in range(maxi(0,a.y-radius),mini(s.height,a.y+radius+1)):
  for x in range(maxi(0,a.x-radius),mini(s.width,a.x+radius+1)):
   var site = s.block_at(x,y)
   if not s.is_building(site) or site.ruin > 0 or site.barricade > 4 or site.id == here.id: continue
   if site.fort != here.fort: continue
   if s.occupants(site,true).any(func(t): return not t.human and not t.down): continue
   if s.occupants(site,false).any(func(t): return not t.human and not t.down and not t.wants_revive): continue
   var friends = s.occupants(site,true).filter(func(t): return t.human and not t.down).size()
   var distance = maxi(absi(x-a.x),absi(y-a.y))
   var score = distance+(4 if friends == 0 else 0)+(4 if site.barricade < 2 else 0)
   if site.id == a.home: score -= 2
   score -= 2.0*s.npc_planner.memory.lookup(a.id,site.id,Memory.Kind.SHELTER,s.minute)
   if score < best_score:
    best = site
    best_score = score
 if best.is_empty(): return false
 a.home = best.id
 a.supply_goal = best.id
 a.supply_kind = ""
 return go(s,a,best)

static func expected_damage(s,target: Dictionary,stats: Dictionary) -> float:
 return float(stats.hit)/100.0*mini(target.hp,s.attack_damage(target,stats))

static func equip_best(s,a: Dictionary,target: Dictionary) -> bool:
 var best_score = expected_damage(s,target,s.attack_stats(a,target,"attack"))
 var best: Dictionary = {}
 for item in a.inventory:
  var def = C.ITEMS[item.kind]
  if not def.has("damage"): continue
  var factor = 1.0
  if def.has("capacity") and item.ammo == 0:
   if a.ap < s.cost(a,"reload")+s.cost(a,"attack") or s.item_kind(a,def.ammo_kind).is_empty(): continue
   # Compare a reload plus the shots it supplies, using actual reload AP.
   var shots = float(mini(def.capacity,def.reload_amount))
   factor = shots/(shots+s.cost(a,"reload"))
  var stats = s.attack_stats(a,target,"attack",item)
  var score = expected_damage(s,target,stats)*factor
  if score > best_score or (is_equal_approx(score,best_score) and item.uid == a.equipped):
   best_score = score
   best = item
 var desired = int(best.get("uid",-1))
 if desired != a.equipped:
  var selected = desired if desired >= 0 else a.equipped
  if selected >= 0: return s._try(a,"equip",-1,{"uid":selected})
 return false

static func zombie_attack(s,a: Dictionary,target: Dictionary) -> String:
 if not s.has_skill(a,"neck_lurch"): return "attack"
 var claws = s.attack_stats(a,target,"attack")
 var bite = s.attack_stats(a,target,"bite")
 var claw_score = expected_damage(s,target,claws)
 var bite_score = expected_damage(s,target,bite)
 var bite_damage = mini(target.hp,s.attack_damage(target,bite))
 if s.has_skill(a,"digestion"):
  bite_score += float(bite.hit)/100.0*mini(maxi(0,s.max_hp(a)-a.hp),bite_damage)
 # Infection adds one prospective point of damage on the survivor's next action.
 var can_infect = target.human and not target.infected and target.hp > bite_damage and s.has_skill(a,"infectious_bite")
 if can_infect: bite_score += float(bite.hit)/100.0
 return "bite" if bite_score > claw_score or (can_infect and is_equal_approx(bite_score,claw_score)) else "attack"

static func prey(s,a: Dictionary,people: Array) -> Dictionary:
 if a.grasp_target >= 0:
  var held = people.filter(func(t): return t.id == a.grasp_target and t.human and not t.down)
  if not held.is_empty(): return held[0]
 var choices = people.filter(func(t): return t.human and not t.down)
 if choices.is_empty(): return {}
 if s.has_skill(a,"scent_fear"):
  choices.sort_custom(func(one,two): return one.hp < two.hp)
  return choices[0]
 return choices[a.id%choices.size()]

static func can_call(s,a: Dictionary,people: Array) -> bool:
 var prey_count = people.filter(func(t): return t.human and not t.down).size()
 if a.next_groan > s.minute or not (s.has_skill(a,"feeding_groan") or s.has_skill(a,"bellow")): return false
 if prey_count == 0: return false
 var radius = 10 if s.has_skill(a,"bellow") and (prey_count >= 25 or not s.has_skill(a,"feeding_groan")) else 6
 for y in range(maxi(0,a.y-radius),mini(s.height,a.y+radius+1)):
  for x in range(maxi(0,a.x-radius),mini(s.width,a.x+radius+1)):
   if x == a.x and y == a.y: continue
   for id in s.spatial.get(y*s.width+x,[]):
    var other: Dictionary = s.actors[id]
    if not other.human and not other.down and not other.wants_revive: return true
 return false

static func seek_revival(s,a: Dictionary) -> void:
 # Public clinic locations replace the multiplayer revive-point coordination.
 var clinic: Dictionary = {}
 var distance = INF
 for medic in s.actors:
  if not medic.human or medic.down or not s.has_skill(medic,"lab_experience"): continue
  var site = s.blocks[medic.home]
  if s.has_skill(a,"brain_rot") and (site.type != "necrotech_lab" or not s.powered(site)): continue
  var d = maxi(absi(site.x-a.x),absi(site.y-a.y))
  if d < distance:
   clinic = site
   distance = d
 if clinic.is_empty():
  for site in s.sites_by_type.get("necrotech_lab",[]):
   var d = maxi(absi(site.x-a.x),absi(site.y-a.y))
   if d < distance:
    clinic = site
    distance = d
 if clinic.is_empty(): return
 if s.current_block(a).id != clinic.id:
  go(s,a,clinic)
 elif a.inside:
  if not s._try(a,"leave") and s.current_block(a).barricade > 0: s._try(a,"break")

