extends Control

var initial_world_mode = "malton"
var map_origin = Vector2i(-1,-1)
var city_overview = false
var new_world_mode = "malton"
var new_world_config: Dictionary = {}
var new_seed = 4815
var new_occupation = "Private"
var new_game_error = ""

const Sim = preload("res://scripts/simulation.gd")
const Feed = preload("res://scripts/event_feed.gd")
const C = preload("res://scripts/catalog.gd")
const MapArtwork = preload("res://scripts/minimap_art.gd")
const MapCanvas = preload("res://scripts/minimap_canvas.gd")
var minimap_artwork = MapArtwork.new()
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

var sim = Sim.new()
var page: Control
var overlay: Control
var selected_actor: int = -1
var selected_item: int = -1
var paused: bool = false
var modal: String = ""
var resting: bool:
 get: return sim.resting
 set(value): sim.resting = value
var rest_target: int:
 get: return sim.rest_target
var feed = Feed.new()
var log_view: RichTextLabel
var log_filter: String = "All"
var history_filter: String = "All"
var refresh_timer: float = 0.0
var last_revision: String = ""
var action_controls: Array = []
var timing_label: Label
var notice: String = "Welcome to Dulston. Explore, find supplies, and keep your neighbours alive."
var textures: Dictionary = {}
var actor_buttons: Array = []
var actor_visuals: Dictionary = {}
var animation_time: float = 0.0
var context_open: bool = false
var mall_store: String = "drugstore"
var message_command: String = "say"
var message_target: int = -1
var message_data: Dictionary = {}
var actions_bottom: float = 971.0
var player_portrait: TextureRect
var lurch_rng = RandomNumberGenerator.new()
var lurch_segments: Array = [{"until":0.55,"frame":0}]

func _ready() -> void:
 lurch_rng.randomize()
 var ui_theme = Theme.new()
 ui_theme.default_font = load("res://assets/fonts/PixelifySans.ttf")
 ui_theme.default_font_size = 19
 theme = ui_theme
 var why = sim.start(4815,"Volunteer",{"mode":initial_world_mode})
 if not why.is_empty():
  sim.start()
  notice = why
 else: notice = "Welcome to %s. Find allies and secure a shelter." % sim.world_title
 feed.reset(sim.messages)
 refresh()

func _process(delta: float) -> void:
 animation_time += delta
 for entry in actor_buttons:
  if is_instance_valid(entry.node):
   position_actor_sprite(entry)
 if is_instance_valid(player_portrait):
  player_portrait.texture.region = portrait_region(sim.player())
 if paused or context_open or not modal.is_empty(): return
 var was_resting = resting
 var was_down = sim.player().down
 # Do not turn a stalled/render-blocked frame into a surprise burst of attacks.
 sim.elapse(minf(delta,0.25))
 if was_down != sim.player().down: refresh()
 sim.discover()
 if was_resting and not resting: notice = sim.last_rest_notice
 var feed_changed = feed.ingest(sim.messages)
 if feed.update(delta): feed_changed = true
 if feed_changed: _update_log()
 for entry in action_controls:
  if is_instance_valid(entry.node):
   var why = sim.action_feedback(sim.player(),entry.command,entry.target,entry.data)
   entry.node.disabled = paused or resting or not why.is_empty()
   entry.node.tooltip_text = why if not why.is_empty() else entry.tip
 if is_instance_valid(timing_label): timing_label.text = _timing_text()
 refresh_timer += delta
 var revision = "%d/%d/%d/%s" % [sim.minute,sim.event_sequence,sim.player().ap,resting]
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
 elif event.keycode == KEY_SPACE: paused = not paused; refresh()
 elif event.keycode == KEY_R: begin_rest(10)
 elif event.keycode == KEY_M: open_modal("map")

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
 if is_instance_valid(page):
  remove_child(page)
  page.queue_free()
 actor_buttons.clear()
 action_controls.clear()
 page = Control.new()
 page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(page)
 move_child(page,0)
 var p = sim.player()
 var b = sim.current_block(p)
 if p.down: selected_actor = -1
 if selected_actor >= 0 and not sim.nearby(p, sim.actors[selected_actor]): selected_actor = -1
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

