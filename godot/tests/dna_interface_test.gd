extends SceneTree
const GameScene = preload("res://main.tscn")
const Sim = preload("res://scripts/simulation.gd")
var checks: int
var failures: int

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sim := Sim.new()
	sim.start(991)
	for a: Dictionary in sim.actors:
		a.dormant = true
		a.down = true
	var p: Dictionary = sim.player()
	p.x = 4
	p.y = 4
	p.inside = false
	p.down = false
	p.human_skills = ["necro_employment"]
	p.inventory.clear()
	sim.give_item(p, "dna_extractor")
	for id: int in [1, 2]:
		var a: Dictionary = sim.actors[id]
		a.x = 4
		a.y = 4
		a.inside = false
		a.down = false
		a.human = false
		a.hp = 50
		a.human_skills = ["first_aid"]
		a.zombie_skills = ["vigour_mortis"]
		a.tagged_until = 0
		a.tagged_skills.clear()
	sim.reindex()
	sim._reset_npc_runtime()
	var game = GameScene.instantiate()
	game.get_node("GameMusic").free()
	game.sim = sim
	game.initial_world_mode = "sandbox"
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.refresh()
	_check(game.selected_actor == -1 and game.action_controls.any(func(row): return row.command == "extract" and not row.node.disabled),
		"DNA action is available without selecting a zombie.")
	game._item_menu(sim.item_kind(p, "dna_extractor"))
	var menu: PopupMenu
	for node in game.get_children():
		if node is PopupMenu: menu = node
	var use_id: int = -1
	if menu != null:
		for index: int in range(menu.item_count):
			if menu.get_item_text(index).begins_with("Use "):
				use_id = menu.get_item_id(index)
				_check(not menu.is_item_disabled(index), "Inventory scanner use automatically finds a valid target.")
	if use_id >= 0: menu.id_pressed.emit(use_id)
	if menu != null: menu.hide()
	_check(p.xp == 4 and sim.actors[1].tagged_until > sim.minute, "Inventory Use performs the automatic sample.")
	var event: Dictionary = sim.messages.back()
	_check(game.log_view.text.contains("[url=dna:%d]View sampled skills[/url]" % event.id), "The activity feed contains the clickable sample report.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var output: String = ProjectSettings.globalize_path("res://.runtime/dna-medical/dna-chat.png")
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_root().get_texture().get_image().save_png(output)
	# Reports must remain historical after movement, death and newly bought skills.
	sim.actors[1].x = 8
	sim.actors[1].down = true
	sim.actors[1].zombie_skills.append("death_grip")
	sim.actors[1].tagged_skills.clear()
	sim.reindex()
	var before: Array = [sim.clock_step, p.ap]
	game.log_view.meta_clicked.emit("dna:%d" % event.id)
	_check([sim.clock_step, p.ap] == before, "Opening a recorded sample consumes neither time nor AP.")
	_check(game.modal == "dna" and game.overlay.get_node_or_null("DnaSkillReport") != null,
		"Clicking the report opens the sampled skill list.")
	var labels: String = _labels(game.overlay)
	_check(labels.contains("HUMAN SKILLS") and labels.contains("First Aid") and labels.contains("Vigour Mortis")
		and not labels.contains("Death Grip"), "The report lists both captured trees without leaking later skills.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var output: String = ProjectSettings.globalize_path("res://.runtime/dna-medical/dna-report.png")
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_root().get_texture().get_image().save_png(output)
		print("DNA report screenshot: ", output)
	game.modal = ""
	game.refresh()
	p.busy_until = sim.now()
	game.selected_actor = 1
	game.dispatch("extract", 1)
	_check(sim.actors[2].tagged_until > sim.minute and p.xp == 8,
		"A stale selection does not prevent automatically scanning the next local zombie.")
	game.open_modal("history")
	var history: RichTextLabel
	for node in game.overlay.get_children():
		if node is RichTextLabel and node.text.contains("View sampled skills"): history = node
	_check(history != null, "History retains the sample link.")
	if history != null: history.meta_clicked.emit("dna:%d" % event.id)
	_check(game.modal == "dna" and _labels(game.overlay).contains("First Aid"), "History links reopen the original sample.")
	game.queue_free()
	await process_frame
	print("DNA INTERFACE CHECKS: %d FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _labels(node: Node) -> String:
	var value: String = node.text if node is Label else ""
	for child in node.get_children(): value += "\n" + _labels(child)
	return value

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
