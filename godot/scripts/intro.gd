extends Control

signal finished(occupation: String)

const FONT = preload("res://assets/fonts/PixelifySans.ttf")
const ROOT = "res://assets/intro/"
const ORIGINS = {"Private":"private", "Medic":"medic", "Scout":"scout", "Doctor":"doctor", "NecroTech Lab Assistant":"necro", "Consumer":"consumer", "Police Officer":"police", "Firefighter":"firefighter"}
const TITLES = ["", "", "QUARANTINE", "NECROTECH", ""]
const VOICES = {"Private":"9a", "Medic":"9b", "Scout":"9c", "Doctor":"9d", "NecroTech Lab Assistant":"9e", "Consumer":"9f", "Police Officer":"9g", "Firefighter":"9h"}
const TEXTS = [
 "Before the outbreak, Malton was an ordinary city.\n\nBehind the doors of its office buildings, NecroTech carried out research few people knew about.",
 "Then people began to die.\n\nAnd the dead began to rise.",
 "The government sealed Malton under quarantine.\n\nThose inside were left to face the dead.",
 "NecroTech had been studying the dead. Its scientists also found a way to bring them back.\n\nWhat happened in their laboratories—and what they knew before the outbreak—remains buried inside the city."
]
var occupation := ""
var reduced_motion := false
var page := 0
var elapsed := 0.0
var ending := false
var ending_time := 0.0
var held_drift := 0.0
var layers: Array[Texture2D] = []
var title: Label
var copy: Label
var prompt: Label
var skip: Button
var eyes: TextureRect
var curtain: ColorRect
var facade_view: TextureRect
var opening_scrim: ColorRect
var specimen: Node2D
var narration: AudioStreamPlayer
var line_labels: Array[Label] = []
var line_times: Array[float] = []
var line_streams: Array[AudioStream] = []
var narration_index := -1
var narration_end := 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 facade_view = TextureRect.new()
 facade_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 facade_view.stretch_mode = TextureRect.STRETCH_SCALE
 facade_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
 facade_view.material = load(ROOT + "01_before/window_glass.tres")
 add_child(facade_view)
 specimen = (load(ROOT + "03_necrotech/specimen_tube-v3.tscn") as PackedScene).instantiate()
 add_child(specimen)
 narration = AudioStreamPlayer.new()
 add_child(narration)
 opening_scrim = ColorRect.new()
 opening_scrim.position = Vector2(0, 690)
 opening_scrim.size = Vector2(1920, 390)
 opening_scrim.color = Color(0.015, 0.018, 0.02, 0.82)
 opening_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(opening_scrim)
 title = _label(30, Color("d6ac6a"))
 title.position = Vector2(120, 725)
 title.size = Vector2(1500, 50)
 copy = _label(30, Color("fff2d8"))
 copy.position = Vector2(120, 780)
 copy.size = Vector2(1450, 190)
 copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 copy.hide()
 for i in range(4):
  var line := _label(30, Color("fff2d8"))
  line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  line_labels.append(line)
 prompt = _label(22, Color("e1be83"))
 prompt.position = Vector2(120, 1000)
 prompt.size = Vector2(1500, 40)
 skip = Button.new()
 skip.text = "SKIP INTRO"
 skip.position = Vector2(1630, 45)
 skip.size = Vector2(200, 48)
 skip.focus_mode = Control.FOCUS_NONE
 skip.add_theme_font_override("font", FONT)
 skip.add_theme_font_size_override("font_size", 20)
 skip.pressed.connect(_skip_intro)
 add_child(skip)
 eyes = TextureRect.new()
 eyes.position = Vector2(-77, -43)
 eyes.size = Vector2(2074, 1166)
 eyes.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 eyes.stretch_mode = TextureRect.STRETCH_SCALE
 eyes.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader := Shader.new()
 shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); float m = smoothstep(0.73, 0.75, UV.x) * (1.0-smoothstep(0.85, 0.87, UV.x)) * smoothstep(0.30, 0.32, UV.y) * (1.0-smoothstep(0.47, 0.49, UV.y)); COLOR = vec4(c.rgb, c.a * m); }"
 var material := ShaderMaterial.new()
 material.shader = shader
 eyes.material = material
 add_child(eyes)
 eyes.hide()
 # Keep text above the face overlay.
 move_child(eyes, 2)
 curtain = ColorRect.new()
 curtain.color = Color.BLACK
 curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
 curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(curtain)
 _show_page(0)

