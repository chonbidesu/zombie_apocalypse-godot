extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.initial_world_mode = "sandbox"
 root.add_child(scene)
 await process_frame
 scene.set_process(false)
 var sim = scene.sim
 var p = sim.player()
 var attacker = sim.actors[1]
 p.human = true; p.down = false; p.hp = 50; p.infected = false
 attacker.human = false; attacker.down = false
 attacker.x = p.x; attacker.y = p.y; attacker.inside = p.inside
 attacker.equipped = -1
 sim.reindex()
 var effects: Array[String] = []
 sim.sound_requested.connect(func(effect): effects.append(effect))
 for i in range(30):
  sim.execute(attacker,"attack",0,{"unarmed":true})
  if not scene.damage_overlay.splashes.is_empty(): break
 check(scene.damage_overlay.splashes.size() == 1 and scene.damage_overlay.splashes[0].human,"A successful attack on a living player creates living blood")
 check(effects.has("break"),"A nearby successful melee hit requests the legacy impact effect")
 check(scene.damage_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and scene.damage_overlay.splashes[0].spots.size() >= 5,"Blood has multiple varied spots and never intercepts input")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://damage-feedback-preview.png")
 scene.damage_overlay._process(5.0)
 check(scene.damage_overlay.splashes.is_empty(),"Blood fades away after its lifetime")
 p.human = false; p.down = false; p.hp = 1; p.infected = false
 attacker.human = true
 for i in range(30):
  sim.execute(attacker,"attack",0,{"unarmed":true})
  if p.down: break
 check(p.down and scene.damage_overlay.splashes.size() == 1 and not scene.damage_overlay.splashes[0].human,"A lethal undead hit retains the undead blood colour")
 check(effects.has("zombie_death"),"An undead death requests its original death effect")
 scene.damage_overlay.splashes.clear()
 p.human = true; p.down = false; p.hp = 10; p.infected = true; p.ap = 50
 sim.execute(p,"wait")
 check(scene.damage_overlay.splashes.size() == 1 and scene.damage_overlay.splashes[0].human,"Infection damage also creates blood")
 effects.clear()
 p.infected = false
 sim.give_item(p,"pistol")
 p.equipped = sim.item_kind(p,"pistol").uid
 attacker.human = false; attacker.down = false; attacker.hp = 50
 sim.execute(p,"attack",attacker.id)
 check(effects.has("gun_shot"),"A fired pistol requests the original gunshot even if it misses")
 check(load("res://assets/sfx/gun_shot.mp3") is AudioStream and load("res://assets/sfx/search/search_1.wav") is AudioStream,"Imported legacy effects load as audio streams")
 print("DAMAGE FEEDBACK CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
