shader_type canvas_item;
render_mode unshaded;

uniform bool reduced_motion = false;
uniform vec4 phosphor : source_color = vec4(0.22, 0.48, 1.0, 1.0);

void fragment() {
 // Alpha glass layer: text and artwork remain separate underneath.
 float scanline = pow(0.5 + 0.5 * sin(UV.y * 676.0 * 3.14159), 10.0);
 float edge = pow(max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0, 6.0);
 float roll = 0.0;
 float flicker = 0.0;
 if (!reduced_motion) {
  float distance_to_band = abs(UV.y - (fract(TIME / 7.0) * 1.3 - 0.15));
  roll = (1.0 - smoothstep(0.0, 0.09, distance_to_band)) * 0.10;
  float burst = 1.0 - step(0.24, mod(TIME, 11.0));
  flicker = burst * (0.5 + 0.5 * sin(TIME * 53.0)) * 0.09;
 }
 float dark_alpha = scanline * 0.10 + flicker;
 float blue_alpha = edge * 0.045 + roll;
 float alpha = dark_alpha + blue_alpha;
 COLOR = vec4(phosphor.rgb * blue_alpha / max(alpha, 0.001), alpha);
}
