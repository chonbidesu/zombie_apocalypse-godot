extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var checks = 0
var failures = 0

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: "+message)

func isolated():
 var s = Sim.new()
 s.start()
 # Keep identity records but prevent NPC interventions in transaction tests.
 for a in s.actors:
  if a.id > 0:
   a.x = 0
   a.y = 0
   a.down = true
   a.ready_at = 999999
 s.reindex()
 return s

func _initialize() -> void:
 melee_combat_rules()
 feedback_rules()
 restored_location_rules()
 perception_rules()
 activity_perspective()
 window_and_necronet_rules()
 binocular_rules()
 reading_and_newspaper()
 var s = isolated()
 var p = s.player()
 var state = JSON.stringify(s.actors)
 check(not s.act("move",-1,{"dx":2,"dy":0}).ok,"No teleport moves")
 check(JSON.stringify(s.actors) == state and s.minute == 480,"Invalid move is atomic")
 p.ap = 0
 check(not s.act("search").ok and p.ap == 0,"AP cannot underflow")
 p.ap = 50
 check(s.act("move",-1,{"dx":1,"dy":0}).ok,"Adjacent move succeeds")
 check(is_equal_approx(p.busy_until,s.now()+0.5) and is_equal_approx(s.recovery("close"),0.6),"Movement and default actions use the shorter recovery")
 check(p.x == 5 and p.y == 4 and not p.inside and p.ap == 49 and s.minute == 480,"Movement costs 1 AP without advancing time")
 check(not s.act("enter").ok,"Recovery rejects action spam")
 s.elapse(1.0)
 check(s.act("enter").ok and p.inside,"Human can pass moderate barricade")
 p.x = 0
 p.y = 0
 check(not s.act("move",-1,{"dx":-1,"dy":0}).ok,"City edges reject movement")
 p.x = 4
 p.y = 4
 p.inside = true
 s.reindex()
 s.elapse(2.0)
 p.human_skills.append("free_running")
 check(s.act("move",-1,{"dx":1,"dy":0}).ok and p.inside,"Free running preserves inside state")

 s = isolated()
 p = s.player()
 var inventory = p.inventory.duplicate(true)
 p.xp = 230
 p.zombie_skills.append("lurching_gait")
 check(s.learn("ankle_grab").is_empty(),"Can buy zombie skill while human")
 check(s.has_skill(p,"ankle_grab") and p.xp == 130,"Ankle Grab works across forms, shared XP charged")
 check(not s.learn("ankle_grab").is_empty() and p.xp == 130,"No duplicate skill purchases")
 s.die(p)
 check(s.display_name(p) == "Ashen Alex" and p.inventory == inventory,"Death changes name and preserves inventory")
 check(p.human_skills.has("construction") and p.zombie_skills.has("ankle_grab"),"Both trees survive death")
 check(not s.act("equip",-1,{"uid":inventory[0].uid}).ok,"Undead cannot equip")
 check(not s.act("stand").ok,"Death cooldown enforced")
 s.advance(30)
 check(s.act("stand").ok and not p.down and p.hp == 25,"Zombie rises")
 check(p.ap == 49,"Ankle Grab reduces zombie standing cost")
 check(not s.has_skill(p,"construction"),"Human skill dormant as zombie")
 s.elapse(2.0)
 check(s.act("drop",-1,{"uid":inventory[1].uid}).ok and p.inventory.size() == 3,"Undead may drop items")
 check(s.learn("first_aid").is_empty() and p.human_skills.has("first_aid"),"Can buy human skill while undead")

 s = isolated()
 p = s.player()
 var z = s.actors[15]
 z.x = 4
 z.y = 4
 z.inside = true
 z.down = false
 z.hp = 30
 z.ready_at = 0
 z.zombie_skills.append("brain_rot")
 s.reindex()
 var syringe_count = p.inventory.size()
 check(not s.act("revive",z.id).ok and p.inventory.size() == syringe_count,"Brain Rot blocks normal revival without consuming supplies")
 p.x = 5
 z.x = 5
 p.human_skills.append("necronet")
 s.reindex()
 check(s.reason(p,"revive",z.id).is_empty(),"Powered lab and trained scientist allow Brain Rot revival")
 s.execute(p,"revive",z.id)
 check(p.ap == 40 and p.inventory.size() == syringe_count-1,"Revival charges 10 AP and consumes exactly one syringe")
 check(z.human and z.down and z.hp == 0,"Revival produces downed human")
 check(s.display_name(z) == z.first+" "+z.last,"Revival restores human name")
 s.advance(5)
 check(z.last_action == "stand","Revived NPC wakes on its standing deadline")
 check(z.human and not z.down and z.hp == 25,"Revived human stands correctly")

 s = isolated()
 p = s.player()
 s.give_item(p,"pistol")
 s.give_item(p,"pistol_clip")
 var gun = s.item_kind(p,"pistol")
 s.act("equip",-1,{"uid":gun.uid})
 s.elapse(1.0)
 gun.ammo = 0
 check(s.act("reload").ok and gun.ammo == 6 and s.item_kind(p,"pistol_clip").is_empty(),"Reload consumes magazine and fills gun")
 s.elapse(2.0)
 p.hp = 30
 check(s.act("heal",0).ok and p.hp == 35 and s.item_kind(p,"first_aid_kit").is_empty(),"Healing consumes kit")
 s.elapse(2.0)
 s.current_block(p).ruin = 2
 check(s.act("repair").ok and s.current_block(p).ruin == 0,"Repair clears ransacking in one action")
 s.current_block(p).ruin = 1
 s.elapse(3.0)
 check(not s.act("barricade").ok,"Cannot barricade damaged building")
 s.elapse(3.0)
 s.current_block(p).ruin = 0
 var before_ap = p.ap
 var before_time = s.minute
 check(s.act("barricade").ok and s.minute == before_time,"Barricade attempt does not jump time")
 check(p.ap == before_ap-1,"Barricade AP charged once")
 p.ap = 10
 s.advance(30)
 check(p.ap == 11,"Recovery is one AP per thirty minutes")
 p.ap = 50
 s.advance(30)
 check(p.ap == 50,"Recovery capped at 50")
 p.ap = 10
 check(s.begin_rest(1).is_empty() and p.ap == 10,"Rest starts without instant recovery")
 s.elapse(4.0)
 check(p.ap == 11 and not s.resting,"Visible accelerated rest uses ordinary recovery")
 z = s.actors[15]
 z.x = p.x
 z.y = p.y
 z.inside = p.inside
 z.human = false
 z.down = false
 s.reindex()
 before_time = s.minute
 check(not s.begin_rest(1).is_empty() and s.minute == before_time,"Rest refuses immediate danger")

 # NPC roles use the same rules, including supplies and AP.
 s = isolated()
 p = s.player()
 p.hp = 30
 var doctor = s.actors[1]
 doctor.human_skills.append("first_aid")
 doctor.x = p.x
 doctor.y = p.y
 doctor.inside = true
 doctor.down = false
 doctor.ready_at = 0
 s.reindex()
 s._npc_turn(doctor)
 check(p.hp == 40 and doctor.ap == 49,"Doctor heals player using AP")
 var engineer = s.actors[2]
 engineer.x = 4
 engineer.y = 4
 engineer.inside = true
 engineer.down = false
 s.current_block(p).ruin = 1
 s.reindex()
 s._npc_turn(engineer)
 check(s.current_block(p).ruin == 0 and engineer.ap == 49,"Engineer repairs shelter")
 s.die(p)
 var scientist = s.actors[3]
 scientist.human_skills.append("lab_experience")
 scientist.x = 4
 scientist.y = 4
 scientist.inside = true
 scientist.down = false
 s.reindex()
 s._npc_turn(scientist)
 check(p.human and p.down and scientist.ap == 49,"Scientist revives player for one AP")
 var busy_ap = scientist.ap
 s._npc_turn(scientist)
 check(scientist.ap == busy_ap and scientist.busy_until == s.now()+1.0,"NPC revival uses the fixed recovery independent of AP cost")

 # Save round-trip preserves simulation state and random continuation exactly.
 s = Sim.new()
 s.start(991)
 s.advance(180)
 s.player().xp = 76
 s.blocks[44].doors = false
 var expected_rng = s.rng.state
 var expected_actors = JSON.stringify(s.actors)
 check(s.save_to("res://test-save.json") == OK,"Save succeeds")
 var loaded = Sim.new()
 check(loaded.load_from("res://test-save.json").is_empty(),"Save loads")
 check(loaded.minute == s.minute and loaded.rng.state == expected_rng,"Time and RNG restored")
 check(JSON.parse_string(JSON.stringify(loaded.actors)) == JSON.parse_string(expected_actors),"Inventory, skills and actors restored without starter duplication")
 check(loaded.blocks[44].doors == false,"Doors restored")
 s.advance(120)
 loaded.advance(120)
 check(JSON.stringify(s.actors) == JSON.stringify(loaded.actors),"Loaded simulation follows same random future")
 check(JSON.stringify(s.blocks) == JSON.stringify(loaded.blocks),"Building evolution follows same future")
 check(not loaded.load_from("res://does-not-exist.json").is_empty(),"Missing save fails gracefully")

 # Real-time clock is invariant to frame partitioning, including NPC random decisions.
 s = Sim.new()
 s.start(123)
 loaded = Sim.new()
 loaded.start(123)
 s.elapse(12.0)
 for frame in range(120): loaded.elapse(0.1)
 check(s.clock_step == loaded.clock_step and JSON.stringify(s.actors) == JSON.stringify(loaded.actors),"Frame partitioning preserves clock and NPC decisions")
 s = isolated()
 s.die(s.player())
 check(s.begin_rest(10).is_empty(),"Downed full-AP character can rest")
 s.elapse(0.5)
 check(s.resting,"Rest does not end before standing delay")
 s.elapse(4.0)
 check(not s.resting and s.reason(s.player(),"stand").is_empty(),"Rest reaches standing readiness")
 var feed = preload("res://scripts/event_feed.gd").new()
 s = isolated()
 feed.reset(s.messages)
 var count_before = feed.rows.size()
 s.log_event("Scott repairs the shelter.","ALLY",2,"repair")
 feed.ingest(s.messages)
 check(feed.rows.size() == count_before and feed.pending.size() == 1,"Routine activity waits for presentation pacing")
 s.log_event("You search.","PLAYER",0,"search")
 feed.ingest(s.messages)
 check(feed.pending.is_empty() and feed.rows.back().category == "PLAYER","Player feedback immediate after earlier routine summary")
 s.log_event("You are struck.","ALERT",15,"attack",true)
 feed.ingest(s.messages)
 check(feed.rows.back().urgent,"Damage alert never waits for chat playback")
 check(not "Scott" in feed.format_rows(feed.rows,"You") and "You search" in feed.format_rows(feed.rows,"You"),"Player filter excludes NPC messages")
 var styled = feed.format_rows([
  {"category":"ALLY","minute":480,"action":"speech","text":"Scott: Hold [i] here."},
  {"category":"WORLD","minute":480,"action":"","text":"Notice: Stay alert."},
  {"category":"ENEMY","minute":480,"action":"attack","text":"A zombie misses."},
  {"category":"ENEMY","minute":480,"action":"bite","text":"A zombie bites.","attack_hit":true},
 ]).split("\n")
 check(styled[0].contains("[i]“Hold [lb]i] here.”[/i]") and not styled[1].contains("[i]"),"Dialogue is quoted and italicized while notices and user brackets remain literal")
 check(styled[2].begins_with("[color=ed9a87]") and styled[3].begins_with("[color=d77e74]"),"Enemy attacks retain the miss color and darken successful hits")
 for i in range(60): s.log_event("Routine work %d" % i,"ALLY",2,"repair")
 feed.ingest(s.messages)
 check(feed.pending.size() < feed.MAX_PENDING,"Routine presentation backlog bounded")
 check(s.messages.size() > feed.rows.size(),"Full history preserves detail omitted from feed")

 # Multi-seed soak: scheduler completes, identities persist, resources stay valid.
 for seed_value in [4815, 77, 994]:
  s = Sim.new()
  s.start(seed_value)
  var identities = s.actors.size()
  s.advance(2880)
  check(s.actors.size() == identities,"Population records conserved over two days, seed %d" % seed_value)
  var valid = true
  for a in s.actors:
   valid = valid and a.ap >= 0 and a.ap <= 50 and a.hp >= 0 and a.hp <= s.max_hp(a) and a.x in range(10) and a.y in range(10) and s.encumbrance(a) <= 118
  check(valid,"Simulation invariants after two days, seed %d" % seed_value)
  print("SOAK seed=",seed_value," population=",s.population()," metrics=",s.metrics)
 print("CHECKS: ",checks,"  FAILURES: ",failures)
 quit(0 if failures == 0 else 1)

