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
 s.start(57)
 for a in s.actors:
  if a.id != 0:
   a.x = 0
   a.y = 0
   a.down = true
   a.next_think = 999999.0
 var p = s.player()
 p.inventory.clear()
 p.equipped = -1
 var b = s.current_block(p)
 s.reindex()
 check(C.ITEMS.values().all(func(d): return d.has("encumbrance") and d.encumbrance >= 0),"Every item has explicit percentage encumbrance")
 for kind in ["portable_generator","radio_transmitter","toolbox","fuel_can"]: s.give_item(p,kind)
 check(s.encumbrance(p) == 66,"Generator 20, transmitter 20, toolbox 16 and fuel 10 add correctly")
 p.inventory.clear()
 for i in range(20): s.give_item(p,"first_aid_kit")
 ready(s,p)
 check(p.inventory.size() == 20 and s.encumbrance(p) == 40 and s.reason(p,"search").is_empty(),"More than ten small items do not fill an inventory")
 p.inventory.clear()
 for i in range(49): s.give_item(p,"first_aid_kit")
 s.search_tables.hospital = {"portable_generator":1.0}
 b.generator = true
 b.generator_hp = 6
 b.fuel_until = s.minute+1440
 b.ruin = 0
 ready(s,p)
 for attempt in range(100):
  ready(s,p)
  s.act("search")
  if not s.item_kind(p,"portable_generator").is_empty(): break
 check(s.encumbrance(p) == 118 and not s.item_kind(p,"portable_generator").is_empty(),"A final find below 100 percent can take load to 118 percent")
 ready(s,p)
 var count = p.inventory.size()
 check(not s.act("search").ok and p.inventory.size() == count and p.ap == 50,"Overloaded searching is rejected without consuming AP or losing items")
 b.generator = false
 ready(s,p)
 check(s.act("generator").ok and s.encumbrance(p) == 98,"Installing a carried generator frees its full twenty percent")
 ready(s,p)
 s.give_item(p,"first_aid_kit")
 check(s.encumbrance(p) == 100 and not s.acquisition_reason(p).is_empty(),"Exactly one hundred percent also blocks collection")
 var last = p.inventory.back()
 check(s.act("drop",-1,{"uid":last.uid}).ok and s.encumbrance(p) == 98,"Dropping an item frees capacity immediately")
 p.inventory.clear()
 s.give_item(p,"pistol")
 s.give_item(p,"pistol_clip")
 var pistol = s.item_kind(p,"pistol")
 pistol.ammo = 0
 p.equipped = pistol.uid
 check(s.encumbrance(p) == 6,"An unloaded handgun and magazine weigh six percent")
 ready(s,p)
 check(s.act("reload").ok and pistol.ammo == 6 and s.encumbrance(p) == 4,"Loaded ammunition adds no weight beyond its firearm")
 p.inventory.clear()
 s.give_item(p,"candy")
 check(s.encumbrance(p) == 0 and not s.acquisition_reason(p,"candy").is_empty(),"Zero-weight candy is limited to one bag")
 s.give_item(p,"dead_fir_tree")
 check(not s.acquisition_reason(p,"plastic_christmas_tree").is_empty(),"Only one Christmas tree of either type can be carried")
 p.inventory.clear()
 var ally = s.actors[1]
 ally.x = p.x
 ally.y = p.y
 ally.inside = p.inside
 ally.human = true
 ally.down = false
 ally.inventory.clear()
 for i in range(5): s.give_item(ally,"portable_generator")
 s.give_item(p,"first_aid_kit")
 s.reindex()
 ready(s,p)
 check(not s.act("give",ally.id,{"uid":p.inventory[0].uid}).ok,"Giving cannot bypass a recipient's encumbrance limit")
 p.inventory.clear()
 for i in range(5): s.give_item(p,"portable_generator")
 b.type = "necrotech_lab"
 b.generator = true
 b.fuel_until = s.minute+1440
 p.human_skills.append("necronet")
 ready(s,p)
 check(not s.reason(p,"manufacture").is_empty() and not s.reason(p,"request",ally.id).is_empty(),"Manufacture and supply requests respect percentage capacity")
 s.save_to("user://encumbrance-test.json")
 var loaded = Sim.new()
 check(loaded.load_from("user://encumbrance-test.json").is_empty() and loaded.player().inventory.size() == 5 and loaded.encumbrance(loaded.player()) == 100,"Saves preserve inventory and derive its encumbrance correctly")
 for type in C.OUTDOORS:
  b.type = type
  b.barricade = 7
  s.initialize_block(b)
  check(not s.can_barricade(b) and b.barricade == 0,"Open land cannot retain barricades: "+type)
 for type in ["church","cathedral","gatehouse","junkyard","aquarium","bear_pit","elephant_house","giraffe_house","lion_enclosure","reptile_house"]:
  b.type = type
  b.doors = true
  b.barricade = 0
  b.ruin = 0
  s.initialize_block(b)
  p.human = false
  p.inside = false
  p.zombie_skills.clear()
  ready(s,p)
  check(s.can_barricade(b) and not s.has_doors(b) and not b.doors and s.reason(p,"enter").is_empty(),"Doorless structure remains barricadable and permits untrained zombie entry: "+type)
 b.type = "hospital"
 b.doors = true
 check(not s.reason(p,"enter").is_empty(),"Ordinary closed doors still require Memories of Life")
 p.zombie_skills = ["memories"]
 ready(s,p)
 check(s.act("enter").ok and p.ap == 48 and not b.doors,"A trained zombie pays one AP to open doors plus one AP to enter")
 p.inside = false
 b.type = "gatehouse"
 s.initialize_block(b)
 ready(s,p)
 check(s.act("enter").ok and p.ap == 49,"Doorless gatehouse entry costs only the movement AP")
 var city = Sim.new()
 city.start(1,"Private",{"mode":"malton","survivors":0,"zombies":0})
 check(city.blocks.filter(func(site): return not site.zoo.is_empty() and city.can_barricade(site)).size() == 6,"All six original zoo enclosures are barricadable")
 print("ENCUMBRANCE/DOORS CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
