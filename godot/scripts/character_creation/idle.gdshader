shader_type canvas_item;
// Each frame is a real drawing. Outside the figure's upper body, hold the
// first drawing so incidental differences in furniture cannot make it jump.
uniform bool idle = false;
uniform int choice_frame = -1;
uniform int subject;
uniform sampler2D atlas_texture : filter_linear, repeat_disable;
uniform sampler2D doctor_portrait : filter_linear, repeat_disable;
varying vec4 tint;
void vertex(){ tint=COLOR; }

// Select one drawing for the entire moving feature. Crossfading displaced
// outlines produced the second hairline, hand and vial seen at close range.
float moving_region(vec2 local, vec2 center, vec2 extent) {
 if(subject==3) return float(local.x<.66 && local.y<.72);
 // Include the whole card fan and hand, but exclude the chair back.
 if(subject==1) return float(local.x>.23 && local.x<.64 && local.y<.50);
 if(subject==4) return float(local.x>.22 && local.x<.79 && local.y<.54);
 if(subject==7) return float(local.y<.55);
 return 1.-smoothstep(.80,1.,length((local-center)/extent));
}

// A static head/neck cutout in the doctor's 362-pixel cells. The original
// atlas supplies every pixel outside it, retaining the exact body animation,
// clothing, hands and jukebox. This selects drawings; it never moves pixels.
bool doctor_head(vec2 p){
 vec2 edge[11]=vec2[11](vec2(120.,0.),vec2(211.,0.),vec2(211.,48.),
  vec2(194.,56.),vec2(184.,64.),vec2(181.,82.),vec2(174.,87.),
  vec2(162.,74.),vec2(155.,60.),vec2(140.,66.),vec2(124.,71.));
 bool inside=false;
 int previous=10;
 for(int i=0;i<11;i++){
  vec2 a=edge[i];
  vec2 b=edge[previous];
  if((a.y>p.y)!=(b.y>p.y)){
   if(p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) inside=!inside;
  }
  previous=i;
 }
 return inside;
}

vec4 sample_pose(vec2 uv){
 vec2 sheet_size=vec2(textureSize(atlas_texture,0));
 vec2 texel=1.0/sheet_size;
 vec2 cell=floor(uv*vec2(4.,3.));
 vec2 cell_min=cell/vec2(4.,3.)+texel*.5;
 vec2 cell_max=(cell+vec2(1.))/vec2(4.,3.)-texel*.5;
 uv=clamp(uv,cell_min,cell_max);
 vec4 c=texture(atlas_texture,uv);
 if(subject==3 && doctor_head(fract(uv*vec2(4.,3.))*362.)){
  c=texture(doctor_portrait,uv);
 }
 if(subject==0 && c.a>.98){
  vec4 n=texture(atlas_texture,clamp(uv+vec2(texel.x,0.),cell_min,cell_max));
  vec4 s=texture(atlas_texture,clamp(uv-vec2(texel.x,0.),cell_min,cell_max));
  vec4 e=texture(atlas_texture,clamp(uv+vec2(0.,texel.y),cell_min,cell_max));
  vec4 w=texture(atlas_texture,clamp(uv-vec2(0.,texel.y),cell_min,cell_max));
  if(min(min(n.a,s.a),min(e.a,w.a))>.98){
   vec3 detail=c.rgb-(n.rgb+s.rgb+e.rgb+w.rgb)*.25;
   c.rgb=clamp(c.rgb+clamp(detail*.85,vec3(-.075),vec3(.075)),0.,1.);
  }
 }
 return c;
}
void fragment(){
 vec4 pose=sample_pose(UV);
 // These three atlases retain the moving upper body, hands and props. Hold
 // only stationary furniture and planted legs to the registered first pose.
 // Selection is hard at the seam to avoid doubled outlines from crossfading.
 if(idle && (subject==5 || subject==6 || subject==7)){
  vec2 local=fract(UV*vec2(4.,3.));
  bool still=false;
  if(subject==5){
   still=local.y>.51 || (local.y>.35 && (local.x<.13 || local.x>.70));
  } else if(subject==6){
   still=local.y>.65 || (local.y>.37 && local.x<.20) || (local.y>.50 && local.x>.86);
  } else {
   still=local.y>.68;
  }
  if(still) pose=sample_pose(local/vec2(4.,3.));
 }
 if(idle && subject!=8 && subject!=7 && subject!=5 && subject!=6){
  vec2 local=fract(UV*vec2(4.,3.));
  vec2 centers[8]=vec2[8](vec2(.54,.22),vec2(.34,.25),vec2(.51,.24),vec2(.44,.26),vec2(.50,.24),vec2(.34,.24),vec2(.50,.28),vec2(.51,.25));
  vec2 sizes[8]=vec2[8](vec2(.19,.25),vec2(.17,.26),vec2(.18,.26),vec2(.17,.26),vec2(.22,.23),vec2(.22,.24),vec2(.24,.27),vec2(.14,.25));
  float w=moving_region(local,centers[subject],sizes[subject]);
  pose=mix(sample_pose(local/vec2(4.,3.)),pose,w);
 }
 // Hold planted lower details to a registered drawing. These boundaries are
 // below the moving hands, cue ball, and stretcher opening.
 if(subject!=3 && subject!=7 && subject!=5 && subject!=6){
  vec2 local=fract(UV*vec2(4.,3.));
  float start=subject==4 || subject==5 ? .68 : .80;
  if(subject==8) start=.72;
  float fixed_furniture=smoothstep(start,start+.035,local.y);
  pose=mix(pose,sample_pose(local/vec2(4.,3.)),fixed_furniture);
 }
 if(subject==3){
  vec2 local=fract(UV*vec2(4.,3.));
  // Keep the cabinet on one drawing. Only the reaching hand crosses it;
  // the circular light is added to that same registered drawing below.
  bool cabinet=local.x>.59 && local.y>.14;
  // The fingertip extends slightly past the old .66 boundary as she presses
  // the controls. Keep the full hand in the animated drawing at that height.
  float hand_top=choice_frame==5 ? .385 : .35;
  bool reaching=choice_frame>=2 && choice_frame<=5 && local.x<.69 && local.y>hand_top && local.y<.45;
  if(cabinet && !reaching){
   pose=sample_pose(local/vec2(4.,3.));
  }
  // Light the complete window after choosing the hand/cabinet drawing, so
  // neither of those selection boundaries can cut a straight edge in it.
  if(choice_frame>=5){
   vec2 p=(local-vec2(.635,.335))/vec2(.071,.060);
   float glow=1.0-smoothstep(.70,1.0,length(p));
   pose.rgb=mix(pose.rgb,pose.rgb*vec3(1.30,1.18,.82)+vec3(.12,.065,.008),glow*.78);
  }
 }
 if(subject==4){
  vec2 local=fract(UV*vec2(4.,3.));
  // Fix the trolley's top and end rails, leaving the hands and vial free.
  float tabletop=smoothstep(.58,.62,local.y);
  float left=smoothstep(.43,.46,local.y)*(1.0-smoothstep(.31,.34,local.x));
  float right=smoothstep(.50,.53,local.y)*smoothstep(.77,.80,local.x);
  pose=mix(pose,sample_pose(local/vec2(4.,3.)),max(tabletop,max(left,right)));
 }
 COLOR=pose*tint;
}
