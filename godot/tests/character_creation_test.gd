extends SceneTree
const Creation = preload("res://scripts/character_creation/character_creation.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var scene := (load("res://character_creation.tscn") as PackedScene).instantiate() as Creation
	var confirmed_jobs: Array[String] = []
	scene.character_confirmed.connect(func(occupation: String): confirmed_jobs.append(occupation))
	root.size = Vector2i(1920,1080)
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(scene.back.visible and not scene.confirm.visible,"Character creation opens without Confirm")
	check(scene.back.z_index>scene.actors[0].z_index and scene.info_panel.z_index>scene.actors[8].z_index,"Menu and details draw above room")
	for i in range(scene.actors.size()):
		var actor := scene.actors[i]
		var frames := actor.visual.sprite_frames
		check(frames.get_frame_count("idle")==4 and frames.get_frame_count("choice")==8,"Frame counts for %d" % i)
		check(actor.visual.material == null,"Atlas draws directly without corrective shader or overlay")
		var sheet_path: String = scene.ATLAS_PATH % scene.JOBS[i][3]
		for animation in ["idle","choice"]:
			for frame in range(frames.get_frame_count(animation)):
				var drawing := frames.get_frame_texture(animation,frame) as AtlasTexture
				check(drawing.atlas.resource_path == sheet_path,"Every frame uses the corrected atlas copy")
		var reference_points = [Vector2(190,350),Vector2(428,312),Vector2(618,310),Vector2(830,235),Vector2(835,480),Vector2(1090,330),Vector2(1300,455),Vector2(1510,285),Vector2(1110,670)]
		var uv = reference_points[i]/Vector2(1672,941)
		check(scene.character_at(uv)==i,"Character hit target %d" % i)
		scene.update_hover(uv)
		check(scene.active_group==actor.group,"Group hit target %d" % i)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = scene.stage.get_global_transform_with_canvas()*(uv*scene.ROOM_SIZE)
		root.push_input(click,true)
		check(scene.selected==i and scene.confirm.visible,"Mouse selection %d" % i)
		check(scene.details.text.contains(scene.JOBS[i][0].to_upper()),"Details match selection")
		actor.tick(0.5,1.0)
		check(actor.visual.animation=="idle","Hover plays idle")
		var shown = {}
		for step in range(24):
			actor.tick(1.0/6.0,1.0)
			shown[actor.visual.frame] = true
		check(shown.size()==4,"Hover cycles four distinct atlas frames")
		var expected_shadow := frames.get_frame_texture("idle",actor.visual.frame)
		check(actor.shadow.last_frame==expected_shadow,"Cast shadow matches the rendered idle drawing")
		if i in [4,8]:
			check(actor.shadow.contacts.points.size()==4,"Trolley and stretcher include the obscured caster contact")
		scene.update_hover(Vector2(0,0))
		check(scene.active_group==actor.group,"Selection holds spotlight when pointer leaves")
		actor.tick(0.5,0.0)
		check(actor.visual.frame==0,"Dark character remains still without cast shadow")
		scene.confirm_selection()
		check(scene.cinema_time==0.0 and not scene.confirm.visible,"Confirm starts cinematic")
		var prior := scene.selected
		# Mouse cannot switch the chosen character during the cinematic.
		click.position = scene.size*Vector2(0.1,0.4)
		root.push_input(click,true)
		check(scene.selected==prior,"Selection locks during cinematic")
		scene.advance_cinematic(0.5)
		check(actor.action_time>=0.0,"Choice animation starts after short beat")
		actor.tick(3.19,1.0)
		check(actor.visual.animation=="choice" and actor.visual.frame==7,"Choice reaches final unique pose")
		check(actor.visual.position.distance_to(actor.registered_offset)<60.0,"Frame registration stays fixed")
		scene.advance_cinematic(3.5)
		check(scene.world.scale.x>1.5 and scene.fade.modulate.a==0.0,"Slow zoom precedes fade")
		scene.advance_cinematic(0.89)
		check(scene.actors[i].modulate.r>0.99 and scene.actors[(i+1)%9].modulate.r<0.02,"Only confirmed survivor remains lit")
		check(scene.fade.z_index>scene.actors[i].z_index,"Final fade covers all characters")
		scene.advance_cinematic(0.51)
		check(scene.fade.modulate.a==1.0 and confirmed_jobs.size()==i+1 and confirmed_jobs.back()==scene.JOBS[i][0],"Chosen occupation is emitted after full black")
		scene.advance_cinematic(1.0)
		check(confirmed_jobs.size()==i+1,"Confirmation emits exactly once")
		scene.deselect_character()
	# Exercise all three cancellation paths and physical window scaling.
	for cancel_type in range(3):
		scene.select_character(1)
		if cancel_type==0: scene.cancel.pressed.emit()
		elif cancel_type==1:
			var right_click = InputEventMouseButton.new()
			right_click.button_index = MOUSE_BUTTON_RIGHT
			right_click.pressed = true
			root.push_input(right_click,true)
		else:
			var escape = InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			root.push_input(escape,true)
		check(scene.back.visible and scene.selected==-1 and not scene.confirm.visible,"Cancel leaves chooser open")
	for window_size in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1920,1080)]:
		root.size = window_size
		await process_frame
		var p = Vector2(428,312)
		var screen_point = scene.stage.get_screen_transform()*p
		var back_to_scene = scene.stage.get_screen_transform().affine_inverse()*screen_point
		check(scene.character_at(back_to_scene/Vector2(1672,941))==1,"Card player hit registration after resize")
	for job in range(9):
		scene.select_character(job)
		scene.confirm_selection()
		var start_focus = scene.FOCUS[job]
		scene.advance_cinematic(2.0)
		var mid_focus = scene.world.transform*start_focus
		scene.advance_cinematic(2.0)
		var end_focus = scene.world.transform*start_focus
		check(mid_focus.distance_to((start_focus+end_focus)/2.0)<0.1,"Direct zoom path without swing")
		check(Rect2(0,0,1672,941).has_point(mid_focus),"Selected subject remains on screen")
		scene.deselect_character()
	# Render each group and final action with real GPU shader compilation.
	for group in range(4):
		var light = Vector4.ZERO
		light[group] = 1.0
		scene.material_room.set_shader_parameter("lights",light)
		for actor in scene.actors: actor.tick(0.0,1.0 if actor.group==group else 0.0)
		scene.lighting = light
		await capture("user://character-creation-group-%d.png" % group)
	# Inspect the last action pose after zoom, before fade, for every occupation.
	for i in range(9):
		scene.select_character(i)
		scene.confirm_selection()
		scene.advance_cinematic(0.5)
		var light = Vector4.ZERO
		var group: int = scene.JOBS[i][1]
		light[group] = 1.0
		scene.material_room.set_shader_parameter("lights",light)
		for actor in scene.actors: actor.tick(3.2,1.0 if actor.group==group else 0.0)
		scene.advance_cinematic(3.5)
		scene.lighting = light
		await capture("user://character-creation-choice-%d.png" % i)
		scene.deselect_character()
	if DisplayServer.get_name() != "headless" and "--motion-review" in OS.get_cmdline_user_args():
		await review_motion(scene)
	print("Character creation: ",checks," checks, ",failures," failures")
	quit(failures)

