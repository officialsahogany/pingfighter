extends RefCounted

const TARGET_PLAYER := "player"
const TARGET_BOSS := "boss"
const STATUS_SLOW := "slow"
const STATUS_STUN := "stun"
const STATUS_CONFUSION := "confusion"
const STATUS_REVERSE := "reverse"
const STATUS_BURN := "burn"

const BOSS_STUN_FRAME_MSEC := 100.0

const _TARGET_ALIASES := {
	"player": TARGET_PLAYER,
	"paddle": TARGET_PLAYER,
	"boss": TARGET_BOSS,
	"enemy": TARGET_BOSS,
}

const _STATUS_ALIASES := {
	"burn": STATUS_BURN,
	"burning": STATUS_BURN,
	"fire": STATUS_BURN,
	"slow": STATUS_SLOW,
	"snare": STATUS_SLOW,
	"둔화": STATUS_SLOW,
	"stun": STATUS_STUN,
	"스턴": STATUS_STUN,
	"confusion": STATUS_CONFUSION,
	"confuse": STATUS_CONFUSION,
	"혼란": STATUS_CONFUSION,
	"reverse": STATUS_REVERSE,
	"invert": STATUS_REVERSE,
	"반전": STATUS_REVERSE,
}

var _status_sources: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_status_sources = {
		TARGET_PLAYER: {},
		TARGET_BOSS: {},
	}


func reset_round() -> void:
	reset()


