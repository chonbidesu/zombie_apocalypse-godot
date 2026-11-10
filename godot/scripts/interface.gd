extends Control

var initial_world_mode: String = "malton"
var map_origin: Vector2i = Vector2i(-1,-1)
var city_overview: bool = false
var new_world_mode: String = "malton"
var new_world_config: Dictionary = {}
var new_seed: int = Sim.DEFAULT_SEED
var new_occupation: String = "Private"
var new_difficulty: String = "medium"
var new_game_error: String = ""

const Sim = preload("res://scripts/simulation.gd")
const Feed = preload("res://scripts/event_feed.gd")
const C = preload("res://scripts/catalog.gd")
const MapArtwork = preload("res://scripts/minimap_art.gd")
const MapCanvas = preload("res://scripts/minimap_canvas.gd")
const GameMusic = preload("res://scripts/game_music.gd")
var minimap_artwork := MapArtwork.new()
const ENVIRONMENT_RECT = Rect2(402,161,1016,572)
const INVENTORY_PAGE_SIZE = 10
var inventory_page: int = 0
var foot_bounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tables/actor_frame_bounds.json"))
const INK = Color("101b18")
const PANEL = Color("1c2b25")
const CREAM = Color("ece4ca")
const MUTED = Color("a8b6a5")
const GOLD = Color("d8b76b")
const RED = Color("df8d77")
const GREEN = Color("a9c69a")

var sim: Sim
var simulation_backlog: float = 0.0
var save_path: String = Sim.SAVE_PATH
var page: Control
var overlay: Control
var selected_actor: int = -1
var selected_item: int = -1
var paused: bool = false
var modal: String = ""
var resting: bool:
 get: return sim.resting
var rest_target: int:
 get: return sim.rest_target
var feed := Feed.new()
var log_view: RichTextLabel
var log_filter: String = "All"
var history_filter: String = "All"
var refresh_timer: float = 0.0
var last_revision: String = ""
var action_controls: Array[Dictionary] = []
var timing_label: Label
var notice: String = "Welcome to Dulston. Explore, find supplies, and keep your neighbours alive."
var textures: Dictionary = {}
var actor_buttons: Array[Dictionary] = []
var actor_visuals: Dictionary = {}
var actor_tooltip: PanelContainer
var actor_tooltip_label: Label
var animation_time: float = 0.0
var context_open: bool = false
var mall_store: String = "drugstore"
var message_command: String = "say"
var message_target: int = -1
var message_data: Dictionary = {}
var actions_bottom: float = 971.0
var player_portrait: TextureRect
var lurch_rng := RandomNumberGenerator.new()
var lurch_segments: Array = [{"until":0.55,"frame":0}]
@onready var game_music := get_node_or_null("GameMusic") as GameMusic

func _ready() -> void:
 lurch_rng.randomize()
 var ui_theme := Theme.new()
 ui_theme.default_font = load("res://assets/fonts/PixelifySans.ttf")
 ui_theme.default_font_size = 19
 var italic := FontVariation.new()
 italic.base_font = ui_theme.default_font
 italic.variation_transform = Transform2D(Vector2.RIGHT,Vector2(-0.22,1),Vector2.ZERO)
 ui_theme.set_font("italics_font","RichTextLabel",italic)
 theme = ui_theme
 if sim == null:
  sim = Sim.new()
  var why := sim.start(Sim.DEFAULT_SEED,"Volunteer",{"mode":initial_world_mode})
  if not why.is_empty():
   sim.start()
   notice = why
  else: notice = "Welcome to %s. Find allies and secure a shelter." % sim.world_title
 _reset_session_view()
 refresh()

func _process(delta: float) -> void:
 _animate_scene(delta)
 if paused or context_open or not modal.is_empty(): return
 _advance_session(delta)

func _animate_scene(delta: float) -> void:
 _update_actor_tooltip()
 animation_time += delta
 for entry in actor_buttons:
  if is_instance_valid(entry.node):
   position_actor_sprite(entry)
 if is_instance_valid(player_portrait):
  player_portrait.texture.region = portrait_region(sim.player())

func _advance_session(delta: float) -> void:
 var was_resting := resting
 var was_down: bool = sim.player().down
 simulation_backlog += delta
 var elapsed := minf(simulation_backlog,0.25)
 simulation_backlog -= elapsed
 sim.elapse(elapsed)
 if was_down != sim.player().down: refresh()
 if was_resting and not resting: notice = sim.last_rest_notice
 var feed_changed := feed.ingest(sim.messages)
 if feed.update(delta): feed_changed = true
 if feed_changed: _update_log()
 for entry in action_controls:
  if is_instance_valid(entry.node):
   var why := sim.action_feedback(sim.player(),entry.command,entry.target,entry.data)
   entry.node.disabled = resting or not why.is_empty()
   entry.node.tooltip_text = why if not why.is_empty() else entry.tip
 if is_instance_valid(timing_label): timing_label.text = _timing_text()
 refresh_timer += delta
 var revision := "%d/%d/%d/%s" % [sim.minute,sim.event_sequence,sim.player().ap,resting]
 if refresh_timer >= 0.25 and revision != last_revision and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
  refresh_timer = 0.0
  last_revision = revision
  refresh()

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_F11:
  toggle_fullscreen()
  return
 if event.keycode == KEY_ESCAPE:
  if not modal.is_empty(): modal = ""
  elif resting:
   sim.stop_rest("You wake up." if sim.sleeping else "Rest cancelled.")
   notice = sim.last_rest_notice
  else: paused = not paused
  refresh()
  return
 if event.keycode == KEY_SPACE and not context_open and modal.is_empty():
  paused = not paused
  refresh()
  return
 if paused or resting or context_open or not modal.is_empty(): return
 var moves = {KEY_W:Vector2i(0,-1), KEY_UP:Vector2i(0,-1), KEY_S:Vector2i(0,1), KEY_DOWN:Vector2i(0,1), KEY_A:Vector2i(-1,0), KEY_LEFT:Vector2i(-1,0), KEY_D:Vector2i(1,0), KEY_RIGHT:Vector2i(1,0), KEY_Q:Vector2i(-1,-1), KEY_E:Vector2i(1,-1), KEY_Z:Vector2i(-1,1), KEY_C:Vector2i(1,1)}
 if moves.has(event.keycode):
  var direction = moves[event.keycode]
  dispatch("move", -1, {"dx":direction.x, "dy":direction.y})
 elif event.keycode == KEY_R: begin_rest(10)
 elif event.keycode == KEY_M: open_city_map()

func tex(path: String) -> Texture2D:
 if not textures.has(path):
  textures[path] = load("res://assets/"+path) if ResourceLoader.exists("res://assets/"+path) else null
 return textures[path]

