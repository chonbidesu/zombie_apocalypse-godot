extends RefCounted
## UI-independent rules. Player and AI use the same validation and transactions.
const C = preload("res://scripts/catalog.gd")
const Dialogue = preload("res://scripts/dialogue.gd")
const Extended = preload("res://scripts/extended_rules.gd")
const World = preload("res://scripts/world_builder.gd")
const AI = preload("res://scripts/npc_ai.gd")
var navigation: AStar2D
var survivor_ratio: float = 0.5
var width: int = 10
var height: int = 10
var world_mode: String = "sandbox"
var world_title: String = "Dulston"
var world_config: Dictionary = {}
var geography_source: Dictionary = {}
var sites_by_type: Dictionary = {}
var mast_sites: Array = []
var complex_bounds: Dictionary = {}

var rng = RandomNumberGenerator.new()
var search_tables: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/search_tables.json"))
var description_pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/descriptions.json"))
var blocks: Array = []
var actors: Array = []
var messages: Array = []
var minute: int = 480
var clock_step: int = 4800
var clock_fraction: float = 0.0
var resting: bool = false
var rest_target: int = 0
var rest_end_step: int = 0
var last_rest_notice: String = ""
var event_sequence: int = 0
var world_seed: int = 4815
var next_item_id: int = 1
var scan_report: String = "No scan yet. Use a powered NecroTech lab."
var scan_minute: int = -1
var spatial: Dictionary = {}
var npc_cursor: int = 0
var next_dialogue: float = 500.0
var sense_report: String = "No recent field report."
var metrics: Dictionary = {"attacks":0, "deaths":0, "revivals":0, "npc_actions":0}

func start(seed_value: int = 4815, occupation: String = "Volunteer", config: Dictionary = {}) -> String:
 var geography = {}
 if config.get("mode","sandbox") != "sandbox":
  geography = World.build(config,seed_value,_read_names())
  if geography.has("error"): return geography.error
 width = 10
 height = 10
 world_mode = "sandbox"
 world_title = "Dulston"
 world_config = config.duplicate(true)
 geography_source = {}
 world_seed = seed_value
 rng.seed = seed_value
 blocks.clear()
 actors.clear()
 messages.clear()
 minute = 480
 clock_step = 4800
 clock_fraction = 0.0
 resting = false
 last_rest_notice = ""
 event_sequence = 0
 next_item_id = 1
 npc_cursor = 0
 next_dialogue = 500.0
 scan_report = "No scan yet. Use a powered NecroTech lab."
 scan_minute = -1
 sense_report = "No recent field report."
 metrics = {"attacks":0, "deaths":0, "revivals":0, "npc_actions":0}
 if not geography.is_empty():
  _start_geography(geography,occupation,config)
  return ""
 var names = _read_names()
 var pool: Array = ["hospital", "hospital", "necrotech_lab", "necrotech_lab", "police_department", "fire_station", "warehouse", "factory", "tower", "church", "mall", "park", "cemetery"]
 while pool.size() < 100:
  if rng.randf() < 0.30:
   pool.append("street")
  else:
   pool.append(C.NORMAL_BUILDINGS[rng.randi_range(0,C.NORMAL_BUILDINGS.size()-1)])
 for i in range(pool.size()-1, 0, -1):
  var j = rng.randi_range(0, i)
  var temp = pool[i]
  pool[i] = pool[j]
  pool[j] = temp
 # A repeatable opening cluster supports comparative pacing playtests.
 var anchors = {44:"hospital", 45:"necrotech_lab", 43:"police_department", 34:"fire_station", 54:"tower", 55:"warehouse"}
 for i in range(100):
  var kind: String = anchors.get(i, pool[i])
  var choices: Array = names.get(kind.to_upper(), [C.pretty(kind)])
  var block_name: String = choices[rng.randi_range(0, choices.size()-1)]
  blocks.append({"id":i, "x":i%10, "y":i/10, "type":kind, "name":block_name, "barricade":0, "doors":false, "ruin":0, "generator":false, "fuel_until":0, "known":false,"barricade_damage":0,"generator_hp":C.GENERATOR_HP,"last_pounding":-9999})
 for b in blocks: initialize_block(b)
 _place_special_sites()
 for b in blocks:
  initialize_block(b)
  ensure_descriptions(b)
 blocks[44].name = "Mercy General Hospital"
 blocks[45].name = "The Wrenford Building"
 blocks[44].barricade = 2
 blocks[44].doors = true
 blocks[45].barricade = 2
 blocks[45].doors = true
 blocks[45].generator = true
 blocks[45].fuel_until = minute + 1440
 var p = _actor("Alex", "Morgan", "Ashen", occupation, 4, 4, true, true)
 _setup_player(p,occupation)
 var doctor = _actor("Maya", "Reed", "Mouldering", "Doctor", 4, 4, true, true)
 doctor.human_skills = ["diagnosis","first_aid"]
 for _i in range(3): give_item(doctor, "first_aid_kit")
 var engineer = _actor("Scott", "Dilkens", "Slimy", "Engineer", 4, 4, true, true)
 engineer.human_skills = ["construction"]
 give_item(engineer, "toolbox")
 var scientist = _actor("June", "Ellis", "Jaundiced", "Scientist", 5, 4, true, true)
 scientist.human_skills = ["necro_employment","lab_experience", "necronet"]
 give_item(scientist, "syringe")
 give_item(scientist, "syringe")
 give_item(scientist, "fuel_can")
 var guard = _actor("Ravi", "Price", "Ravenous", "Guard", 3, 4, true, true)
 guard.human_skills = ["firearms"]
 give_item(guard, "pistol")
 give_item(guard, "pistol_clip")
 give_item(guard, "knife")
 guard.equipped = guard.inventory[0].uid
 for i in range(10):
  var h = _actor("Survivor %d" % (i+1), "West", "Withered", ["Doctor", "Engineer", "Guard"][i%3], [4,4,4,5,5,5,3,3,5,5][i], [3,3,3,5,5,5,4,4,4,4][i], true, true)
  if not is_building(block_at(h.x, h.y)): h.inside = false
  h.human_skills = [["first_aid"], ["construction"], ["firearms"]][i%3].duplicate()
  give_item(h, ["first_aid_kit", "toolbox", "baseball_bat"][i%3])
  if i%3 == 2: h.equipped = h.inventory[0].uid
 for i in range(18):
  var z = _actor(["Evan", "Grace", "Oliver", "Nora", "Henry", "Iris"][i%6], "Walker %d" % i, ["Empty", "Ghastly", "Oozing", "Noxious", "Hollow", "Ichorous"][i%6], "Resident", rng.randi_range(0, 9), rng.randi_range(0, 9), false, false)
  z.zombie_skills = ["vigour_mortis", "memories", "ransack"]
  if i >= 3:
   z.down = true
   z.hp = 0
   z.dormant = true
   if i%2 == 0:
    var site = blocks[[34,43,55,45,44][i%5]]
    z.x = site.x
    z.y = site.y
    z.inside = true
 actors[15].x = 4
 actors[15].y = 5
 actors[16].x = 5
 actors[16].y = 5
 actors[17].x = 5
 actors[17].y = 4
 actors[17].hp = 20
 for a in actors: a.home = a.y*width+a.x
 rebuild_geography_index()
 reindex()
 discover()
 log_event("You reach Mercy General. Maya heals; Scott maintains shelter. June works at the lab east of here.")
 log_event("50 AP. Time flows independently. Actions spend energy; brief recovery prevents repeated clicks. Rest speeds time up.")
 return ""

func _read_names() -> Dictionary:
 var result = {}
 var file = FileAccess.open("res://assets/tables/block_names.csv", FileAccess.READ)
 if file == null: return result
 var headers = file.get_csv_line()
 while not file.eof_reached():
  var row = file.get_csv_line()
  for i in range(mini(row.size(), headers.size())):
   if not row[i].is_empty():
    if not result.has(headers[i]): result[headers[i]] = []
    result[headers[i]].append(row[i])
 return result

func rebuild_geography_index() -> void:
 sites_by_type.clear()
 mast_sites.clear()
 complex_bounds.clear()
 for b in blocks:
  if not b.complex.is_empty():
   var at = Vector2i(b.x,b.y)
   if not complex_bounds.has(b.complex): complex_bounds[b.complex] = Rect2i(at,Vector2i.ONE)
   else: complex_bounds[b.complex] = complex_bounds[b.complex].merge(Rect2i(at,Vector2i.ONE))
  if b.mast: mast_sites.append(b)
  if not sites_by_type.has(b.type): sites_by_type[b.type] = []
  sites_by_type[b.type].append(b)
 navigation = AI.build_navigation(self)

func _start_geography(geography: Dictionary, occupation: String, config: Dictionary) -> void:
 width = int(geography.width)
 height = int(geography.height)
 world_mode = geography.mode
 world_title = geography.title
 geography_source = geography.source
 blocks = geography.blocks
 for b in blocks:
  for key in ["id","x","y"]: b[key] = int(b[key])
  initialize_block(b)
  if b.unbarricadable: b.barricade = 0
 rebuild_geography_index()
 var opening = blocks.filter(func(b): return b.type == "hospital")
 if opening.is_empty(): opening = blocks.filter(func(b): return is_building(b) and b.fort.is_empty() and not b.unbarricadable)
 var start_site: Dictionary = blocks[0] if opening.is_empty() else opening[rng.randi_range(0,opening.size()-1)]
 if world_mode == "malton":
  var dulston = opening.filter(func(b): return b.get("suburb","") == "Dulston")
  if not dulston.is_empty(): start_site = dulston[0]
 var p = _actor("Alex","Morgan","Ashen",occupation,start_site.x,start_site.y,true,is_building(start_site))
 _setup_player(p,occupation)
 var shelters = blocks.filter(func(b): return is_building(b) and b.fort.is_empty() and not b.unbarricadable)
 if shelters.is_empty(): shelters = blocks
 var human_count = clampi(int(config.get("survivors",300)),0,2000)
 var zombie_count = clampi(int(config.get("zombies",600)),0,4000)
 var jobs = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer"]
 var group_site = start_site
 var clinics = blocks.filter(func(b): return b.type == "necrotech_lab")
 for i in range(human_count):
  if i > 1 and i%3 == 0:
   var clinic_group = false
   for offset in range(3):
    if jobs[(i+offset)%jobs.size()] == "NecroTech Lab Assistant": clinic_group = true
   var workplaces = clinics if clinic_group and not clinics.is_empty() else shelters
   group_site = workplaces[rng.randi_range(0,workplaces.size()-1)]
  var job = jobs[i%jobs.size()]
  var a = _actor(["Maya","Scott","June","Ravi","Nora","Evan","Iris","Sam"][i%8],"Survivor %d" % (i+1),"Withered",job,group_site.x,group_site.y,true,is_building(group_site))
  _setup_player(a,job)
  # Offline populations include working specialists, not only first-day novices.
  if job == "Doctor": a.human_skills.append("first_aid")
  if job in ["Firefighter","Consumer"]: a.human_skills.append("construction")
  if i%3 == 1:
   if not has_skill(a,"construction"): a.human_skills.append("construction")
   give_item(a,"toolbox")
  if job == "NecroTech Lab Assistant":
   a.human_skills.append("lab_experience")
   give_item(a,"syringe")
  if is_building(group_site) and not group_site.unbarricadable:
   group_site.barricade = 2
   group_site.doors = has_doors(group_site)
 for i in range(zombie_count):
  var site = blocks[rng.randi_range(0,blocks.size()-1)]
  if i == 0 or i >= zombie_count-5:
   var x = clampi(p.x+rng.randi_range(-3,3),0,width-1)
   var y = clampi(p.y+rng.randi_range(-3,3),0,height-1)
   site = block_at(x,y)
  var a = _actor(["Evan","Grace","Oliver","Nora","Henry","Iris"][i%6],"Walker %d" % (i+1),["Empty","Ghastly","Oozing","Hollow"][i%4],"Corpse",site.x,site.y,false,is_building(site) and i%3 == 0)
  a.zombie_skills = ["vigour_mortis","memories","ransack"]
  if i >= maxi(1,int(zombie_count*0.16)):
   a.down = true
   a.hp = 0
   a.dormant = true
 for a in actors: a.home = a.y*width+a.x
 reindex()
 discover()
 log_event("You arrive at %s in %s. Find allies and keep a shelter secure." % [start_site.name,start_site.get("suburb",world_title)])
 log_event("%s: %d × %d blocks. Most of the dead are still motionless." % [world_title,width,height])