func update(fps_scale: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	_clear_stage2_boss_disable_statuses(context, deps)
	var step: float = max(0.0, fps_scale)
	for target in _status_sources.keys():
		var target_statuses: Dictionary = _get_target_statuses(str(target))
		for status_id in target_statuses.keys():
			var sources: Dictionary = _get_status_source_map(str(target), str(status_id))
			for source_key in sources.keys():
				var entry: Dictionary = _as_dictionary(sources.get(source_key, {}))
				if bool(entry.get("persistent", false)):
					sources[source_key] = entry
					continue
				var remaining: float = max(0.0, float(entry.get("remaining_frames", 0.0)) - step)
				if remaining <= 0.0:
					sources.erase(source_key)
				else:
					entry["remaining_frames"] = remaining
					_update_entry_knockback(entry, step)
					sources[source_key] = entry
			if sources.is_empty():
				target_statuses.erase(status_id)


func needs_effect_update() -> bool:
	return has_any_status()


func has_any_status() -> bool:
	for target in _status_sources.keys():
		var target_statuses: Dictionary = _get_target_statuses(str(target))
		for status_id in target_statuses.keys():
			if not _get_status_source_map(str(target), str(status_id)).is_empty():
				return true
	return false


func apply_status(
	target: String,
	status_id: String,
	duration_frames: float,
	data: Dictionary = {},
	source: String = ""
) -> Dictionary:
	var normalized_target: String = _normalize_target(target)
	var normalized_status: String = _normalize_status_id(status_id)
	if normalized_target == "" or normalized_status == "":
		return {}

	var duration: float = max(0.0, duration_frames)
	var persistent: bool = bool(data.get("persistent", false))
	if duration <= 0.0 and not persistent:
		return {}

	var source_key: String = _normalize_source(source, data)
	var target_statuses: Dictionary = _get_target_statuses(normalized_target)
	if not target_statuses.has(normalized_status):
		target_statuses[normalized_status] = {}
	var sources: Dictionary = _get_status_source_map(normalized_target, normalized_status)
	var previous: Dictionary = _as_dictionary(sources.get(source_key, {}))
	var next_entry: Dictionary = _build_entry(normalized_status, duration, data, source_key, previous)
	sources[source_key] = next_entry
	target_statuses[normalized_status] = sources
	return get_status(normalized_target, normalized_status)


func clear_status(target: String, status_id: String = "", source: String = "") -> void:
	var normalized_target: String = _normalize_target(target)
	if normalized_target == "":
		return
	var target_statuses: Dictionary = _get_target_statuses(normalized_target)
	if status_id == "":
		target_statuses.clear()
		return
	var normalized_status: String = _normalize_status_id(status_id)
	if normalized_status == "" or not target_statuses.has(normalized_status):
		return
	if source == "":
		target_statuses.erase(normalized_status)
		return
	var sources: Dictionary = _get_status_source_map(normalized_target, normalized_status)
	sources.erase(source)
	if sources.is_empty():
		target_statuses.erase(normalized_status)


func clear_cleansable_status_effects(target: String = TARGET_PLAYER) -> void:
	var normalized_target: String = _normalize_target(target)
	if normalized_target == "":
		return
	var target_statuses: Dictionary = _get_target_statuses(normalized_target)
	for status_id in target_statuses.keys():
		var sources: Dictionary = _get_status_source_map(normalized_target, str(status_id))
		for source_key in sources.keys():
			var entry: Dictionary = _as_dictionary(sources.get(source_key, {}))
			if bool(entry.get("cleansable", true)):
				sources.erase(source_key)
		if sources.is_empty():
			target_statuses.erase(status_id)


func clear_player_status_effects() -> void:
	clear_cleansable_status_effects(TARGET_PLAYER)


func has_status(target: String, status_id: String) -> bool:
	return not get_status(target, status_id).is_empty()


func has_status_effect(target: String = TARGET_PLAYER, cleansable_only: bool = true) -> bool:
	var normalized_target: String = _normalize_target(target)
	if normalized_target == "":
		return false
	var target_statuses: Dictionary = _get_target_statuses(normalized_target)
	for status_id in target_statuses.keys():
		var sources: Dictionary = _get_status_source_map(normalized_target, str(status_id))
		for entry_value in sources.values():
			var entry: Dictionary = _as_dictionary(entry_value)
			if not cleansable_only or bool(entry.get("cleansable", true)):
				return true
	return false


func get_status(target: String, status_id: String) -> Dictionary:
	var normalized_target: String = _normalize_target(target)
	var normalized_status: String = _normalize_status_id(status_id)
	if normalized_target == "" or normalized_status == "":
		return {}
	var sources: Dictionary = _get_status_source_map(normalized_target, normalized_status)
	if sources.is_empty():
		return {}
	if normalized_status == STATUS_SLOW:
		return _combine_slow_status(normalized_target, sources)
	return _combine_duration_status(normalized_target, normalized_status, sources)


func get_status_source(target: String, status_id: String, source: String) -> Dictionary:
	var normalized_target: String = _normalize_target(target)
	var normalized_status: String = _normalize_status_id(status_id)
	if normalized_target == "" or normalized_status == "":
		return {}
	var sources: Dictionary = _get_status_source_map(normalized_target, normalized_status)
	var entry: Dictionary = _as_dictionary(sources.get(_normalize_source(source, {}), {}))
	return entry.duplicate(true)


func get_snapshot() -> Dictionary:
	var snapshot := {
		"player_status_effect_active": has_status_effect(TARGET_PLAYER, true),
		"boss_status_effect_active": has_status_effect(TARGET_BOSS, false),
	}
	snapshot.merge(get_actor_draw_context(), true)
	snapshot.merge(get_boss_ai_context(), true)
	return snapshot


func get_actor_draw_context() -> Dictionary:
	var context := {}
	var boss_stun: Dictionary = get_status(TARGET_BOSS, STATUS_STUN)
	if not boss_stun.is_empty():
		context["status_boss_stun_active"] = true
		context["status_boss_stun_ratio"] = float(boss_stun.get("ratio", 1.0))
		context["active_item_boss_stun_active"] = true
		context["active_item_boss_stun_frame"] = _get_boss_stun_frame()
		if bool(boss_stun.get("suppress_stun_stars", false)):
			context["active_item_boss_stun_stars_suppressed"] = true
		if bool(boss_stun.get("electric_stun", false)):
			context["boss_electric_stun_active"] = true

	var boss_confusion: Dictionary = get_status(TARGET_BOSS, STATUS_CONFUSION)
	if not boss_confusion.is_empty():
		context["status_boss_confusion_active"] = true
		context["status_boss_confusion_ratio"] = float(boss_confusion.get("ratio", 1.0))
		context["active_item_boss_confusion_active"] = true

	var boss_slow: Dictionary = get_status(TARGET_BOSS, STATUS_SLOW)
	if not boss_slow.is_empty():
		context["status_boss_slow_active"] = true
		context["status_boss_slow_ratio"] = float(boss_slow.get("ratio", 1.0))
		context["status_boss_slow_multiplier"] = float(boss_slow.get("multiplier", 1.0))
		context["active_item_boss_spider_slow_active"] = true
		context["active_item_boss_spider_slow_ratio"] = float(boss_slow.get("ratio", 1.0))

	var player_slow: Dictionary = get_status(TARGET_PLAYER, STATUS_SLOW)
	if not player_slow.is_empty():
		context["status_player_slow_active"] = true
		context["status_player_slow_ratio"] = float(player_slow.get("ratio", 1.0))
		context["status_player_slow_multiplier"] = float(player_slow.get("multiplier", 1.0))

	var player_reverse: Dictionary = get_status(TARGET_PLAYER, STATUS_REVERSE)
	if not player_reverse.is_empty():
		context["status_player_reverse_active"] = true
		context["status_player_reverse_ratio"] = float(player_reverse.get("ratio", 1.0))
		context["stage3_curse_reverse_active"] = true
		context["stage3_curse_reverse_ratio"] = float(player_reverse.get("ratio", 1.0))

	var player_burn: Dictionary = get_status(TARGET_PLAYER, STATUS_BURN)
	if not player_burn.is_empty():
		context["status_player_burn_active"] = true
		context["status_player_burn_ratio"] = float(player_burn.get("ratio", 1.0))
		context["stage4_player_burn_active"] = true
		context["stage4_player_burn_ratio"] = float(player_burn.get("ratio", 1.0))

	var player_stun: Dictionary = get_status(TARGET_PLAYER, STATUS_STUN)
	if not player_stun.is_empty():
		context["status_player_stun_active"] = true
		context["status_player_stun_ratio"] = float(player_stun.get("ratio", 1.0))

	var player_confusion: Dictionary = get_status(TARGET_PLAYER, STATUS_CONFUSION)
	if not player_confusion.is_empty():
		context["status_player_confusion_active"] = true
		context["status_player_confusion_ratio"] = float(player_confusion.get("ratio", 1.0))

	return context


func get_boss_ai_context() -> Dictionary:
	var context := {}
	var boss_stun: Dictionary = get_status(TARGET_BOSS, STATUS_STUN)
	if not boss_stun.is_empty():
		var knockback_vel: float = float(boss_stun.get("knockback_vel", 0.0))
		var knockback_active: bool = bool(boss_stun.get("knockback_active", abs(knockback_vel) > 0.001))
		if not knockback_active:
			knockback_vel = 0.0
		context["status_boss_stun_active"] = true
		context["active_item_grenade_stun_active"] = true
		context["active_item_grenade_knockback_vel"] = knockback_vel
		context["active_item_grenade_knockback_active"] = knockback_active

	var boss_confusion: Dictionary = get_status(TARGET_BOSS, STATUS_CONFUSION)
	if not boss_confusion.is_empty():
		context["status_boss_confusion_active"] = true
		context["active_item_flare_confusion_active"] = true

	var boss_slow: Dictionary = get_status(TARGET_BOSS, STATUS_SLOW)
	if not boss_slow.is_empty():
		var multiplier: float = float(boss_slow.get("multiplier", 1.0))
		context["status_boss_slow_active"] = true
		context["status_boss_slow_multiplier"] = multiplier
		if not bool(boss_slow.get("suppress_legacy_boss_ai_slow", false)):
			context["active_item_spider_mine_slow_active"] = true
			context["active_item_spider_mine_slow_factor"] = multiplier

	return context


func get_player_control_context() -> Dictionary:
	var player_reverse: Dictionary = get_status(TARGET_PLAYER, STATUS_REVERSE)
	return {
		"player_reverse_active": not player_reverse.is_empty(),
		"player_reverse_ratio": float(player_reverse.get("ratio", 0.0)),
	}


func get_player_speed_multiplier() -> float:
	var player_slow: Dictionary = get_status(TARGET_PLAYER, STATUS_SLOW)
	if player_slow.is_empty():
		return 1.0
	return clamp(float(player_slow.get("multiplier", 1.0)), 0.0, 1.0)


func is_player_reverse_active() -> bool:
	return has_status(TARGET_PLAYER, STATUS_REVERSE)


func is_curse_reverse_active() -> bool:
	return is_player_reverse_active()


func _build_entry(
	status_id: String,
	duration_frames: float,
	data: Dictionary,
	source_key: String,
	previous: Dictionary
) -> Dictionary:
	var remaining: float = max(float(previous.get("remaining_frames", 0.0)), duration_frames)
	var total: float = max(duration_frames, float(previous.get("total_frames", duration_frames)))
	var entry: Dictionary = data.duplicate(true)
	entry["status_id"] = status_id
	entry["source"] = source_key
	entry["remaining_frames"] = remaining
	entry["total_frames"] = max(0.001, total)
	entry["cleansable"] = bool(data.get("cleansable", previous.get("cleansable", true)))
	if status_id == STATUS_SLOW:
		entry["multiplier"] = clamp(float(data.get("multiplier", previous.get("multiplier", 1.0))), 0.0, 1.0)
	if entry.has("knockback_frames"):
		var knockback_frames: float = max(0.0, float(entry.get("knockback_frames", 0.0)))
		entry["knockback_frames"] = knockback_frames
		entry["knockback_remaining_frames"] = max(knockback_frames, float(previous.get("knockback_remaining_frames", 0.0)))
		entry["knockback_active"] = bool(entry.get("knockback_active", abs(float(entry.get("knockback_vel", 0.0))) > 0.001))
	return entry


func _combine_duration_status(target: String, status_id: String, sources: Dictionary) -> Dictionary:
	var best := {}
	for source_key in sources.keys():
		var entry: Dictionary = _as_dictionary(sources.get(source_key, {}))
		var remaining: float = float(entry.get("remaining_frames", 0.0))
		if remaining <= 0.0 and not bool(entry.get("persistent", false)):
			continue
		if best.is_empty() or remaining > float(best.get("remaining_frames", 0.0)):
			best = entry.duplicate(true)
	if best.is_empty():
		return {}
	best["target"] = target
	best["status_id"] = status_id
	best["ratio"] = _get_entry_ratio(best)
	best["sources"] = sources.keys()
	return best


func _combine_slow_status(target: String, sources: Dictionary) -> Dictionary:
	var best := {}
	for source_key in sources.keys():
		var entry: Dictionary = _as_dictionary(sources.get(source_key, {}))
		var remaining: float = float(entry.get("remaining_frames", 0.0))
		if remaining <= 0.0 and not bool(entry.get("persistent", false)):
			continue
		var multiplier: float = clamp(float(entry.get("multiplier", 1.0)), 0.0, 1.0)
		var current_multiplier: float = clamp(float(best.get("multiplier", 1.0)), 0.0, 1.0)
		if best.is_empty() or multiplier < current_multiplier or (
			is_equal_approx(multiplier, current_multiplier)
			and remaining > float(best.get("remaining_frames", 0.0))
		):
			best = entry.duplicate(true)
	if best.is_empty():
		return {}
	best["target"] = target
	best["status_id"] = STATUS_SLOW
	best["ratio"] = _get_entry_ratio(best)
	best["sources"] = sources.keys()
	return best


func _update_entry_knockback(entry: Dictionary, step: float) -> void:
	if not entry.has("knockback_vel"):
		return
	if entry.has("knockback_frames"):
		var remaining: float = max(0.0, float(entry.get("knockback_remaining_frames", entry.get("knockback_frames", 0.0))) - step)
		entry["knockback_remaining_frames"] = remaining
		if remaining <= 0.0:
			entry["knockback_vel"] = 0.0
			entry["knockback_active"] = false
			return
	var decay: float = clamp(float(entry.get("knockback_decay_per_frame", 1.0)), 0.0, 1.0)
	if decay < 1.0 and bool(entry.get("knockback_active", abs(float(entry.get("knockback_vel", 0.0))) > 0.001)):
		var next_vel: float = float(entry.get("knockback_vel", 0.0)) * pow(decay, step)
		if abs(next_vel) <= float(entry.get("knockback_stop_threshold", 0.3)):
			entry["knockback_vel"] = 0.0
			entry["knockback_active"] = false
		else:
			entry["knockback_vel"] = next_vel


func _clear_stage2_boss_disable_statuses(context: Dictionary, deps: Dictionary) -> void:
	if not _is_stage2_speed_defense_status_immune(context, deps):
		return
	clear_status(TARGET_BOSS, STATUS_STUN)
	clear_status(TARGET_BOSS, STATUS_CONFUSION)


func _is_stage2_speed_defense_status_immune(context: Dictionary, deps: Dictionary) -> bool:
	if int(context.get("current_stage", deps.get("current_stage", 0))) != 2:
		return false
	if bool(context.get("stage2_speed_defense_status_immunity_active", false)) or bool(context.get("stage2_speed_defense_active", false)):
		return true
	var stage2_state: Object = deps.get("stage2_boss_skill_state", null)
	return stage2_state != null and stage2_state.has_method("is_boss_status_immune") and bool(stage2_state.is_boss_status_immune())


func _get_entry_ratio(entry: Dictionary) -> float:
	if bool(entry.get("persistent", false)):
		return clamp(float(entry.get("ratio", 1.0)), 0.0, 1.0)
	return clamp(float(entry.get("remaining_frames", 0.0)) / max(0.001, float(entry.get("total_frames", 1.0))), 0.0, 1.0)


func _get_boss_stun_frame() -> int:
	return int(floor(float(Time.get_ticks_msec()) / BOSS_STUN_FRAME_MSEC)) % 8


func _get_target_statuses(target: String) -> Dictionary:
	if not _status_sources.has(target):
		_status_sources[target] = {}
	return _status_sources[target]


func _get_status_source_map(target: String, status_id: String) -> Dictionary:
	var target_statuses: Dictionary = _get_target_statuses(target)
	if not target_statuses.has(status_id):
		return {}
	var value: Variant = target_statuses.get(status_id, {})
	if value is Dictionary:
		return value
	return {}


func _normalize_target(target: String) -> String:
	var key: String = str(target).strip_edges().to_lower()
	return str(_TARGET_ALIASES.get(key, ""))


func _normalize_status_id(status_id: String) -> String:
	var key: String = str(status_id).strip_edges().to_lower()
	return str(_STATUS_ALIASES.get(key, ""))


func _normalize_source(source: String, data: Dictionary) -> String:
	var source_key: String = source.strip_edges()
	if source_key == "":
		source_key = str(data.get("source", "")).strip_edges()
	if source_key == "":
		source_key = "default"
	return source_key


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
