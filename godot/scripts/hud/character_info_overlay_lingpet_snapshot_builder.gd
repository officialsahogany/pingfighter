extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

static func _get_display_name(lingpet_id: String) -> String:
	if LingpetCatalog.has_pet(lingpet_id):
		return LingpetCatalog.get_display_name(lingpet_id)
	match lingpet_id:
		"maribo":
			return "마리보"
		"":
			return "수호령"
		_:
			return lingpet_id


# Up to 3 acquired-lingpet tabs in acquisition (battle-slot) order for the
# character-info panel header. Reads the owner-mirrored battle slots
# (lingpet_collection_state._sync_owner_slots), with the lingpet_*/ringpet_*
# pair fallback used throughout this builder. The active flag resolves like
# lingpet_collection_state.get_active_slot_index_from_owner: an explicit synced
# index wins; otherwise match the active companion pet_id; otherwise the first
# occupied slot (never force slot 0 on the -1 "not synced" sentinel).
static func _build_slot_tabs(owner: Object, safe_owner_get: Callable, active_pet_id: String) -> Array:
	var slots_value: Variant = safe_owner_get.call(owner, "lingpet_slots", [])
	if not (slots_value is Array) or (slots_value as Array).is_empty():
		slots_value = safe_owner_get.call(owner, "ringpet_slots", [])
	var slots: Array = slots_value if slots_value is Array else []
	var active_index: int = int(safe_owner_get.call(owner, "lingpet_active_slot_index", -1))
	if active_index < 0:
		active_index = int(safe_owner_get.call(owner, "ringpet_active_slot_index", -1))
	var normalized_active: String = active_pet_id.strip_edges().to_lower()
	var occupied: Array = []
	var first_occupied: int = -1
	for i in range(slots.size()):
		var pet_id: String = str(slots[i]).strip_edges().to_lower()
		if pet_id == "":
			continue
		if first_occupied < 0:
			first_occupied = i
		occupied.append({"slot_index": i, "pet_id": pet_id})
	if occupied.is_empty():
		# Slots not synced yet but a companion is on field — show a single tab so
		# the header never reads zero tabs while a lingpet accompanies the player.
		var empty_slot_tabs: Array = []
		if normalized_active != "":
			empty_slot_tabs.append({
				"slot_index": 0,
				"pet_id": normalized_active,
				"name": _get_display_name(normalized_active),
				"active": true,
			})
		_append_sealed_tabs(empty_slot_tabs, owner, safe_owner_get)
		return empty_slot_tabs
	var resolved_active: int = -1
	if active_index >= 0:
		resolved_active = active_index
	elif normalized_active != "":
		for entry in occupied:
			if str(entry.get("pet_id", "")) == normalized_active:
				resolved_active = int(entry.get("slot_index", -1))
				break
	if resolved_active < 0:
		resolved_active = first_occupied
	var tabs: Array = []
	for entry in occupied:
		var pet_id: String = str(entry.get("pet_id", ""))
		tabs.append({
			"slot_index": int(entry.get("slot_index", -1)),
			"pet_id": pet_id,
			"name": _get_display_name(pet_id),
			"active": int(entry.get("slot_index", -1)) == resolved_active,
		})
	_append_sealed_tabs(tabs, owner, safe_owner_get)
	return tabs


