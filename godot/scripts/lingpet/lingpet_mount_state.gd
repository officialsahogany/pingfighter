extends RefCounted

# 수호령 탑승 (socket composition contract, lane C pilot -- 방망깨비 / onimaru).
#
# Interaction: while the companion is active and the player stands within
# MOUNT_PROXIMITY_PX of it, a bare right-click toggles mount. Right-click is
# SHARED with Smasher 벽력유성 (hold-to-arm, fires on the paddle hit), so the
# caller passes input_blocked=true whenever that skill currently claims the
# button -- see lingpet_egg_runtime._is_right_click_claimed_by_player_skill.
# The skill only claims it while it is actually armable (equipped + gauge +
# cooldown + live rally) or in flight, so outside a rally the mount keeps the
# button unconditionally. S/down is ALSO still excluded here: it neighbours the
# dash / warp-gate chords and a crouch-mount reads as a misfire.
# While mounted:
#  - the companion position-overrides to the player's center X, KEEPING its
#    own lane Y (ground-pet locomotion trap: X changes only)
#  - companion body-hit / defense is suppressed (parked != disabled trap)
#  - the rider (player sprite stack: body + glow + parts) is lifted by the
#    companion's saddle height so she stands on the mount's back
#
# Edge detection polls Input directly with module-local previous-state (the
# same pattern smasher_input_reader uses) -- it never consumes another
# reader's stateful edges.
#
# Every round/result/stage reset must call reset(); a mount surviving a round
# boundary is a state leak (boss-skill cleanup trap family).

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const MOUNT_PROXIMITY_PX := 78.0
# D1 안장 게이트 (S2, 2026-08-05): 탑승 자격의 기준은 펫 화이트리스트가 아니라
# "현재 액티브 슬롯에 그 펫의 안장 스킬(interaction_permit)이 장착"이다 — 보유가
# 아니라 장착. 지원 펫 = 이 맵의 키 ∪ 유예 목록. egg runtime이 장착 슬롯을 조회해
# is_mount_permitted()로 불리언 하나를 만들어 advance()에 전달하고, 철회 전이
# (탑승 중 permit 상실 → 같은 프레임 강제 하차) 처리는 이 모듈이 단독 소유한다.
const MOUNT_SADDLE_SKILL_IDS := {
	"baekrin": "baekrin_saddle",
	"onimaru": "onimaru_saddle",
}
# 온이마루 유예 (D2): `오니마루의안장` 스킬이 아직 제작되지 않아(S8 예정) 장착
# 게이트를 그대로 적용하면 현행 탑승이 회귀로 죽는다. 유예 = 장착 없이 항상
# permitted. S8에서 onimaru_saddle이 랜딩되면 이 목록에서 제거한다 — 조용한
# 예외 금지 계약이라 S2 씰이 이 유예를 명시적으로 봉인한다.
const MOUNT_UNGATED_LEGACY_PET_IDS := ["onimaru"]
# Fallback only. `player_paddle_width` is the DECLARED owner key -- see
# _get_player_center_x for why the old `player_paddle_size` read was a silent
# schema miss.
const DEFAULT_PLAYER_PADDLE_WIDTH := 155.0
# Rider Y-lift for the shoulder-ride (목말) composition: low enough that the
# rider's board/seat hides BEHIND the mount's head (the companion draws in
# front of the rider while mounted), leaving her upper body above his head.
# Tuned against the 목말 reference shot; live-QA adjustable.
const ONIMARU_SADDLE_LIFT_PX := 14.0

var _mounted := false
var _last_rmb_pressed := false
var _pet_id := ""
# Test seam: object exposing is_rmb_pressed() / is_down_pressed(). Headless
# smokes inject it because real Input cannot be driven there; live play
# leaves it null and polls Input directly.
var _input_probe: Object = null


func set_input_probe(probe: Object) -> void:
	_input_probe = probe


func _is_rmb_pressed() -> bool:
	if _input_probe != null and _input_probe.has_method("is_rmb_pressed"):
		return bool(_input_probe.is_rmb_pressed())
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _is_down_pressed() -> bool:
	if _input_probe != null and _input_probe.has_method("is_down_pressed"):
		return bool(_input_probe.is_down_pressed())
	return Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)


