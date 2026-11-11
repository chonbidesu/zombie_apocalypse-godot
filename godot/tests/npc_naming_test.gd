extends SceneTree
const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/character_names.json"))
 var city = Sim.new()
 assert(city.start(42,"Volunteer",{"mode":"malton","survivors":32,"zombies":24}).is_empty())
 for actor in city.actors.slice(1):
  var pool: Array = data.male_first_name if actor.sex == "male" else data.female_first_name
  assert(actor.first in pool)
 var s = Sim.new()
 s.start(42)
 var original_identity = [s.actors[5].first, s.actors[5].last, s.actors[5].adjective, s.actors[5].sex]
 assert(s.save_to("user://npc-naming-test.json") == OK)
 var restored = Sim.new()
 assert(restored.load_from("user://npc-naming-test.json").is_empty())
 assert([restored.actors[5].first, restored.actors[5].last, restored.actors[5].adjective, restored.actors[5].sex] == original_identity)
 for i in range(6000 - (s.actors.size() - 1)):
  s._actor("", "", "", "Resident", 0, 0, i % 2 == 0, false)
 s.ensure_unique_npc_names()
 var names = {}
 var adjectives = {}
 for a in s.actors:
  if a.id > 0:
   var pool: Array = data.male_first_name if a.sex == "male" else data.female_first_name
   assert(a.first in pool)
  var full = (a.first + " " + a.last).to_lower()
  var adjective = a.adjective.to_lower()
  assert(not a.first.is_empty() and not a.last.is_empty() and not adjective.is_empty())
  assert(not names.has(full) and not adjectives.has(adjective))
  names[full] = true
  adjectives[adjective] = true
  a.human = true
  assert(s.display_name(a) == a.first + " " + a.last)
  a.human = false
  assert(s.display_name(a) == a.adjective + " " + a.first)
 var existing = s.actors[1].duplicate(true)
 s.player().first = existing.first
 s.player().last = existing.last
 s.player().adjective = existing.adjective
 s.ensure_unique_npc_names()
 assert(s.actors[1].first + " " + s.actors[1].last != existing.first + " " + existing.last)
 assert(s.actors[1].adjective != existing.adjective)
 print("NPC naming checks passed for 6000 NPCs")
 quit()
