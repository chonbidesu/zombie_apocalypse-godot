extends Control

signal closed

const Settings = preload("res://scripts/player_settings.gd")
const FONT = preload("res://assets/fonts/PixelifySans.ttf")
const GOLD := Color("d8b76b")
const CREAM := Color("ece4ca")

var settings: Settings
var screen_mode: OptionButton

func _ready() -> void:
 settings = get_node("/root/PlayerSettings") as Settings
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP

 var ui_theme := Theme.new()
 ui_theme.default_font = FONT
 ui_theme.default_font_size = 22
 ui_theme.set_color("font_color", "Label", CREAM)
 theme = ui_theme

 var shade := ColorRect.new()
 shade.color = Color(0.01, 0.03, 0.02, 0.85)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

 var center := CenterContainer.new()
 center.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(center)
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel := PanelContainer.new()
 panel.custom_minimum_size.x = 620
 var frame := StyleBoxFlat.new()
 frame.bg_color = Color("1c2b25")
 frame.border_color = GOLD
 frame.set_border_width_all(2)
 frame.content_margin_left = 32
 frame.content_margin_right = 32
 frame.content_margin_top = 24
 frame.content_margin_bottom = 24
 panel.add_theme_stylebox_override("panel", frame)
 center.add_child(panel)

 var content := VBoxContainer.new()
 content.add_theme_constant_override("separation", 18)
 panel.add_child(content)
 var heading := Label.new()
 heading.text = "SETTINGS"
 heading.add_theme_font_size_override("font_size", 36)
 heading.add_theme_color_override("font_color", GOLD)
 content.add_child(heading)

 var screen := HBoxContainer.new()
 content.add_child(screen)
 var screen_label := Label.new()
 screen_label.text = "Screen"
 screen_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 screen.add_child(screen_label)
 screen_mode = OptionButton.new()
 screen_mode.name = "ScreenMode"
 screen_mode.accessibility_name = "Screen mode"
 screen_mode.custom_minimum_size = Vector2(220, 46)
 screen_mode.add_item("Windowed")
 screen_mode.add_item("Full Screen")
 screen_mode.item_selected.connect(func(index: int): settings.set_fullscreen(index == 1))
 screen.add_child(screen_mode)
 settings.screen_mode_changed.connect(_sync_screen_mode)
 _sync_screen_mode()

 var divider := HSeparator.new()
 content.add_child(divider)
 var audio := GridContainer.new()
 audio.columns = 3
 audio.add_theme_constant_override("h_separation", 20)
 audio.add_theme_constant_override("v_separation", 16)
 content.add_child(audio)
 var controls: Array[Control] = [screen_mode]
 controls.append(_volume_row(audio, &"Master", "Master volume"))
 controls.append(_volume_row(audio, &"Music", "Music"))
 controls.append(_volume_row(audio, &"SFX", "Sound effects"))

 var done := Button.new()
 done.name = "SettingsDone"
 done.text = "Done [Esc]"
 done.custom_minimum_size = Vector2(160, 44)
 done.size_flags_horizontal = Control.SIZE_SHRINK_END
 done.pressed.connect(func(): closed.emit())
 content.add_child(done)
 controls.append(done)
 for i in range(controls.size()):
  var control := controls[i]
  control.focus_next = control.get_path_to(controls[(i+1) % controls.size()])
  control.focus_previous = control.get_path_to(controls[posmod(i-1, controls.size())])
  control.focus_neighbor_bottom = control.focus_next
  control.focus_neighbor_top = control.focus_previous
 screen_mode.grab_focus()

func _sync_screen_mode() -> void:
 screen_mode.select(1 if settings.is_fullscreen() else 0)

func _volume_row(parent: GridContainer, bus: StringName, caption: String) -> HSlider:
 var label := Label.new()
 label.text = caption
 parent.add_child(label)
 var slider := HSlider.new()
 slider.name = String(bus) + "Volume"
 slider.accessibility_name = caption
 slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 slider.step = 1
 slider.value = settings.volume_percent(bus)
 parent.add_child(slider)
 var level := Label.new()
 level.custom_minimum_size.x = 58
 level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 level.text = "%d%%" % slider.value
 parent.add_child(level)
 slider.value_changed.connect(func(value: float):
  level.text = "%d%%" % value
  settings.set_volume_percent(bus, int(value)))
 return slider