func _header() -> void:
 rect(page, Rect2(0, 0, 1920, 74), Color("111d18"))
 label(page, "MALTON", Rect2(22, 5, 210, 44), 39, CREAM)
 label(page, sim.world_title.to_upper()+"  /  SURVIVAL", Rect2(24, 47, 400, 22), 15, GOLD)
 label(page, sim.time_text(), Rect2(270, 15, 270, 30), 24, GOLD)
 label(page, "LIVE · %s" % ("%d×" % sim.time_speed()), Rect2(570, 15, 146, 40), 23, GOLD)
 button(page, "Resume" if paused else "Pause", Rect2(726, 15, 95, 40), func(): paused = not paused; refresh())
 button(page, "Map [M]", Rect2(831, 15, 105, 40), func(): open_modal("map"))
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
 var caption = "%s  ·  [%02d, %02d]" % [sim.suburb_name(p).to_upper(),p.x,p.y]
 var caption_font = 24
 while caption_font > 14 and theme.default_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_font).x > 350: caption_font -= 1
 label(page,caption,Rect2(24,451,350,28),caption_font,GOLD)
 label(page, "Click a neighbour • Arrows / WASD • QEZC", Rect2(24,480,355,22), 15, MUTED)

func _minimap_population(tile: Button, b: Dictionary, p: Dictionary, inside: bool) -> void:
 var visible = sim.occupants(b,inside)
 var names: Array[String] = []
 for person in visible:
  if person.id != p.id and person.human and not person.down: names.append(sim.display_name(person))
 var sensed = sim.occupants(b) if not p.human and sim.has_skill(p,"scent_death") else visible
 var zombies = sensed.filter(func(person): return person.id != p.id and not person.down and not person.human).size()
 var rows: Array[String] = []
 rows.assign(names.slice(0,3))
 if names.size() > 3: rows.append("…")
 if zombies > 0: rows.append("%d zombie%s" % [zombies,"" if zombies == 1 else "s"])
 var y = 103-rows.size()*14
 for i in range(rows.size()):
  var undead_row = zombies > 0 and i == rows.size()-1
  rect(tile,Rect2(3,y,100,13),Color(0.04,0.07,0.05,0.90))
  var caption = label(tile,rows[i],Rect2(6,y-1,94,15),12,RED if undead_row else GREEN)
  caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  y += 14
 if not names.is_empty(): tile.tooltip_text += "\n" + ", ".join(names)
 if zombies > 0: tile.tooltip_text += "\n" + rows.back()
 if not p.human and sim.has_skill(p,"scent_blood"):
  var injured = sim.occupants(b).any(func(person): return person.human and not person.down and person.hp <= 12)
  if injured:
   var cross = rect(tile,Rect2(4,4,18,18),INK)
   cross.name = "ScentBlood"
   rect(cross,Rect2(7,3,4,12),RED)
   rect(cross,Rect2(3,7,12,4),RED)
   tile.tooltip_text += "\nScent Blood: a heavily injured survivor"
 if p.trail_origin == b.id:
  var direction = sim.scent_trail_direction(p)
  if not direction.is_empty():
   var arrow = {"north":"↑","south":"↓","east":"→","west":"←","northeast":"↗","northwest":"↖","southeast":"↘","southwest":"↙"}
   var marker = rect(tile,Rect2(84,4,18,18),INK)
   marker.name = "ScentTrail"
   label(marker,arrow[direction],Rect2(2,0,16,17),15,GOLD)
   tile.tooltip_text += "\nScent Trail leads " + direction

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
 if sim.player().down or sim.sleeping: return
 var people = ordered_people().filter(func(a): return a.id != 0)
 var humans = people.filter(func(a): return a.human)
 var zombies = people.filter(func(a): return not a.human)
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
   var x = 416+col*spacing+row*spacing*0.18 if group[i].human else 1404-(col+1)*spacing-row*spacing*0.18
   var floor_y = ENVIRONMENT_RECT.end.y-2-row*43-offset
   entries.append({"actor":group[i],"x":x,"floor":floor_y,"size":size})
 entries.sort_custom(func(a,b): return a.floor < b.floor)
 var actors_layer = Control.new()
 actors_layer.name = "SceneActors"
 actors_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 page.add_child(actors_layer)
 var speaking: Array = []
 for entry in entries:
  var a = entry.actor
  var bounds = Rect2(entry.x,entry.floor-entry.size,spacing-2,entry.size-2)
  var target = button(actors_layer,"",bounds,func(): selected_actor = a.id; refresh())
  target.name = "Actor_%d" % a.id
  var clear = StyleBoxFlat.new()
  clear.bg_color = Color.TRANSPARENT
  clear.border_color = GOLD if selected_actor == a.id else Color.TRANSPARENT
  clear.set_border_width_all(1)
  target.add_theme_stylebox_override("normal",clear)
  var hover = clear.duplicate()
  hover.bg_color = Color(1,1,1,0.06)
  hover.border_color = GOLD
  target.add_theme_stylebox_override("hover",hover)
  target.tooltip_text = "%s · %s" % [sim.display_name(a),"Down" if a.down else (a.job if a.human else "Zombie")]
  if a.human: target.tooltip_text += " · " + sim.trust_description(a,sim.player())
  var p = sim.player()
  var b = sim.current_block(p)
  var scent_health = a.human and not a.down and a.hp < sim.max_hp(a) and sim.has_skill(p,"scent_fear")
  var diagnosis = a.human and sim.has_skill(p,"diagnosis") and not (p.inside and sim.is_dark_building(b) and not sim.powered(b))
  if scent_health or diagnosis: target.tooltip_text += " · %d/%d HP" % [a.hp,sim.max_hp(a)]
  var sheet = C.occupation_sheet(a.job,a.human)
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
  if a.down and sim.now()-a.pose_at > 2: sprite.modulate = Color(0.55,0.55,0.55)
  var visual = {"node":sprite,"id":a.id,"offset":a.id%8,"sheet":sheet,"size":entry.size,"ground":entry.size-12}
  position_actor_sprite(visual)
  actor_buttons.append(visual)
  if scent_health:
   var bar_width = minf(34.0,spacing*0.48)
   rect(target,Rect2((spacing-bar_width)/2,entry.size-11,bar_width,8),Color("290d0d"))
   rect(target,Rect2((spacing-bar_width)/2,entry.size-11,bar_width*clampf(float(a.hp)/sim.max_hp(a),0,1),8),Color("c63f37"))
  if not a.down and not a.speech.is_empty() and a.speech_until > sim.now(): speaking.append({"actor":a,"bounds":bounds})
 for entry in speaking: _speech_bubble(actors_layer,entry.actor,entry.bounds)

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
  options = [["leave" if p.inside else "enter", "Leave" if p.inside else "Enter", -1], ["search","Search",-1], ["attack","Attack",selected_actor], ["heal","Heal self",0], ["heal","Heal ally",selected_actor], ["revive","Revive",selected_actor], ["barricade","Barricade",-1], ["repair","Repair building" if sim.current_block(p).ruin >= 3 else "Repair the room",-1], ["repair_generator","Fix generator",-1], ["dump","Dump body",selected_actor], ["close","Close doors",-1], ["request","Ask supplies",selected_actor], ["reload","Reload",-1], ["break","Break cades",-1], ["generator","Install gen.",-1], ["fuel","Fuel gen.",-1], ["scan","Scan",-1], ["manufacture","Make syringe",-1]]
  if sim.current_block(p).type == "tower" and p.inside: options.append(["jump","Jump",-1])
 else:
  options = [["leave" if p.inside else "enter", "Leave" if p.inside else "Enter", -1], ["attack","Claws",selected_actor,{"unarmed":true}], ["bite","Bite",selected_actor], ["close","Close doors",-1], ["break","Break cades",-1], ["ruin" if sim.current_block(p).get("ransack_hits",0) >= 5 else "ransack", "Ruin building" if sim.current_block(p).get("ransack_hits",0) >= 5 else "Ransack",-1], ["destroy_generator","Smash gen.",-1]]
  var weapon = sim.item_by_uid(p,p.equipped)
  if not weapon.is_empty() and weapon.kind in C.ZOMBIE_MELEE_ITEMS: options.append(["attack","Swing weapon",selected_actor])
 if not p.down:
  options.append_array([["say","Speak",-1],["scout","Scout shelter",-1],["extract","DNA sample",selected_actor],["tag","Spray tag",-1],["install_radio","Set up radio",-1],["repair_radio","Fix radio",-1],["broadcast","Broadcast",-1],["phone","Phone",selected_actor],["tune","Tune receiver",-1],["tune_transmitter","Tune transmitter",-1],["lookout","Binoculars",-1],["locate","GPS/map",-1],["feed","Feed",selected_actor],["drag","Drag prey",selected_actor],["groan","Groan",-1],["bellow","Bellow",-1],["gesture","Gesture",selected_actor],["smell","Scent death",-1],["trail","Scent trail",-1],["destroy_radio","Smash radio",-1],["smash_decorations","Smash decor",-1],["flare","Signal flare",-1]])
 options = options.filter(func(option): return sim.action_feedback(p,option[0],option[2],option[3] if option.size() > 3 else {},true).is_empty())
 for i in range(options.size()):
  var option = options[i]
  _action_button(option[0],option[1],Rect2(400+(i%10)*102,944+(i/10)*31,98,28),option[2],option[3] if option.size() > 3 else {})
 actions_bottom = 944+ceili(float(options.size())/10)*31

