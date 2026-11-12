extends Node

signal screen_mode_changed

const AUDIO_BUSES := [&"Master", &"Music", &"SFX"]

var config_path := "user://settings.cfg"
var config := ConfigFile.new()

func _ready() -> void:
 if config.load(config_path) != OK: config.clear()
 for bus in AUDIO_BUSES:
  _apply_volume(bus, volume_percent(bus))
 var saved_mode = config.get_value("screen", "fullscreen", false)
 if saved_mode is bool and saved_mode:
  get_tree().root.mode = Window.MODE_FULLSCREEN

func is_fullscreen() -> bool:
 return get_tree().root.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(enabled: bool) -> void:
 if enabled != is_fullscreen():
  get_tree().root.mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
 config.set_value("screen", "fullscreen", is_fullscreen())
 _save()
 screen_mode_changed.emit()

func toggle_fullscreen() -> void:
 set_fullscreen(not is_fullscreen())

func volume_percent(bus: StringName) -> int:
 var value = config.get_value("audio", String(bus).to_lower(), 100)
 if value is int or value is float:
  return roundi(clampf(value, 0, 100))
 return 100

func set_volume_percent(bus: StringName, value: int) -> void:
 var percent := clampi(value, 0, 100)
 config.set_value("audio", String(bus).to_lower(), percent)
 _apply_volume(bus, percent)
 _save()

func _apply_volume(bus: StringName, percent: int) -> void:
 var index := AudioServer.get_bus_index(bus)
 AudioServer.set_bus_mute(index, percent == 0)
 AudioServer.set_bus_volume_db(index, linear_to_db(maxi(percent, 1) / 100.0))

func _save() -> void:
 var error := config.save(config_path)
 if error != OK: push_warning("Could not save settings: %s" % error_string(error))