# Ride-motion tuning: hop-on arc, dismount drop, gait bounce, breath sway,
# and X-follow inertia. All procedural (no art), all delta-driven.
const MOUNT_HOP_SECONDS := 0.28
const DISMOUNT_SECONDS := 0.16
const RIDE_BOUNCE_MOVE_PX := 3.2
const RIDE_BOUNCE_MOVE_HZ := 5.0
const RIDE_BREATH_PX := 1.5
const RIDE_BREATH_HZ := 0.9
const RIDE_MOVE_SPEED_EPSILON := 0.2

var _hop_t := 1.0
var _dismount_t := 1.0
var _ride_clock := 0.0
var _riding_moving := false
var _last_delta := 0.0


func reset() -> void:
	_mounted = false
	_last_rmb_pressed = false
	_hop_t = 1.0
	_dismount_t = 1.0
	_ride_clock = 0.0
	_riding_moving = false
	_last_delta = 0.0


static func is_supported_pet(pet_id: String) -> bool:
	return MOUNT_SADDLE_SKILL_IDS.has(pet_id) or MOUNT_UNGATED_LEGACY_PET_IDS.has(pet_id)


# 장착 게이트 판정 (S2). equipped_active_skill_ids = 현재 액티브 슬롯에 장착된
# 스킬 id들(egg runtime이 _skill_runtime_surface.get_active_skill_ids로 조회).
# 유예 펫은 장착 없이 true, 맵에 없는 펫은 false(fail-closed).
static func is_mount_permitted(pet_id: String, equipped_active_skill_ids: Array) -> bool:
	if MOUNT_UNGATED_LEGACY_PET_IDS.has(pet_id):
		return true
	var saddle_id := str(MOUNT_SADDLE_SKILL_IDS.get(pet_id, ""))
	if saddle_id == "":
		return false
	return equipped_active_skill_ids.has(saddle_id)


func set_pet_id(pet_id: String) -> void:
	_pet_id = pet_id
	if not is_supported_pet(_pet_id):
		_mounted = false


func is_mounted() -> bool:
	return _mounted


# Animated rider lift: hop-on arc with a small overshoot, then gait bounce
# while the pair moves / gentle breath sway at rest; eased drop on dismount.
func get_rider_lift_px() -> float:
	if _mounted:
		var hop: float = clampf(_hop_t, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - hop, 3.0)
		var overshoot: float = sin(hop * PI) * 0.3 * (1.0 - hop)
		return ONIMARU_SADDLE_LIFT_PX * (eased + overshoot) + _get_ride_bounce_px() * eased
	if _dismount_t < 1.0:
		return ONIMARU_SADDLE_LIFT_PX * pow(1.0 - _dismount_t, 2.0)
	return 0.0


func _get_ride_bounce_px() -> float:
	if _riding_moving:
		return RIDE_BOUNCE_MOVE_PX * absf(sin(_ride_clock * TAU * RIDE_BOUNCE_MOVE_HZ * 0.5))
	return RIDE_BREATH_PX * 0.5 * (1.0 + sin(_ride_clock * TAU * RIDE_BREATH_HZ * 0.5))


