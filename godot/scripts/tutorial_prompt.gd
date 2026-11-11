extends "res://scripts/naming_screen.gd"

signal answered(enabled: bool)
signal boot_finished

const BOOT_DURATION := 2.4
var boot_elapsed := -1.0
var boot_text: Label

const YES = ["y", "yes", "yeah", "yep", "yup", "sure", "ok", "okay", "true", "1", "affirmative"]
const NO = ["n", "no", "nope", "nah", "false", "0", "negative"]

func _ready() -> void:
 super._ready()
 heading.text = "NECROTECH / RECOVERY CONSOLE"
 progress.text = "INITIALIZATION / TRAINING"
 rows[0].get_node("Prompt").text = "Start with tutorials? Y/N:"
 fields[0].text_submitted.disconnect(_next_field.bind(0))
 fields[0].text_submitted.connect(_submit_answer)
 fields[0].max_length = 32
 back.hide()
 proceed.text = "[ENTER] CONTINUE"
 footer.text = "ENTER YES OR NO / PRESS ENTER"

func _advance() -> void:
 _submit_answer(fields[0].text)

func _submit_answer(value: String) -> void:
 if boot_elapsed >= 0.0: return
 var answer := value.strip_edges().to_lower()
 if answer in YES:
  answered.emit(true)
 elif answer in NO:
  answered.emit(false)
 else:
  error_label.text = "PLEASE ENTER YES OR NO."
  fields[0].grab_focus()

func _input(_event: InputEvent) -> void:
 pass

# The question must be silent; naming narration begins only after startup.
func _play_prompt(_index: int) -> void:
 pass

func begin_boot() -> void:
 boot_elapsed = 0.0
 rows[0].hide()
 proceed.hide()
 error_label.hide()
 heading.text = "NECROTECH / SYSTEM STARTUP"
 progress.text = "INITIALIZING RECOVERY CONSOLE"
 footer.text = "PLEASE STAND BY"
 boot_text = _label("", 24, BLUE, Rect2(284, 292, 960, 300))
 boot_text.name = "BootStatus"
 _update_boot()

func _process(delta: float) -> void:
 if boot_elapsed < 0.0: return
 boot_elapsed += delta
 _update_boot()
 if boot_elapsed >= BOOT_DURATION:
  boot_elapsed = -1.0
  boot_finished.emit()

func _update_boot() -> void:
 var lines := ["Z:\\> INITIALIZE RECOVERY CONSOLE", "CHECKING SYSTEMS ............ OK", "LOADING SUBJECT INTAKE ...... OK", "RECOVERY CONSOLE READY_"]
 var count := mini(4, 1 + int(boot_elapsed / 0.55))
 boot_text.text = "\n\n".join(lines.slice(0, count))
