extends RefCounted

const SIZE = 10
const AP_CAP = 50
const RECOVERY_MINUTES = 30
const GAME_MINUTES_PER_SECOND = 1.0
const REST_SPEED = 16.0
const SLEEP_SPEED = 128.0
const DEATH_SPEED = 32.0
const DAILY_REANIMATION_CHANCE = 0.20
const GENERATOR_HP = 6
const FUEL_MINUTES = 1440
const BARRICADE_MAX_STRENGTH = [0, 1, 4, 7, 10, 13, 16, 21]
const STRONGLY_BARRICADED_STRENGTH = 8
const BARRICADE_STRUCTURE_CHANCE = 0.50
# Indexed by current visible band; strength 21 is blocked separately.
const BARRICADE_BUILD_CHANCES = [1.0, 0.995, 0.99, 0.978, 0.851, 0.615, 0.38, 0.205]
const DARK_BUILDINGS = ["bank", "cinema", "nightclub", "armoury", "mall"]
const DARK_BARRICADE_BUILDINGS = DARK_BUILDINGS
const BARRICADE_MATERIALS = {
 "hospital":["a gurney", "a wheelchair", "an empty bed"],
 "cinema":["a row of seats", "a popcorn machine"],
 "warehouse":["a wooden crate", "some loose planks"],
 "mall":["a shopping trolley", "a mannequin", "a dining table"],
 "junkyard":["some junk", "some loose bricks", "some tyres"]
}
const SEARCH_LIT_CHANCE = 0.30
const SEARCH_UNLIT_CHANCE = 0.20
const SEARCH_RUIN_CHANCE = 0.10
const SEARCH_OUTSIDE_CHANCE = 0.05
const SEARCH_DARK_CHANCE = 0.01
const DARK_SEARCH_BUILDINGS = DARK_BUILDINGS
const INVENTORY_ITEM_LIMIT = 100
# One shared, conditional grab bag for every exterior and open-ground square.
const OUTSIDE_SEARCH_WEIGHTS = {
 "newspaper":20.0,"clothing":15.0,"book":10.0,"glass_piece":10.0,
 "beer":8.0,"wine":5.0,"spray_can":5.0,"crowbar":4.0,"knife":4.0,
 "length_of_pipe":4.0,"baseball_bat":3.0,"fuel_can":3.0,"flashlight":3.0,
 "fire_axe":2.0,"binoculars":2.0,"shovel":2.0,"golf_club":2.0
}
const MALL_STORE_WEIGHTS = {
 "gun_store":{"pistol_clip":0.327,"shotgun_shell":0.327,"pistol":0.173,"shotgun":0.173},
 "drugstore":{"first_aid_kit":0.70,"book":0.20,"candy":0.10},
 "hardware":{"fuel_can":0.33,"crowbar":0.33,"fire_axe":0.16,"portable_generator":0.08,"toolbox":0.06,"knife":0.02,"spray_can":0.02}
}
const CLOCK_STEPS_PER_MINUTE = 10
# Recovery is independent of AP cost. At normal speed these values are seconds.
const ACTION_RECOVERY = {"move":0.5, "attack":0.7, "search":1.1,
 "revive":1.5, "manufacture":3.0, "stand":1.0, "heal":0.9,
 "dump":1.0, "repair_generator":1.25, "destroy_generator":1.0, "barricade":1.0, "break":0.9, "repair":1.25, "equip":0.2, "drop":0.2}
