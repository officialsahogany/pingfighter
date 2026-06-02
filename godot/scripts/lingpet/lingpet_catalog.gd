extends RefCounted

const DEFAULT_PET_ID := "maribo"
const REQUIRED_STAT_KEYS := [
	"patrol_speed_default",
	"patrol_speed_min",
	"patrol_speed_max",
	"catch_width",
	"catch_height",
	"defense_rate",
	"hit_gauge_gain",
	"gauge_gain_bonus_pct",
]
const REQUIRED_VISUAL_KEYS := [
	"egg",
	"egg_crack_1",
	"egg_crack_2",
	"companion_walk",
	"companion_strike",
	"companion_cast",
	"cutin_art",
	"cutin_anim",
	"cutin_dismiss_anim",
	"click_reaction_anim",
]
const REQUIRED_ACTIVE_SKILL_KEYS := [
	"id",
	"runtime_kind",
	"name",
	"description",
	"cooldown",
	"card_texture_path",
]

const PETS := {
	"maribo": {
		"id": "maribo",
		"display_name": "마리보",
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 120.0,
			"patrol_speed_min": 70.0,
			"patrol_speed_max": 135.0,
			"catch_width": 100.0,
			"catch_height": 44.0,
			"defense_rate": 0.30,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 10.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/maribo_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/maribo_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/maribo_companion_hydro_cast.png",
			"cutin_art": "res://assets/sprites/lingpet/maribo_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/maribo_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/maribo_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/maribo_click_live2d_pingpong_98f.png",
		},
		"active_skill": {
			"id": "maribo_hydro_sphere",
			"runtime_kind": "hydro_sphere",
			"name": "하이드로 스피어",
			"description": "물의 기운이 담긴 창을 던집니다. 상대 진영 벽에 닿으면 5초 동안 가로로 넓은 물장판을 만듭니다.",
			"cooldown": 40.0,
			"windup_seconds": 1.0,
			"card_texture_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png",
		},
		"passive_icons": {
			"gauge_gain_bonus": "res://assets/sprites/lingpet/maribo_resonance_boost_passive_icon_imagegen_v1.png",
		},
		"effect_text": "공을 받아칠 때 게이지 획득량 +10% / 링펫이 공을 직접 튕기면 게이지 +40 / 하이드로 스피어: 40초마다 물창을 던져 상대 진영에 5초 둔화 장판을 만듭니다.",
	},
	"lunabi": {
		"id": "lunabi",
		"display_name": "루나비",
		"motion_style": "sortie_flight",
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 285.0,
			"patrol_speed_min": 210.0,
			"patrol_speed_max": 390.0,
			"catch_width": 88.0,
			"catch_height": 58.0,
			"defense_rate": 0.0,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/lunabi_companion_wing_flap.png",
			"companion_strike": "res://assets/sprites/lingpet/lunabi_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/lunabi_companion_strike.png",
			"cutin_art": "res://assets/sprites/lingpet/lunabi_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/lunabi_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/lunabi_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/lunabi_click_live2d_pingpong_98f.png",
		},
		"active_skill": {
			"id": "lunabi_headbutt",
			"runtime_kind": "headbutt",
			"name": "박치기",
			"description": "루나비가 상대 패들을 향해 돌진합니다. 맞으면 상대 패들이 약 150px 밀려나며, 상대가 이동 중이면 빗나갈 수 있습니다.",
			"cooldown": 30.0,
			"windup_seconds": 0.45,
			"card_texture_path": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/lunabi_headbutt_skill_icon_imagegen_v1.png",
		},
		"effect_text": "전장 전체를 자유비행합니다. 가끔 화면 밖으로 사라졌다가 다시 들어오며, 공과 겹치면 날개로 받아칩니다. 박치기: 30초마다 상대 패들에 돌진해 약 150px 넉백을 노립니다.",
	},
	"draft_bat": {
		"id": "draft_bat",
		"display_name": "드래프트 배트",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 216.0,
			"patrol_speed_min": 170.0,
			"patrol_speed_max": 260.0,
			"catch_width": 84.0,
			"catch_height": 52.0,
			"defense_rate": 0.10,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/draft_bat_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/draft_bat_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/draft_bat_companion_cast.png",
			"cutin_art": "res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1.png",
			"cutin_anim": "res://assets/sprites/lingpet/draft_bat_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/draft_bat_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/draft_bat_click_live2d_pingpong_98f.png",
		},
		"active_skill": {
			"id": "draft_bat_moon_orbit",
			"runtime_kind": "moon_orbit",
			"name": "월영 궤도",
			"description": "보랏빛 달 궤도를 던집니다. 상대 진영 벽에 닿으면 4초 동안 가로로 넓은 월영장을 만들고, 범위 안의 상대 이동 반응을 둔화시킵니다.",
			"cooldown": 35.0,
			"windup_seconds": 0.85,
			"card_texture_path": "res://assets/sprites/lingpet/draft_bat_moon_orbit_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/draft_bat_moon_orbit_skill_icon_imagegen_v1.png",
		},
		"effect_text": "공을 직접 받아치면 게이지 +40 / 월영 궤도는 35초마다 보랏빛 달 궤도를 던져 상대 진영에 4초 동안 가로로 넓은 둔화장을 만듭니다.",
		"concept_art_path": "res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1.png",
		"concept_chromakey_path": "res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1_chromakey.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/bat_lingpet_cutin_concept_imagegen_v1_magenta_source.png",
		"note": "Draft runtime candidate; disabled until final hatch-pool QA and balance approval.",
	},
}


