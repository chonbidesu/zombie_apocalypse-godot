extends SceneTree

const GameScene = preload("res://main.tscn")
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 var game = GameScene.instantiate()
 game.sim = Sim.new()
 check(game.sim.start(44,"Volunteer",{"mode":"malton","survivors":2,"zombies":2}).is_empty(),"Load fort geography")
 game.get_node("GameMusic").free()
 root.add_child(game)
 game.set_process(false)
 var player: Dictionary = game.sim.player()
 for fort in ["Fort Creedy","Fort Perryn"]:
  var gate: Dictionary = game.sim.fort_gatehouse(fort)
  var approach := Vector2i(1,0) if fort == "Fort Creedy" else Vector2i(0,1)
  player.x = gate.x + approach.x
  player.y = gate.y + approach.y
  player.inside = false
  player.ap = 50
  player.busy_until = game.sim.now()
  game.sim.reindex()
  game.refresh()
  var tile: Button = game.local_map.get_node("MapTile_%d" % gate.id)
  var motion := InputEventMouseMotion.new()
  motion.position = tile.get_global_rect().get_center()
  root.push_input(motion,true)
  await process_frame
  check(root.gui_get_hovered_control() == tile,"Hover gatehouse before moving: " + fort)
  game.refresh()
  check(game.local_map.get_node("MapTile_%d" % gate.id) == tile,"Stationary refresh retains hovered map tile: " + fort)
  tile.pressed.emit()
  check(player.x == gate.x and player.y == gate.y,"Map click reaches gatehouse: " + fort)
  await process_frame
  var complete := true
  for dy in range(-1,2):
   for dx in range(-1,2):
    var block: Dictionary = game.sim.block_at(player.x+dx,player.y+dy)
    var current := game.local_map.get_node_or_null("MapTile_%d" % block.id) as Button
    check(current != null,"Recentered map keeps named tile %d: %s" % [block.id,fort])
    if current == null: complete = false
    else:
     check(current.position == Vector2((dx+1)*106,(dy+1)*106),"Map tile matches recentered position")
  if complete:
   game._refresh_dashboard()
   var center: Button = game.local_map.get_node("MapTile_%d" % gate.id)
   check(center.disabled and center.tooltip_text.contains("Only fort entrance"),"Gatehouse tile refreshes its state and tooltip")
 game.queue_free()
 await process_frame
 print("MINIMAP MOVEMENT CHECKS: %d FAILURES: %d" % [checks,failures])
 quit(0 if failures == 0 else 1)
