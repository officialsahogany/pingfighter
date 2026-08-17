extends RefCounted

## Owns AudioServer bus creation/routing, persistent BGM/SFX volume state,
## existing-bus adoption, character-info BGM filtering, hit-panner effect
## installation/cache, and source-X pan projection. GameAudio retains cue
## lists, playback timing, pitch, and player lifecycle.

const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 0.7
const BGM_BUS_NAME := "BGM"
const SFX_BUS_NAME := "SFX"
const PADDLE_PAN_BUS_NAME := "SFXPanPaddle"
const WALL_PAN_BUS_NAME := "SFXPanWall"
const CHARACTER_INFO_BGM_MUFFLE_EFFECT_NAME := "CharacterInfoBgmMuffle"
# ⚠️`CUTOFF_HZ` 는 -3dB 지점이 아니다. Godot 은 `resonance` 를 바이쿼드 Q 로 쓰고
# `FILTER_12DB` 를 같은 계수의 **2단 캐스케이드**로 처리하므로, 바이쿼드 LPF 의
# |H(f0)| = Q 정의에 따라 f0 에서 Q^2 만큼 떨어진다. 현재 값(Q 0.707 / 2단):
#   1200Hz 에서 20*log10(0.707^2) ≈ **-6.02dB**, 실효 -3dB 지점 ≈ **963Hz**
#   (단당 |H|^2 = 1/sqrt(2) → 1 + u^2 = sqrt(2) → x = 0.802 → 1200*0.802).
# 세기를 조정할 때 CUTOFF 만 움직이면 체감이 기대만큼 따라오지 않는다 — Q 와
# 단수(FILTER_12DB/6DB)가 실효 대역을 같이 정하므로 셋을 함께 보고 위 실효값을
# 다시 계산해 적을 것. 참고로 Q 0.35 / 2단 은 1200Hz 에서 -18.24dB, 실효 ≈310Hz
# 라 "벽 너머" 수준으로 어두웠고, 청감 A/B 후 현재 값으로 확정했다.
const CHARACTER_INFO_BGM_MUFFLE_CUTOFF_HZ := 1200.0
const CHARACTER_INFO_BGM_MUFFLE_RESONANCE := 0.707
const PLAYFIELD_LEFT_X := 0.0
const PLAYFIELD_RIGHT_X := 760.0
const PLAYFIELD_CENTER_X := 380.0
const HIT_PAN_STRENGTH := 0.6

var _bgm_volume := DEFAULT_BGM_VOLUME
var _sfx_volume := DEFAULT_SFX_VOLUME
var _audio_bus_volumes_adopted := false
var _paddle_hit_panner: AudioEffectPanner = null
var _wall_hit_panner: AudioEffectPanner = null
var _character_info_bgm_muffle_filter: AudioEffectLowPassFilter = null
var _character_info_bgm_muffled := false
var _story_cinematic_bgm_gain_db := 0.0


func apply_audio_buses_and_volumes(
	bgm_players: Array,
	sfx_players: Array,
	paddle_player: AudioStreamPlayer,
	wall_player: AudioStreamPlayer
) -> void:
	adopt_existing_audio_bus_volumes()
	ensure_audio_bus(BGM_BUS_NAME)
	ensure_audio_bus(SFX_BUS_NAME)
	_ensure_character_info_bgm_muffle_filter()
	ensure_hit_pan_buses()
	route_bgm_players(bgm_players)
	route_sfx_players(sfx_players, paddle_player, wall_player)
	apply_bgm_bus_volume()
	apply_sfx_bus_volume()


func get_bgm_volume() -> float:
	return _bgm_volume


func set_bgm_volume_state(value: float) -> void:
	_bgm_volume = value


func set_bgm_volume(value: float) -> float:
	_bgm_volume = clampf(value, 0.0, 1.0)
	apply_bgm_bus_volume()
	return _bgm_volume


func set_story_cinematic_bgm_gain_db(value: float) -> float:
	_story_cinematic_bgm_gain_db = clampf(value, -80.0, 0.0)
	apply_bgm_bus_volume()
	return _story_cinematic_bgm_gain_db


func clear_story_cinematic_bgm_gain() -> void:
	if is_zero_approx(_story_cinematic_bgm_gain_db):
		return
	_story_cinematic_bgm_gain_db = 0.0
	apply_bgm_bus_volume()


func get_story_cinematic_bgm_gain_db() -> float:
	return _story_cinematic_bgm_gain_db


func get_sfx_volume() -> float:
	return _sfx_volume


func set_sfx_volume_state(value: float) -> void:
	_sfx_volume = value


func set_sfx_volume(value: float) -> float:
	_sfx_volume = clampf(value, 0.0, 1.0)
	apply_sfx_bus_volume()
	return _sfx_volume


func get_audio_bus_volumes_adopted() -> bool:
	return _audio_bus_volumes_adopted


func set_audio_bus_volumes_adopted(value: bool) -> void:
	_audio_bus_volumes_adopted = value


func adopt_existing_audio_bus_volumes() -> void:
	if _audio_bus_volumes_adopted:
		return
	_audio_bus_volumes_adopted = true
	_bgm_volume = get_existing_audio_bus_volume(BGM_BUS_NAME, _bgm_volume)
	_sfx_volume = get_existing_audio_bus_volume(SFX_BUS_NAME, _sfx_volume)


func get_existing_audio_bus_volume(bus_name: String, fallback: float) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return fallback
	var volume_db := AudioServer.get_bus_volume_db(bus_index)
	if volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(volume_db), 0.0, 1.0)