func feedback_rules() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 p.inside = false
 b.barricade = 4
 check(s.reason(p,"enter").is_empty(),"Very strongly barricaded permits outside entry")
 b.barricade = 5
 check(s.action_feedback(p,"enter").is_empty(),"Heavy barricades keep Enter clickable")
 var before = JSON.stringify(s.actors)
 check(s.act("enter").message.contains("try to find an entry point"),"Blocked entry explains the attempt")
 check(JSON.stringify(s.actors) == before,"Blocked entry spends no AP or recovery")
 b.barricade = 0
 b.doors = true
 p.human = false
 p.zombie_skills = []
 check(s.reason(p,"enter").contains("Memories of Life"),"Unskilled zombie cannot open closed entrance")
 p.zombie_skills.append("memories")
 check(s.act("enter").ok and not b.doors,"Memories of Life opens entrance")
 p.busy_until = s.now()
 b.doors = true
 p.zombie_skills = []
 check(s.act("leave").ok and b.doors,"A zombie can exit without Memories of Life and secures the doors")
 for kind in preload("res://scripts/catalog.gd").ITEMS:
  if kind != "pool_cue":
   check(s.melee_break_chance({"kind":kind,"wear":100000,"durability":0}) == 0.0,"No wear breakage for "+kind)
 check(s.melee_break_chance({"kind":"pool_cue","wear":0}) == 0.20 and s.melee_break_chance({"kind":"pool_cue","wear":100000}) == 0.20,"Pool cue has a constant 20% break chance on hits")

