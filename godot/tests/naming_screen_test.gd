extends SceneTree

const Naming = preload("res://scripts/naming_screen.gd")
var failures := 0
var checks := 0
var identities: Array[Dictionary] = []
var backs := 0

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func press(key: Key, unicode: int = 0) -> void:
 var event := InputEventKey.new()
 event.keycode = key
 event.unicode = unicode
 event.pressed = true
 root.push_input(event, true)
 event = event.duplicate() as InputEventKey
 event.pressed = false
 root.push_input(event, true)
 await process_frame

func capture(path: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var rendered := root.get_texture().get_image()
 rendered.save_png(path)
 var casing := rendered.get_pixel(int(rendered.get_width() * 0.15), int(rendered.get_height() * 0.5))
 check(casing.r > 0.1, "Fixed terminal casing remains visible in " + path.get_file())

func run() -> void:
 root.size = Vector2i(1536, 1024)
 var naming := Naming.new()
 naming.confirmed.connect(func(identity: Dictionary): identities.append(identity))
 naming.back_requested.connect(func(): backs += 1)
 root.add_child(naming)
 await process_frame
 check(naming.fields[0].has_focus() and not naming.rows[1].visible, "Only first prompt starts active")
 await press(KEY_ENTER)
 check(naming.step == 0 and not naming.error_label.text.is_empty(), "Empty Enter stays at the current prompt")
 naming.fields[0].text = "  Jamie  "
 await press(KEY_ENTER)
 check(naming.step == 1 and naming.fields[1].has_focus(), "Enter advances focus to the last name")
 check(naming.fields[0].text == "Jamie" and not naming.fields[0].editable, "Submitted first name is trimmed and retained")
 naming.fields[1].text = "Rivera"
 await press(KEY_ENTER)
 naming.fields[2].text = "Ghastly"
 naming.fields[2].caret_column = naming.fields[2].text.length()
 await capture("res://tests/terminal-intake-preview.png")
 await press(KEY_ESCAPE)
 check(naming.step == 1 and naming.fields[2].text == "Ghastly", "Back preserves previously entered values")
 await press(KEY_ENTER)
 await press(KEY_ENTER)
 check(naming.reviewing and identities.is_empty(), "Third submission opens review without accepting identity")
 check(naming.heading.text == "SUBJECT RECORD RECOVERED" and naming.preview.text == "In life: Jamie Rivera\n\nAfter death: Ghastly Jamie", "Recovered record displays the requested living and undead identities")
 check(naming.narration.stream.resource_path.ends_with("naming 4.mp3"), "Record screen uses the fourth narration clip")
 await capture("res://tests/terminal-record-preview.png")
 await press(KEY_ESCAPE)
 check(not naming.reviewing and naming.step == 0 and naming.fields[0].has_focus() and not naming.rows[1].visible, "Escape from confirmation restarts at the first prompt")
 check(naming.fields[0].text == "Jamie" and naming.fields[1].text == "Rivera" and naming.fields[2].text == "Ghastly", "Restarting the prompts preserves all entered values")
 check(naming.fields[0].caret_column == 5 and not naming.fields[0].has_selection(), "First name resumes with an unselected cursor at the end")
 await press(KEY_S, "s".unicode_at(0))
 check(naming.fields[0].text == "Jamies", "Typing immediately appends to the retained first name")
 await press(KEY_BACKSPACE)
 await press(KEY_ENTER)
 check(naming.step == 1 and naming.fields[1].caret_column == 6, "Enter revisits the retained last name with the cursor at its end")
 await press(KEY_ENTER)
 naming.fields[2].text = "Ashen"
 await press(KEY_ENTER)
 await press(KEY_ENTER)
 check(identities.size() == 1 and identities[0] == {"first": "Jamie", "last": "Rivera", "adjective": "Ashen"}, "Confirmation emits the final edited identity")
 naming._accept()
 check(identities.size() == 1, "Repeated confirmation cannot emit twice")
 naming._show_step(0)
 await press(KEY_ESCAPE)
 check(backs == 1, "Escape from the first prompt returns to character selection")
 naming.fields[0].text = "A".repeat(32)
 naming.fields[1].text = "B".repeat(32)
 naming.fields[2].text = "C".repeat(32)
 naming._confirm()
 for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
  root.size = window_size
  await process_frame
  await process_frame
  var bounds := naming.stage.get_global_rect()
  check(naming.get_global_rect().encloses(bounds), "Terminal fits window %s without stretching or cropping" % window_size)
 check(naming.preview.get_line_count() <= 6, "Maximum length identities remain within the record text area")
 await capture("res://tests/terminal-long-names-preview.png")
 naming.queue_free()
 await process_frame
 # The audio mixer releases stopped narration playbacks asynchronously.
 await create_timer(0.1).timeout
 print("Naming screen: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
