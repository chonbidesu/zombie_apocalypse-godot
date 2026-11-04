extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.initial_world_mode = "sandbox"
 root.add_child(scene)
 await process_frame
 await process_frame
 var dlabel = scene.page.get_node("LocationDescription")
 check(dlabel.get_visible_line_count() == dlabel.get_line_count(),"All rendered description lines fit including spacing")
 var opening_actors = scene.page.get_node("SceneActors")
 var opening_target = opening_actors.get_node("Actor_1")
 check(opening_target.size.y >= 100,"NPC sprites use enlarged scene targets")
 var red_bars = opening_target.get_children().filter(func(node): return node is Panel)
 check(red_bars.size() == 2 and red_bars[0].size.y == 8 and red_bars[0].size.x <= 34,"Health bars are thicker and narrower")
 scene.set_process(false)
 var p = scene.sim.player()
 var start_time = scene.sim.minute
 for i in range(20): scene._process(0.1)
 check(scene.sim.minute == start_time+2,"Real-time clock advances while choosing actions")
 var mouse = InputEventMouseButton.new()
 mouse.button_index = MOUSE_BUTTON_LEFT
 mouse.pressed = true
 mouse.position = scene.action_controls.filter(func(entry): return entry.command == "search")[0].node.get_global_rect().get_center()
 root.push_input(mouse,true)
 mouse = mouse.duplicate()
 mouse.pressed = false
 root.push_input(mouse,true)
 await process_frame
 check(p.ap == 49 and scene.sim.minute == start_time+2,"Mouse search button commits action")
 for i in range(25): scene._process(0.1)
 start_time = scene.sim.minute
 var event = InputEventKey.new()
 event.keycode = KEY_RIGHT
 event.pressed = true
 Input.parse_input_event(event)
 await process_frame
 check(p.x == 5 and p.y == 4 and p.ap == 48,"Arrow input moves player and spends AP")
 scene.open_modal("map")
 var x = p.x
 Input.parse_input_event(event)
 await process_frame
 check(p.x == x,"Map blocks underlying movement")
 scene._process(3.0)
 check(scene.sim.minute == start_time,"Modal blocks simulation")
 scene.modal = ""
 for i in range(21): scene._process(0.1)
 check(scene.sim.minute == start_time+2,"Real-time pacing advances time while idle")
 scene.paused = true
 scene._process(3.0)
 Input.parse_input_event(event)
 await process_frame
 check(scene.sim.minute == start_time+2 and p.x == x,"Pause blocks clock and input")
 var space = InputEventKey.new()
 space.keycode = KEY_SPACE
 space.pressed = true
 scene._unhandled_key_input(space)
 check(not scene.paused,"Space resumes paused simulation")
 scene.sim.start()
 scene.feed.reset(scene.sim.messages)
 scene.selected_actor = 1
 scene.selected_item = scene.sim.player().inventory[0].uid
 scene.refresh()
 scene.dispatch("request",1)
 check(scene.sim.player().inventory.size() == 4 and scene.notice.contains("refuses"),"Untrusted UI supply request receives a refusal")
 for i in range(20): scene._process(0.1)
 scene.dispatch("equip",-1,{"uid":scene.selected_item})
 check(scene.sim.player().equipped == -1,"UI item equip toggles")
 scene.open_modal("skills")
 await process_frame
 check(scene.modal == "skills","Skill modal builds")
 scene.modal = ""
 for i in range(10): scene._process(0.1)
 scene.sim.player().busy_until = scene.sim.now()
 scene.sim.player().ap = 40
 scene.begin_rest(10)
 check(scene.resting and scene.rest_target == 50,"Rest starts with requested target")
 var escape = InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 Input.parse_input_event(escape)
 await process_frame
 check(not scene.resting,"Escape cancels rest")
 scene.sim.player().ap = 50
 scene.sim.die(scene.sim.player())
 scene.begin_rest(10)
 check(scene.resting,"Downed character at full AP can rest through standing cooldown")
 scene.resting = false
 var barricade_player = scene.sim.player()
 barricade_player.down = false
 barricade_player.human = true
 barricade_player.ap = 50
 barricade_player.busy_until = scene.sim.now()
 var construction_site = scene.sim.current_block(barricade_player)
 construction_site.doors = false
 scene.sim.set_barricade_strength(construction_site,0)
 scene.refresh()
 check(scene.action_controls.any(func(entry): return entry.command == "barricade"),"Open doors do not hide the Barricade action")
 scene.dispatch("barricade")
 check(construction_site.doors and scene.sim.barricade_strength(construction_site) == 1 and barricade_player.ap == 49,"UI barricading closes doors and adds the first point in one AP")
 barricade_player.busy_until = scene.sim.now()
 barricade_player.ap = 0
 scene.sim.set_barricade_strength(construction_site,21)
 scene.refresh()
 var cap_actions = scene.action_controls.filter(func(entry): return entry.command == "barricade")
 check(cap_actions.size() == 1 and not cap_actions[0].node.disabled,"Maximum-strength feedback is available even with no AP")
 scene.dispatch("barricade")
 check(scene.notice == "The barricade cannot be built any higher." and barricade_player.ap == 0,"UI maximum-strength attempt gives exact feedback without AP cost")
 barricade_player.ap = 50
 scene.sim.set_barricade_strength(scene.sim.current_block(barricade_player),10)
 scene.sim.give_item(barricade_player,"pistol")
 barricade_player.equipped = barricade_player.inventory.back().uid
 scene.refresh()
 check(not scene.action_controls.any(func(entry): return entry.command == "break"),"Ineffective firearms do not offer a barricade attack")
 barricade_player.equipped = -1
 scene.refresh()
 check(scene.action_controls.any(func(entry): return entry.command == "break"),"Human fists offer a barricade attack")
 var undead_player = scene.sim.player()
 undead_player.down = false
 undead_player.human = false
 undead_player.busy_until = scene.sim.now()
 undead_player.ap = 50
 scene.selected_actor = 1
 scene.selected_item = undead_player.inventory[0].uid
 scene.refresh()
 check(scene.action_controls.any(func(entry): return entry.command == "equip"),"Zombie inventory exposes equip for a carried bat")
 scene.dispatch("equip",-1,{"uid":scene.selected_item})
 check(undead_player.equipped == scene.selected_item,"Zombie can equip a bat through the interface")
 var attacks = scene.action_controls.filter(func(entry): return entry.command == "attack")
 check(attacks.size() == 2 and attacks.any(func(entry): return entry.node.text.begins_with("Claws")) and attacks.any(func(entry): return entry.node.text.begins_with("Swing weapon")),"Zombie UI keeps claws and tool swing separately available")
 check(scene.action_controls.any(func(entry): return entry.command == "bite"),"Bite remains available while wielding a tool")
 scene.sim.start()
 scene.feed.reset(scene.sim.messages)
 scene.selected_actor = -1
 scene.selected_item = -1
 scene.notice = "Welcome to Dulston. Explore, find supplies, and keep your neighbours alive."
 scene.refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 var image = root.get_texture().get_image()
 image.save_png("res://tests/prototype-preview.png")
 scene.open_modal("skills")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/skills-preview.png")
 scene.open_modal("help")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/help-preview.png")
 scene.modal = ""
 scene.sim.start()
 var player = scene.sim.player()
 player.busy_until = scene.sim.now()+10.0
 player.ap = 0
 scene.refresh()
 var commands = scene.action_controls.map(func(entry): return entry.command)
 check("search" in commands and "leave" in commands,"Relevant actions remain visible during AP/recovery limits")
 check("fuel" not in commands and "heal" not in commands and "attack" not in commands,"Unavailable inventory and target actions are hidden")
 player.inside = false
 player.busy_until = scene.sim.now()
 player.ap = 50
 scene.sim.current_block(player).barricade = 5
 scene.refresh()
 var entries = scene.action_controls.filter(func(entry): return entry.command == "enter")
 check(entries.size() == 1 and not entries[0].node.disabled,"Heavy barricade does not disable Enter")
 check(scene.portrait_region({"hp":50,"human":true,"down":false}).position.x < 6*66,"Healthy face uses first animation")
 check(scene.portrait_region({"hp":30,"human":true,"down":false}).position.x >= 6*66,"Injured face uses second animation")
 check(scene.portrait_region({"hp":10,"human":true,"down":false}).position.x >= 12*66,"Critical face uses third animation")
 check(scene.portrait_region({"hp":0,"human":false,"down":true}).position.x == 18*66,"Downed face uses death frame")
 check(scene.portrait_region({"hp":25,"human":false,"down":false}).position.x >= 19*66,"Zombie face uses undead animation")
 var block = scene.sim.current_block(player)
 block.generator = true
 block.fuel_until = scene.sim.minute+20
 var lit = scene.tile_background(block)
 block.fuel_until = 0
 check(scene.tile_background(block) != lit,"Viewport background changes when power runs out")
 block.ruin = 3
 check(scene.tile_background(block) == Color("303238"),"Ruins use dark grey")
 block.fuel_until = scene.sim.minute+20
 check(scene.tile_background(block) == Color("303238"),"Ruin appearance takes priority over light")
 var zombie = scene.sim.actors[15]
 zombie.x = player.x
 zombie.y = player.y
 zombie.inside = player.inside
 zombie.down = false
 scene.sim.reindex()
 var people = scene.ordered_people()
 var saw_zombie = false
 var grouped = true
 for actor in people:
  if not actor.human: saw_zombie = true
  elif saw_zombie: grouped = false
 check(grouped and saw_zombie,"Human cards precede zombie cards regardless of actor order")
 for job in ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse"]:
  var sheet = scene.C.occupation_sheet(job,job != "Corpse")
  var asset = scene.tex("sprite_sheets/"+sheet+"_sprite_sheet.png")
  check(asset != null and scene.actor_region(scene.sim.player(),asset).size.x > 0 and (asset.get_width() > asset.get_height()*8 or asset.get_width()*2 == asset.get_height()*3),"Complete original animation sheet: "+job)
 scene.animation_time = 0.0
 var zombie_pose = scene.portrait_region({"hp":25,"human":false,"down":false})
 scene.animation_time = 0.4
 check(scene.portrait_region({"hp":25,"human":false,"down":false}) == zombie_pose,"Zombie portrait holds rigid before lurching")
 scene.animation_time = 0.56
 check(scene.portrait_region({"hp":25,"human":false,"down":false}) != zombie_pose,"Zombie portrait jerks to a different pose")
 scene.refresh()
 check(scene.page.get_node("LocationDescription").text == scene.sim.location_description(player),"Full generated location description is displayed")
 scene.sim.blocks[45].ruin = 3
 scene.sim.blocks[34].generator = true
 scene.sim.blocks[34].fuel_until = scene.sim.minute+20
 scene.refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/location-preview.png")
 # Put every NPC together to verify fitting, hit targets and two opposing groups.
 scene.sim.start()
 player = scene.sim.player()
 for actor in scene.sim.actors:
  actor.x = player.x
  actor.y = player.y
  actor.inside = player.inside
  actor.down = false
 scene.sim.reindex()
 scene.selected_actor = -1
 scene.refresh()
 var layer = scene.page.get_node("SceneActors")
 check(layer.get_child_count() == scene.sim.actors.size()-1,"Every NPC fits directly into the scene")
 var fits = true
 var no_stats = true
 for target in layer.get_children():
  var bounds = target.get_rect()
  if not scene.ENVIRONMENT_RECT.encloses(bounds): fits = false
  if "AP" in target.tooltip_text or "HP" in target.tooltip_text: no_stats = false
 check(fits and no_stats,"Staggered crowd stays in the scene with no unearned AP/HP details")
 layer.get_node("Actor_1").pressed.emit()
 check(scene.selected_actor == 1,"Scene sprites remain selectable")
 var descriptions_fit = true
 for block_to_test in scene.sim.blocks:
  player.x = block_to_test.x
  player.y = block_to_test.y
  for inside in [true,false]:
   player.inside = inside
   block_to_test.generator = true
   block_to_test.fuel_until = scene.sim.minute+10
   block_to_test.ruin = 3
   var text = scene.sim.location_description(player)
   if scene.description_height(text,scene.description_font_size(text)) > 190: descriptions_fit = false
 check(descriptions_fit,"Interior and exterior descriptions fit without scrollbars")
 player.x = 4
 player.y = 4
 player.inside = true
 scene.sim.reindex()
 scene.refresh()
 check(scene.page.get_node("LocationDescription") is Label,"Description uses a non-scrolling overlay")
 var world_rng = scene.sim.rng.state
 scene.zombie_pose(30.0)
 var durations = {}
 var previous_end = 0.0
 for segment in scene.lurch_segments:
  durations[snappedf(segment.until-previous_end,0.01)] = true
  previous_end = segment.until
 check(durations.size() > 10 and scene.sim.rng.state == world_rng,"Lurch timing varies without consuming simulation randomness")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/crowded-scene-preview.png")
 scene.sim.die(player)
 scene.refresh()
 check(scene.page.has_node("DarkMinimap") and scene.page.has_node("DarkEnvironment") and not scene.page.has_node("SceneActors"),"Downed view blacks out minimap, environment and NPCs")
 check(scene.selected_actor == -1 and not scene.log_view.visible and scene.log_view.text.is_empty(),"Downed view clears targets and hides activity")
 scene._process(0.1)
 check(not scene.log_view.visible and scene.log_view.text.is_empty(),"Pending feed updates cannot reveal activity while down")
 scene.open_modal("map")
 check(scene.overlay.find_children("*","TextureRect",true,false).is_empty(),"Downed full map reveals no tile art")
 scene.open_modal("history")
 check(scene.overlay.find_children("*","RichTextLabel",true,false).is_empty(),"Downed history cannot reveal events")
 scene.modal = ""
 scene.refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/downed-preview.png")
 player.ready_at = scene.sim.minute
 player.ap = 50
 player.busy_until = scene.sim.now()
 scene.dispatch("stand")
 check(not player.down and scene.page.has_node("SceneActors") and scene.log_view.visible,"Standing restores scene and activity")
 scene.sim.start()
 player = scene.sim.player()
 var site = scene.sim.current_block(player)
 site.generator = true
 site.generator_hp = 2
 site.fuel_until = scene.sim.minute+10
 site.ruin = 0
 site.last_pounding = scene.sim.minute
 site.barricade = 7
 var max_text_fits = true
 for site_to_test in scene.sim.blocks:
  for inside in [true,false]:
   player.x = site_to_test.x
   player.y = site_to_test.y
   player.inside = inside
   scene.refresh()
   await process_frame
   var paragraph = scene.page.get_node("LocationDescription")
   if paragraph.get_visible_line_count() != paragraph.get_line_count() or paragraph.position.y+paragraph.size.y > 370: max_text_fits = false
 check(max_text_fits,"All locations render their entire description within the text area")
 player.x = 4
 player.y = 4
 player.inside = true
 scene.refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/context-description-preview.png")
 scene.sim.start()
 scene.feed.reset(scene.sim.messages)
 scene.notice = "Nearby voices carry through the shelter."
 player = scene.sim.player()
 var speaker = scene.sim.actors[1]
 scene.sim.speak(speaker,"Clean dressings are worth their weight in gold.")
 scene.feed.ingest(scene.sim.messages)
 scene.refresh()
 await process_frame
 var speech = scene.page.get_node("SceneActors/Speech_1")
 check(speech.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Speech bubble does not intercept sprite selection")
 var words = speech.get_child(0)
 check(words.get_visible_line_count() == words.get_line_count(),"All speech text fits the bubble")
 var speaker_target = scene.page.get_node("SceneActors/Actor_1")
 check(speech.position.y+speech.size.y <= speaker_target.position.y,"Human speech bubble sits above the speaker")
 check(scene.log_view.text.contains(speaker.speech),"Bubble utterance is also displayed in chat")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/dialogue-preview.png")
 scene.sim.speak(speaker,"I wish we had a working light.")
 scene.refresh()
 scene.page.get_node("SceneActors/Actor_1").pressed.emit()
 check(scene.selected_actor == 1,"Speaking character remains selectable")
 speaker.speech_until = scene.sim.now()-1
 scene.refresh()
 check(not scene.page.has_node("SceneActors/Speech_1"),"Expired bubbles disappear")
 var groaner = scene.sim.actors[15]
 groaner.x = player.x
 groaner.y = player.y
 groaner.inside = player.inside
 groaner.down = false
 scene.sim.reindex()
 scene.sim.speak(groaner,"*a wet, rattling moan*")
 scene.feed.ingest(scene.sim.messages)
 scene.refresh()
 check(scene.page.has_node("SceneActors/Speech_15") and scene.log_view.text.contains("rattling moan"),"Zombie groans appear above its sprite and in chat")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/zombie-dialogue-preview.png")
 scene.sim.die(player)
 scene.refresh()
 check(not scene.page.has_node("SceneActors") and not scene.log_view.visible,"Downed view hides all speech bubbles and dialogue")
 scene.sim.start()
 scene.feed.reset(scene.sim.messages)
 player = scene.sim.player()
 scene.selected_actor = 1
 scene.selected_item = -1
 scene.refresh()
 scene.dispatch("request",1)
 await process_frame
 check(scene.page.has_node("SceneActors/Speech_1") and scene.notice.contains("refuses"),"Supply refusal appears in both chat feedback and an NPC bubble")
 check(scene.page.get_node("SceneActors/Actor_1").tooltip_text.contains("Wary"),"NPC tooltip describes current trust")
 var all_icons = true
 for kind in scene.C.ITEMS:
  if scene.tex("items/"+kind+".png") == null: all_icons = false
 check(all_icons,"Every weapon, shell and supply item has an existing icon")
 player.busy_until = scene.sim.now()
 scene.sim.give_item(player,"shotgun")
 scene.sim.give_item(player,"shotgun_shell")
 var shotgun = scene.sim.item_kind(player,"shotgun")
 shotgun.ammo = 0
 scene.selected_item = shotgun.uid
 scene.dispatch("equip",-1,{"uid":shotgun.uid})
 player.busy_until = scene.sim.now()
 scene.refresh()
 var reloads = scene.action_controls.filter(func(entry): return entry.command == "reload")
 check(reloads.size() == 1 and not reloads[0].node.disabled,"Shotgun shell enables the same visible Reload action")
 scene.dispatch("reload")
 check(shotgun.ammo == 1 and scene.sim.item_kind(player,"shotgun_shell").is_empty(),"UI reload dispatch consumes exactly one shell")
 scene.sim.start()
 scene.feed.reset(scene.sim.messages)
 player = scene.sim.player()
 scene.refresh()
 var centre = scene.page.get_node("MapTile_44")
 var mini_labels = centre.find_children("*","Label",true,false)
 check(not mini_labels.any(func(node): return node.text == "YOU" or node.text == "LIT"),"Centre minimap tile has no YOU or LIT label")
 var powered_tile = scene.page.get_node("MapTile_45")
 check(powered_tile.get_node("MapArt").material == null,"Powered building artwork is displayed without recoloring")
 check(not powered_tile.find_children("*","Label",true,false).any(func(node): return node.text == "LIT"),"Power is conveyed without a LIT label")
 check(scene.tile_background(scene.sim.blocks[45]) == Color("d8c477"),"Powered buildings retain a yellow outline")
 scene.sim.blocks[34].ruin = 3
 scene.refresh()
 check(scene.page.get_node("MapTile_34/MapArt").material != null,"Ruined minimap artwork gets the desaturated grey overlay")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/minimap-outline-preview.png")
 scene.sim.current_block(player).type = "junkyard"
 scene.sim.current_block(player).doors = false
 scene.refresh()
 check(not scene.action_controls.any(func(entry): return entry.command == "close"),"Junkyard UI omits Close doors")
 var crowded_site = scene.sim.current_block(player)
 crowded_site.graffiti = "A long survivor message. ".repeat(20).left(255)
 crowded_site.decorations = ["painting","pottery","tapestry","statue","skeleton","stuffed_animal","glass_piece","sculpture","painting","tapestry","painting","pottery","statue"]
 scene.refresh()
 await process_frame
 var decorated_text = scene.page.get_node("LocationDescription")
 check(decorated_text.get_visible_line_count() == decorated_text.get_line_count() and decorated_text.position.y+decorated_text.size.y <= 370,"Full decoration capacity and long graffiti stay inside description bounds")
 check(not scene.page.get_node("MapTile_34").find_children("*","Label",true,false).any(func(node): return node.text == "RUIN"),"Ruins use the grey overlay without a RUIN label")
 scene.open_modal("skills")
 var skill_scroll = scene.overlay.get_node("FullSkillTrees")
 check(skill_scroll is ScrollContainer and skill_scroll.find_children("*","Button",true,false).size() == 45,"All forty-five skill purchase controls fit in scrolling trees")
 scene.modal = ""
 for occupation in ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse"]:
  player.job = occupation
  player.human = true
  player.down = false
  player.hp = 50
  player.human_skills.clear()
  scene.animation_time = 0
  var portrait = scene.portrait_texture(player)
  var cell = Vector2(portrait.get_width()/5.0,portrait.get_height()/5.0)
  check(scene.portrait_region(player).position == Vector2.ZERO,"Healthy portrait starts on first atlas frame: "+occupation)
  player.hp = 25
  check(scene.portrait_region(player).position == Vector2(0,cell.y),"Injured portrait uses second row: "+occupation)
  player.hp = 10
  check(scene.portrait_region(player).position == Vector2(0,cell.y*2),"Critical portrait uses third row: "+occupation)
  player.down = true
  var dead = scene.portrait_region(player)
  scene.animation_time += 2
  check(scene.portrait_region(player) == dead and dead.position == Vector2(0,cell.y*3),"Dead portrait is static: "+occupation)
  player.down = false
  player.human = false
  check(scene.portrait_region(player) != dead,"Undead portrait uses separate lurch frames: "+occupation)
 scene.animation_time = 100
 player.human = true
 scene.sim.set_pose(player,"attack")
 check(scene.actor_frame(player) == 8,"Combat starts on the existing attack frames")
 scene.animation_time += 0.35
 check(scene.actor_frame(player) in range(9,15),"Attack animation advances through the sheet")
 scene.sim.set_pose(player,"hurt")
 check(scene.actor_frame(player) == 21,"Damage starts on existing hurt frames")
 player.down = true
 scene.sim.set_pose(player,"die")
 check(scene.actor_frame(player) == 15,"Death starts on existing collapse frames")
 scene.animation_time += 1
 check(scene.actor_frame(player) == 20,"Death settles on final unmoving frame")
 player.down = false
 scene.sim.set_pose(player,"idle")
 scene.actor_frame(player)
 var human_changes = 0
 var zombie_changes = 0
 var previous_human = -1
 var previous_zombie = -1
 for step in range(100):
  scene.animation_time = 200+step*0.1
  player.human = true
  var human_frame = scene.actor_frame(player)
  player.human = false
  var zombie_frame = scene.actor_frame(player)
  if human_frame != previous_human: human_changes += 1
  if zombie_frame != previous_zombie: zombie_changes += 1
  previous_human = human_frame
  previous_zombie = zombie_frame
 check(zombie_changes < human_changes/2,"Zombie gait uses slower holds and uneven stepping")
 print("UI CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
