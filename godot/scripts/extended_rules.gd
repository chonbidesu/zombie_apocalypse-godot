extends RefCounted

const C = preload("res://scripts/catalog.gd")
const COMMANDS = ["feed","drag","groan","bellow","gesture","say","smell","trail","scout","extract","tag","install_radio","repair_radio","destroy_radio","broadcast","phone","tune","lookout","locate","read","drink","eat","inspect","decorate","smash_decorations","wear","flare"]

static func max_hp(a: Dictionary) -> int:
 return 60 if "body_building" in a.human_skills or (not a.human and "flesh_rot" in a.zombie_skills) else 50

static func command_reason(s,a: Dictionary, command: String, target: int, data: Dictionary) -> String:
 var b = s.current_block(a)
 var human_commands = ["scout","extract","tag","install_radio","repair_radio","broadcast","phone","tune","lookout","locate","read","drink","eat","inspect","decorate","wear","flare"]
 if not a.human and command in human_commands: return "This requires living hands."
 var skill = {"feed":"digestion","drag":"feeding_drag","groan":"feeding_groan","bellow":"bellow","gesture":"flailing_gesture","smell":"scent_death","trail":"scent_trail","scout":"scout_safehouse","extract":"necro_employment"}.get(command,"")
 if not skill.is_empty() and not s.has_skill(a,skill): return "Requires "+C.SKILLS[skill].name+"."
 if command in ["feed","drag","groan","bellow","gesture","destroy_radio","smash_decorations"] and a.human: return "This is an undead ability."
 if command in ["feed","drag","extract"]:
  if target < 0 or target >= s.actors.size() or not s.nearby(a,s.actors[target]): return "Select a nearby character."
  var t = s.actors[target]
  if command == "feed":
   if not t.down or t.human: return "Choose a dead, untainted body."
   if t.get("fed",0) >= 10: return "The body has been picked clean."
   if a.hp >= max_hp(a): return "You are already at full health."
  if command == "drag":
   if not a.inside or not t.human or t.down or t.hp > 12: return "Choose a dying survivor inside."
   if b.barricade > 0 or s.doors_closed(b): return "Dragging needs an open, unbarricaded entrance."
  if command == "extract":
   if t.human or t.down: return "Choose a standing zombie."
   if t.tagged_until > s.minute: return "This zombie already has a current DNA tag."
   if s.item_kind(a,"dna_extractor").is_empty(): return "You need a DNA extractor."
 if command in ["install_radio","repair_radio","destroy_radio","decorate","smash_decorations","scout"] and (not a.inside or not s.is_building(b)): return "You must be inside."
 if command == "scout" and b.ruin > 0: return "Repair this shelter before scouting it."
 if command == "trail":
  if a.trail_from < 0 or a.trail_until < s.minute: return "No recent scent trail remains."
  var t = s.actors[a.trail_from]
  if t.down or not t.human or maxi(absi(a.x-t.x),absi(a.y-t.y)) > 10: return "The trail has gone cold."
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
 if command == "broadcast":
  if not a.inside or not b.radio or b.radio_hp <= 0 or not s.powered(b): return "You need a powered radio transmitter."
  var frequency = float(data.get("frequency",27.0))
  if frequency >= 26 and frequency <= 28 and not s.has_skill(a,"radio_operation"): return "Radio Operation is needed on restricted channels."
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
  if not a.inside or b.type not in ["hotel","tower","office","necrotech_lab"]: return "Use binoculars from a tall building."
 if command == "locate" and s.item_kind(a,"gps_unit").is_empty() and s.item_kind(a,"map").is_empty(): return "You need a GPS unit or map."
 if command in ["read","drink","eat","inspect","decorate","wear"]:
  var item = s.item_by_uid(a,int(data.get("uid",-1)))
  if item.is_empty() or C.ITEMS[item.kind].get("action","") != command: return "Select an appropriate carried item."
  if command in ["drink","eat"] and a.hp >= max_hp(a): return "You are already at full health."
  if command == "decorate" and b.decorations.size() >= 13: return "There is no room for another decoration."
 if command == "flare" and s.item_kind(a,"flare_gun").is_empty(): return "You need a flare gun."
 return ""

