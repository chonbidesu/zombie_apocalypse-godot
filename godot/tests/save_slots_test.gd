extends SceneTree
const Slots = preload("res://scripts/save_slots.gd")
const Sim = preload("res://scripts/simulation.gd")
func _initialize() -> void:
 call_deferred("run_tests")
func run_tests() -> void:
 var base = "user://slot-feature-test.json"
 for i in range(3):
  var path = Slots.slot_path(base,i)
  if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
  assert(Slots.slot_description(path) == "Empty")
 var sim = Sim.new()
 assert(sim.start(42,"Doctor",{"mode":"legacy"}).is_empty())
 sim.player().first = "Alex"
 sim.player().last = "Smith"
 sim.player().adjective = "Ghastly"
 assert(sim.save_to(Slots.slot_path(base,0)) == OK)
 sim.player().human = false
 assert(sim.save_to(Slots.slot_path(base,1)) == OK)
 assert(Slots.slot_description(Slots.slot_path(base,0)).contains("Alex Smith  ·  Doctor"))
 assert(Slots.slot_description(Slots.slot_path(base,1)).contains("Ghastly Alex  ·  Doctor"))
 var loaded = Sim.new()
 assert(loaded.load_from(Slots.slot_path(base,1)).is_empty())
 assert(not loaded.player().human and loaded.player().first == "Alex")
 var chooser = Slots.new()
 chooser.base_path = base
 root.add_child(chooser)
 assert(chooser.content.get_child_count() == 5)
 assert(chooser.content.get_child(3).disabled)
 chooser.queue_free()
 for i in range(3):
  var path = Slots.slot_path(base,i)
  if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
 print("Save slot tests passed")
 quit()