func restored_location_rules() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 var original = b.inside_description
 check(original.split(".",false).size() >= 3,"Location flavour restores three legacy sentence positions")
 check(s.location_description(p).begins_with(original),"Description includes generated interior text")
 check(s.location_description(p).contains("lightly barricaded"),"Description reports current barricades")
 b.generator = true
 b.fuel_until = s.minute+10
 check(s.location_description(p).contains("running"),"Description reports live generator state")
 b.fuel_until = 0
 b.ruin = 3
 check(s.location_description(p).contains("out of fuel") and s.location_description(p).contains("has been ruined"),"Description updates fuel and ruin state")
 p.inside = false
 check(s.location_description(p).begins_with(b.outside_description),"Exterior has its own generated text")
 var repeat = isolated()
 check(repeat.blocks[44].inside_description == original,"Descriptions repeat for the same world seed")
 check(s.save_to("res://test-save.json") == OK,"Description save succeeds")
 var loaded = Sim.new()
 check(loaded.load_from("res://test-save.json").is_empty() and loaded.blocks[44].inside_description == original,"Generated text survives save and load")
 for block in s.blocks:
  block.erase("inside_description")
  block.erase("outside_description")
 s.save_to("res://test-save.json")
 check(loaded.load_from("res://test-save.json").is_empty() and loaded.blocks[44].inside_description == original,"Older saves gain deterministic descriptions")
 for job in ["Private","Medic","Scout","Guard"]:
  p.job = job
  check(s.skill_cost(p,"firearms") == 75 and s.skill_cost(p,"first_aid") == 150,"Military occupation pricing: "+job)
 for job in ["Scientist","Doctor","NecroTech Lab Assistant"]:
  p.job = job
  check(s.skill_cost(p,"first_aid") == 75 and s.skill_cost(p,"free_running") == 150,"Science occupation pricing: "+job)
 for job in ["Volunteer","Engineer","Police Officer","Firefighter","Consumer","Corpse"]:
  p.job = job
  check(s.skill_cost(p,"firearms") == 100 and s.skill_cost(p,"first_aid") == 100,"Civilian/starting corpse pricing: "+job)
 for job in ["Guard","Doctor","Volunteer"]:
  p.job = job
  check(s.skill_cost(p,"construction") == 100 and s.skill_cost(p,"brain_rot") == 100,"Civilian and zombie skills always cost 100 XP")
 p.job = "Guard"
 p.xp = 75
 check(s.learn("free_running").is_empty() and p.xp == 0,"Learning charges occupation discount")
 p.job = "Doctor"
 p.human = false
 check(s.skill_cost(p,"firearms") == 150,"Death preserves occupation pricing")
 p.human_skills.erase("lab_experience")
 p.xp = 75
 check(s.learn("lab_experience").is_empty() and p.xp == 0,"Off-form purchase uses the same price")

