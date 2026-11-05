shader_type canvas_item;
uniform sampler2D intact_model : filter_linear;
uniform vec4 region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 joined_edges = vec4(0.0); // north, east, south, west
uniform bool ruined = false;

void fragment() {
 vec4 art = texture(TEXTURE,UV);
 vec4 intact = texture(intact_model,UV);
 vec2 local_uv = (UV-region.xy)/region.zw;
 // Keep the same structural edge on either side of a complex section seam.
 float edge = 1.0;
 if (joined_edges.x > 0.5) edge *= smoothstep(0.0,0.035,local_uv.y);
 if (joined_edges.y > 0.5) edge *= smoothstep(0.0,0.035,1.0-local_uv.x);
 if (joined_edges.z > 0.5) edge *= smoothstep(0.0,0.035,1.0-local_uv.y);
 if (joined_edges.w > 0.5) edge *= smoothstep(0.0,0.035,local_uv.x);
 if (ruined) {
  float grey = dot(art.rgb,vec3(0.299,0.587,0.114));
  art.rgb = mix(art.rgb,vec3(grey*0.69),0.5);
 }
 COLOR = mix(intact,art,edge);
}
