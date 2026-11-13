extends RefCounted
## UI-independent rules. Player and AI use the same validation and transactions.
signal player_damaged(amount: int, human: bool)
signal sound_requested(effect: String)
signal rest_finished
const C = preload("res://scripts/catalog.gd")
const Dialogue = preload("res://scripts/dialogue.gd")
const Extended = preload("res://scripts/extended_rules.gd")
const World = preload("res://scripts/world_builder.gd")
const AI = preload("res://scripts/npc_ai.gd")
const NpcGate = preload("res://scripts/npc_utility/action_gate.gd")
const NpcSchedule = preload("res://scripts/npc_utility/scheduler.gd")
const NpcPlanner = preload("res://scripts/npc_utility/planner.gd")
const PerformanceCounters = preload("res://scripts/performance_counters.gd")
const SAVE_PATH = "user://prototype-save.json"
const DEFAULT_SEED = 4815
var navigation: AStar2D
var performance_counters: PerformanceCounters
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
var visited_neighbourhoods: Dictionary = {}
var actors: Array = []
var npc_sex_counts: Dictionary = {}
var messages: Array = []
var minute: int = 480
var clock_step: int = 4800
var clock_fraction: float = 0.0
var resting: bool = false
var sleeping: bool = false
var sleep_damage_hits: int = 0
var sleep_last_damage_at: float = -1000.0
var rest_target: int = 0
var rest_end_step: int = 0
var last_rest_notice: String = ""
var event_sequence: int = 0
var world_seed: int = DEFAULT_SEED
var next_item_id: int = 1
var scan_report: String = "No scan yet. Use a powered NecroTech lab."
var scan_minute: int = -1
var scan_cells: Array = []
const MAIN_DOORS_BLOCKED = "The building has been so heavily barricaded that you cannot leave by the main doors."
var spatial: Dictionary = {}
const EMPTY_OCCUPANT_IDS: Array = []
var npc_cursor: int = 0
var npc_schedule = NpcSchedule.new()
var npc_planner = NpcPlanner.new()
var revive_sites: Dictionary[int, bool] = {}
var radio_defense: Dictionary = {}
var next_dialogue: float = 500.0
var sense_report: String = "No recent field report."
var scent_heatmap: Array[Dictionary] = []
var binocular_area: Rect2i
var binocular_direction: String = ""
const BINOCULAR_DIRECTION_REQUIRED = "Choose a compass direction."
const SKYLINE_RADIUS = 10
var scent_trackers: Dictionary = {}
const BRAIN_ROT_REVIVAL_BLOCKED = "Brain Rot requires a powered NecroTech lab and NecroNet access."
const BRAIN_ROT_EXTRACTION_BLOCKED = "Brain Rot prevents DNA extraction."
const CORPSE_REVIVAL_BLOCKED = "You cannot revive that body."
var metrics: Dictionary = {"attacks":0, "deaths":0, "revivals":0, "npc_actions":0}

func start(seed_value: int = DEFAULT_SEED, occupation: String = "Volunteer", config: Dictionary = {}) -> String:
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
 visited_neighbourhoods.clear()
 actors.clear()
 npc_sex_counts.clear()
 messages.clear()
 minute = 480
 clock_step = 4800
 clock_fraction = 0.0
 resting = false
 sleeping = false
 last_rest_notice = ""
 event_sequence = 0
 next_item_id = 1
 npc_cursor = 0
 next_dialogue = 500.0
 scan_report = "No scan yet. Use a powered NecroTech lab."
 scan_minute = -1
 scan_cells.clear()
 sense_report = "No recent field report."
 scent_heatmap.clear()
 metrics = {"attacks":0, "deaths":0, "revivals":0, "npc_actions":0}
 radio_defense.clear()
 if not geography.is_empty():
  _start_geography(geography,occupation,config)
  _reset_npc_runtime()
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
 var workplaces = {"Private":["armoury","police_department"], "Medic":["hospital"], "Scout":["police_department"], "Doctor":["hospital"], "NecroTech Lab Assistant":["necrotech_lab"], "Consumer":["mall"], "Police Officer":["police_department"], "Firefighter":["fire_station"], "Corpse":["hospital"]}
 var opening = blocks.filter(func(site): return site.type in workplaces.get(occupation,["hospital"]) and is_building(site))
 if opening.is_empty(): opening = blocks.filter(func(site): return is_building(site))
 var start_site: Dictionary = opening[rng.randi_range(0,opening.size()-1)]
 var p = _actor("Alex", "Morgan", "Ashen", occupation, start_site.x, start_site.y, true, true)
 _setup_player(p,occupation)
 var jobs = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer"]
 for i in range(14):
  var site: Dictionary = blocks[rng.randi_range(0,blocks.size()-1)]
  var job: String = jobs[rng.randi_range(0,jobs.size()-1)]
  var h = _actor("", "", "", job, site.x, site.y, true, is_building(site) and rng.randf() < 0.65)
  _setup_player(h,job)
 for i in range(18):
  var site: Dictionary = blocks[rng.randi_range(0,blocks.size()-1)]
  var z = _actor("", "", "", "Corpse", site.x, site.y, false, is_building(site) and rng.randf() < 0.5)
  _setup_starting_skills(z,"Corpse")
  if i >= 3:
   z.down = true
   z.hp = 0
   z.dormant = true
 ensure_unique_npc_names()
 for a in actors: a.home = a.y*width+a.x
 rebuild_geography_index()
 reindex()
 _reset_npc_runtime()
 discover()
 log_event("You awaken at %s." % start_site.name)
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
 # Start where the character's former life (or death) makes sense. Prefer
 # accessible buildings; generated maps may omit a particular workplace.
 var starting_workplaces = {"Private":["armoury", "police_department"], "Medic":["hospital"], "Scout":["armoury", "police_department"], "Doctor":["hospital"], "NecroTech Lab Assistant":["necrotech_lab"], "Consumer":["mall"], "Police Officer":["police_department"], "Firefighter":["fire_station"], "Corpse":["hospital"]}
 var opening: Array = []
 for kind in starting_workplaces.get(occupation, ["hospital"]):
  opening = blocks.filter(func(b): return b.type == kind and is_building(b) and not b.unbarricadable)
  if not opening.is_empty(): break
 if opening.is_empty(): opening = blocks.filter(func(b): return is_building(b) and b.fort.is_empty() and not b.unbarricadable)
 var start_site: Dictionary = blocks[0] if opening.is_empty() else opening[rng.randi_range(0,opening.size()-1)]
 if world_mode == "malton":
  var dulston = opening.filter(func(b): return b.get("suburb","") == "Dulston")
  if not dulston.is_empty(): start_site = dulston[rng.randi_range(0,dulston.size()-1)]
 var p = _actor("Alex","Morgan","Ashen",occupation,start_site.x,start_site.y,true,is_building(start_site))
 _setup_player(p,occupation)
 var shelters = blocks.filter(func(b): return is_building(b) and b.fort.is_empty() and not b.unbarricadable)
 if shelters.is_empty(): shelters = blocks
 var population = World.population_defaults(width,height,str(config.get("difficulty","medium")))
 var human_count = clampi(int(config.get("survivors",population.x)),0,2000)
 var zombie_count = clampi(int(config.get("zombies",population.y)),0,4000)
 var jobs = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer"]
 for i in range(human_count):
  var site: Dictionary = blocks[rng.randi_range(0,blocks.size()-1)]
  var job: String = jobs[rng.randi_range(0,jobs.size()-1)]
  var a = _actor("","","",job,site.x,site.y,true,is_building(site) and rng.randf() < 0.65)
  _setup_player(a,job)
 for i in range(zombie_count):
  var site = blocks[rng.randi_range(0,blocks.size()-1)]
  var a = _actor("","","","Corpse",site.x,site.y,false,is_building(site) and rng.randf() < 0.5)
  _setup_starting_skills(a,"Corpse")
  if i >= maxi(1,int(zombie_count*0.16)):
   a.down = true
   a.hp = 0
   a.dormant = true
 ensure_unique_npc_names()
 for a in actors: a.home = a.y*width+a.x
 reindex()
 discover()
 log_event("You awaken at %s in %s." % [start_site.name,start_site.get("suburb",world_title)])
 log_event("%s: %d × %d blocks. Most of the dead are still motionless." % [world_title,width,height])

func phone_coverage(a: Dictionary) -> bool:
 return mast_sites.any(func(site): return site.get("suburb",world_title) == suburb_name(a) and powered(site))

func suburb_name(a: Dictionary) -> String:
 return current_block(a).get("suburb",world_title)

func _actor(first: String, last: String, adjective: String, job: String, x: int, y: int, human: bool, inside: bool) -> Dictionary:
 var actor = {"id":actors.size(), "first":first, "last":last, "adjective":adjective, "job":job, "x":x, "y":y, "human":human, "inside":inside, "down":false, "hp":50, "ap":50, "xp":0, "human_skills":[], "zombie_skills":[], "inventory":[], "equipped":-1, "memory":-1, "memory_until":0, "ready_at":0, "busy_until":0.0, "next_think":480.0+rng.randf_range(1.0,8.0), "last_action":"","dormant":false,"home":y*width+x,"supply_goal":-1,"supply_kind":"","next_trip":500+actors.size()*3,"trust":{},"request_after":{},"speech":"","speech_until":0.0,"next_speech":500.0+actors.size()*7.0}
 actor.original_human = human
 actor.sex = _next_npc_sex(job) if actor.id > 0 else C.occupation_sex(job)
 actor.prefers_undead = actor.id > 0 and not human and int(actor.id)%3 != 0
 initialize_actor(actor)
 actors.append(actor)
 return actor

func _next_npc_sex(job: String) -> String:
 # Balance each occupation independently; alternate the extra NPC for odd totals
 # by world seed, without consuming the gameplay random stream.
 var counts: Dictionary = npc_sex_counts.get(job,{"male":0,"female":0})
 var sex = "male" if counts.male < counts.female else "female"
 if counts.male == counts.female:
  sex = "male" if (world_seed + int(job.hash()) + int(counts.male)) % 2 == 0 else "female"
 counts[sex] += 1
 npc_sex_counts[job] = counts
 return sex

func player() -> Dictionary:
 return actors[0]

func visible_type(b: Dictionary, observer: Dictionary) -> String:
 return "office" if b.type == "necrotech_lab" and not has_skill(observer,"necro_employment") and not (current_block(observer).id == b.id and observer.inside) else b.type

func action_phrase(a: Dictionary, player_verb: String, npc_verb: String) -> String:
 return "You " + player_verb if a.id == 0 else display_name(a) + " " + npc_verb

func display_name(a: Dictionary) -> String:
 return (a.first + " " + a.last) if a.human else (a.adjective + " " + a.first)

func ensure_unique_npc_names() -> void:
 # Use a separate random stream so naming never changes the simulation's rolls.
 var naming_rng = RandomNumberGenerator.new()
 naming_rng.seed = world_seed + 71391
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/character_names.json"))
 var adjectives: Array = []
 for prefix in ["", "Deeply ", "Dreadfully ", "Gruesomely ", "Horribly ", "Terribly ", "Utterly ", "Vilely ", "Grimly ", "Ghastly ", "Foully ", "Sickeningly ", "Hideously ", "Wretchedly "]:
  for word in data.zombie_adjective: adjectives.append(prefix + word)
 for i in range(adjectives.size()-1, 0, -1):
  var j = naming_rng.randi_range(0,i)
  var temp = adjectives[i]
  adjectives[i] = adjectives[j]
  adjectives[j] = temp
 var used_names = {(player().first + " " + player().last).to_lower(): true}
 var used_adjectives = {str(player().adjective).to_lower(): true}
 var adjective_index = 0
 for i in range(1,actors.size()):
  var a: Dictionary = actors[i]
  var full_name = (a.first + " " + a.last).to_lower()
  var first_names: Array = data.male_first_name if a.sex == "male" else data.female_first_name
  if a.first not in first_names or a.last.is_empty() or used_names.has(full_name):
   while true:
    a.first = first_names[naming_rng.randi_range(0,first_names.size()-1)]
    a.last = data.last_name[naming_rng.randi_range(0,data.last_name.size()-1)]
    full_name = (a.first + " " + a.last).to_lower()
    if not used_names.has(full_name): break
  used_names[full_name] = true
  if a.adjective.is_empty() or used_adjectives.has(a.adjective.to_lower()):
   while used_adjectives.has(str(adjectives[adjective_index]).to_lower()): adjective_index += 1
   a.adjective = adjectives[adjective_index]
   adjective_index += 1
  used_adjectives[a.adjective.to_lower()] = true