func activity_perspective() -> void:
 var s = isolated()
 var p = s.player()
 var npc = s.actors[1]
 npc.down = false
 npc.x = p.x
 npc.y = p.y
 npc.inside = true
 npc.human_skills = ["construction"]
 var b = s.current_block(p)
 s.set_barricade_strength(b,0)
 s.reindex()
 var name = s.display_name(npc)
 check(s._try(npc,"barricade") and s.messages.back().text == name+" barricades the building.","NPC construction uses third-person agreement")
 npc.busy_until = s.now()
 check(s._try(npc,"leave") and s.messages.back().text == name+" steps outside.","NPC exit uses third-person agreement")
 p.inside = false
 npc.busy_until = s.now()
 var destination = s.block_at(npc.x+1,npc.y)
 check(s._try(npc,"move",-1,{"dx":1,"dy":0}) and s.messages.back().text == name+" moves to "+destination.name+".","NPC movement uses third-person agreement")

func window_and_necronet_rules() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 for human in [true,false]:
  for strength in [10,11]:
   p.human = human; p.inside = true; p.ap = 50; p.busy_until = s.now()
   b.doors = false
   s.set_barricade_strength(b,strength)
   var result = s.act("leave")
   if strength == 10:
    check(result.ok and not p.inside and b.doors == not human,"At VSB either form exits, and only the zombie secures an open door")
   else:
    check(not result.ok and result.message == Sim.MAIN_DOORS_BLOCKED and p.inside and p.ap == 50,"Heavy barricades block the main doors in both forms")
    check(s.act("move",-1,{"dx":1,"dy":0}).ok and not p.inside,"Heavy barricades still allow an adjacent-block exit")
    p.x = b.x; p.y = b.y; s.reindex()
 p.human = true
 s.set_barricade_strength(b,0)
 for closed in [false,true]:
  p.inside = false; p.ap = 50; p.busy_until = s.now(); b.doors = closed
  check(s.act("enter").ok and b.doors == closed,"Humans preserve the starting door state on entry")
  p.busy_until = s.now()
  check(s.act("leave").ok and b.doors == closed,"Humans preserve the starting door state on exit")
 p.busy_until = s.now()
 s.give_item(p,"binoculars")
 for kind in ["office","necrotech_lab","hotel","tower"]:
  b.type = kind; p.inside = true
  check(s.reason(p,"lookout",-1,{"direction":"north"}).is_empty() and s.reason(p,"jump").is_empty(),"Tall building supports binoculars and windows: "+kind)
 b.type = "hospital"
 check(not s.reason(p,"lookout").is_empty() and not s.reason(p,"jump").is_empty(),"Ordinary buildings have no tall-building actions")
 b.type = "hotel"; p.human = false; p.hp = 27; p.ap = 50
 s.set_barricade_strength(b,21)
 check(s.act("jump").ok and p.x == b.x and p.y == b.y and not p.inside and not p.down and p.hp == 27 and p.ap == 49,"Zombie window exit bypasses EHB and stays on the same block unharmed")
 p.human = true; p.inside = true; p.ap = 50; p.busy_until = s.now()
 check(s.act("jump").ok and not p.human and p.down and p.hp == 0 and not p.inside and p.ap == 49,"Survivor window jump kills immediately on the same block")
 p.human = true; p.down = false; p.hp = 50; p.inside = true; p.ap = 50; p.busy_until = s.now()
 p.human_skills = ["necro_employment","necronet"]
 b.type = "necrotech_lab"; b.generator = true; b.generator_hp = 6; b.fuel_until = 0
 check(not s.act("scan").ok and not s.act("manufacture").ok,"An unpowered lab cannot scan or manufacture")
 b.fuel_until = s.minute+30
 var tagged = s.actors[15]
 tagged.human = false; tagged.down = false; tagged.x = p.x; tagged.y = p.y
 tagged.tagged_until = s.minute+10
 var expired = s.actors[16]
 expired.human = false; expired.down = false; expired.x = p.x; expired.y = p.y
 expired.tagged_until = s.minute
 s.reindex()
 check(s.act("scan").ok and s.scan_cells.size() == 81 and s.scan_cells[40].count == 1 and s.scan_cells[40].type == "necrotech_lab","NecroNet snapshot captures only active tags and records each block type")
 tagged.x += 1; s.reindex()
 check(s.scan_cells[40].count == 1,"A saved scan is a snapshot rather than live tracking")
 check(s.save_to("user://necronet-scan-test.json") == OK,"NecroNet snapshot saves")
 var loaded = Sim.new()
 check(loaded.load_from("user://necronet-scan-test.json").is_empty() and loaded.scan_cells.size() == 81 and loaded.scan_cells[40].count == 1,"The snapshot survives loading")
 p.ap = 50; p.busy_until = s.now(); p.inventory.clear(); p.scout_site = b.id; p.scout_used = 0
 check(s.act("manufacture").ok and p.ap == 30 and not s.item_kind(p,"syringe").is_empty(),"Powered manufacturing creates one syringe for twenty AP")