const ENCUMBRANCE_LIMIT = 100
const TALL_BUILDINGS = ["office","necrotech_lab","hotel","tower"]
const COMPASS_DIRECTIONS = {
 "northwest": Vector2i(-1,-1), "north": Vector2i(0,-1), "northeast": Vector2i(1,-1),
 "west": Vector2i(-1,0), "east": Vector2i(1,0),
 "southwest": Vector2i(-1,1), "south": Vector2i(0,1), "southeast": Vector2i(1,1)
}
const OUTDOORS = ["wasteland", "exercise_yard", "training_ground", "zoo_ground", "street", "park", "cemetery", "monument", "carpark"]
const NORMAL_BUILDINGS = ["fire_station", "police_department", "hospital", "library", "church", "warehouse", "auto_repair", "factory", "school", "office", "necrotech_lab", "junkyard", "museum", "nightclub", "pub", "mall", "bank", "cinema", "hotel", "railway_station", "tower"]
const BUILDINGS = NORMAL_BUILDINGS + ["cathedral", "mansion", "power_station", "stadium", "armoury", "barracks", "gatehouse", "infirmary", "storehouse", "vehicle_depot", "aquarium", "bear_pit", "elephant_house", "giraffe_house", "lion_enclosure", "reptile_house"]
const ZOMBIE_MELEE_ITEMS = ["crowbar", "baseball_bat", "length_of_pipe"]
const ITEMS = {
 "fire_axe": {
  "name": "Fire axe",
  "damage": 3,
  "hit": 10,
  "encumbrance": 6
 },
 "knife": {
  "name": "Knife",
  "damage": 2,
  "hit": 10,
  "encumbrance": 2
 },
 "pistol": {
  "name": "Pistol",
  "damage": 5,
  "hit": 15,
  "capacity": 6,
  "ammo_kind": "pistol_clip",
  "reload_amount": 6,
  "encumbrance": 4
 },
 "pistol_clip": {
  "name": "Pistol magazine",
  "encumbrance": 2
 },
 "shotgun": {
  "name": "Shotgun",
  "damage": 10,
  "hit": 15,
  "capacity": 2,
  "ammo_kind": "shotgun_shell",
  "reload_amount": 1,
  "encumbrance": 6
 },
 "shotgun_shell": {
  "name": "Shotgun shell",
  "encumbrance": 2
 },
 "baseball_bat": {
  "name": "Baseball bat",
  "damage": 2,
  "hit": 10,
  "encumbrance": 2
 },
 "golf_club": {
  "name": "Golf club",
  "damage": 2,
  "hit": 10,
  "encumbrance": 4
 },
 "crowbar": {
  "name": "Crowbar",
  "damage": 2,
  "hit": 5,
  "encumbrance": 4
 },
 "shovel": {
  "name": "Shovel",
  "damage": 2,
  "hit": 10,
  "encumbrance": 4
 },
 "hockey_stick": {
  "name": "Hockey stick",
  "damage": 3,
  "hit": 10,
  "encumbrance": 4
 },
 "tennis_racket": {
  "name": "Tennis racket",
  "damage": 1,
  "hit": 10,
  "encumbrance": 4
 },
 "first_aid_kit": {
  "name": "First aid kit",
  "encumbrance": 2
 },
 "syringe": {
  "name": "Revivification syringe",
  "encumbrance": 2
 },
 "toolbox": {
  "name": "Toolbox",
  "encumbrance": 16
 },
 "portable_generator": {
  "name": "Portable generator",
  "encumbrance": 20
 },
 "fuel_can": {
  "name": "Fuel can",
  "encumbrance": 10
 },
 "length_of_pipe": {
  "name": "Length of pipe",
  "damage": 2,
  "hit": 10,
  "encumbrance": 4
 },
 "cricket_bat": {
  "name": "Cricket bat",
  "damage": 3,
  "hit": 10,
  "encumbrance": 4
 },
 "fencing_foil": {
  "name": "Fencing foil",
  "damage": 2,
  "hit": 10,
  "encumbrance": 4
 },
 "pool_cue": {
  "name": "Pool cue",
  "break_on_hit": 0.20,
  "damage": 2,
  "hit": 25,
  "encumbrance": 4
 },
 "ski_pole": {
  "name": "Ski pole",
  "damage": 2,
  "hit": 10,
  "encumbrance": 4
 },
 "flare_gun": {
  "name": "Flare gun",
  "damage": 15,
  "hit": 2.5,
  "ranged": true,
  "single_use": true,
  "encumbrance": 2
 },
 "flak_jacket": {
  "name": "Flak jacket",
  "action": "inspect",
  "encumbrance": 2
 },
 "mobile_phone": {
  "name": "Mobile phone",
  "action": "phone",
  "encumbrance": 2
 },
 "radio": {
  "name": "Radio receiver",
  "action": "tune",
  "encumbrance": 4
 },
 "radio_transmitter": {
  "name": "Radio transmitter",
  "action": "install_radio",
  "encumbrance": 20
 },
 "spray_can": {
  "name": "Spray can",
  "action": "tag",
  "encumbrance": 2
 },
 "flashlight": {
  "name": "Flashlight",
  "action": "inspect",
  "encumbrance": 2
 },
 "binoculars": {
  "name": "Binoculars",
  "action": "lookout",
  "encumbrance": 4
 },
 "dna_extractor": {
  "name": "DNA extractor",
  "action": "extract",
  "encumbrance": 4
 },
 "gps_unit": {
  "name": "GPS unit",
  "action": "locate",
  "encumbrance": 2
 },
 "map": {
  "name": "City map",
  "action": "view_map",
  "encumbrance": 2
 },
 "book": {
  "name": "Book",
  "action": "read",
  "encumbrance": 2
 },
 "poetry_book": {
  "name": "Poetry book",
  "action": "read",
  "encumbrance": 2
 },
 "newspaper": {
  "name": "Newspaper",
  "damage": 0,
  "hit": 100,
  "encumbrance": 2
 },
 "crucifix": {
  "name": "Crucifix",
  "action": "inspect",
  "encumbrance": 2
 },
 "clothing": {
  "name": "Clothing",
  "action": "wear",
  "encumbrance": 2
 },
 "beer": {
  "name": "Beer",
  "action": "drink",
  "damage": 3,
  "hit": 10,
  "fragile": true,
  "encumbrance": 2
 },
 "wine": {
  "name": "Wine",
  "action": "drink",
  "damage": 3,
  "hit": 10,
  "fragile": true,
  "encumbrance": 4
 },
 "candy": {
  "name": "Stale candy",
  "action": "eat",
  "encumbrance": 0
 },
 "glass_piece": {
  "name": "Glass piece",
  "action": "decorate",
  "encumbrance": 20
 },
 "painting": {
  "name": "Painting",
  "action": "decorate",
  "encumbrance": 20
 },
 "pottery": {
  "name": "Pottery",
  "action": "decorate",
  "encumbrance": 20
 },
 "sculpture": {
  "name": "Sculpture",
  "action": "decorate",
  "encumbrance": 20
 },
 "skeleton": {
  "name": "Skeleton",
  "action": "decorate",
  "encumbrance": 20
 },
 "statue": {
  "name": "Statue",
  "action": "decorate",
  "encumbrance": 20
 },
 "stuffed_animal": {
  "name": "Stuffed animal",
  "action": "decorate",
  "encumbrance": 20
 },
 "tapestry": {
  "name": "Tapestry",
  "action": "decorate",
  "encumbrance": 20
 },
 "christmas_lights": {
  "name": "Christmas lights",
  "action": "decorate",
  "encumbrance": 2
 },
 "dead_fir_tree": {
  "name": "Dead fir tree",
  "action": "decorate",
  "encumbrance": 20
 },
 "plastic_christmas_tree": {
  "name": "Plastic christmas tree",
  "action": "decorate",
  "encumbrance": 20
 },
 "pumpkin": {
  "name": "Pumpkin",
  "action": "decorate",
  "encumbrance": 20
 },
 "tinsel": {
  "name": "Tinsel",
  "action": "decorate",
  "encumbrance": 20
 }
}
# Full persistent skill catalogue; descriptions describe the local simulation effects.
const SKILLS = {
 "shopping": {
  "name": "Shopping",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Choose a mall store when searching."
 },
 "bargain_hunting": {
  "name": "Bargain Hunting",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "shopping",
  "min_level": 0,
  "description": "Improve the total chance of finding items in malls."
 },
 "body_building": {
  "name": "Body Building",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Raise maximum HP to 60, including after death."
 },
 "tagging": {
  "name": "Tagging",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Earn XP for useful exterior tags and make spray cans last longer."
 },
 "construction": {
  "name": "Construction",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Build and reinforce barricades without a pipe. Use a toolbox to repair machinery and ruins."
 },
 "radio_operation": {
  "name": "Radio Operation",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Install, tune and broadcast over radio transmitters."
 },
 "firearms": {
  "name": "Basic Firearms Training",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Add 15 percentage points to pistol and shotgun accuracy."
 },
 "pistol_training": {
  "name": "Pistol Training",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "firearms",
  "min_level": 0,
  "description": "Add 25 points to pistol accuracy."
 },
 "advanced_pistol": {
  "name": "Advanced Pistol Training",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "firearms",
  "min_level": 0,
  "description": "Add another 10 points to pistol accuracy."
 },
 "shotgun_training": {
  "name": "Shotgun Training",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "firearms",
  "min_level": 0,
  "description": "Add 25 points to shotgun accuracy."
 },
 "advanced_shotgun": {
  "name": "Advanced Shotgun Training",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "firearms",
  "min_level": 0,
  "description": "Add another 10 points to shotgun accuracy."
 },
 "hand_to_hand": {
  "name": "Hand-to-Hand Combat",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Add 15 points to melee and fist accuracy."
 },
 "knife_combat": {
  "name": "Knife Combat",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "hand_to_hand",
  "min_level": 0,
  "description": "Add 25 points to knife accuracy, reaching 50%."
 },
 "axe_proficiency": {
  "name": "Axe Proficiency",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "hand_to_hand",
  "min_level": 0,
  "description": "Add 30 points to fire axe accuracy, capped at 40%."
 },
 "free_running": {
  "name": "Free Running",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Move directly between intact building interiors."
 },
 "scout_safehouse": {
  "name": "Scout Safehouse",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Spend 30 AP scouting a shelter for five discounted actions each day."
 },
 "necro_employment": {
  "name": "NecroTech Employment",
  "side": "human",
  "category": "science",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Operate DNA extractors and recognise NecroTech sites."
 },
 "lab_experience": {
  "name": "Lab Experience",
  "side": "human",
  "category": "science",
  "cost": 100,
  "requires": "necro_employment",
  "min_level": 0,
  "description": "Revive zombies using syringes."
 },
 "necronet": {
  "name": "NecroNet Access",
  "side": "human",
  "category": "science",
  "cost": 100,
  "requires": "necro_employment",
  "min_level": 0,
  "description": "Scan tagged zombies, make syringes and revive Brain Rot in powered labs."
 },
 "first_aid": {
  "name": "First Aid",
  "side": "human",
  "category": "science",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "First aid kits heal 10 HP instead of 5."
 },
 "surgery": {
  "name": "Surgery",
  "side": "human",
  "category": "science",
  "cost": 100,
  "requires": "first_aid",
  "min_level": 0,
  "description": "Heal another 5 HP in powered hospitals and infirmaries."
 },
 "diagnosis": {
  "name": "Diagnosis",
  "side": "human",
  "category": "science",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Read exact HP for nearby survivors while alive."
 },
 "headshot": {
  "name": "Headshot",
  "side": "human",
  "category": "hunter",
  "cost": 100,
  "requires": "",
  "min_level": 10,
  "description": "Killed zombies need five additional AP to stand. Requires level 10."
 },
"scent_fear": {
  "name": "Scent Fear",
  "side": "zombie",
  "category": "scent",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Mark survivors below 25 HP as wounded and below 13 HP as dying. Gain 10 bonus XP for killing a survivor."
 },
"scent_blood": {
  "name": "Scent Blood",
  "side": "zombie",
  "category": "scent",
  "cost": 100,
  "requires": "scent_fear",
  "min_level": 0,
  "description": "Read exact survivor HP and highlight infected survivors in light green."
 },
"scent_trail": {
  "name": "Scent Trail",
  "side": "zombie",
  "category": "scent",
  "cost": 100,
  "requires": "scent_fear",
  "min_level": 0,
  "description": "Automatically track a survivor after combat, DNA sampling, first aid, or a failed Brain Rot revival. The scent is lost at 10 blocks."
 },
"scent_death": {
  "name": "Scent Death",
  "side": "zombie",
  "category": "scent",
  "cost": 100,
  "requires": "scent_fear",
  "min_level": 0,
  "description": "Recognize revivifying bodies in either form. As a zombie, spend 1 AP to sense bodies and zombies within five blocks."
 },
"digestion": {
  "name": "Digestion",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Bites restore HP; feed on corpses to recover four HP."
 },
"infectious_bite": {
  "name": "Infectious Bite",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "digestion",
  "min_level": 0,
  "description": "Successful bites infect survivors. Infection costs 1 HP per AP spent until cured by first aid."
 },
"vigour_mortis": {
  "name": "Vigour Mortis",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Add 10 points to claw accuracy, reaching 35%."
 },
"neck_lurch": {
  "name": "Neck Lurch",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Unlock a bite at 30% accuracy for 4 damage."
 },
"death_grip": {
  "name": "Death Grip",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Add 15 points to hand accuracy."
 },
"rend_flesh": {
  "name": "Rend Flesh",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Raise bite accuracy to 40% and bite damage to 5."
 },
"tangling_grasp": {
  "name": "Tangling Grasp",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "A claw hit grips the survivor and lowers their attack accuracy by 10 points until released."
 },
"feeding_drag": {
  "name": "Feeding Drag",
  "side": "zombie",
  "category": "offensive",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Drag dying or unconscious survivors through an open, clear entrance."
 },
"memories": {
  "name": "Memories of Life",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Open and secure doors."
 },
"death_rattle": {
  "name": "Death Rattle",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Communicate using groaned zombie speech."
 },
"feeding_groan": {
  "name": "Feeding Groan",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Call nearby zombies towards the survivors you face."
 },
"bellow": {
  "name": "Bellow",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Spend 10 AP to call a horde when facing at least 25 survivors."
 },
"ransack": {
  "name": "Ransack",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Ransack and ruin undefended buildings, blocking barricading and reducing loot."
 },
"flailing_gesture": {
  "name": "Flailing Gesture",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Point towards locations, objects or people."
 },
"lurching_gait": {
  "name": "Lurching Gait",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Movement costs one AP instead of two."
 },
"death_lurch": {
  "name": "Death Lurch",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Stand for 5 AP and move one square for 1 AP."
 },
"ankle_grab": {
  "name": "Ankle Grab",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "lurching_gait",
  "min_level": 0,
  "description": "Standing costs one AP, plus any Headshot penalty."
 },
"brain_rot": {
  "name": "Brain Rot",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Block DNA extraction. Revival costs 10 AP and needs a powered lab and NecroNet."
 },
"flesh_rot": {
  "name": "Flesh Rot",
  "side": "zombie",
  "category": "utility",
  "cost": 100,
  "requires": "brain_rot",
  "min_level": 0,
  "description": "Raise zombie maximum HP to 60 and reduce firearm damage."
 }
}
static func pretty(value: String) -> String:
 return value.replace("_", " ").capitalize()