func rect(parent: Node, bounds: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
 var panel = Panel.new()
 panel.position = bounds.position
 panel.size = bounds.size
 var style = StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = border
 style.set_border_width_all(1)
 panel.add_theme_stylebox_override("panel", style)
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(panel)
 return panel

func label(parent: Node, text: String, bounds: Rect2, font_size: int = 20, color: Color = CREAM) -> Label:
 var node = Label.new()
 node.position = bounds.position
 node.size = bounds.size
 node.text = text
 node.add_theme_font_size_override("font_size", font_size)
 node.add_theme_color_override("font_color", color)
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 node.clip_text = true
 parent.add_child(node)
 return node

func picture(parent: Node, texture: Texture2D, bounds: Rect2) -> TextureRect:
 var node = TextureRect.new()
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.stretch_mode = TextureRect.STRETCH_SCALE
 node.texture = texture
 node.position = bounds.position
 node.size = bounds.size
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(node)
 return node

func button(parent: Node, text: String, bounds: Rect2, callback: Callable, accent: bool = false) -> Button:
 var node = Button.new()
 node.text = text
 node.position = bounds.position
 node.size = bounds.size
 node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 node.focus_mode = Control.FOCUS_NONE
 var style = StyleBoxFlat.new()
 style.bg_color = Color("3b4c38") if accent else Color("283a30")
 style.border_color = GOLD if accent else Color("51614b")
 style.set_border_width_all(1)
 node.add_theme_stylebox_override("normal", style)
 var hover = style.duplicate()
 hover.bg_color = Color("4b5c3d")
 hover.border_color = GOLD
 node.add_theme_stylebox_override("hover", hover)
 var pressed = style.duplicate()
 pressed.bg_color = INK
 node.add_theme_stylebox_override("pressed", pressed)
 var disabled = style.duplicate()
 disabled.bg_color = Color("202922")
 disabled.border_color = Color("354038")
 node.add_theme_stylebox_override("disabled", disabled)
 node.add_theme_color_override("font_color", CREAM)
 node.add_theme_color_override("font_disabled_color", Color("778074"))
 node.add_theme_font_size_override("font_size", 18)
 node.pressed.connect(callback)
 parent.add_child(node)
 return node

func refresh() -> void:
 if not is_instance_valid(page):
  page = Control.new()
  page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  add_child(page)
  move_child(page,0)
 for child in page.get_children():
  # Hover and tooltip timing belong to the actor controls across refreshes.
  if child.name == "SceneActors" and not sim.player().down and not sim.sleeping: continue
  page.remove_child(child)
  child.queue_free()
 actor_buttons.clear()
 action_controls.clear()
 var p = sim.player()
 var b = sim.current_block(p)
 if p.down: selected_actor = -1
 if selected_actor >= sim.actors.size() or (selected_actor >= 0 and not sim.nearby(p, sim.actors[selected_actor])): selected_actor = -1
 if sim.item_by_uid(p, selected_item).is_empty(): selected_item = -1
 _header()
 _local_map()
 _status()
 _rest_controls()
 _inventory()
 _location(b)
 _people()
 _actions()
 _log()
 rect(page, Rect2(20, 1044, 1880, 28), INK)
 label(page, "You are asleep. Wake to return to the city." if sim.sleeping else (sim.location_description(p) if p.down else notice), Rect2(28, 1045, 1860, 26), 18, GOLD)
 if paused:
  rect(page, Rect2(400, 85, 1020, 52), Color("2c3526"), GOLD)
  label(page, "PAUSED  /  Press Escape or Resume to continue", Rect2(420, 90, 980, 40), 25, GOLD)
 if not modal.is_empty(): _modal()
 if is_instance_valid(log_view): log_view.visible = modal.is_empty() and not p.down and not sim.sleeping
 _update_actor_tooltip()

func _header() -> void:
 rect(page, Rect2(0, 0, 1920, 74), Color("111d18"))
 label(page, "MALTON", Rect2(22, 5, 210, 44), 39, CREAM)
 label(page, sim.world_title.to_upper()+"  /  SURVIVAL", Rect2(24, 47, 400, 22), 15, GOLD)
 label(page, sim.time_text(), Rect2(270, 15, 270, 30), 24, GOLD)
 label(page, "LIVE · %s" % ("%d×" % sim.time_speed()), Rect2(570, 15, 146, 40), 23, GOLD)
 button(page, "Resume" if paused else "Pause", Rect2(726, 15, 95, 40), func(): paused = not paused; refresh())
 button(page, "Map [M]", Rect2(831, 15, 105, 40), open_city_map)
 button(page, "Skills", Rect2(946, 15, 90, 40), func(): open_modal("skills"))
 button(page, "Save", Rect2(1046, 15, 80, 40), _save)
 button(page, "Load", Rect2(1136, 15, 80, 40), _load)
 button(page, "Help", Rect2(1226, 15, 80, 40), func(): open_modal("help"))
 button(page, "Restart", Rect2(1316, 15, 104, 40), func(): open_modal("restart"))
 var fullscreen_button = button(page,"Full screen [F11]",Rect2(1440,15,190,40),toggle_fullscreen)
 fullscreen_button.name = "FullscreenToggle"

func toggle_fullscreen() -> void:
 var fullscreen = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
 refresh()

func _local_map() -> void:
 var p = sim.player()
 if p.down or sim.sleeping:
  var darkness = rect(page, Rect2(20,88,358,414), Color.BLACK)
  darkness.name = "DarkMinimap"
  return
 picture(page, tex("panels/viewport_frame.png"), Rect2(20, 88, 358, 358))
 var city = map_region(page,Rect2i(p.x-1,p.y-1,3,3),Vector2(40,108),106)
 city.name = "CityMinimap"
 for dy in range(-1, 2):
  for dx in range(-1, 2):
   var bounds = Rect2((dx+1)*106, (dy+1)*106, 106, 106)
   if p.x+dx not in range(sim.width) or p.y+dy not in range(sim.height):
    rect(city, bounds, INK)
    continue
   var b = sim.block_at(p.x+dx, p.y+dy)
   var tile = button(city, "", bounds, func(): dispatch("move", -1, {"dx":dx,"dy":dy}), dx == 0 and dy == 0)
   tile.name = "MapTile_%d" % b.id
   tile.flat = true
   tile.z_index = 1000
   tile.disabled = paused or resting or (dx == 0 and dy == 0)
   tile.tooltip_text = map_site_tooltip(b) + "\nMove: %d AP" % sim.cost(p,"move")
   if b.type == "gatehouse" and not b.fort.is_empty(): tile.tooltip_text += "\nOnly fort entrance: enter the gatehouse to access the grounds."
   if dx == 0 and dy == 0:
    var outline = rect(tile,Rect2(0,0,106,106),Color.TRANSPARENT,GOLD)
    outline.get_theme_stylebox("panel").set_border_width_all(1)
   necrotech_mark(tile,b,Vector2(42,27),19)
   _minimap_population(tile,b,p,p.inside if dx == 0 and dy == 0 else false)
 var caption = sim.suburb_name(p).to_upper()
 if not sim.item_kind(p,"gps_unit").is_empty():
  caption += "  ·  [%02d, %02d]" % [p.x,p.y]
 var caption_font = 24
 while caption_font > 14 and theme.default_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_font).x > 350: caption_font -= 1
 label(page,caption,Rect2(24,451,350,28),caption_font,GOLD).name = "MinimapCaption"
 label(page, "Click to move • Arrows / WASD • QEZC", Rect2(24,480,355,22), 15, MUTED)

func _minimap_population(tile: Button, b: Dictionary, p: Dictionary, inside: bool) -> void:
 var visible = sim.occupants(b,inside)
 var names: Array[String] = []
 var captions: Array[String] = []
 var colours: Array[Color] = []
 for person in visible:
  if person.id == p.id or not person.human or person.down: continue
  var name = sim.display_name(person)
  var condition = sim.survivor_condition(p,person)
  var hp = sim.sees_survivor_hp(p,person)
  var infected = sim.has_skill(p,"scent_blood") and person.infected
  var prefix = "" if condition.is_empty() else "* "
  if hp: prefix += "%d HP · " % person.hp
  captions.append(prefix+name)
  if not condition.is_empty(): name += " · "+condition
  if hp: name += " · %d HP" % person.hp
  if infected: name += " · Infected"
  names.append(name)
  colours.append(Color("b7ef9e") if infected else GREEN)
 var sensed = sim.occupants(b) if not p.human and sim.has_skill(p,"scent_death") else visible
 var zombies = sensed.filter(func(person): return person.id != p.id and not person.down and not person.human).size()
 var rows: Array[String] = []
 rows.assign(captions.slice(0,3))
 if names.size() > 3: rows.append("…")
 if zombies > 0: rows.append("%d zombie%s" % [zombies,"" if zombies == 1 else "s"])
 var y = 103-rows.size()*14
 for i in range(rows.size()):
  var undead_row = zombies > 0 and i == rows.size()-1
  rect(tile,Rect2(3,y,100,13),Color(0.04,0.07,0.05,0.90))
  var colour = RED if undead_row else (colours[i] if i < mini(3,colours.size()) else GREEN)
  var caption = label(tile,rows[i],Rect2(6,y-1,94,15),12,colour)
  caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  y += 14
 if not names.is_empty(): tile.tooltip_text += "\n" + ", ".join(names)
 if zombies > 0: tile.tooltip_text += "\n" + rows.back()
 var tracked = sim.scent_trail_target(p)
 if not tracked.is_empty() and tracked.x == b.x and tracked.y == b.y:
  var marker = rect(tile,Rect2(74,4,29,17),INK)
  marker.name = "ScentTrail"
  label(marker,"Trail",Rect2(3,0,25,17),11,GOLD)
  tile.tooltip_text += "\n" + sim.scent_trail_text(p)

func _status() -> void:
 var p = sim.player()
 rect(page, Rect2(20, 511, 358, 139), PANEL, Color("4e5847"))
 var atlas = AtlasTexture.new()
 atlas.atlas = portrait_texture(p)
 atlas.region = portrait_region(p)
 player_portrait = picture(page, atlas, Rect2(24,518,98,98))
 label(page, sim.display_name(p), Rect2(124,521,245,28), 24)
 label(page, ("SURVIVOR" if p.human else "UNDEAD") + (" / ASLEEP" if sim.sleeping else (" / DOWN" if p.down else " / STANDING")), Rect2(124,550,245,24), 16, GREEN if p.human else RED)
 var health = label(page,"%d / %d HP · %d XP" % [p.hp,sim.max_hp(p),p.xp],Rect2(124,578,245,28),18)
 health.name = "PlayerHealth"
 rect(page, Rect2(31,638,334,6), INK)
 rect(page, Rect2(31,638,334*clampf(float(p.ap)/50.0,0.0,1.0),6), GOLD)
 var energy = label(page,"%02d / 50 AP" % p.ap,Rect2(124,608,111,26),16,GOLD)
 energy.name = "PlayerEnergy"
 label(page, "+1 AP / 30 min", Rect2(238,609,133,24), 14, MUTED)

func _rest_controls() -> void:
 var rest = button(page,("Wake" if sim.sleeping else "Cancel rest") if resting else "Rest +10 AP [R]",Rect2(24,658,171,30),func():
  if resting: sim.stop_rest("You wake up." if sim.sleeping else "Rest cancelled."); notice = sim.last_rest_notice; refresh()
  else: begin_rest(10),true)
 rest.add_theme_font_size_override("font_size",16)
 rest.disabled = paused
 var full = button(page,"Sleep",Rect2(203,658,171,30),begin_sleep)
 full.name = "SleepButton"
 full.tooltip_text = "Sleep until 50 AP at 128× speed. Barricades collapsing or sustained damage can wake you."
 full.add_theme_font_size_override("font_size",16)
 full.disabled = resting or paused
 timing_label = label(page,_timing_text(),Rect2(24,691,350,22),14,GOLD)

