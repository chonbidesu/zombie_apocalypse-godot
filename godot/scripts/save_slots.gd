extends Control

signal selected(path: String)
signal closed

var base_path := "user://prototype-save.json"
var saving := false
var pending_path := ""
var content: VBoxContainer

static func slot_path(base: String, index: int) -> String:
 if index == 0: return base
 return base.get_basename() + "-slot-%d." % (index + 1) + base.get_extension()

static func slot_description(path: String) -> String:
 if not FileAccess.file_exists(path): return "Empty"
 var data = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or not data.get("actors") is Array or data.actors.is_empty() or not data.actors[0] is Dictionary:
  return "Unreadable save"
 var actor: Dictionary = data.actors[0]
 var player_name = (str(actor.get("first","Unknown")) + " " + str(actor.get("last",""))) if actor.get("human",true) else (str(actor.get("adjective","Unknown")) + " " + str(actor.get("first","")))
 var local_time = FileAccess.get_modified_time(path) + int(Time.get_time_zone_from_system().bias) * 60
 var date = Time.get_datetime_string_from_unix_time(local_time).replace("T"," ")
 return "%s  ·  %s  ·  %s" % [player_name.strip_edges(),str(actor.get("job","Unknown")),date]

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 var shade := ColorRect.new()
 shade.color = Color(0.01,0.03,0.02,0.92)
 add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var center := CenterContainer.new()
 add_child(center)
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 content = VBoxContainer.new()
 var ui_theme := Theme.new()
 ui_theme.default_font = load("res://assets/fonts/PixelifySans.ttf")
 ui_theme.default_font_size = 20
 content.theme = ui_theme
 content.custom_minimum_size = Vector2(700,0)
 content.add_theme_constant_override("separation",16)
 center.add_child(content)
 _render()

func _render() -> void:
 for child in content.get_children():
  content.remove_child(child)
  child.queue_free()
 var heading := Label.new()
 heading.text = "SAVE GAME" if saving else "LOAD GAME"
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size",32)
 content.add_child(heading)
 if not pending_path.is_empty():
  var prompt := Label.new()
  prompt.text = "Overwrite this saved game?"
  prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  content.add_child(prompt)
  var confirm := Button.new()
  confirm.text = "Overwrite"
  confirm.custom_minimum_size.y = 54
  confirm.pressed.connect(func(): selected.emit(pending_path))
  content.add_child(confirm)
  var back := Button.new()
  back.text = "Back"
  back.pressed.connect(func(): pending_path = ""; _render())
  content.add_child(back)
  return
 for i in range(3):
  var path := slot_path(base_path,i)
  var slot := Button.new()
  slot.text = "SLOT %s   %s" % [char(65+i),slot_description(path)]
  slot.custom_minimum_size.y = 76
  slot.disabled = not saving and not FileAccess.file_exists(path)
  slot.pressed.connect(func(): _choose(path))
  content.add_child(slot)
 var cancel := Button.new()
 cancel.text = "Back"
 cancel.custom_minimum_size.y = 44
 cancel.pressed.connect(func(): closed.emit())
 content.add_child(cancel)

func _choose(path: String) -> void:
 if saving and FileAccess.file_exists(path):
  pending_path = path
  _render()
 else: selected.emit(path)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
  if pending_path.is_empty(): closed.emit()
  else: pending_path = ""; _render()
  get_viewport().set_input_as_handled()
