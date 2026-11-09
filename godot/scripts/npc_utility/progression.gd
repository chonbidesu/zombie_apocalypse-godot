extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")

const HUMAN_CORE: Array[String] = ["free_running", "construction"]
const PISTOL: Array[String] = ["firearms", "pistol_training", "advanced_pistol"]
const SHOTGUN: Array[String] = ["firearms", "shotgun_training", "advanced_shotgun"]
const AXE: Array[String] = ["hand_to_hand", "axe_proficiency"]
const KNIFE: Array[String] = ["hand_to_hand", "knife_combat"]
const MELEE: Array[String] = ["hand_to_hand"]
const SURVIVAL: Array[String] = ["first_aid", "body_building"]
const REVIVAL: Array[String] = ["necro_employment", "lab_experience", "necronet"]
const MEDICAL: Array[String] = ["diagnosis", "surgery"]
const CIVILIAN: Array[String] = ["shopping", "bargain_hunting", "scout_safehouse", "tagging", "radio_operation"]
const HUNTER: Array[String] = ["headshot"]
const ROT: Array[String] = ["brain_rot", "flesh_rot"]
const RETURN_TO_LIFE: Array[String] = ["lurching_gait", "ankle_grab"]
const ZOMBIE_CORE: Array[String] = [
	"vigour_mortis", "lurching_gait", "ankle_grab", "death_grip", "memories",
	"feeding_groan", "ransack", "tangling_grasp", "neck_lurch", "rend_flesh",
	"digestion", "infectious_bite", "scent_fear", "scent_trail", "scent_blood",
	"feeding_drag", "scent_death", "bellow", "death_rattle", "flailing_gesture",
]


# Pick a strategically eligible skill before checking XP, so the actor saves
# for that unlock instead of spending on whatever it can afford this instant.
static func target_skill(actor: Dictionary, level: int, weapon_track: String, clinic: bool) -> String:
	var owned: Array = actor.human_skills if actor.human else actor.zombie_skills
	if not actor.human:
		if actor.get("wants_revive", false): return _next_in(RETURN_TO_LIFE, owned, level)
		var upgrade: String = _next_in(ZOMBIE_CORE, owned, level)
		if upgrade.is_empty() and actor.get("prefers_undead", false):
			return _next_in(ROT, owned, level)
		return upgrade
	var skill: String = _next_in(HUMAN_CORE, owned, level)
	if not skill.is_empty():
		return skill
	var combat: Array[String] = MELEE
	match weapon_track:
		"pistol": combat = PISTOL
		"shotgun": combat = SHOTGUN
		"axe": combat = AXE
		"knife": combat = KNIFE
	# Buy the first usable combat bonus, then branch into the assigned role.
	if combat[0] not in owned:
		return _next_in(combat, owned, level)
	if clinic:
		skill = _next_in(REVIVAL, owned, level)
		if not skill.is_empty():
			return skill
	skill = _next_in(SURVIVAL, owned, level)
	if not skill.is_empty(): return skill
	if actor.get("job", "") in ["Doctor", "Medic"]:
		skill = _next_in(MEDICAL, owned, level)
		if not skill.is_empty(): return skill
	skill = _next_in(combat, owned, level)
	if not skill.is_empty(): return skill
	skill = _next_in(HUNTER, owned, level)
	return skill if not skill.is_empty() else _next_in(CIVILIAN, owned, level)


static func _next_in(track: Array[String], owned: Array, level: int) -> String:
	for skill in track:
		if skill in owned:
			continue
		var definition: Dictionary = Catalog.SKILLS[skill]
		var prerequisite: String = definition.requires
		if level >= int(definition.min_level) and (prerequisite.is_empty() or prerequisite in owned):
			return skill
	return ""
