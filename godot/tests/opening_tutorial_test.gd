extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/interface.gd")
const C = preload("res://scripts/catalog.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var types := {"Private":["armoury"], "Medic":["hospital"], "Scout":["armoury"], "Doctor":["hospital"], "NecroTech Lab Assistant":["necrotech_lab"], "Consumer":["mall"], "Police Officer":["police_department"], "Firefighter":["fire_station"], "Corpse":["hospital"]}
 var last_sim: Sim
 for job in types:
  var sim := Sim.new()
  var error := sim.start(Sim.DEFAULT_SEED,job,{"mode":"malton", "survivors":0, "zombies":0})
  check(error.is_empty() and sim.current_block(sim.player()).type in types[job] and sim.player().inside, "%s starts inside their workplace" % job)
  last_sim = sim
 var game := (load("res://main.tscn") as PackedScene).instantiate() as Game
 game.sim = last_sim
 game.start_tutorial = true
 root.add_child(game)
 await process_frame
 check(game.modal == "tutorial" and game.tutorial_step == 0, "Tutorial starts paused on awakening")
 for i in range(5):
  game.tutorial_step = i
  game.refresh()
  check(is_instance_valid(game.overlay), "Tutorial page %d renders" % i)
 game.modal = ""
 game.refresh()
 check(game.sim.player().human == false, "Corpse starts as an undead player")
 var help_buttons = game.page.find_children("*", "Button", true, false).filter(func(node): return node.text == "Help")
 check(help_buttons.size() == 1, "Top bar has a Help button")
 help_buttons[0].pressed.emit()
 check(game.modal == "tutorial" and game.tutorial_step == 0 and not game.tutorial_opening, "Help reopens the field guide at the beginning")
 game.tutorial_step = 2
 game.refresh()
 var text = game.overlay.find_children("*", "Label", true, false).map(func(node): return node.text)
 check(text.any(func(value): return value.begins_with("THE HUNGER")), "Reopened guide uses the current undead form")
 game.sim.player().human = true
 game.refresh()
 text = game.overlay.find_children("*", "Label", true, false).map(func(node): return node.text)
 check(text.any(func(value): return value.begins_with("SUPPLIES AND PEOPLE")), "Reopened guide adapts to the current human form")
 game.open_modal("help")
 check(game.tutorial_step == 0, "Reopening Help resets the guide page")
 for human in [true, false]:
  game.sim.player().human = human
  game.open_modal("skills")
  var labels = game.overlay.find_children("*", "Label", true, false).map(func(node): return node.text)
  var side = "human" if human else "zombie"
  for key in C.SKILLS:
   var skill: Dictionary = C.SKILLS[key]
   var found = labels.any(func(value): return value == skill.name or value.begins_with(skill.name + " / "))
   check(found == (skill.side == side), "%s skills screen visibility for %s" % [side, skill.name])
 game.open_modal("help")
 var appendix_buttons = game.overlay.find_children("*", "Button", true, false).filter(func(node): return node.text == "Appendix: Skills")
 check(appendix_buttons.size() == 1, "Field Guide offers the appendix")
 appendix_buttons[0].pressed.emit()
 for side in ["human", "zombie"]:
  var tabs = game.overlay.find_children("*", "Button", true, false).filter(func(node): return node.text == "%s skills" % side.capitalize())
  check(tabs.size() == 1, "%s appendix tab exists" % side)
  tabs[0].pressed.emit()
  var appendix = game.overlay.get_node("SkillAppendix") as RichTextLabel
  for key in C.SKILLS:
   var skill: Dictionary = C.SKILLS[key]
   if skill.side == side:
    check(appendix.text.contains(skill.name + "\n" + skill.description), "Appendix includes %s and its description" % skill.name)
 game.queue_free()
 print("Opening tutorial: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
