extends Button
## Draw symbols with the button's text colour, independent of emoji fonts.
var sex: String = "male"

func _draw() -> void:
 var colour_name := "font_color"
 match get_draw_mode():
  DRAW_PRESSED: colour_name = "font_pressed_color"
  DRAW_HOVER: colour_name = "font_hover_color"
  DRAW_HOVER_PRESSED: colour_name = "font_hover_pressed_color"
  DRAW_DISABLED: colour_name = "font_disabled_color"
 var tint := get_theme_color(colour_name)
 var centre := size/2.0 + (Vector2(-4,4) if sex == "male" else Vector2(0,-6))
 draw_circle(centre,10.0,tint,false,3.0,true)
 if sex == "male":
  var tip := centre+Vector2(20,-20)
  draw_line(centre+Vector2(7,-7),tip,tint,3.0,true)
  draw_polyline(PackedVector2Array([tip+Vector2(-12,0),tip,tip+Vector2(0,12)]),tint,3.0,true)
 else:
  draw_line(centre+Vector2(0,10),centre+Vector2(0,28),tint,3.0,true)
  draw_line(centre+Vector2(-8,21),centre+Vector2(8,21),tint,3.0,true)