func _inventory() -> void:
 var p = sim.player()
 if p.down or sim.sleeping:
  rect(page,Rect2(20,720,358,184),Color.BLACK)
  return
 rect(page,Rect2(20,720,358,184),PANEL,Color("4e5847"))
 var load_percent = sim.encumbrance(p)
 var title = label(page,"INVENTORY  %d%% / 100%%" % load_percent,Rect2(32,725,332,24),18,RED if load_percent >= 100 else GOLD)
 title.tooltip_text = "Collection stops at 100 items or 100% encumbrance. Use or drop items to make room. A final find below 100% may exceed the weight limit."
 var pages = maxi(1,ceili(float(p.inventory.size())/INVENTORY_PAGE_SIZE))
 inventory_page = clampi(inventory_page,0,pages-1)
 for slot_index in range(INVENTORY_PAGE_SIZE):
  var bounds = Rect2(32+(slot_index%5)*67,753+(slot_index/5)*47,61,44)
  var i = inventory_page*INVENTORY_PAGE_SIZE+slot_index
  if i >= p.inventory.size():
   rect(page,bounds,INK,Color("35483a"))
   continue
  var item = p.inventory[i]
  var slot = button(page,"",bounds,func(): selected_item = item.uid; refresh(),item.uid == selected_item)
  slot.name = "InventoryItem_%d" % item.uid
  slot.tooltip_text = "%s · %d%% encumbrance" % [C.ITEMS[item.kind].name,C.ITEMS[item.kind].encumbrance]
  if item.kind == "radio": slot.tooltip_text += " · %.2f MHz" % float(item.frequency)
  if item.kind == "spray_can": slot.tooltip_text += " · %d sprays left" % sim.paint_remaining(p,item)
  slot.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: _item_menu(item))
  picture(slot,tex("items/"+item.kind+".png"),Rect2(11,1,39,39))
  if item.uid == p.equipped: label(slot,"E",Rect2(3,23,20,20),16,GOLD)
  if C.ITEMS[item.kind].has("capacity"): label(slot,str(item.ammo),Rect2(40,24,20,18),14,CREAM)
 var previous = button(page,"<",Rect2(32,849,38,23),func(): inventory_page -= 1; selected_item = -1; refresh())
 previous.name = "InventoryPrevious"
 previous.disabled = inventory_page == 0
 var next = button(page,">",Rect2(322,849,38,23),func(): inventory_page += 1; selected_item = -1; refresh())
 next.name = "InventoryNext"
 next.disabled = inventory_page >= pages-1
 label(page,"%d / %d · %d items" % [inventory_page+1,pages,p.inventory.size()],Rect2(77,849,239,23),16,MUTED)
 _action_button("equip","Equip",Rect2(32,879,100,24),-1,{"uid":selected_item})
 _action_button("give","Give",Rect2(141,879,100,24),selected_actor,{"uid":selected_item})
 _action_button("drop","Drop",Rect2(250,879,110,24),-1,{"uid":selected_item})

func _location(b: Dictionary) -> void:
 var p = sim.player()
 if p.down or sim.sleeping:
  var darkness = rect(page,Rect2(400,84,1020,851),Color.BLACK)
  darkness.name = "DarkEnvironment"
  label(page,"ASLEEP" if sim.sleeping else "EVERYTHING IS DARK",Rect2(420,250,980,40),27,MUTED)
  var down_text = label(page,"The city fades away. You will awaken at 50 AP, or if collapsing barricades or sustained injuries disturb you." if sim.sleeping else sim.location_description(p),Rect2(420,303,980,62),20,MUTED)
  down_text.name = "LocationDescription"
  down_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  return
 label(page, b.name.to_upper(), Rect2(400,84,1010,38), 31, CREAM)
 var subtitle = "%s / %s" % ["INSIDE" if p.inside else "OUTSIDE", C.pretty(sim.visible_type(b,p))]
 if sim.is_building(b):
  subtitle += " · %s · %s" % [sim.barricade_description(b).capitalize(), "Lights on" if sim.powered(b) else "Unpowered"]
  if b.ruin >= 3 or p.inside or sim.entrance_is_open(b):
   subtitle += " · " + ("Ruined" if b.ruin >= 3 else ("Ransacked" if b.ruin > 0 else "Intact"))
 label(page,subtitle,Rect2(402,124,690 if b.type == "mall" and sim.has_skill(p,"shopping") else 1005,26),19,MUTED)
 var filename = "settings/%s_%s.png" % ["office" if b.type == "necrotech_lab" and not p.inside else b.type, "inside" if p.inside else "outside"]
 rect(page,Rect2(400,159,1020,576),INK,GOLD)
 var art = picture(page,tex(filename),ENVIRONMENT_RECT)
 art.name = "EnvironmentArt"
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.clip_contents = true
 if not p.inside: necrotech_mark(page,b,Vector2(895,365),28)
 var text = sim.location_description(p)
 var font_size = description_font_size(text)
 var height = description_height(text,font_size)
 rect(page,Rect2(400,745,1020,190),PANEL,Color("4e5847"))
 var description = label(page,text,Rect2(416,753,987,height),font_size,CREAM)
 description.name = "LocationDescription"
 description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 description.add_theme_constant_override("line_spacing",3)
 description.clip_text = true

func description_height(text: String, font_size: int) -> float:
 var measured = theme.default_font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,987,font_size,-1,TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
 var lines = ceili(measured.y/theme.default_font.get_height(font_size))
 return measured.y+maxi(0,lines-1)*3+6.0

func description_font_size(text: String) -> int:
 var font_size = 20
 while font_size > 12 and description_height(text,font_size) > 174: font_size -= 1
 return font_size

func _people() -> void:
 var p = sim.player()
 if p.down or sim.sleeping: return
 var people = ordered_people().filter(func(a): return a.id != 0)
 var humans = people.filter(func(a): return appears_human(a))
 var zombies = people.filter(func(a): return not appears_human(a))
 var lanes = maxi(1,ceili(float(people.size())/14.0))
 var columns = maxi(1,ceili(float(humans.size())/lanes)+ceili(float(zombies.size())/lanes))
 var spacing = minf(92.0,950.0/columns)
 var size = 132.0 if lanes == 1 else 112.0
 var entries: Array = []
 for group in [humans,zombies]:
  var cols = maxi(1,ceili(float(group.size())/lanes))
  for i in range(group.size()):
   var row = i/cols
   var col = i%cols
   var offset = 12.0 if col%2 == 1 else 0.0
   var x = 416+col*spacing+row*spacing*0.18 if appears_human(group[i]) else 1404-(col+1)*spacing-row*spacing*0.18
   var floor_y = ENVIRONMENT_RECT.end.y-2-row*43-offset
   entries.append({"actor":group[i],"x":x,"floor":floor_y,"size":size})
 entries.sort_custom(func(a,b): return a.floor < b.floor)
 var actors_layer = page.get_node_or_null("SceneActors")
 if actors_layer == null:
  actors_layer = Control.new()
  actors_layer.name = "SceneActors"
  actors_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
  page.add_child(actors_layer)
 else: page.move_child(actors_layer,-1)
 var visible_ids = {}
 for a in people: visible_ids["Actor_%d" % a.id] = true
 for child in actors_layer.get_children():
  if visible_ids.has(str(child.name)): continue
  actors_layer.remove_child(child)
  child.queue_free()
 var speaking: Array = []
 for entry in entries:
  var a = entry.actor
  var bounds = Rect2(entry.x,entry.floor-entry.size,spacing-2,entry.size-2)
  var target_name = "Actor_%d" % a.id
  var target = actors_layer.get_node_or_null(target_name)
  if target == null:
   var id: int = a.id
   target = button(actors_layer,"",bounds,func(): selected_actor = id; refresh())
   target.name = target_name
   var clear = StyleBoxFlat.new()
   clear.bg_color = Color.TRANSPARENT
   clear.set_border_width_all(1)
   target.add_theme_stylebox_override("normal",clear)
   var hover = clear.duplicate()
   hover.bg_color = Color(1,1,1,0.06)
   hover.border_color = GOLD
   target.add_theme_stylebox_override("hover",hover)
  target.position = bounds.position
  target.size = bounds.size
  actors_layer.move_child(target,-1)
  target.get_theme_stylebox("normal").border_color = GOLD if selected_actor == a.id else Color.TRANSPARENT
  var human_appearance = appears_human(a)
  var tooltip: String
  if a.down:
   tooltip = "Revivifying body" if human_appearance else "Dead body"
  else:
   tooltip = "%s · %s" % [sim.display_name(a),a.job if a.human else "Zombie"]
   if a.human: tooltip += " · " + sim.trust_description(a,p)
  var condition = sim.survivor_condition(p,a)
  var scent_health = sim.sees_survivor_hp(p,a)
  var infected = a.human and not a.down and a.infected and sim.has_skill(p,"scent_blood")
  if not condition.is_empty(): tooltip += " · "+condition.capitalize()
  if scent_health: tooltip += " · %d/%d HP" % [a.hp,sim.max_hp(a)]
  if infected: tooltip += " · Infected"
  target.set_meta("actor_infected",infected)
  target.set_meta("actor_tooltip",tooltip)
  for child in target.get_children():
   target.remove_child(child)
   child.queue_free()
  var sheet = C.occupation_sheet(a.job,human_appearance)
  var atlas = AtlasTexture.new()
  atlas.atlas = tex("sprite_sheets/"+sheet+"_sprite_sheet.png")
  atlas.region = actor_region(a,atlas.atlas)
  var shadow = Polygon2D.new()
  var vertices = PackedVector2Array()
  for point in range(16):
   var angle = TAU*point/16
   vertices.append(Vector2(spacing/2+cos(angle)*15,entry.size-12+sin(angle)*3))
  shadow.polygon = vertices
  shadow.color = Color(0,0,0,0.25)
  target.add_child(shadow)
  var sprite = picture(target,atlas,Rect2((spacing-entry.size)/2,0,entry.size,entry.size))
  sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  if a.down: sprite.modulate = Color(0.55,0.55,0.55)
  var visual = {"node":sprite,"id":a.id,"offset":a.id%8,"sheet":sheet,"size":entry.size,"ground":entry.size-12}
  position_actor_sprite(visual)
  actor_buttons.append(visual)
  if scent_health:
   var bar_width = minf(34.0,spacing*0.48)
   rect(target,Rect2((spacing-bar_width)/2,entry.size-11,bar_width,8),Color("290d0d"))
   rect(target,Rect2((spacing-bar_width)/2,entry.size-11,bar_width*clampf(float(a.hp)/sim.max_hp(a),0,1),8),Color("c63f37"))
  if not a.down and not a.speech.is_empty() and a.speech_until > sim.now(): speaking.append({"actor":a,"bounds":bounds})
 for entry in speaking: _speech_bubble(actors_layer,entry.actor,entry.bounds)