func _timing_text() -> String:
 if sim.sleeping: return "SLEEP 128×  ·  %d / 50 AP" % sim.player().ap
 if sim.player().down and sim.time_speed() > 1: return "DOWN %d× · Recovering to stand" % sim.time_speed()
 if resting: return "REST %d×  ·  %d / %d AP" % [int(sim.time_speed()),sim.player().ap,rest_target]
 var remaining = sim.player().busy_until-sim.now()
 if remaining > 0: return "Recovering: %.1fs  ·  %s" % [remaining,C.pretty(sim.player().last_action)]
 return "READY  ·  1 game minute / second"

func _action_button(command: String, text: String, bounds: Rect2, target: int = -1, data: Dictionary = {}) -> void:
 if not sim.action_feedback(sim.player(),command,target,data,true).is_empty(): return
 var ap_cost = sim.cost(sim.player(),command,target)
 var caption = text + (" · %d" % ap_cost if ap_cost > 0 else "")
 var node = button(page, caption, bounds, func():
  if command in ["tag","say","gesture","broadcast","phone","tune","tune_transmitter"]:
   message_command = command
   message_target = target
   message_data = data.duplicate()
   open_modal("message")
  elif command == "jump": open_modal("jump")
  else: dispatch(command,target,data))
 node.add_theme_font_size_override("font_size", 14)
 var caption_size = 14
 while caption_size > 11 and theme.default_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x > bounds.size.x-10: caption_size -= 1
 node.add_theme_font_size_override("font_size",caption_size)
 node.clip_text = true
 node.size = bounds.size
 var why = sim.action_feedback(sim.player(),command,target,data)
 node.disabled = not why.is_empty() or paused or resting
 var tip = "%s: %d AP • %.1fs recovery. No clock jump." % [text,ap_cost,sim.recovery(command)]
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
 if command == "search": data = {"store":mall_store}
 var result = sim.act(command,target,data)
 notice = result.message if not result.ok else (sim.messages.back().text if not sim.messages.is_empty() else "")
 feed.ingest(sim.messages)
 if result.ok and command in ["smell","trail","lookout","locate"]: modal = "intelligence"
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
 notice = "Saved to " + ProjectSettings.globalize_path("user://prototype-save.json") if sim.save_to("user://prototype-save.json") == OK else "Could not save."
 refresh()