static func get_default_pet_id() -> String:
	return DEFAULT_PET_ID


static func has_pet(pet_id: String) -> bool:
	return is_pet_enabled_from_entries(PETS, pet_id)


static func get_pet_ids(include_disabled: bool = false) -> Array[String]:
	var result: Array[String] = []
	for pet_id in PETS.keys():
		var entry: Variant = PETS.get(pet_id, {})
		if include_disabled or (entry is Dictionary and _is_entry_enabled(entry as Dictionary)):
			result.append(str(pet_id))
	return result


static func is_pet_enabled(pet_id: String) -> bool:
	return is_pet_enabled_from_entries(PETS, pet_id)


static func is_pet_enabled_from_entries(entries: Dictionary, pet_id: String) -> bool:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = _get_entry_from_entries(entries, normalized)
	return entry is Dictionary and _is_entry_enabled(entry as Dictionary)


static func get_entry(pet_id: String) -> Dictionary:
	var normalized := _normalize_pet_id(pet_id)
	if PETS.has(normalized):
		return (PETS[normalized] as Dictionary).duplicate(true)
	return (PETS[DEFAULT_PET_ID] as Dictionary).duplicate(true)


static func get_display_name(pet_id: String) -> String:
	return str(get_entry(pet_id).get("display_name", _normalize_pet_id(pet_id)))


static func get_required_hits(pet_id: String, fallback: int = 1) -> int:
	return max(1, int(get_entry(pet_id).get("required_hits", fallback)))


static func get_stat(pet_id: String, stat_name: String, fallback: float = 0.0) -> float:
	var stats: Variant = get_entry(pet_id).get("stats", {})
	if stats is Dictionary:
		return float((stats as Dictionary).get(stat_name, fallback))
	return fallback


static func get_active_skill(pet_id: String) -> Dictionary:
	var skill: Variant = get_entry(pet_id).get("active_skill", {})
	if skill is Dictionary:
		return (skill as Dictionary).duplicate(true)
	return {}


static func get_active_skill_entry(skill_id: String) -> Dictionary:
	return get_active_skill_entry_from_entries(PETS, skill_id)


static func get_active_skill_entry_from_entries(entries: Dictionary, skill_id: String) -> Dictionary:
	var normalized := _normalize_skill_id(skill_id)
	if normalized == "":
		return {}
	for raw_pet_id in entries.keys():
		var entry: Variant = entries.get(raw_pet_id, {})
		if not (entry is Dictionary):
			continue
		var skill: Variant = (entry as Dictionary).get("active_skill", {})
		if skill is Dictionary and _normalize_skill_id(str((skill as Dictionary).get("id", ""))) == normalized:
			return (skill as Dictionary).duplicate(true)
	return {}


static func get_active_skill_runtime_kind(skill_id: String) -> String:
	return get_active_skill_runtime_kind_from_entries(PETS, skill_id)


static func get_active_skill_runtime_kind_from_entries(entries: Dictionary, skill_id: String) -> String:
	var skill := get_active_skill_entry_from_entries(entries, skill_id)
	return str(skill.get("runtime_kind", "")).strip_edges().to_lower()


static func get_visual_path(pet_id: String, visual_key: String) -> String:
	var visuals: Variant = get_entry(pet_id).get("visuals", {})
	if visuals is Dictionary:
		return str((visuals as Dictionary).get(visual_key, ""))
	return ""


static func get_passive_icon_path(pet_id: String, passive_id: String) -> String:
	var passive_icons: Variant = get_entry(pet_id).get("passive_icons", {})
	if passive_icons is Dictionary:
		return str((passive_icons as Dictionary).get(passive_id, ""))
	return ""


static func get_effect_text(pet_id: String) -> String:
	return str(get_entry(pet_id).get("effect_text", ""))


static func get_motion_style(pet_id: String) -> String:
	return str(get_entry(pet_id).get("motion_style", "patrol")).strip_edges().to_lower()


static func validate_catalog(require_existing_files: bool = false) -> Array[String]:
	return validate_entries(PETS, require_existing_files)


