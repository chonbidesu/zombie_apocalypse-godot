extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var s
var p: Dictionary
var b: Dictionary
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func ready() -> void:
 p.ap = 50; p.busy_until = s.now(); p.infected = false

func _initialize() -> void:
 s = Sim.new(); s.start(992)
 p = s.player(); b = s.current_block(p)
 for a in s.actors:
  if a.id != 0: a.x = 0; a.y = 0; a.down = true; a.inside = false
 s.reindex()
 var state = s.rng.state
 for kind in C.BUILDINGS+C.OUTDOORS:
  var sides = ["outside","inside"] if kind in C.BUILDINGS else ["outside"]
  for side in sides:
   var pool: Dictionary = s.description_pools[kind][side]
   for slot in ["first","second","third"]:
    var fixed_logo = kind == "necrotech_lab" and side == "inside" and slot == "third"
    check(pool[slot].size() >= (1 if fixed_logo else 2),"Sentence choices: %s/%s/%s" % [kind,side,slot])
   var variants = {}
   for id in range(20):
    var sample = b.duplicate(true); sample.id = id; sample.type = kind; sample.description_version = 0
    s.ensure_descriptions(sample)
    variants[sample[side+"_description"]] = true
   check(variants.size() > 1,"Independent locations receive varied prose: "+kind+"/"+side)
 check(s.rng.state == state,"Description selection does not change simulation RNG")
 necrotech()
 dark_repairs()
 state_text()
 print("ENVIRONMENT RULE CHECKS: %d FAILURES: %d" % [checks,failures])
 quit(1 if failures else 0)

func necrotech() -> void:
 b.type = "necrotech_lab"; b.generator = false; b.ruin = 0
 p.inside = false; p.human_skills = []; p.human = true
 var before_view := b.duplicate(true)
 var hidden = s.environmental_description(b,p)
 check(b == before_view,"Reading a location with stale prose leaves its saved state intact")
 s.ensure_descriptions(b)
 var office = b.duplicate(true); office.type = "office"; office.description_version = 0
 check(hidden == s.environmental_description(office,p) and not hidden.contains("NecroTech"),"Untrained lab exterior is exactly its office counterpart")
 var original_parts: Array = b.outside_description_parts.duplicate()
 p.human_skills = ["necro_employment"]
 var recognized = s.environmental_description(b,p)
 check(recognized.begins_with(original_parts[0]+" "+original_parts[1]) and recognized.ends_with(b.necrotech_recognition),"Employment replaces only the third exterior sentence")
 p.human = false
 check(s.environmental_description(b,p) == recognized,"Recognizing NecroTech survives death")
 p.human = true; p.human_skills = []; p.inside = true
 var inside = s.environmental_description(b,p)
 check(inside.contains("NecroTech logo") and inside.contains("computer") and inside.contains("lab"),"Untrained interiors identify NecroTech and laboratory equipment")
 check(inside.ends_with("The NecroTech logo is set in the wall behind the front desk, and doors open onto powered-down computer rooms and laboratories."),"Unpowered logo sentence matches the requested copy")
 var parts: Array = b.inside_description_parts.duplicate()
 b.generator = true; b.generator_hp = C.GENERATOR_HP; b.fuel_until = s.minute+100
 var lit = s.environmental_description(b,p)
 check(lit.begins_with(parts[0]+" "+parts[1]) and lit.ends_with("The NecroTech logo glows gently above the front desk, and doors open onto a number of brightly-lit laboratories and computer rooms."),"Power replaces only the third interior sentence with the requested copy")
 b.description_version = 5; b.inside_description = "Old generic description."
 s.ensure_descriptions(b)
 check(b.description_version == 6 and not b.inside_description.contains("Old generic"),"Older saved prose migrates to current descriptions")
 var before = s.location_description(p)
 check(s.save_to("user://environment-rules-test.json") == OK,"Description fields save")
 var loaded = Sim.new()
 check(loaded.load_from("user://environment-rules-test.json").is_empty() and loaded.location_description(loaded.player()) == before,"Generated prose survives save/load without rerolling")

