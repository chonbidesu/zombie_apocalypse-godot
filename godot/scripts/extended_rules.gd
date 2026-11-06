extends RefCounted

const C = preload("res://scripts/catalog.gd")
const CORPSE_FEED_BLOCKED = "You cannot feed on that body."
const CORPSE_DRAG_BLOCKED = "You cannot drag that body."
const BOOK_LORE = [
 "The last tram left Dulston with its destination board blank. The driver promised to fill it in once they knew where they were going.",
 "The hospital's night porter kept the keys on a string. After the power failed, the nurses found their way by listening for the jingle.",
 "A library ledger records seventy-three overdue books on evacuation day. Someone has renewed every one of them in pencil.",
 "The zoo keeper's notes say the parrots learned the evacuation siren before anyone knew what it meant.",
 "An old city guide recommends the view from the tower. In the margin, someone has written that the lights across the river went out one by one."
]
const POETRY_LORE = [
 "We count the windows left alight, and keep our names against the night.",
 "Rain fills the ticket booth. The trains are late again. No one complains.",
 "A kettle sings in an empty ward. For one small moment, someone is home.",
 "The city keeps its old addresses, even where the houses fell.",
 "I left a lamp beside the door. The moths came back before you did."
]
const COMMANDS = ["feed","drag","groan","bellow","gesture","say","smell","scout","extract","tag","install_radio","repair_radio","destroy_radio","broadcast","phone","tune","tune_transmitter","lookout","locate","read","drink","eat","inspect","decorate","smash_decorations","wear","flare"]

static func max_hp(a: Dictionary) -> int:
 return 60 if "body_building" in a.human_skills or (not a.human and "flesh_rot" in a.zombie_skills) else 50

static func command_reason(s,a: Dictionary, command: String, target: int, data: Dictionary) -> String:
 var b = s.current_block(a)
 var human_commands = ["scout","extract","tag","install_radio","repair_radio","broadcast","phone","tune","tune_transmitter","lookout","locate","read","drink","eat","inspect","decorate","wear","flare"]
 if not a.human and command in human_commands: return "This requires living hands."
 var skill = {"feed":"digestion","drag":"feeding_drag","groan":"feeding_groan","bellow":"bellow","gesture":"flailing_gesture","smell":"scent_death","scout":"scout_safehouse","extract":"necro_employment","install_radio":"radio_operation","broadcast":"radio_operation","tune_transmitter":"radio_operation"}.get(command,"")
 if not skill.is_empty() and not s.has_skill(a,skill): return "Requires "+C.SKILLS[skill].name+"."
 if command in ["feed","drag","groan","bellow","gesture","destroy_radio","smash_decorations","smell"] and a.human: return "This is an undead ability."
 if command in ["feed","drag","extract"]:
  if target < 0 or target >= s.actors.size() or not s.nearby(a,s.actors[target]): return "Select a nearby character."
  var t = s.actors[target]
  if command == "feed":
   if not t.down: return "Choose a dead body."
   if a.hp >= max_hp(a): return "You are already at full health."
   if t.human: return CORPSE_FEED_BLOCKED
   if t.get("fed",0) >= 10: return "The body has been picked clean."
  if command == "drag":
   if not a.inside or (not t.down and (not t.human or t.hp > 12)): return "Choose a dying or unconscious survivor inside."
   if b.barricade > 0 or s.doors_closed(b): return "Dragging needs an open, unbarricaded entrance."
   if t.down and not t.human: return CORPSE_DRAG_BLOCKED
  if command == "extract":
   if t.human or t.down: return "Choose a standing zombie."
   if s.has_skill(t,"brain_rot"): return "Brain Rot prevents DNA extraction."
   if t.tagged_until > s.minute: return "This zombie already has a current DNA tag."
   if s.item_kind(a,"dna_extractor").is_empty(): return "You need a DNA extractor."
 if command in ["install_radio","repair_radio","destroy_radio","decorate","smash_decorations","scout"] and (not a.inside or not s.is_building(b)): return "You must be inside."
 if command == "scout" and b.ruin >= 3: return "Repair this shelter before scouting it."
 if command in ["groan","bellow"] and s.occupants(b,a.inside).filter(func(t): return t.human and not t.down).is_empty(): return "You need living prey nearby to call a feeding horde."
 if command == "say" and not a.human and not s.has_skill(a,"death_rattle"): return "Death Rattle is needed for zombie speech."
 if command == "tag" and s.item_kind(a,"spray_can").is_empty(): return "You need a spray can."
 if command == "install_radio":
  if b.radio: return "A transmitter is already installed."
  if b.ruin > 0: return "Repair the building first."
  if s.item_kind(a,"radio_transmitter").is_empty(): return "You need a radio transmitter."
 if command == "repair_radio":
  if not b.radio or b.radio_hp >= 6: return "The transmitter needs no repairs."
  if s.item_kind(a,"toolbox").is_empty(): return "You need a toolbox."
  if not s.has_skill(a,"construction"): return "Construction is required to repair transmitters."
 if command == "destroy_radio" and not b.radio: return "No transmitter is installed."
 if command == "smash_decorations" and b.decorations.is_empty(): return "There are no decorations here."
 if command in ["broadcast","tune_transmitter"]:
  if not a.inside or not b.radio or b.radio_hp <= 0 or not s.powered(b): return "You need a powered radio transmitter."
 if command == "phone":
  if s.item_kind(a,"mobile_phone").is_empty(): return "You need a mobile phone."
  if not s.phone_coverage(a): return "Your suburb phone mast has no power."
  if target < 0 or target >= s.actors.size(): return "Select a contact."
  if not s.actors[target].human or s.actors[target].down: return "That contact cannot answer. Stand them up first."
  if s.item_kind(s.actors[target],"mobile_phone").is_empty(): return "That contact has no phone."
  if not s.phone_coverage(s.actors[target]): return "Your contact has no phone coverage."
 if command == "tune" and s.item_kind(a,"radio").is_empty(): return "You need a radio receiver."
 if command == "lookout":
  if s.item_kind(a,"binoculars").is_empty(): return "You need binoculars."
  if a.inside:
   if b.type not in C.TALL_BUILDINGS: return "Use binoculars indoors from a tall building."
   if not C.COMPASS_DIRECTIONS.has(data.get("direction","")): return s.BINOCULAR_DIRECTION_REQUIRED
  elif b.type not in ["street","monument"]: return "Use binoculars outdoors from a street, square or monument."
 if command == "locate" and s.item_kind(a,"gps_unit").is_empty(): return "You need a GPS unit."
 if command in ["read","drink","eat","inspect","decorate","wear"]:
  var item = s.item_by_uid(a,int(data.get("uid",-1)))
  if item.is_empty() or C.ITEMS[item.kind].get("action","") != command: return "Select an appropriate carried item."
  if command in ["drink","eat"] and a.hp >= max_hp(a): return "You are already at full health."
  if command == "decorate" and b.decorations.size() >= 13: return "There is no room for another decoration."
 if command == "flare" and s.item_kind(a,"flare_gun").is_empty(): return "You need a flare gun."
 return ""