func binocular_rules() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 var origin = Vector2i(p.x,p.y)
 b.type = "tower"
 p.inside = true
 check(not s.act("lookout",-1,{"direction":"north"}).ok,"Binoculars must be carried")
 s.give_item(p,"binoculars")
 check(not s.act("lookout").ok and not s.act("lookout",-1,{"direction":"up"}).ok and p.ap == 50,"Rooftop use requires a valid direction before spending AP")
 for direction in s.C.COMPASS_DIRECTIONS:
  p.ap = 50; p.busy_until = s.now()
  var bearing = s.C.COMPASS_DIRECTIONS[direction]
  var area = Rect2i(origin+2*bearing-Vector2i.ONE,Vector2i(3,3))
  check(s.act("lookout",-1,{"direction":direction}).ok and p.ap == 49 and s.binocular_area == area and not area.has_point(origin),"Rooftop survey covers nine blocks "+direction)
 p.inside = false
 p.busy_until = s.now()
 check(not s.act("lookout").ok,"The exterior of a building is not a street survey location")
 for kind in ["street","monument"]:
  b.type = kind
  p.ap = 50; p.busy_until = s.now()
  check(s.act("lookout").ok and p.ap == 49 and s.binocular_area == Rect2i(origin-Vector2i(3,3),Vector2i(7,7)),"Outdoor survey immediately covers forty-nine blocks at a "+kind)
 var skyline = s.block_at(p.x+4,p.y)
 skyline.type = "tower"; skyline.complex = ""; skyline.known = false
 check(s.skyline_landmarks(p).any(func(entry): return entry.site.id == skyline.id and entry.distance == 4 and entry.bearing == "east") and not skyline.known,"Skyline identifies distant tall buildings without surveying their blocks")
 p.x = 0; p.y = 0; p.busy_until = s.now()
 s.current_block(p).type = "street"
 check(s.act("lookout").ok and s.binocular_area.position == Vector2i(-3,-3),"Edge survey retains the centred grid")
 p.human = false; p.busy_until = s.now()
 check(not s.act("lookout").ok,"Zombies cannot use binoculars outdoors")
 p.human = true; p.inside = true
 p.human_skills = ["shopping"]
 b.type = "mall"
 check(s.item_search_chance(b,"binoculars",p,"sports") > 0 and s.item_search_chance(b,"binoculars",p,"drugstore") == 0,"Mall sports stores carry binoculars")
 for kind in ["armoury","storehouse","stadium"]:
  b.type = kind
  check(s.item_search_chance(b,"binoculars",p) > 0,"Binoculars are searchable in "+kind)

