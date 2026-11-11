extends Control

signal character_confirmed(occupation: String)
signal back_requested

const JOBS = [
 ["Private", 0, "Basic Firearms Training • Pistol + spare magazine", "private"],
 ["Medic", 0, "First Aid • Pistol + first aid kit", "medic-refined"],
 ["Scout", 0, "Free Running • Binoculars", "scout"],
 ["Doctor", 1, "Diagnosis • Two first aid kits", "doctor-refined"],
 ["NecroTech Lab Assistant", 1, "NecroTech Employment • DNA extractor", "lab-face-refined"],
 ["Consumer", 2, "Shopping • Baseball bat + mobile phone", "consumer-full-redraw"],
 ["Police Officer", 2, "Basic Firearms Training • Pistol, magazine, flak jacket + radio", "police-full-redraw"],
 ["Firefighter", 2, "Axe Proficiency • Fire axe + first aid kit", "firefighter-size-matched"],
 ["Corpse", 3, "Vigour Mortis • Begin as a zombie, without equipment", "corpse-refined"]
]
const GROUPS = ["MILITARY", "SCIENCE", "CIVILIAN", "UNDEAD"]
const XP_RATES = [
 "Military skills 75 XP • Science 150 XP • Civilian 100 XP",
 "Science skills 75 XP • Military 150 XP • Civilian 100 XP",
 "Human skills cost 100 XP",
 "Zombie skills cost 100 XP"
]
const ActorLayer = preload("res://scripts/character_creation/actor_layer.gd")
const C = preload("res://scripts/catalog.gd")
const ALTERNATE_SHEETS = ["private_female","medic_male","scout_male","doctor_male","necro_female","consumer_male","police_female","firefighter_male","corpse-refined"]
const ATLAS_PATH = "res://assets/character_creation/corrected/%s.png"
const ROOM_SIZE = Vector2(1672, 941)
const CINEMATIC_DURATION = 5.3
const HINT = "Hover to explore • Click to select • Right-click / Esc to cancel"
const FRONT_TO_BACK = [8, 4, 6, 7, 5, 1, 2, 0, 3]
const SHADOW_ORDER = [3, 0, 1, 2, 5, 7, 6, 4, 8]
# Each actor and its furniture share one atlas.
const PLACEMENTS = [
 Rect2(15,180,330,480), Rect2(324,186,310,345), Rect2(500,190,235,334),
 Rect2(615,28,320,400), Rect2(630,330,390,440), Rect2(975,126,391,391),
 Rect2(1265,300,270,400), Rect2(1415,160,220,440), Rect2(880,565,510,280)
]
const FOCUS = [Vector2(180,390),Vector2(427,347),Vector2(618,350),Vector2(835,248),Vector2(765,490),Vector2(1180,310),Vector2(1300,465),Vector2(1525,355),Vector2(1135,695)]
var actors: Array[ActorLayer] = []
var world: Node2D
var fade: ColorRect
var cinema_time: float = -1.0
var material_room: ShaderMaterial
var stage: Control
var title_label: Label
var hint: Label
var details: Label
var cancel: Button
var confirm: Button
var back: Button
var selected: int = -1
var hovered: int = -1
var active_group: int = -1
var lighting: Vector4 = Vector4.ZERO
var info_panel: ColorRect
var sexes: Array[String] = []
var sex_buttons: Array[Button] = []