func review_motion(scene: Creation) -> void:
	# Contact sheets are actual viewport crops, including occlusion and camera composition.
	for i in range(9):
		scene.select_character(i)
		scene.confirm_selection()
		scene.set_process(false)
		var actor = scene.actors[i]
		var strip = Image.create_empty(1024,768,false,Image.FORMAT_RGBA8)
		var light = Vector4.ZERO
		light[actor.group] = 1.0
		scene.material_room.set_shader_parameter("lights",light)
		scene.lighting = light
		for j in range(12):
			actor.reset()
			var t = 0.0
			if j>=4:
						actor.begin_choice()
						for k in range(j-4): t += actor.ACTION_HOLDS[i][k]
						t += 0.01
			for other in scene.actors:
						other.tick(t if j>=4 else [0.1,0.8,1.6,3.75][j],light[other.group])
			await process_frame
			await RenderingServer.frame_post_draw
			var img = root.get_texture().get_image()
			var rect = scene.PLACEMENTS[i].grow(20)
			rect.size.x = maxf(rect.size.x,rect.size.y)
			var area = Rect2i(rect.position*Vector2(img.get_size())/Vector2(1672,941),rect.size*Vector2(img.get_size())/Vector2(1672,941))
			var crop = img.get_region(area.intersection(Rect2i(Vector2i.ZERO,img.get_size())))
			crop.resize(256,256,Image.INTERPOLATE_LANCZOS)
			strip.blit_rect(crop,Rect2i(0,0,256,256),Vector2i(j%4,j/4)*256)
		strip.save_png("user://character-creation-motion-%d.png"%i)
		scene.deselect_character()