func _update_actor_tooltip() -> void:
 var hovered = get_viewport().gui_get_hovered_control()
 var show_tooltip = modal.is_empty() and not context_open and not sim.player().down and not sim.sleeping
 if not show_tooltip or not is_instance_valid(hovered) or not hovered.is_inside_tree() or not hovered.has_meta("actor_tooltip"):
  if is_instance_valid(actor_tooltip): actor_tooltip.hide()
  return
 if not is_instance_valid(actor_tooltip):
  actor_tooltip = PanelContainer.new()
  actor_tooltip.name = "ActorTooltip"
  actor_tooltip.z_index = 1900
  actor_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var style = StyleBoxFlat.new()
  style.bg_color = INK
  style.border_color = GOLD
  style.set_border_width_all(1)
  style.set_content_margin_all(7)
  actor_tooltip.add_theme_stylebox_override("panel",style)
  actor_tooltip_label = Label.new()
  actor_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  actor_tooltip_label.add_theme_color_override("font_color",CREAM)
  actor_tooltip_label.add_theme_font_size_override("font_size",16)
  actor_tooltip.add_child(actor_tooltip_label)
  add_child(actor_tooltip)
 var text: String = hovered.get_meta("actor_tooltip")
 if actor_tooltip_label.text != text:
  actor_tooltip_label.text = text
  actor_tooltip.reset_size()
 actor_tooltip_label.add_theme_color_override("font_color",Color("b7ef9e") if hovered.get_meta("actor_infected",false) else CREAM)
 var at = get_local_mouse_position() + Vector2(14,18)
 var limit = get_viewport_rect().size - actor_tooltip.size
 actor_tooltip.position = at.clamp(Vector2.ZERO,limit.max(Vector2.ZERO))
 actor_tooltip.show()

func _actions() -> void:
 var p = sim.player()
 if sim.sleeping:
  actions_bottom = 940
  return
 if p.inside and sim.current_block(p).type == "mall" and sim.has_skill(p,"shopping"):
  var stores = OptionButton.new()
  stores.position = Vector2(1110,125)
  stores.size = Vector2(300,28)
  for store in C.MALL_STORES:
   stores.add_item(C.pretty(store))
   if store == mall_store: stores.select(stores.item_count-1)
  stores.item_selected.connect(func(index): mall_store = C.MALL_STORES.keys()[index])
  page.add_child(stores)
 var options: Array = []
 if p.down:
  options = [["stand","Stand up",-1]]
 elif p.human:
  options = [["leave" if p.inside else "enter", "Leave" if p.inside else "Enter", -1], ["search","Search",-1], ["attack","Attack",selected_actor], ["heal","Heal self",0], ["heal","Heal ally",selected_actor], ["revive","Revive",selected_actor], ["barricade","Barricade" if sim.has_skill(p,"construction") else "Use pipe",-1], ["repair","Repair building" if sim.current_block(p).ruin >= 3 else "Repair the room",-1], ["repair_generator","Fix generator",-1], ["dump","Dump body",selected_actor], ["close","Close doors",-1], ["request","Ask supplies",selected_actor], ["reload","Reload",-1], ["break","Break cades",-1], ["generator","Install gen.",-1], ["fuel","Fuel gen.",-1], ["scan","Access NecroNet",-1], ["manufacture","Manufacture syringe",-1]]
 else:
  options = [["leave" if p.inside else "enter", "Leave" if p.inside else "Enter", -1], ["attack","Claws",selected_actor,{"unarmed":true}], ["bite","Bite",selected_actor], ["close","Close doors",-1], ["break","Break cades",-1], ["ruin" if sim.current_block(p).get("ransack_hits",0) >= 5 else "ransack", "Ruin building" if sim.current_block(p).get("ransack_hits",0) >= 5 else "Ransack",-1], ["destroy_generator","Smash gen.",-1]]
  var weapon = sim.item_by_uid(p,p.equipped)
  if not weapon.is_empty() and weapon.kind in C.ZOMBIE_MELEE_ITEMS: options.append(["attack","Swing weapon",selected_actor])
 if not p.down:
  if p.inside and sim.current_block(p).type in C.TALL_BUILDINGS: options.append(["jump","Jump from a window",-1])
  options.append_array([["say","Speak",-1],["scout","Scout shelter",-1],["extract","DNA sample",selected_actor],["tag","Spray tag",-1],["install_radio","Set up radio",-1],["repair_radio","Fix radio",-1],["broadcast","Broadcast",-1],["phone","Phone",selected_actor],["tune","Tune receiver",-1],["tune_transmitter","Tune transmitter",-1],["lookout","Binoculars",-1],["view_map","Open map",-1],["locate","GPS",-1],["feed","Feed",selected_actor],["drag","Drag prey",selected_actor],["groan","Groan",-1],["bellow","Bellow",-1],["gesture","Gesture",selected_actor],["smell","Scent death",-1],["destroy_radio","Smash radio",-1],["smash_decorations","Smash decor",-1],["flare","Signal flare",-1]])
 options = options.filter(func(option): return sim.action_feedback(p,option[0],option[2],option[3] if option.size() > 3 else {},true).is_empty())
 var slot = 0
 for option in options:
  var span = 2 if option[0] in ["jump","manufacture","scan"] else 1
  if slot%10+span > 10: slot += 10-slot%10
  _action_button(option[0],option[1],Rect2(400+(slot%10)*102,944+(slot/10)*31,span*102-4,28),option[2],option[3] if option.size() > 3 else {})
  slot += span
 actions_bottom = 944+ceili(float(slot)/10)*31

func _timing_text() -> String:
 if sim.sleeping: return "SLEEP 128×  ·  %d / 50 AP" % sim.player().ap
 if sim.player().down and sim.time_speed() > 1: return "DOWN %d× · Recovering to stand" % sim.time_speed()
 if resting: return "REST %d×  ·  %d / %d AP" % [int(sim.time_speed()),sim.player().ap,rest_target]
 var remaining = sim.player().busy_until-sim.now()
 if remaining > 0: return "Recovering: %.2fs  ·  %s" % [remaining,C.pretty(sim.player().last_action)]
 return "READY  ·  1 game minute / second"

func _action_button(command: String, text: String, bounds: Rect2, target: int = -1, data: Dictionary = {}) -> void:
 if command == "broadcast" and not data.has("frequency"): data = {"frequency":sim.suggested_transmit_frequency(sim.player())}
 if not sim.action_feedback(sim.player(),command,target,data,true).is_empty(): return
 var ap_cost = sim.cost(sim.player(),command,target,data)
 var caption = text + (" · %d" % ap_cost if ap_cost > 0 else "")
 var node = button(page, caption, bounds, func():
  if command in ["tag","say","gesture","broadcast","phone","tune","tune_transmitter"]:
   message_command = command
   message_target = target
   message_data = data.duplicate()
   open_modal("message")
  elif command == "jump" and sim.player().human: open_modal("jump")
  else: dispatch(command,target,data))
 node.add_theme_font_size_override("font_size", 14)
 var caption_size = 14
 while caption_size > 11 and theme.default_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x > bounds.size.x-10: caption_size -= 1
 node.add_theme_font_size_override("font_size",caption_size)
 node.clip_text = true
 node.size = bounds.size
 var why = sim.action_feedback(sim.player(),command,target,data)
 node.disabled = not why.is_empty() or paused or resting
 var tip = "%s: %d AP • %.2fs recovery. No clock jump." % [text,ap_cost,sim.recovery(command)]
 node.tooltip_text = why if not why.is_empty() else tip
 action_controls.append({"node":node,"command":command,"target":target,"data":data,"tip":tip})

func _log() -> void:
 if sim.player().down or sim.sleeping:
  var darkness = rect(page,Rect2(1440,88,460,946),Color.BLACK)
  darkness.name = "DarkDialogue"
  if is_instance_valid(log_view): log_view.text = ""
  return
 rect(page,Rect2(1440,88,460,946),PANEL,Color("4e5847"))
 label(page,"DIALOGUE & ACTIVITY",Rect2(1452,96,285,26),19,GOLD)
 button(page,"History",Rect2(1794,96,94,26),func(): open_modal("history"))
 for i in range(4):
  var choice = ["All","You","Allies","Hostiles"][i]
  button(page,choice,Rect2(1452+i*110,132,104,28),func(): log_filter = choice; _update_log(); refresh(),log_filter == choice)
 if not is_instance_valid(log_view):
  log_view = RichTextLabel.new()
  log_view.name = "DialogueFeed"
  log_view.add_theme_color_override("default_color",CREAM)
  log_view.bbcode_enabled = true
  log_view.scroll_following = true
  add_child(log_view)
 log_view.position = Vector2(1454,172)
 log_view.size = Vector2(432,848)
 log_view.add_theme_font_size_override("normal_font_size",18)
 _update_log()

func _update_log() -> void:
 if not is_instance_valid(log_view): return
 if sim.player().down or sim.sleeping:
  log_view.text = ""
  log_view.visible = false
  return
 var bar = log_view.get_v_scroll_bar()
 var was_at_end = bar.value >= bar.max_value-bar.page-3
 var old_scroll = bar.value
 var content = feed.format_rows(feed.rows,log_filter)
 if log_view.text == content: return
 log_view.scroll_following = was_at_end
 log_view.text = content
 if not was_at_end: bar.set_deferred("value",old_scroll)

func dispatch(command: String, target: int = -1, data: Dictionary = {}) -> void:
 if paused or resting or not modal.is_empty(): return
 if command == "lookout" and sim.player().inside and not data.has("direction"):
  var why = sim.action_feedback(sim.player(),command)
  if why.is_empty(): open_modal("binocular_compass")
  else:
   notice = why
   refresh()
  return
 if command == "search": data = {"store":mall_store}
 var result = sim.act(command,target,data)
 if result.ok and command == "view_map":
  open_city_map()
  return
 notice = result.message if not result.ok else (sim.messages.back().text if not sim.messages.is_empty() else "")
 feed.ingest(sim.messages)
 if result.ok and command == "smell": modal = "scent_death"
 elif result.ok and command == "scan": modal = "necronet"
 elif result.ok and command == "lookout": modal = "binocular_survey"
 elif result.ok and command == "locate": modal = "intelligence"
 refresh()

