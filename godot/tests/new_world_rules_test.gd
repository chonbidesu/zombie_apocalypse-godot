extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Progression = preload("res://scripts/npc_utility/progression.gd")
var failures = 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 var s = Sim.new()
 for job in ["Doctor", "Police Officer", "NecroTech Lab Assistant", "Corpse"]:
  s.start(991,job)
  check(s.player().inside and s.is_building(s.current_block(s.player())), job + " starts inside")
  var types = {"Doctor":"hospital", "Police Officer":"police_department", "NecroTech Lab Assistant":"necrotech_lab", "Corpse":"hospital"}
  check(s.current_block(s.player()).type == types[job], job + " starts at a relevant building")
 var p = s.player()
 s.start(991,"Doctor")
 p = s.player()
 var b = s.current_block(p)
 var other = s.actors[1]
 other.x = p.x; other.y = p.y; other.inside = true; other.human = true; other.down = false; other.hp = 33
 p.human_skills = ["diagnosis"]
 s.reindex()
 var desc = s.location_description(p)
 check(desc.begins_with("You are standing in " + b.name + ". "), "Location begins with block name")
 check(desc.contains(s.display_name(other)) and desc.contains("[33/50 HP]"), "Diagnosis displays survivor name and health")
 check(s.environmental_description(b,p).count(".") == 1, "One environmental sentence")
 p.inside = false
 check(s.location_description(p).begins_with("You are standing outside " + b.name), "Exterior uses outside wording")
 var z = s.actors[15]
 z.human = false; z.zombie_skills = []; z.wants_revive = false
 check(Progression.target_skill(z,0,"",false) == "memories", "Zombie prioritizes Memories")
 z.zombie_skills.append("memories")
 check(Progression.target_skill(z,0,"",false) == "ransack", "Zombie prioritizes Ransack second")
 p.inside = true; p.ap = 1; p.busy_until = 0
 for a in s.actors:
  if a.id > 0: a.down = true
 s.reindex()
 check(s.begin_sleep().is_empty(), "Player can sleep")
 s.stop_rest()
 other.down = false; other.human = true; other.ap = 0; other.busy_until = 0; other.dormant = false
 s.reindex(); s._schedule_npc(other,s.clock_step+1); s.advance_steps(1)
 check(other.get("recovery_mode", "") == "sleep", "Exhausted sheltered NPC sleeps")
 var due = other.next_think
 s.wake_npc(other)
 check(other.next_think == due and other.recovery_mode == "sleep", "Sleeping NPC does not wake from danger")
 s.advance_steps(300)
 check(other.ap == 2, "Sleeping NPC recovers AP faster")
 print("New rules failures: ",failures)
 quit(1 if failures else 0)
