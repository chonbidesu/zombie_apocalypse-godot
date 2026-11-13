extends Control

const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/interface.gd")
const Parallax = preload("res://scripts/title_parallax.gd")
const CharacterCreation = preload("res://scripts/character_creation/character_creation.gd")
const Intro = preload("res://scripts/intro.gd")
const Naming = preload("res://scripts/naming_screen.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const Attribution = preload("res://scripts/attribution.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
var attribution: Attribution
var slot_chooser: Control
var settings_menu: SettingsMenu
var previous_title_focus: Control
const TITLE_FONT = preload("res://assets/fonts/PixelifySans.ttf")
var save_path: String = Sim.SAVE_PATH
var title_page: Control
var parallax: Parallax
var heading: Label
var status: Label
var buttons: Array[Button] = []
var eyebrow: Label
var music: AudioStreamPlayer
var creation: CharacterCreation
var intro: Intro
var naming: Naming
var chosen_occupation := ""
var chosen_sex := ""
var chosen_identity := {}

func _ready() -> void:
 DisplayServer.window_set_title("Malton Reborn")
 title_page = Control.new()
 add_child(title_page)
 title_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 parallax = Parallax.new()
 title_page.add_child(parallax)
 parallax.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade := ColorRect.new()
 shade.color = Color(0.025,0.035,0.035,0.52)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title_page.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 eyebrow = Label.new()
 eyebrow.text = "THE CITY THAT REFUSES TO DIE"
 eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 eyebrow.add_theme_font_override("font",TITLE_FONT)
 eyebrow.add_theme_color_override("font_color",Color("d2bd8b"))
 eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title_page.add_child(eyebrow)
 heading = Label.new()
 heading.text = "MALTON REBORN"
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 heading.add_theme_font_override("font",TITLE_FONT)
 heading.add_theme_color_override("font_shadow_color",Color("242a25"))
 heading.add_theme_constant_override("shadow_offset_x",4)
 heading.add_theme_constant_override("shadow_offset_y",4)
 heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title_page.add_child(heading)
 make_button("New Game",open_attribution)
 make_button("Load Game",load_game)
 make_button("Settings",_open_settings)
 make_button("Quit",func(): get_tree().quit())
 status = Label.new()
 status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status.add_theme_font_override("font",TITLE_FONT)
 status.add_theme_color_override("font_color",Color("fff0cb"))
 status.add_theme_color_override("font_shadow_color",Color.BLACK)
 status.add_theme_constant_override("shadow_offset_y",2)
 status.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title_page.add_child(status)
 music = AudioStreamPlayer.new()
 music.bus = &"Music"
 music.stream = load("res://assets/music/summoning.mp3")
 music.volume_db = linear_to_db(0.3)
 music.finished.connect(music.play)
 add_child(music)
 music.play()
 resized.connect(layout)
 layout()
 buttons[0].grab_focus()

func menu_style(background: Color, border: Color) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = background
 style.border_color = border
 style.set_border_width_all(1)
 style.set_corner_radius_all(3)
 return style

func make_button(caption: String, action: Callable) -> void:
 var button := Button.new()
 button.name = caption.replace(" ","")
 button.text = caption.to_upper()
 button.add_theme_font_override("font",TITLE_FONT)
 button.add_theme_color_override("font_color",Color("e8e3d2"))
 button.add_theme_color_override("font_hover_color",Color("fff4d3"))
 button.add_theme_color_override("font_focus_color",Color("fff4d3"))
 button.add_theme_color_override("font_pressed_color",Color.WHITE)
 button.add_theme_stylebox_override("normal",menu_style(Color(0.05,0.07,0.065,0.83),Color(0.65,0.63,0.51,0.48)))
 button.add_theme_stylebox_override("hover",menu_style(Color(0.19,0.22,0.18,0.94),Color("d2bd8b")))
 button.add_theme_stylebox_override("pressed",menu_style(Color(0.28,0.29,0.22,0.98),Color("e6d2a1")))
 var focus := StyleBoxFlat.new()
 focus.bg_color = Color.TRANSPARENT
 focus.border_color = Color("e6d2a1")
 focus.set_border_width_all(2)
 focus.set_corner_radius_all(3)
 button.add_theme_stylebox_override("focus",focus)
 button.focus_mode = Control.FOCUS_ALL
 button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 button.pressed.connect(action)
 title_page.add_child(button)
 buttons.append(button)

func layout() -> void:
 if not is_instance_valid(status): return
 var scale_factor := minf(size.x/1200.0,size.y/800.0)
 eyebrow.position = Vector2(0,size.y*0.17)
 eyebrow.size = Vector2(size.x,28*scale_factor)
 eyebrow.add_theme_font_size_override("font_size",int(16*scale_factor))
 heading.position = Vector2(0,size.y*0.21)
 heading.size = Vector2(size.x,100*scale_factor)
 heading.add_theme_font_size_override("font_size",int(76*scale_factor))
 for i in range(buttons.size()):
  buttons[i].size = Vector2(300,52)*scale_factor
  buttons[i].position = Vector2((size.x-buttons[i].size.x)/2,size.y*0.50+i*65*scale_factor)
  buttons[i].add_theme_font_size_override("font_size",int(23*scale_factor))
 status.position = Vector2(size.x*0.1,size.y*0.50+(buttons.size()*65+10)*scale_factor)
 status.size = Vector2(size.x*0.8,60*scale_factor)
 status.add_theme_font_size_override("font_size",int(18*scale_factor))

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_F11:
  get_node("/root/PlayerSettings").toggle_fullscreen()
  get_viewport().set_input_as_handled()
 elif event.keycode == KEY_ESCAPE and title_page.visible and not is_instance_valid(slot_chooser):
  if is_instance_valid(settings_menu): _close_settings()
  else: _open_settings()
  get_viewport().set_input_as_handled()

func _open_settings() -> void:
 if is_instance_valid(settings_menu) or is_instance_valid(slot_chooser): return
 previous_title_focus = get_viewport().gui_get_focus_owner()
 title_page.process_mode = Node.PROCESS_MODE_DISABLED
 settings_menu = SettingsMenu.new()
 settings_menu.name = "SettingsMenu"
 settings_menu.closed.connect(_close_settings)
 add_child(settings_menu)

func _close_settings() -> void:
 remove_child(settings_menu)
 settings_menu.queue_free()
 settings_menu = null
 title_page.process_mode = Node.PROCESS_MODE_INHERIT
 if is_instance_valid(previous_title_focus): previous_title_focus.grab_focus()

func open_attribution() -> void:
 if is_instance_valid(attribution) or is_instance_valid(creation): return
 status.text = ""
 title_page.hide()
 parallax.set_process(false)
 attribution = Attribution.new()
 attribution.finished.connect(open_creation)
 add_child(attribution)

func open_creation() -> void:
 if is_instance_valid(creation): return
 if is_instance_valid(attribution):
  attribution.queue_free()
  attribution = null
 chosen_sex = ""
 status.text = ""
 creation = (load("res://character_creation.tscn") as PackedScene).instantiate() as CharacterCreation
 creation.back_requested.connect(show_title)
 creation.character_confirmed.connect(show_naming)
 title_page.hide()
 parallax.set_process(false)
 add_child(creation)

func show_title() -> void:
 if is_instance_valid(attribution): attribution.queue_free()
 attribution = null
 if is_instance_valid(naming): naming.queue_free()
 naming = null
 if is_instance_valid(intro):
  intro.queue_free()
 intro = null
 if is_instance_valid(creation):
  remove_child(creation)
  creation.queue_free()
 creation = null
 title_page.show()
 music.volume_db = linear_to_db(0.3)
 parallax.set_process(true)
 buttons[0].grab_focus()

func show_naming(occupation: String) -> void:
 chosen_occupation = occupation
 chosen_sex = creation.selected_sex()
 creation.hide()
 creation.process_mode = Node.PROCESS_MODE_DISABLED
 naming = Naming.new()
 naming.confirmed.connect(show_intro)
 naming.back_requested.connect(back_to_creation)
 add_child(naming)

func back_to_creation() -> void:
 naming.queue_free()
 naming = null
 creation.process_mode = Node.PROCESS_MODE_INHERIT
 creation.deselect_character()
 creation.show()

func show_intro(identity: Dictionary) -> void:
 chosen_identity = identity
 naming.queue_free()
 naming = null
 music.volume_db = linear_to_db(0.1)
 intro = (load("res://intro.tscn") as PackedScene).instantiate() as Intro
 intro.occupation = chosen_occupation
 intro.finished.connect(start_new_game)
 creation.queue_free()
 creation = null
 add_child(intro)

func start_new_game(occupation: String) -> void:
 var simulation := Sim.new()
 var error := simulation.start(Sim.DEFAULT_SEED,occupation,{"mode":"malton"})
 if not error.is_empty():
  show_title()
  status.text = error
  return
 simulation.player().merge(chosen_identity, true)
 if chosen_sex in ["male","female"]: simulation.player().sex = chosen_sex
 simulation.ensure_unique_npc_names()
 enter_game(simulation,"A new life in Malton. You are a %s." % occupation,true)

func load_game() -> void:
 if is_instance_valid(slot_chooser): return
 slot_chooser = SaveSlots.new()
 slot_chooser.base_path = save_path
 slot_chooser.closed.connect(_close_slots)
 slot_chooser.selected.connect(_load_slot)
 add_child(slot_chooser)

func _close_slots() -> void:
 slot_chooser.queue_free()
 slot_chooser = null

func _load_slot(path: String) -> void:
 var simulation := Sim.new()
 var error := simulation.load_from(path)
 if not error.is_empty():
  _close_slots()
  status.text = "Could not load game: " + error
  return
 _close_slots()
 enter_game(simulation,"Loaded your neighbourhood.")

func enter_game(simulation: Sim, message: String, new_game: bool = false) -> void:
 var game := (load("res://main.tscn") as PackedScene).instantiate() as Game
 game.sim = simulation
 game.save_path = save_path
 game.notice = message
 game.start_tutorial = new_game
 if get_tree().change_scene_to_node(game) != OK:
  game.free()
  show_title()
  status.text = "Could not open the game."
