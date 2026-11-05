extends Control
## Project the actual architectural silhouette onto the ground, toward the
## southeast. Ground shadows share a layer below every building and wall.
var texture: Texture2D
var reach = 0.32

func _draw() -> void:
 if texture == null: return
 draw_set_transform_matrix(Transform2D(Vector2(1,0),Vector2(-reach,-0.12),Vector2(size.y*reach,size.y*1.12)))
 draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false,Color(0.025,0.028,0.023,0.28))