func _ready() -> void:
 stage = Control.new()
 stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(stage)
 world = Node2D.new()
 stage.add_child(world)
 var room := TextureRect.new()
 room.texture = load("res://assets/character_creation/background.png")
 room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 room.mouse_filter = Control.MOUSE_FILTER_IGNORE
 room.size = ROOM_SIZE
 material_room = ShaderMaterial.new()
 material_room.shader = preload("res://scripts/character_creation/room.gdshader")
 room.material = material_room
 room.z_index = -4
 world.add_child(room)
 var shadows := Node2D.new()
 world.add_child(shadows)
 actors.resize(JOBS.size())
 for job in JOBS: sexes.append(C.occupation_sex(job[0]))
 for i in SHADOW_ORDER:
  var actor := ActorLayer.new()
  var sheet := load(ATLAS_PATH % JOBS[i][3]) as Texture2D
  actor.setup(sheet,PLACEMENTS[i],JOBS[i][1],i,shadows)
  world.add_child(actor)
  actors[i] = actor
  actor.z_index = [8,11,10,4,40,20,31,25,52][i]
 title_label = make_label(34,Color("e7dfb9"))
 title_label.text = "MALTON  /  CHOOSE YOUR SURVIVOR"
 hint = make_label(18,Color("bdbb9d"))
 info_panel = ColorRect.new()
 info_panel.color = Color(0.035,0.065,0.052,0.94)
 info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 stage.add_child(info_panel)
 details = make_label(22,Color("eee5c6"))
 details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 confirm = make_button("CONFIRM", confirm_selection)
 cancel = make_button("CANCEL", deselect_character)
 var sex_group := ButtonGroup.new()
 for sex in ["male","female"]:
  var caption := "Body Type 1" if sex == "male" else "Body Type 2"
  var button := make_button(caption,select_sex.bind(sex))
  button.name = "BodyType1" if sex == "male" else "BodyType2"
  button.tooltip_text = caption
  button.toggle_mode = true
  button.button_group = sex_group
  button.add_theme_font_size_override("font_size",22)
  var pressed_style := StyleBoxFlat.new()
  pressed_style.bg_color = Color("bba568")
  pressed_style.border_color = Color("f6e6b2")
  pressed_style.set_border_width_all(3)
  pressed_style.set_content_margin_all(12)
  button.add_theme_stylebox_override("pressed",pressed_style)
  button.add_theme_stylebox_override("hover_pressed",pressed_style)
  button.add_theme_color_override("font_pressed_color",Color("17251f"))
  button.add_theme_color_override("font_hover_pressed_color",Color("17251f"))
  sex_buttons.append(button)
 back = make_button("← BACK", back_requested.emit)
 fade = ColorRect.new()
 fade.color = Color.BLACK
 fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fade.modulate.a = 0.0
 add_child(fade)
 for control in stage.get_children():
  if control is Control: control.z_index = 100
 fade.z_index = 120
 resized.connect(layout)
 deselect_character()
 layout()

func make_label(font_size: int, tint: Color) -> Label:
 var label = Label.new()
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",tint)
 label.add_theme_color_override("font_shadow_color",Color.BLACK)
 label.add_theme_constant_override("shadow_offset_x",2)
 label.add_theme_constant_override("shadow_offset_y",2)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 stage.add_child(label)
 return label

func make_button(caption: String, action: Callable) -> Button:
 var button := Button.new()
 button.text = caption
 button.add_theme_font_size_override("font_size",24)
 var style = StyleBoxFlat.new()
 style.bg_color = Color("17251fee")
 style.border_color = Color("bba568")
 style.set_border_width_all(2)
 style.set_content_margin_all(12)
 button.add_theme_stylebox_override("normal",style)
 var hover_style = style.duplicate()
 hover_style.bg_color = Color("425242")
 button.add_theme_stylebox_override("hover",hover_style)
 button.pressed.connect(action)
 stage.add_child(button)
 return button

func layout() -> void:
 fade.size = size
 stage.scale = size/ROOM_SIZE
 title_label.position = Vector2(28,20)
 title_label.size = Vector2(900,110)
 hint.position = Vector2(32,137)
 hint.size = Vector2(1150,55)
 info_panel.position = Vector2(20,795)
 info_panel.size = Vector2(1120,135)
 details.position = Vector2(35,805)
 details.size = Vector2(870,130)
 cancel.position = Vector2(1150,835)
 cancel.size = Vector2(225,65)
 confirm.position = Vector2(1400,835)
 confirm.size = Vector2(235,65)
 for i in sex_buttons.size():
  sex_buttons[i].position = Vector2(930,805+i*62)
  sex_buttons[i].size = Vector2(195,52)
 back.position = Vector2(1400,28)
 back.size = Vector2(235,55)

func character_at(uv: Vector2) -> int:
 # Front-to-back alpha hit tests: transparent space never selects a character.
 var point := uv*ROOM_SIZE
 for i in FRONT_TO_BACK:
  if actors[i].contains_point(point): return i
 return -1

func group_at_position(uv: Vector2) -> int:
 if Rect2(0.53,0.61,0.31,0.29).has_point(uv): return 3
 if not Rect2(0,0.10,1,0.68).has_point(uv): return -1
 if uv.x < 0.415: return 0
 if uv.x < 0.62: return 1
 return 2

func select_character(index: int) -> void:
 if cinema_time >= 0.0: return
 if selected >= 0 and selected != index:
  select_sex(C.occupation_sex(JOBS[selected][0]))
 info_panel.show()
 details.show()
 selected = index
 var job: Array = JOBS[index]
 active_group = actors[index].group
 details.text = "%s  /  %s\n%s\n%s" % [job[0].to_upper(),GROUPS[active_group],job[2],XP_RATES[active_group]]
 confirm.show()
 cancel.show()
 for i in sex_buttons.size():
  sex_buttons[i].show()
  sex_buttons[i].set_pressed_no_signal(sexes[index] == ["male","female"][i])