func reading_and_newspaper() -> void:
 var s = isolated()
 var p = s.player()
 var xp_totals = []
 for job in ["Private","Scientist"]:
  p.job = job
  p.xp = 0
  s.rng.seed = 812
  var excerpts = {}
  var consumed = true
  for attempt in range(500):
   s.give_item(p,"book")
   var book = s.item_kind(p,"book")
   p.busy_until = s.now(); p.ap = 50
   consumed = s.act("read",-1,{"uid":book.uid}).ok and s.item_by_uid(p,book.uid).is_empty() and consumed
   excerpts[s.messages.back().text.get_slice("”",0)] = true
  check(consumed and excerpts.size() > 1,"Reading consumes every book and varies its lore")
  xp_totals.append(p.xp)
 check(xp_totals[0] >= 33 and xp_totals[0] <= 67 and xp_totals[1] == 2*xp_totals[0],"Books award XP about ten percent of the time and double the award for scientists")
 var poetry = {}
 var before_xp = p.xp
 var consumed_poetry = true
 for attempt in range(30):
  s.give_item(p,"poetry_book")
  var book = s.item_kind(p,"poetry_book")
  p.busy_until = s.now(); p.ap = 50
  consumed_poetry = s.act("read",-1,{"uid":book.uid}).ok and s.item_by_uid(p,book.uid).is_empty() and consumed_poetry
  poetry[s.messages.back().text] = true
 check(consumed_poetry and poetry.size() > 1 and p.xp == before_xp,"Poetry is consumed, varies its lore and never awards XP")
 s.give_item(p,"newspaper")
 var paper = s.item_kind(p,"newspaper")
 p.busy_until = s.now(); p.ap = 50
 check(not s.act("read",-1,{"uid":paper.uid}).ok and p.ap == 50,"Newspapers cannot be read")
 check(s.act("equip",-1,{"uid":paper.uid}).ok and p.equipped == paper.uid,"A survivor can equip the newspaper")
 var t = s.actors[1]
 t.x = p.x; t.y = p.y; t.inside = p.inside; t.down = false; t.hp = 25
 s.reindex()
 p.scout_site = s.current_block(p).id; p.scout_day = s.minute/1440; p.scout_used = 0
 check(s.attack_stats(p,t,"attack",paper).hit == 100 and s.attack_stats(p,t,"attack",paper).damage == 0,"Newspapers have one hundred percent base accuracy and zero damage")
 for human in [true,false]:
  t.human = human
  var pose = t.pose_sequence
  p.busy_until = s.now(); p.ap = 50
  check(s.act("attack",t.id).ok and p.ap == 49 and p.xp == before_xp and t.hp == 25 and t.pose_sequence == pose and s.messages.back().text.contains("classifieds"),"Newspaper swat costs one AP and leaves the target unhurt in either form")
 check(not s.item_by_uid(p,paper.uid).is_empty() and p.scout_used == 0,"Newspapers remain equipped and their fixed AP cost uses no scout discount")

