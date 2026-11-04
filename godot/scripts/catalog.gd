extends RefCounted

const SIZE = 10
const AP_CAP = 50
const RECOVERY_MINUTES = 30
const GAME_MINUTES_PER_SECOND = 1.0
const REST_SPEED = 16.0
const DEATH_SPEED = 32.0
const DAILY_REANIMATION_CHANCE = 0.20
const GENERATOR_HP = 6
const FUEL_MINUTES = 1440
const BARRICADE_SUBLEVELS = 3
const BREACH_CHANCE = 0.25
const DARK_SEARCH_MULTIPLIER = 0.30
const RUIN_SEARCH_MULTIPLIER = 0.025
const CLOCK_STEPS_PER_MINUTE = 10
# Recovery is independent of AP cost. At normal speed these values are seconds.
const ACTION_RECOVERY = {"move":1.0, "attack":1.4, "search":2.2,
 "revive":3.0, "manufacture":6.0, "stand":2.0, "heal":1.8,
 "dump":2.0, "repair_generator":2.5, "destroy_generator":2.0, "barricade":2.0, "break":1.8, "repair":2.5, "equip":0.4, "drop":0.4}
const ENCUMBRANCE_LIMIT = 100
const OUTDOORS = ["wasteland", "exercise_yard", "training_ground", "zoo_ground", "street", "park", "cemetery", "monument", "carpark"]
const NORMAL_BUILDINGS = ["fire_station", "police_department", "hospital", "library", "church", "warehouse", "auto_repair", "factory", "school", "office", "necrotech_lab", "junkyard", "museum", "nightclub", "pub", "mall", "bank", "cinema", "hotel", "railway_station", "tower"]
const BUILDINGS = NORMAL_BUILDINGS + ["cathedral", "mansion", "power_station", "stadium", "armoury", "barracks", "gatehouse", "infirmary", "storehouse", "vehicle_depot", "aquarium", "bear_pit", "elephant_house", "giraffe_house", "lion_enclosure", "reptile_house"]
const ITEMS = {
 "fire_axe": {
  "name": "Fire axe",
  "damage": 3,
  "hit": 10,
  "durability": 30,
  "encumbrance": 6
 },
 "knife": {
  "name": "Knife",
  "damage": 2,
  "hit": 20,
  "durability": 50,
  "encumbrance": 2
 },
 "pistol": {
  "name": "Pistol",
  "damage": 5,
  "hit": 5,
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
  "hit": 5,
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
  "durability": 25,
  "encumbrance": 2
 },
 "golf_club": {
  "name": "Golf club",
  "damage": 2,
  "hit": 10,
  "durability": 25,
  "encumbrance": 4
 },
 "crowbar": {
  "name": "Crowbar",
  "damage": 2,
  "hit": 5,
  "durability": 60,
  "encumbrance": 4
 },
 "shovel": {
  "name": "Shovel",
  "damage": 2,
  "hit": 10,
  "durability": 30,
  "encumbrance": 4
 },
 "hockey_stick": {
  "name": "Hockey stick",
  "damage": 2,
  "hit": 10,
  "durability": 25,
  "encumbrance": 4
 },
 "tennis_racket": {
  "name": "Tennis racket",
  "damage": 1,
  "hit": 10,
  "durability": 20,
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
  "durability": 30,
  "encumbrance": 4
 },
 "cricket_bat": {
  "name": "Cricket bat",
  "damage": 3,
  "hit": 10,
  "durability": 30,
  "encumbrance": 4
 },
 "fencing_foil": {
  "name": "Fencing foil",
  "damage": 2,
  "hit": 10,
  "durability": 30,
  "encumbrance": 4
 },
 "pool_cue": {
  "name": "Pool cue",
  "damage": 2,
  "hit": 25,
  "durability": 30,
  "encumbrance": 4
 },
 "ski_pole": {
  "name": "Ski pole",
  "damage": 2,
  "hit": 10,
  "durability": 30,
  "encumbrance": 4
 },
 "flare_gun": {
  "name": "Flare gun",
  "damage": 15,
  "hit": 15,
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
  "action": "locate",
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
  "action": "read",
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
  "description": "Barricade and use a toolbox to repair buildings."
 },
 "radio_operation": {
  "name": "Radio Operation",
  "side": "human",
  "category": "civilian",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Broadcast on restricted 26-28 MHz radio channels."
 },
 "firearms": {
  "name": "Basic Firearms Training",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Add 25 percentage points to firearm accuracy."
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
  "requires": "pistol_training",
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
  "requires": "shotgun_training",
  "min_level": 0,
  "description": "Add another 10 points to shotgun accuracy."
 },
 "hand_to_hand": {
  "name": "Hand to Hand Combat",
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
  "description": "Add 15 points to knife accuracy."
 },
 "axe_proficiency": {
  "name": "Axe Proficiency",
  "side": "human",
  "category": "military",
  "cost": 100,
  "requires": "hand_to_hand",
  "min_level": 0,
  "description": "Add 15 points to axe accuracy."
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
  "requires": "lab_experience",
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
  "description": "Read nearby survivor HP when visibility permits."
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
  "category": "zombie",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Distinguish wounded and dying survivors."
 },
 "scent_blood": {
  "name": "Scent Blood",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "scent_fear",
  "min_level": 0,
  "description": "Read survivor HP and recognise infection."
 },
 "scent_trail": {
  "name": "Scent Trail",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "scent_fear",
  "min_level": 0,
  "description": "Track survivors with whom you recently fought."
 },
 "scent_death": {
  "name": "Scent Death",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "scent_fear",
  "min_level": 0,
  "description": "Sense nearby zombies, bodies and revivifying bodies."
 },
 "digestion": {
  "name": "Digestion",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Bites restore HP; feed on corpses to recover four HP."
 },
 "infectious_bite": {
  "name": "Infectious Bite",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "digestion",
  "min_level": 0,
  "description": "Bites infect survivors until medical treatment."
 },
 "vigour_mortis": {
  "name": "Vigour Mortis",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Add 10 points to hand and bite accuracy."
 },
 "neck_lurch": {
  "name": "Neck Lurch",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Add 10 points to bite accuracy."
 },
 "death_grip": {
  "name": "Death Grip",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Add 15 points to hand accuracy."
 },
 "rend_flesh": {
  "name": "Rend Flesh",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Hand attacks inflict one extra damage."
 },
 "tangling_grasp": {
  "name": "Tangling Grasp",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Hand hits grasp a victim: +10 accuracy; a miss has 50% grip-loss chance."
 },
 "feeding_drag": {
  "name": "Feeding Drag",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "vigour_mortis",
  "min_level": 0,
  "description": "Drag survivors at 12 HP or less through an open, clear entrance."
 },
 "memories": {
  "name": "Memories of Life",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Open closed doors."
 },
 "death_rattle": {
  "name": "Death Rattle",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Communicate using groaned zombie speech."
 },
 "feeding_groan": {
  "name": "Feeding Groan",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Call nearby zombies towards the survivors you face."
 },
 "bellow": {
  "name": "Bellow",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "feeding_groan",
  "min_level": 0,
  "description": "Spend 10 AP to call a horde when facing at least 25 survivors."
 },
 "ransack": {
  "name": "Ransack",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Damage undefended interiors after destroying generators."
 },
 "flailing_gesture": {
  "name": "Flailing Gesture",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "memories",
  "min_level": 0,
  "description": "Point towards locations, objects or people."
 },
 "lurching_gait": {
  "name": "Lurching Gait",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Movement costs one AP instead of two."
 },
 "ankle_grab": {
  "name": "Ankle Grab",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "lurching_gait",
  "min_level": 0,
  "description": "Standing costs one AP, plus any Headshot penalty."
 },
 "brain_rot": {
  "name": "Brain Rot",
  "side": "zombie",
  "category": "zombie",
  "cost": 100,
  "requires": "",
  "min_level": 0,
  "description": "Resist DNA extraction; revival needs a powered lab and NecroNet."
 },
 "flesh_rot": {
  "name": "Flesh Rot",
  "side": "zombie",
  "category": "zombie",
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
const MALL_STORES = {"bookstore":["book","poetry_book","newspaper"],"drugstore":["first_aid_kit"],"gun_store":["pistol","shotgun","pistol_clip","shotgun_shell"],"hardware":["crowbar","fire_axe","knife","portable_generator","spray_can","toolbox","flare_gun"],"liquor":["beer","wine"],"sports":["baseball_bat","cricket_bat","fencing_foil","golf_club","hockey_stick","pool_cue","ski_pole","tennis_racket","binoculars"],"tech":["gps_unit","mobile_phone","radio","radio_transmitter"]}