func begin_sleep() -> void:
 if paused or not modal.is_empty(): return
 var rejection = sim.begin_sleep()
 notice = rejection if not rejection.is_empty() else sim.last_rest_notice
 feed.ingest(sim.messages)
 refresh()

func begin_rest(amount: int) -> void:
 if paused or not modal.is_empty(): return
 var rejection = sim.begin_rest(amount)
 notice = rejection if not rejection.is_empty() else sim.last_rest_notice
 feed.ingest(sim.messages)
 refresh()

func _save() -> void:
 if resting: sim.stop_rest()
 notice = "Saved to " + ProjectSettings.globalize_path(save_path) if sim.save_to(save_path) == OK else "Could not save."
 refresh()

func _load() -> void:
 var result := sim.load_from(save_path)
 notice = "Loaded your neighbourhood." if result.is_empty() else result
 if result.is_empty(): _reset_session_view()
 refresh()

func _reset_session_view() -> void:
 simulation_backlog = 0.0
 map_origin = Vector2i(-1,-1)
 city_overview = false
 inventory_page = 0
 actor_visuals.clear()
 selected_actor = -1
 selected_item = -1
 feed.reset(sim.messages)
 if game_music: game_music.restart_playlist()

func open_modal(which: String) -> void:
 if resting: sim.stop_rest()
 modal = which
 refresh()

func _modal() -> void:
 overlay = Control.new()
 overlay.z_index = 2000
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_STOP
 page.add_child(overlay)
 overlay.position = Vector2(240,60)
 rect(overlay, Rect2(-240,-60,1920,1080), Color(0.01,0.03,0.02,0.92))
 rect(overlay, Rect2(100,80,1240,800), PANEL, GOLD)
 label(overlay, {"map":sim.world_title.to_upper()+" / FIELD MAP", "skills":"SKILLS / ONE LIFE, TWO FORMS", "help":"SURVIVING DULSTON", "history":"EVENT HISTORY / PAUSED", "restart":"NEW GAME / WORLD SETUP", "jump":"LEAVE HUMAN LIFE BEHIND?","message":"COMMUNICATION","intelligence":"FIELD INTELLIGENCE","scent_death":"SCENT DEATH","necronet":"NECRONET SCAN","binocular_compass":"ROOFTOP BINOCULARS","binocular_survey":"BINOCULAR SURVEY"}[modal], Rect2(130,99,1050,48), 32, GOLD)
 button(overlay, "Close [Esc]", Rect2(1170,103,140,38), func(): modal = ""; refresh())
 if modal == "message": _message_modal()
 elif modal == "intelligence":
  var report = RichTextLabel.new()
  report.position = Vector2(140,170)
  report.size = Vector2(1160,670)
  report.text = sim.sense_report
  overlay.add_child(report)
 elif modal == "scent_death": _scent_death_modal()
 elif modal == "necronet": _necronet_modal()
 elif modal == "binocular_compass": _binocular_compass_modal()
 elif modal == "binocular_survey": _binocular_survey_modal()
 elif modal == "map": _map_modal()
 elif modal == "skills": _skills_modal()
 elif modal == "history" and sim.player().down:
  rect(overlay,Rect2(130,160,1180,690),Color.BLACK)
  label(overlay,"You cannot observe any activity while down.",Rect2(160,420,1100,50),24,MUTED)
 elif modal == "history":
  for i in range(4):
   var choice = ["All","You","Allies","Hostiles"][i]
   button(overlay,choice,Rect2(140+i*160,164,150,35),func(): history_filter = choice; refresh(),history_filter == choice)
  label(overlay,"Last 1,000 local events • exact order • no routine-event summaries",Rect2(140,210,1150,30),20,MUTED)
  var history = RichTextLabel.new()
  history.position = Vector2(140,255)
  history.size = Vector2(1160,590)
  history.bbcode_enabled = true
  history.scroll_following = true
  history.text = feed.format_rows(sim.messages,history_filter)
  overlay.add_child(history)
 elif modal == "help":
  var help_text = "Explore with the 3×3 map, arrow keys or WASD. Q/E/Z/C move diagonally.\nEnter buildings to search and find shelter. Free running links intact interiors.\n\nSelect a person, then attack, heal, revive, or ask for supplies.\nSelect an inventory item to equip, give, or drop it. Undead can wield crowbars, bats and pipes; claws are stronger.\n\nAP measures energy, not time. Everyone regains 1 AP / 30 game minutes.\nActions resolve once, then briefly recover. Extra clicks cannot queue or spam.\nThe world runs continuously: 1 game minute / second; resting speeds it to 16×.\nDanger interrupts ordinary rest. Sleep runs at 128× speed with dark screens;\ncollapsing barricades or sustained injuries wake you. Space pauses; menus pause too.\n\nDeath preserves your identity, XP, skills and possessions. Stand as a zombie;\nseek June at the lab east of Mercy General for revival. Brain Rot requires\na powered lab and NecroNet access. Both skill trees use the same XP pool.\n\nMaya heals, Scott repairs and barricades, guards defend, and June revives.\nKeep their supplies stocked. They have the same AP limits as you.\n\nPrototype balance: 50 AP; revival 1 AP (Brain Rot: 10); standing 10 AP (Death Lurch: 5, Ankle Grab: 1);\nsyringe manufacture 20 AP. This is a local sandbox, not the full city war.\n\nGold: you  •  Green: allies  •  Red: enemies / danger  •  Grey: world\nRoutine activity is grouped; History preserves all local details.\nSpace: pause    R: rest    M: map    F11: full screen    Escape: pause / close / wake / cancel rest"
  var body = label(overlay,help_text,Rect2(140,170,1160,680),21)
  body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 elif modal == "restart": _new_game_modal()
 elif modal == "jump":
  label(overlay,"Jumping from the window kills your survivor. You can spend AP to stand as a zombie.",Rect2(140,230,1140,60),24)
  button(overlay,"Jump from a window · 1 AP",Rect2(140,340,350,50),func(): modal = ""; dispatch("jump"),true)

func _binocular_compass_modal() -> void:
 var cost = sim.cost(sim.player(),"lookout")
 label(overlay,"Choose a direction to survey nine blocks for %d AP." % cost,Rect2(145,174,1120,38),23,MUTED)
 for direction in C.COMPASS_DIRECTIONS:
  var bearing: Vector2i = C.COMPASS_DIRECTIONS[direction]
  var at = Vector2(620,407)+Vector2(bearing)*Vector2(178,76)
  var choice = button(overlay,direction.capitalize(),Rect2(at,Vector2(164,62)),func():
   modal = ""
   dispatch("lookout",-1,{"direction":direction}))
  choice.name = "Look_"+direction
 label(overlay,"Roof",Rect2(674,422,80,30),24,GOLD)

