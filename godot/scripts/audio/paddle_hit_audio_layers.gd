extends RefCounted

# 일반 패들 반사의 짧은 몸통/타점 보조층 소유자.
# 디스크 로드나 AudioStream 복제 없이, CoreBallDashAudio가 이미 프리웜한
# paddle_hit 스트림을 두 setup-time 플레이어가 읽기 전용으로 공유한다.
const MIN_PROFILE_SPEED := 8.0
const FULL_PROFILE_SPEED := 35.0
const BODY_GAIN_DB_MIN := -22.0
const BODY_GAIN_DB_MAX := -16.0
const EDGE_GAIN_DB_MIN := -29.0
const EDGE_GAIN_DB_MAX := -23.0
const BODY_CENTER_BONUS_DB := 1.5
const EDGE_CONTACT_BONUS_DB := 8.0
const RALLY_BODY_GAIN_DB_PER_TIER := 0.25
const RALLY_EDGE_GAIN_DB_PER_TIER := 0.20
const RALLY_BASE_PITCH_PER_TIER := 0.006
const RALLY_BODY_PITCH_PER_TIER := 0.008
const RALLY_EDGE_PITCH_PER_TIER := 0.012
const BODY_PLAYER_NAME := "PaddleHitBodyLayerSfx"
const EDGE_PLAYER_NAME := "PaddleHitEdgeLayerSfx"

var _body_player: AudioStreamPlayer = null
var _edge_player: AudioStreamPlayer = null
var _last_profile: Dictionary = {}
var _layer_play_count := 0


func setup(parent: Node, shared_stream: AudioStream, bus_name: StringName) -> void:
	if parent == null:
		return
	_body_player = _ensure_player(_body_player, parent, BODY_PLAYER_NAME)
	_edge_player = _ensure_player(_edge_player, parent, EDGE_PLAYER_NAME)
	for player in [_body_player, _edge_player]:
		if player == null:
			continue
		player.stream = shared_stream
		player.bus = bus_name


func get_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	if _is_player_valid(_body_player):
		players.append(_body_player)
	if _is_player_valid(_edge_player):
		players.append(_edge_player)
	return players


func route_to_bus(bus_name: StringName) -> void:
	for player in get_players():
		player.bus = bus_name


func play_layers(profile: Dictionary) -> void:
	stop_layers()
	_last_profile = profile.duplicate()
	if not bool(profile.get("layered", false)):
		return
	var played := false
	played = _play_layer(
		_body_player,
		float(profile.get("body_pitch", 0.8)),
		float(profile.get("body_gain_db", BODY_GAIN_DB_MIN))
	) or played
	played = _play_layer(
		_edge_player,
		float(profile.get("edge_pitch", 1.25)),
		float(profile.get("edge_gain_db", EDGE_GAIN_DB_MIN))
	) or played
	if played:
		_layer_play_count += 1


func stop_layers() -> void:
	for player in get_players():
		if player.playing:
			player.stop()


func get_last_profile_for_tests() -> Dictionary:
	return _last_profile.duplicate()


func get_layer_play_count_for_tests() -> int:
	return _layer_play_count


static func build_profile(
	ball_speed: float,
	contact_ratio: float,
	is_player: bool,
	layered: bool = true,
	rally_tier: int = 0
) -> Dictionary:
	var speed_ratio: float = clampf(
		inverse_lerp(MIN_PROFILE_SPEED, FULL_PROFILE_SPEED, maxf(0.0, ball_speed)),
		0.0,
		1.0
	)
	var edge_ratio: float = clampf(absf(contact_ratio), 0.0, 1.0)
	var clamped_rally_tier: int = clampi(rally_tier, 0, 5)
	var identity_pitch_offset: float = 0.01 if is_player else -0.018
	var body_pitch: float = lerpf(0.74, 0.88, speed_ratio)
	body_pitch += float(clamped_rally_tier) * RALLY_BODY_PITCH_PER_TIER
	var edge_pitch: float = lerpf(1.18, 1.38, speed_ratio) + edge_ratio * 0.10
	edge_pitch += float(clamped_rally_tier) * RALLY_EDGE_PITCH_PER_TIER
	if not is_player:
		body_pitch -= 0.035
		edge_pitch -= 0.025
	var body_gain_db: float = lerpf(BODY_GAIN_DB_MIN, BODY_GAIN_DB_MAX, speed_ratio)
	body_gain_db += (1.0 - edge_ratio) * BODY_CENTER_BONUS_DB
	body_gain_db += float(clamped_rally_tier) * RALLY_BODY_GAIN_DB_PER_TIER
	var edge_gain_db: float = lerpf(EDGE_GAIN_DB_MIN, EDGE_GAIN_DB_MAX, speed_ratio)
	edge_gain_db += edge_ratio * EDGE_CONTACT_BONUS_DB
	edge_gain_db += float(clamped_rally_tier) * RALLY_EDGE_GAIN_DB_PER_TIER
	if not is_player:
		body_gain_db += 1.0
		edge_gain_db -= 1.0
	return {
		"base_pitch": clampf(
			lerpf(0.96, 1.055, speed_ratio)
			+ identity_pitch_offset
			+ float(clamped_rally_tier) * RALLY_BASE_PITCH_PER_TIER,
			0.90,
			1.10
		),
		"body_pitch": clampf(body_pitch, 0.66, 0.94),
		"body_gain_db": clampf(body_gain_db, -24.0, -13.0),
		"edge_pitch": clampf(edge_pitch, 1.10, 1.52),
		"edge_gain_db": clampf(edge_gain_db, -32.0, -14.0),
		"speed_ratio": speed_ratio,
		"edge_ratio": edge_ratio,
		"is_player": is_player,
		"layered": layered,
		"rally_tier": clamped_rally_tier,
	}


func _ensure_player(
	current: AudioStreamPlayer,
	parent: Node,
	player_name: String
) -> AudioStreamPlayer:
	if _is_player_valid(current) and current.get_parent() == parent:
		return current
	var existing: Node = parent.get_node_or_null(player_name)
	if existing is AudioStreamPlayer:
		return existing as AudioStreamPlayer
	var player := AudioStreamPlayer.new()
	player.name = player_name
	parent.add_child(player)
	return player


func _play_layer(player: AudioStreamPlayer, pitch: float, gain_db: float) -> bool:
	if not _is_player_valid(player) or player.stream == null:
		return false
	player.pitch_scale = pitch
	player.volume_db = gain_db
	player.play()
	return true


func _is_player_valid(player: AudioStreamPlayer) -> bool:
	return player != null and is_instance_valid(player) and not player.is_queued_for_deletion()
