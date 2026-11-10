extends Control

signal confirmed(identity: Dictionary)
signal back_requested

const TERMINAL = preload("res://assets/terminal/necrotech-terminal.png")
const DUST = preload("res://assets/terminal/screen-dust.png")
const ASCII_FRAME = preload("res://assets/terminal/record-ascii-frame.png")
const GLASS = preload("res://shaders/terminal_glass.gdshader")
const CHASSIS_SHADER = preload("res://shaders/terminal_chassis.gdshader")
const BLUE = Color("72aaff")
const DIM_BLUE = Color("5183c6")
const PROMPTS = ["Enter your first name:", "Enter your last name:", "Enter your corpse descriptor:"]
const AUDIO = ["naming 1.mp3", "naming 2.mp3", "naming 3.mp3", "naming 4.mp3"]
const LEGACY_AUDIO = ["Malton name first.mp3", "Malton name last.mp3", "Malton name corpse.mp3"]
const SCREEN = Rect2(220, 130, 1096, 674)

var fields: Array[LineEdit] = []
var rows: Array[Control] = []
var preview: Label
var error_label: Label
var narration: AudioStreamPlayer
var stage: Control
var heading: Label
var progress: Label
var footer: Label
var record_frame: TextureRect
var proceed: Button
var back: Button
var effects: ColorRect
var font: SystemFont
var step := 0
var reviewing := false
var reduced_motion := false
var accepted := false

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 font = SystemFont.new()
 font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
 var background := ColorRect.new()
 background.color = Color.BLACK
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 stage = Control.new()
 stage.name = "TerminalStage"
 stage.size = Vector2(1536, 1024)
 add_child(stage)
 var chassis := _texture(TERMINAL, Rect2(0, 0, 1536, 1024), "Chassis")
 var chassis_material := ShaderMaterial.new()
 chassis_material.shader = CHASSIS_SHADER
 chassis.material = chassis_material
 record_frame = _texture(ASCII_FRAME, Rect2(230, 152, 1076, 630), "RecordArt")
 record_frame.modulate.a = 0.45
 record_frame.hide()
 heading = _label("NECROTECH / SUBJECT INTAKE", 28, BLUE, Rect2(282, 185, 970, 40))
 progress = _label("", 18, DIM_BLUE, Rect2(284, 231, 960, 28))
 narration = AudioStreamPlayer.new()
 add_child(narration)
 for i in range(3):
  var row := Control.new()
  row.position = Vector2(284, 292 + i * 119)
  row.size = Vector2(960, 104)
  stage.add_child(row)
  rows.append(row)
  var prompt := _label(PROMPTS[i], 25, BLUE, Rect2(0, 0, 960, 36), row)
  prompt.name = "Prompt"
  _label("Z:\\>", 26, BLUE, Rect2(0, 42, 64, 42), row)
  var field := LineEdit.new()
  field.name = ["FirstName", "LastName", "CorpseAdjective"][i]
  field.position = Vector2(72, 40)
  field.size = Vector2(880, 46)
  field.max_length = 32
  field.placeholder_text = "_"
  field.caret_blink = true
  field.caret_blink_interval = 0.55
  field.caret_mid_grapheme = false
  field.keep_editing_on_text_submit = true
  field.add_theme_font_override("font", font)
  field.add_theme_font_size_override("font_size", 26)
  field.add_theme_color_override("font_color", BLUE)
  field.add_theme_color_override("font_uneditable_color", DIM_BLUE)
  field.add_theme_color_override("caret_color", BLUE)
  field.add_theme_color_override("selection_color", Color("214674"))
  field.add_theme_constant_override("caret_width", 14)
  for style_name in ["normal", "focus", "read_only"]:
   field.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
  field.text_changed.connect(_update_preview)
  field.text_submitted.connect(_next_field.bind(i))
  row.add_child(field)
  fields.append(field)
 preview = _label("", 27, BLUE, Rect2(340, 410, 856, 170))
 preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 preview.hide()
 error_label = _label("", 20, BLUE, Rect2(284, 651, 960, 30))
 back = _button("[ESC] BACK", Rect2(284, 695, 270, 44), _back)
 proceed = _button("[ENTER] NEXT", Rect2(870, 695, 370, 44), _advance)
 proceed.name = "Continue"
 footer = _label("LOCAL RECORD / AWAITING INPUT", 16, DIM_BLUE, Rect2(284, 757, 960, 25))
 var dust := _texture(DUST, SCREEN, "ScreenDust")
 dust.modulate.a = 0.55
 effects = ColorRect.new()
 effects.name = "GlassEffects"
 effects.position = SCREEN.position
 effects.size = SCREEN.size
 effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var material := ShaderMaterial.new()
 material.shader = GLASS
 material.set_shader_parameter("reduced_motion", reduced_motion)
 effects.material = material
 stage.add_child(effects)
 resized.connect(_layout)
 _layout()
 _show_step(0)

func _texture(texture: Texture2D, rect: Rect2, node_name: String) -> TextureRect:
 var image := TextureRect.new()
 image.name = node_name
 image.texture = texture
 image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image.position = rect.position
 image.size = rect.size
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 stage.add_child(image)
 return image

