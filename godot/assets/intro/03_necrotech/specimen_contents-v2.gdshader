shader_type canvas_item;

// Remove the generated neutral white backdrop during rendering.
// Source art remains unchanged. Only near-white, low-saturation pixels fade.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lightest_floor = min(tex.r, min(tex.g, tex.b));
	float background = smoothstep(0.86, 0.98, lightest_floor);
	tex.a *= 1.0 - background;
	COLOR = tex;
}
