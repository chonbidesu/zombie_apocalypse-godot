shader_type canvas_item;

// Normalized bounds of the centre, fifth-floor glass pane in facade v4.
// Apply to the facade only; put the lab and a black backing behind it.
uniform vec4 glass_rect = vec4(0.443787, 0.553169, 0.117160, 0.060150);
uniform float glass_opacity : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 end = glass_rect.xy + glass_rect.zw;
	bool glass = UV.x >= glass_rect.x && UV.x <= end.x && UV.y >= glass_rect.y && UV.y <= end.y;
	if (glass) {
		tex.a *= glass_opacity;
	}
	COLOR = tex;
}