func _label(text: String, font_size: int, color: Color, rect: Rect2, parent: Control = null) -> Label:
 var label := Label.new()
 label.text = text
 label.position = rect.position
 label.size = rect.size
 label.add_theme_font_override("font", font)
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", color)
 label.add_theme_color_override("font_shadow_color", Color(0.15, 0.4, 1.0, 0.25))
 label.add_theme_constant_override("shadow_outline_size", 3)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 (parent if parent != null else stage).add_child(label)
 return label

func _button(text: String, rect: Rect2, action: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.position = rect.position
 button.size = rect.size
 button.add_theme_font_override("font", font)
 button.add_theme_font_size_override("font_size", 22)
 for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
  button.add_theme_color_override(state, BLUE)
 button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
 var focus := StyleBoxFlat.new()
 focus.bg_color = Color(0.1, 0.25, 0.5, 0.25)
 focus.border_color = DIM_BLUE
 focus.set_border_width_all(1)
 for state in ["hover", "pressed", "focus"]:
  button.add_theme_stylebox_override(state, focus)
 button.pressed.connect(action)
 stage.add_child(button)
 return button

func _layout() -> void:
 var factor := minf(size.x / 1536.0, size.y / 1024.0)
 stage.scale = Vector2.ONE * factor
 stage.position = (size - Vector2(1536, 1024) * factor) / 2.0

func _show_step(index: int) -> void:
 step = index
 reviewing = false
 record_frame.hide()
 preview.hide()
 heading.text = "NECROTECH / SUBJECT INTAKE"
 heading.position = Vector2(282, 185)
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
 progress.show()
 progress.text = "RECOVERY CONSOLE  /  FIELD %02d OF 03" % (step + 1)
 for i in range(3):
  rows[i].visible = i <= step
  fields[i].editable = i == step
  fields[i].focus_mode = Control.FOCUS_ALL if i == step else Control.FOCUS_NONE
 back.text = "[ESC] BACK"
 back.position.y = 695
 proceed.position.y = 695
 proceed.text = "[ENTER] REVIEW" if step == 2 else "[ENTER] NEXT"
 footer.text = "LOCAL RECORD / AWAITING INPUT"
 _focus_field.call_deferred(step)
 _play_prompt(step)

func _focus_field(index: int) -> void:
 if reviewing or index != step: return
 fields[index].grab_focus()
 fields[index].deselect()
 fields[index].caret_column = fields[index].text.length()

func _play_prompt(index: int) -> void:
 narration.stop()
 var path: String = "res://assets/intro/audio/" + AUDIO[index]
 if not ResourceLoader.exists(path) and index < LEGACY_AUDIO.size():
  path = "res://assets/intro/audio/" + LEGACY_AUDIO[index]
 if ResourceLoader.exists(path):
  narration.stream = load(path) as AudioStream
  narration.play()

func _update_preview(_text: String) -> void:
 if fields.size() < 3 or not is_instance_valid(preview): return
 preview.text = "In life: %s %s\n\nAfter death: %s %s" % [fields[0].text.strip_edges(), fields[1].text.strip_edges(), fields[2].text.strip_edges(), fields[0].text.strip_edges()]
 error_label.text = ""

func _next_field(_text: String, index: int) -> void:
 if reviewing or index != step: return
 if fields[index].text.strip_edges().is_empty():
  error_label.text = "INPUT REQUIRED > " + PROMPTS[index]
  fields[index].grab_focus()
  return
 fields[index].text = fields[index].text.strip_edges()
 error_label.text = ""
 if index < 2: _show_step(index + 1)
 else: _confirm()

func _advance() -> void:
 if reviewing: _accept()
 else: _next_field(fields[step].text, step)

func _confirm() -> void:
 for i in range(fields.size()):
  if fields[i].text.strip_edges().is_empty():
   _show_step(i)
   error_label.text = "INPUT REQUIRED > " + PROMPTS[i]
   return
 _update_preview("")
 reviewing = true
 for row in rows: row.hide()
 record_frame.show()
 progress.hide()
 heading.text = "SUBJECT RECORD RECOVERED"
 heading.position = Vector2(282, 327)
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 preview.show()
 back.text = "[ESC] EDIT"
 back.position.y = 640
 proceed.position.y = 640
 proceed.text = "[ENTER] CONFIRM"
 footer.text = "VERIFY IDENTITY / CONFIRM TO CONTINUE"
 proceed.grab_focus.call_deferred()
 _play_prompt(3)

func _accept() -> void:
 if not reviewing or accepted: return
 accepted = true
 narration.stop()
 confirmed.emit({"first": fields[0].text.strip_edges(), "last": fields[1].text.strip_edges(), "adjective": fields[2].text.strip_edges()})

func _back() -> void:
 error_label.text = ""
 if reviewing: _show_step(0)
 elif step > 0: _show_step(step - 1)
 else: back_requested.emit()

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
  _back()
  get_viewport().set_input_as_handled()
