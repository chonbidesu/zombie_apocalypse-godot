extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
const JOBS = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse"]

func check_balance(sim) -> void:
 var counts = {}
 var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/character_names.json"))
 for a in sim.actors.slice(1):
  assert(a.sex in ["male","female"])
  if not counts.has(a.job): counts[a.job] = {"male":0,"female":0}
  counts[a.job][a.sex] += 1
  assert(a.first in (names.male_first_name if a.sex == "male" else names.female_first_name))
 for job in counts:
  assert(absi(counts[job].male-counts[job].female) <= 1,"Unbalanced occupation: "+job)

func _initialize() -> void:
 for seed_value in [42,4815,731]:
  var city = Sim.new()
  assert(city.start(seed_value,"Volunteer",{"mode":"malton","survivors":73,"zombies":65}).is_empty())
  check_balance(city)
  var repeat = Sim.new()
  repeat.start(seed_value,"Volunteer",{"mode":"malton","survivors":73,"zombies":65})
  assert(city.actors == repeat.actors,"Same seed must reproduce NPC identities")
  assert(city.save_to("user://npc-sex-test.json") == OK)
  var restored = Sim.new()
  assert(restored.load_from("user://npc-sex-test.json").is_empty())
  for i in city.actors.size():
   assert(restored.actors[i].sex == city.actors[i].sex)
   assert(restored.actors[i].first == city.actors[i].first)
  check_balance(restored)
  # A pre-variant save has no sex fields. It should gain both sexes on load.
  var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://npc-sex-test.json"))
  for a in old_save.actors: a.erase("sex")
  var old_file = FileAccess.open("user://npc-sex-legacy-test.json",FileAccess.WRITE)
  old_file.store_string(JSON.stringify(old_save))
  old_file.close()
  var migrated = Sim.new()
  assert(migrated.load_from("user://npc-sex-legacy-test.json").is_empty())
  check_balance(migrated)
  for job in JOBS:
   var state = restored.rng.state
   restored._next_npc_sex(job)
   assert(restored.rng.state == state,"Sex selection must not advance gameplay RNG")
 var sandbox = Sim.new()
 sandbox.start(42)
 check_balance(sandbox)
 for job in JOBS + ["Guard","Scientist","NecroTech Assistant","Engineer","Volunteer","Resident"]:
  assert(C.occupation_sheet(job,true,"male") != C.occupation_sheet(job,true,"female"))
  for sex in ["male","female"]:
   for human in [true,false]:
    var sheet = C.occupation_sheet(job,human,sex)
    assert(ResourceLoader.exists("res://assets/sprite_sheets/"+sheet+"_sprite_sheet.png"),sheet)
   assert(ResourceLoader.exists("res://assets/portraits/"+C.occupation_portrait(job,sex)+".png"))
 assert(C.occupation_sheet("Corpse",false,"female") == "zombie_female")
 assert(C.occupation_sheet("Corpse",true,"female") == "vagrant_female")
 print("NPC sex checks passed: balanced occupations, names, determinism, saves and artwork")
 quit()