func _load() -> void:
 map_origin = Vector2i(-1,-1)
 city_overview = false
 resting = false
 var result = sim.load_from("user://prototype-save.json")
 notice = "Loaded your neighbourhood." if result.is_empty() else result
 actor_visuals.clear()
 selected_actor = -1
 selected_item = -1
 feed.reset(sim.messages)
 refresh()

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
 label(overlay, {"map":sim.world_title.to_upper()+" / FIELD MAP", "skills":"SKILLS / ONE LIFE, TWO FORMS", "help":"SURVIVING DULSTON", "history":"EVENT HISTORY / PAUSED", "restart":"NEW GAME / WORLD SETUP", "jump":"LEAVE HUMAN LIFE BEHIND?","message":"COMMUNICATION","intelligence":"FIELD INTELLIGENCE"}[modal], Rect2(130,99,1050,48), 32, GOLD)
 button(overlay, "Close [Esc]", Rect2(1170,103,140,38), func(): modal = ""; refresh())
 if modal == "message": _message_modal()
 elif modal == "intelligence":
  var report = RichTextLabel.new()
  report.position = Vector2(140,170)
  report.size = Vector2(1160,670)
  report.text = sim.sense_report
  overlay.add_child(report)
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
  label(overlay,"Jumping kills your human character. You keep your identity and can rise as a zombie.",Rect2(140,230,1140,60),24)
  button(overlay,"Jump from the tower · 1 AP",Rect2(140,340,350,50),func(): modal = ""; dispatch("jump"),true)

