extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

static func _get_display_name(lingpet_id: String) -> String:
	if LingpetCatalog.has_pet(lingpet_id):
		return LingpetCatalog.get_display_name(lingpet_id)
	match lingpet_id:
		"maribo":
			return "마리보"
		"":
			return "링펫"
		_:
			return lingpet_id


static func _default_affinity_next_label(level: int) -> String:
	if level >= LingpetAffinityState.MAX_LEVEL:
		return "하트 공명"
	return ""


static func _companion_subtitle_for_bond(title: String) -> String:
	var bond_title := title.strip_edges()
	if bond_title == "":
		bond_title = LingpetAffinityState.get_bond_title_for_points(0)
	return "동행 중 · 친밀도 " + bond_title


static func build_panel_snapshot(owner: Object, safe_owner_get: Callable, hatch_required_hits: int) -> Dictionary:
	var lingpet_id: String = str(safe_owner_get.call(owner, "lingpet_id", ""))
	if lingpet_id == "":
		lingpet_id = str(safe_owner_get.call(owner, "active_lingpet_id", ""))
	if lingpet_id == "":
		lingpet_id = str(safe_owner_get.call(owner, "current_lingpet_id", ""))
	var state: String = str(safe_owner_get.call(owner, "lingpet_state", "")).to_lower()
	if state == "":
		state = str(safe_owner_get.call(owner, "ringpet_state", "")).to_lower()
	var hits: int = int(safe_owner_get.call(owner, "lingpet_hatch_hits", safe_owner_get.call(owner, "ringpet_hatch_hits", 0)))
	var required_hits: int = max(1, int(safe_owner_get.call(owner, "lingpet_hatch_required_hits", safe_owner_get.call(owner, "ringpet_hatch_required_hits", hatch_required_hits))))
	if state == "":
		if lingpet_id != "":
			state = "companion"
		elif hits > 0:
			state = "egg"
		else:
			state = "none"
	var display_name: String = _get_display_name(lingpet_id)
	match state:
		"egg", "hatching", "알":
			return {
				"state": "egg",
				"title": "링펫 알",
				"subtitle": "공 충돌 " + CharacterInfoOverlayFormatter.format_int_pair(hits, required_hits),
				"body": "공에 맞을 때마다 금이 가고, 가득 차면 링펫이 깨어납니다.",
				"hatch_hits": hits,
				"required_hits": required_hits,
			}
		"companion", "active", "owned", "동행":
			var owner_active_id := str(safe_owner_get.call(owner, "lingpet_active_skill_id", safe_owner_get.call(owner, "ringpet_active_skill_id", "")))
			var owner_active_level := int(safe_owner_get.call(owner, "lingpet_active_skill_level", safe_owner_get.call(owner, "ringpet_active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL)))
			var catalog_skill := LingpetCatalog.get_active_skill(lingpet_id, owner_active_id, owner_active_level)
			var catalog_skill_enabled := bool(catalog_skill.get("enabled", true))
			var catalog_skill_id := str(catalog_skill.get("id", "")) if catalog_skill_enabled else ""
			var catalog_skill_name := str(catalog_skill.get("name", "")) if catalog_skill_enabled else ""
			var catalog_skill_description := str(catalog_skill.get("description", "")) if catalog_skill_enabled else ""
			var catalog_skill_card_path := str(catalog_skill.get("card_texture_path", "")) if catalog_skill_enabled else ""
			var catalog_skill_icon_path := str(catalog_skill.get("icon_texture_path", "")) if catalog_skill_enabled else ""
			var catalog_skill_cooldown := float(catalog_skill.get("cooldown", 0.0)) if catalog_skill_enabled else 0.0
			var owner_passive_id := str(safe_owner_get.call(owner, "lingpet_passive_skill_id", safe_owner_get.call(owner, "ringpet_passive_skill_id", "")))
			var owner_passive_level := int(safe_owner_get.call(owner, "lingpet_passive_skill_level", safe_owner_get.call(owner, "ringpet_passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL)))
			var catalog_passive := LingpetCatalog.get_passive_skill(lingpet_id, owner_passive_id, owner_passive_level)
			var catalog_passive_enabled := bool(catalog_passive.get("enabled", true))
			var catalog_passive_id := str(catalog_passive.get("id", "")) if catalog_passive_enabled else ""
			var catalog_passive_name := str(catalog_passive.get("name", "")) if catalog_passive_enabled else ""
			var catalog_passive_description := str(catalog_passive.get("description", "")) if catalog_passive_enabled else ""
			var catalog_passive_icon_path := str(catalog_passive.get("icon_texture_path", "")) if catalog_passive_enabled else ""
			var catalog_gauge_bonus := float(catalog_passive.get("gauge_gain_bonus_pct", LingpetCatalog.get_stat(lingpet_id, "gauge_gain_bonus_pct", 0.0))) if catalog_passive_enabled else 0.0
			var catalog_player_speed_bonus := float(catalog_passive.get("player_speed_bonus_pct", 0.0)) if catalog_passive_enabled else 0.0
			var catalog_starpoint_tracking_chance := float(catalog_passive.get("starpoint_tracking_chance_pct", 0.0)) if catalog_passive_enabled else 0.0
			var catalog_ring_dash_chance := float(catalog_passive.get("ring_dash_chance_pct", 0.0)) if catalog_passive_enabled else 0.0
			var affinity_level := int(safe_owner_get.call(owner, "lingpet_affinity_level", safe_owner_get.call(owner, "ringpet_affinity_level", 0)))
			var affinity_points := float(safe_owner_get.call(owner, "lingpet_affinity_points", safe_owner_get.call(owner, "ringpet_affinity_points", 0.0)))
			var affinity_next_requirement := float(safe_owner_get.call(owner, "lingpet_affinity_next_requirement", safe_owner_get.call(owner, "ringpet_affinity_next_requirement", LingpetAffinityState.get_requirement_for_level(affinity_level))))
			var affinity_next_label := str(safe_owner_get.call(owner, "lingpet_affinity_next_label", safe_owner_get.call(owner, "ringpet_affinity_next_label", _default_affinity_next_label(affinity_level))))
			var bond_points := maxi(0, int(safe_owner_get.call(owner, "lingpet_bond_points", safe_owner_get.call(owner, "ringpet_bond_points", 0))))
			var bond_title := str(safe_owner_get.call(owner, "lingpet_bond_title", safe_owner_get.call(owner, "ringpet_bond_title", LingpetAffinityState.get_bond_title_for_points(bond_points))))
			if bond_title.strip_edges() == "":
				bond_title = LingpetAffinityState.get_bond_title_for_points(bond_points)
			return {
				"state": "companion",
				"pet_id": lingpet_id,
				"title": display_name,
				"subtitle": _companion_subtitle_for_bond(bond_title),
				"body": str(safe_owner_get.call(owner, "lingpet_effect_text", "링펫 효과는 다음 단계에서 연결됩니다.")),
				"gauge_gain_bonus_pct": float(safe_owner_get.call(owner, "lingpet_gauge_gain_bonus_pct", safe_owner_get.call(owner, "ringpet_gauge_gain_bonus_pct", catalog_gauge_bonus))),
				"companion_player_speed_bonus_pct": float(safe_owner_get.call(owner, "lingpet_player_speed_bonus_pct", safe_owner_get.call(owner, "ringpet_player_speed_bonus_pct", catalog_player_speed_bonus))),
				"companion_starpoint_tracking_chance_pct": float(safe_owner_get.call(owner, "lingpet_starpoint_tracking_chance_pct", safe_owner_get.call(owner, "ringpet_starpoint_tracking_chance_pct", catalog_starpoint_tracking_chance))),
				"companion_ring_dash_chance_pct": float(safe_owner_get.call(owner, "lingpet_ring_dash_chance_pct", safe_owner_get.call(owner, "ringpet_ring_dash_chance_pct", catalog_ring_dash_chance))),
				"gauge_gain_bonus_icon_path": str(safe_owner_get.call(owner, "lingpet_gauge_gain_bonus_icon_path", catalog_passive_icon_path if catalog_passive_icon_path != "" else LingpetCatalog.get_passive_icon_path(lingpet_id, "gauge_gain_bonus"))),
				"companion_hit_gauge_gain": float(safe_owner_get.call(owner, "lingpet_companion_hit_gauge_gain", safe_owner_get.call(owner, "ringpet_companion_hit_gauge_gain", LingpetCatalog.get_stat(lingpet_id, "hit_gauge_gain", 40.0)))),
				"companion_skill_id": str(safe_owner_get.call(owner, "lingpet_skill_id", safe_owner_get.call(owner, "ringpet_skill_id", catalog_skill_id))),
				"companion_skill_name": str(safe_owner_get.call(owner, "lingpet_skill_name", safe_owner_get.call(owner, "ringpet_skill_name", catalog_skill_name))),
				"companion_skill_description": str(safe_owner_get.call(owner, "lingpet_skill_description", safe_owner_get.call(owner, "ringpet_skill_description", catalog_skill_description))),
				"companion_skill_card_path": str(safe_owner_get.call(owner, "lingpet_skill_card_path", safe_owner_get.call(owner, "ringpet_skill_card_path", catalog_skill_card_path))),
				"companion_skill_icon_path": str(safe_owner_get.call(owner, "lingpet_skill_icon_path", safe_owner_get.call(owner, "ringpet_skill_icon_path", catalog_skill_icon_path))),
				"companion_skill_cooldown_duration": float(safe_owner_get.call(owner, "lingpet_skill_cooldown_duration", safe_owner_get.call(owner, "ringpet_skill_cooldown_duration", catalog_skill_cooldown))),
				"companion_skill_level": int(safe_owner_get.call(owner, "lingpet_active_skill_level", safe_owner_get.call(owner, "ringpet_active_skill_level", int(catalog_skill.get("level", 1))))),
				"companion_skill_max_level": int(safe_owner_get.call(owner, "lingpet_active_skill_max_level", safe_owner_get.call(owner, "ringpet_active_skill_max_level", int(catalog_skill.get("max_level", 5))))),
				"companion_passive_skill_id": str(safe_owner_get.call(owner, "lingpet_passive_skill_id", safe_owner_get.call(owner, "ringpet_passive_skill_id", catalog_passive_id))),
				"companion_passive_skill_name": str(safe_owner_get.call(owner, "lingpet_passive_skill_name", safe_owner_get.call(owner, "ringpet_passive_skill_name", catalog_passive_name))),
				"companion_passive_skill_description": str(safe_owner_get.call(owner, "lingpet_passive_skill_description", safe_owner_get.call(owner, "ringpet_passive_skill_description", catalog_passive_description))),
				"companion_passive_skill_icon_path": str(safe_owner_get.call(owner, "lingpet_passive_skill_icon_path", safe_owner_get.call(owner, "ringpet_passive_skill_icon_path", catalog_passive_icon_path))),
				"companion_passive_skill_level": int(safe_owner_get.call(owner, "lingpet_passive_skill_level", safe_owner_get.call(owner, "ringpet_passive_skill_level", int(catalog_passive.get("level", 1))))),
				"companion_passive_skill_max_level": int(safe_owner_get.call(owner, "lingpet_passive_skill_max_level", safe_owner_get.call(owner, "ringpet_passive_skill_max_level", int(catalog_passive.get("max_level", 5))))),
				"companion_patrol_speed_default": float(safe_owner_get.call(owner, "lingpet_companion_patrol_speed_default", safe_owner_get.call(owner, "ringpet_companion_patrol_speed_default", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_default", 120.0)))),
				"companion_patrol_speed_min": float(safe_owner_get.call(owner, "lingpet_companion_patrol_speed_min", safe_owner_get.call(owner, "ringpet_companion_patrol_speed_min", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_min", 70.0)))),
				"companion_patrol_speed_max": float(safe_owner_get.call(owner, "lingpet_companion_patrol_speed_max", safe_owner_get.call(owner, "ringpet_companion_patrol_speed_max", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_max", 135.0)))),
				"companion_catch_width": float(safe_owner_get.call(owner, "lingpet_companion_catch_width", safe_owner_get.call(owner, "ringpet_companion_catch_width", LingpetCatalog.get_stat(lingpet_id, "catch_width", 100.0)))),
				"companion_catch_height": float(safe_owner_get.call(owner, "lingpet_companion_catch_height", safe_owner_get.call(owner, "ringpet_companion_catch_height", LingpetCatalog.get_stat(lingpet_id, "catch_height", 44.0)))),
				"companion_defense_rate": float(safe_owner_get.call(owner, "lingpet_companion_defense_rate", safe_owner_get.call(owner, "ringpet_companion_defense_rate", LingpetCatalog.get_stat(lingpet_id, "defense_rate", 0.0)))),
				"companion_appearance_rate": float(safe_owner_get.call(owner, "lingpet_companion_appearance_rate", safe_owner_get.call(owner, "ringpet_companion_appearance_rate", LingpetCatalog.get_stat(lingpet_id, "appearance_rate", 0.0)))),
				"affinity_level": affinity_level,
				"affinity_points": affinity_points,
				"affinity_next_requirement": affinity_next_requirement,
				"affinity_next_label": affinity_next_label,
				"bond_points": bond_points,
				"bond_title": bond_title,
				"hatch_hits": required_hits,
				"required_hits": required_hits,
			}
		_:
			return {
				"state": "none",
				"title": "링펫 알 없음",
				"subtitle": "미획득",
				"body": "주니어리그에서 미카로 플레이하면 첫 링펫 알이 나타납니다.",
				"hatch_hits": 0,
				"required_hits": required_hits,
			}
