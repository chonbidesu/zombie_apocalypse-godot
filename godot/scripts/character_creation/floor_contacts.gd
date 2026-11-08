extends Node2D
## Small, soft floor contacts supplement the long projected silhouette.
var points: Array[Vector2] = []
var radius: float = 1.0

func set_contacts(new_points: Array[Vector2], new_radius: float) -> void:
 points = new_points
 radius = new_radius
 queue_redraw()

func _draw() -> void:
 for point in points:
  # Three translucent ellipses make the contact soft without blurring the
  # cast silhouette or shifting it away from the back edge of the sole.
  draw_set_transform(point, 0.0, Vector2(1.0, .28))
  draw_circle(Vector2.ZERO, radius, Color(0.012,0.012,0.014,.12))
  draw_circle(Vector2.ZERO, radius*.68, Color(0.012,0.012,0.014,.16))
  draw_circle(Vector2.ZERO, radius*.36, Color(0.012,0.012,0.014,.20))
 draw_set_transform(Vector2.ZERO)
