extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const EXPECTED = {
 "Private":["firearms"], "Guard":["firearms"], "Medic":["first_aid"],
 "Scout":["free_running"], "NecroTech Lab Assistant":["necro_employment"],
 "Scientist":["necro_employment"], "Doctor":["diagnosis"],
 "Police Officer":["firearms"], "Firefighter":["axe_proficiency"],
 "Consumer":["shopping"], "Volunteer":["construction","necro_employment","lab_experience"],
 "Engineer":["construction","necro_employment","lab_experience"], "Corpse":[], "Resident":[]
}
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)

func _initialize() -> void:
 for config in [{"mode":"sandbox"},{"mode":"malton","survivors":24,"zombies":12},{"mode":"random","width":10,"height":10,"malls":0,"forts":0,"zoos":0,"survivors":24,"zombies":12}]:
  var sim = Sim.new()
  var error = sim.start(4815,"Corpse",config)
  check(error.is_empty(),"World starts: "+config.mode)
  if not error.is_empty(): continue
  for actor in sim.actors:
   var expected_zombie = ["vigour_mortis"] if actor.job in ["Corpse","Resident"] else []
   check(actor.human_skills == EXPECTED[actor.job] and actor.zombie_skills == expected_zombie,"Starting skills match player occupation in %s: %s" % [config.mode,actor.job])
  var zombie = sim.actors.filter(func(actor): return actor.id > 0 and actor.job in ["Corpse","Resident"])[0]
  var block = sim.blocks[44]
  block.type = "hospital"; block.generator = false; block.ruin = 0; block.ransack_hits = 0
  for actor in sim.actors:
   if actor.id != zombie.id and actor.x == block.x and actor.y == block.y: actor.inside = false
  zombie.x = block.x; zombie.y = block.y; zombie.inside = true; zombie.down = false; zombie.ap = 50; zombie.busy_until = 0.0; zombie.xp = 300
  sim.reindex()
  check(sim.reason(zombie,"ransack").contains("Ransack is required"),"Starting zombie cannot ransack")
  check(not sim.skill_reason(zombie,"ransack").is_empty(),"Ransack requires learning Memories of Life first")
  check(sim.learn("memories",zombie.id).is_empty() and sim.learn("ransack",zombie.id).is_empty(),"Zombie can learn Memories of Life and Ransack")
  check(sim.reason(zombie,"ransack").is_empty(),"Zombie can ransack after learning the skill")
  check(sim.save_to("user://npc-starting-skills-test.json") == OK,"Learned skills save")
  var restored = Sim.new()
  check(restored.load_from("user://npc-starting-skills-test.json").is_empty() and restored.actors[zombie.id].zombie_skills == zombie.zombie_skills,"Loading preserves learned NPC skills")
 print("NPC STARTING SKILLS CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
