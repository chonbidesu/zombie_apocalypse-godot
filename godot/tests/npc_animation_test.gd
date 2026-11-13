extends "res://tests/interface_test.gd"

# Run the animation regressions without the full UI suite's rendered captures.
func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.initial_world_mode = "sandbox"
 scene.get_node("GameMusic").free()
 root.add_child(scene)
 scene.set_process(false)
 scene.sim.player().down = false
 scene.sim.set_pose(scene.sim.player(),"idle")
 npc_idle_animation(scene)
 location_transitions(scene)
 rise_transitions(scene)
 print("NPC ANIMATION CHECKS: ",checks," FAILURES: ",failures)
 scene.queue_free()
 await process_frame
 await process_frame
 quit(0 if failures == 0 else 1)
