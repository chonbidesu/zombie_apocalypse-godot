shader_type canvas_item;
uniform float exposure = 1.0;
uniform vec4 lights = vec4(0.0);

float oval(vec2 uv, vec2 center, vec2 radius) {
 return 1.0 - smoothstep(0.65, 1.0, length((uv-center)/radius));
}
float cone(vec2 uv, float x, float width) {
 float spread = width * (0.35 + uv.y);
 return (1.0-smoothstep(spread*0.55, spread, abs(uv.x-x))) * (1.0-smoothstep(0.72, 1.0, uv.y));
}
void fragment() {
 vec2 uv = UV;
 float bag = oval(uv, vec2(0.68,0.75),vec2(0.16,0.12));
 vec3 base = texture(TEXTURE,UV).rgb;
 float left = cone(uv,0.23,0.38)*lights.x;
 float middle = cone(uv,0.50,0.21)*lights.y*smoothstep(0.34,0.38,uv.x);
 float right = cone(uv,0.83,0.36)*lights.z;
 float body = oval(uv,vec2(0.68,0.75),vec2(0.21,0.18))*lights.w;
 float illumination = max(max(left,middle),right)*(1.0-bag*0.97);
 illumination = max(illumination,body);
 vec3 color = base*(vec3(0.047,0.060,0.075)+illumination*vec3(1.15,1.04,0.85));
 float haze = (left+middle+right)*0.035*(1.0-uv.y)*(1.0-bag);
 color += vec3(1.0,0.81,0.51)*haze;
 COLOR = vec4(color*exposure,1.0);
}
