shader_type canvas_item;
varying float opacity;
void vertex(){ opacity=COLOR.a; }
void fragment(){
 vec2 d=TEXTURE_PIXEL_SIZE*1.8;
 float a=texture(TEXTURE,UV).a*.4;
 a+=(texture(TEXTURE,UV+d).a+texture(TEXTURE,UV-d).a+texture(TEXTURE,UV+vec2(d.x,-d.y)).a+texture(TEXTURE,UV+vec2(-d.x,d.y)).a)*.15;
 COLOR=vec4(.012,.012,.014,a*.62*opacity);
}
