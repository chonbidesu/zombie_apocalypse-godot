extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: "+message)

func ready(s,a) -> void:
 a.ap = 50
 a.busy_until = s.now()

func _initialize() -> void:
 var s = Sim.new()
 s.start(4321)
 for a in s.actors:
  if a.id > 0:
   a.x = 0
   a.y = 0
   a.down = true
   a.next_think = 999999.0
 var p = s.player()
 var t = s.actors[1]
 var z = s.actors[2]
 for a in [t,z]:
  a.x = p.x
  a.y = p.y
  a.inside = p.inside
  a.down = false
  a.dormant = false
  a.hp = 50
 s.reindex()
 check(C.SKILLS.size() == 45,"Complete 23-human / 22-zombie skill catalogue")
 check(C.SKILLS.values().filter(func(d): return d.side == "human").size() == 23,"All human skills present")
 p.human_skills.clear()
 p.zombie_skills.clear()
 p.xp = 100000
 check(not s.skill_reason(p,"advanced_pistol").is_empty(),"Advanced training cannot bypass prerequisites")
 check(not s.skill_reason(p,"headshot").is_empty(),"Headshot cannot bypass level ten")
 for pass_number in range(4):
  for key in C.SKILLS:
   if s.skill_reason(p,key).is_empty(): s.learn(key)
 for key in C.SKILLS:
  check(key in p.human_skills or key in p.zombie_skills,"Skill can be learned with its prerequisites: "+key)
 p.job = "Private"
 check(s.skill_cost(p,"firearms") == 75 and s.skill_cost(p,"first_aid") == 150 and s.skill_cost(p,"construction") == 100 and s.skill_cost(p,"vigour_mortis") == 100,"Military occupation prices all categories correctly")
 p.job = "Doctor"
 check(s.skill_cost(p,"first_aid") == 75 and s.skill_cost(p,"firearms") == 150,"Science occupation prices reverse military prices")
 check(s.max_hp(p) == 60,"Body Building raises maximum human HP")
 p.human = false
 t.human = true
 z.human = false
 p.zombie_skills.clear()
 var hand = s.attack_stats(p,t,"attack")
 var bite = s.attack_stats(p,t,"bite")
 check(hand.hit == 25 and hand.damage == 2 and bite.hit == 10 and bite.damage == 4,"Untrained bite is stronger but less accurate than hands")
 p.zombie_skills = ["vigour_mortis","neck_lurch","death_grip","rend_flesh","tangling_grasp"]
 check(s.attack_stats(p,t,"attack").hit == 50 and s.attack_stats(p,t,"attack").damage == 3,"Hand training applies accuracy and damage")
 check(s.attack_stats(p,t,"bite").hit == 30,"Bite accuracy includes Vigour Mortis and Neck Lurch")
 s.claim_grasp(p,t)
 check(s.attack_stats(p,t,"attack").hit == 60 and s.attack_stats(p,t,"bite").hit == 40,"Grasp gives both subsequent attacks ten percentage points")
 s.claim_grasp(z,t)
 check(p.grasp_target == -1 and z.grasp_target == t.id and t.grasped_by == z.id,"A target has exactly one grasp owner")
 s.clear_grasp(t)
 check(z.grasp_target == -1 and t.grasped_by == -1,"Victim movement/death can release its holder")
 p.inventory.clear()
 s.give_item(p,"shotgun")
 p.equipped = p.inventory[0].uid
 check(s.attack_stats(p,t,"attack",p.inventory[0]).damage == 3 and not s.reason(p,"equip",-1,{"uid":p.equipped}).is_empty(),"Zombies cannot use carried weapons")
 var released = 0
 var misses = 0
 for attempt in range(500):
  s.claim_grasp(p,t)
  t.hp = 10000
  var hp = t.hp
  s.execute(p,"attack",t.id)
  if t.hp == hp:
   misses += 1
   if p.grasp_target == -1: released += 1
 check(misses > 100 and float(released)/misses > 0.38 and float(released)/misses < 0.62,"Seeded combat loses grasp on approximately half of misses")
 s.clear_grasp(p)
 p.zombie_skills.append_array(["digestion","infectious_bite"])
 p.hp = 10
 t.hp = 10000
 for attempt in range(100):
  s.execute(p,"bite",t.id)
  if t.infected: break
 check(t.infected and p.hp > 10,"A successful infected bite infects prey and heals through Digestion")
 s.execute(t,"wait")
 check(t.hp < 10000-4,"Infected survivors lose HP when acting")
 t.hp = 1
 t.infected = false
 s.die(t)
 p.hp = 10
 ready(s,p)
 check(s.reason(p,"feed",t.id).is_empty(),"Digestion permits feeding on an untainted corpse")
 s.execute(p,"feed",t.id)
 check(p.hp == 14 and t.fed == 1,"Corpse feeding restores four HP and records depletion")
 t.human = true
 check(not s.reason(p,"feed",t.id).is_empty(),"Revivifying bodies cannot be eaten")
 p.human = true
 p.infected = true
 p.hp = 20
 t.down = false
 t.human = true
 t.hp = 20
 t.infected = true
 p.inventory.clear()
 s.give_item(p,"first_aid_kit")
 var b = s.current_block(p)
 b.type = "hospital"
 b.ruin = 0
 b.generator = true
 b.generator_hp = 6
 b.fuel_until = s.minute+1440
 s.execute(p,"heal",t.id)
 check(t.hp == 35 and not t.infected,"First Aid and powered Surgery heal fifteen and cure infection")
 p.infected = false
 p.inventory.clear()
 s.give_item(p,"pistol")
 var pistol = p.inventory[0]
 p.equipped = pistol.uid
 t.human = false
 t.zombie_skills = ["brain_rot","flesh_rot"]
 t.inventory.clear()
 s.give_item(t,"flak_jacket")
 check(s.attack_stats(p,t,"attack",pistol).hit == 65,"Full handgun tree reaches sixty-five percent")
 t.hp = 50
 for attempt in range(30):
  pistol.ammo = 6
  s.execute(p,"attack",t.id)
  if t.hp < 50: break
 check(t.hp == 46,"Flak and Flesh Rot reduce firearm damage without stacking")
 check(s.max_hp(t) == 60,"Flesh Rot raises zombie HP")
 p.scout_site = -1
 ready(s,p)
 check(s.reason(p,"scout").is_empty() and s.cost(p,"scout") == 30,"Safehouse scouting is a thirty-AP skill action")
 s.execute(p,"scout")
 for i in range(5):
  check(s.cost(p,"wait") == 0,"Scouting discounts one of five daily actions")
  s.execute(p,"wait")
 check(s.cost(p,"wait") == 1,"Scouting stops discounting after five actions")
 p.scout_site = -1
 p.inventory.clear()
 s.give_item(p,"dna_extractor")
 t.zombie_skills.clear()
 ready(s,p)
 var xp = p.xp
 s.execute(p,"extract",t.id)
 check(t.tagged_until > s.minute and p.xp == xp+4,"DNA extraction marks a zombie and awards four XP")
 check(not s.reason(p,"extract",t.id).is_empty(),"Current DNA tag prevents repeated XP farming")
 p.inventory.clear()
 s.give_item(p,"radio_transmitter")
 ready(s,p)
 check(s.reason(p,"install_radio").is_empty(),"Transmitter can be installed in repaired interior")
 s.execute(p,"install_radio")
 check(b.radio and b.radio_hp == 6 and s.item_kind(p,"radio_transmitter").is_empty(),"Installation consumes transmitter and records condition")
 p.human_skills.erase("radio_operation")
 ready(s,p)
 check(not s.reason(p,"broadcast",-1,{"frequency":27.0}).is_empty() and s.reason(p,"broadcast",-1,{"frequency":29.0}).is_empty(),"Radio Operation gates restricted channels only")
 b.radio_hp = 2
 check(not s.reason(p,"repair_radio").is_empty(),"Transmitter repair requires a toolbox")
 s.give_item(p,"toolbox")
 check(s.reason(p,"repair_radio").is_empty(),"Construction and toolbox allow transmitter repair")
 s.execute(p,"repair_radio")
 check(b.radio_hp == 6,"Repair restores transmitter condition")
 s.give_item(p,"mobile_phone")
 s.give_item(t,"mobile_phone")
 t.human = true
 var mast = s.blocks[54]
 mast.generator = true
 mast.ruin = 0
 mast.generator_hp = 6
 mast.fuel_until = s.minute+1440
 ready(s,p)
 check(s.reason(p,"phone",t.id).is_empty(),"Phones work with two handsets and a powered local mast")
 mast.fuel_until = 0
 check(not s.reason(p,"phone",t.id).is_empty(),"Phone service fails when mast loses power")
 s.give_item(p,"spray_can")
 ready(s,p)
 s.execute(p,"tag",-1,{"text":"Safe shelter"})
 check(b.graffiti == "Safe shelter","Spray-painted messages persist on the building")
 s.give_item(p,"painting")
 var painting = s.item_kind(p,"painting")
 s.execute(p,"decorate",-1,{"uid":painting.uid})
 check("painting" in b.decorations and s.item_kind(p,"painting").is_empty(),"Decorations move from inventory to interior")
 p.human = false
 s.execute(p,"smash_decorations")
 check(b.decorations.is_empty(),"Zombies can destroy installed decorations")
 b.type = "mall"
 b.generator = true
 b.fuel_until = s.minute+1440
 p.human = true
 p.human_skills.erase("bargain_hunting")
 var shopping = s.item_search_chance(b,"first_aid_kit",p,"drugstore")
 p.human_skills.append("bargain_hunting")
 check(is_equal_approx(s.item_search_chance(b,"first_aid_kit",p,"drugstore"),shopping*1.5),"Bargain Hunting improves targeted mall searches")
 check(s.item_search_chance(b,"shotgun",p,"drugstore") == 0,"Shopping chooses appropriate store inventory")
 b.ruin = 3
 check(not s.powered(b) and s.item_search_chance(b,"first_aid_kit",p,"drugstore") > 0 and s.item_search_chance(b,"first_aid_kit",p,"drugstore") < shopping*0.02,"Ruins remain dark with tiny nonzero search chances")
 b.ruin = 0
 p.human = false
 p.zombie_skills.append("scent_death")
 s.execute(p,"smell")
 check(s.sense_report.begins_with("SCENT DEATH"),"Scent Death produces local intelligence")
 p.trail_from = t.id
 p.trail_until = s.minute+30
 p.zombie_skills.append("scent_trail")
 s.execute(p,"trail")
 check(p.memory == s.current_block(t).id,"Scent Trail follows recent attacker position")
 p.zombie_skills.append_array(["feeding_drag","feeding_groan","bellow","death_rattle","flailing_gesture","lurching_gait","ankle_grab"])
 t.human = true
 t.down = false
 t.hp = 12
 b.barricade = 0
 b.doors = false
 ready(s,p)
 check(s.reason(p,"drag",t.id).is_empty(),"Feeding Drag permits dying prey through an open entrance")
 b.doors = true
 check(not s.reason(p,"drag",t.id).is_empty(),"Closed doors prevent dragging prey")
 b.doors = false
 s.execute(p,"drag",t.id)
 check(not p.inside and not t.inside,"Feeding Drag moves both actors into the street")
 z.x = p.x+1
 z.y = p.y
 z.down = false
 z.human = false
 s.reindex()
 s.execute(p,"groan")
 check(z.memory == b.id and z.memory_until > s.minute,"Feeding Groan attracts nearby zombies to prey")
 check(s.cost(p,"bellow") == 1,"Bellow falls back to an ordinary groan without twenty-five prey")
 s.execute(p,"say",-1,{"text":"Hello survivors"})
 check(not p.speech.to_lower().contains("survivors") and p.speech_until > s.now(),"Death Rattle converts speech to a groaned vocabulary")
 check(s.cost(p,"move") == 1 and s.cost(p,"stand") == 1,"Lurching Gait and Ankle Grab reduce AP costs")
 p.headshot = 5
 check(s.cost(p,"stand") == 6,"Headshot penalty adds to Ankle Grab")
 s.claim_grasp(p,t)
 s.die(t)
 check(p.grasp_target == -1 and t.grasped_by == -1,"Death releases both ends of a grasp")
 for kind in C.BUILDINGS:
  check(ResourceLoader.exists("res://assets/blocks/"+kind+".png") and ResourceLoader.exists("res://assets/settings/"+kind+"_inside.png") and ResourceLoader.exists("res://assets/settings/"+kind+"_outside.png"),"Building has map and both scene assets: "+kind)
 for kind in C.OUTDOORS:
  check(ResourceLoader.exists("res://assets/blocks/"+("streets" if kind == "street" else kind)+".png") and ResourceLoader.exists("res://assets/settings/"+kind+"_outside.png"),"Outdoor site has map and environment art: "+kind)
 check(not s.fort_move_reason(p,s.blocks[3],s.blocks[2]).is_empty() and s.fort_move_reason(p,s.blocks[13],s.blocks[12]).is_empty(),"Fort walls channel entry through gatehouse")
 check(s.blocks[7].complex == s.blocks[8].complex and not s.blocks[7].complex.is_empty(),"Large building squares share a complex identity")
 var save_path = "user://content-expansion-test.json"
 var state = [p.grasp_target,p.trail_from,b.graffiti,b.decorations.duplicate(),b.radio,b.radio_hp]
 s.save_to(save_path)
 var restored = Sim.new()
 restored.load_from(save_path)
 var rp = restored.player()
 var rb = restored.current_block(rp)
 check(state == [rp.grasp_target,rp.trail_from,rb.graffiti,rb.decorations,rb.radio,rb.radio_hp],"Extended combat, scent and building state survives save/load")
 for occupation in ["Private","Medic","Scout","NecroTech Lab Assistant","Doctor","Police Officer","Firefighter","Consumer","Corpse"]:
  var new_game = Sim.new()
  new_game.start(42,occupation)
  check(new_game.player().job == occupation and new_game.player().human == (occupation != "Corpse"),"New-game occupation and form: "+occupation)
 print("CONTENT CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
