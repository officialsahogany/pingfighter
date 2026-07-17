extends RefCounted


func update_runtime_perk_resume(owner: Object, registry: Object, delta: float) -> void:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("update_resume_safety"):
		runtime_perk_state.update_resume_safety(owner, registry, delta)
	# 주사위 패들 연출의 게임플레이 시간 3초 시계: 모달 physics 차단 중엔 이
	# 드라이버가 안 돌아 자연 정지하고, 재개 첫 틱이 지연 시작한다. 활성
	# 틱은 통합 redraw만 요청한다(직접 queue_redraw 금지).
	if runtime_perk_state != null and runtime_perk_state.has_method("update_mystic_dice_paddle_effect"):
		if bool(runtime_perk_state.update_mystic_dice_paddle_effect(delta)):
			_request_battle_redraw(owner)
	var laurel_leaf_shield_state: Object = _get_instance(registry, "laurel_leaf_shield_state")
	if laurel_leaf_shield_state != null and laurel_leaf_shield_state.has_method("update_from_runtime"):
		laurel_leaf_shield_state.update_from_runtime(owner, registry, delta)


func _request_battle_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
