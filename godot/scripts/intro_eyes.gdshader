shader_type canvas_item;

void fragment() {
 vec4 frame = texture(TEXTURE, UV);
 float mask_x = smoothstep(0.73, 0.75, UV.x) * (1.0 - smoothstep(0.85, 0.87, UV.x));
 float mask_y = smoothstep(0.30, 0.32, UV.y) * (1.0 - smoothstep(0.47, 0.49, UV.y));
 COLOR = vec4(frame.rgb, frame.a * mask_x * mask_y);
}
