extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var s
var p: Dictionary
var b: Dictionary
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(message)

func ready(ap: int = 50) -> void:
 p.busy_until = s.now(); p.ap = ap; p.infected = false; p.down = false

func _initialize() -> void:
 s = Sim.new(); s.start(421)
 p = s.player(); b = s.current_block(p)
 for a in s.actors:
  if a.id != 0: a.x = 0; a.y = 0; a.inside = false; a.down = true
 s.reindex()
 b.type = "office"; b.generator = false; b.ruin = 0; b.ransack_hits = 0
 p.human = false; p.inside = true; p.zombie_skills = ["memories","ransack"]
 var xp = p.xp
 s.set_barricade_strength(b,21)
 for hit in range(1,6):
  ready()
  check(s.act("ransack").ok and p.ap == 49,"Each ransack costs one AP")
  check(b.ruin == 1 and b.ransack_hits == hit,"Five ransacks do not prematurely ruin the building")
  check(p.xp == xp+1,"Only first ransack grants XP")
  if hit > 1: check(s.messages.back().text.contains("ransack further rooms"),"Further-room flavour is used")
 ready()
 check(not s.act("ransack").ok and p.ap == 50,"Fifth ransack changes action to Ruin building")
 p.scout_site = b.id; s.actors[1].scout_site = b.id
 check(s.act("ruin").ok and b.ruin == 3 and b.ruined_at == s.minute and p.xp == xp+1,"Sixth action ruins without extra XP")
 check(p.scout_site == -1 and s.actors[1].scout_site == -1,"Ruin clears all scouting benefits")
 check(s.barricade_strength(b) == 21,"Ruin preserves EHB barricades")
 p.human = true; p.human_skills = ["construction","scout_safehouse"]; p.inventory.clear()
 ready()
 check(s.reason(p,"repair").contains("toolbox"),"Structural repair needs a toolbox")
 s.give_item(p,"toolbox")
 check(not s.reason(p,"scout").is_empty(),"Ruined shelter cannot be scouted")
 for days in [0,1,14,70,1000]:
  s.minute = b.ruined_at+days*1440
  check(s.cost(p,"repair") == 1+days,"Repair AP age is uncapped and increases daily")
 var tool = s.item_kind(p,"toolbox").uid
 xp = p.xp
 ready(1)
 check(s.act("repair").ok and p.ap == -1000 and b.ruin == 0 and p.xp == xp+1,"One repair clears ruin and spends full AP into debt")
 check(s.item_kind(p,"toolbox").uid == tool,"Repair neither consumes nor breaks toolbox")
 p.busy_until = s.now()
 check(not s.act("search").ok and p.ap == -1000,"Debt blocks further AP-spending actions")
 check(s.save_to("user://ruin-debt-test.json") == OK,"Negative AP saves")
 var loaded = Sim.new()
 check(loaded.load_from("user://ruin-debt-test.json").is_empty() and loaded.player().ap == -1000,"Negative AP survives loading")
 # Basic ransacking cleanup is a different, tool-free action and resets the streak.
 b.ruin = 1; b.ransack_hits = 5; b.ruined_at = -1
 p.inventory.clear(); p.human_skills = []; ready()
 check(s.act("repair").ok and p.ap == 49 and b.ruin == 0 and b.ransack_hits == 0,"Any survivor clears all basic ransack damage for one AP")
 # All living survivors block ransacking; active zombies block cleanup.
 var other = s.actors[1]
 other.x = p.x; other.y = p.y; other.inside = true; other.down = false; other.human = true; other.hp = 50
 p.human = false; ready(); s.reindex()
 check(not s.act("ransack").ok,"Living defenders prevent ransacking")
 other.human = false; p.human = true; b.ruin = 1
 check(not s.act("repair").ok,"Standing zombies prevent basic cleanup")
 other.down = true; s.reindex()
 # Immune and unpowerable categories are checked even with injected old state.
 for kind in C.OUTDOORS+["junkyard","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]:
  b.type = kind; b.ruin = 3; b.ransack_hits = 5
  s.initialize_block(b)
  check(b.ruin == 0 and b.ransack_hits == 0,"Immune location drops invalid legacy ruin: "+kind)
  p.human = false; ready()
  check(not s.act("ransack").ok and not s.act("ruin").ok,"Immune type cannot be damaged: "+kind)
  check(p.ap == 50 and b.ruin == 0 and b.ransack_hits == 0,"Rejected damage spends no AP or changes state: "+kind)
 p.human = true; p.inside = true
 s.give_item(p,"portable_generator"); s.give_item(p,"fuel_can")
 for kind in C.OUTDOORS+["junkyard","stadium","power_station"]:
  b.type = kind; b.generator = true; b.generator_hp = 6; b.fuel_until = s.minute+100
  ready()
  check(not s.can_host_generator(b) and not s.powered(b),"Unsupported square can never be lit: "+kind)
  s.initialize_block(b)
  check(not b.generator and not s.act("generator").ok and not s.act("fuel").ok,"Legacy generator removed and actions rejected")
  check(p.ap == 50 and not s.item_kind(p,"portable_generator").is_empty() and not s.item_kind(p,"fuel_can").is_empty(),"Rejected power actions preserve AP and supplies: "+kind)
 # Multi-AP actions other than repair may also overdraw, while NPCs conserve AP.
 b.type = "necrotech_lab"; p.human_skills = ["lab_experience","necronet"]; p.inventory.clear()
 b.generator = true; b.generator_hp = C.GENERATOR_HP; b.fuel_until = s.minute+100
 other.x = p.x; other.y = p.y; other.inside = true; other.human = false; other.down = false; other.hp = 30; other.zombie_skills = ["brain_rot"]
 s.give_item(p,"syringe"); ready(1); s.reindex()
 check(s.act("revive",other.id).ok and p.ap == -9,"Brain Rot revival costs ten AP and may overdraw")
 p.busy_until = s.now(); var minute = s.minute
 s.elapse(9*30)
 check(p.ap == 0 and not s.act("search").ok,"Zero AP is still exhausted")
 s.elapse(30)
 p.busy_until = s.now()
 check(p.ap == 1 and s.reason(p,"search").is_empty(),"Action eligibility returns at positive AP")
 other.human = true; other.down = false; other.ap = 1; other.busy_until = s.now(); other.human_skills = ["scout_safehouse"]
 check(not s.reason(other,"scout").is_empty(),"NPC refuses ordinary multi-AP debt")
 print("RUIN / AP DEBT CHECKS: %d FAILURES: %d" % [checks,failures])
 quit(1 if failures else 0)