static func perform(s,a: Dictionary, command: String, target: int, data: Dictionary) -> String:
 var b = s.current_block(a)
 var name = "You" if a.id == 0 else s.display_name(a)
 var text = str(data.get("text","Keep together. Help the wounded and guard the entrance.")).strip_edges().left(255)
 match command:
  "feed":
   s.actors[target].fed += 1
   a.hp = mini(max_hp(a),a.hp+4)
   return "%s feed on a corpse and regain strength." % name
  "drag":
   a.inside = false
   s.actors[target].inside = false
   s.clear_grasp(a)
   s.clear_grasp(s.actors[target])
   return "%s drag %s into the street!" % [name,s.display_name(s.actors[target])]
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
   return "%s send %s over the neighbourhood, calling attention to %s." % [name,"a red flare" if command == "flare" else ("a thunderous bellow" if radius == 10 else "a feeding groan"),b.name]
  "gesture": return "%s gesture towards %s." % [name,s.display_name(s.actors[target]) if target >= 0 else str(data.get("direction","the street"))]
  "say":
   if not a.human:
    var zamgrh = ""
    for letter in text.to_lower(): zamgrh += letter if letter in "abghmnrz .!?" else "h"
    text = zamgrh
   if a.id > 0: s.speak(a,text)
   else: _set_speech(a,text,s.now())
   return "%s say: %s" % [name,text]
  "smell":
   var lines: Array[String] = []
   for site in s.blocks:
    if maxi(absi(site.x-a.x),absi(site.y-a.y)) > 5: continue
    var zombies = 0
    var bodies = 0
    var changing = 0
    for other in s.occupants(site):
     if other.down:
      bodies += 1
      if other.human: changing += 1
     elif not other.human: zombies += 1
    if zombies+bodies > 0: lines.append("[%d,%d] %d undead, %d bodies, %d revivifying" % [site.x,site.y,zombies,bodies,changing])
   s.sense_report = "SCENT DEATH\n"+"\n".join(lines)
   return "%s read the scents of death around the neighbourhood." % name
  "trail":
   var t = s.actors[a.trail_from]
   a.memory = s.current_block(t).id
   a.memory_until = s.minute+30
   s.sense_report = "A familiar scent leads to [%d,%d]." % [t.x,t.y]
   return "%s catch a familiar scent leading away." % name
  "scout":
   a.scout_site = b.id
   a.scout_day = s.minute/1440
   a.scout_used = 0
   return "%s memorise this shelter's routes. Five actions each day will cost one less AP." % name
  "extract":
   var t = s.actors[target]
   if s.has_skill(t,"brain_rot") and s.rng.randf() < 0.5: return "The degraded sample cannot be read."
   t.tagged_until = s.minute+1440
   a.xp += 4
   return "%s identify %s with a DNA sample; the lab network can track this tag for a day." % [name,s.display_name(t)]
  "tag":
   b.graffiti = text
   var can = s.item_kind(a,"spray_can")
   if s.rng.randf() < (0.1 if s.has_skill(a,"tagging") else 0.2): s.consume(a,can)
   if not a.inside and s.has_skill(a,"tagging"):
    if b.type in ["armoury","monument","police_department"]: a.xp += 2
    elif b.type in ["mansion","power_station","bank","school"]: a.xp += 1
   return "%s spray a message: %s" % [name,text]
  "install_radio":
   b.radio = true
   b.radio_hp = 6
   s.consume(a,s.item_kind(a,"radio_transmitter"))
   return "%s install a radio transmitter." % name
  "repair_radio":
   b.radio_hp = 6
   a.xp += 1
   return "%s repair the radio transmitter." % name
  "destroy_radio":
   b.radio_hp = maxi(0,b.radio_hp-1)
   if b.radio_hp == 0:
    b.radio = false
    a.xp += 5
   return "%s smash the radio transmitter's casing." % name
  "broadcast":
   b.frequency = float(data.get("frequency",27.0))
   return "[Radio %.2f MHz] %s: %s" % [b.frequency,s.display_name(a),text]
  "phone": return "[Phone to %s] %s: %s" % [s.display_name(s.actors[target]),s.display_name(a),text]
  "tune":
   a.channel = float(data.get("frequency",27.0))
   return "%s tune the receiver to %.2f MHz." % [name,a.channel]
  "lookout","locate":
   var lines: Array[String] = []
   var radius = 3 if command == "lookout" else 1
   for site in s.blocks:
    if maxi(absi(site.x-a.x),absi(site.y-a.y)) > radius: continue
    site.known = true
    if command == "lookout": lines.append("[%d,%d] %s: %d figures outside" % [site.x,site.y,site.name,s.occupants(site,false).filter(func(t): return not t.down).size()])
   s.sense_report = "Position [%d,%d]\n" % [a.x,a.y]+"\n".join(lines)
   return "%s check %s." % [name,"the view from the roof" if command == "lookout" else "your position on the map"]
  "read":
   var item = s.item_by_uid(a,int(data.uid))
   if item.kind == "book":
    var xp = (2 if C.occupation_category(a.job) == "science" else 1) if s.rng.randf() < 0.1 else 0
    a.xp += xp
    if s.rng.randf() < 0.08: s.consume(a,item)
    return "%s read a chapter%s." % [name," and learn something useful" if xp > 0 else " by the available light"]
   if item.kind == "newspaper":
    s.consume(a,item)
    return "QUARANTINE ADVICE: Clear bodies from shelters. Medical treatment cures infection. Keep an escape route."
   return "The poem reads: We count the windows left alight, and keep our names against the night."
  "drink","eat":
   var item = s.item_by_uid(a,int(data.uid))
   a.hp = mini(max_hp(a),a.hp+1)
   if command == "drink": s.consume(a,item)
   return "%s take a small comfort and recover one HP." % name
  "inspect": return "%s inspect %s." % [name,C.ITEMS[s.item_by_uid(a,int(data.uid)).kind].name]
  "wear":
   a.outfit = "A change of scavenged civilian clothing."
   s.consume(a,s.item_by_uid(a,int(data.uid)))
   return "%s change into scavenged clothes." % name
  "decorate":
   var item = s.item_by_uid(a,int(data.uid))
   b.decorations.append(item.kind)
   s.consume(a,item)
   return "%s set up %s." % [name,C.ITEMS[item.kind].name]
  "smash_decorations":
   b.decorations.pop_back()
   a.xp += 1
   return "%s smash one of the decorations." % name
 return ""

static func _set_speech(a: Dictionary, text: String, now: float) -> void:
 a.speech = text
 a.speech_until = now+6.0