func encumbrance(a: Dictionary) -> int:
 var total = 0
 for item in a.inventory: total += int(C.ITEMS[item.kind].encumbrance)
 return total

func acquisition_reason(a: Dictionary, kind: String = "") -> String:
 if a.inventory.size() >= C.INVENTORY_ITEM_LIMIT: return "You are carrying 100 items. Drop or use an item before collecting more."
 if encumbrance(a) >= C.ENCUMBRANCE_LIMIT: return "Already carrying %d%%; drop or use an item first." % encumbrance(a)
 if kind == "candy" and not item_kind(a,"candy").is_empty(): return "You already carry a bag of candy."
 if kind in ["dead_fir_tree","plastic_christmas_tree"] and (not item_kind(a,"dead_fir_tree").is_empty() or not item_kind(a,"plastic_christmas_tree").is_empty()): return "You can carry only one Christmas tree."
 return ""

func can_barricade(b: Dictionary) -> bool:
 return is_building(b) and not b.get("unbarricadable",false)

func give_item(a: Dictionary, kind: String) -> void:
 var def: Dictionary = C.ITEMS[kind]
 var item = {"uid":next_item_id, "kind":kind, "ammo":def.get("capacity", 0), "durability":def.get("durability", 0)}
 if kind == "radio": item.frequency = C.PUBLIC_RADIO_FREQUENCY
 a.inventory.append(item)
 next_item_id += 1

func block_at(x: int, y: int) -> Dictionary:
 return blocks[y*width+x]

func current_block(a: Dictionary) -> Dictionary:
 return block_at(a.x, a.y)

func query_route(from_id: int, to_id: int) -> PackedInt64Array:
 if performance_counters != null: performance_counters.path_queries += 1
 return navigation.get_id_path(from_id,to_id)

func is_building(b: Dictionary) -> bool:
 return b.type not in C.OUTDOORS