func perception_rules() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 b.generator = true
 b.fuel_until = s.minute+30
 b.ruin = 0
 p.inside = false
 var exterior = s.location_description(p)
 check(exterior.contains("and lights are on inside.") and not exterior.contains("portable generator") and not exterior.contains("has been ruined"),"Exterior sees light without revealing interior equipment")
 p.inside = true
 var interior = s.location_description(p)
 check(interior.contains("portable generator") and interior.contains("running"),"Standing inside observes generator state")
 b.generator = false
 b.ruin = 3
 check(s.location_description(p).contains("has been ruined"),"Unpowered ruined interior is described")
 s.die(p)
 var dark = s.location_description(p)
 check(not dark.contains(b.name) and not dark.contains(b.inside_description) and not dark.contains("body") and dark.contains("Everything is dark"),"Downed description reveals no surroundings or bodies")
 var count = s.messages.size()
 var engineer = s.actors[2]
 engineer.x = p.x
 engineer.y = p.y
 engineer.inside = p.inside
 engineer.down = false
 b.ruin = 1
 s.reindex()
 s.execute(engineer,"repair")
 check(b.ruin == 0 and s.messages.size() == count,"NPC activity continues unobserved and is absent from history while down")
 for block in s.blocks: block.known = false
 s.discover()
 check(not b.known,"Downed characters do not discover locations")
 p.ready_at = s.minute
 p.ap = 50
 check(s.act("stand").ok and not p.down,"Standing restores perception")
 s.discover()
 check(b.known and s.location_description(p).contains(b.name),"Surroundings return after standing")

