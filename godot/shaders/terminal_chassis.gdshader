shader_type canvas_item;
render_mode unshaded;

void fragment() {
 // Keep the fixed casing in its own material pass. This avoids the casing
 // disappearing when the transparent record artwork joins the canvas batch.
 COLOR = texture(TEXTURE, UV);
}