static func perform(s,a: Dictionary, command: String, target: int, data: Dictionary) -> String:
 var b = s.current_block(a)
 var text = str(data.get("text","Keep together. Help the wounded and guard the entrance.")).strip_edges().left(255)
 match command:
  "feed":
   s.actors[target].fed += 1
   a.hp = mini(max_hp(a),a.hp+4)
   return "%s strength." % s.action_phrase(a,"feed on a corpse and regain","feeds on a corpse and regains")
  "drag":
   a.inside = false
   s.actors[target].inside = false
   s.secure_zombie_exit(a,b)
   s.clear_grasp(a)
   s.clear_grasp(s.actors[target])
   return "%s %s into the street!" % [s.action_phrase(a,"drag","drags"),s.display_name(s.actors[target])]
  "groan","bellow","flare":
   var humans = s.occupants(b,a.inside).filter(func(t): return t.human and not t.down).size()
   var radius = 10 if command == "bellow" and humans >= 25 else mini(6,maxi(1,humans))
   if command == "flare":
    s.consume(a,s.item_kind(a,"flare_gun"))
    radius = 10
   for other in s.actors:
    if other.down or other.human: continue
    if maxi(absi(other.x-a.x),absi(other.y-a.y)) <= radius:
     other.memory = b.id
     other.memory_until = s.minute+90
   return "%s %s over the neighbourhood, calling attention to %s." % [s.action_phrase(a,"send","sends"),"a red flare" if command == "flare" else ("a thunderous bellow" if radius == 10 else "a feeding groan"),b.name]
  "gesture": return "%s towards %s." % [s.action_phrase(a,"gesture","gestures"),s.display_name(s.actors[target]) if target >= 0 else str(data.get("direction","the street"))]
  "say":
   if not a.human:
    var zamgrh = ""
    for letter in text.to_lower(): zamgrh += letter if letter in "abghmnrz .!?" else "h"
    text = zamgrh
   if a.id > 0: s.speak(a,text)
   else: _set_speech(a,text,s.now())
   return "%s: %s" % [s.action_phrase(a,"say","says"),text]
  "smell":
   if a.id == 0:
    s.scent_heatmap = s.scent_death_snapshot(a)
    s.sense_report = "SCENT DEATH"
   return "%s the scents of death around the neighbourhood." % s.action_phrase(a,"read","reads")
  "scout":
   a.scout_site = b.id
   a.scout_day = s.minute/1440
   a.scout_used = 0
   return "%s this shelter's routes. Five actions each day will cost one less AP." % s.action_phrase(a,"memorise","memorises")
  "extract":
   var t = s.actors[target]
   t.tagged_until = s.minute+1440
   a.xp += 4
   return "%s %s with a DNA sample; the lab network can track this tag for a day." % [s.action_phrase(a,"identify","identifies"),s.display_name(t)]
  "tag":
   b.graffiti = text
   var can = s.item_kind(a,"spray_can")
   if s.rng.randf() < (0.1 if s.has_skill(a,"tagging") else 0.2): s.consume(a,can)
   if not a.inside and s.has_skill(a,"tagging"):
    if b.type in ["armoury","monument","police_department"]: a.xp += 2
    elif b.type in ["mansion","power_station","bank","school"]: a.xp += 1
   return "%s a message: %s" % [s.action_phrase(a,"spray","sprays"),text]
  "install_radio":
   b.radio = true
   b.radio_hp = 6
   s.consume(a,s.item_kind(a,"radio_transmitter"))
   return "%s a radio transmitter." % s.action_phrase(a,"install","installs")
  "repair_radio":
   b.radio_hp = 6
   a.xp += 1
   return "%s the radio transmitter." % s.action_phrase(a,"repair","repairs")
  "destroy_radio":
   b.radio_hp = maxi(0,b.radio_hp-1)
   if b.radio_hp == 0:
    b.radio = false
    a.xp += 5
   return "%s the radio transmitter's casing." % s.action_phrase(a,"smash","smashes")
  "tune_transmitter":
   b.frequency = float(data.get("frequency",b.frequency))
   return "%s the transmitter to %.2f MHz." % [s.action_phrase(a,"tune","tunes"),b.frequency]
  "broadcast":
   b.frequency = float(data.get("frequency",b.frequency))
   return "[Radio %.2f MHz] %s: %s" % [b.frequency,s.display_name(a),text]
  "phone": return "[Phone to %s] %s: %s" % [s.display_name(s.actors[target]),s.display_name(a),text]
  "tune":
   a.channel = float(data.get("frequency",27.0))
   return "%s the receiver to %.2f MHz." % [s.action_phrase(a,"tune","tunes"),a.channel]
  "lookout":
   if a.id == 0: s.survey_binoculars(a,str(data.get("direction","")))
   if a.inside:
    return "%s %s from the roof." % [s.action_phrase(a,"look","looks"),data.direction]
   return "%s the surrounding streets and skyline." % s.action_phrase(a,"survey","surveys")
  "locate":
   for site in s.blocks:
    if maxi(absi(site.x-a.x),absi(site.y-a.y)) > 1: continue
    site.known = true
   s.sense_report = "Position [%d,%d]\n" % [a.x,a.y]
   return "%s position on the map." % s.action_phrase(a,"check your","checks their")
  "read":
   var item = s.item_by_uid(a,int(data.uid))
   var prose = item.kind == "book"
   var xp = 0
   if prose and s.rng.randf() < 0.1:
    xp = 2 if C.occupation_category(a.job) == "science" else 1
   var passages = BOOK_LORE if prose else POETRY_LORE
   var passage = passages[s.rng.randi_range(0,passages.size()-1)]
   a.xp += xp
   s.consume(a,item)
   var message = "%s %s. “%s”" % [s.action_phrase(a,"read","reads"),"a book" if prose else "a poetry book",passage]
   if xp > 0: message += " (+%d XP)" % xp
   return message
  "drink","eat":
   var item = s.item_by_uid(a,int(data.uid))
   a.hp = mini(max_hp(a),a.hp+1)
   if command == "drink": s.consume(a,item)
   return "%s one HP." % s.action_phrase(a,"take a small comfort and recover","takes a small comfort and recovers")
  "inspect": return "%s %s." % [s.action_phrase(a,"inspect","inspects"),C.ITEMS[s.item_by_uid(a,int(data.uid)).kind].name]
  "wear":
   a.outfit = "A change of scavenged civilian clothing."
   s.consume(a,s.item_by_uid(a,int(data.uid)))
   return "%s into scavenged clothes." % s.action_phrase(a,"change","changes")
  "decorate":
   var item = s.item_by_uid(a,int(data.uid))
   b.decorations.append(item.kind)
   s.consume(a,item)
   return "%s %s." % [s.action_phrase(a,"set up","sets up"),C.ITEMS[item.kind].name]
  "smash_decorations":
   b.decorations.pop_back()
   a.xp += 1
   return "%s one of the decorations." % s.action_phrase(a,"smash","smashes")
 return ""

static func _set_speech(a: Dictionary, text: String, now: float) -> void:
 a.speech = text
 a.speech_until = now+6.0
