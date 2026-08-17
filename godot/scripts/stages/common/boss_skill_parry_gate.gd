extends RefCounted

# 파열광은 "결계(플레이어) -> 쳐낸 스킬"로 뻗어야 읽힌다. 호출부 대부분은
# 명시 위치를 넘기지 않으므로(현재 15곳 중 14곳), 폴백을 플레이어 중심으로
# 잡으면 시작점과 끝점이 같아져 선 길이 0 + 파열 링이 결계 한가운데 겹친다.
# 폴백 원점은 스킬을 낸 주체인 보스 패들 중심이다.
const DEFAULT_BOSS_POS := Vector2(330.0, 25.0)
const DEFAULT_BOSS_PADDLE_WIDTH := 100.0
const DEFAULT_BOSS_HITBOX_HEIGHT := 40.0


static func is_active(context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if bool(context.get("perk_fusion_boss_skill_parry_active", false)):
		return true
	var runtime := _runtime(context, deps)
	return (
		runtime != null
		and runtime.has_method("is_perk_fusion_boss_skill_parry_active")
		and bool(runtime.is_perk_fusion_boss_skill_parry_active())
	)


static func try_parry(
	skill_id: String,
	skill_label: String,
	context: Dictionary = {},
	deps: Dictionary = {},
	impact_pos: Vector2 = Vector2.ZERO
) -> bool:
	var runtime := _runtime(context, deps)
	if runtime == null or not runtime.has_method("try_parry_perk_fusion_boss_skill"):
		return false
	var resolved_pos := impact_pos
	if resolved_pos == Vector2.ZERO:
		resolved_pos = _resolve_skill_origin(context)
	var result: Dictionary = runtime.try_parry_perk_fusion_boss_skill(
		skill_id,
		skill_label,
		resolved_pos
	)
	if not bool(result.get("parried", false)):
		return false
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio != null and audio.has_method("play_spellbreaker_guard_parry"):
		audio.play_spellbreaker_guard_parry()
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.025, 0.55)
	return true


static func _runtime(context: Dictionary, deps: Dictionary) -> Object:
	var runtime: Variant = deps.get("runtime_perk_state", context.get("runtime_perk_state", null))
	if typeof(runtime) == TYPE_OBJECT and is_instance_valid(runtime):
		return runtime as Object
	return null


static func _resolve_skill_origin(context: Dictionary) -> Vector2:
	var pos_value: Variant = context.get("boss_pos", null)
	var pos := DEFAULT_BOSS_POS
	if pos_value is Vector2:
		pos = pos_value
	var width := maxf(1.0, float(context.get("boss_paddle_width", DEFAULT_BOSS_PADDLE_WIDTH)))
	var height := maxf(1.0, float(context.get("boss_hitbox_height", DEFAULT_BOSS_HITBOX_HEIGHT)))
	return pos + Vector2(width, height) * 0.5
