extends "res://scripts/naming_screen.gd"

signal answered(enabled: bool)

const YES = ["y", "yes", "yeah", "yep", "yup", "sure", "ok", "okay", "true", "1", "affirmative"]
const NO = ["n", "no", "nope", "nah", "false", "0", "negative"]

func _ready() -> void:
 super._ready()
 narration.stop()
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