func selected_sex() -> String:
 return sexes[selected] if selected >= 0 else ""

func select_sex(sex: String) -> void:
 if selected < 0 or cinema_time >= 0.0 or sex not in ["male","female"]: return
 if sexes[selected] != sex:
  sexes[selected] = sex
  # Corpse shares its bag/stretcher animation; identity still changes in-game.
  if selected != 8:
   var original := sex == C.occupation_sex(JOBS[selected][0])
   var key: String = JOBS[selected][3] if original else ALTERNATE_SHEETS[selected]
   actors[selected].set_sheet(load(ATLAS_PATH % key))
   actors[selected].tick(0.0,lighting[actors[selected].group])
 for i in sex_buttons.size():
  sex_buttons[i].set_pressed_no_signal(sex == ["male","female"][i])

func confirm_selection() -> void:
 if selected < 0 or cinema_time >= 0.0: return
 cinema_time = 0.0
 hovered = -1
 for control in [title_label,hint,details,info_panel,confirm,cancel,back]: control.hide()
 for button in sex_buttons: button.hide()

func deselect_character() -> void:
 cinema_time = -1.0
 if selected >= 0: select_sex(C.occupation_sex(JOBS[selected][0]))
 selected = -1
 hovered = -1
 world.scale = Vector2.ONE
 world.position = Vector2.ZERO
 fade.modulate.a = 0.0
 material_room.set_shader_parameter("exposure",1.0)
 for actor in actors:
  actor.modulate = Color.WHITE
  actor.reset()
 for control in [title_label,hint,back]: control.show()
 for control in [details,info_panel,confirm,cancel]: control.hide()
 for button in sex_buttons: button.hide()
 active_group = -1
 hint.text = HINT

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
  deselect_character()
  get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  deselect_character()
  get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
 if cinema_time >= 0.0: return
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  var uv: Vector2 = (stage.get_transform().affine_inverse()*event.position)/ROOM_SIZE
  if over_interface(uv): return
  var index := character_at(uv)
  if index >= 0:
   select_character(index)
   accept_event()

func update_hover(uv: Vector2) -> void:
 var over_ui := over_interface(uv)
 hovered = -1 if over_ui else character_at(uv)
 if selected >= 0:
  active_group = actors[selected].group
 elif hovered >= 0:
  active_group = actors[hovered].group
 else:
  active_group = -1 if over_ui else group_at_position(uv)

func _process(delta: float) -> void:
 if cinema_time < 0.0:
  update_hover(stage.get_local_mouse_position()/ROOM_SIZE)
  hint.text = "%s  ·  Click to select" % JOBS[hovered][0] if hovered >= 0 else HINT
 var target := Vector4.ZERO
 if active_group >= 0: target[active_group] = 1.0
 lighting = lighting.lerp(target,1.0-exp(-delta*7.0))
 material_room.set_shader_parameter("lights",lighting)
 for actor in actors:
  actor.tick(delta,lighting[actor.group])
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 else Control.CURSOR_ARROW
 if cinema_time >= 0.0: advance_cinematic(delta)

func over_interface(uv: Vector2) -> bool:
 for button in sex_buttons:
  if button.visible and button.get_rect().has_point(uv*ROOM_SIZE): return true
 if uv.y < 0.10: return true
 if selected >= 0 and uv.y > 0.84: return true
 return false

func advance_cinematic(delta: float) -> void:
 if cinema_time >= CINEMATIC_DURATION: return
 var previous_time := cinema_time
 cinema_time = minf(cinema_time+delta,CINEMATIC_DURATION)
 if previous_time < 0.45 and cinema_time >= 0.45:
  actors[selected].begin_choice()
 var t := smoothstep(0.0,4.0,cinema_time)
 var end_zoom := 1.65
 var final_offset: Vector2 = ROOM_SIZE/2.0-FOCUS[selected]*end_zoom
 final_offset = final_offset.clamp(ROOM_SIZE*(1.0-end_zoom),Vector2.ZERO)
 # Interpolate one affine transform: every point follows a straight screen path.
 world.scale = Vector2.ONE*lerpf(1.0,end_zoom,t)
 world.position = final_offset*t
 var surrounding := 1.0-smoothstep(4.05,4.88,cinema_time)
 material_room.set_shader_parameter("exposure",surrounding)
 for i in range(actors.size()):
  actors[i].modulate = Color.WHITE if i==selected else Color(surrounding,surrounding,surrounding,1)
 fade.modulate.a = smoothstep(4.88,5.15,cinema_time)
 if cinema_time >= CINEMATIC_DURATION:
  character_confirmed.emit(JOBS[selected][0])