func phone_coverage(a: Dictionary) -> bool:
 return mast_sites.any(func(site): return site.get("suburb",world_title) == suburb_name(a) and powered(site))

func suburb_name(a: Dictionary) -> String:
 return current_block(a).get("suburb",world_title)

func _actor(first: String, last: String, adjective: String, job: String, x: int, y: int, human: bool, inside: bool) -> Dictionary:
 var actor = {"id":actors.size(), "first":first, "last":last, "adjective":adjective, "job":job, "x":x, "y":y, "human":human, "inside":inside, "down":false, "hp":50, "ap":50, "xp":0, "human_skills":[], "zombie_skills":[], "inventory":[], "equipped":-1, "memory":-1, "memory_until":0, "ready_at":0, "busy_until":0.0, "next_think":480.0+rng.randf_range(1.0,8.0), "last_action":"","dormant":false,"home":y*width+x,"supply_goal":-1,"supply_kind":"","next_trip":500+actors.size()*3,"trust":{},"request_after":{},"speech":"","speech_until":0.0,"next_speech":500.0+actors.size()*7.0}
 initialize_actor(actor)
 actors.append(actor)
 return actor

func player() -> Dictionary:
 return actors[0]

func visible_type(b: Dictionary, observer: Dictionary) -> String:
 return "office" if b.type == "necrotech_lab" and not has_skill(observer,"necro_employment") and not (current_block(observer).id == b.id and observer.inside) else b.type

func display_name(a: Dictionary) -> String:
 return (a.first + " " + a.last) if a.human else (a.adjective + " " + a.first)

func encumbrance(a: Dictionary) -> int:
 var total = 0
 for item in a.inventory: total += int(C.ITEMS[item.kind].encumbrance)
 return total

func acquisition_reason(a: Dictionary, kind: String = "") -> String:
 if encumbrance(a) >= C.ENCUMBRANCE_LIMIT: return "Already carrying %d%%; drop or use an item first." % encumbrance(a)
 if kind == "candy" and not item_kind(a,"candy").is_empty(): return "You already carry a bag of candy."
 if kind in ["dead_fir_tree","plastic_christmas_tree"] and (not item_kind(a,"dead_fir_tree").is_empty() or not item_kind(a,"plastic_christmas_tree").is_empty()): return "You can carry only one Christmas tree."
 return ""

func can_barricade(b: Dictionary) -> bool:
 return is_building(b) and not b.get("unbarricadable",false)

func give_item(a: Dictionary, kind: String) -> void:
 var def: Dictionary = C.ITEMS[kind]
 a.inventory.append({"uid":next_item_id, "kind":kind, "ammo":def.get("capacity", 0), "durability":def.get("durability", 0)})
 next_item_id += 1

func block_at(x: int, y: int) -> Dictionary:
 return blocks[y*width+x]

func current_block(a: Dictionary) -> Dictionary:
 return block_at(a.x, a.y)

func is_building(b: Dictionary) -> bool:
 return b.type not in C.OUTDOORS

func has_doors(b: Dictionary) -> bool:
 return is_building(b) and b.type not in ["junkyard","church","cathedral","gatehouse","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]

func doors_closed(b: Dictionary) -> bool:
 return has_doors(b) and b.doors

func powered(b: Dictionary) -> bool:
 return b.ruin == 0 and b.generator and b.fuel_until > minute

func has_skill(a: Dictionary, skill: String) -> bool:
 if skill in ["body_building","diagnosis","necro_employment","ankle_grab","scent_death"]: return skill in a.human_skills or skill in a.zombie_skills
 return skill in (a.human_skills if a.human else a.zombie_skills)

func reindex() -> void:
 spatial.clear()
 var human_forms = 0
 for a in actors:
  if a.human: human_forms += 1
  var key = a.y*width+a.x
  if not spatial.has(key): spatial[key] = []
  spatial[key].append(a.id)
 survivor_ratio = float(human_forms)/maxi(1,actors.size())

func occupants(b: Dictionary, inside = null) -> Array:
 var result: Array = []
 for id in spatial.get(b.id, []):
  var a = actors[id]
  if inside == null or a.inside == inside: result.append(a)
 return result

func nearby(a: Dictionary, b: Dictionary) -> bool:
 return a.x == b.x and a.y == b.y and a.inside == b.inside

func discover() -> void:
 var p = player()
 if p.down: return
 for dy in range(-1, 2):
  for dx in range(-1, 2):
   if p.x+dx in range(width) and p.y+dy in range(height): block_at(p.x+dx, p.y+dy).known = true

func item_by_uid(a: Dictionary, uid: int) -> Dictionary:
 for item in a.inventory:
  if item.uid == uid: return item
 return {}

func item_kind(a: Dictionary, kind: String) -> Dictionary:
 for item in a.inventory:
  if item.kind == kind: return item
 return {}

func consume(a: Dictionary, item: Dictionary) -> void:
 if a.equipped == item.uid: a.equipped = -1
 a.inventory.erase(item)

func cost(a: Dictionary, command: String) -> int:
 var base = 1
 match command:
  "move": base = 2 if not a.human and not has_skill(a,"lurching_gait") else 1
  "enter","leave": base = 2 if not a.human and doors_closed(current_block(a)) else 1
  "revive": base = 10
  "manufacture": base = 20
  "scout": base = 30
  "bellow": base = 10 if occupants(current_block(a),a.inside).filter(func(t): return t.human and not t.down).size() >= 25 else 1
  "stand": base = (1 if has_skill(a,"ankle_grab") else 10)+int(a.get("headshot",0))
  "equip","drop": base = 0
 if a.human and a.inside and a.get("scout_site",-1) == current_block(a).id and current_block(a).ruin == 0 and command not in ["scout","stand","move"]:
  var used = int(a.scout_used) if int(a.scout_day) == minute/1440 else 0
  if used < 5: return maxi(0,base-1)
 return base

func reason(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}, context_only: bool = false) -> String:
 if not context_only and a.busy_until > now(): return "Recovering for %.1f seconds." % (a.busy_until-now())
 if a.down and command not in ["stand", "drop"]: return "You are down. Rest for AP, then stand up."
 if command == "stand":
  if a.get("dormant",false): return "This body has not begun to stir."
  if not a.down: return "Already standing."
  if not context_only and minute < a.ready_at: return "You can stand in %d minutes." % (a.ready_at-minute)
 if not context_only and a.ap < cost(a, command): return "Not enough AP. Rest to recover."
 var b = current_block(a)
 if command in Extended.COMMANDS: return Extended.command_reason(self,a,command,target_id,data)
 if command == "bite" and a.human: return "Only zombies can bite. Humans use carried weapons or fists."
 var human_only = ["search", "heal", "revive", "reload", "barricade", "repair", "generator", "fuel", "scan", "manufacture", "request", "give", "jump", "close", "dump", "repair_generator"]
 if not a.human and command in human_only: return "The undead cannot use items or human abilities. You can drop carried items."
 match command:
  "move":
   var dx: int = data.get("dx", 0)
   var dy: int = data.get("dy", 0)
   if maxi(absi(dx), absi(dy)) != 1: return "Choose a neighbouring block."
   if a.x+dx not in range(width) or a.y+dy not in range(height): return "You have reached the city boundary."
   var destination = block_at(a.x+dx,a.y+dy)
   var fort_error = fort_move_reason(a,b,destination)
   if not fort_error.is_empty(): return fort_error
  "enter":
   if not is_building(b) or a.inside: return "There is no entrance here."
   if b.barricade > (4 if a.human else 0): return "You try to find an entry point, but the building is too heavily barricaded to enter from the outside."
   if not a.human and doors_closed(b) and not has_skill(a, "memories"): return "Memories of Life is needed to open doors."
  "leave":
   if not a.inside: return "Already outside."
   if not a.human and b.barricade > 0: return "Break the barricade before leaving."
   if not a.human and doors_closed(b) and not has_skill(a, "memories"): return "Memories of Life is needed to open doors."
  "barricade", "repair", "generator", "fuel", "close", "ransack", "scan", "manufacture", "jump", "dump", "repair_generator", "destroy_generator":
   if not a.inside or not is_building(b): return "You must be inside a building."
 if command == "dump":
  if target_id < 0 or target_id >= actors.size(): return "Select a body first."
  var body = actors[target_id]
  if body.id == a.id or not nearby(a,body) or not body.down: return "Select a body inside this building."
 if command in ["heal", "revive", "attack", "bite", "request", "give"]:
  if target_id < 0 or target_id >= actors.size(): return "Select a character first."
  var t = actors[target_id]
  if not nearby(a, t): return "That character is not within reach."
  if command in ["attack", "bite", "heal", "request", "give"] and t.down: return "That character is down."
  if command in ["attack","bite"]:
   if a.human == t.human: return "Choose a character on the other side."
   var weapon = item_by_uid(a, a.equipped)
   if a.human and not weapon.is_empty() and C.ITEMS[weapon.kind].has("capacity") and weapon.ammo == 0: return "The %s is empty. Reload or switch weapons." % C.ITEMS[weapon.kind].name.to_lower()
  if command == "heal":
   if t.hp >= max_hp(t) and not t.infected: return "Already at full health."
   if item_kind(a, "first_aid_kit").is_empty(): return "You need a first aid kit."
  if command == "revive":
   if t.human: return "Already human."
   if not has_skill(a, "lab_experience"): return "Lab experience is required."
   if item_kind(a, "syringe").is_empty(): return "You need a syringe."
   if has_skill(t, "brain_rot") and not (a.inside and b.type == "necrotech_lab" and powered(b) and has_skill(a, "necronet")): return "Brain Rot requires a powered NecroTech lab and NecroNet access."
  if command in ["request", "give"]:
   if not t.human or t.id == a.id: return "Choose another survivor."
   if command == "request":
    if encumbrance(a) >= C.ENCUMBRANCE_LIMIT: return "You are at %d%% encumbrance. Drop or use something before collecting more." % encumbrance(a)
   else:
    var gift = item_by_uid(a,data.get("uid",-1))
    if gift.is_empty(): return "Select a carried item to give."
    var carry_error = acquisition_reason(t,gift.kind)
    if not carry_error.is_empty(): return "They cannot carry it: "+carry_error
 match command:
  "equip", "drop":
   var item = item_by_uid(a, data.get("uid", -1))
   if item.is_empty(): return "Select a carried item."
   if command == "equip" and not a.human and item.kind not in C.ZOMBIE_MELEE_ITEMS: return "Zombies can only wield a crowbar, baseball bat or length of pipe."
   if command == "equip" and not C.ITEMS[item.kind].has("damage"): return "This item is used by its action button."
  "reload":
   var weapon = item_by_uid(a,a.equipped)
   if weapon.is_empty() or not C.ITEMS[weapon.kind].has("capacity"): return "Equip a firearm first."
   var def = C.ITEMS[weapon.kind]
   if weapon.ammo >= def.capacity: return "The firearm is already loaded."
   if item_kind(a,def.ammo_kind).is_empty(): return "You need %s." % C.ITEMS[def.ammo_kind].name.to_lower()
  "barricade":
   if not can_barricade(b): return "This open ground has no entrance to barricade."
   if not has_skill(a,"construction") and (b.barricade > 0 or item_kind(a,"length_of_pipe").is_empty()): return "Construction or a length of pipe for a loose barricade is required."
   if b.ruin > 0: return "Repair the building first."
   if b.barricade >= 7 and b.barricade_damage == 0: return "The barricade is at maximum strength."
   for other in occupants(b, true):
    if not other.human and not other.down: return "Remove the zombies inside first."
  "break":
   if not is_building(b) or b.barricade == 0: return "There are no barricades here."
  "repair":
   if b.ruin == 0: return "The building needs no repairs."
   if item_kind(a,"toolbox").is_empty(): return "You need a toolbox to repair the building."
   if not has_skill(a,"construction"): return "Construction is required to repair buildings."
   if occupants(b,true).any(func(t): return not t.human and not t.down): return "Remove standing zombies before repairing the building."
  "repair_generator":
   if not b.generator or b.generator_hp >= C.GENERATOR_HP: return "The generator needs no repairs."
   if item_kind(a,"toolbox").is_empty(): return "You need a toolbox."
   if not has_skill(a,"construction"): return "Construction is required to repair generators."
  "destroy_generator":
   if a.human: return "Only zombies attack generators."
   if not b.generator: return "There is no generator here."
  "ransack":
   if b.type == "junkyard": return "An open junkyard cannot be ransacked."
   if not has_skill(a,"ransack"): return "Ransack is required."
   if b.generator: return "Destroy the generator before ransacking the building."
   if a.human: return "Only zombies ransack buildings."
   if b.ruin >= 3: return "The building is already ruined."
   for other in occupants(b, true):
    if other.human and not other.down: return "Survivors are still defending this building."
  "close":
   if not has_doors(b): return "There are no doors here, only a hole in the fence." if b.type == "junkyard" else "There are no closable doors here."
   if doors_closed(b): return "The doors are already closed."
  "generator":
   if b.ruin > 0: return "Repair the building before installing a generator."
   if b.generator: return "A generator is already installed."
   if item_kind(a, "portable_generator").is_empty(): return "You need a portable generator."
  "fuel":
   if b.ruin > 0: return "Repair the building before refueling."
   if not b.generator: return "Install a generator first."
   if b.generator_hp < C.GENERATOR_HP: return "Repair the damaged generator before refueling."
   if item_kind(a, "fuel_can").is_empty(): return "You need a fuel can."
  "scan", "manufacture":
   if b.type != "necrotech_lab" or not powered(b): return "You need a powered NecroTech lab."
   if not has_skill(a, "necronet"): return "NecroNet access is required."
   if command == "manufacture" and not acquisition_reason(a,"syringe").is_empty(): return acquisition_reason(a,"syringe")
  "search":
   if is_building(b) and not a.inside: return "Enter the building before searching it."
   if encumbrance(a) >= C.ENCUMBRANCE_LIMIT: return "You are at %d%% encumbrance. Drop or use something before collecting more." % encumbrance(a)
  "jump":
   if b.type != "tower": return "You must be inside a tower."
 if command not in ["move", "enter", "leave", "attack", "bite", "heal", "revive", "stand", "search", "equip", "drop", "reload", "barricade", "break", "repair", "ransack", "close", "generator", "fuel", "scan", "manufacture", "request", "give", "jump", "wait", "dump", "repair_generator", "destroy_generator"]: return "Unknown action."
 return ""

