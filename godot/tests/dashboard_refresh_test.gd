extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const Game = preload("res://scripts/interface.gd")
const GameScene = preload("res://main.tscn")

var _checks: int
var _failures: int


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Game = GameScene.instantiate() as Game
	game.initial_world_mode = "sandbox"
	game.get_node("GameMusic").free()
	root.add_child(game)
	game.set_process(false)
	var player: Dictionary = game.sim.player()
	var actor: Dictionary = game.sim.actors[1]
	actor.x = player.x; actor.y = player.y; actor.inside = player.inside; actor.down = false
	game.sim.reindex()
	var nearby: Dictionary = game.sim.block_at(player.x + 1, player.y)
	nearby.generator = false
	game.refresh()
	var clock: Label = game.clock_label
	var energy: Label = game.energy_label
	var bar: Panel = game.energy_bar
	var minimap: Control = game.local_map
	var environment: TextureRect = game.page.get_node("EnvironmentArt")
	var description: RichTextLabel = game.page.get_node("LocationDescription")
	var actor_button: Button = game.page.get_node("SceneActors/Actor_1")
	var sprite: TextureRect = game.actor_buttons[0].node
	var inventory_item: Button = game.page.get_node("InventoryItem_%d" % player.inventory[0].uid)
	var action: Button = game.action_controls[0].node

	game.sim.minute += 1
	game.sim.clock_step += Catalog.CLOCK_STEPS_PER_MINUTE
	player.ap = 37
	game._refresh_dashboard()
	_check(game.clock_label == clock and clock.text == game.sim.time_text(), "Clock text updates in place.")
	_check(game.energy_label == energy and energy.text == "37 / 50 AP" and game.energy_bar == bar
		and is_equal_approx(bar.size.x, 334.0 * 37.0 / 50.0), "AP text and bar update in place.")
	_check(game.local_map == minimap and game.page.get_node("EnvironmentArt") == environment
		and game.actor_buttons[0].node == sprite and inventory_item.is_inside_tree() and action.is_inside_tree(),
		"Clock and AP changes keep the minimap, art, actors, inventory, and actions.")

	var map_art: TextureRect = minimap.get_node("Plot_%d/MapArt" % nearby.id)
	var intact: Texture2D = map_art.texture
	nearby.generator = true
	nearby.generator_hp = Catalog.GENERATOR_HP
	nearby.fuel_until = game.sim.minute + 1
	game._refresh_dashboard()
	_check(game.local_map == minimap and map_art.texture != intact and map_art.material != null,
		"Power changes update the existing map art.")
	game.sim.minute += 1
	game.sim.clock_step += Catalog.CLOCK_STEPS_PER_MINUTE
	game._refresh_dashboard()
	_check(map_art.texture == intact and map_art.material == null, "Fuel expiration updates the map without rebuilding it.")

	actor.speech = "We should stay together."
	actor.speech_until = game.sim.now() + 1.0
	game._refresh_dashboard()
	_check(game.page.get_node("SceneActors/Actor_1") == actor_button and game.page.has_node("SceneActors/Speech_1")
		and game.local_map == minimap and inventory_item.is_inside_tree(), "Speech updates without replacing other sections.")
	game.sim.clock_step += Catalog.CLOCK_STEPS_PER_MINUTE
	game.sim.minute += 1
	game._refresh_dashboard()
	_check(not game.page.has_node("SceneActors/Speech_1"), "Expired speech is removed on the periodic update.")
	actor.x += 1
	game.sim.reindex()
	game._refresh_dashboard()
	_check(game.page.get_node("LocationDescription") == description and description.get_parsed_text() == game.sim.location_description(player),
		"Changing occupants updates the existing location description.")
	_check(not game.page.has_node("SceneActors/Actor_1"), "An NPC departure updates the scene.")

	action = game.action_controls[0].node
	game.sim.give_item(player, "newspaper")
	var paper: Dictionary = game.sim.item_kind(player, "newspaper")
	game._refresh_dashboard()
	_check(game.page.has_node("InventoryItem_%d" % paper.uid) and game.local_map == minimap
		and game.page.get_node("EnvironmentArt") == environment and action.is_inside_tree(),
		"Inventory changes update their controls and retain the map, location, and actions.")
	game.sim.give_item(player, "gps_unit")
	game.sim.give_item(player, "map")
	game._refresh_dashboard()
	_check(game.action_controls.any(func(entry: Dictionary) -> bool: return entry.command == "view_map")
		and game.local_map == minimap and game.page.get_node("EnvironmentArt") == environment,
		"Newly eligible actions update without rebuilding the map or location.")
	var paper_button: Button = game.page.get_node("InventoryItem_%d" % paper.uid)
	game.sim.current_block(player).doors = false
	game._refresh_dashboard()
	_check(game.action_controls.any(func(entry: Dictionary) -> bool: return entry.command == "close")
		and paper_button.is_inside_tree(), "Action eligibility changes keep unrelated inventory controls.")

	game.begin_sleep()
	energy = game.energy_label
	var darkness: Control = game.page.get_node("DarkEnvironment")
	player.ap = 40
	game._refresh_dashboard()
	_check(game.energy_label == energy and energy.text == "40 / 50 AP"
		and game.page.get_node("DarkEnvironment") == darkness, "Sleep updates AP while retaining the blackout.")
	game.open_modal("settings")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	_check(game.sim.sleeping and game.page.get_node("DarkEnvironment") == darkness and not minimap.is_visible_in_tree(),
		"Opening and closing settings while asleep keeps the original blackout and hidden map.")
	actor.x = player.x
	game.sim.reindex()
	nearby.fuel_until = game.sim.minute + 2
	game.rest_button.pressed.emit()
	_check(game.local_map == minimap and map_art.material != null and map_art.is_visible_in_tree()
		and game.page.has_node("SceneActors/Actor_1") and game.page.get_node("LocationDescription") == description
		and description.get_parsed_text() == game.sim.location_description(player),
		"Wake restores the same map and description with current power and occupants.")
	game.queue_free()
	await process_frame
	print("DASHBOARD REFRESH CHECKS: %d FAILURES: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