func has_doors(b: Dictionary) -> bool:
 return is_building(b) and b.type not in ["junkyard","church","cathedral","gatehouse","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]

func doors_closed(b: Dictionary) -> bool:
 return has_doors(b) and b.doors

func secure_zombie_exit(a: Dictionary, b: Dictionary) -> void:
 if not a.human and has_doors(b): b.doors = true

func powered(b: Dictionary) -> bool:
 return can_host_generator(b) and b.generator and b.generator_hp > 0 and b.fuel_until > minute

func can_host_generator(b: Dictionary) -> bool:
 return is_building(b) and b.type not in ["junkyard","stadium","power_station"]

func can_be_ransacked(b: Dictionary) -> bool:
 return is_building(b) and b.type not in ["junkyard","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]

func repair_cost(b: Dictionary) -> int:
 return 1+maxi(0,(minute-int(b.get("ruined_at",minute)))/1440) if b.ruin >= 3 else 1

func is_dark_building(b: Dictionary) -> bool:
 return b.type in C.DARK_BUILDINGS

func has_skill(a: Dictionary, skill: String) -> bool:
 if skill in ["body_building","necro_employment","ankle_grab","death_lurch","scent_death"]: return skill in a.human_skills or skill in a.zombie_skills
 return skill in (a.human_skills if a.human else a.zombie_skills)

func reindex() -> void:
 spatial.clear()
 scent_trackers.clear()
 for a in actors:
  if a.trail_from >= 0: scent_trackers[a.id] = true
  var key = a.y*width+a.x
  if not spatial.has(key): spatial[key] = []
  spatial[key].append(a.id)

func _reset_npc_runtime(saved_memory: Variant = []) -> void:
 npc_planner.reset(width,height,actors.size())
 npc_planner.memory.restore_records(saved_memory,minute)
 revive_sites.clear()
 for b in blocks:
  if b.revive_point: revive_sites[b.id] = true
 npc_schedule.clear()
 for a in actors:
  if a.id > 0 and not a.dormant:
   _schedule_npc(a,_npc_due(a))
  else:
   a.next_think = 0.0

func _npc_due(a: Dictionary) -> int:
 return roundi(float(a.next_think)*C.CLOCK_STEPS_PER_MINUTE)

func _schedule_npc(a: Dictionary, step: int) -> void:
 if a.id == 0 or a.dormant: return
 var due = maxi(step,clock_step+1)
 a.next_think = float(due)/C.CLOCK_STEPS_PER_MINUTE
 npc_schedule.add(a.id,due)

func wake_npc(a: Dictionary) -> void:
 var step = maxi(clock_step+1,ceili(float(a.busy_until)*C.CLOCK_STEPS_PER_MINUTE-0.00001))
 if a.get("recovery_mode", "") == "sleep": return
 a.recovery_mode = ""
 if _npc_due(a) > step: _schedule_npc(a,step)

func set_graffiti(b: Dictionary, text: String, outside: bool) -> void:
 if not outside:
  b.graffiti_inside = text
  return
 b.graffiti = text
 b.revive_point = b.fort.is_empty() and text.strip_edges().to_lower() == "revive point"
 if b.revive_point: revive_sites[b.id] = true
 else: revive_sites.erase(b.id)

func revive_site_ids() -> Array:
 # Equally close markers are visited in map order.
 var ids := revive_sites.keys()
 ids.sort()
 return ids

func radio_receives(a: Dictionary, frequency: float) -> bool:
 if not a.human or a.down: return false
 var key = _radio_key(frequency)
 for item in a.inventory:
  if item.kind == "radio" and _radio_key(item.frequency) == key: return true
 var here = current_block(a)
 return _station_receives(a,here) and _radio_key(here.frequency) == key

func _station_receives(a: Dictionary, here: Dictionary) -> bool:
 return a.inside and here.radio and here.radio_hp > 0 and powered(here)

func can_transmit(a: Dictionary, frequency: float) -> bool:
 if not is_finite(frequency) or frequency < 26.0 or frequency > 29.0: return false
 return roundi(frequency*100.0) > 2800 or has_skill(a,"radio_operation")

func suggested_transmit_frequency(a: Dictionary) -> float:
 var station_frequency = float(current_block(a).frequency)
 return station_frequency if can_transmit(a,station_frequency) else C.PUBLIC_RADIO_FREQUENCY

func _radio_key(frequency: float) -> String:
 return str(roundi(clampf(frequency,25.0,30.0)*100.0))

func record_defense_call(b: Dictionary) -> void:
 radio_defense[_radio_key(b.frequency)] = {"site":b.id,"until":minute+90}

func heard_defense_call(a: Dictionary) -> Dictionary:
 if radio_defense.is_empty() or not a.human or a.down: return {}
 var here = current_block(a)
 var best: Dictionary = radio_defense.get(_radio_key(here.frequency),{}) if _station_receives(a,here) else {}
 for item in a.inventory:
  if item.kind != "radio": continue
  var call: Dictionary = radio_defense.get(_radio_key(item.frequency),{})
  if int(call.get("until",0)) > int(best.get("until",minute)): best = call
 return best if int(best.get("until",0)) > minute else {}

func action_item(a: Dictionary, kind: String, data: Dictionary) -> Dictionary:
 var item = item_by_uid(a,int(data.uid)) if data.has("uid") else item_kind(a,kind)
 return item if item.get("kind","") == kind else {}

func paint_remaining(a: Dictionary, can: Dictionary) -> int:
 return int(can.get("sprays_left",C.SPRAYS_PER_CAN+int(has_skill(a,"tagging"))))

func dna_profile(a: Dictionary) -> String:
 var names: Array[String] = []
 for skill in a.tagged_skills:
  if C.SKILLS.has(skill) and C.SKILLS[skill].side == "zombie": names.append(C.SKILLS[skill].name)
 return ", ".join(names) if not names.is_empty() else "none detected"

func _relocate(a: Dictionary, from: int, to: int) -> void:
 if from == to: return
 for id in scent_trackers.keys():
  var tracker = actors[id]
  if tracker.trail_from >= 0 and (tracker.id == a.id or tracker.trail_from == a.id): _check_scent_trail(tracker)
 var origin: Array = spatial.get(from,[])
 if not origin.has(a.id):
  reindex()
  return
 origin.erase(a.id)
 if origin.is_empty(): spatial.erase(from)
 if not spatial.has(to): spatial[to] = []
 var destination: Array = spatial[to]
 destination.insert(destination.bsearch(a.id),a.id)

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
 visited_neighbourhoods[neighbourhood_key(p.x,p.y)] = true
 ensure_descriptions(current_block(p))
 for dy in range(-1, 2):
  for dx in range(-1, 2):
   if p.x+dx in range(width) and p.y+dy in range(height): block_at(p.x+dx, p.y+dy).known = true

func neighbourhood_key(x: int, y: int) -> String:
 return "%d,%d" % [int(x/10),int(y/10)]

func neighbourhood_visited(x: int, y: int) -> bool:
 return visited_neighbourhoods.has(neighbourhood_key(x,y))

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

func uses_newspaper(a: Dictionary, command: String, data: Dictionary) -> bool:
 return a.human and command == "attack" and not data.get("unarmed",false) and item_by_uid(a,a.equipped).get("kind","") == "newspaper"

func cost(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> int:
 if command == "view_map": return 0
 if command == "jump": return 1
 if uses_newspaper(a,command,data): return 1
 if command == "manufacture": return 20
 if command == "repair": return repair_cost(current_block(a))
 if command == "dump" and within_fort(a,current_block(a)): return 5
 if command == "barricade" and barricade_strength(current_block(a)) == 21: return 0
 var base = 1
 match command:
  "move": base = 2 if not a.human and not (has_skill(a,"lurching_gait") or has_skill(a,"death_lurch")) else 1
  "enter","leave": base = 2 if not a.human and doors_closed(current_block(a)) else 1
  "revive": return 10 if target_id >= 0 and target_id < actors.size() and has_skill(actors[target_id],"brain_rot") else 1
  "scout": base = 30
  "bellow": base = 10 if occupants(current_block(a),a.inside).filter(func(t): return t.human and not t.down).size() >= 25 else 1
  "stand": base = (1 if has_skill(a,"ankle_grab") else (5 if has_skill(a,"death_lurch") else 10))+int(a.get("headshot",0))
  "equip","drop": base = 0
 if a.human and a.inside and a.get("scout_site",-1) == current_block(a).id and current_block(a).ruin < 3 and command not in ["scout","stand","move"]:
  var used = int(a.scout_used) if int(a.scout_day) == minute/1440 else 0
  if used < 5: return maxi(0,base-1)
 return base

func reason(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}, context_only: bool = false) -> String:
 if command == "view_map":
  if a.down: return "Stand up before using the map."
  if item_kind(a,"map").is_empty(): return "You need a city map."
  return ""
 if not context_only and a.busy_until > now(): return "Recovering for %.2f seconds." % (a.busy_until-now())
 if a.down and command not in ["stand", "drop"]: return "You are down. Rest for AP, then stand up."
 if command == "stand":
  if a.get("dormant",false): return "This body has not begun to stir."
  if not a.down: return "Already standing."
  if not context_only and minute < a.ready_at: return "You can stand in %d minutes." % (a.ready_at-minute)
 if not context_only:
  var required_ap = cost(a,command,target_id,data)
  if required_ap > 0 and a.ap < 1: return "Exhausted, you can go no further. Rest until AP is positive."
  if a.id != 0 and a.ap < required_ap and not bool(data.get("allow_ap_debt",false)): return "Not enough AP. Rest to recover."
 var b = current_block(a)
 if command in Extended.COMMANDS: return Extended.command_reason(self,a,command,target_id,data)
 if command == "bite" and (a.human or not has_skill(a,"neck_lurch")): return "Neck Lurch is required."
 var human_only = ["search", "heal", "revive", "reload", "barricade", "repair", "generator", "fuel", "scan", "manufacture", "request", "give", "dump", "repair_generator"]
 if not a.human and command in human_only: return "The undead cannot use items or human abilities. You can drop carried items."
 match command:
  "move":
   var dx: int = data.get("dx", 0)
   var dy: int = data.get("dy", 0)
   if maxi(absi(dx), absi(dy)) != 1: return "Choose a neighbouring block."
   if a.x+dx not in range(width) or a.y+dy not in range(height): return "You have reached the city boundary."
   var destination = block_at(a.x+dx,a.y+dy)
   var fort_error = fort_move_reason(a,b,destination,data)
   if not fort_error.is_empty(): return fort_error
  "enter":
   if not is_building(b) or a.inside: return "There is no entrance here."
   if b.barricade > (4 if a.human else 0): return "You try to find an entry point, but the building is too heavily barricaded to enter from the outside."
   if not a.human and doors_closed(b) and not has_skill(a, "memories"): return "Memories of Life is needed to open doors."
  "leave":
   if not is_building(b): return "There is no building to leave."
   if not a.inside: return "Already outside."
   if b.barricade > 4: return MAIN_DOORS_BLOCKED
  "barricade", "repair", "generator", "fuel", "close", "ransack", "ruin", "scan", "manufacture", "jump", "repair_generator", "destroy_generator":
   if not a.inside or not is_building(b): return "You must be inside a building."
 if command == "dump":
  if not within_fort(a,b) and (not a.inside or not is_building(b)): return "You must be inside a building or within a fort."
  if within_fort(a,b) and fort_gatehouse(b.fort).is_empty(): return "This fort has no gatehouse to dump bodies through."
  if target_id < 0 or target_id >= actors.size(): return "Select a body first."
  var body = actors[target_id]
  if body.id == a.id or not nearby(a,body) or not body.down: return "Select a body at your current location."
 if command in ["heal", "revive", "attack", "bite", "request", "give"]:
  if target_id < 0 or target_id >= actors.size(): return "Select a character first."
  var t = actors[target_id]
  if not nearby(a, t): return "That character is not within reach."
  if command in ["attack", "bite", "heal", "request", "give"] and t.down: return "That character is down."
  if command in ["attack","bite"]:
   if a.id == t.id or (a.human == t.human and not uses_newspaper(a,command,data)): return "Choose a character on the other side."
   var weapon = item_by_uid(a,a.equipped) if command == "attack" and not data.get("unarmed",false) else {}
   if a.human and not weapon.is_empty() and C.ITEMS[weapon.kind].has("capacity") and weapon.ammo == 0: return "The %s is empty. Reload or switch weapons." % C.ITEMS[weapon.kind].name.to_lower()
  if command == "heal":
   if t.hp >= max_hp(t) and not t.infected: return "Already at full health."
   if item_kind(a, "first_aid_kit").is_empty(): return "You need a first aid kit."
  if command == "revive":
   if t.human and not t.down: return "Already human."
   if not has_skill(a, "lab_experience"): return "Lab experience is required."
   if item_kind(a, "syringe").is_empty(): return "You need a syringe."
   if t.human: return CORPSE_REVIVAL_BLOCKED
   if has_skill(t, "brain_rot") and not (a.inside and b.type == "necrotech_lab" and powered(b) and has_skill(a, "necronet")): return BRAIN_ROT_REVIVAL_BLOCKED
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
   if barricade_strength(b) == 21: return "The barricade cannot be built any higher."
   if b.ruin > 0: return "Repair the building first."
   if not has_skill(a,"construction"):
    if barricade_strength(b) > 0: return "Construction is required to reinforce barricades."
    if item_kind(a,"length_of_pipe").is_empty(): return "You need Construction or a length of pipe to build a loose barricade."
  "break":
   if not is_building(b) or b.barricade == 0: return "There are no barricades here."
   if barricade_attack_stats(a,data).hit == 0: return "That attack is ineffective against barricades. Use fists, claws or a suitable melee weapon."
  "repair":
   if b.ruin == 0: return "The building needs no repairs."
   if b.ruin >= 3:
    if item_kind(a,"toolbox").is_empty(): return "You need a toolbox to repair the building."
    if not has_skill(a,"construction"): return "Construction is required to repair buildings."
    if is_dark_building(b) and not powered(b): return "It is too dark to repair the ruin. Install a generator and fuel it to turn on the lights."
   if occupants(b,true).any(func(t): return not t.human and not t.down): return "Remove standing zombies before repairing the building."
  "repair_generator":
   if not b.generator or b.generator_hp >= C.GENERATOR_HP: return "The generator needs no repairs."
   if item_kind(a,"toolbox").is_empty(): return "You need a toolbox."
   if not has_skill(a,"construction"): return "Construction is required to repair generators."
  "destroy_generator":
   if a.human: return "Only zombies attack generators."
   if not b.generator: return "There is no generator here."
  "ransack", "ruin":
   if not can_be_ransacked(b): return "This location cannot be ransacked or ruined."
   if not has_skill(a,"ransack"): return "Ransack is required."
   if b.generator: return "Destroy the generator before ransacking the building."
   if a.human: return "Only zombies ransack buildings."
   if b.ruin >= 3: return "The building is already ruined."
   if command == "ruin" and int(b.get("ransack_hits",0)) < 5: return "Ransack five consecutive times before ruining the building."
   if command == "ransack" and int(b.get("ransack_hits",0)) >= 5: return "The rooms are ransacked. Choose Ruin building."
   for other in occupants(b, true):
    if other.human and not other.down: return "Survivors are still defending this building."
  "close":
   if not a.human and not has_skill(a,"memories"): return "Memories of Life is required to secure doors."
   if not has_doors(b): return "There are no doors here, only a hole in the fence." if b.type == "junkyard" else "There are no closable doors here."
   if doors_closed(b): return "The doors are already closed."
  "generator":
   if not can_host_generator(b): return "Generators cannot be installed at this location."
   if b.generator: return "A generator is already installed."
   if item_kind(a, "portable_generator").is_empty(): return "You need a portable generator."
  "fuel":
   if not can_host_generator(b): return "This location cannot be powered by a portable generator."
   if not b.generator: return "Install a generator first."
   if b.generator_hp < C.GENERATOR_HP: return "Repair the damaged generator before refueling."
   if item_kind(a, "fuel_can").is_empty(): return "You need a fuel can."
  "scan", "manufacture":
   if b.type != "necrotech_lab" or not powered(b): return "You need a powered NecroTech lab."
   if not has_skill(a, "necronet"): return "NecroNet access is required."
   if command == "manufacture" and not acquisition_reason(a,"syringe").is_empty(): return acquisition_reason(a,"syringe")
  "search":
   if a.inventory.size() >= C.INVENTORY_ITEM_LIMIT: return "You are carrying 100 items. Drop or use an item before searching."
   if encumbrance(a) >= C.ENCUMBRANCE_LIMIT: return "You are at %d%% encumbrance. Drop or use something before collecting more." % encumbrance(a)
  "jump":
   if b.type not in C.TALL_BUILDINGS: return "You must be inside a tall building."
 if command not in ["move", "enter", "leave", "attack", "bite", "heal", "revive", "stand", "search", "equip", "drop", "reload", "barricade", "break", "repair", "ransack", "ruin", "close", "generator", "fuel", "scan", "manufacture", "request", "give", "jump", "wait", "dump", "repair_generator", "destroy_generator"]: return "Unknown action."
 return ""

func act(command: String, target_id: int = -1, data: Dictionary = {}) -> Dictionary:
 if resting: return {"ok":false, "message":"Cancel rest before acting."}
 var p = player()
 var rejection = reason(p, command, target_id, data)
 if not rejection.is_empty():
  if rejection == BRAIN_ROT_REVIVAL_BLOCKED: start_scent_trail(actors[target_id],p)
  return {"ok":false, "message":rejection}
 if command == "view_map": return {"ok":true, "message":""}
 execute(p, command, target_id, data)
 discover()
 return {"ok":true, "message":""}

func execute(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> void:
 # Internal callers must validate first. Effects happen before any time passes.
 var ap_spent = cost(a,command,target_id,data)
 if int(a.scout_day) != minute/1440:
  a.scout_day = minute/1440
  a.scout_used = 0
 if a.human and a.inside and a.scout_site == current_block(a).id and current_block(a).ruin < 3 and a.scout_used < 5 and command not in ["scout","stand","move","equip","drop","repair","jump","manufacture"] and not uses_newspaper(a,command,data) and not (command == "dump" and within_fort(a,current_block(a))): a.scout_used += 1
 a.ap -= ap_spent
 a.busy_until = now()+(recovery(command) if a.id == 0 else 1.0)
 a.last_action = command
 var b = current_block(a)
 var origin = {"x":a.x, "y":a.y, "inside":a.inside}
 var friendly = a.human == player().human
 var critical = false
 var attack_hit = false
 var initial_target_hp = actors[target_id].hp if target_id >= 0 else -1
 var initial_barricade_strength = barricade_strength(b)
 var attack_weapon = item_by_uid(a,a.equipped) if command == "attack" and not data.get("unarmed",false) else {}
 var firearm_attack = not attack_weapon.is_empty() and C.ITEMS[attack_weapon.kind].has("capacity")
 var name = "You" if a.id == 0 else display_name(a)
 var text = ""
 match command:
  "move":
   clear_grasp(a)
   var destination = block_at(a.x+data.dx, a.y+data.dy)
   var ruined_free_run = destination.ruin >= 3 and not shared_building_interior(b,destination) and bool(data.get("free_run",true)) and free_run_route(a,b,destination)
   a.inside = move_ends_inside(a,b,destination,data)
   if origin.inside and not a.inside: secure_zombie_exit(a,b)
   a.x += data.dx
   a.y += data.dy
   _relocate(a,b.id,destination.id)
   text = "%s to %s." % [action_phrase(a,"move","moves"),destination.name]
   if ruined_free_run:
    text += " You find your route blocked by a collapsed wall, and are forced to street level." if a.id == 0 else " A collapsed wall forces them to street level."
    if roll_free_run_fall():
     var previous_hp: int = a.hp
     a.hp = maxi(1,a.hp-5)
     if a.id == 0 and a.hp < previous_hp: player_damaged.emit(previous_hp-a.hp,a.human)
     set_pose(a,"hurt")
     critical = true
     text += " You lose your footing on the ruined building, and fall to the street below, injuring yourself." if a.id == 0 else " They lose their footing and fall to the street, injuring themselves."
   if not b.fort.is_empty() and b.fort == destination.fort and destination.type == "armoury" and origin.inside and a.human and has_skill(a,"free_running"):
    text += " The defensive design of the armoury prevents Free Running into it. Use the entrance."
   if b.type == "gatehouse" and not b.fort.is_empty() and b.fort != destination.fort and b.barricade > 4 and origin.inside:
    text += " %s at ground level. The barricades prevent Free Running out." % action_phrase(a,"exit","exits")
  "enter":
   clear_grasp(a)
   var opened = not a.human and doors_closed(b)
   a.inside = true
   if not a.human and has_doors(b): b.doors = false
   text = "%s %s." % [action_phrase(a,"open the doors and enter","opens the doors and enters") if opened else action_phrase(a,"enter","enters"),b.name]
  "leave":
   clear_grasp(a)
   a.inside = false
   secure_zombie_exit(a,b)
   text = "%s outside." % action_phrase(a,"step","steps")
  "equip":
   a.equipped = data.uid if a.equipped != data.uid else -1
   text = "Equipment changed."
  "drop":
   var item = item_by_uid(a, data.uid)
   text = "%s %s." % [action_phrase(a,"discard","discards"),C.ITEMS[item.kind].name]
   consume(a, item)
  "attack","bite":
   var t = actors[target_id]
   if a.grasp_target >= 0 and a.grasp_target != target_id: clear_grasp(a)
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
   attack_hit = roll_attack_hit(stats.hit)
   if weapon.get("kind","") == "newspaper":
    if attack_hit:
     text = "%s %s with a rolled-up newspaper. The only casualty is the classifieds." % [action_phrase(a,"swat","swats"),display_name(t)]
    else:
     text = "%s a newspaper at %s. The weather page catches a draft." % [action_phrase(a,"swing","swings"),display_name(t)]
   elif attack_hit:
    var damage = attack_damage(t,stats)
    var actual = mini(t.hp,damage)
    t.hp -= actual
    if t.id == 0 and actual > 0: player_damaged.emit(actual,t.human)
    a.xp += actual
    set_pose(t,"hurt")
    text = "%s %s for %d damage." % [action_phrase(a,"bite","bites") if command == "bite" else action_phrase(a,"hit","hits"),display_name(t),actual]
    if weapon.get("kind","") == "fuel_can":
     t.fuel_soaked = true
     consume(a,weapon)
     text += " They are soaked in fuel."
    elif weapon.get("kind","") == "flare_gun" and t.get("fuel_soaked",false):
     t.fuel_soaked = false
     text += " The fuel ignites."
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
     if t.human and has_skill(a,"scent_fear"): a.xp += 10
     die(t,penalty)
     critical = true
     text += " They fall." + (" A Headshot delays their return." if penalty > 0 else "")
   else:
    text = "%s %s." % [action_phrase(a,"miss","misses"),display_name(t)]
    if a.grasp_target == target_id and rng.randf() < 0.5:
     clear_grasp(a)
     text += " The grasp slips free."
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
   text = "%s %s for %d HP." % [action_phrase(a,"heal","heals"),display_name(t), amount]
  "revive":
   critical = true
   var t = actors[target_id]
   clear_grasp(t)
   clear_scent_trail(t)
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
   t.tagged_until = 0
   t.tagged_skills.clear()
   t.supply_goal = -1
   t.supply_kind = ""
   if t.id > 0:
    if t.original_human and a.id > 0:
     t.home = a.home
     t.next_trip = minute+90
    _schedule_npc(t,t.ready_at*C.CLOCK_STEPS_PER_MINUTE)
   consume(a, item_kind(a, "syringe"))
   a.xp += 10
   add_trust(t,a,25)
   metrics.revivals += 1
   text = "%s %s. They can stand as a human." % [action_phrase(a,"revive","revives"),display_name(t)]
  "stand":
   a.down = false
   a.headshot = 0
   set_pose(a,"idle")
   a.hp = max_hp(a)/2
   text = "%s as %s." % [action_phrase(a,"rise","rises"),"a survivor" if a.human else "a zombie"]
  "search": text = _search(a,b,name,str(data.get("store","")))
  "reload":
   var weapon = item_by_uid(a,a.equipped)
   var def = C.ITEMS[weapon.kind]
   weapon.ammo = mini(def.capacity,weapon.ammo+def.reload_amount)
   consume(a,item_kind(a,def.ammo_kind))
   text = "%s a single shell into the shotgun." % action_phrase(a,"load","loads") if weapon.kind == "shotgun" else "%s the pistol with a magazine." % action_phrase(a,"reload","reloads")
  "barricade":
   var pipe = {} if has_skill(a,"construction") else item_kind(a,"length_of_pipe")
   var interference = barricade_interference(b)
   if rng.randf() < barricade_build_chance(b):
    gain_local_trust(a,b,3)
    if has_doors(b): b.doors = true
    set_barricade_strength(b,barricade_strength(b)+1)
    if not pipe.is_empty():
     consume(a,pipe)
     text = "%s a length of pipe to put up a loose barricade." % action_phrase(a,"use","uses")
    elif barricade_strength(b) == 10:
     text = "Using %s, %s the barricade. It is now very strong, and any further barricading will prevent survivors from climbing in." % [barricade_material(b),"you reinforce" if a.id == 0 else action_phrase(a,"reinforce","reinforces")]
    elif interference:
     text = "Dragging %s past the zombies, %s the barricade." % [barricade_material(b),"you reinforce" if a.id == 0 else action_phrase(a,"reinforce","reinforces")]
    else: text = "%s the building." % action_phrase(a,"barricade","barricades")
   elif not pipe.is_empty():
    text = "%s to wedge a length of pipe into place, but it slips." % action_phrase(a,"try","tries")
   elif interference:
    text = "%s %s towards the doors, but the zombies lurch into %s way." % [action_phrase(a,"drag","drags"),barricade_material(b),"your" if a.id == 0 else "their"]
   else: text = "%s around for something to barricade the building with." % action_phrase(a,"look","looks")
  "break":
   if a.human: gain_local_trust(a,b,-5)
   if not a.human and not a.inside: b.last_pounding = minute
   var stats = barricade_attack_stats(a,data)
   var weapon = stats.weapon
   var tool_name = C.ITEMS[weapon.kind].name.to_lower() if not weapon.is_empty() else "fists"
   var possessive = "your" if a.id == 0 else "their"
   var hit = rng.randi_range(1,100) <= stats.hit
   if not hit:
    text = "%s %s %s at the barricade." % [action_phrase(a,"swing","swings"),possessive,tool_name] if a.human else "%s at the barricade." % action_phrase(a,"swipe","swipes")
   elif stats.structural == 1.0 or rng.randf() < stats.structural:
    var previous_level = b.barricade
    set_barricade_strength(b,barricade_strength(b)-1)
    critical = b.barricade == 0
    if not a.human and b.barricade < previous_level: a.xp += 1
    text = "%s the barricade with %s %s, damaging it." % [action_phrase(a,"hit","hits"),possessive,tool_name] if a.human else "%s at the barricade, damaging it." % action_phrase(a,"smash","smashes")
   else:
    text = "%s the barricade with %s %s; it creaks." % [action_phrase(a,"hit","hits"),possessive,tool_name] if a.human else "%s at the barricade; it creaks." % action_phrase(a,"smash","smashes")
   if hit and not weapon.is_empty():
    if C.ITEMS[weapon.kind].get("fragile",false): consume(a,weapon)
    elif melee_break_chance(weapon) > 0.0 and rng.randf() < melee_break_chance(weapon):
     consume(a,weapon)
     text += " The pool cue splinters and breaks."
  "dump":
   var body = actors[target_id]
   body.inside = false
   gain_local_trust(a,b,2)
   if within_fort(a,b):
    var gate = fort_gatehouse(b.fort)
    clear_grasp(a)
    clear_grasp(body)
    a.x = gate.x
    a.y = gate.y
    a.inside = true
    body.x = gate.x
    body.y = gate.y
    _relocate(a,b.id,gate.id)
    _relocate(body,b.id,gate.id)
    a.route.clear()
    body.route.clear()
    text = "%s a body through %s and %s it outside. %s inside the gatehouse." % [action_phrase(a,"carry","carries"),gate.name,"dump" if a.id == 0 else "dumps",action_phrase(a,"remain","remains")]
   else: text = "%s." % action_phrase(a,"drag a body to the doorway and dump it outside","drags a body to the doorway and dumps it outside")
  "repair_generator":
   b.generator_hp = mini(C.GENERATOR_HP,b.generator_hp+2)
   a.xp += 1
   gain_local_trust(a,b,5)
   text = "%s the generator. It is %s." % [action_phrase(a,"repair","repairs"),generator_condition(b)]
  "destroy_generator":
   if rng.randf() < 0.65:
    b.generator_hp = maxi(0,b.generator_hp-1)
    text = "%s the generator. It is %s." % [action_phrase(a,"batter","batters"),generator_condition(b)]
    if b.generator_hp == 0:
     b.generator = false
     b.fuel_until = 0
     critical = true
     a.xp += 5
     text = "%s the generator beyond repair. The lights go out." % action_phrase(a,"smash","smashes")
   else: text = "%s at the generator's metal casing without damaging it." % action_phrase(a,"claw","claws")
  "repair":
   var structural = b.ruin >= 3
   b.ruin = 0
   b.ransack_hits = 0
   b.ruined_at = -1
   if structural: a.xp += 1
   gain_local_trust(a,b,4)
   text = "%s the ruined building for %d AP." % [action_phrase(a,"repair","repairs"),ap_spent] if structural else "%s the room." % action_phrase(a,"repair","repairs")
  "ransack":
   var first = b.ruin == 0
   b.ruin = 1
   b.ransack_hits = int(b.get("ransack_hits",0))+1
   if first: a.xp += 1
   text = "%s the building." % action_phrase(a,"ransack","ransacks") if first else ("You ransack further rooms of the building." if a.id == 0 else "%s further rooms of the building." % action_phrase(a,"ransack","ransacks"))
  "ruin":
   b.ruin = 3
   b.ruined_at = minute
   for occupant in actors:
    if occupant.scout_site == b.id:
     occupant.scout_site = -1
     occupant.scout_used = 0
   text = "You ransack further rooms of the building. The building is now ruined." if a.id == 0 else "%s the building." % action_phrase(a,"ruin","ruins")
  "close":
   b.doors = true
   text = "%s the doors." % action_phrase(a,"close","closes")
  "generator":
   b.generator = true
   b.generator_hp = C.GENERATOR_HP
   consume(a, item_kind(a, "portable_generator"))
   gain_local_trust(a,b,8)
   text = "%s a generator." % action_phrase(a,"install","installs")
  "fuel":
   var already_running = powered(b)
   b.fuel_until = minute+C.FUEL_MINUTES
   consume(a, item_kind(a, "fuel_can"))
   gain_local_trust(a,b,6)
   text = "%s off the running generator to 24 hours. The remaining fuel in the can is wasted." % action_phrase(a,"top","tops") if already_running else "%s the generator. The lights come on for 24 hours." % action_phrase(a,"fuel","fuels")
  "manufacture":
   give_item(a, "syringe")
   text = "%s a syringe (20 AP)." % action_phrase(a,"manufacture","manufactures")
  "scan":
   if a.id == 0: record_necronet_scan(a)
   else: npc_planner.record_scan(self,a)
   text = "%s a view of DNA-tagged zombies on NecroNet." % action_phrase(a,"open","opens")
  "request":
   text = request_supplies(a,actors[target_id])
  "give":
   var t = actors[target_id]
   var item = item_by_uid(a, data.uid)
   if item_kind(t,item.kind).is_empty() and supply_needed_by(t,item.kind): add_trust(t,a,8)
   consume(a, item)
   t.inventory.append(item)
   text = "%s %s to %s." % [action_phrase(a,"give","gives"),C.ITEMS[item.kind].name, display_name(t)]
  "jump":
   clear_grasp(a)
   a.inside = false
   secure_zombie_exit(a,b)
   text = "%s from a window." % action_phrase(a,"jump","jumps")
   if a.human:
    critical = true
    if a.id == 0 and a.hp > 0: player_damaged.emit(a.hp,a.human)
    die(a)
    text += " You die and can stand as a zombie." if a.id == 0 else " They die on impact."
   else:
    text += " You land unharmed." if a.id == 0 else " They land unharmed."
  "wait": text = "%s." % action_phrase(a,"wait and watch","waits and watches")
  _: text = Extended.perform(self,a,command,target_id,data)
 if command in ["attack","bite","extract","heal"] and target_id >= 0:
  var target: Dictionary = actors[target_id]
  if a.human: start_scent_trail(target,a)
  elif command in ["attack","bite"]: start_scent_trail(a,target)
 if a.ap <= 0 and a.id == 0: text += " Exhausted, you can go no further."
 if a.human and not a.down and a.infected and ap_spent > 0:
  var previous_hp: int = a.hp
  a.hp = maxi(0,a.hp-ap_spent)
  if a.id == 0 and a.hp < previous_hp: player_damaged.emit(previous_hp-a.hp,a.human)
  if a.hp == 0: die(a)
  if a.id == 0: text += " Infection costs %d HP." % ap_spent
 if a.id > 0: a.busy_until = float(NpcGate.ready_after_action(clock_step))/C.CLOCK_STEPS_PER_MINUTE
 if a.id > 0 and command in ["scan","smell","broadcast","gesture"]: a.npc_special_at = minute+180
 if command in ["move","enter","leave","break","attack","bite","drag","revive"]:
  for id in spatial.get(current_block(a).id,[]):
   var other: Dictionary = actors[id]
   if id > 0 and id != a.id and other.human != a.human and not other.down:
    if other.get("recovery_mode", "") != "rest" or other.inside == a.inside: wake_npc(other)
 var p = player()
 var event_action = command
 if command == "break" and not a.human and not a.inside and p.inside and a.x == p.x and a.y == p.y:
  event_action = "breach_noise"
  text = "Pounding fists and scraping claws batter the barricades outside. " + ("The last barricade gives way." if b.barricade == 0 else "The barricades shudder but hold.")
 var visible = nearby(a,p) or nearby(origin,p)
 var station_destroyed = command == "destroy_radio" and not b.radio
 var remote = ((command == "broadcast" or station_destroyed) and radio_receives(p,b.frequency)) or (command == "phone" and target_id == 0) or (command == "flare" and not p.down and maxi(absi(a.x-p.x),absi(a.y-p.y)) <= 14)
 if station_destroyed and remote and not visible: text = "[Radio %.2f MHz] A transmitter falls silent." % b.frequency
 var call_audible = not p.down and command in ["groan","bellow"] and maxi(absi(a.x-p.x),absi(a.y-p.y)) <= (10 if command == "bellow" else 6)
 var audible = call_audible or (a.x == p.x and a.y == p.y and command in ["break","barricade","enter","leave"])
 if not sleeping and (a.id == 0 or visible or audible):
  var sound = ""
  match command:
   "move": sound = "footsteps"
   "enter": sound = "door_open"
   "leave", "stand": sound = "footsteps"
   "close": sound = "door_close"
   "search": sound = "search"
   "reload": sound = "reload"
   "barricade": sound = "barricade"
   "break": sound = "decade"
   "ransack", "ruin": sound = "ransack"
   "groan", "bellow": sound = "zombie_sounds"
   "attack", "bite":
    if firearm_attack: sound = "gun_shot"
    elif attack_hit: sound = "break"
  if not sound.is_empty(): sound_requested.emit(sound)
 if a.id == 0 or visible or audible or remote or target_id == 0:
  var category = "PLAYER" if a.id == 0 else ("ALLY" if friendly else "ENEMY")
  if target_id == 0 or (critical and not friendly): category = "ALERT"
  if not text.is_empty(): log_event(text, category, a.id, event_action, critical or target_id == 0, attack_hit)
 if resting and not sleeping and ((target_id == 0 and (initial_target_hp > p.hp or command == "revive")) or (critical and audible) or threats()):
  stop_rest("Rest interrupted. Danger or a change in your condition brings you back to normal speed.")

func die(a: Dictionary, penalty: int = 0) -> void:
 if not sleeping and (a.id == 0 or nearby(a,player())): sound_requested.emit("human_death" if a.human else "zombie_death")
 if a.human and a.id > 0:
  a.wants_revive = a.original_human
  a.supply_goal = -1
  a.supply_kind = ""
 clear_scent_trail(a)
 for id in scent_trackers.keys():
  var tracker = actors[id]
  if tracker.trail_from == a.id:
   clear_scent_trail(tracker)
 clear_grasp(a)
 a.headshot = penalty
 a.fed = 0
 a.fuel_soaked = false
 a.tagged_until = 0
 a.tagged_skills.clear()
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
 if a.id == 0: a.busy_until = 0.0
 else: _schedule_npc(a,a.ready_at*C.CLOCK_STEPS_PER_MINUTE)
 metrics.deaths += 1

func _search(a: Dictionary, b: Dictionary, name: String, store: String = "") -> String:
 if not acquisition_reason(a).is_empty(): return acquisition_reason(a)
 var found = roll_search(b,a,store)
 if found == "dead_fir_tree" and item_kind(a,"fire_axe").is_empty(): return "You find a small fir tree, but need a fire axe to fell it." if a.id == 0 else "%s searches the area for supplies." % name
 if not found.is_empty() and not acquisition_reason(a,found).is_empty():
  return "You find %s, but cannot carry another: %s" % [C.ITEMS[found].name,acquisition_reason(a,found)] if a.id == 0 else "%s searches for supplies." % name
 if not found.is_empty():
  give_item(a,found)
  if C.ITEMS[found].has("capacity"):
   var capacity = int(C.ITEMS[found].capacity)
   a.inventory.back().ammo = rng.randi_range(1,capacity-1) if rng.randf() < 0.75 else 0
 # Other actors get the same loot rules without the player's detailed narration.
 if a.id != 0: return "%s searches the area for supplies." % name
 var outside = search_is_outside(b,a)
 var spot = "the surrounding streets and discarded debris" if outside else search_spot(b)
 var lit = not outside and powered(b)
 if found.is_empty():
  var finds = ["only rotting paper and empty wrappers; nothing worth carrying", "a promising container, but its contents have spoiled", "a broken item whose working parts have rusted away", "a heap of useless scraps, which you leave behind", "an empty hiding place beneath a thick layer of dust"]
  var result: String = finds[rng.randi_range(0,finds.size()-1)]
  if outside: return "%s search %s and find %s." % [name,spot,result]
  return "%s search %s and find %s." % [name,spot,result] if lit else "%s feel through %s in the dark, stumbling over debris, and find %s." % [name,spot,result]
 var description: String = C.ITEMS[found].name
 var condition = "It is intact and ready to use."
 if C.ITEMS[found].has("capacity"):
  var ammo = int(a.inventory.back().ammo)
  condition = "It holds %d round%s." % [ammo,"" if ammo == 1 else "s"] if ammo > 0 else "It is empty and needs ammunition."
 if outside: return "%s search %s. At last: %s! %s" % [name,spot,description,condition]
 return "%s search %s under the lights. At last: %s! %s" % [name,spot,description,condition] if lit else "%s grope through %s in the darkness. Against the odds, you find %s! %s" % [name,spot,description,condition]

func search_is_outside(b: Dictionary, a: Dictionary = {}) -> bool:
 return not is_building(b) or (not a.is_empty() and not a.inside)

func search_distribution(b: Dictionary, a: Dictionary = {}, store: String = "") -> Dictionary:
 if search_is_outside(b,a):
  return C.OUTSIDE_SEARCH_WEIGHTS
 if b.type == "mall" and not a.is_empty() and has_skill(a,"shopping") and C.MALL_STORES.has(store):
  if C.MALL_STORE_WEIGHTS.has(store): return C.MALL_STORE_WEIGHTS[store]
  var targeted = {}
  for kind in C.MALL_STORES[store]: targeted[kind] = search_tables.mall.get(kind,1.0)
  return targeted
 return search_tables.get(b.type,{})

func item_search_chance(b: Dictionary, kind: String, a: Dictionary = {}, store: String = "") -> float:
 var table = search_distribution(b,a,store)
 var total = 0.0
 for weight in table.values(): total += maxf(0.0,float(weight))
 return search_chance(b,a,store)*maxf(0.0,float(table.get(kind,0.0)))/total if total > 0.0 else 0.0

func search_chance(b: Dictionary, a: Dictionary = {}, _store: String = "") -> float:
 if search_is_outside(b,a): return C.SEARCH_OUTSIDE_CHANCE
 # Total darkness includes ruins. Lighting permits repair without erasing ruin.
 if is_dark_building(b) and not powered(b): return C.SEARCH_DARK_CHANCE
 if b.ruin > 0: return C.SEARCH_RUIN_CHANCE
 var chance = C.SEARCH_UNLIT_CHANCE
 if powered(b):
  chance = 0.26 if b.type == "mall" else (0.28 if b.type == "necrotech_lab" else C.SEARCH_LIT_CHANCE)
 if b.type == "mall" and not a.is_empty() and has_skill(a,"bargain_hunting"): chance *= 2.0
 return minf(chance,1.0)

func roll_search(b: Dictionary, a: Dictionary = {}, store: String = "") -> String:
 # First roll for any find; only then roll the site's conditional loot weights.
 if rng.randf() >= search_chance(b,a,store): return ""
 var table = search_distribution(b,a,store)
 var total = 0.0
 for weight in table.values(): total += maxf(0.0,float(weight))
 if total <= 0.0: return ""
 var roll = rng.randf()*total
 var last = ""
 for kind in table:
  var weight = maxf(0.0,float(table[kind]))
  if weight <= 0.0: continue
  last = kind
  roll -= weight
  if roll < 0.0: return kind
 return last

func search_loot(kind: String) -> Array:
 if kind in C.OUTDOORS: return C.OUTSIDE_SEARCH_WEIGHTS.keys()
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
 if command == "view_map": return 0.0
 return C.ACTION_RECOVERY.get(command,0.6)

func elapse(real_seconds: float) -> void:
 _elapse(real_seconds,0)

func elapse_budgeted(real_seconds: float, budget_usec: int) -> float:
 return _elapse(real_seconds,budget_usec)

func _elapse(real_seconds: float, budget_usec: int) -> float:
 var started: int = Time.get_ticks_usec() if performance_counters != null or budget_usec > 0 else 0
 var start_step: int = clock_step
 var budgeted_recovery: bool = budget_usec > 0 and resting
 # Recompute the speed per tick. Budgeted recovery drops unspent time on wake,
 # since it may include time deferred from earlier accelerated frames.
 var remaining = real_seconds
 while remaining > 0.000000001:
  var rate = C.GAME_MINUTES_PER_SECOND*C.CLOCK_STEPS_PER_MINUTE*time_speed()
  var until_step = (1.0-clock_fraction)/rate
  if remaining+0.000000001 < until_step:
   clock_fraction += remaining*rate
   remaining = 0.0
   break
  remaining = maxf(0.0,remaining-until_step)
  clock_fraction = 0.0
  _clock_step()
  if budgeted_recovery and not resting:
   remaining = 0.0
   break
  if budget_usec > 0 and Time.get_ticks_usec()-started >= budget_usec: break
 discover()
 _record_advance(started,start_step)
 return remaining

func advance(minutes: int) -> void:
 # Headless tests only. Interactive play always uses elapse(delta).
 advance_steps(minutes*C.CLOCK_STEPS_PER_MINUTE)

func advance_steps(steps: int) -> void:
 var started: int = Time.get_ticks_usec() if performance_counters != null else 0
 var start_step: int = clock_step
 for i in range(steps): _clock_step()
 _record_advance(started,start_step)

func advance_budgeted(target_step: int, budget_usec: int, max_steps: int) -> int:
 var started: int = Time.get_ticks_usec()
 var start_step: int = clock_step
 var last_step: int = mini(target_step,start_step+max_steps)
 while clock_step < last_step:
  _clock_step()
  if Time.get_ticks_usec()-started >= budget_usec: break
 _record_advance(started,start_step)
 return maxi(0,target_step-clock_step)

func _record_advance(started: int, start_step: int) -> void:
 if performance_counters == null: return
 performance_counters.simulation_usec += Time.get_ticks_usec()-started
 performance_counters.clock_steps += clock_step-start_step

func _clock_step() -> void:
 clock_step += 1
 minute = clock_step/C.CLOCK_STEPS_PER_MINUTE
 if clock_step % (1440*C.CLOCK_STEPS_PER_MINUTE) == 0: reanimate_bodies()
 if clock_step % (C.RECOVERY_MINUTES*C.CLOCK_STEPS_PER_MINUTE) == 0:
  var started: int = Time.get_ticks_usec() if performance_counters != null else 0
  var grants: int = 0
  for a in actors:
   if performance_counters != null: grants += int(a.ap < C.AP_CAP)
   a.ap = mini(C.AP_CAP,a.ap+(2 if a.id > 0 and a.get("recovery_mode", "") == "sleep" else 1))
  if performance_counters != null:
   performance_counters.ap_usec += Time.get_ticks_usec()-started
   performance_counters.ap_updates += actors.size()
   performance_counters.ap_grants += grants
 var due = npc_schedule.take(clock_step)
 var first = due.bsearch(npc_cursor)
 var has_due_npc := false
 for offset in range(due.size()):
  var id: int = due[(first+offset)%due.size()]
  var a: Dictionary = actors[id]
  if a.dormant or _npc_due(a) != clock_step: continue
  has_due_npc = true
  var recovery_step = ceili(float(a.busy_until)*C.CLOCK_STEPS_PER_MINUTE-0.00001)
  if recovery_step > clock_step:
   _schedule_npc(a,recovery_step)
   continue
  if a.down:
   if npc_planner.train_before_standing(self,a):
    _schedule_npc(a,NpcGate.ready_after_action(clock_step))
    continue
   var stand_cost = cost(a,"stand")
   if minute < a.ready_at or not NpcGate.can_act(a.ap,stand_cost,clock_step,recovery_step):
    var afford = (clock_step/NpcGate.AP_INTERVAL_STEPS+maxi(0,stand_cost-a.ap))*NpcGate.AP_INTERVAL_STEPS
    _schedule_npc(a,maxi(afford,int(a.ready_at)*C.CLOCK_STEPS_PER_MINUTE))
    continue
  if not str(a.get("recovery_mode", "")).is_empty():
   a.recovery_mode = ""
  var rest_ap = _npc_turn(a)
  if a.ap <= 0 and not a.down:
   var nearby_danger = occupants(current_block(a),a.inside).any(func(other): return other.id != a.id and other.human != a.human and not other.down)
   a.recovery_mode = "sleep" if a.human and a.inside and not nearby_danger else "rest"
   var target_ap = C.AP_CAP if a.recovery_mode == "sleep" else 20
   var intervals = ceili(float(target_ap-int(a.ap))/(2.0 if a.recovery_mode == "sleep" else 1.0))
   var recovery_due = (clock_step/NpcGate.AP_INTERVAL_STEPS+intervals)*NpcGate.AP_INTERVAL_STEPS
   _schedule_npc(a,recovery_due)
   continue
  if a.down and _npc_due(a) > clock_step: continue
  if a.busy_until > now():
   _schedule_npc(a,NpcGate.ready_after_action(clock_step)+10+(id+clock_step)%17)
  elif a.ap < rest_ap:
   var afford = (clock_step/NpcGate.AP_INTERVAL_STEPS+rest_ap-int(a.ap))*NpcGate.AP_INTERVAL_STEPS
   _schedule_npc(a,afford+id%19)
  else:
   _schedule_npc(a,clock_step+70+(id+clock_step)%61)
 # A wake-up can leave an obsolete bucket entry that is absent after loading.
 if has_due_npc: npc_cursor = 1+(npc_cursor%maxi(1,actors.size()-1))
 if resting and ((player().ap >= rest_target and (not player().down or minute >= player().ready_at)) or clock_step >= rest_end_step):
  stop_rest(("You awaken rested. " if sleeping else "Rest complete. ")+"%d AP available." % player().ap)

func _try(a: Dictionary, command: String, target_id: int = -1, data: Dictionary = {}) -> bool:
 if command == "break" and not a.human: data = {"unarmed":true}
 var ready_step = ceili(float(a.busy_until)*C.CLOCK_STEPS_PER_MINUTE-0.00001)
 if not NpcGate.can_act(a.ap,cost(a,command,target_id,data),clock_step,ready_step): return false
 var rejection = reason(a, command, target_id, data)
 if not rejection.is_empty():
  if rejection == BRAIN_ROT_REVIVAL_BLOCKED: start_scent_trail(actors[target_id],a)
  return false
 execute(a, command, target_id, data)
 metrics.npc_actions += 1
 return true

func _npc_turn(a: Dictionary) -> int:
 if performance_counters == null: return npc_planner.turn(self,a)
 var started: int = Time.get_ticks_usec()
 var rest_ap: int = npc_planner.turn(self,a)
 performance_counters.decision_usec += Time.get_ticks_usec()-started
 performance_counters.decisions += 1
 return rest_ap

func start_scent_trail(tracker: Dictionary, survivor: Dictionary) -> void:
 if tracker.human or tracker.down or not has_skill(tracker,"scent_trail") or not survivor.human or survivor.down: return
 tracker.trail_from = survivor.id
 tracker.trail_lost = false
 scent_trackers[tracker.id] = true

func clear_scent_trail(tracker: Dictionary, lost: bool = false) -> void:
 if tracker.trail_from >= 0: tracker.memory = -1
 tracker.trail_from = -1
 tracker.trail_lost = lost
 scent_trackers.erase(tracker.id)

func scent_trail_target(tracker: Dictionary) -> Dictionary:
 if tracker.human or tracker.down or not has_skill(tracker,"scent_trail"): return {}
 if tracker.trail_from < 0 or tracker.trail_from >= actors.size(): return {}
 var target = actors[tracker.trail_from]
 if not target.human or target.down or scent_distance(tracker,target) >= 10: return {}
 return target

func _check_scent_trail(tracker: Dictionary) -> void:
 if tracker.trail_from < 0 or not scent_trail_target(tracker).is_empty(): return
 clear_scent_trail(tracker,not tracker.human and not tracker.down)

func scent_distance(a: Dictionary, b: Dictionary) -> int:
 return maxi(absi(b.x-a.x),absi(b.y-a.y))

func scent_trail_text(tracker: Dictionary) -> String:
 if tracker.human or tracker.down or not has_skill(tracker,"scent_trail"): return ""
 var target = scent_trail_target(tracker)
 if target.is_empty(): return "(Scent lost)" if tracker.trail_lost else ""
 var distance = scent_distance(tracker,target)
 if distance == 0: return "Scent Trail: %s is on this block." % display_name(target)
 var vertical = "north" if target.y < tracker.y else ("south" if target.y > tracker.y else "")
 var horizontal = "west" if target.x < tracker.x else ("east" if target.x > tracker.x else "")
 return "Scent Trail: %s is %d block%s %s." % [display_name(target),distance,"" if distance == 1 else "s",vertical+horizontal]

func survey_binoculars(a: Dictionary, direction: String) -> void:
 binocular_direction = direction if a.inside else ""
 var origin = Vector2i(a.x,a.y)
 if a.inside:
  var bearing: Vector2i = C.COMPASS_DIRECTIONS[direction]
  binocular_area = Rect2i(origin+2*bearing-Vector2i.ONE,Vector2i(3,3))
 else:
  binocular_area = Rect2i(origin-Vector2i(3,3),Vector2i(7,7))
 var visible = binocular_area.intersection(Rect2i(0,0,width,height))
 for y in range(visible.position.y,visible.end.y):
  for x in range(visible.position.x,visible.end.x):
   block_at(x,y).known = true

func skyline_landmarks(a: Dictionary) -> Array:
 var closest = {}
 var landmarks = C.TALL_BUILDINGS + ["monument","cathedral","mall","stadium","power_station","mansion","gatehouse"]
 var origin = Vector2i(a.x,a.y)
 var horizon = Rect2i(origin-Vector2i.ONE*SKYLINE_RADIUS,Vector2i.ONE*(2*SKYLINE_RADIUS+1))
 horizon = horizon.intersection(Rect2i(0,0,width,height))
 for y in range(horizon.position.y,horizon.end.y):
  for x in range(horizon.position.x,horizon.end.x):
   if Vector2i(x,y) == origin: continue
   var site = block_at(x,y)
   if site.type not in landmarks: continue
   var key = site.complex if not site.complex.is_empty() else str(site.id)
   var distance = scent_distance(a,site)
   if closest.has(key) and closest[key].distance <= distance: continue
   var bearing = C.COMPASS_DIRECTIONS.find_key(Vector2i(signi(x-a.x),signi(y-a.y)))
   closest[key] = {"site":site,"distance":distance,"bearing":bearing}
 var entries = closest.values()
 entries.sort_custom(func(left,right):
  if left.distance != right.distance: return left.distance < right.distance
  return left.site.id < right.site.id)
 return entries

func record_necronet_scan(a: Dictionary) -> void:
 scan_cells.clear()
 var total = 0
 for y in range(a.y-4,a.y+5):
  for x in range(a.x-4,a.x+5):
   if x not in range(width) or y not in range(height):
    scan_cells.append({"site":-1,"type":"","count":0})
    continue
   var site = block_at(x,y)
   var count = occupants(site).filter(func(other): return not other.human and not other.down and other.tagged_until > minute).size()
   total += count
   scan_cells.append({"site":site.id,"type":visible_type(site,a),"count":count})
 scan_report = "Tagged zombies in the local scan  %d" % total
 scan_minute = minute

func scent_death_snapshot(a: Dictionary) -> Array[Dictionary]:
 var cells: Array[Dictionary] = []
 for y in range(a.y-5,a.y+6):
  for x in range(a.x-5,a.x+6):
   var cell = {"x":x,"y":y,"valid":x in range(width) and y in range(height),"bodies":0,"zombies":0,"revivifying":0}
   if cell.valid:
    for other in occupants(block_at(x,y)):
     if other.down:
      cell.bodies += 1
      if other.human: cell.revivifying += 1
     elif not other.human and other.id != a.id:
      cell.zombies += 1
   cells.append(cell)
 return cells

func survivor_condition(observer: Dictionary, survivor: Dictionary) -> String:
 if not survivor.human or survivor.down or not has_skill(observer,"scent_fear"): return ""
 if survivor.hp < 13: return "dying"
 if survivor.hp < 25: return "wounded"
 return ""

func sees_survivor_hp(observer: Dictionary, survivor: Dictionary) -> bool:
 return survivor.human and not survivor.down and (has_skill(observer,"diagnosis") or has_skill(observer,"scent_blood"))

func _visible_human(a: Dictionary) -> Dictionary:
 var origin_x: int = a.x
 var origin_y: int = a.y
 var inside: bool = a.inside
 var origin: int = origin_y*width+origin_x
 var start_x: int = maxi(0,origin_x-1)
 var end_x: int = mini(width,origin_x+2)
 # Walk the existing buckets in map order and retain their actor ID order.
 for y in range(maxi(0,origin_y-1),mini(height,origin_y+2)):
  var row: int = y*width
  for site in range(row+start_x,row+end_x):
   var ids: Array = spatial.get(site,EMPTY_OCCUPANT_IDS)
   for id: int in ids:
    var other: Dictionary = actors[id]
    if not other.human or other.down: continue
    if not inside and not other.inside: return other
    if other.inside == inside and other.x == origin_x and other.y == origin_y: return other
    if site == origin:
     var b: Dictionary = blocks[site]
     if b.barricade == 0 and not doors_closed(b): return other
 return {}

func _wander(a: Dictionary, ground_move: bool = false) -> void:
 if a.inside and not ground_move:
  _try(a, "leave")
  return
 var options: Array = []
 for dy in range(-1, 2):
  for dx in range(-1, 2):
   if dx == 0 and dy == 0: continue
   if a.x+dx in range(width) and a.y+dy in range(height):
    var b = block_at(a.x+dx, a.y+dy)
    var move = {"dx":dx, "dy":dy, "free_run":not ground_move}
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
 if skill == "brain_rot":
  a.tagged_until = 0
  a.tagged_skills.clear()
 if actor_id == 0: log_event("Learned %s." % def.name)
 return ""

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
 sleeping = false
 rest_target = mini(50,player().ap+amount)
 rest_end_step = clock_step+maxi(1800,maxi(0,rest_target-player().ap)*30+30)*C.CLOCK_STEPS_PER_MINUTE
 last_rest_notice = "Resting at 16× speed. Danger cancels fast-forward."
 log_event(last_rest_notice)
 return ""

func begin_sleep() -> String:
 if player().down: return "Stand up before sleeping."
 if player().busy_until > now(): return "Finish recovering before sleeping."
 if player().ap >= C.AP_CAP: return "Already at full AP."
 resting = true
 sleeping = true
 sleep_damage_hits = 0
 sleep_last_damage_at = -1000.0
 rest_target = C.AP_CAP
 rest_end_step = clock_step+(maxi(0,rest_target-player().ap)*30+30)*C.CLOCK_STEPS_PER_MINUTE
 last_rest_notice = "You fall asleep at 128× speed. You will sleep until fully rested."
 log_event(last_rest_notice)
 return ""

func stop_rest(message: String = "Rest cancelled.") -> void:
 if not resting: return
 resting = false
 sleeping = false
 last_rest_notice = message
 log_event(message,"ALERT" if "interrupted" in message else "WORLD",-1,"rest",true)
 rest_finished.emit()

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

func log_event(text: String, category: String = "WORLD", actor_id: int = -1, action: String = "", urgent: bool = false, attack_hit: bool = false) -> void:
 if not actors.is_empty() and player().down and actor_id > 0: return
 event_sequence += 1
 messages.append({"id":event_sequence,"step":clock_step,"minute":minute,"category":category,"actor":actor_id,"action":action,"text":text,"urgent":urgent})
 if attack_hit: messages.back().attack_hit = true
 while messages.size() > 1000: messages.pop_front()

func save_to(path: String) -> Error:
 var file = FileAccess.open(path, FileAccess.WRITE)
 if file == null: return FileAccess.get_open_error()
 var state = {
  "version":3, "width":width, "height":height, "world_mode":world_mode, "world_title":world_title,
  "world_config":world_config, "geography_source":geography_source, "seed":str(world_seed),
  "rng":str(rng.state), "minute":minute, "clock_step":clock_step, "clock_fraction":clock_fraction,
  "event_sequence":event_sequence, "blocks":blocks, "actors":actors, "messages":messages,
  "next_item_id":next_item_id, "scan_report":scan_report, "scan_minute":scan_minute, "scan_cells":scan_cells,
  "npc_cursor":npc_cursor, "next_dialogue":next_dialogue, "sense_report":sense_report, "metrics":metrics,
  "npc_locations":npc_planner.memory.save_records(), "radio_defense":radio_defense,
  "visited_neighbourhoods":visited_neighbourhoods
 }
 # Preserve fractional clock and actor deadlines across a JSON round trip.
 file.store_string(JSON.stringify(state,"",true,true))
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
  if a.x < 0 or a.x >= loaded_width or a.y < 0 or a.y >= loaded_height or a.ap > 50: return "Invalid character bounds."
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
 npc_sex_counts.clear()
 var missing_sex: Array = []
 for a in actors:
  if a.id > 0 and a.get("sex","") not in ["male","female"]: missing_sex.append(int(a.id))
 visited_neighbourhoods = parsed.get("visited_neighbourhoods",{}).duplicate() if parsed.get("visited_neighbourhoods",{}) is Dictionary else {}
 # Older saves have no visit history; retain the current neighbourhood.
 if not parsed.has("visited_neighbourhoods"):
  visited_neighbourhoods[neighbourhood_key(int(actors[0].x),int(actors[0].y))] = true
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
   if item.kind == "radio": item.frequency = clampf(float(item.get("frequency",a.channel)),25.0,30.0)
   if item.kind == "spray_can" and item.has("sprays_left"): item.sprays_left = clampi(int(item.sprays_left),1,C.SPRAYS_PER_CAN)
 for b in blocks:
  for key in ["id", "x", "y", "barricade", "ruin", "fuel_until"]: b[key] = int(b[key])
  if not b.has("ruined_at") and b.ruin >= 3: b.ruined_at = int(parsed.minute)
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
 sleeping = false
 last_rest_notice = ""
 world_seed = int(parsed.seed)
 # Upgrade older cities as well as new spawns. Already saved identities stay fixed.
 for a in actors:
  if a.id == 0 or a.id in missing_sex: continue
  if not npc_sex_counts.has(a.job): npc_sex_counts[a.job] = {"male":0,"female":0}
  npc_sex_counts[a.job][a.sex] += 1
 for id in missing_sex:
  actors[id].sex = _next_npc_sex(actors[id].job)
 if not missing_sex.is_empty(): ensure_unique_npc_names()
 for b in blocks: ensure_descriptions(b)
 rng.seed = world_seed
 rng.state = int(parsed.rng)
 messages = [] if legacy else parsed.messages
 if legacy:
  for old_message in parsed.messages: log_event(str(old_message))
 else:
  for event in messages:
   for key in ["id","step","minute","actor"]: event[key] = int(event[key])
 next_item_id = int(parsed.next_item_id)
 scan_report = parsed.scan_report
 scan_minute = int(parsed.scan_minute)
 var saved_scan = parsed.get("scan_cells",[])
 scan_cells = saved_scan if saved_scan is Array and saved_scan.size() == 81 and saved_scan.all(func(cell): return cell is Dictionary and int(cell.get("site",-2)) in range(-1,blocks.size()) and cell.has("type") and cell.has("count")) else []
 npc_cursor = int(parsed.npc_cursor)
 next_dialogue = float(parsed.get("next_dialogue",float(parsed.minute)+20.0))
 sense_report = str(parsed.get("sense_report","No recent field report."))
 scent_heatmap.clear()
 for actor in actors: _check_scent_trail(actor)
 metrics = parsed.metrics
 for key in metrics: metrics[key] = int(metrics[key])
 radio_defense.clear()
 var saved_calls = parsed.get("radio_defense",{})
 if saved_calls is Dictionary:
  for frequency in saved_calls:
   var call = saved_calls[frequency]
   if not str(frequency).is_valid_int() or int(frequency) not in range(2500,3001) or not call is Dictionary: continue
   var site = int(call.get("site",-1))
   var until = int(call.get("until",0))
   if site >= 0 and site < blocks.size() and until > minute: radio_defense[str(frequency)] = {"site":site,"until":until}
 rebuild_geography_index()
 reindex()
 _reset_npc_runtime(parsed.get("npc_locations",[]))
 return ""

# Strength is stored as a visible band and damage below that band's maximum.
func barricade_strength(b: Dictionary) -> int:
 var level = clampi(int(b.barricade),0,7)
 if level == 0: return 0
 return clampi(C.BARRICADE_MAX_STRENGTH[level]-int(b.get("barricade_damage",0)),C.BARRICADE_MAX_STRENGTH[level-1]+1,C.BARRICADE_MAX_STRENGTH[level])

func barricade_description(b: Dictionary) -> String:
 if barricade_strength(b) == C.STRONGLY_BARRICADED_STRENGTH: return "strongly barricaded"
 return C.barricade_description(b.barricade)

func set_barricade_strength(b: Dictionary, strength: int) -> void:
 strength = clampi(strength,0,21)
 var level = 0
 while C.BARRICADE_MAX_STRENGTH[level] < strength: level += 1
 b.barricade = level
 b.barricade_damage = C.BARRICADE_MAX_STRENGTH[level]-strength

func barricade_interference(b: Dictionary) -> bool:
 return occupants(b,true).filter(func(t): return not t.human and not t.down and t.hp > 0).size() >= 2

func barricade_build_chance(b: Dictionary) -> float:
 if barricade_strength(b) >= 21: return 0.0
 var chance = float(C.BARRICADE_BUILD_CHANCES[int(b.barricade)])
 if b.type in C.DARK_BARRICADE_BUILDINGS and not powered(b): chance *= 0.5
 if barricade_interference(b): chance *= 0.5
 return chance

func barricade_material(b: Dictionary) -> String:
 var materials = C.BARRICADE_MATERIALS.get(b.type,["a chair", "a table", "some loose planks"])
 return materials[rng.randi_range(0,materials.size()-1)]

func barricade_attack_stats(a: Dictionary, data: Dictionary = {}) -> Dictionary:
 var weapon = item_by_uid(a,a.equipped) if not data.get("unarmed",false) else {}
 var ineffective = {"hit":0,"structural":0.0,"weapon":weapon}
 if data.get("attack","") == "bite": return ineffective
 if not weapon.is_empty():
  var def = C.ITEMS[weapon.kind]
  if def.get("damage",0) <= 0 or def.has("capacity") or def.get("ranged",false) or weapon.kind == "knife": return ineffective
  if not a.human and weapon.kind not in C.ZOMBIE_MELEE_ITEMS: return ineffective
 var stats = attack_stats(a,{},"attack",weapon)
 return {"hit":stats.hit,"structural":1.0 if not weapon.is_empty() and weapon.kind == "crowbar" else C.BARRICADE_STRUCTURE_CHANCE,"weapon":weapon}

func melee_break_chance(item: Dictionary) -> float:
 # Legacy durability/wear fields remain loadable but no longer affect combat.
 return float(C.ITEMS[item.kind].get("break_on_hit",0.0))

func action_feedback(a: Dictionary, command: String, target: int = -1, data: Dictionary = {}, context_only: bool = false) -> String:
 var why = reason(a, command, target, data, context_only)
 # Entry remains an attempt the player can make, with feedback on rejection.
 if command == "barricade" and why == "The barricade cannot be built any higher.": return ""
 if command == "enter" and why.begins_with("You try to find an entry point"): return ""
 if command == "leave" and why == MAIN_DOORS_BLOCKED: return ""
 if command == "phone" and why == "Select a contact.": return ""
 if command == "revive" and why == BRAIN_ROT_REVIVAL_BLOCKED: return ""
 if why in [CORPSE_REVIVAL_BLOCKED,Extended.CORPSE_FEED_BLOCKED,Extended.CORPSE_DRAG_BLOCKED] and not has_skill(a,"scent_death"): return ""
 if command == "lookout" and not data.has("direction") and why == BINOCULAR_DIRECTION_REQUIRED: return ""
 return why

func skill_cost(a: Dictionary, skill: String) -> int:
 var category = C.skill_category(skill)
 if C.SKILLS[skill].side == "zombie" or category in ["civilian", "hunter"]: return 100
 var occupation = C.occupation_category(a.job)
 if occupation == category: return 75
 if occupation in ["military", "science"]: return 150
 return 100

func has_current_descriptions(b: Dictionary) -> bool:
 return int(b.get("description_version",0)) == 7 and b.get("description_type","") == b.type and b.has("inside_description") and b.has("outside_description")

func ensure_descriptions(b: Dictionary) -> void:
 if has_current_descriptions(b): return
 var local_rng = RandomNumberGenerator.new()
 for side in ["inside", "outside"]:
  local_rng.seed = world_seed*1000+int(b.id)+(10000019 if side == "outside" else 0)
  var kind = "office" if b.type == "necrotech_lab" and side == "outside" else b.type
  var pool: Dictionary = description_pools.get(kind,{}).get(side,{})
  var choices: Array = []
  for column in ["first", "second", "third"]: choices.append_array(pool.get(column,[]))
  b[side+"_description"] = choices[local_rng.randi_range(0,choices.size()-1)].strip_edges() if not choices.is_empty() else "This place shows signs of decay and neglect."
 b.description_version = 7
 b.description_type = b.type

func environmental_description(b: Dictionary, observer: Dictionary) -> String:
 var descriptions := b
 if not has_current_descriptions(b):
  descriptions = {"id":b.id, "type":b.type}
  ensure_descriptions(descriptions)
 if b.type == "necrotech_lab" and observer.inside:
  return description_pools.necrotech_lab.inside.powered_third[0] if powered(b) else description_pools.necrotech_lab.inside.third[0]
 return descriptions["inside_description" if observer.inside else "outside_description"]

func entrance_is_open(b: Dictionary) -> bool:
 return b.barricade == 0 and not doors_closed(b)

func entrance_description(b: Dictionary) -> String:
 if b.barricade == 1:
  return "The %s protected by a loose barricade of discarded furniture." % ("doors are" if has_doors(b) else "entrance is")
 if b.barricade > 0: return "The building has been %s." % barricade_description(b)
 if not has_doors(b):
  return "A hole cut in the fence serves as the entrance." if b.type == "junkyard" else "A broad opening leads into the site."
 if doors_closed(b): return "The building's doors have been secured."
 return "The doors to the building are wide open."

func exterior_building_clues(b: Dictionary) -> String:
 var clues = entrance_description(b)
 if b.ruin >= 3:
  clues += " The building has been ruined."
 elif b.ruin > 0 and entrance_is_open(b):
  clues = "The doors are wide open, the building is a mess." if has_doors(b) else "The entrance is open, the building is a mess."
 if powered(b):
  clues = clues.trim_suffix(".") + ", and lights are on inside."
 return clues

func location_description(a: Dictionary) -> String:
 if a.down: return "You are down. Everything is dark. Rest and stand up to see your surroundings again."
 var b = current_block(a)
 var first = "You are standing %s %s. %s" % ["outside" if is_building(b) and not a.inside else "in", b.name, environmental_description(b,a)]
 if is_building(b): first += " " + entrance_description(b)
 var names: Array[String] = []
 var zombies = 0
 var bodies = 0
 for other in occupants(b,a.inside):
  if other.id == a.id: continue
  if other.down: bodies += 1
  elif other.human:
   var name = display_name(other)
   if sees_survivor_hp(a,other): name += " [%d/%d HP]" % [other.hp,max_hp(other)]
   names.append(name)
  else: zombies += 1
 if not names.is_empty():
  var listing = names[0] if names.size() == 1 else (" and ".join(names) if names.size() == 2 else ", ".join(names.slice(0,-1)) + ", and " + names[-1])
  first += " Also here %s %s." % ["is" if names.size() == 1 else "are",listing]
 var paragraphs: Array[String] = [first]
 if a.inside and b.generator:
  var power = "A portable generator is set up here. "
  if powered(b):
   power += "It is running, powering a radio transmitter that's currently set to %.2f MHz." % float(b.frequency) if b.radio and b.radio_hp > 0 else "It is running."
  elif b.generator_hp <= 0: power += "It is damaged."
  else: power += "It is out of fuel."
  paragraphs.append(power)
 elif not a.inside and is_building(b) and powered(b): paragraphs.append("Lights are on inside.")
 var graffiti: String = b.graffiti_inside if a.inside else b.graffiti
 if not graffiti.is_empty(): paragraphs.append("Somebody has spraypainted %s onto a %s." % [graffiti, "tree" if not a.inside and b.type in ["park","cemetery","zoo"] else "wall"])
 if zombies > 0:
  if a.human:
   paragraphs.append("There is a lone zombie here." if zombies == 1 else ("There are two zombies here." if zombies == 2 else "There is a group of %d zombies here." % zombies))
  else: paragraphs.append("There is another zombie here." if zombies == 1 else "There are another %d zombies here." % zombies)
 if bodies > 0: paragraphs.append("There is 1 dead body here." if bodies == 1 else "There are %d dead bodies here." % bodies)
 return "\n\n".join(paragraphs)

func time_speed() -> float:
 var p = player()
 if sleeping: return C.SLEEP_SPEED
 if p.down and (p.ap < 1 or minute < p.ready_at): return C.DEATH_SPEED
 return C.REST_SPEED if resting else 1.0

func reanimate_bodies() -> void:
 for a in actors:
  if a.id > 0 and a.get("dormant",false) and rng.randf() < C.DAILY_REANIMATION_CHANCE:
   a.dormant = false
   a.ready_at = minute
   _schedule_npc(a,clock_step+rng.randi_range(10,600))

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
  "radio_transmitter": return has_skill(a,"radio_operation")
  "spray_can": return has_skill(a,"lab_experience") or has_skill(a,"tagging")
  "fuel_can": return AI.shelter_worker(self,a)
 return false

func wanted_supply(a: Dictionary) -> String:
 if (a.hp < 43 or a.infected or a.job in ["Doctor","Medic"]) and item_kind(a,"first_aid_kit").is_empty(): return "first_aid_kit"
 if has_skill(a,"lab_experience") and item_kind(a,"syringe").is_empty(): return "syringe"
 var home = blocks[a.home]
 if item_kind(a,"toolbox").is_empty() and has_skill(a,"construction"): return "toolbox"
 if not item_kind(a,"pistol").is_empty() and item_kind(a,"pistol_clip").is_empty(): return "pistol_clip"
 if not item_kind(a,"shotgun").is_empty() and item_kind(a,"shotgun_shell").is_empty(): return "shotgun_shell"
 if a.job in ["Private","Police Officer","Guard","Medic"] and item_kind(a,"pistol").is_empty() and item_kind(a,"shotgun").is_empty(): return "pistol"
 if a.job == "Firefighter" and item_kind(a,"fire_axe").is_empty(): return "fire_axe"
 if AI.shelter_worker(self,a):
  if not home.generator and item_kind(a,"portable_generator").is_empty(): return "portable_generator"
  if (not powered(home) or home.fuel_until-minute < 360) and item_kind(a,"fuel_can").is_empty(): return "fuel_can"
 var armed = a.inventory.any(func(item): return C.ITEMS[item.kind].has("damage") and not C.ITEMS[item.kind].get("fragile",false))
 if not armed:
  return "crowbar" if a.job == "Engineer" else "baseball_bat"
 if powered(home) and not home.radio and has_skill(a,"radio_operation") and item_kind(a,"radio_transmitter").is_empty(): return "radio_transmitter"
 if has_skill(a,"lab_experience") and not revive_sites.has(home.id) and home.type in ["church","cathedral"] and item_kind(a,"spray_can").is_empty(): return "spray_can"
 return ""

func nearby_light(a: Dictionary) -> Dictionary:
 var origin_x: int = a.x
 var origin_y: int = a.y
 var start_x: int = maxi(0,origin_x-3)
 var end_x: int = mini(width,origin_x+4)
 var best: Dictionary = {}
 var nearest: int = 4
 for y in range(maxi(0,origin_y-3),mini(height,origin_y+4)):
  var row: int = y*width
  var dy: int = absi(y-origin_y)
  if dy >= nearest: continue
  for x in range(start_x,end_x):
   var b: Dictionary = blocks[row+x]
   if not b.generator: continue
   var distance: int = maxi(absi(x-origin_x),dy)
   # Keep the first map square at each distance. Query power live.
   if distance < nearest and powered(b):
    if distance == 0: return b
    best = b
    nearest = distance
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
 if a.get("sex","") not in ["male","female"]: a.sex = C.occupation_sex(a.job)
 if not a.has("original_human"):
  a.original_human = a.job not in ["Corpse","Resident"]
  if a.id > 0 and a.original_human and not a.human: a.wants_revive = true
 if not a.has("prefers_undead"):
  a.prefers_undead = a.id > 0 and a.job in ["Corpse","Resident"] and int(a.id)%3 != 0
 if not a.get("tagged_skills") is Array: a.tagged_skills = []
 if a.has("trail_until"):
  # Old departure markers lack a survivor interaction to anchor the trail.
  if int(a.get("trail_from",-1)) >= 0: a.memory = -1
  a.trail_from = -1
  for key in ["trail_origin","trail_destination","trail_until"]: a.erase(key)
 var defaults = {"wants_revive":false,"route":[],"route_goal":-1,"avoid_site":-1,"avoid_until":0,"next_groan":0,"heard_call":"","heard_call_site":-1,"heard_call_until":0,"grasp_target":-1,"grasped_by":-1,"infected":false,"pose":"idle","pose_at":0.0,"pose_sequence":0,"trail_from":-1,"trail_lost":false,"scout_site":-1,"scout_day":-1,"scout_used":0,"fed":0,"headshot":0,"tagged_until":0,"channel":27.0,"outfit":"","npc_purchases":0,"npc_observed":-1,"npc_observed_at":-1,"npc_signal":"","npc_special_at":0}
 for key in defaults:
  if not a.has(key): a[key] = defaults[key]
 for key in ["route_goal","avoid_site","avoid_until","next_groan","heard_call_site","heard_call_until","grasp_target","grasped_by","pose_sequence","trail_from","scout_site","scout_day","scout_used","fed","headshot","tagged_until","npc_purchases","npc_observed","npc_observed_at","npc_special_at"]: a[key] = int(a[key])
 a.route = a.route.map(func(id): return int(id))
 a.pose_at = float(a.pose_at)
 a.channel = float(a.channel)

func initialize_block(b: Dictionary) -> void:
 if not b.has("ransack_hits"): b.ransack_hits = 5 if int(b.get("ruin",0)) >= 3 else int(b.get("ruin",0))
 if not b.has("ruined_at"): b.ruined_at = minute if int(b.get("ruin",0)) >= 3 else -1
 b.ransack_hits = int(b.ransack_hits)
 b.ruined_at = int(b.ruined_at)
 var defaults = {"barricade":0,"doors":false,"ruin":0,"generator":false,"generator_hp":C.GENERATOR_HP,"fuel_until":0,"known":false,"barricade_damage":0,"last_pounding":-9999,"zoo":"","unbarricadable":false,"radio":false,"radio_hp":0,"frequency":C.PUBLIC_RADIO_FREQUENCY,"graffiti":"","graffiti_inside":"","decorations":[],"complex":"","fort":"","mast":false,"revive_point":false,"npc_entry":-1,"npc_ingress":false}
 for key in defaults:
  if not b.has(key): b[key] = defaults[key]
 b.npc_entry = int(b.npc_entry)
 if b.npc_entry < 0 or b.npc_entry >= width*height: b.npc_entry = -1
 if not can_be_ransacked(b):
  b.ruin = 0
  b.ransack_hits = 0
  b.ruined_at = -1
 if not can_host_generator(b):
  b.generator = false
  b.fuel_until = 0
 b.unbarricadable = not is_building(b)
 if b.unbarricadable: b.barricade = 0; b.barricade_damage = 0
 set_barricade_strength(b,barricade_strength(b))
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

func attack_damage(target: Dictionary, stats: Dictionary) -> int:
 var damage = int(stats.damage)
 if stats.ranged and (not item_kind(target,"flak_jacket").is_empty() or has_skill(target,"flesh_rot")): damage = int(floor(damage*0.8))
 return damage

func roll_attack_hit(hit: float) -> bool:
 # Keep integer attack rolls stable while representing fractional chances exactly.
 if hit == floor(hit): return rng.randi_range(1,100) <= hit
 return rng.randf()*100.0 < hit

func attack_stats(a: Dictionary, target: Dictionary, command: String, weapon: Dictionary = {}) -> Dictionary:
 var hit = 10.0
 var damage = 1
 var ranged = false
 var newspaper = a.human and weapon.get("kind","") == "newspaper"
 if not a.human and command != "bite" and not weapon.is_empty() and weapon.kind in C.ZOMBIE_MELEE_ITEMS:
  hit = C.ITEMS[weapon.kind].hit
  damage = 2
 elif not a.human:
  if command == "bite":
   var trained = has_skill(a,"rend_flesh")
   hit = (40 if trained else 30) if has_skill(a,"neck_lurch") else 0
   damage = 5 if trained else 4
  else:
   hit = 25+(10 if has_skill(a,"vigour_mortis") else 0)+(15 if has_skill(a,"death_grip") else 0)
   damage = 2
 else:
  if not weapon.is_empty():
   var def = C.ITEMS[weapon.kind]
   hit = def.hit
   damage = def.damage
   ranged = def.has("capacity") or def.get("ranged",false)
   if weapon.kind == "flare_gun" and target.get("fuel_soaked",false): damage *= 2
  if ranged:
   if has_skill(a,"firearms"): hit += 12.5 if weapon.kind == "flare_gun" else 15
   if weapon.kind == "pistol": hit += (25 if has_skill(a,"pistol_training") else 0)+(10 if has_skill(a,"advanced_pistol") else 0)
   if weapon.kind == "shotgun": hit += (25 if has_skill(a,"shotgun_training") else 0)+(10 if has_skill(a,"advanced_shotgun") else 0)
  else:
   if has_skill(a,"hand_to_hand") and not newspaper: hit += 15
   if not weapon.is_empty() and weapon.kind == "knife" and has_skill(a,"knife_combat"): hit += 25
   if not weapon.is_empty() and weapon.kind == "fire_axe" and has_skill(a,"axe_proficiency"): hit = minf(40,hit+30)
  if a.grasped_by >= 0: hit -= 10
 if is_dark_building(current_block(a)) and a.inside and not powered(current_block(a)):
  hit = hit*0.5 if not weapon.is_empty() and weapon.kind == "flare_gun" else floor(hit*0.5)
 return {"hit":clampf(hit,0.0,100.0 if newspaper else 95.0),"damage":damage,"ranged":ranged}

func within_fort(a: Dictionary, b: Dictionary) -> bool:
 return not b.fort.is_empty() and (b.type != "gatehouse" or a.inside)

func fort_gatehouse(identity: String) -> Dictionary:
 for site in sites_by_type.get("gatehouse",[]):
  if site.fort == identity: return site
 return {}

func roll_free_run_fall() -> bool:
 return rng.randf() < 0.2

func shared_building_interior(origin: Dictionary, destination: Dictionary) -> bool:
 return not origin.complex.is_empty() and origin.complex == destination.complex and origin.zoo.is_empty() and origin.fort.is_empty()

func free_run_route(a: Dictionary, origin: Dictionary, destination: Dictionary) -> bool:
 if not a.inside or not a.human or not has_skill(a,"free_running") or not is_building(destination): return false
 if not destination.fort.is_empty() and destination.fort != origin.fort: return false
 if not origin.fort.is_empty():
  if destination.fort == origin.fort:
   return origin.type != "gatehouse" and destination.type != "armoury"
  return origin.type == "gatehouse" and origin.barricade <= 4
 return true

func can_free_run_between(a: Dictionary, origin: Dictionary, destination: Dictionary) -> bool:
 return destination.ruin < 3 and free_run_route(a,origin,destination)

func move_ends_inside(a: Dictionary, origin: Dictionary, destination: Dictionary, data: Dictionary = {}) -> bool:
 if not origin.fort.is_empty() and origin.fort == destination.fort:
  if destination.type == "gatehouse": return true
  if origin.type == "gatehouse": return false
 if not destination.fort.is_empty() and destination.fort != origin.fort: return false
 if shared_building_interior(origin,destination): return a.inside and is_building(destination)
 return bool(data.get("free_run",true)) and can_free_run_between(a,origin,destination)

func fort_move_reason(a: Dictionary, origin: Dictionary, destination: Dictionary, data: Dictionary = {}) -> String:
 if origin.fort == destination.fort:
  if not origin.fort.is_empty() and origin.type == "gatehouse" and not a.inside: return "Enter the gatehouse before crossing into the fort."
  return ""
 if not origin.fort.is_empty() and origin.type != "gatehouse" and bool(data.get("free_run",false)):
  return "There are no accessible windows across the fort wall. Use a ground-level map exit."
 if not destination.fort.is_empty() and destination.type != "gatehouse": return "Enter the fort through its gatehouse."
 if not destination.fort.is_empty() and destination.fort != origin.fort and a.inside and a.human and has_skill(a,"free_running") and bool(data.get("free_run",true)):
  return "The gatehouse only has a single, low entrance. You cannot Free Run into it; approach at ground level."
 if origin.type == "gatehouse" and not origin.fort.is_empty() and a.inside and origin.barricade > 4 and bool(data.get("free_run",false)):
  return "The gatehouse is too heavily barricaded to Free Run out. Click an adjacent map square to exit at ground level."
 return ""

func _starting_setup(occupation: String) -> Array:
 var setups = {"Private":[["firearms"],["pistol","pistol_clip"]],"Medic":[["first_aid"],["pistol","first_aid_kit"]],"Scout":[["free_running"],["binoculars"]],"NecroTech Lab Assistant":[["necro_employment"],["dna_extractor"]],"Doctor":[["diagnosis"],["first_aid_kit","first_aid_kit"]],"Police Officer":[["firearms"],["pistol","pistol_clip","flak_jacket","radio"]],"Firefighter":[["axe_proficiency"],["fire_axe","first_aid_kit"]],"Consumer":[["shopping"],["baseball_bat","mobile_phone"]],"Corpse":[[],[]],"Volunteer":[["construction","necro_employment","lab_experience"],["baseball_bat","first_aid_kit","toolbox","syringe"]]}
 var aliases = {"Guard":"Private","Scientist":"NecroTech Lab Assistant","Engineer":"Volunteer","Resident":"Corpse"}
 return setups.get(aliases.get(occupation,occupation),setups.Volunteer)

func _setup_starting_skills(a: Dictionary, occupation: String) -> void:
 a.human_skills = _starting_setup(occupation)[0].duplicate()
 a.zombie_skills = ["vigour_mortis"] if occupation in ["Corpse","Resident"] else []

func _setup_player(a: Dictionary, occupation: String) -> void:
 var setup = _starting_setup(occupation)
 _setup_starting_skills(a,occupation)
 a.human = occupation not in ["Corpse","Resident"]
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