func _label(font_size: int, color: Color) -> Label:
 var label := Label.new()
 label.add_theme_font_override("font", FONT)
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", color)
 label.add_theme_color_override("font_shadow_color", Color.BLACK)
 label.add_theme_constant_override("shadow_offset_x", 2)
 label.add_theme_constant_override("shadow_offset_y", 3)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(label)
 return label

func _load_layer(path: String) -> Texture2D:
 return load(ROOT + path) as Texture2D

func _show_page(index: int) -> void:
 page = index
 elapsed = 0.0
 narration.stop()
 narration_index = -1
 line_times.clear()
 line_streams.clear()
 layers.clear()
 eyes.hide()
 match page:
  0:
   for path in ["01_before/skyline_far.png", "01_before/skyline_mid.png", "01_before/lab_window_interior.png", "01_before/office_facade-v4.png"]: layers.append(_load_layer(path))
  2:
   for path in ["02_quarantine/background.png", "02_quarantine/soldiers-v2.png", "02_quarantine/civilians.png"]: layers.append(_load_layer(path))
  3:
   layers.append(_load_layer("03_necrotech/background.png"))
  4:
   var folder: String = "05_corpse/" if occupation == "Corpse" else "04_origins/%s/" % ORIGINS.get(occupation, "consumer")
   layers.append(_load_layer(folder + "background.png"))
   layers.append(_load_layer(folder + ("body_closed.png" if occupation == "Corpse" else "foreground.png")))
   if occupation == "Corpse": eyes.texture = _load_layer(folder + "body_open-v2.png")
 title.text = TITLES[page] if page < 4 else ("THE DEAD" if occupation == "Corpse" else occupation.to_upper())
 facade_view.visible = page == 0
 specimen.visible = page == 3
 var contents := specimen.get_node("Contents") as AnimatedSprite2D
 if page == 3 and not reduced_motion: contents.play()
 else: contents.pause()
 opening_scrim.visible = page != 1
 if page == 0: facade_view.texture = layers[3]
 if page < 4:
  copy.text = TEXTS[page]
 elif occupation == "Corpse":
  copy.text = "Your old life is gone, but something remains.\n\nThe living hide behind barricades. The dead roam the streets. And somewhere in the city, there may be a way back."
 else:
  copy.text = "Before the outbreak, you were a %s.\n\nNow, you must find shelter, gather supplies, and survive in a city where death is not the end." % occupation
 var texts: Array = []
 var tracks: Array = []
 match page:
  0: texts = ["Before the outbreak, Malton was an ordinary city.", "Behind the doors of its office buildings, NecroTech carried out research few people knew about."]; tracks = ["1", "2"]
  1: texts = ["Then people began to die.", "And the dead began to rise."]; tracks = ["3", "4"]
  2: texts = ["The government sealed Malton under quarantine.", "Those inside were left to face the dead."]; tracks = ["5", "6"]
  3: texts = ["NecroTech had been studying the dead. Its scientists also found a way to bring them back.", "What happened in their laboratories—and what they knew before the outbreak—remains buried inside the city."]; tracks = ["7", "8"]
  4:
   if occupation == "Corpse":
    texts = ["Your old life is gone, but something remains.", "The living hide behind barricades. The dead roam the streets. And somewhere in the city, there may be a way back.", "RISE"]
    tracks = ["12", "13", "14"]
   else:
    texts = ["Before the outbreak, you were a %s." % occupation, "Now, you must find shelter, gather supplies, and survive in a city where death is not the end.", "ENTER MALTON"]
    tracks = [VOICES.get(occupation, "9f"), "10", "11"]
 var next_time := 0.8
 var y := 410.0 if page == 1 else 780.0
 for i in range(line_labels.size()):
  var label := line_labels[i]
  label.visible = i < texts.size()
  if i >= texts.size(): continue
  label.text = texts[i]
  label.position = Vector2(260, y) if page == 1 else Vector2(120, y)
  var width := 1400.0 if page == 1 else 1450.0
  var text_height := maxf(42.0, FONT.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, 30).y)
  label.size = Vector2(width, text_height)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if page == 1 else HORIZONTAL_ALIGNMENT_LEFT
  label.modulate.a = 0.0
  y += text_height + (22.0 if texts.size() < 3 else 5.0)
  var stream := load(ROOT + "audio/Malton %s.mp3" % tracks[i]) as AudioStream
  line_streams.append(stream)
  line_times.append(next_time)
  next_time += (stream.get_length() if stream else 0.0) + 1.0
 narration_end = next_time
 prompt.text = "CLICK OR PRESS ANY KEY TO CONTINUE" if page < 4 else "CLICK OR PRESS ANY KEY"
 if page == 1:
  copy.position = Vector2(260, 410)
  copy.size = Vector2(1400, 260)
  copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 else:
  copy.position = Vector2(120, 780)
  copy.size = Vector2(1450, 190)
  copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
 queue_redraw()

