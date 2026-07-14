extends RefCounted
## Player hostile-hit immunity gates. Two SEPARATE concepts — do not merge:
##
## 1) `is_cleanse_immune()` — Smasher cleanse is a FULL CC immunity window.
##    Callers gate the WHOLE hostile hit on it (skip stun + burn + knockback),
##    exactly like the stage6 tetro `_is_player_status_immune` pattern. Cleanse
##    does not retroactively clear, so it must be checked BEFORE any effect is
##    applied.
##
## 2) 부동갑주(celestial_armor) — rolls chance, spends gauge; the item contract
##    is "스턴·넉백 무시" (stun AND knockback are blockable; burn and the
##    paddle-hit "recoil" effect type are never eligible). Pick the gate by the
##    HIT SHAPE, and use exactly ONE armor gate per hit:
##    - Stun-bearing hit (stun ± knockback): gate the WHOLE hit on
##      `try_block_player_stun()` — one roll; on proc the stun AND its
##      accompanying knockback are both skipped (stage6 tetro precedent).
##      A partial block ("wave played but I still got stunned") reads as a
##      bug, so never gate only the knockback of a hit that also stuns.
##    - Knockback-only hit: gate just the knockback on
##      `try_block_player_knockback()`. Accompanying burn stays (burn is not
##      in the item contract).
##
## Standard wiring for a stun+knockback hostile hit:
##   if PlayerKnockbackImmunity.is_cleanse_immune(deps, context):
##       return                                   # cleanse = whole hit skipped
##   if PlayerKnockbackImmunity.try_block_player_stun(deps, context, src):
##       return                                   # armor proc = whole hit skipped
##   apply stun ... ; movement_state.start_knockback(...)
##
## Standard wiring for a knockback-only hostile hit:
##   if is_cleanse_immune(...) or try_block_player_knockback(...):
##       ... skip knockback (apply burn first if any) ...

const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")


static func is_cleanse_immune(deps: Dictionary, context: Dictionary = {}) -> bool:
	var cleanse_state: Object = _resolve_cleanse_state(deps, context)
	return (
		cleanse_state != null
		and cleanse_state.has_method("is_immune")
		and bool(cleanse_state.is_immune())
	)


static func try_block_player_knockback(
	deps: Dictionary,
	context: Dictionary,
	source: String
) -> bool:
	# ARMOR only, knockback-ONLY hits. Cleanse is a separate whole-hit gate
	# (see is_cleanse_immune); stun-bearing hits use try_block_player_stun.
	return _try_consume_armor_immunity(deps, context, source, "knockback")


static func try_block_player_stun(
	deps: Dictionary,
	context: Dictionary,
	source: String
) -> bool:
	# ARMOR whole-hit gate for stun-bearing hits: one roll; a proc means the
	# caller skips the stun AND its accompanying knockback together.
	return _try_consume_armor_immunity(deps, context, source, "stun")


static func _try_consume_armor_immunity(
	deps: Dictionary,
	context: Dictionary,
	source: String,
	effect_type: String
) -> bool:
	var mythic_item_runtime: Object = StarpointBonusDropPolicy.get_mythic_item_runtime(deps, context)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		return false
	var status_deps: Dictionary = deps.duplicate()
	status_deps["context"] = context
	var owner: Object = _resolve_owner(deps, context)
	if owner != null:
		status_deps["owner"] = owner
	return bool(mythic_item_runtime.try_consume_celestial_armor_immunity(source, effect_type, status_deps))


static func _resolve_cleanse_state(deps: Dictionary, context: Dictionary) -> Object:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null:
		return cleanse_state
	var registry: Object = context.get("registry", deps.get("registry", null))
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("smasher_cleanse_state")
	return null


static func _resolve_owner(deps: Dictionary, context: Dictionary) -> Object:
	if deps.get("owner", null) is Object:
		return deps.get("owner", null)
	if context.get("owner", null) is Object:
		return context.get("owner", null)
	return null