static func validate_entries(entries: Dictionary, require_existing_files: bool = false) -> Array[String]:
	var issues: Array[String] = []
	var seen_ids := {}
	for raw_pet_id in entries.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		var entry: Variant = entries.get(raw_pet_id, {})
		if pet_id == "":
			issues.append("entry key is empty")
			continue
		if bool(seen_ids.get(pet_id, false)):
			issues.append("%s: duplicate normalized pet id" % pet_id)
		seen_ids[pet_id] = true
		if not (entry is Dictionary):
			issues.append("%s: entry must be a Dictionary" % pet_id)
			continue
		issues.append_array(validate_entry(pet_id, entry as Dictionary, require_existing_files))
	return issues


static func validate_entry(pet_id: String, entry: Dictionary, require_existing_files: bool = false) -> Array[String]:
	var issues: Array[String] = []
	var normalized := _normalize_pet_id(pet_id)
	var entry_id := _normalize_pet_id(str(entry.get("id", "")))
	if entry_id == "":
		issues.append("%s: missing id" % normalized)
	elif entry_id != normalized:
		issues.append("%s: id mismatch (%s)" % [normalized, entry_id])
	if str(entry.get("display_name", "")).strip_edges() == "":
		issues.append("%s: missing display_name" % normalized)
	if float(entry.get("hatch_weight", 0.0)) <= 0.0:
		issues.append("%s: hatch_weight must be > 0" % normalized)
	if int(entry.get("required_hits", 0)) < 1:
		issues.append("%s: required_hits must be >= 1" % normalized)
	var unlock: Variant = entry.get("unlock", {})
	if not (unlock is Dictionary):
		issues.append("%s: unlock must be a Dictionary" % normalized)
	if not _is_entry_enabled(entry):
		return issues
	_validate_required_stats(normalized, entry, issues)
	_validate_required_visuals(normalized, entry, issues, require_existing_files)
	_validate_active_skill(normalized, entry, issues, require_existing_files)
	_validate_passive_icons(normalized, entry, issues, require_existing_files)
	if str(entry.get("effect_text", "")).strip_edges() == "":
		issues.append("%s: missing effect_text" % normalized)
	return issues


static func _validate_required_stats(pet_id: String, entry: Dictionary, issues: Array[String]) -> void:
	var stats: Variant = entry.get("stats", {})
	if not (stats is Dictionary):
		issues.append("%s: stats must be a Dictionary" % pet_id)
		return
	var stats_data: Dictionary = stats as Dictionary
	for key in REQUIRED_STAT_KEYS:
		if not stats_data.has(key):
			issues.append("%s: missing stats.%s" % [pet_id, str(key)])
	if float(stats_data.get("patrol_speed_default", 0.0)) <= 0.0:
		issues.append("%s: stats.patrol_speed_default must be > 0" % pet_id)
	if float(stats_data.get("patrol_speed_min", 0.0)) <= 0.0:
		issues.append("%s: stats.patrol_speed_min must be > 0" % pet_id)
	if float(stats_data.get("patrol_speed_max", 0.0)) < float(stats_data.get("patrol_speed_min", 0.0)):
		issues.append("%s: stats.patrol_speed_max must be >= stats.patrol_speed_min" % pet_id)
	if float(stats_data.get("catch_width", 0.0)) <= 0.0 or float(stats_data.get("catch_height", 0.0)) <= 0.0:
		issues.append("%s: stats.catch_width/height must be > 0" % pet_id)
	var defense_rate := float(stats_data.get("defense_rate", 0.0))
	if defense_rate < 0.0 or defense_rate > 1.0:
		issues.append("%s: stats.defense_rate must be 0..1" % pet_id)


