extends Control

const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/interface.gd")
const Parallax = preload("res://scripts/title_parallax.gd")
const CharacterCreation = preload("res://scripts/character_creation/character_creation.gd")
const Intro = preload("res://scripts/intro.gd")
const TITLE_FONT = preload("res://assets/fonts/PixelifySans.ttf")
var save_path: String = Sim.SAVE_PATH
var title_page: Control
var parallax: Parallax
var heading: Label
var status: Label
var buttons: Array[TextureButton] = []
var music: AudioStreamPlayer
var creation: CharacterCreation
var intro: Intro

func _ready() -> void:
 DisplayServer.window_set_title("Zombie Apocalypse")
 title_page = Control.new()
 add_child(title_page)
 title_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 parallax = Parallax.new()
 title_page.add_child(parallax)
 parallax.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 heading = Label.new()
 heading.text = "Zombie Apocalypse"
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 heading.add_theme_font_override("font",TITLE_FONT)
 heading.add_theme_color_override("font_shadow_color",Color("242a25"))
 heading.add_theme_constant_override("shadow_offset_x",4)
 heading.add_theme_constant_override("shadow_offset_y",4)
 heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title_page.add_child(heading)
 make_button("New Game",preload("res://assets/title/menu_newgame.png"),open_creation)
 make_button("Load Game",preload("res://assets/title/menu_load.png"),load_game)
 make_button("Exit",preload("res://assets/title/menu_exit.png"),func(): get_tree().quit())
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
 music.stream = load("res://assets/music/summoning.mp3")
 music.volume_db = linear_to_db(0.3)
 music.finished.connect(music.play)
 add_child(music)
 music.play()
 resized.connect(layout)
 layout()
 buttons[0].grab_focus()

func make_button(caption: String, texture: Texture2D, action: Callable) -> void:
 var button := TextureButton.new()
 button.name = caption.replace(" ","")
 button.texture_normal = texture
 button.ignore_texture_size = true
 button.stretch_mode = TextureButton.STRETCH_SCALE
 button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 button.tooltip_text = caption
 button.focus_mode = Control.FOCUS_ALL
 button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 button.pressed.connect(action)
 button.mouse_entered.connect(func(): button.modulate = Color(1.2,1.2,1.2))
 button.mouse_exited.connect(func(): button.modulate = Color.WHITE if not button.has_focus() else Color(1.2,1.2,1.2))
 button.focus_entered.connect(func(): button.modulate = Color(1.2,1.2,1.2))
 button.focus_exited.connect(func(): button.modulate = Color.WHITE)
 title_page.add_child(button)
 buttons.append(button)

func layout() -> void:
 if not is_instance_valid(status): return
 var scale_factor := minf(size.x/1200.0,size.y/800.0)
 heading.position = Vector2(0,size.y*0.2-70*scale_factor)
 heading.size = Vector2(size.x,140*scale_factor)
 heading.add_theme_font_size_override("font_size",int(102*scale_factor))
 for i in range(buttons.size()):
  buttons[i].size = Vector2(232,102)*scale_factor
  buttons[i].position = Vector2((size.x-buttons[i].size.x)/2,size.y*float(i+2)/5.0)
 status.position = Vector2(size.x*0.1,size.y*0.335)
 status.size = Vector2(size.x*0.8,size.y*0.06)
 status.add_theme_font_size_override("font_size",int(20*scale_factor))

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
  var window := get_window()
  var fullscreen := window.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]
  window.mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN
  get_viewport().set_input_as_handled()

func open_creation() -> void:
 if is_instance_valid(creation): return
 status.text = ""
 creation = (load("res://character_creation.tscn") as PackedScene).instantiate() as CharacterCreation
 creation.back_requested.connect(show_title)
 creation.character_confirmed.connect(show_intro)
 title_page.hide()
 parallax.set_process(false)
 add_child(creation)

func show_title() -> void:
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

func show_intro(occupation: String) -> void:
 music.volume_db = linear_to_db(0.1)
 intro = (load("res://intro.tscn") as PackedScene).instantiate() as Intro
 intro.occupation = occupation
 intro.reduced_motion = creation.reduce_motion.button_pressed
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
 enter_game(simulation,"A new life in Malton. You are a %s." % occupation)

func load_game() -> void:
 var simulation := Sim.new()
 var error := simulation.load_from(save_path)
 if not error.is_empty():
  status.text = "No saved game yet. Choose New Game to begin." if not FileAccess.file_exists(save_path) else "Could not load game: " + error
  return
 enter_game(simulation,"Loaded your neighbourhood.")

func enter_game(simulation: Sim, message: String) -> void:
 var game := (load("res://main.tscn") as PackedScene).instantiate() as Game
 game.sim = simulation
 game.save_path = save_path
 game.notice = message
 if get_tree().change_scene_to_node(game) != OK:
  game.free()
  show_title()
  status.text = "Could not open the game."