func _process(delta: float) -> void:
 elapsed += delta
 if page == 0:
  var facade := _opening_facade_rect()
  facade_view.position = facade.position
  facade_view.size = facade.size
 if page == 3:
  var progress := 1.0 if reduced_motion else 1.0 - pow(1.0 - clampf(elapsed / 14.0, 0.0, 1.0), 3.0)
  specimen.position = Vector2(lerpf(2270.0, 1570.0, progress), 535)
  specimen.scale = Vector2.ONE * lerpf(0.65, 0.48, progress)
 if ending:
  ending_time += delta
  curtain.color.a = clampf((ending_time - (2.0 if occupation == "Corpse" else 0.1)) / 1.1, 0.0, 1.0)
  if ending_time >= (3.2 if occupation == "Corpse" else 1.2):
   set_process(false)
   finished.emit(occupation)
 else:
  curtain.color.a = 1.0 - clampf(elapsed / 0.65, 0.0, 1.0)
  var fade_duration := 1.4 if page == 1 else 0.9
  for i in range(line_times.size()):
   line_labels[i].modulate.a = clampf((elapsed - line_times[i]) / fade_duration, 0.0, 1.0)
  if narration_index + 1 < line_times.size() and elapsed >= line_times[narration_index + 1]:
   narration_index += 1
   narration.stream = line_streams[narration_index]
   if narration.stream: narration.play()
  var prompt_at := _advance_time()
  prompt.modulate.a = clampf((elapsed - prompt_at) / 0.5, 0.0, 1.0)
 queue_redraw()

func _opening_facade_rect() -> Rect2:
 var travel := 1.0 if reduced_motion else smoothstep(2.5, 9.3, elapsed)
 var zoom_progress := 1.0 if reduced_motion else clampf((elapsed - 9.3) / 9.0, 0.0, 1.0)
 var zoom := 1.0 + 0.28 * (1.0 - pow(1.0 - zoom_progress, 3.0))
 var top := lerpf(2100.0, -1983.0, travel)
 var anchor := Vector2(960, 485)
 var origin := anchor + (Vector2(0, top) - anchor) * zoom
 return Rect2(origin, Vector2(1920, 1920.0 * 1862.0 / 845.0) * zoom)

func _opening_light() -> float:
 if reduced_motion: return 1.0
 if elapsed < 10.3: return 0.0
 if elapsed < 10.45: return 0.8
 if elapsed < 10.62: return 0.0
 if elapsed < 10.75: return 0.55
 if elapsed < 10.9: return 0.0
 return 1.0