static func _validate_required_visuals(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var visuals: Variant = entry.get("visuals", {})
	if not (visuals is Dictionary):
		issues.append("%s: visuals must be a Dictionary" % pet_id)
		return
	var visuals_data: Dictionary = visuals as Dictionary
	for key in REQUIRED_VISUAL_KEYS:
		var path := str(visuals_data.get(key, "")).strip_edges()
		if path == "":
			issues.append("%s: missing visuals.%s" % [pet_id, str(key)])
		elif require_existing_files and not FileAccess.file_exists(path):
			issues.append("%s: missing visual file %s" % [pet_id, path])


static func _validate_active_skill(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var skill: Variant = entry.get("active_skill", {})
	if not (skill is Dictionary):
		issues.append("%s: active_skill must be a Dictionary" % pet_id)
		return
	var skill_data: Dictionary = skill as Dictionary
	for key in REQUIRED_ACTIVE_SKILL_KEYS:
		if str(skill_data.get(key, "")).strip_edges() == "":
			issues.append("%s: missing active_skill.%s" % [pet_id, str(key)])
	if float(skill_data.get("cooldown", 0.0)) <= 0.0:
		issues.append("%s: active_skill.cooldown must be > 0" % pet_id)
	if skill_data.has("windup_seconds") and float(skill_data.get("windup_seconds", 0.0)) < 0.0:
		issues.append("%s: active_skill.windup_seconds must be >= 0" % pet_id)
	var card_path := str(skill_data.get("card_texture_path", "")).strip_edges()
	if card_path != "" and require_existing_files and not FileAccess.file_exists(card_path):
		issues.append("%s: missing skill-card file %s" % [pet_id, card_path])


static func _validate_passive_icons(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var passive_icons: Variant = entry.get("passive_icons", {})
	if passive_icons == null:
		return
	if not (passive_icons is Dictionary):
		issues.append("%s: passive_icons must be a Dictionary" % pet_id)
		return
	for raw_key in (passive_icons as Dictionary).keys():
		var icon_key := str(raw_key).strip_edges()
		var path := str((passive_icons as Dictionary).get(raw_key, "")).strip_edges()
		if icon_key == "":
			issues.append("%s: passive_icons has an empty key" % pet_id)
		if path == "":
			issues.append("%s: missing passive icon path for %s" % [pet_id, icon_key])
		elif require_existing_files and not FileAccess.file_exists(path):
			issues.append("%s: missing passive icon file %s" % [pet_id, path])


static func get_hatch_candidates(context: Dictionary, owned_pet_ids: Array) -> Array[String]:
	return get_hatch_candidates_from_entries(PETS, context, owned_pet_ids)


static func get_hatch_candidates_from_entries(entries: Dictionary, context: Dictionary, owned_pet_ids: Array) -> Array[String]:
	var owned_lookup := {}
	for raw_id in owned_pet_ids:
		var owned_id := _normalize_pet_id(str(raw_id))
		if owned_id != "":
			owned_lookup[owned_id] = true
	var result: Array[String] = []
	for raw_pet_id in entries.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		var entry: Variant = entries.get(raw_pet_id, {})
		if (
			pet_id != ""
			and entry is Dictionary
			and _is_entry_enabled(entry as Dictionary)
			and not bool(owned_lookup.get(pet_id, false))
			and _matches_unlock(entry as Dictionary, context)
		):
			result.append(pet_id)
	return result


static func pick_hatch_pet_id(context: Dictionary, owned_pet_ids: Array, rng: RandomNumberGenerator = null) -> String:
	return pick_hatch_pet_id_from_entries(PETS, context, owned_pet_ids, rng)


static func pick_hatch_pet_id_from_entries(entries: Dictionary, context: Dictionary, owned_pet_ids: Array, rng: RandomNumberGenerator = null) -> String:
	var candidates := get_hatch_candidates_from_entries(entries, context, owned_pet_ids)
	if candidates.is_empty():
		return ""
	var total_weight := 0.0
	for pet_id in candidates:
		total_weight += _get_entry_weight(entries, pet_id)
	if total_weight <= 0.0:
		return candidates[0]
	var roll := (rng.randf() if rng != null else randf()) * total_weight
	for pet_id in candidates:
		roll -= _get_entry_weight(entries, pet_id)
		if roll <= 0.0:
			return pet_id
	return candidates[candidates.size() - 1]


static func _get_entry_weight(entries: Dictionary, pet_id: String) -> float:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = _get_entry_from_entries(entries, normalized)
	if entry is Dictionary:
		return maxf(0.0, float((entry as Dictionary).get("hatch_weight", 1.0)))
	return 0.0


static func _get_entry_from_entries(entries: Dictionary, pet_id: String) -> Variant:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = entries.get(normalized, null)
	if entry is Dictionary:
		return entry
	for raw_pet_id in entries.keys():
		if _normalize_pet_id(str(raw_pet_id)) == normalized:
			return entries.get(raw_pet_id, null)
	return null


static func _is_entry_enabled(entry: Dictionary) -> bool:
	return bool(entry.get("enabled", true))


static func _matches_unlock(entry: Dictionary, context: Dictionary) -> bool:
	var unlock: Variant = entry.get("unlock", {})
	if not (unlock is Dictionary):
		return true
	var unlock_data: Dictionary = unlock as Dictionary
	var required_league := str(unlock_data.get("league_mode", "")).strip_edges().to_lower()
	if required_league != "" and _normalize_league_mode(str(context.get("league_mode", ""))) != required_league:
		return false
	var required_character := str(unlock_data.get("character_type", "")).strip_edges().to_lower()
	if required_character != "" and _normalize_character_type(str(context.get("character_type", ""))) != required_character:
		return false
	return true


static func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _normalize_skill_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _normalize_league_mode(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")
	if normalized in ["junior", "juniorleague", "주니어", "주니어리그"]:
		return "junior"
	return normalized


static func _normalize_character_type(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["mika", "미카", "smasher", "스매셔"]:
		return "smasher"
	return normalized