static func _append_sealed_tabs(tabs: Array, owner: Object, safe_owner_get: Callable) -> void:
	var sealed_value: Variant = safe_owner_get.call(owner, "tower_ascent_sealed_guardians", [])
	if not (sealed_value is Array):
		return
	for raw_entry in (sealed_value as Array):
		if not (raw_entry is Dictionary):
			continue
		var sealed := raw_entry as Dictionary
		var pet_id := str(sealed.get("pet_id", "")).strip_edges().to_lower()
		if pet_id.is_empty():
			continue
		var display_name := str(sealed.get("display_name", _get_display_name(pet_id)))
		tabs.append({
			"slot_index": -1,
			"pet_id": pet_id,
			"name": "봉인 %s" % display_name,
			"active": false,
			"sealed": true,
		})


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
	var slot_tabs: Array = _build_slot_tabs(owner, safe_owner_get, lingpet_id)
	match state:
		"egg", "hatching", "알":
			return {
				"state": "egg",
				"slot_tabs": slot_tabs,
				"title": "수호령 알",
				"subtitle": LanguageSettings.translate_text("공 충돌 %s") % CharacterInfoOverlayFormatter.format_int_pair(hits, required_hits),
				"body": "공에 맞을 때마다 금이 가고, 가득 차면 수호령이 깨어납니다.",
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
			var owner_second_active_id := str(safe_owner_get.call(owner, "lingpet_second_skill_id", safe_owner_get.call(owner, "ringpet_second_skill_id", ""))).strip_edges()
			var owner_second_active_level := int(safe_owner_get.call(owner, "lingpet_second_active_skill_level", safe_owner_get.call(owner, "ringpet_second_active_skill_level", 0)))
			var catalog_second_skill := LingpetCatalog.get_active_skill(lingpet_id, owner_second_active_id, owner_second_active_level) if owner_second_active_id != "" else {}
			var catalog_second_skill_enabled := owner_second_active_id != "" and bool(catalog_second_skill.get("enabled", true))
			var catalog_second_skill_id := str(catalog_second_skill.get("id", "")) if catalog_second_skill_enabled else ""
			var catalog_second_skill_name := str(catalog_second_skill.get("name", "")) if catalog_second_skill_enabled else ""
			var catalog_second_skill_description := str(catalog_second_skill.get("description", "")) if catalog_second_skill_enabled else ""
			var catalog_second_skill_card_path := str(catalog_second_skill.get("card_texture_path", "")) if catalog_second_skill_enabled else ""
			var catalog_second_skill_icon_path := str(catalog_second_skill.get("icon_texture_path", "")) if catalog_second_skill_enabled else ""
			var catalog_second_skill_cooldown := float(catalog_second_skill.get("cooldown", 0.0)) if catalog_second_skill_enabled else 0.0
			var owner_second_skill_name := str(safe_owner_get.call(owner, "lingpet_second_skill_name", safe_owner_get.call(owner, "ringpet_second_skill_name", ""))).strip_edges()
			var owner_second_skill_cooldown := float(safe_owner_get.call(owner, "lingpet_second_skill_cooldown_duration", safe_owner_get.call(owner, "ringpet_second_skill_cooldown_duration", 0.0)))
			var owner_second_skill_max_level := int(safe_owner_get.call(owner, "lingpet_second_skill_max_level", safe_owner_get.call(owner, "ringpet_second_skill_max_level", 0)))
			var panel_second_skill_name := ""
			var panel_second_skill_cooldown := 0.0
			var panel_second_skill_max_level := 0
			if catalog_second_skill_id != "":
				panel_second_skill_name = owner_second_skill_name if owner_second_skill_name != "" else catalog_second_skill_name
				panel_second_skill_cooldown = owner_second_skill_cooldown if owner_second_skill_cooldown > 0.0 else catalog_second_skill_cooldown
				panel_second_skill_max_level = owner_second_skill_max_level if owner_second_skill_max_level > 0 else int(catalog_second_skill.get("max_level", 5))
			var owner_second_passive_id := str(safe_owner_get.call(owner, "lingpet_second_passive_skill_id", safe_owner_get.call(owner, "ringpet_second_passive_skill_id", ""))).strip_edges()
			var owner_second_passive_level := int(safe_owner_get.call(owner, "lingpet_second_passive_skill_level", safe_owner_get.call(owner, "ringpet_second_passive_skill_level", 0)))
			var catalog_second_passive := LingpetCatalog.get_passive_skill(lingpet_id, owner_second_passive_id, owner_second_passive_level) if owner_second_passive_id != "" else {}
			var catalog_second_passive_raw_id := str(catalog_second_passive.get("id", "")).strip_edges()
			var catalog_second_passive_enabled := owner_second_passive_id != "" and catalog_second_passive_raw_id == owner_second_passive_id and bool(catalog_second_passive.get("enabled", true))
			var catalog_second_passive_id := catalog_second_passive_raw_id if catalog_second_passive_enabled else ""
			var catalog_second_passive_name := str(catalog_second_passive.get("name", "")) if catalog_second_passive_enabled else ""
			var catalog_second_passive_description := str(catalog_second_passive.get("description", "")) if catalog_second_passive_enabled else ""
			var catalog_second_passive_icon_path := str(catalog_second_passive.get("icon_texture_path", "")) if catalog_second_passive_enabled else ""
			return {
				"state": "companion",
				"slot_tabs": slot_tabs,
				"pet_id": lingpet_id,
				"title": display_name,
				"subtitle": LanguageSettings.translate_text("동행 중"),
				"body": str(safe_owner_get.call(owner, "lingpet_effect_text", "수호령 효과는 다음 단계에서 연결됩니다.")),
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
				"companion_skill_id_1": catalog_second_skill_id,
				"companion_skill_name_1": panel_second_skill_name,
				"companion_skill_description_1": catalog_second_skill_description,
				"companion_skill_card_path_1": catalog_second_skill_card_path,
				"companion_skill_icon_path_1": catalog_second_skill_icon_path,
				"companion_skill_cooldown_duration_1": panel_second_skill_cooldown,
				"companion_skill_level_1": owner_second_active_level if catalog_second_skill_id != "" else 0,
				"companion_skill_max_level_1": panel_second_skill_max_level,
				"companion_passive_skill_id": str(safe_owner_get.call(owner, "lingpet_passive_skill_id", safe_owner_get.call(owner, "ringpet_passive_skill_id", catalog_passive_id))),
				"companion_passive_skill_name": str(safe_owner_get.call(owner, "lingpet_passive_skill_name", safe_owner_get.call(owner, "ringpet_passive_skill_name", catalog_passive_name))),
				"companion_passive_skill_description": str(safe_owner_get.call(owner, "lingpet_passive_skill_description", safe_owner_get.call(owner, "ringpet_passive_skill_description", catalog_passive_description))),
				"companion_passive_skill_icon_path": str(safe_owner_get.call(owner, "lingpet_passive_skill_icon_path", safe_owner_get.call(owner, "ringpet_passive_skill_icon_path", catalog_passive_icon_path))),
				"companion_passive_skill_level": int(safe_owner_get.call(owner, "lingpet_passive_skill_level", safe_owner_get.call(owner, "ringpet_passive_skill_level", int(catalog_passive.get("level", 1))))),
				"companion_passive_skill_max_level": int(safe_owner_get.call(owner, "lingpet_passive_skill_max_level", safe_owner_get.call(owner, "ringpet_passive_skill_max_level", int(catalog_passive.get("max_level", 5))))),
				"companion_passive_skill_id_1": catalog_second_passive_id,
				"companion_passive_skill_name_1": catalog_second_passive_name,
				"companion_passive_skill_description_1": catalog_second_passive_description,
				"companion_passive_skill_icon_path_1": catalog_second_passive_icon_path,
				"companion_passive_skill_level_1": owner_second_passive_level if catalog_second_passive_id != "" else 0,
				"companion_passive_skill_max_level_1": int(catalog_second_passive.get("max_level", 5)) if catalog_second_passive_id != "" else 0,
				"companion_patrol_speed_default": float(safe_owner_get.call(owner, "lingpet_companion_patrol_speed_default", safe_owner_get.call(owner, "ringpet_companion_patrol_speed_default", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_default", 120.0)))),
				"companion_patrol_speed_min": float(safe_owner_get.call(owner, "lingpet_companion_patrol_speed_min", safe_owner_get.call(owner, "ringpet_companion_patrol_speed_min", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_min", 70.0)))),
				"companion_patrol_speed_max": float(safe_owner_get.call(owner, "lingpet_companion_patrol_speed_max", safe_owner_get.call(owner, "ringpet_companion_patrol_speed_max", LingpetCatalog.get_stat(lingpet_id, "patrol_speed_max", 135.0)))),
				"companion_catch_width": float(safe_owner_get.call(owner, "lingpet_companion_catch_width", safe_owner_get.call(owner, "ringpet_companion_catch_width", LingpetCatalog.get_stat(lingpet_id, "catch_width", 100.0)))),
				"companion_catch_height": float(safe_owner_get.call(owner, "lingpet_companion_catch_height", safe_owner_get.call(owner, "ringpet_companion_catch_height", LingpetCatalog.get_stat(lingpet_id, "catch_height", 44.0)))),
				"companion_defense_rate": float(safe_owner_get.call(owner, "lingpet_companion_defense_rate", safe_owner_get.call(owner, "ringpet_companion_defense_rate", LingpetCatalog.get_stat(lingpet_id, "defense_rate", 0.0)))),
				"companion_appearance_rate": float(safe_owner_get.call(owner, "lingpet_companion_appearance_rate", safe_owner_get.call(owner, "ringpet_companion_appearance_rate", LingpetCatalog.get_stat(lingpet_id, "appearance_rate", 0.0)))),
				"hatch_hits": required_hits,
				"required_hits": required_hits,
			}
		_:
			return {
				"state": "none",
				"slot_tabs": slot_tabs,
				"title": "수호령 알 없음",
				"subtitle": "미획득",
				"body": "수련 난이도에서 한미량으로 플레이하면 첫 수호령 알이 나타납니다.",
				"hatch_hits": 0,
				"required_hits": required_hits,
			}
