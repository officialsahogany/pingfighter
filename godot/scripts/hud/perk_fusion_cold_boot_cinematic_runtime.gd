extends RefCounted

# 콜드부트 시네마틱 호스트 lifecycle 래퍼(CB3, mythic runtime 패턴 포크).
# 소유 틱 경로 = battle_scene_overlay_frame_controller.process_idle의
# runtime_perk_state.update 직후(모달=idle 오버레이 tick 계약) — 융합
# 모달은 물리 flow가 choice_active에서 조기 반환하므로 update 드라이버는
# 모달 중 도달 불가하다. 같은 프레임 스킵→확정처럼 idle이 다시 오지 않는
# 종료 경로는 state의 _finish_perk_fusion_modal이 호스트를 직접 닫는다.
# 호스트 생성/prewarm은 애니메이션 진입이라는 이산 시점에만 일어난다
# (_draw/_process 인스턴스화 금지 — 핫패스 lazy-init 트랩). B5 SETTLE의
# 화면은 호스트가 아니라 모달 리빌 패널이 소유한다(핸드오프 계약) —
# reveal 진입 프레임에 호스트를 닫아도 같은 프레임의 즉시모드가 리빌
# 패널을 그리므로 단절 프레임이 없다.
const PerkFusionColdBootCinematic := preload("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")

const HOST_STATE_FIELD := "_cold_boot_cinematic_host"


func sync_from_runtime_state(state: Object, owner: Object, delta: float) -> void:
	if state == null or not state.has_method("is_perk_fusion_modal_active"):
		return
	var host: Object = _get_host(state)
	if (
		bool(state.is_perk_fusion_modal_active())
		and state.has_method("is_perk_fusion_boot_animation_active")
		and bool(state.is_perk_fusion_boot_animation_active())
	):
		if host == null:
			host = _ensure_host(state, owner)
		if host == null:
			# 호스트 불가(owner가 Node가 아님 등) — 렌더러 즉시모드가
			# degraded 폴백으로 그린다(무크래시 계약).
			return
		var boot_snapshot: Dictionary = {}
		if state.has_method("get_perk_fusion_modal_snapshot"):
			boot_snapshot = (state.get_perk_fusion_modal_snapshot().get("cold_boot", {}) as Dictionary)
		var events: Array = []
		if state.has_method("consume_perk_fusion_cold_boot_events"):
			events = state.consume_perk_fusion_cold_boot_events()
		if not bool(host.is_boot_active()) and host.has_method("prepare_committed_icons"):
			# 부트 진입 에지(모달당 1회, 이산 시점): 커밋 record의 재료
			# 아이콘+B4 코어 페이스 합성쌍을 프리웜한다 — draw 핫패스
			# 로드/합성 금지 계약.
			host.prepare_committed_icons(
				boot_snapshot.get("committed_record", {}) as Dictionary
			)
		host.sync_boot(boot_snapshot, events, delta)
		return
	if host != null and bool(host.is_boot_active()):
		host.finish_boot()
		# 마지막 프레임에 큐에 남은 전이 이벤트(settle 등)는 폐기한다 —
		# 다음 모달의 첫 sync로 stale 전이가 배달되면 안 된다.
		if state.has_method("consume_perk_fusion_cold_boot_events"):
			state.consume_perk_fusion_cold_boot_events()


# freed-인스턴스 가드: typed 인자·`is` 연산도 freed에 에러이므로
# is_instance_valid를 항상 선행한다.
func _get_host(state: Object) -> Object:
	var host_value: Variant = state.get(HOST_STATE_FIELD)
	if host_value is Object and is_instance_valid(host_value):
		return host_value
	return null


func _ensure_host(state: Object, owner: Object) -> Object:
	if not (owner is Node):
		return null
	# 이산 시점 prewarm(애니메이션 진입 1회) — 이후 add_child.
	PerkFusionColdBootCinematic.prewarm_assets()
	var host: Node2D = PerkFusionColdBootCinematic.new()
	(owner as Node).add_child(host)
	state.set(HOST_STATE_FIELD, host)
	return host


func reset_from_runtime_state(state: Object) -> void:
	if state == null:
		return
	var host: Object = _get_host(state)
	if host != null and bool(host.is_boot_active()):
		host.finish_boot()