func route_bgm_players(players: Array) -> void:
	for value: Variant in players:
		if value is AudioStreamPlayer:
			(value as AudioStreamPlayer).bus = BGM_BUS_NAME


func route_sfx_players(
	players: Array,
	paddle_player: AudioStreamPlayer,
	wall_player: AudioStreamPlayer
) -> void:
	for value: Variant in players:
		if not value is AudioStreamPlayer:
			continue
		var player := value as AudioStreamPlayer
		if player == paddle_player:
			player.bus = PADDLE_PAN_BUS_NAME
		elif player == wall_player:
			player.bus = WALL_PAN_BUS_NAME
		else:
			player.bus = SFX_BUS_NAME


func set_character_info_bgm_muffled(active: bool) -> void:
	_character_info_bgm_muffled = active
	var effect_index := _ensure_character_info_bgm_muffle_filter()
	var bus_index := AudioServer.get_bus_index(BGM_BUS_NAME)
	if bus_index >= 0 and effect_index >= 0:
		AudioServer.set_bus_effect_enabled(bus_index, effect_index, active)


func is_character_info_bgm_muffled() -> bool:
	return _character_info_bgm_muffled


func _ensure_character_info_bgm_muffle_filter() -> int:
	var bus_index := ensure_audio_bus(BGM_BUS_NAME)
	if bus_index < 0:
		return -1
	var effect_index := _find_character_info_bgm_muffle_filter(bus_index)
	if effect_index < 0:
		var filter := AudioEffectLowPassFilter.new()
		filter.resource_name = CHARACTER_INFO_BGM_MUFFLE_EFFECT_NAME
		filter.cutoff_hz = CHARACTER_INFO_BGM_MUFFLE_CUTOFF_HZ
		filter.resonance = CHARACTER_INFO_BGM_MUFFLE_RESONANCE
		filter.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(bus_index, filter)
		_character_info_bgm_muffle_filter = filter
		effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
	AudioServer.set_bus_effect_enabled(bus_index, effect_index, _character_info_bgm_muffled)
	return effect_index


func _find_character_info_bgm_muffle_filter(bus_index: int) -> int:
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect == _character_info_bgm_muffle_filter:
			return effect_index
		if effect is AudioEffectLowPassFilter and effect.resource_name == CHARACTER_INFO_BGM_MUFFLE_EFFECT_NAME:
			_character_info_bgm_muffle_filter = effect as AudioEffectLowPassFilter
			return effect_index
	return -1


func ensure_hit_pan_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) < 0:
		ensure_audio_bus(SFX_BUS_NAME)
	_paddle_hit_panner = ensure_sfx_pan_bus(PADDLE_PAN_BUS_NAME, _paddle_hit_panner)
	_wall_hit_panner = ensure_sfx_pan_bus(WALL_PAN_BUS_NAME, _wall_hit_panner)


func ensure_sfx_pan_bus(bus_name: String, current_panner: AudioEffectPanner) -> AudioEffectPanner:
	var bus_index := ensure_audio_bus(bus_name)
	if bus_index < 0:
		return current_panner
	AudioServer.set_bus_send(bus_index, SFX_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, 0.0)
	if current_panner != null:
		return current_panner
	for effect_index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectPanner:
			var existing_panner := effect as AudioEffectPanner
			existing_panner.set_pan(0.0)
			return existing_panner
	var panner := AudioEffectPanner.new()
	panner.set_pan(0.0)
	AudioServer.add_bus_effect(bus_index, panner)
	return panner


func get_paddle_hit_panner() -> AudioEffectPanner:
	return _paddle_hit_panner


func set_paddle_hit_panner(value: AudioEffectPanner) -> void:
	_paddle_hit_panner = value


func get_wall_hit_panner() -> AudioEffectPanner:
	return _wall_hit_panner


func set_wall_hit_panner(value: AudioEffectPanner) -> void:
	_wall_hit_panner = value


func configure_bgm_player(player: AudioStreamPlayer) -> AudioStreamPlayer:
	if player != null:
		ensure_audio_bus(BGM_BUS_NAME)
		player.bus = BGM_BUS_NAME
	apply_bgm_bus_volume()
	return player


func configure_sfx_player(player: AudioStreamPlayer) -> AudioStreamPlayer:
	if player != null:
		ensure_audio_bus(SFX_BUS_NAME)
		player.bus = SFX_BUS_NAME
		apply_sfx_bus_volume()
	return player


func apply_bgm_bus_volume() -> void:
	var bus_index := ensure_audio_bus(BGM_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(
			bus_index,
			maxf(-80.0, volume_to_db(_bgm_volume) + _story_cinematic_bgm_gain_db)
		)


func apply_sfx_bus_volume() -> void:
	var bus_index := ensure_audio_bus(SFX_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_to_db(_sfx_volume))


func ensure_audio_bus(bus_name: String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	return bus_index


func volume_to_db(volume: float) -> float:
	var clamped := clampf(volume, 0.0, 1.0)
	if clamped <= 0.0:
		return -80.0
	return linear_to_db(clamped)


func get_hit_pan_from_source_x(source_x: float) -> float:
	var clamped_x := clampf(source_x, PLAYFIELD_LEFT_X, PLAYFIELD_RIGHT_X)
	var half_width := maxf((PLAYFIELD_RIGHT_X - PLAYFIELD_LEFT_X) * 0.5, 1.0)
	var normalized_x := (clamped_x - PLAYFIELD_CENTER_X) / half_width
	return clampf(normalized_x * HIT_PAN_STRENGTH, -1.0, 1.0)