func map_site_tooltip(b: Dictionary) -> String:
 var text = "%s\n%s" % [b.name,C.pretty(sim.visible_type(b,sim.player()))]
 if sim.is_building(b): text += "\n" + sim.exterior_building_clues(b)
 return text

func _map_modal() -> void:
 var p = sim.player()
 if p.down:
  rect(overlay,Rect2(130,160,1180,690),Color.BLACK)
  label(overlay,"Everything is dark. Stand up to see your surroundings.",Rect2(160,420,1100,50),24,MUTED)
  return
 if map_origin.x < 0: map_origin = Vector2i(p.x/10*10,p.y/10*10)
 button(overlay,"City" if not city_overview else "Local blocks",Rect2(135,154,180,30),func(): city_overview = not city_overview; refresh())
 button(overlay,"Find me",Rect2(325,154,150,30),func(): map_origin = Vector2i(p.x/10*10,p.y/10*10); city_overview = false; refresh())
 for i in range(4):
  var direction = [Vector2i(-10,0),Vector2i(10,0),Vector2i(0,-10),Vector2i(0,10)][i]
  button(overlay,["W","E","N","S"][i],Rect2(492+i*62,154,54,30),func(): map_origin = Vector2i(clampi(map_origin.x+direction.x,0,(sim.width-1)/10*10),clampi(map_origin.y+direction.y,0,(sim.height-1)/10*10)); city_overview = false; refresh())
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
    var tile = button(overlay,"",bounds,func(): map_origin = at; city_overview = false; refresh(),p.x/10 == x and p.y/10 == y)
    var title = label(tile,b.get("suburb",sim.world_title),Rect2(3,5,cell_width-9,48),15)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tile.tooltip_text = "%s [%d–%d, %d–%d]" % [b.get("suburb",sim.world_title),bx,mini(sim.width-1,bx+9),by,mini(sim.height-1,by+9)]
    continue
   if b.known:
    var mark = Control.new()
    mark.position = bounds.position-Vector2(135,196)
    mark.size = Vector2.ONE*61
    mark.tooltip_text = map_site_tooltip(b)
    mark.z_index = 1000
    mark.mouse_filter = Control.MOUSE_FILTER_PASS
    field_map.add_child(mark)
    if p.x == bx and p.y == by:
     var outline = rect(mark,Rect2(0,0,61,61),Color.TRANSPARENT,GOLD)
     outline.get_theme_stylebox("panel").set_border_width_all(1)
    necrotech_mark(mark,b,Vector2(22,9),14)
   else:
    var unknown = rect(field_map,Rect2(bounds.position-Vector2(135,196),bounds.size),INK)
    unknown.z_index = 1000
    label(unknown,"?",Rect2(20,12,35,35),23,MUTED)
 if city_overview: return
 label(overlay,"NECRONET INTELLIGENCE",Rect2(780,176,510,40),26,GOLD)
 var report = label(overlay,sim.scan_report,Rect2(780,230,510,190),24)
 report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label(overlay,"Scan age: %d minutes" % (sim.minute-sim.scan_minute) if sim.scan_minute >= 0 else "Not connected",Rect2(780,422,510,35),20,MUTED)
 var info = label(overlay,"%s · %d × %d blocks\n%s\n\nExplore to reveal local blocks. Use City to choose a suburb, or W/E/N/S to browse.\n\nWarm windows: powered · Broken roofs: ruined\nGold outline: your location\nNecroTech Employment reveals the NT logo.\n\nThe scan is a snapshot of tagged zombies, not live tracking.",Rect2(780,487,510,280),22,MUTED)
 info.text = info.text % [sim.world_title,sim.width,sim.height,sim.suburb_name(p)]
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