func dark_repairs() -> void:
 p.inside = true; p.human = true; p.human_skills = ["construction"]; p.inventory.clear()
 s.give_item(p,"toolbox")
 b.fort = ""; b.complex = ""; b.zoo = ""
 for kind in C.DARK_BUILDINGS:
  b.type = kind; b.ruin = 3; b.generator = false; b.fuel_until = 0; b.generator_hp = 6; b.doors = false
  s.set_barricade_strength(b,0)
  ready()
  check(s.reason(p,"repair").contains("too dark"),"Unpowered dark ruin cannot be repaired: "+kind)
  s.give_item(p,"portable_generator"); s.give_item(p,"fuel_can")
  check(s.act("generator").ok and b.generator and b.ruin == 3,"Generator installation is legal in a ruin")
  ready()
  check(s.reason(p,"repair").contains("too dark"),"An unfueled generator does not unlock repair")
  check(s.act("fuel").ok and s.powered(b) and b.ruin == 3,"Fueled generator lights a ruined building")
  ready()
  check(not s.reason(p,"barricade").is_empty(),"Powered ruin still cannot be barricaded")
  check(s.act("close").ok and b.doors,"Doors can be secured in a powered ruin")
  check(is_equal_approx(s.search_chance(b,p),0.1),"Powered ruin retains ordinary ruined search odds")
  ready()
  check(s.act("repair").ok and b.ruin == 0,"Lighting unlocks single-action structural repair")
  b.generator = false
  check(is_equal_approx(s.search_chance(b,p),0.01),"Total darkness uses one percent find rate")
  b.ruin = 3
  check(is_equal_approx(s.search_chance(b,p),0.01),"Unpowered dark ruins also have near-zero searches")
  b.ruin = 0; s.set_barricade_strength(b,8)
  check(is_equal_approx(s.barricade_build_chance(b),0.851*0.5),"Dark construction odds are halved")
 for kind in ["warehouse","power_station","hospital","police_department","office"]:
  b.type = kind; b.name = "The Dark Building"; b.generator = false; b.ruin = 3
  ready()
  check(not s.is_dark_building(b) and s.reason(p,"repair").is_empty(),"Ordinary unlit ruin needs no generator: "+kind)
  b.ruin = 0
  check(is_equal_approx(s.barricade_build_chance(b),0.851),"Ordinary unlit building has no construction penalty")
 for kind in ["gatehouse","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house","junkyard","church","cathedral"]:
  b.type = kind; b.ruin = 3; b.doors = false
  ready()
  check(not s.has_doors(b) and not s.act("close").ok and p.ap == 50,"Doorless type cannot acquire closed doors: "+kind)

func state_text() -> void:
 b.type = "bank"; b.ruin = 3; b.generator = true; b.generator_hp = 6; b.fuel_until = s.minute+100; b.doors = true
 s.set_barricade_strength(b,0)
 p.inside = false
 var text = s.location_description(p)
 check(text.contains("The building's doors have been secured. The building has been ruined, and lights are on inside.") and not text.contains("portable generator"),"Closed exterior shows powered ruin after the doors and keeps generator details indoors")
 b.fuel_until = 0
 check(s.exterior_building_clues(b).ends_with("The building has been ruined.") and not s.exterior_building_clues(b).contains("lights"),"Unpowered ruin remains visible without a lighting cue")
 b.ruin = 1
 check(s.exterior_building_clues(b) == "The building's doors have been secured.","Closed doors conceal ransacking")
 b.doors = false
 check(s.exterior_building_clues(b) == "The doors are wide open, the building is a mess.","Open doors reveal ransacking")
 b.fuel_until = s.minute+100
 check(s.exterior_building_clues(b).ends_with("the building is a mess, and lights are on inside."),"Exterior lighting follows the visible ransacking")
 var barricade_text = {
  1: "The doors are protected by a loose barricade of discarded furniture",
  10: "The building has been very strongly barricaded",
  21: "The building has been extremely heavily barricaded"
 }
 for strength in barricade_text:
  s.set_barricade_strength(b,strength)
  check(s.exterior_building_clues(b) == barricade_text[strength] + ", and lights are on inside.","Barricade conceals ransacking and shows lights last")
 s.set_barricade_strength(b,0)
 b.ruin = 0; b.fuel_until = 0
 check(s.exterior_building_clues(b) == "The doors to the building are wide open.","Intact unpowered exterior shows only open doors")
 b.ruin = 3; b.fuel_until = s.minute+100
 p.inside = true; b.generator_hp = 2
 text = s.location_description(p)
 check(text.contains("A portable generator has been set up here. It is running.") and not text.contains("The lights are on.") and not text.contains("badly damaged") and text.contains("The building has been ruined. Its structural damage prevents you from barricading."),"Powered interior uses the running generator sentence and explains structural limits")
 b.fuel_until = 0
 text = s.location_description(p)
 check(text.contains("The building is pitch black inside.") and text.contains("A portable generator has been set up here. It is badly damaged."),"Dark interior reports generator damage")
 b.generator_hp = C.GENERATOR_HP; b.ruin = 1; b.doors = true
 text = s.location_description(p)
 check(text.contains("A portable generator has been set up here. It is out of fuel.") and text.contains("The building has been ransacked."),"Inside sees empty fuel and ransacking behind closed doors")
 b.type = "office"
 text = s.location_description(p)
 check(not text.contains("pitch black") and not text.contains("The building is unlit."),"Ordinary unpowered interiors omit generic lighting")