func melee_combat_rules() -> void:
 var s = isolated()
 var p = s.player()
 var t = s.actors[1]
 t.x = p.x
 t.y = p.y
 t.inside = p.inside
 t.down = false
 t.human = false
 t.hp = 100000
 p.human_skills = []
 p.inventory.clear()
 s.give_item(p,"fire_axe")
 var axe = p.inventory.back()
 axe.wear = 100000
 axe.durability = 0
 p.equipped = axe.uid
 for attempt in range(500): s.execute(p,"attack",t.id)
 check(not s.item_by_uid(p,axe.uid).is_empty() and axe.wear == 100000,"Even heavily worn legacy melee weapons survive repeated attacks without wear")
 var hits = 0
 var breaks = 0
 var misses_safe = true
 var removals_correct = true
 for attempt in range(4000):
  if s.item_kind(p,"pool_cue").is_empty(): s.give_item(p,"pool_cue")
  var cue = s.item_kind(p,"pool_cue")
  p.equipped = cue.uid
  var before = t.hp
  s.execute(p,"attack",t.id)
  var message = s.messages.back().text
  var removed = s.item_by_uid(p,cue.uid).is_empty()
  if t.hp < before:
   hits += 1
   if removed: breaks += 1
  else:
   misses_safe = misses_safe and not removed
  if removed: removals_correct = removals_correct and p.equipped == -1 and message.contains("splinters and breaks") and before-t.hp == 2
 check(misses_safe,"Missed pool cue attacks never break the cue")
 check(hits > 800 and float(breaks)/hits > 0.16 and float(breaks)/hits < 0.24,"Pool cues break on approximately 20% of successful hits")
 check(removals_correct and breaks > 0,"Broken cues deal their hit damage, leave inventory, unequip and report splintering")