func act(command: String, target_id: int = -1, data: Dictionary = {}) -> Dictionary:
 if resting: return {"ok":false, "message":"Cancel rest before acting."}
 var p = player()
 var rejection = reason(p, command, target_id, data)
 if not rejection.is_empty(): return {"ok":false, "message":rejection}
 execute(p, command, target_id, data)
 discover()
 return {"ok":true, "message":""}

func execute(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> void:
 # Internal callers must validate first. Effects happen before any time passes.
 var ap_spent = cost(a,command)
 if int(a.scout_day) != minute/1440:
  a.scout_day = minute/1440
  a.scout_used = 0
 if a.human and a.inside and a.scout_site == current_block(a).id and current_block(a).ruin == 0 and a.scout_used < 5 and command not in ["scout","stand","move","equip","drop"]: a.scout_used += 1
 a.ap -= ap_spent
 a.busy_until = now()+recovery(command)
 a.last_action = command
 var b = current_block(a)
 var origin = {"x":a.x, "y":a.y, "inside":a.inside}
 var friendly = a.human == player().human
 var critical = false
 var initial_target_hp = actors[target_id].hp if target_id >= 0 else -1
 var name = "You" if a.id == 0 else display_name(a)
 var text = ""
 match command:
  "move":
   clear_grasp(a)
   var destination = block_at(a.x+data.dx, a.y+data.dy)
   a.inside = a.inside and a.human and has_skill(a, "free_running") and is_building(destination) and destination.ruin < 3
   if not destination.fort.is_empty() and destination.fort != b.fort: a.inside = false
   if destination.fort == b.fort and not b.fort.is_empty(): a.inside = destination.type == "gatehouse"
   if destination.complex == b.complex and not b.complex.is_empty(): a.inside = origin.inside and is_building(destination)
   a.x += data.dx
   a.y += data.dy
   text = "%s move to %s." % [name, destination.name]
  "enter":
   clear_grasp(a)
   var opened = not a.human and doors_closed(b)
   a.inside = true
   if not a.human: b.doors = false
   text = "%s %s %s." % [name,"open the doors and enter" if opened else "enter",b.name]
  "leave":
   clear_grasp(a)
   a.inside = false
   if not a.human: b.doors = false
   text = "%s step outside." % name
  "equip":
   a.equipped = data.uid if a.equipped != data.uid else -1
   text = "Equipment changed."
  "drop":
   var item = item_by_uid(a, data.uid)
   text = "%s discard %s." % [name, C.ITEMS[item.kind].name]
   consume(a, item)
  "attack","bite":
   var t = actors[target_id]
   if a.grasp_target != target_id: clear_grasp(a)
   var weapon = item_by_uid(a,a.equipped) if command == "attack" and not data.get("unarmed",false) else {}
   if not a.human and not weapon.is_empty() and weapon.kind not in C.ZOMBIE_MELEE_ITEMS: weapon = {}
   var stats = attack_stats(a,t,command,weapon)
   var fragile = false
   set_pose(a,"attack")
   if not weapon.is_empty():
    var def = C.ITEMS[weapon.kind]
    if def.has("capacity"): weapon.ammo -= 1
    elif def.get("single_use",false): consume(a,weapon)
    elif def.get("fragile",false): fragile = true
   metrics.attacks += 1
   if rng.randi_range(1,100) <= stats.hit:
    var damage = int(stats.damage)
    if stats.ranged and (not item_kind(t,"flak_jacket").is_empty() or has_skill(t,"flesh_rot")): damage = int(floor(damage*0.8))
    var actual = mini(t.hp,damage)
    t.hp -= actual
    a.xp += actual
    set_pose(t,"hurt")
    text = "%s %s %s for %d damage." % [name,"bite" if command == "bite" else "hit",display_name(t),actual]
    if not a.human:
     if command == "bite":
      if has_skill(a,"digestion"): a.hp = mini(max_hp(a),a.hp+actual)
      if t.human and has_skill(a,"infectious_bite"):
       t.infected = true
       text += " The wound is infected."
     elif weapon.is_empty() and has_skill(a,"tangling_grasp") and t.hp > 0:
      claim_grasp(a,t)
      text += " A grasp locks onto the victim."
    if fragile: consume(a,weapon)
    elif not weapon.is_empty() and melee_break_chance(weapon) > 0.0 and rng.randf() < melee_break_chance(weapon):
     consume(a,weapon)
     text += " The pool cue splinters and breaks."
    if t.hp <= 0:
     var penalty = 5 if not t.human and has_skill(a,"headshot") else 0
     a.xp += 10
     die(t,penalty)
     critical = true
     text += " They fall." + (" A Headshot delays their return." if penalty > 0 else "")
   else:
    text = "%s miss %s." % [name,display_name(t)]
    if a.grasp_target == target_id and rng.randf() < 0.5:
     clear_grasp(a)
     text += " The grasp slips free."
   if a.human and not t.human and has_skill(t,"scent_trail"):
    t.trail_from = a.id
    t.trail_until = minute+60
  "heal":
   var t = actors[target_id]
   var healing = (10 if has_skill(a,"first_aid") else 5)+(5 if has_skill(a,"surgery") and a.inside and b.type in ["hospital","infirmary"] and powered(b) else 0)
   var amount = mini(max_hp(t)-t.hp,healing)
   t.hp += amount
   t.infected = false
   if t.id != a.id:
    add_trust(t,a,amount*2)
    if amount > 0: a.xp += 5
   consume(a, item_kind(a, "first_aid_kit"))
   text = "%s heal %s for %d HP." % [name, display_name(t), amount]
  "revive":
   critical = true
   var t = actors[target_id]
   clear_grasp(t)
   t.human = true
   t.wants_revive = false
   t.speech = ""
   t.speech_until = 0.0
   t.dormant = false
   t.down = true
   t.hp = 0
   t.ready_at = minute + 5
   t.equipped = -1
   t.memory = -1
   consume(a, item_kind(a, "syringe"))
   a.xp += 10
   add_trust(t,a,25)
   metrics.revivals += 1
   text = "%s revive %s. They can stand as a human." % [name, display_name(t)]
  "stand":
   a.down = false
   a.headshot = 0
   set_pose(a,"idle")
   a.hp = max_hp(a)/2
   text = "%s rise as %s." % [name, "a survivor" if a.human else "a zombie"]
  "search": text = _search(a,b,name,str(data.get("store","")))
  "reload":
   var weapon = item_by_uid(a,a.equipped)
   var def = C.ITEMS[weapon.kind]
   weapon.ammo = mini(def.capacity,weapon.ammo+def.reload_amount)
   consume(a,item_kind(a,def.ammo_kind))
   text = "%s load a single shell into the shotgun." % name if weapon.kind == "shotgun" else "%s reload the pistol with a magazine." % name
  "barricade":
   var improvised = not has_skill(a,"construction")
   if rng.randf() < (0.9 if b.barricade < 4 else 0.65):
    gain_local_trust(a,b,3)
    if improvised: consume(a,item_kind(a,"length_of_pipe"))
    if has_doors(b): b.doors = true
    if b.barricade_damage > 0:
     b.barricade_damage = 0
     text = "%s shore up the damaged barricade. It is %s." % [name,C.barricade_description(b.barricade)]
    else:
     b.barricade = mini(7,b.barricade+1)
     text = "%s reinforce the building. It is now %s." % [name,C.barricade_description(b.barricade)]
     if b.barricade == 4: text += " Any more barricades will prevent survivors from climbing inside from outside."
   else: text = "%s find no suitable material for the barricade." % name
  "break":
   if a.human: gain_local_trust(a,b,-5)
   if not a.human and not a.inside: b.last_pounding = minute
   if rng.randf() < C.BREACH_CHANCE+(0.10 if not a.human and has_skill(a,"death_grip") else 0.0):
    b.barricade_damage += 1
    if b.barricade_damage >= C.BARRICADE_SUBLEVELS:
     b.barricade -= 1
     b.barricade_damage = 0
     critical = b.barricade == 0
     if not a.human: a.xp += 1
     text = "%s dislodge part of the barricade. The building is %s." % [name,C.barricade_description(b.barricade)]
    else: text = "%s loosen the barricade, but it still holds." % name
   else: text = "%s strike the barricade. It holds." % name
  "dump":
   var body = actors[target_id]
   body.inside = false
   gain_local_trust(a,b,2)
   text = "%s drag a body to the doorway and dump it outside." % name
  "repair_generator":
   b.generator_hp = mini(C.GENERATOR_HP,b.generator_hp+2)
   a.xp += 1
   gain_local_trust(a,b,5)
   text = "%s repair the generator. It is %s." % [name,generator_condition(b)]
  "destroy_generator":
   if rng.randf() < 0.65:
    b.generator_hp = maxi(0,b.generator_hp-1)
    text = "%s batter the generator. It is %s." % [name,generator_condition(b)]
    if b.generator_hp == 0:
     b.generator = false
     b.fuel_until = 0
     critical = true
     a.xp += 5
     text = "%s smash the generator beyond repair. The lights go out." % name
   else: text = "%s claw at the generator's metal casing without damaging it." % name
  "repair":
   b.ruin = maxi(0, b.ruin-1)
   a.xp += 1
   gain_local_trust(a,b,4)
   text = "%s repair the building: damage %d/3." % [name, b.ruin]
  "ransack":
   b.ruin += 1
   if b.ruin >= 3:
    for occupant in actors:
     if occupant.scout_site == b.id: occupant.scout_site = -1
   a.xp += 1
   text = "%s ransack the building: damage %d/3." % [name, b.ruin]
  "close":
   b.doors = true
   text = "%s close the doors." % name
  "generator":
   b.generator = true
   b.generator_hp = C.GENERATOR_HP
   consume(a, item_kind(a, "portable_generator"))
   gain_local_trust(a,b,8)
   text = "%s install a generator." % name
  "fuel":
   var already_running = powered(b)
   b.fuel_until = minute+C.FUEL_MINUTES
   consume(a, item_kind(a, "fuel_can"))
   gain_local_trust(a,b,6)
   text = "%s top off the running generator to 24 hours. The remaining fuel in the can is wasted." % name if already_running else "%s fuel the generator. The lights come on for 24 hours." % name
  "manufacture":
   give_item(a, "syringe")
   text = "%s manufacture a syringe (20 AP)." % name
  "scan":
   var records: Array[String] = []
   for other in actors:
    if other.human or other.down or other.tagged_until < minute: continue
    if maxi(absi(other.x-a.x),absi(other.y-a.y)) <= 4: records.append("[%d,%d] Tagged zombie: %s" % [other.x,other.y,display_name(other)])
   scan_report = "NECRONET TAGS\n"+("\n".join(records) if not records.is_empty() else "No current DNA tags in the local 9x9 scan.")
   scan_minute = minute
   text = "A timestamped DNA tag scan is ready on the field map."
  "request":
   text = request_supplies(a,actors[target_id])
  "give":
   var t = actors[target_id]
   var item = item_by_uid(a, data.uid)
   if item_kind(t,item.kind).is_empty() and supply_needed_by(t,item.kind): add_trust(t,a,8)
   consume(a, item)
   t.inventory.append(item)
   text = "%s give %s to %s." % [name, C.ITEMS[item.kind].name, display_name(t)]
  "jump":
   critical = true
   a.inside = false
   die(a)
   text = "%s fall from the tower. Your story continues among the dead." % name
  "wait": text = "%s wait and watch." % name
  _: text = Extended.perform(self,a,command,target_id,data)
 if a.human and a.infected and command != "say":
  a.hp = maxi(0,a.hp-1)
  if a.hp == 0: die(a)
  if a.id == 0: text += " Infection costs one HP."
 reindex()
 var p = player()
 var event_action = command
 if command == "break" and not a.human and not a.inside and p.inside and a.x == p.x and a.y == p.y:
  event_action = "breach_noise"
  text = "Pounding fists and scraping claws batter the barricades outside. " + ("The last barricade gives way." if b.barricade == 0 else "The barricades shudder but hold.")
 var visible = nearby(a,p) or nearby(origin,p)
 var remote = (command == "broadcast" and not item_kind(p,"radio").is_empty() and is_equal_approx(p.channel,b.frequency)) or (command == "phone" and target_id == 0)
 var audible = a.x == p.x and a.y == p.y and command in ["break","barricade","enter","leave"]
 if a.id == 0 or visible or audible or remote or target_id == 0:
  var category = "PLAYER" if a.id == 0 else ("ALLY" if friendly else "ENEMY")
  if target_id == 0 or (critical and not friendly): category = "ALERT"
  if not text.is_empty(): log_event(text, category, a.id, event_action, critical or target_id == 0)
 if resting and ((target_id == 0 and (initial_target_hp > p.hp or command == "revive")) or (critical and audible) or threats()):
  stop_rest("Rest interrupted. Danger or a change in your condition brings you back to normal speed.")

func die(a: Dictionary, penalty: int = 0) -> void:
 if a.human and a.id > 0 and a.job not in ["Corpse","Resident"]:
  a.wants_revive = a.id%3 != 0
 for tracker in actors:
  if tracker.trail_from == a.id: tracker.trail_from = -1
 clear_grasp(a)
 a.headshot = penalty
 a.fed = 0
 a.tagged_until = 0
 a.scout_site = -1
 set_pose(a,"die")
 a.speech = ""
 a.speech_until = 0.0
 a.hp = 0
 a.dormant = false
 a.down = true
 a.human = false
 a.equipped = -1
 a.memory = -1
 a.ready_at = minute+30
 a.busy_until = 0.0
 metrics.deaths += 1

func _search(a: Dictionary, b: Dictionary, name: String, store: String = "") -> String:
 var found = roll_search(b,a,store)
 if found == "dead_fir_tree" and item_kind(a,"fire_axe").is_empty(): return "You find a small fir tree, but need a fire axe to fell it." if a.id == 0 else "%s searches the area for supplies." % name
 if not found.is_empty() and not acquisition_reason(a,found).is_empty():
  return "You find %s, but cannot carry another: %s" % [C.ITEMS[found].name,acquisition_reason(a,found)] if a.id == 0 else "%s searches for supplies." % name
 if not found.is_empty():
  give_item(a,found)
  if C.ITEMS[found].has("capacity"): a.inventory.back().ammo = 0
 # Other actors get the same loot rules without the player's detailed narration.
 if a.id != 0: return "%s searches the area for supplies." % name
 var spot = search_spot(b)
 var lit = powered(b)
 if found.is_empty():
  var finds = ["only rotting paper and empty wrappers; nothing worth carrying", "a promising container, but its contents have spoiled", "a broken item whose working parts have rusted away", "a heap of useless scraps, which you leave behind", "an empty hiding place beneath a thick layer of dust"]
  var result: String = finds[rng.randi_range(0,finds.size()-1)]
  return "%s search %s and find %s." % [name,spot,result] if lit else "%s feel through %s in the dark, stumbling over debris, and find %s." % [name,spot,result]
 var description: String = C.ITEMS[found].name
 var condition = "It is empty and needs ammunition." if C.ITEMS[found].has("capacity") else "It is intact and ready to use."
 return "%s search %s under the lights. At last: %s! %s" % [name,spot,description,condition] if lit else "%s grope through %s in the darkness. Against the odds, you find %s! %s" % [name,spot,description,condition]

func item_search_chance(b: Dictionary, kind: String, a: Dictionary = {}, store: String = "") -> float:
 var base = float(search_tables.get(b.type,{}).get(kind,0.0))
 if b.type == "mall" and not a.is_empty() and has_skill(a,"shopping") and C.MALL_STORES.has(store):
  if kind not in C.MALL_STORES[store]: return 0.0
  var total = 0.0
  for candidate in C.MALL_STORES[store]: total += float(search_tables.mall.get(candidate,0.0))
  base *= 0.12/maxf(0.001,total)
 if b.type == "mall" and not a.is_empty() and has_skill(a,"bargain_hunting"): base *= 1.5
 var multiplier = 1.0 if powered(b) else C.DARK_SEARCH_MULTIPLIER
 if b.ruin >= 3: multiplier *= C.RUIN_SEARCH_MULTIPLIER
 if kind in ["first_aid_kit","syringe"]: multiplier *= 1.0+clampf((0.3-survivor_ratio)/0.3,0.0,1.0)
 return base*multiplier

func search_chance(b: Dictionary) -> float:
 var total = 0.0
 for kind in search_tables.get(b.type,{}): total += item_search_chance(b,kind)
 return total

func roll_search(b: Dictionary, a: Dictionary = {}, store: String = "") -> String:
 # Disjoint per-item probability bands, plus the remaining no-find probability.
 # One roll yields at most one item; unrelated loot never dilutes an item's odds.
 var roll = rng.randf()
 var cumulative = 0.0
 for kind in search_tables.get(b.type,{}):
  cumulative += item_search_chance(b,kind,a,store)
  if roll < cumulative: return kind
 return ""

func search_loot(kind: String) -> Array:
 return search_tables.get(kind,{}).keys()

func search_spot(b: Dictionary) -> String:
 var spots: Array
 match b.type:
  "hospital": spots = ["a tipped medicine cabinet","the drawers of a treatment trolley","a dusty ward supply cupboard"]
  "necrotech_lab": spots = ["a locked sample tray","the storage beneath a lab bench","an abandoned equipment locker"]
  "police_department": spots = ["an overturned evidence drawer","the station's old weapons lockers","a desk in the duty office"]
  "fire_station": spots = ["the emergency equipment racks","a battered crew locker","the cab of an abandoned engine"]
  "warehouse", "factory", "auto_repair": spots = ["a stack of shipping crates","the shelves of a parts store","a rusted maintenance cabinet"]
  "library", "school", "office": spots = ["the drawers of a broken desk","a neglected storage cupboard","the shelves behind a fallen bookcase"]
  "pub", "nightclub", "cinema": spots = ["a cupboard behind the counter","the lost-property boxes","a dark storeroom by the rear exit"]
  "church": spots = ["the vestry cupboards","the space beneath a broken pew","a donation chest by the door"]
  _: spots = ["the debris beneath an overturned counter","a battered storage cabinet","a stack of abandoned bags"]
 return spots[rng.randi_range(0,spots.size()-1)]

func now() -> float:
 return float(clock_step)/C.CLOCK_STEPS_PER_MINUTE

func recovery(command: String) -> float:
 return C.ACTION_RECOVERY.get(command,1.2)

func elapse(real_seconds: float) -> void:
 # Consume real time in small slices so interruptions immediately cancel fast-forward.
 var remaining = real_seconds
 while remaining > 0.000001:
  var slice = minf(remaining,0.05)
  remaining -= slice
  clock_fraction += slice*C.GAME_MINUTES_PER_SECOND*C.CLOCK_STEPS_PER_MINUTE*time_speed()
  while clock_fraction >= 1.0-0.000001:
   clock_fraction = maxf(0.0,clock_fraction-1.0)
   _clock_step()

func advance(minutes: int) -> void:
 # Headless tests only. Interactive play always uses elapse(delta).
 for i in range(minutes*C.CLOCK_STEPS_PER_MINUTE): _clock_step()

func _clock_step() -> void:
 clock_step += 1
 minute = clock_step/C.CLOCK_STEPS_PER_MINUTE
 if clock_step % (1440*C.CLOCK_STEPS_PER_MINUTE) == 0: reanimate_bodies()
 if clock_step % (C.RECOVERY_MINUTES*C.CLOCK_STEPS_PER_MINUTE) == 0:
  for a in actors: a.ap = mini(C.AP_CAP,a.ap+1)
 # Characters have individual due times, not a synchronized global NPC turn.
 for offset in range(actors.size()-1):
  var index = 1+(npc_cursor+offset)%(actors.size()-1)
  var a = actors[index]
  if a.next_think > now() or a.busy_until > now(): continue
  var old_ap = a.ap
  _npc_turn(a)
  var delay = rng.randf_range(1.0,4.0) if a.ap != old_ap else rng.randf_range(5.0,10.0)
  a.next_think = maxf(now(),a.busy_until)+delay
 npc_cursor = (npc_cursor+1)%maxi(1,actors.size()-1)
 if resting and ((player().ap >= rest_target and (not player().down or minute >= player().ready_at)) or clock_step >= rest_end_step):
  stop_rest("Rest complete. %d AP available." % player().ap)

func _try(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> bool:
 if not reason(a, command, target_id, data).is_empty(): return false
 execute(a, command, target_id, data)
 metrics.npc_actions += 1
 return true

func _npc_turn(a: Dictionary) -> void:
 _learn_npc(a)
 if a.busy_until > now(): return
 if a.down:
  if a.get("dormant",false): return
  _try(a, "stand")
  return
 _maybe_speak(a)
 if a.ap < 1: return
 var b = current_block(a)
 var present = occupants(b, a.inside)
 if a.human:
  if has_skill(a,"lab_experience"):
   for other in present:
    if not other.human and _try(a, "revive", other.id): return
  if (a.hp <= 35 or a.infected) and _try(a, "heal", a.id): return
  for other in present:
   if other.human and (other.hp < 40 or other.infected) and not other.down and _try(a, "heal", other.id): return
  if (a.hp <= 15 or a.ap <= 6) and AI.retreat(self,a,true): return
  for other in present:
   if not other.human and not other.down and not (other.wants_revive and not a.inside):
    if has_skill(a,"necro_employment") and other.tagged_until <= minute and not item_kind(a,"dna_extractor").is_empty() and a.ap > 15 and a.hp > 30:
     if _try(a,"extract",other.id): return
    if AI.equip_best(self,a,other): return
    if _try(a, "attack", other.id): return
    if _try(a, "reload"): return
  var return_distance = maxi(absi(blocks[a.home].x-a.x),absi(blocks[a.home].y-a.y))
  if a.supply_goal >= 0 and (a.supply_kind.is_empty() or not item_kind(a,a.supply_kind).is_empty() or a.ap <= return_distance+12):
   if a.ap <= return_distance+12:
    a.supply_goal = a.home
    a.supply_kind = ""
   if human_expedition(a): return
  if a.inside:
   for other in present:
    if other.down and not other.human and _try(a,"dump",other.id): return
   if _try(a,"repair_generator"): return
   if _try(a,"repair"): return
   var away = actors.any(func(t): return t.id != a.id and t.human and not t.down and t.home == b.id and (not t.inside or t.x != b.x or t.y != b.y))
   var threatened = occupants(b,false).filter(func(t): return not t.human and not t.down and not t.wants_revive).size() >= 5 and not away
   if (b.barricade_damage > 0 or b.barricade < (7 if threatened else 4)) and _try(a,"barricade"): return
   if _try(a,"close"): return
   if _try(a,"generator"): return
   if (not powered(b) or b.fuel_until-minute <= 360) and _try(a,"fuel"): return
   for other in present:
    if other.id == a.id or not other.human or other.down: continue
    for kind in ["first_aid_kit","toolbox","pistol_clip","shotgun_shell","fuel_can"]:
     if item_kind(other,kind).is_empty() and not item_kind(a,kind).is_empty() and supply_needed_by(other,kind) and not supply_needed_by(a,kind):
      if _try(a,"give",other.id,{"uid":item_kind(a,kind).uid}): return
   if has_skill(a,"lab_experience"):
    if item_kind(a,"syringe").is_empty() and _try(a,"manufacture"): return
    for other in occupants(b,false):
     if not other.human and not other.get("dormant",false) and not item_kind(a,"syringe").is_empty() and not has_skill(other,"brain_rot"):
      if _try(a,"leave"): return
  if a.ap < 8 and a.inside: return
  if a.inside and b.id == a.home and b.type == "necrotech_lab" and has_skill(a,"lab_experience"):
   if item_kind(a,"syringe").is_empty() and a.ap > 20: _try(a,"search")
   return
  if AI.regroup(self,a): return
  if a.inside and b.id == a.home and AI.keeper(self,a):
   var wanted = wanted_supply(a)
   if a.ap > 20 and not wanted.is_empty() and item_search_chance(b,wanted,a) > 0: _try(a,"search")
   return
  if AI.retreat(self,a): return
  if human_expedition(a): return
  if not a.inside:
   if _try(a,"enter"): return
   _wander(a)
  return
 else:
  if a.wants_revive:
   AI.seek_revival(self,a)
   return
  var victim = AI.prey(self,a,present)
  if not victim.is_empty():
   if AI.can_call(self,a,present):
    a.next_groan = minute+180
    if _try(a,"groan"): return
   if has_skill(a,"feeding_drag") and a.inside and victim.hp <= 12 and _try(a,"drag",victim.id): return
   _try(a,"bite" if (has_skill(a,"infectious_bite") and not victim.infected) or (has_skill(a,"digestion") and a.hp < max_hp(a)) else "attack",victim.id)
   return
  if has_skill(a,"digestion") and a.hp <= max_hp(a)-4:
   for body in present:
    if _try(a,"feed",body.id): return
  var target = _visible_human(a)
  if not target.is_empty():
   a.memory = target.y*width+target.x
   a.memory_until = minute+60
  if target.is_empty() and (a.memory < 0 or minute > a.memory_until) and not a.inside:
   var light = nearby_light(a)
   if not light.is_empty():
    a.memory = light.id
    a.memory_until = minute+90
  if a.memory >= 0 and minute <= a.memory_until:
   var goal = blocks[a.memory]
   if a.x == goal.x and a.y == goal.y:
    if not a.inside:
     if _try(a, "break"): return
     if _try(a, "enter"): return
    else:
     if not target.is_empty() and not target.inside and _try(a,"leave"): return
    a.memory = -1
   else:
    if AI.go(self,a,goal): return
    a.memory = -1
  if a.inside:
   if _try(a,"destroy_generator"): return
   if _try(a, "ransack"): return
  if not a.inside and powered(b):
   if _try(a, "break"): return
   if _try(a, "enter"): return
  _wander(a)

func _visible_human(a: Dictionary) -> Dictionary:
 if has_skill(a,"scent_trail") and a.trail_from >= 0 and a.trail_until >= minute:
  var tracked = actors[a.trail_from]
  if tracked.human and not tracked.down and maxi(absi(tracked.x-a.x),absi(tracked.y-a.y)) <= 10: return tracked
 for dy in range(-1, 2):
  for dx in range(-1, 2):
   if a.x+dx not in range(width) or a.y+dy not in range(height): continue
   var b = block_at(a.x+dx, a.y+dy)
   for other in occupants(b):
    if other.human and not other.down:
     if nearby(a, other) or (not other.inside and not a.inside) or (dx == 0 and dy == 0 and not doors_closed(b) and b.barricade == 0): return other
 return {}

func _wander(a: Dictionary) -> void:
 if a.inside:
  _try(a, "leave")
  return
 var options: Array = []
 for dy in range(-1, 2):
  for dx in range(-1, 2):
   if dx == 0 and dy == 0: continue
   if a.x+dx in range(width) and a.y+dy in range(height):
    var b = block_at(a.x+dx, a.y+dy)
    var move = {"dx":dx, "dy":dy}
    if not reason(a,"move",-1,move).is_empty(): continue
    options.append(move)
    if (not a.human and powered(b)) or (a.human and is_building(b) and b.barricade <= 4):
     options.append(move)
     options.append(move)
 if not options.is_empty(): _try(a, "move", -1, options[rng.randi_range(0, options.size()-1)])

func skill_reason(a: Dictionary, skill: String) -> String:
 if not C.SKILLS.has(skill): return "Unknown skill."
 var def = C.SKILLS[skill]
 if skill in a.human_skills or skill in a.zombie_skills: return "Already learned."
 if level(a) < int(def.min_level): return "Reach level %d first." % def.min_level
 if a.xp < skill_cost(a,skill): return "You need %d XP." % skill_cost(a,skill)
 if not str(def.requires).is_empty() and def.requires not in a.human_skills and def.requires not in a.zombie_skills: return "Learn %s first." % C.SKILLS[def.requires].name
 return ""

func learn(skill: String, actor_id: int = 0) -> String:
 var a = actors[actor_id]
 var why = skill_reason(a,skill)
 if not why.is_empty(): return why
 var def = C.SKILLS[skill]
 a.xp -= skill_cost(a,skill)
 if def.side == "human": a.human_skills.append(skill)
 else: a.zombie_skills.append(skill)
 if actor_id == 0: log_event("Learned %s." % def.name)
 return ""

func _learn_npc(a: Dictionary) -> void:
 if a.xp < 75: return
 var priorities: Array = ["construction","first_aid","firearms","hand_to_hand","free_running"] if a.human else ["vigour_mortis","lurching_gait","ankle_grab","memories","death_grip","rend_flesh","feeding_groan","tangling_grasp","digestion","infectious_bite","scent_fear","scent_blood"]
 if a.human and a.job in ["Scientist","NecroTech Lab Assistant"]: priorities = ["lab_experience","necronet","construction","first_aid","free_running","firearms"]
 elif a.human and a.job in ["Doctor","Medic"]: priorities = ["first_aid","construction","surgery","firearms","hand_to_hand","free_running"]
 for skill in C.SKILLS:
  if skill in ["brain_rot","flesh_rot"]: continue
  if C.SKILLS[skill].side == ("human" if a.human else "zombie") and skill not in priorities: priorities.append(skill)
 if not a.human: priorities.append_array(["brain_rot","flesh_rot"])
 for skill in priorities:
  if learn(skill, a.id).is_empty(): return

func threats() -> bool:
 var p = player()
 if p.down: return false
 for a in occupants(current_block(p), p.inside):
  if a.id != 0 and a.human != p.human and not a.down: return true
 return false

func begin_rest(amount: int) -> String:
 if threats(): return "An enemy is within reach. Find shelter before resting."
 if player().busy_until > now(): return "Finish recovering before resting."
 if player().ap >= 50 and not player().down: return "Already at full AP. The world continues while you wait."
 resting = true
 rest_target = mini(50,player().ap+amount)
 rest_end_step = clock_step+1800*C.CLOCK_STEPS_PER_MINUTE
 last_rest_notice = "Resting at 16× speed. Danger cancels fast-forward."
 log_event(last_rest_notice)
 return ""

func stop_rest(message: String = "Rest cancelled.") -> void:
 if not resting: return
 resting = false
 last_rest_notice = message
 log_event(message,"ALERT" if "interrupted" in message else "WORLD",-1,"rest",true)

func population() -> Dictionary:
 var counts = {"humans":0, "zombies":0, "down":0, "powered":0, "ruined":0}
 for a in actors:
  if a.down: counts.down += 1
  elif a.human: counts.humans += 1
  else: counts.zombies += 1
 for b in blocks:
  if powered(b): counts.powered += 1
  if b.ruin >= 3: counts.ruined += 1
 return counts

func time_text() -> String:
 return "DAY %02d  ·  %02d:%02d" % [minute/1440+1, (minute%1440)/60, minute%60]

func log_event(text: String, category: String = "WORLD", actor_id: int = -1, action: String = "", urgent: bool = false) -> void:
 if not actors.is_empty() and player().down and actor_id > 0: return
 event_sequence += 1
 messages.append({"id":event_sequence,"step":clock_step,"minute":minute,"category":category,"actor":actor_id,"action":action,"text":text,"urgent":urgent})
 while messages.size() > 1000: messages.pop_front()

func save_to(path: String) -> Error:
 var file = FileAccess.open(path, FileAccess.WRITE)
 if file == null: return FileAccess.get_open_error()
 file.store_string(JSON.stringify({"version":3, "width":width,"height":height,"world_mode":world_mode,"world_title":world_title,"world_config":world_config,"geography_source":geography_source, "seed":str(world_seed), "rng":str(rng.state), "minute":minute, "clock_step":clock_step, "clock_fraction":clock_fraction, "event_sequence":event_sequence, "blocks":blocks, "actors":actors, "messages":messages, "next_item_id":next_item_id, "scan_report":scan_report, "scan_minute":scan_minute, "npc_cursor":npc_cursor, "next_dialogue":next_dialogue, "sense_report":sense_report, "metrics":metrics}))
 return OK

func load_from(path: String) -> String:
 var file = FileAccess.open(path, FileAccess.READ)
 if file == null: return "No prototype save found."
 var parsed = JSON.parse_string(file.get_as_text())
 if not parsed is Dictionary: return "The save is not valid JSON."
 var loaded_width = int(parsed.get("width",10))
 var loaded_height = int(parsed.get("height",10))
 if loaded_width < 10 or loaded_width > 100 or loaded_height < 10 or loaded_height > 100: return "Invalid map dimensions."
 if int(parsed.get("version",0)) not in [1,2,3] or not parsed.get("blocks") is Array or parsed.blocks.size() != loaded_width*loaded_height or not parsed.get("actors") is Array or parsed.actors.is_empty(): return "The save is incompatible."
 var legacy = parsed.version == 1
 # Validate before replacing the live game. Saves are data, never executable objects.
 for a in parsed.actors:
  if not a is Dictionary: return "Invalid character record."
  for key in ["id", "x", "y", "hp", "ap", "xp", "human", "inside", "down", "inventory", "human_skills", "zombie_skills", "first", "last", "adjective", "job", "equipped", "memory", "memory_until", "ready_at", "busy_until"]:
   if not a.has(key): return "Incomplete character record."
  if a.x < 0 or a.x >= loaded_width or a.y < 0 or a.y >= loaded_height or a.ap < 0 or a.ap > 50: return "Invalid character bounds."
  if a.id != parsed.actors.find(a): return "Invalid character identity."
  for item in a.inventory:
   if not item is Dictionary or not C.ITEMS.has(item.get("kind", "")) or not item.has("uid") or not item.has("ammo") or not item.has("durability"): return "Invalid inventory."
 for i in range(parsed.blocks.size()):
  var b = parsed.blocks[i]
  if not b is Dictionary: return "Invalid block."
  for key in ["id", "x", "y", "type", "name", "barricade", "doors", "ruin", "generator", "fuel_until", "known"]:
   if not b.has(key): return "Incomplete block."
  if b.id != i or b.x != i%loaded_width or b.y != int(i/loaded_width) or b.type not in C.BUILDINGS+C.OUTDOORS: return "Invalid block identity."
 for key in ["seed", "rng", "minute", "messages", "next_item_id", "scan_report", "scan_minute", "npc_cursor", "metrics"]:
  if not parsed.has(key): return "Incomplete save."
 if not legacy:
  for key in ["clock_step","clock_fraction","event_sequence"]:
   if not parsed.has(key): return "Incomplete clock state."
  for a in parsed.actors:
   if not a.has("next_think") or not a.has("last_action"): return "Incomplete actor schedule."
  for event in parsed.messages:
   if not event is Dictionary: return "Invalid event history."
   for key in ["id","step","minute","category","actor","action","text","urgent"]:
    if not event.has(key): return "Incomplete event."
 width = loaded_width
 height = loaded_height
 world_mode = str(parsed.get("world_mode","sandbox"))
 world_title = str(parsed.get("world_title","Dulston"))
 world_config = parsed.get("world_config",{})
 geography_source = parsed.get("geography_source",{})
 blocks = parsed.blocks
 actors = parsed.actors
 # JSON numbers are floats. Normalize integer identity/coordinate fields.
 for a in actors:
  for key in ["id", "x", "y", "hp", "ap", "xp", "equipped", "memory", "memory_until", "ready_at"]: a[key] = int(a[key])
  for key in ["home","supply_goal","next_trip"]: a[key] = int(a.get(key,{"home":int(a.y)*width+int(a.x),"supply_goal":-1,"next_trip":int(parsed.minute)+60}[key]))
  initialize_actor(a)
  a.trust = a.get("trust",{})
  a.request_after = a.get("request_after",{})
  for key in a.trust: a.trust[key] = int(a.trust[key])
  for key in a.request_after: a.request_after[key] = int(a.request_after[key])
  a.speech = str(a.get("speech",""))
  a.speech_until = float(a.get("speech_until",0.0))
  a.next_speech = float(a.get("next_speech",float(parsed.minute)+20.0+float(a.id)*7.0))
  a.dormant = bool(a.get("dormant",false))
  a.supply_kind = str(a.get("supply_kind",""))
  a.busy_until = float(a.busy_until)
  if legacy:
   a.busy_until = float(parsed.minute)
   a.next_think = float(parsed.minute)+1.0+float(a.id%23)/3.0
   a.last_action = ""
  for item in a.inventory:
   for key in ["uid", "ammo", "durability"]: item[key] = int(item[key])
   if item.has("wear"): item.wear = int(item.wear)
 for b in blocks:
  for key in ["id", "x", "y", "barricade", "ruin", "fuel_until"]: b[key] = int(b[key])
  initialize_block(b)
  if not has_doors(b): b.doors = false
  b.description_version = int(b.get("description_version",0))
  b.barricade_damage = int(b.get("barricade_damage",0))
  b.generator_hp = int(b.get("generator_hp",C.GENERATOR_HP))
  b.last_pounding = int(b.get("last_pounding",-9999))
 minute = int(parsed.minute)
 clock_step = int(parsed.get("clock_step",minute*C.CLOCK_STEPS_PER_MINUTE))
 clock_fraction = float(parsed.get("clock_fraction",0.0))
 event_sequence = int(parsed.get("event_sequence",0))
 resting = false
 last_rest_notice = ""
 world_seed = int(parsed.seed)
 for b in blocks: ensure_descriptions(b)
 rng.seed = world_seed
 rng.state = int(parsed.rng)
 messages = [] if legacy else parsed.messages
 if legacy:
  for old_message in parsed.messages: log_event(str(old_message))
 next_item_id = int(parsed.next_item_id)
 scan_report = parsed.scan_report
 scan_minute = int(parsed.scan_minute)
 npc_cursor = int(parsed.npc_cursor)
 next_dialogue = float(parsed.get("next_dialogue",float(parsed.minute)+20.0))
 sense_report = str(parsed.get("sense_report","No recent field report."))
 metrics = parsed.metrics
 rebuild_geography_index()
 reindex()
 return ""

func melee_break_chance(item: Dictionary) -> float:
 # Legacy durability/wear fields remain loadable but no longer affect combat.
 return float(C.ITEMS[item.kind].get("break_on_hit",0.0))

func action_feedback(a: Dictionary, command: String, target: int = -1, data: Dictionary = {}, context_only: bool = false) -> String:
 var why = reason(a, command, target, data, context_only)
 # Entry remains an attempt the player can make, with feedback on rejection.
 if command == "enter" and why.begins_with("You try to find an entry point"): return ""
 if command == "phone" and why == "Select a contact.": return ""
 return why

func skill_cost(a: Dictionary, skill: String) -> int:
 var category = C.skill_category(skill)
 if category in ["zombie", "civilian", "hunter"]: return 100
 var occupation = C.occupation_category(a.job)
 if occupation == category: return 75
 if occupation in ["military", "science"]: return 150
 return 100

func ensure_descriptions(b: Dictionary) -> void:
 # Separate RNG keeps flavour text from changing combat/AI randomness.
 var local_rng = RandomNumberGenerator.new()
 local_rng.seed = world_seed*1000+int(b.id)
 var pool: Dictionary = description_pools.get(b.type, {})
 for side in ["inside", "outside"]:
  var key = side+"_description"
  if b.has(key) and int(b.get("description_version",0)) == 3: continue
  var phrases: Array[String] = []
  for position in ["first", "second", "third"]:
   var choices: Array = pool.get(side, {}).get(position, [])
   if not choices.is_empty(): phrases.append(choices[local_rng.randi_range(0,choices.size()-1)])
  b[key] = " ".join(phrases) if not phrases.is_empty() else "This place shows signs of decay and neglect."
 b.description_version = 3

func location_description(a: Dictionary) -> String:
 if a.down: return "You are down. Everything is dark. Rest and stand up to see your surroundings again."
 var b = current_block(a)
 ensure_descriptions(b)
 var observation = "You are %s %s. " % ["inside" if a.inside else "outside",b.name]
 if is_building(b):
  observation += ("The fence opening is %s. " if b.type == "junkyard" else "The building is %s. ") % C.barricade_description(b.barricade)
  if not has_doors(b): observation += "A hole cut in the fence serves as the entrance. " if b.type == "junkyard" else "A broad opening leads into the site. "
  elif not doors_closed(b): observation += "The doors stand wide open. "
  elif b.barricade == 0: observation += "The doors are closed. "
  if a.inside:
   observation += "The lights are on. " if powered(b) else "It is too dim to see clearly. "
  else:
   observation += "Lights are on inside. " if powered(b) else "No lights show inside. "
  if a.inside or not doors_closed(b):
   if b.ruin >= 3: observation += "The interior is completely ruined and needs major repairs. "
   elif b.ruin > 0: observation += "The interior is ransacked and needs repairs. "
  if a.inside and b.generator:
   observation += "A portable generator is %s, %s. " % [generator_condition(b),"running" if powered(b) else "out of fuel"]
 var humans = 0
 var zombies = 0
 var bodies = 0
 for other in occupants(b,a.inside):
  if other.id == a.id: continue
  if other.down: bodies += 1
  elif other.human: humans += 1
  else: zombies += 1
 if humans > 0: observation += "There is another survivor here. " if humans == 1 else "There are %d other survivors here. " % humans
 if zombies > 0: observation += "There is a lone zombie here. " if zombies == 1 else "There are %d zombies here. " % zombies
 if bodies > 0: observation += "You see a dead body. " if bodies == 1 else "You see %d dead bodies. " % bodies
 if not b.graffiti.is_empty(): observation += "A painted message reads: %s. " % (b.graffiti.left(80)+("…" if b.graffiti.length() > 80 else ""))
 if a.inside and not b.decorations.is_empty():
  var names: Array[String] = []
  for kind in b.decorations.slice(0,3): names.append(C.ITEMS[kind].name)
  observation += "Decorations: "+", ".join(names)+(" and %d more" % (b.decorations.size()-3) if b.decorations.size() > 3 else "")+". "
 if has_skill(a,"scent_death"):
  var changing = occupants(b,a.inside).filter(func(t): return t.down and t.human).size()
  if changing > 0: observation += "%d bodies carry the scent of revival. " % changing
 return b["inside_description" if a.inside else "outside_description"]+"\n\n"+observation.strip_edges()

func time_speed() -> float:
 var p = player()
 if p.down and (p.ap < cost(p,"stand") or minute < p.ready_at): return C.DEATH_SPEED
 return C.REST_SPEED if resting else 1.0

func reanimate_bodies() -> void:
 for a in actors:
  if a.id > 0 and a.get("dormant",false) and rng.randf() < C.DAILY_REANIMATION_CHANCE:
   a.dormant = false
   a.ready_at = minute
   a.next_think = now()+rng.randf_range(1,60)

func generator_condition(b: Dictionary) -> String:
 if b.generator_hp <= 0: return "destroyed"
 if b.generator_hp <= 2: return "badly damaged"
 if b.generator_hp <= 4: return "damaged"
 if b.generator_hp < C.GENERATOR_HP: return "dented"
 return "in good condition"

func supply_needed_by(a: Dictionary, kind: String) -> bool:
 match kind:
  "first_aid_kit": return a.job in ["Doctor","Medic"] or has_skill(a,"first_aid") or a.hp < 40
  "toolbox": return has_skill(a,"construction")
  "portable_generator": return AI.shelter_worker(self,a)
  "pistol_clip": return not item_kind(a,"pistol").is_empty()
  "shotgun_shell": return not item_kind(a,"shotgun").is_empty()
  "syringe": return has_skill(a,"lab_experience")
  "fuel_can": return AI.shelter_worker(self,a)
 return false

func wanted_supply(a: Dictionary) -> String:
 if a.hp < 40 and item_kind(a,"first_aid_kit").is_empty(): return "first_aid_kit"
 if item_kind(a,"toolbox").is_empty() and (has_skill(a,"construction") or (blocks[a.home].generator and blocks[a.home].generator_hp < C.GENERATOR_HP)): return "toolbox"
 if (a.job in ["Doctor","Medic"] or has_skill(a,"first_aid")) and item_kind(a,"first_aid_kit").is_empty(): return "first_aid_kit"
 if has_skill(a,"lab_experience") and item_kind(a,"syringe").is_empty(): return "syringe"
 var home = blocks[a.home]
 if AI.shelter_worker(self,a):
  if not home.generator and item_kind(a,"portable_generator").is_empty(): return "portable_generator"
  if not powered(home) and item_kind(a,"fuel_can").is_empty(): return "fuel_can"
 var communal = AI.group_need(self,a)
 if not communal.is_empty(): return communal
 var armed = false
 for item in a.inventory:
  if C.ITEMS[item.kind].has("damage"): armed = true
 if not armed: return "crowbar" if a.job == "Engineer" else "baseball_bat"
 if not item_kind(a,"pistol").is_empty() and item_kind(a,"pistol_clip").is_empty(): return "pistol_clip"
 if not item_kind(a,"shotgun").is_empty() and item_kind(a,"shotgun_shell").is_empty(): return "shotgun_shell"
 return ""

func human_expedition(a: Dictionary) -> bool:
 # Trips are directed toward resources, then back to a small shared shelter.
 if a.supply_goal >= 0:
  if not a.supply_kind.is_empty() and not item_kind(a,a.supply_kind).is_empty():
   a.supply_goal = a.home
   a.supply_kind = ""
  var goal = blocks[a.supply_goal]
  if a.x != goal.x or a.y != goal.y:
   if AI.go(self,a,goal): return true
   a.avoid_site = goal.id
   a.avoid_until = minute+180
   a.supply_goal = -1
   a.supply_kind = ""
   a.next_trip = minute+30
   return false
  if not a.inside:
   if _try(a,"enter"): return true
   # A shelter that became impassable should not strand a returning survivor.
   if goal.barricade > 4:
    a.supply_goal = -1
    a.supply_kind = ""
    a.next_trip = minute+60
   return false
  if a.supply_kind.is_empty():
   a.supply_goal = -1
   a.next_trip = minute+120+a.id*3
   return false
  if encumbrance(a) >= C.ENCUMBRANCE_LIMIT:
   for item in a.inventory:
    if item.uid != a.equipped and not supply_needed_by(a,item.kind) and item.kind != a.supply_kind:
     return _try(a,"drop",-1,{"uid":item.uid})
   a.supply_goal = a.home
   a.supply_kind = ""
   return false
  return _try(a,"search")
 if minute < a.next_trip: return false
 var kind = wanted_supply(a)
 if not kind.is_empty():
  var best = -1
  var best_score = 9999.0
  var sources: Array = []
  for type in sites_by_type:
   if kind in search_loot(type): sources.append_array(sites_by_type[type])
  for site in sources:
   if not is_building(site) or site.barricade > 4 or (site.id == a.avoid_site and minute < a.avoid_until): continue
   var trip = maxi(absi(site.x-a.x),absi(site.y-a.y))
   if trip*2+10 > a.ap: continue
   var score = maxf(absf(site.x-a.x),absf(site.y-a.y))*3 + minf(100.0,0.4/maxf(0.000001,item_search_chance(site,kind)))
   if score < best_score:
    best = site.id
    best_score = score
  if best >= 0:
   a.supply_goal = best
   a.supply_kind = kind
   return human_expedition(a)
 # When supplied, join an undersized nearby group and help maintain its shelter.
 var destination = -1
 var distance = 999.0
 for site_id in spatial:
  var site = blocks[site_id]
  if not is_building(site) or site.barricade > 4: continue
  var allies = 0
  for other in occupants(site,true):
   if other.id != a.id and other.human and not other.down: allies += 1
  if allies < 1 or allies > 2 or site.id == current_block(a).id: continue
  var d = maxf(absf(site.x-a.x),absf(site.y-a.y))
  if d < distance:
   destination = site.id
   distance = d
 if destination >= 0:
  a.home = destination
  a.supply_goal = destination
  return human_expedition(a)
 a.next_trip = minute+120
 return false

func nearby_light(a: Dictionary) -> Dictionary:
 var best: Dictionary = {}
 var distance = 4
 for y in range(maxi(0,a.y-3),mini(height,a.y+4)):
  for x in range(maxi(0,a.x-3),mini(width,a.x+4)):
   var b = block_at(x,y)
   var d = maxi(absi(x-a.x),absi(y-a.y))
   if powered(b) and d < distance:
    best = b
    distance = d
 return best

func _maybe_speak(a: Dictionary) -> void:
 if a.id == 0 or a.down or player().down or resting or not nearby(a,player()): return
 if now() < next_dialogue or now() < a.next_speech: return
 var local = RandomNumberGenerator.new()
 # Chatter changes neither combat randomness nor the actor's AP/recovery.
 local.seed = world_seed*1000003+a.id*7919+int(a.next_speech*10)
 var choices = speech_options(a)
 if choices.size() > 1: choices = choices.filter(func(line): return line != a.speech)
 var line: String = choices[local.randi_range(0,choices.size()-1)]
 speak(a,line)
 a.next_speech = now()+local.randf_range(60.0,150.0)
 next_dialogue = now()+local.randf_range(22.0,42.0)

func speech_options(a: Dictionary) -> Array:
 var b = current_block(a)
 var people = occupants(b,a.inside)
 var context = {"lit":powered(b),"building":is_building(b),"bodies":false,"enemy":false,"injured_ally":false,"pounding":a.inside and b.barricade > 0 and b.last_pounding >= minute-10}
 for other in people:
  if other.id == a.id: continue
  if other.down: context.bodies = true
  elif other.human != a.human: context.enemy = true
  elif other.hp < 35: context.injured_ally = true
 return Dialogue.choices(a,b,context)

func speak(a: Dictionary, line: String) -> bool:
 if a.id == 0 or a.down or player().down or not nearby(a,player()): return false
 a.speech = line
 a.speech_until = now()+6.0
 var text = "%s: %s" % [display_name(a),line]
 log_event(text,"ALLY" if a.human == player().human else "ENEMY",a.id,"speech")
 return true

func trust_level(npc: Dictionary, helper: Dictionary) -> int:
 return int(npc.trust.get(str(helper.id),0))

func add_trust(npc: Dictionary, helper: Dictionary, amount: int) -> void:
 if npc.id == helper.id or not npc.human or not helper.human: return
 npc.trust[str(helper.id)] = clampi(trust_level(npc,helper)+amount,0,100)

func gain_local_trust(helper: Dictionary, b: Dictionary, amount: int) -> void:
 for witness in occupants(b,true):
  if not witness.down: add_trust(witness,helper,amount)

func trust_description(npc: Dictionary, helper: Dictionary) -> String:
 var value = trust_level(npc,helper)
 if value >= 60: return "Trusts you"
 if value >= 30: return "Growing trust"
 if value >= 15: return "Getting to know you"
 return "Wary of you"

func _spare_item(npc: Dictionary, requester: Dictionary) -> Dictionary:
 var trust = trust_level(npc,requester)
 if trust < 15: return {}
 for item in npc.inventory:
  if not acquisition_reason(requester,item.kind).is_empty(): continue
  if item.uid == npc.equipped: continue
  var count = 0
  var weapons = 0
  for carried in npc.inventory:
   if carried.kind == item.kind: count += 1
   if C.ITEMS[carried.kind].has("damage"): weapons += 1
  if C.ITEMS[item.kind].has("damage") and weapons <= 1: continue
  if supply_needed_by(npc,item.kind) and count <= 1: continue
  if item.kind in ["portable_generator","syringe","fuel_can","shotgun"] and trust < 60: continue
  if count <= 1 and trust < 35: continue
  return item
 return {}

func request_supplies(requester: Dictionary, npc: Dictionary) -> String:
 var key = str(requester.id)
 var prefix = display_name(npc)
 if int(npc.request_after.get(key,0)) > minute:
  return supply_reply(npc,"Give me a moment. I have already answered you.","%s says: Give me a moment. I have already answered you." % prefix)
 npc.request_after[key] = minute+10
 var trust = trust_level(npc,requester)
 if trust < 15:
  return supply_reply(npc,"Help us first. I need to know I can count on you.","%s refuses: I need to know I can count on you first. Help us out around here." % prefix)
 var item = _spare_item(npc,requester)
 if item.is_empty(): return supply_reply(npc,"I need these supplies. I cannot spare them.","%s hesitates: I need to keep these supplies. I cannot spare anything right now." % prefix)
 if rng.randf() > 0.30+0.006*trust:
  return supply_reply(npc,"You have helped us, but I need to keep these for now.","%s hesitates: You have helped us, but I need to hold onto my supplies for now." % prefix)
 npc.inventory.erase(item)
 requester.inventory.append(item)
 npc.trust[key] = maxi(0,trust-10)
 return supply_reply(npc,"You have earned a hand. Please make it count.","%s shares %s: You have earned a hand. Please make it count." % [prefix,C.ITEMS[item.kind].name])

func supply_reply(npc: Dictionary, line: String, message: String) -> String:
 npc.speech = line
 npc.speech_until = now()+6.0
 next_dialogue = maxf(next_dialogue,now()+22.0)
 return message

func max_hp(a: Dictionary) -> int:
 return Extended.max_hp(a)

func level(a: Dictionary) -> int:
 return maxi(1,a.human_skills.size()+a.zombie_skills.size())

func initialize_actor(a: Dictionary) -> void:
 var defaults = {"wants_revive":false,"route":[],"route_goal":-1,"avoid_site":-1,"avoid_until":0,"next_groan":0,"grasp_target":-1,"grasped_by":-1,"infected":false,"pose":"idle","pose_at":0.0,"pose_sequence":0,"trail_from":-1,"trail_until":0,"scout_site":-1,"scout_day":-1,"scout_used":0,"fed":0,"headshot":0,"tagged_until":0,"channel":27.0,"outfit":""}
 for key in defaults:
  if not a.has(key): a[key] = defaults[key]
 for key in ["route_goal","avoid_site","avoid_until","next_groan","grasp_target","grasped_by","pose_sequence","trail_from","trail_until","scout_site","scout_day","scout_used","fed","headshot","tagged_until"]: a[key] = int(a[key])
 a.route = a.route.map(func(id): return int(id))
 a.pose_at = float(a.pose_at)
 a.channel = float(a.channel)

func initialize_block(b: Dictionary) -> void:
 var defaults = {"barricade":0,"doors":false,"ruin":0,"generator":false,"generator_hp":C.GENERATOR_HP,"fuel_until":0,"known":false,"barricade_damage":0,"last_pounding":-9999,"zoo":"","unbarricadable":false,"radio":false,"radio_hp":0,"frequency":27.0,"graffiti":"","decorations":[],"complex":"","fort":"","mast":false}
 for key in defaults:
  if not b.has(key): b[key] = defaults[key]
 b.unbarricadable = not is_building(b)
 if b.unbarricadable: b.barricade = 0; b.barricade_damage = 0
 if not has_doors(b): b.doors = false
 b.radio_hp = int(b.radio_hp)
 b.frequency = float(b.frequency)

func clear_grasp(a: Dictionary) -> void:
 if a.grasp_target >= 0 and a.grasp_target < actors.size(): actors[a.grasp_target].grasped_by = -1
 if a.grasped_by >= 0 and a.grasped_by < actors.size(): actors[a.grasped_by].grasp_target = -1
 a.grasp_target = -1
 a.grasped_by = -1

func claim_grasp(a: Dictionary, target: Dictionary) -> void:
 if target.grasped_by >= 0 and target.grasped_by != a.id: actors[target.grasped_by].grasp_target = -1
 if a.grasp_target >= 0 and a.grasp_target != target.id: actors[a.grasp_target].grasped_by = -1
 target.grasped_by = a.id
 a.grasp_target = target.id

func set_pose(a: Dictionary, pose: String) -> void:
 a.pose = pose
 a.pose_at = now()
 a.pose_sequence += 1

func attack_stats(a: Dictionary, target: Dictionary, command: String, weapon: Dictionary = {}) -> Dictionary:
 var hit = 25
 var damage = 1
 var ranged = false
 if not a.human and command != "bite" and not weapon.is_empty() and weapon.kind in C.ZOMBIE_MELEE_ITEMS:
  hit = C.ITEMS[weapon.kind].hit
  damage = 2
 elif not a.human:
  hit = (10 if command == "bite" else 25)+(10 if has_skill(a,"vigour_mortis") else 0)
  damage = 4 if command == "bite" else 2+(1 if has_skill(a,"rend_flesh") else 0)
  hit += (10 if has_skill(a,"neck_lurch") else 0) if command == "bite" else (15 if has_skill(a,"death_grip") else 0)
  if a.grasp_target == target.id and target.grasped_by == a.id: hit += 10
 else:
  if not weapon.is_empty():
   var def = C.ITEMS[weapon.kind]
   hit = def.hit
   damage = def.damage
   ranged = def.has("capacity") or def.get("ranged",false)
  if ranged:
   if has_skill(a,"firearms"): hit += 25
   if weapon.kind == "pistol": hit += (25 if has_skill(a,"pistol_training") else 0)+(10 if has_skill(a,"advanced_pistol") else 0)
   if weapon.kind == "shotgun": hit += (25 if has_skill(a,"shotgun_training") else 0)+(10 if has_skill(a,"advanced_shotgun") else 0)
  else:
   if has_skill(a,"hand_to_hand"): hit += 15
   if not weapon.is_empty() and weapon.kind == "knife" and has_skill(a,"knife_combat"): hit += 15
   if not weapon.is_empty() and weapon.kind == "fire_axe" and has_skill(a,"axe_proficiency"): hit += 15
 if current_block(a).type in ["bank","cinema","nightclub","armoury"] and a.inside and not powered(current_block(a)): hit = int(floor(hit*0.5))
 return {"hit":clampi(hit,0,95),"damage":damage,"ranged":ranged}

func fort_move_reason(a: Dictionary, origin: Dictionary, destination: Dictionary) -> String:
 if origin.fort == destination.fort:
  if not origin.fort.is_empty() and origin.type == "gatehouse" and not a.inside: return "Enter the gatehouse before crossing into the fort."
  return ""
 if not origin.fort.is_empty() and origin.type != "gatehouse": return "The fort walls block this route. Use the gatehouse."
 if not destination.fort.is_empty() and destination.type != "gatehouse": return "Enter the fort through its gatehouse."
 if origin.type == "gatehouse" and not origin.fort.is_empty() and a.inside and origin.barricade > 4: return "The gatehouse is too heavily barricaded to leave the compound."
 return ""

func _setup_player(a: Dictionary, occupation: String) -> void:
 var setups = {"Private":[["firearms"],["pistol","pistol_clip"]],"Medic":[["first_aid"],["pistol","first_aid_kit"]],"Scout":[["free_running"],["binoculars"]],"NecroTech Lab Assistant":[["necro_employment"],["dna_extractor"]],"Doctor":[["diagnosis"],["first_aid_kit","first_aid_kit"]],"Police Officer":[["firearms"],["pistol","pistol_clip","flak_jacket","radio"]],"Firefighter":[["hand_to_hand","axe_proficiency"],["fire_axe","first_aid_kit"]],"Consumer":[["shopping"],["baseball_bat","mobile_phone"]],"Corpse":[[],[]],"Volunteer":[["construction","necro_employment","lab_experience"],["baseball_bat","first_aid_kit","toolbox","syringe"]]}
 var setup = setups.get(occupation,setups.Volunteer)
 a.human_skills = setup[0].duplicate()
 a.human = occupation != "Corpse"
 if not a.human: a.zombie_skills = ["vigour_mortis"]
 for kind in setup[1]: give_item(a,kind)
 for item in a.inventory:
  if C.ITEMS[item.kind].has("damage"):
   a.equipped = item.uid if a.human else -1
   break

func _place_special_sites() -> void:
 for b in blocks:
  if b.type == "mall": b.type = "office"
 # Use a clear 2x2 location away from the opening services.
 var fort = {0:"barracks",1:"storehouse",2:"vehicle_depot",10:"infirmary",11:"armoury",12:"gatehouse",20:"barracks",21:"exercise_yard",22:"training_ground"}
 for id in fort:
  blocks[id].type = fort[id]
  blocks[id].fort = "Fort Perryn"
  blocks[id].name = "Fort Perryn "+C.pretty(fort[id])
 var large = {"cathedral":[7,8,17,18],"mansion":[77,78,87,88],"power_station":[70,71,80,81],"stadium":[37,38,47,48]}
 for kind in large:
  for id in large[kind]:
   blocks[id].type = kind
   blocks[id].complex = kind
   blocks[id].name = "Dulston "+C.pretty(kind)
 var zoo = {60:"aquarium",61:"bear_pit",62:"elephant_house",63:"giraffe_house",70:"lion_enclosure",71:"reptile_house",72:"zoo_ground",73:"zoo_ground",80:"zoo_ground",81:"zoo_ground",82:"zoo_ground",83:"zoo_ground",90:"zoo_ground",91:"zoo_ground",92:"zoo_ground",93:"zoo_ground"}
 for id in zoo:
  blocks[id].type = zoo[id]
  blocks[id].name = "Malton Zoo "+C.pretty(zoo[id])
  blocks[id].zoo = "Malton Zoo"
  blocks[id].complex = "Malton Zoo"
  blocks[id].unbarricadable = blocks[id].type in C.OUTDOORS
 for id in [25,26,35,36]:
  blocks[id].type = "mall"
  blocks[id].name = "Dulston Mall"
  blocks[id].complex = "Dulston Mall"
 blocks[99].type = "wasteland"
 blocks[99].name = "The abandoned lots"
 blocks[54].mast = true