func _quarantine_rect(index: int) -> Rect2:
 var progress := 0.0 if reduced_motion else smoothstep(0.0, 8.0, elapsed)
 var anchor := Vector2(960, 490)
 var base := Rect2(-77, -43, 2074, 1166)
 var factor := 1.0 + progress * (0.12 if index == 0 else (0.75 if index == 1 else 2.5))
 if index == 1:
  base = Rect2(-77, 350, 2074, 2074.0 / 3.0)
  return _zoom_rect(base, factor, Vector2(anchor.x, base.end.y))
 return Rect2(anchor + (base.position - anchor) * factor, base.size * factor)

func _advance_time() -> float:
 if page == 4 and not line_times.is_empty(): return line_times[-1]
 return maxf(narration_end, 11.2 if page == 0 and not reduced_motion else 0.8)

func _zoom_rect(base: Rect2, factor: float, anchor: Vector2 = Vector2(960, 490)) -> Rect2:
 return Rect2(anchor + (base.position - anchor) * factor, base.size * factor)

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, Vector2(1920,1080)), Color.BLACK)
 var drift := 0.0 if reduced_motion else (held_drift if ending else sin(elapsed * 0.18))
 var base := Rect2(-77, -43, 2074, 1166)
 if page == 0 and layers.size() == 4:
  var descent := 1.0 if reduced_motion else smoothstep(0.0, 9.3, elapsed)
  draw_texture_rect(layers[0], Rect2(base.position + Vector2(0, -descent * 20), base.size), false)
  draw_texture_rect(layers[1], Rect2(base.position + Vector2(0, 145 - descent * 240), base.size), false)
  var facade := _opening_facade_rect()
  var scale_factor := facade.size.x / 845.0
  # Crop the lab to fill the narrow pane, with overscan behind its frame.
  var lab := Rect2(facade.position + Vector2(370, 1025) * scale_factor, Vector2(109, 122) * scale_factor)
  draw_rect(lab, Color.BLACK)
  var light := _opening_light()
  var source_width := 941.0 * 109.0 / 122.0
  draw_texture_rect_region(layers[2], lab, Rect2((1672.0 - source_width) / 2.0, 0, source_width, 941), Color(light,light,light))
 elif page != 1:
  for i in range(layers.size()):
   var speed := 10.0 if i == 0 else (24.0 if i == 1 else 42.0)
   var destination := Rect2(base.position + Vector2(drift * speed, drift * speed * 0.25), base.size)
   if page == 2: destination = _quarantine_rect(i)
   elif page == 3:
    var retreat := 1.0 if reduced_motion else 1.0 - pow(1.0 - clampf(elapsed / 14.0, 0.0, 1.0), 3.0)
    destination = _zoom_rect(base, lerpf(1.4, 1.0, retreat))
   elif page == 4 and occupation != "Corpse":
    var approach := 0.0 if reduced_motion else smoothstep(0.0, 18.0, elapsed)
    destination = _zoom_rect(base, 1.0 + approach * (0.12 if i == 0 else 0.85))
   draw_texture_rect(layers[i], destination, false)

func _input(event: InputEvent) -> void:
 if ending: return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_F11:
  _advance()
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  if skip.get_global_rect().has_point(event.position): return
  _advance()
  get_viewport().set_input_as_handled()

func _advance() -> void:
 if elapsed < _advance_time(): return
 if page < 4:
  _show_page(page + 1)
 else:
  narration.stop()
  held_drift = sin(elapsed * 0.18)
  ending = true
  ending_time = 0.0
  skip.hide()
  prompt.hide()
  if occupation == "Corpse":
   var drift := 0.0 if reduced_motion else held_drift
   eyes.position = Vector2(-77, -43) + Vector2(drift * 24.0, drift * 6.0)
   eyes.show()

func _skip_intro() -> void:
 if ending: return
 narration.stop()
 # A corpse always gets its player-triggered awakening.
 if occupation == "Corpse": _show_page(4)
 else:
  ending = true
  ending_time = 0.0
  skip.hide()
  prompt.hide()