const BARRICADE_DESCRIPTIONS = ["not barricaded", "loosely barricaded", "lightly barricaded", "quite strongly barricaded", "very strongly barricaded", "heavily barricaded", "very heavily barricaded", "extremely heavily barricaded"]

static func barricade_description(level: int) -> String:
 return BARRICADE_DESCRIPTIONS[clampi(level, 0, 7)]

static func skill_category(skill: String) -> String:
 return SKILLS[skill].category

static func occupation_category(job: String) -> String:
 if job in ["Private", "Medic", "Scout", "Guard"]: return "military"
 if job in ["Doctor", "Scientist", "NecroTech Lab Assistant", "NecroTech Assistant"]: return "science"
 return "civilian"

static func occupation_sheet(job: String, human: bool) -> String:
 if not human: return "zombie"
 return {"Private":"private","Guard":"private","Medic":"medic","Scout":"scout","NecroTech Lab Assistant":"necro","NecroTech Assistant":"necro","Scientist":"necro","Doctor":"doctor","Police Officer":"police","Firefighter":"firefighter","Engineer":"firefighter","Consumer":"consumer","Volunteer":"consumer","Resident":"vagrant","Corpse":"vagrant"}.get(job,"consumer")

const PORTRAITS = {"Private":"private","Guard":"private","Medic":"medic","Scout":"scout","NecroTech Lab Assistant":"necro","Scientist":"necro","Doctor":"doctor","Police Officer":"police","Firefighter":"firefighter","Engineer":"firefighter","Consumer":"consumer","Volunteer":"consumer","Resident":"corpse","Corpse":"corpse"}
const MALL_STORES = {"bookstore":["book","poetry_book","newspaper"],"drugstore":["first_aid_kit","book","candy"],"gun_store":["pistol","shotgun","pistol_clip","shotgun_shell"],"hardware":["fuel_can","crowbar","fire_axe","knife","portable_generator","spray_can","toolbox","flare_gun"],"liquor":["beer","wine"],"sports":["baseball_bat","cricket_bat","fencing_foil","golf_club","hockey_stick","pool_cue","ski_pole","tennis_racket","binoculars"],"tech":["gps_unit","mobile_phone","radio","radio_transmitter"]}
