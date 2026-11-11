extends Control

signal finished

const FONT = preload("res://assets/fonts/PixelifySans.ttf")
const LOGO = preload("res://assets/author-bee.png")
const FADE := 1.2
const HOLDS := [3.5, 9.0]

var page := 0
var elapsed := 0.0
var content: Control
var author: Control
var tribute: Control

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var background := ColorRect.new()
 background.color = Color("101713")
 add_child(background)
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 content = Control.new()
 add_child(content)
 content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 author = Control.new()
 content.add_child(author)
 author.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var logo := TextureRect.new()
 logo.texture = LOGO
 logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 author.add_child(logo)
 _place(logo, 0.35, 0.12, 0.65, 0.61)
 var credit := _label("A GAME BY", 28, Color("d2bd8b"))
 author.add_child(credit)
 _place(credit, 0.1, 0.64, 0.9, 0.69)
 var name_label := _label("chonbidesu", 64, Color("e8e3d2"))
 author.add_child(name_label)
 _place(name_label, 0.1, 0.69, 0.9, 0.78)
 tribute = Control.new()
 content.add_child(tribute)
 tribute.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var heading := _label("IN TRIBUTE TO URBAN DEAD", 38, Color("d2bd8b"))
 tribute.add_child(heading)
 _place(heading, 0.1, 0.29, 0.9, 0.36)
 var copy := _label("This game is inspired by Urban Dead, created by Kevan Davis — an MMO published in 2005 that ended in 2025.\n\nMalton Reborn hopes it will one day return to us. Meanwhile, enjoy this offline adaptation of that iconic experience.", 32, Color("e8e3d2"))
 copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 tribute.add_child(copy)
 _place(copy, 0.19, 0.39, 0.81, 0.72)
 tribute.hide()
 content.modulate.a = 0.0

func _place(control: Control, left: float, top: float, right: float, bottom: float) -> void:
 control.anchor_left = left
 control.anchor_top = top
 control.anchor_right = right
 control.anchor_bottom = bottom

func _label(copy: String, font_size: int, color: Color) -> Label:
 var label := Label.new()
 label.text = copy
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label.add_theme_font_override("font", FONT)
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", color)
 return label

func _process(delta: float) -> void:
 elapsed += delta
 var duration: float = FADE * 2.0 + HOLDS[page]
 content.modulate.a = clampf(minf(elapsed / FADE, (duration - elapsed) / FADE), 0.0, 1.0)
 if elapsed >= duration:
  if page == 0:
   page = 1
   elapsed = 0.0
   author.hide()
   tribute.show()
  else:
   set_process(false)
   finished.emit()