func ordered_people() -> Array:
 var people = sim.occupants(sim.current_block(sim.player()), sim.player().inside).duplicate()
 people.sort_custom(func(a,b):
  if a.human != b.human: return a.human
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
 match record.pose:
  "die":
   if a.down: return 15+mini(5,int(elapsed*10))
  "hurt":
   if elapsed < 0.3: return 21+mini(2,int(elapsed*10))
  "attack":
   if elapsed < 0.7: return 8+mini(6,int(elapsed*10))
 if a.down: return 20
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
 label(overlay,C.pretty(message_command)+": enter a message or choose a frequency.",Rect2(140,180,1100,42),24)
 var input = LineEdit.new()
 input.position = Vector2(140,260)
 input.size = Vector2(1140,50)
 input.max_length = 255
 input.text = "Keep together. Help the wounded and guard the entrance."
 overlay.add_child(input)
 var frequency = SpinBox.new()
 frequency.position = Vector2(140,340)
 frequency.size = Vector2(260,45)
 frequency.min_value = 25.0
 frequency.max_value = 30.0
 frequency.step = 0.01
 frequency.value = sim.current_block(sim.player()).frequency if message_command in ["broadcast","tune_transmitter"] else sim.player().channel
 overlay.add_child(frequency)
 var contacts = OptionButton.new()
 contacts.position = Vector2(440,340)
 contacts.size = Vector2(500,45)
 var ids: Array = []
 for a in sim.actors:
  if a.id == 0 or not a.human: continue
  if message_command == "phone" and sim.item_kind(a,"mobile_phone").is_empty(): continue
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
 label(overlay,"Choose a world, occupation and seed. A new game replaces the current session.",Rect2(140,157,1140,32),21)
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
 if new_world_mode == "random":
  label(overlay,"Exact ordinary-building counts",Rect2(140,267,600,30),23,GOLD)
  var scroll = ScrollContainer.new()
  scroll.name = "GenerationCounts"
  scroll.position = Vector2(140,310)
  scroll.size = Vector2(620,442)
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
  var setting_scroll = ScrollContainer.new()
  setting_scroll.name = "GenerationSettings"
  setting_scroll.position = Vector2(800,300)
  setting_scroll.size = Vector2(510,390)
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
  var explanation = label(overlay,text,Rect2(140,300,1130,320),23,MUTED)
  explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var error_text = label(overlay,new_game_error,Rect2(140,754,1140,48),18,RED)
 error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 button(overlay,"Start new game",Rect2(140,813,300,42),func():
  var config = new_world_config.duplicate(true)
  config.mode = new_world_mode
  var why = sim.start(new_seed,new_occupation,config)
  if not why.is_empty(): new_game_error = why; refresh(); return
  feed.reset(sim.messages)
  actor_visuals.clear()
  selected_actor = -1
  selected_item = -1
  map_origin = Vector2i(-1,-1)
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
