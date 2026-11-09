extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")


static func unit(value: float) -> float:
	return clampf(value, 0.0, 1.0)


static func smooth(value: float) -> float:
	var x: float = unit(value)
	return x * x * (3.0 - 2.0 * x)


static func proximity(distance: float) -> float:
	return 1.0 / (1.0 + 0.65 * distance * distance)


static func danger(
	distance: float, hostile_power: float, friendly_power: float, exposure: float, breach: float
) -> float:
	var force_ratio: float = hostile_power / maxf(0.65, friendly_power)
	var odds: float = unit((force_ratio - 0.5) / 2.0)
	return maxf(unit(breach), proximity(distance) * odds * unit(exposure))


static func flee(threat: float, hp_fraction: float, ap: int) -> float:
	var wounds: float = 1.0 - unit(hp_fraction)
	var exhausted: float = 1.0 - smooth(float(ap) / 16.0)
	return unit(threat) * (0.72 + 0.18 * wounds + 0.10 * exhausted)


static func scavenge(ap: int, trip_ap: int, need: float, cache_quality: float, threat: float) -> float:
	if ap < trip_ap:
		return 0.0
	var surplus: float = smooth(float(ap - trip_ap) / 18.0)
	return (0.20 + 0.80 * surplus) * unit(need) * unit(cache_quality) * (1.0 - unit(threat))


static func rest(ap: int, shelter_quality: float, threat: float) -> float:
	var exhausted: float = 1.0 - smooth(float(ap) / 28.0)
	return exhausted * unit(shelter_quality) * (1.0 - unit(threat))


static func heal(hp_fraction: float, infection_urgency: float) -> float:
	var wounds: float = smooth((1.0 - unit(hp_fraction)) / 0.70)
	return maxf(wounds, unit(infection_urgency))


static func defend(damage_per_ap: float, defense_value: float, threat: float) -> float:
	var efficiency: float = maxf(0.0, damage_per_ap)
	return efficiency / (efficiency + 2.0) * unit(defense_value) * (1.0 - 0.65 * unit(threat))


static func barricade_target(is_entry: bool, has_open_entry_path: bool) -> int:
	if is_entry or not has_open_entry_path:
		return Catalog.BARRICADE_MAX_STRENGTH[4]
	return Catalog.BARRICADE_MAX_STRENGTH[7]


static func barricade(strength: int, target: int, build_chance: float, shelter_value: float, breach: float) -> float:
	if strength >= target:
		return 0.0
	var deficit: float = smooth(float(target - strength) / 10.0)
	return unit(build_chance) * unit(shelter_value) * (0.20 + 0.45 * deficit + 0.35 * unit(breach))


static func hunt(sighting: float, groan: float, lit: bool, distance: float, pack: int) -> float:
	var cue: float = maxf(unit(sighting), maxf(0.85 * unit(groan), 0.50 if lit else 0.0))
	var crowd: float = unit(float(pack - 1) / 4.0)
	var travel: float = 1.0 / (1.0 + maxf(0.0, distance) / 4.0)
	return cue * travel * (0.68 + 0.10 * crowd)


static func attack(damage_per_ap: float, target_vulnerability: float, pack: int) -> float:
	var efficiency: float = maxf(0.0, damage_per_ap)
	var crowd: float = unit(float(pack - 1) / 4.0)
	return 0.80 + 0.10 * efficiency / (efficiency + 2.0) + 0.06 * unit(target_vulnerability) + 0.04 * crowd


static func breach(cue: float, work_ap: float, pack: int) -> float:
	var crowd: float = unit(float(pack - 1) / 4.0)
	var effort: float = 1.0 / (1.0 + maxf(0.0, work_ap) / (8.0 * maxi(1, pack)))
	return unit(cue) * (0.30 + 0.32 * effort + 0.12 * crowd)


static func vandalize(site_value: float, committed: bool) -> float:
	return 0.19 + 0.06 * unit(site_value) + (0.03 if committed else 0.0)


static func wander(best_signal: float, exploration: float) -> float:
	return (0.05 + 0.13 * unit(exploration)) * (1.0 - 0.85 * unit(best_signal))