func _binocular_survey_modal() -> void:
 var p = sim.player()
 var area: Rect2i = sim.binocular_area
 var outdoor: bool = sim.binocular_direction.is_empty()
 var stride = 79.0 if outdoor else 182.0
 var caption = "Street survey · 7 × 7 blocks" if outdoor else "Roof view · %s · 3 × 3 blocks" % sim.binocular_direction.capitalize()
 label(overlay,caption,Rect2(145,162,1050,30),24,GOLD)
 var grid = map_region(overlay,area,Vector2(145,211),stride,true)
 grid.name = "BinocularGrid"
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   var at = Vector2(Vector2i(x,y)-area.position)*stride
   var valid = x in range(sim.width) and y in range(sim.height)
   var frame = rect(grid,Rect2(at,Vector2.ONE*stride),Color.TRANSPARENT if valid else INK,GOLD if x == p.x and y == p.y else Color("465045"))
   frame.z_index = 1000
   if not valid: continue
   var b = sim.block_at(x,y)
   var humans = 0
   var zombies = 0
   for person in sim.occupants(b,false):
    if person.id == p.id or person.down: continue
    if person.human: humans += 1
    else: zombies += 1
   frame.mouse_filter = Control.MOUSE_FILTER_PASS
   frame.tooltip_text = map_site_tooltip(b)+"\nSurvivors outside  %d · Zombies outside  %d" % [humans,zombies]
   rect(frame,Rect2(2,stride-32,stride-4,30),Color(0.03,0.06,0.05,0.92))
   var name = label(frame,b.name,Rect2(4,stride-33,stride-8,16),12)
   name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
   label(frame,"%d H · %d Z" % [humans,zombies],Rect2(4,stride-18,stride-8,17),12,RED if zombies > 0 else GREEN)
 label(overlay,"Hover a block for barricades, power, damage and outdoor population.",Rect2(725,211,490,42),17,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 if not outdoor: return
 label(overlay,"Skyline landmarks",Rect2(725,276,480,32),24,GOLD)
 var landmarks = sim.skyline_landmarks(p)
 if landmarks.is_empty():
  label(overlay,"No landmarks on the nearby skyline.",Rect2(725,316,490,30),18,MUTED)
  return
 var scroll = ScrollContainer.new()
 scroll.position = Vector2(725,316)
 scroll.size = Vector2(510,433)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 overlay.add_child(scroll)
 var listing = VBoxContainer.new()
 listing.custom_minimum_size.x = 480
 scroll.add_child(listing)
 for i in range(landmarks.size()):
  var landmark = landmarks[i]
  var line = "%s · %d %s %s" % [landmark.site.name,landmark.distance,"block" if landmark.distance == 1 else "blocks",landmark.bearing]
  var entry = label(listing,line,Rect2(0,0,480,30),17,CREAM)
  entry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _necronet_color(kind: String) -> Color:
 match kind:
  "street": return Color("666b6c")
  "hospital": return Color("f4c1c7")
  "infirmary": return Color("e4a9bc")
  "police_department": return Color("a4ace7")
  "necrotech_lab": return Color("f5e79e")
  "fire_station": return Color("ee8c79")
  "park": return Color("a2c691")
  "zoo_ground": return Color("83ad8b")
  "warehouse": return Color("b69c82")
  "office": return Color("c8ced6")
  "": return INK
 var index = (C.BUILDINGS+C.OUTDOORS).find(kind)
 return Color.from_hsv(fposmod(index*0.618034,1.0),0.22+(index%3)*0.07,0.74+(index%4)*0.06)

func _necronet_modal() -> void:
 label(overlay,sim.scan_report+"   ·   %d minutes ago" % (sim.minute-sim.scan_minute),Rect2(145,160,1120,33),21,MUTED)
 var grid = Control.new()
 grid.name = "NecroNetGrid"
 grid.position = Vector2(145,211)
 overlay.add_child(grid)
 var types: Array[String] = []
 for i in range(sim.scan_cells.size()):
  var cell = sim.scan_cells[i]
  var edge = GOLD if i == 40 else INK
  var tile = rect(grid,Rect2((i%9)*60,(i/9)*60,58,58),_necronet_color(cell.type),edge)
  if i == 40: tile.get_theme_stylebox("panel").set_border_width_all(3)
  if int(cell.site) < 0: continue
  if cell.type not in types: types.append(cell.type)
  var site = sim.blocks[int(cell.site)]
  tile.mouse_filter = Control.MOUSE_FILTER_PASS
  tile.tooltip_text = "%s [%d, %d]\n%s · Tagged zombies  %d" % [site.name,site.x,site.y,C.pretty(cell.type),int(cell.count)]
  if cell.count > 0:
   var count = label(tile,str(int(cell.count)),Rect2(2,2,54,54),24,INK)
   count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label(overlay,"Block types",Rect2(725,211,470,31),24,GOLD)
 types.sort()
 for i in range(types.size()):
  var at = Vector2(725+(i%2)*260,251+(i/2)*23)
  rect(overlay,Rect2(at,Vector2(16,16)),_necronet_color(types[i]),INK)
  label(overlay,C.pretty(types[i]),Rect2(at+Vector2(23,-3),Vector2(226,23)),16,CREAM)
 label(overlay,"Gold outline marks the lab used for this scan.",Rect2(145,768,820,29),19,MUTED)

func _scent_death_modal() -> void:
 label(overlay,"You take in the rot and decay in the air around you.",Rect2(145,160,1120,30),21,MUTED)
 var grid = Control.new()
 grid.name = "ScentDeathGrid"
 grid.position = Vector2(145,205)
 overlay.add_child(grid)
 for i in range(sim.scent_heatmap.size()):
  var cell = sim.scent_heatmap[i]
  var red = 0.025 + 0.94*(1.0-pow(0.76,cell.bodies))
  var green = 0.025 + 0.94*(1.0-pow(0.76,cell.zombies))
  var color = Color(red,green,0.018) if cell.valid else Color.BLACK
  var edge = GOLD if i == 60 else Color("111713")
  var tile = rect(grid,Rect2((i%11)*48,(i/11)*48,47,47),color,edge)
  if not cell.valid: continue
  tile.mouse_filter = Control.MOUSE_FILTER_PASS
  tile.tooltip_text = "%s [%d, %d]\nStanding zombies  %d · Dead bodies  %d\nRevivifying  %d" % [sim.block_at(cell.x,cell.y).name,cell.x,cell.y,cell.zombies,cell.bodies,cell.revivifying]
  if i == 60: rect(tile,Rect2(20,20,7,7),GOLD)
 label(overlay,"Red · Dead bodies",Rect2(725,220,460,36),24,RED)
 label(overlay,"Green · Standing zombies",Rect2(725,270,460,36),24,GREEN)
 label(overlay,"Mixed colours · Both are present",Rect2(725,320,500,36),24,GOLD)
 label(overlay,"Gold marker · Your block",Rect2(725,370,460,36),20,CREAM)
 label(overlay,"Brighter squares indicate higher counts.\nHover a square for the breakdown.",Rect2(725,427,530,70),20,MUTED)

func map_site_tooltip(b: Dictionary) -> String:
 var text = "%s\n%s" % [b.name,C.pretty(sim.visible_type(b,sim.player()))]
 if sim.is_building(b): text += "\n" + sim.exterior_building_clues(b)
 return text

func open_city_map() -> void:
 city_overview = true
 map_origin = Vector2i(-1,-1)
 open_modal("map")

func _map_modal() -> void:
 var p = sim.player()
 if p.down:
  rect(overlay,Rect2(130,160,1180,690),Color.BLACK)
  label(overlay,"Everything is dark. Stand up to see your surroundings.",Rect2(160,420,1100,50),24,MUTED)
  return
 var has_gps = not sim.item_kind(p,"gps_unit").is_empty()
 var player_neighbourhood = Vector2i(p.x/10*10,p.y/10*10)
 if map_origin.x < 0: city_overview = true
 if city_overview:
  label(overlay,"Click a neighbourhood to zoom in.",Rect2(135,154,470,30),20,MUTED)
 else:
  button(overlay,"City",Rect2(135,154,180,30),func(): city_overview = true; refresh())
  for i in range(4):
   var direction = [Vector2i(-10,0),Vector2i(10,0),Vector2i(0,-10),Vector2i(0,10)][i]
   button(overlay,["W","E","N","S"][i],Rect2(492+i*62,154,54,30),func(): map_origin = Vector2i(clampi(map_origin.x+direction.x,0,(sim.width-1)/10*10),clampi(map_origin.y+direction.y,0,(sim.height-1)/10*10)); refresh())
 if has_gps:
  var find_x = 1030 if city_overview else 325
  var find_button = button(overlay,"Find me",Rect2(find_x,154,150,30),func(): map_origin = player_neighbourhood; city_overview = false; refresh())
  find_button.name = "FindMe"
 var columns = ceili(sim.width/10.0) if city_overview else 10
 var rows = ceili(sim.height/10.0) if city_overview else 10
 var field_map: Control
 if not city_overview:
  field_map = map_region(overlay,Rect2i(map_origin,Vector2i(10,10)),Vector2(135,196),61,true)
 for y in range(rows):
  for x in range(columns):
   var bx = x*10 if city_overview else map_origin.x+x
   var by = y*10 if city_overview else map_origin.y+y
   if bx >= sim.width or by >= sim.height: continue
   var b = sim.block_at(bx,by)
   var cell_width = 116 if city_overview else 61
   var bounds = Rect2(135+x*cell_width,196+y*61,cell_width-3 if city_overview else 61,58 if city_overview else 61)
   if city_overview:
    var at = Vector2i(bx,by)
    var here = has_gps and at == player_neighbourhood
    var tile = button(overlay,"",bounds,func(): map_origin = at; city_overview = false; refresh(),here)
    tile.name = "Neighbourhood_%d_%d" % [bx,by]
    var title = label(tile,b.get("suburb",sim.world_title),Rect2(3,5,cell_width-9,48),15)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tile.tooltip_text = "%s [%d–%d, %d–%d]" % [b.get("suburb",sim.world_title),bx,mini(sim.width-1,bx+9),by,mini(sim.height-1,by+9)]
    if here:
     var outline = rect(tile,Rect2(Vector2.ZERO,bounds.size),Color.TRANSPARENT,GOLD)
     outline.name = "GPSNeighbourhood"
     outline.get_theme_stylebox("panel").set_border_width_all(2)
     tile.tooltip_text += "\nYour neighbourhood"
    continue
   var player_square = has_gps and p.x == bx and p.y == by
   if b.known or player_square:
    var mark = Control.new()
    mark.position = bounds.position-Vector2(135,196)
    mark.size = Vector2.ONE*61
    mark.tooltip_text = map_site_tooltip(b)
    mark.z_index = 1000
    mark.mouse_filter = Control.MOUSE_FILTER_PASS
    field_map.add_child(mark)
    if player_square:
     var outline = rect(mark,Rect2(0,0,61,61),Color.TRANSPARENT,GOLD)
     outline.name = "GPSSquare"
     outline.get_theme_stylebox("panel").set_border_width_all(2)
    necrotech_mark(mark,b,Vector2(22,9),14)
   else:
    var unknown = rect(field_map,Rect2(bounds.position-Vector2(135,196),bounds.size),INK)
    unknown.z_index = 1000
    label(unknown,"?",Rect2(20,12,35,35),23,MUTED)
 if city_overview: return
 label(overlay,"NECRONET INTELLIGENCE",Rect2(780,176,510,40),26,GOLD)
 var report = label(overlay,sim.scan_report,Rect2(780,230,510,190),24)
 report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label(overlay,"Scan age: %d minutes" % (sim.minute-sim.scan_minute) if sim.scan_minute >= 0 else "Not connected",Rect2(780,422,250,35),20,MUTED)
 if not sim.scan_cells.is_empty():
  button(overlay,"View scan",Rect2(1050,422,150,32),func(): open_modal("necronet"))
 var suburb = sim.block_at(map_origin.x,map_origin.y).get("suburb",sim.world_title)
 var gps_hint = "\nGold outline: your location" if has_gps else ""
 var info = label(overlay,"%s · %d × %d blocks\n%s\n\nExplore to reveal local blocks. Use City to choose a suburb, or W/E/N/S to browse.\n\nWarm windows: powered · Broken roofs: ruined%s\nNecroTech Employment reveals the NT logo.\n\nThe scan is a snapshot of tagged zombies, not live tracking." % [sim.world_title,sim.width,sim.height,suburb,gps_hint],Rect2(780,487,510,280),22,MUTED)
 info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _skills_modal() -> void:
 var p = sim.player()
 label(overlay,"%d XP · Level %d · Human and zombie skills persist through death and revival." % [p.xp,sim.level(p)],Rect2(140,153,1140,38),22,CREAM)
 var scroll = ScrollContainer.new()
 scroll.name = "FullSkillTrees"
 scroll.position = Vector2(130,205)
 scroll.size = Vector2(1180,645)
 overlay.add_child(scroll)
 var content = Control.new()
 scroll.add_child(content)
 var height = {"human":0,"zombie":0}
 var tracks = {"military":"Military","science":"Scientific","civilian":"Civilian","scent":"Scent","offensive":"Offensive & Attack","utility":"Utility & Brain"}
 var skills: Array = []
 for track in tracks:
  skills.append_array(C.SKILLS.keys().filter(func(key): return C.SKILLS[key].category == track or (track == "military" and C.SKILLS[key].category == "hunter")))
 var last_track = ""
 for key in skills:
  var def = C.SKILLS[key]
  var owned = key in p.human_skills or key in p.zombie_skills
  var x = 10 if def.side == "human" else 605
  var track = "military" if def.category == "hunter" else def.category
  if track != last_track:
   label(content,tracks[track].to_upper(),Rect2(x,height[def.side],555,32),23,GOLD)
   height[def.side] += 40
   last_track = track
  var y = height[def.side]
  height[def.side] += 102
  var active = sim.has_skill(p,key)
  label(content,def.name+(" / ACTIVE" if active else " / DORMANT") if owned else def.name,Rect2(x,y,555,27),21,GREEN if owned and active else CREAM)
  var details: String = def.description
  if not str(def.requires).is_empty(): details += " Needs "+C.SKILLS[def.requires].name+"."
  var desc = label(content,details,Rect2(x,y+28,405,70),16,MUTED)
  desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  var buy = button(content,"Learned" if owned else "%d XP" % sim.skill_cost(p,key),Rect2(x+425,y+32,130,40),func():
   var response = sim.learn(key)
   notice = response if not response.is_empty() else "Learned "+def.name
   refresh())
  buy.disabled = not sim.skill_reason(p,key).is_empty()
  buy.tooltip_text = sim.skill_reason(p,key)
 content.custom_minimum_size = Vector2(1160,maxi(height.human,height.zombie))

func _item_menu(item: Dictionary) -> void:
 if paused or resting or not modal.is_empty(): return
 context_open = true
 var popup = PopupMenu.new()
 add_child(popup)
 var commands: Array = []
 var use_action = {"first_aid_kit":"heal", "pistol_clip":"reload", "shotgun_shell":"reload", "toolbox":"repair", "portable_generator":"generator", "fuel_can":"fuel", "syringe":"revive"}
 if C.ITEMS[item.kind].has("damage"): commands.append(["equip","Equip / unequip",-1])
 elif use_action.has(item.kind): commands.append([use_action[item.kind],"Use",0 if item.kind == "first_aid_kit" else selected_actor])
 if C.ITEMS[item.kind].has("action"): commands.append([C.ITEMS[item.kind].action,"Use "+C.ITEMS[item.kind].name,selected_actor])
 if item.kind == "flare_gun": commands.append(["flare","Fire signal flare",-1])
 commands.append(["give","Give to selected survivor",selected_actor])
 commands.append(["drop","Drop permanently",-1])
 for i in range(commands.size()):
  var option = commands[i]
  var why = sim.reason(sim.player(),option[0],option[2],{"uid":item.uid})
  if option[0] == "lookout": why = sim.action_feedback(sim.player(),"lookout")
  if option[0] == "revive": why = sim.action_feedback(sim.player(),option[0],option[2],{"uid":item.uid})
  popup.add_item(option[1],i)
  popup.set_item_disabled(i,not why.is_empty())
  popup.set_item_tooltip(i,why)
 popup.id_pressed.connect(func(index):
  var option = commands[index]
  if option[0] in ["tag","broadcast","phone","tune"]:
   message_command = option[0]; message_target = option[2]; message_data = {"uid":item.uid}; open_modal("message")
  else: dispatch(option[0],option[2],{"uid":item.uid}))
 popup.popup_hide.connect(func(): context_open = false; popup.queue_free())
 popup.position = Vector2i(get_viewport().get_mouse_position()*get_viewport().get_stretch_transform().get_scale())
 popup.popup()

func portrait_texture(p: Dictionary) -> Texture2D:
 var key: String = C.PORTRAITS.get(p.get("job",""),"consumer")
 var portrait = tex("portraits/"+key+".png")
 return portrait if portrait != null else tex("sprite_sheets/male1_sprite_sheet.png")

func portrait_region(p: Dictionary) -> Rect2:
 if p.has("job") and tex("portraits/"+str(C.PORTRAITS.get(p.job,"consumer"))+".png") != null:
  var texture = portrait_texture(p)
  var cell = Vector2(texture.get_width()/5.0,texture.get_height()/5.0)
  var frame = 15
  if not p.down and p.hp > 0:
   if not p.human: frame = 16+zombie_pose(animation_time)%9
   else:
    var start = 0 if float(p.hp)/sim.max_hp(p) > 0.7 else (5 if float(p.hp)/sim.max_hp(p) > 0.3 else 10)
    frame = start+int(animation_time/0.35)%5
  return Rect2(Vector2(frame%5,frame/5)*cell,cell)
 var start = 0 if p.hp > 35 else (6 if p.hp > 15 else 12)
 if not p.human: start = 19
 if p.hp <= 0 or p.down: return Rect2(18*66,0,66,66)
 if not p.human: return Rect2((start+zombie_pose(animation_time)%6)*66,0,66,66)
 return Rect2((start+int(animation_time/0.35)%6)*66,0,66,66)

func appears_human(a: Dictionary) -> bool:
 return a.human and (not a.down or sim.has_skill(sim.player(),"scent_death"))

func ordered_people() -> Array:
 var people = sim.occupants(sim.current_block(sim.player()), sim.player().inside).duplicate()
 people.sort_custom(func(a,b):
  var left_human = appears_human(a)
  if left_human != appears_human(b): return left_human
  return a.id < b.id)
 return people

func zombie_pose(time: float) -> int:
 # Cosmetic randomness is independent of world RNG and survives UI rebuilds.
 while float(lurch_segments.back().until) <= time:
  var end = float(lurch_segments.back().until)
  var pose = lurch_rng.randi_range(2,8)
  var jerks = lurch_rng.randi_range(1,3)
  for i in range(jerks):
   end += lurch_rng.randf_range(0.06,0.16)
   lurch_segments.append({"until":end,"frame":pose if i%2 == 0 else maxi(0,pose-2)})
  end += lurch_rng.randf_range(0.12,0.45)
  lurch_segments.append({"until":end,"frame":lurch_rng.randi_range(1,3)})
  end += lurch_rng.randf_range(0.4,2.6)
  lurch_segments.append({"until":end,"frame":lurch_rng.randi_range(0,1)})
 var low = 0
 var high = lurch_segments.size()-1
 while low < high:
  var mid = (low+high)/2
  if time < float(lurch_segments[mid].until): high = mid
  else: low = mid+1
 return lurch_segments[low].frame

func _speech_bubble(parent: Node, actor: Dictionary, actor_bounds: Rect2) -> void:
 var width = 204.0
 var font_size = 16
 var text_size = theme.default_font.get_multiline_string_size(actor.speech,HORIZONTAL_ALIGNMENT_LEFT,width-20,font_size)
 var height = text_size.y+20.0
 var x = clampf(actor_bounds.get_center().x-width/2,408,1412-width)
 var y = maxf(166,actor_bounds.position.y-height-10)
 var bubble = rect(parent,Rect2(x,y,width,height),Color("ece4ca") if actor.human else Color("26352b"),GOLD if actor.human else GREEN)
 bubble.name = "Speech_%d" % actor.id
 var style: StyleBoxFlat = bubble.get_theme_stylebox("panel")
 style.set_corner_radius_all(5)
 var words = label(bubble,actor.speech,Rect2(10,7,width-20,height-14),font_size,INK if actor.human else CREAM)
 words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 words.add_theme_constant_override("line_spacing",0)
 words.clip_text = true
 var tail_x = clampf(actor_bounds.get_center().x-x-6,8,width-20)
 var tail = Polygon2D.new()
 tail.polygon = PackedVector2Array([Vector2(tail_x,height-1),Vector2(tail_x+12,height-1),Vector2(tail_x+6,height+8)])
 tail.color = style.bg_color
 bubble.add_child(tail)

func actor_frame(a: Dictionary) -> int:
 var sequence = int(a.get("pose_sequence",0))
 var record: Dictionary = actor_visuals.get(a.id,{"sequence":-1,"since":animation_time,"pose":"idle"})
 if record.sequence != sequence:
  record = {"sequence":sequence,"since":animation_time,"pose":a.get("pose","idle") if sim.now()-float(a.get("pose_at",0.0)) <= 2 else "idle"}
  actor_visuals[a.id] = record
 var elapsed = animation_time-float(record.since)
 if a.down:
  return 15+mini(5,int(elapsed*10)) if record.pose == "die" else 20
 match record.pose:
  "hurt":
   if elapsed < 0.3: return 21+mini(2,int(elapsed*10))
  "attack":
   if elapsed < 0.7: return 8+mini(6,int(elapsed*10))
 if not a.human:
  var stagger = [0,0,1,1,1,2,3,3,4,4,4,5,6,7,7,7]
  return stagger[(int(animation_time*3)+a.id*3)%stagger.size()]
 return (int(animation_time*5)+a.id)%8

func actor_region(a: Dictionary, texture: Texture2D) -> Rect2:
 var frame = actor_frame(a)
 if texture.get_width() > texture.get_height()*8:
  var cell = float(texture.get_width())/24.0
  return Rect2(frame*cell,0,cell,texture.get_height())
 var cell = Vector2(texture.get_width()/6.0,texture.get_height()/4.0)
 return Rect2(Vector2(frame%6,frame/6)*cell,cell)

func map_art(b: Dictionary) -> Texture2D:
 return minimap_artwork.texture_for(sim,b)

func map_region(parent: Node, footprint: Rect2i, at: Vector2, cell: float, discovered_only: bool = false) -> Control:
 var city = MapCanvas.new()
 city.sim = sim
 city.artwork = minimap_artwork
 city.footprint = footprint
 city.cell = cell
 city.discovered_only = discovered_only
 city.position = at
 parent.add_child(city)
 city.build()
 return city

func necrotech_mark(parent: Node, b: Dictionary, at: Vector2, size: float = 20) -> void:
 if b.type != "necrotech_lab" or not sim.has_skill(sim.player(),"necro_employment"): return
 var logo = rect(parent,Rect2(at,Vector2(size,size)),Color("172e2b"),Color("9bd6b2"))
 logo.name = "NecroTechLogo_%d" % b.id
 var n = label(logo,"NT",Rect2(0,-1,size,size),int(size*0.58),Color("b8efc8"))
 n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 logo.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _message_modal() -> void:
 var hint = "Enter a message."
 if message_command == "tag": hint = "Spray ‘Revive point’ outdoors to mark a meeting place for revivals."
 if message_command == "broadcast": hint = "Broadcast ‘Defend’ to ask nearby tuned survivors for help."
 if message_command == "tune": hint = "Choose a frequency for this receiver."
 if message_command == "tune_transmitter": hint = "Choose a frequency for the installed transmitter."
 label(overlay,hint,Rect2(140,180,1100,42),24)
 var input = LineEdit.new()
 input.position = Vector2(140,260)
 input.size = Vector2(1140,50)
 input.max_length = C.FIELD_MESSAGE_LIMIT if message_command in ["tag","broadcast"] else 255
 input.placeholder_text = "Write a message"
 if message_command in ["say","gesture","phone"]: input.text = "Keep together. Help the wounded and guard the entrance."
 input.visible = message_command not in ["tune","tune_transmitter"]
 overlay.add_child(input)
 var frequency = SpinBox.new()
 frequency.position = Vector2(140,340)
 frequency.size = Vector2(260,45)
 var receiver = sim.action_item(sim.player(),"radio",message_data)
 var transmitting = message_command in ["broadcast","tune_transmitter"]
 frequency.min_value = (26.0 if sim.has_skill(sim.player(),"radio_operation") else C.PUBLIC_RADIO_FREQUENCY) if transmitting else 25.0
 frequency.max_value = 29.0 if transmitting else 30.0
 frequency.step = 0.01
 frequency.value = sim.suggested_transmit_frequency(sim.player()) if transmitting else float(receiver.get("frequency",C.PUBLIC_RADIO_FREQUENCY))
 frequency.visible = transmitting or message_command == "tune"
 overlay.add_child(frequency)
 var contacts = OptionButton.new()
 contacts.position = Vector2(440,340)
 contacts.size = Vector2(500,45)
 var ids: Array = []
 contacts.visible = message_command == "phone"
 if contacts.visible:
  for a in sim.actors:
   if a.id == 0 or not a.human or sim.item_kind(a,"mobile_phone").is_empty(): continue
   contacts.add_item(sim.display_name(a))
   ids.append(a.id)
   if a.id == message_target: contacts.select(contacts.item_count-1)
 overlay.add_child(contacts)
 button(overlay,"Send / apply",Rect2(140,430,260,48),func():
  var data = message_data.duplicate()
  data.text = input.text
  data.frequency = frequency.value
  var target = ids[contacts.selected] if message_command == "phone" and contacts.item_count > 0 else message_target
  modal = ""
  dispatch(message_command,target,data),true)

func generation_spin(parent: Node, key: String, text: String, at: Vector2, lower: int, upper: int, counts: bool = false) -> void:
 label(parent,text,Rect2(at,Vector2(330 if counts else 240,38)),20)
 var spin = SpinBox.new()
 spin.name = ("Count_" if counts else "Config_")+key
 spin.position = at+Vector2(350 if counts else 250,0)
 spin.size = Vector2(180,38)
 spin.min_value = lower
 spin.max_value = upper
 spin.value = new_world_config.counts.get(key,0) if counts else new_world_config.get(key,0)
 spin.value_changed.connect(func(value):
  if counts: new_world_config.counts[key] = int(value)
  else: new_world_config[key] = int(value))
 parent.add_child(spin)

func _new_game_modal() -> void:
 if new_world_config.is_empty(): new_world_config = sim.World.defaults()
 label(overlay,"Choose a world, occupation, seed and population. A new game replaces the current session.",Rect2(140,157,1140,32),21)
 var mode = OptionButton.new()
 mode.name = "WorldMode"
 mode.position = Vector2(140,204)
 mode.size = Vector2(380,42)
 for name in ["Original Malton · 100 × 100","Random city","Legacy test neighbourhood"]: mode.add_item(name)
 mode.select(["malton","random","sandbox"].find(new_world_mode))
 mode.item_selected.connect(func(index): new_world_mode = ["malton","random","sandbox"][index]; new_game_error = ""; refresh())
 overlay.add_child(mode)
 var occupations = OptionButton.new()
 occupations.name = "NewOccupation"
 occupations.position = Vector2(550,204)
 occupations.size = Vector2(400,42)
 var jobs = ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse","Volunteer"]
 for job in jobs: occupations.add_item(job)
 occupations.select(jobs.find(new_occupation))
 occupations.item_selected.connect(func(index): new_occupation = jobs[index])
 overlay.add_child(occupations)
 label(overlay,"Seed",Rect2(980,203,80,40),20)
 var seed_input = SpinBox.new()
 seed_input.position = Vector2(1050,204)
 seed_input.size = Vector2(250,42)
 seed_input.max_value = 2147483647
 seed_input.value = new_seed
 seed_input.value_changed.connect(func(value): new_seed = int(value))
 overlay.add_child(seed_input)
 if new_world_mode != "sandbox":
  var choices = ["easy","medium","hard"]
  if new_world_mode == "random": choices.append("custom")
  if new_difficulty not in choices: new_difficulty = "medium"
  var difficulty = OptionButton.new()
  difficulty.name = "Difficulty"
  difficulty.position = Vector2(140,258)
  difficulty.size = Vector2(230,40)
  for choice in choices: difficulty.add_item(choice.capitalize())
  difficulty.select(choices.find(new_difficulty))
  difficulty.item_selected.connect(func(index): new_difficulty = choices[index]; refresh())
  overlay.add_child(difficulty)
  var hint = "Set survivor and zombie counts below." if new_difficulty == "custom" else "Population difficulty · Most zombies start dormant and rise over successive nights."
  label(overlay,hint,Rect2(390,258,910,40),19,MUTED)
 if new_world_mode == "random":
  label(overlay,"Exact ordinary-building counts",Rect2(140,305,600,30),23,GOLD)
  var scroll = ScrollContainer.new()
  scroll.name = "GenerationCounts"
  scroll.position = Vector2(140,345)
  scroll.size = Vector2(620,407)
  overlay.add_child(scroll)
  var content = Control.new()
  content.custom_minimum_size = Vector2(590,20*48)
  scroll.add_child(content)
  var index = 0
  for kind in C.NORMAL_BUILDINGS:
   if kind == "mall": continue
   generation_spin(content,kind,C.pretty(kind),Vector2(0,index*48),0,10000,true)
   index += 1
  var settings = [["width","Width",10,100],["height","Height",10,100],["malls","Malls (Malton plans)",0,100],["forts","3×3 forts",0,20],["zoos","5×4 zoos",0,20],["cathedrals","Cathedrals",0,100],["mansions","Mansions",0,100],["power_stations","Power stations",0,100],["stadiums","Stadiums",0,100],["survivors","Survivors",0,2000],["zombies","Zombies / bodies",0,4000]]
  if new_difficulty != "custom": settings.resize(9)
  var setting_scroll = ScrollContainer.new()
  setting_scroll.name = "GenerationSettings"
  setting_scroll.position = Vector2(800,345)
  setting_scroll.size = Vector2(510,345)
  overlay.add_child(setting_scroll)
  var settings_content = Control.new()
  settings_content.custom_minimum_size = Vector2(470,settings.size()*54)
  setting_scroll.add_child(settings_content)
  for i in range(settings.size()):
   var setting = settings[i]
   generation_spin(settings_content,setting[0],setting[1],Vector2(0,i*54),setting[2],setting[3])
  button(overlay,"Reset ordinary counts for map size",Rect2(800,700,500,40),func():
   new_world_config.counts = sim.World.defaults(int(new_world_config.width),int(new_world_config.height)).counts
   refresh())
 else:
  var text = "All original named squares across 100 Malton suburbs.\nThe imported data preserves the original zoo, forts and mall footprints.\nMove across suburb boundaries without loading another map.\n\nZoo squares cannot be barricaded. Enter forts through the gatehouse. Perimeter map exits lead outside.\nConnected indoor mall squares do not require Free Running." if new_world_mode == "malton" else "The legacy 10×10 neighbourhood, retained for focused playtests and old saves."
  var explanation = label(overlay,text,Rect2(140,330,1130,320),23,MUTED)
  explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var error_text = label(overlay,new_game_error,Rect2(140,754,1140,48),18,RED)
 error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 button(overlay,"Start new game",Rect2(140,813,300,42),func():
  var config = new_world_config.duplicate(true)
  config.mode = new_world_mode
  config.difficulty = new_difficulty
  if new_difficulty != "custom" or new_world_mode != "random":
   config.erase("survivors")
   config.erase("zombies")
  var why = sim.start(new_seed,new_occupation,config)
  if not why.is_empty(): new_game_error = why; refresh(); return
  _reset_session_view()
  new_game_error = ""
  modal = ""
  paused = false
  notice = "New game started."
  refresh(),true)

func position_actor_sprite(entry: Dictionary) -> void:
 var a = sim.actors[entry.id]
 var atlas: AtlasTexture = entry.node.texture
 atlas.region = actor_region(a,atlas.atlas)
 var frames = foot_bounds.get(entry.sheet,[])
 var bottom = float(frames[actor_frame(a)].bottom) if frames.size() == 24 else 1.0
 entry.node.position.y = entry.ground-entry.size*bottom