# Ticks the toggle + ride motion clocks. Call once per companion update frame
# while the companion is in its active (non-egg) state; pass
# companion_active=false to force a dismount (pet incapacitated / despawned).
func advance(owner: Object, companion_pos: Vector2, companion_active: bool, input_blocked: bool, delta: float, mount_permitted: bool, body_presentation_incompatible: bool) -> Dictionary:
	var result := {"toggled": false, "mounted": _mounted}
	_last_delta = maxf(delta, 0.0)
	if _mounted:
		_hop_t = minf(1.0, _hop_t + _last_delta / MOUNT_HOP_SECONDS)
		_ride_clock += _last_delta
		_riding_moving = absf(float(BattleSceneOwnerReader.get_value(owner, "player_speed", 0.0))) > RIDE_MOVE_SPEED_EPSILON
	else:
		_dismount_t = minf(1.0, _dismount_t + _last_delta / DISMOUNT_SECONDS)
	# mount_permitted(S2 장착 게이트)는 진입 게이트이자 철회 전이다: 탑승 중에
	# 안장 슬롯이 제거·교체돼 permit이 떨어지면 미지원 펫/컴패니언 비활성과 같은
	# 조건으로 이 프레임에 강제 하차한다(입력 엣지 처리보다 먼저).
	# body_presentation_incompatible(S3-a §C-3c)은 egg runtime 이 "탑다운 모델 ×
	# 플레이어 본체 대체(오딘/뿔딸기)"를 곱해 만든 필수 인자다 — 판정은 egg 가
	# 소유하고 여기는 철회 전이만 소유한다. 필수인 이유 = 기본값은 호출 누락을
	# 조용히 숨긴다(S2 fail-open 교훈). 목말(온이마루)은 모델 축이 false 라 항상
	# false 로 들어와 변신 중에도 현행 그대로 탑승이 유지된다.
	if not is_supported_pet(_pet_id) or not companion_active or not mount_permitted or body_presentation_incompatible:
		if _mounted:
			_dismount()
			result["toggled"] = true
		result["mounted"] = _mounted
		_last_rmb_pressed = _is_rmb_pressed()
		return result

	var rmb_pressed: bool = _is_rmb_pressed()
	var rmb_just_pressed: bool = rmb_pressed and not _last_rmb_pressed
	_last_rmb_pressed = rmb_pressed
	if input_blocked or not rmb_just_pressed:
		return result
	# S+RMB neighbours the dash / warp-gate chords -- never mount on a crouch.
	# (벽력유성 우클릭 소유권은 호출자가 input_blocked 로 이미 걸러 준다.)
	if _is_down_pressed():
		return result
	if _mounted:
		_dismount()
		result["toggled"] = true
		result["mounted"] = false
		return result
	var player_center_x: float = _get_player_center_x(owner)
	if absf(player_center_x - companion_pos.x) > MOUNT_PROXIMITY_PX:
		return result
	_mounted = true
	_hop_t = 0.0
	_ride_clock = 0.0
	result["toggled"] = true
	result["mounted"] = true
	return result


func _dismount() -> void:
	_mounted = false
	_dismount_t = 0.0


# S3-a §C-3d: pre-pause reconcile 전용 멱등 철회. pause 게이트가 update_lingpet
# 앞에서 프레임을 반환하는 동안(뿔딸기 이벤트 등) advance()가 돌지 않으므로,
# egg 의 reconcile 표면이 이 API 로 철회만 수행한다.
# ⚠️ advance(delta=0) 재사용 금지 계약의 이행체다 — advance 는 RMB 에지와 홉/하차
#    시계까지 갱신하므로 pause 프레임에 돌리면 입력 에지를 먹거나 시계를 오염시킨다.
#    여기는 상태 전이 하나만 한다. 이미 하차 상태면 아무것도 바꾸지 않는다(멱등).
# 반환 = 이 호출로 실제 하차가 일어났는가 (호출자가 스냅샷 무효화 판단에 쓴다).
func force_dismount_for_body_presentation() -> bool:
	if not _mounted:
		return false
	_dismount()
	return true


func has_companion_position_override() -> bool:
	return _mounted


# Ground pet keeps its lane Y -- only X follows the rider (companion
# teleport/reposition locomotion trap). The X-follow SNAPS to the rider:
# the rider is glued to the physics paddle, so ANY follow inertia visibly
# separates the pair at move speed (lag = speed / k). Inertia belongs to
# follower pets, never to a mounted pair -- ride life comes from the
# Y-channel (hop / gait bounce / breath) instead.
func get_companion_position_override(owner: Object, current: Vector2) -> Vector2:
	if not _mounted:
		return current
	return Vector2(_get_player_center_x(owner), current.y)


# `player_paddle_size` is NOT declared in BattleSceneState.DEFAULT_VALUES (only
# `player_paddle_width` / `player_paddle_height` are), so reading it yielded the
# hardcoded fallback FOREVER -- owner-field schema trap. An expanded paddle (220)
# therefore pushed this anchor 32.5px left of the visual center, mis-aiming BOTH
# the mount proximity window and the mounted follow override (the rider and the
# companion visibly separate). Read the declared width key.
func _get_player_center_x(owner: Object) -> float:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO)
	var paddle_width: float = float(BattleSceneOwnerReader.get_value(
		owner,
		"player_paddle_width",
		DEFAULT_PLAYER_PADDLE_WIDTH
	))
	if paddle_width <= 0.0:
		paddle_width = DEFAULT_PLAYER_PADDLE_WIDTH
	return player_pos.x + paddle_width * 0.5
