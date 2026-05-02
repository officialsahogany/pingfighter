extends RefCounted

const GameAudioPlayerFactory := preload("res://scripts/audio/game_audio_player_factory.gd")

const PADDLE_HIT_SOUND_PATH := "res://assets/sounds/paddle_hit.wav"
const SERVE_SOUND_PATH := "res://assets/sounds/serve.wav"
const PINGPONG_SERVE_SOUND_PATH := "res://assets/sounds/pong_paddle.wav"
const WALL_HIT_SOUND_PATH := "res://assets/sounds/wall_hit.wav"
const DASH_SOUND_PATH := "res://assets/sounds/dash.wav"
const HALF_DASH_SOUND_PATH := "res://assets/sounds/halfdash.wav"
const DASH_DELAY_SOUND_PATH := "res://assets/sounds/dashdelay.wav"
const DRIVE_SOUND_PATH := "res://assets/sounds/drive.wav"
const WHIP_SOUND_PATH := "res://assets/sounds/whip_effect.wav"
const ITEM_GET_SOUND_PATH := "res://assets/sounds/itemget.wav"
const DRINK_SOUND_PATH := "res://assets/sounds/drink.wav"
const THROW_BEFORE_SOUND_PATH := "res://assets/sounds/throwbefore.wav"
const THROW_SOUND_PATH := "res://assets/sounds/throw.wav"
const GRENADE_SOUND_PATH := "res://assets/sounds/grenade.wav"
const POWER_SMASH_SOUND_PATH := "res://assets/sounds/power_smash.wav"
const POWER_SMASH_LAUNCH_SOUND_PATH := "res://assets/sounds/power_smash_launch.wav"
const ROUND_SET_SOUND_PATH := "res://assets/sounds/roundset.wav"
const STAGE1_BGM_PATH := "res://assets/bgm/stage1bgm.mp3"
const PADDLE_HIT_SOUND_COOLDOWN := 0.06
const WALL_HIT_SOUND_COOLDOWN := 0.035
const SCOREBOARD_SOUND_VOLUME_DB := -8.0
const DEFAULT_BGM_VOLUME := 0.4
const STAGE1_BGM_GAIN := 0.75

var owner_node: Node
var player_factory: Object = GameAudioPlayerFactory.new()
var paddle_sound_cooldown := 0.0
var wall_sound_cooldown := 0.0
var current_bgm_name := ""
var paddle_hit_sfx: AudioStreamPlayer
var serve_sfx: AudioStreamPlayer
var pingpong_serve_sfx: AudioStreamPlayer
var wall_hit_sfx: AudioStreamPlayer
var dash_sfx: AudioStreamPlayer
var half_dash_sfx: AudioStreamPlayer
var dash_delay_sfx: AudioStreamPlayer
var drive_sfx: AudioStreamPlayer
var whip_sfx: AudioStreamPlayer
var item_get_sfx: AudioStreamPlayer
var drink_sfx: AudioStreamPlayer
var throw_before_sfx: AudioStreamPlayer
var throw_sfx: AudioStreamPlayer
var grenade_sfx: AudioStreamPlayer
var power_smash_sfx: AudioStreamPlayer
var power_smash_launch_sfx: AudioStreamPlayer
var round_set_sfx: AudioStreamPlayer
var stage1_bgm: AudioStreamPlayer


func setup(parent: Node) -> void:
	owner_node = parent
	paddle_hit_sfx = player_factory.create(owner_node, "PaddleHitSfx", PADDLE_HIT_SOUND_PATH, -5.0)
	serve_sfx = player_factory.create(owner_node, "ServeSfx", SERVE_SOUND_PATH, -5.0)
	pingpong_serve_sfx = player_factory.create(owner_node, "PingpongServeSfx", PINGPONG_SERVE_SOUND_PATH, -5.0)
	wall_hit_sfx = player_factory.create(owner_node, "WallHitSfx", WALL_HIT_SOUND_PATH, -7.0)
	dash_sfx = player_factory.create(owner_node, "DashSfx", DASH_SOUND_PATH, -6.0)
	half_dash_sfx = player_factory.create(owner_node, "HalfDashSfx", HALF_DASH_SOUND_PATH, -6.0)
	dash_delay_sfx = player_factory.create(owner_node, "DashDelaySfx", DASH_DELAY_SOUND_PATH, -9.0)
	_enable_loop(dash_delay_sfx)
	drive_sfx = player_factory.create(owner_node, "DriveSfx", DRIVE_SOUND_PATH, -5.0)
	whip_sfx = player_factory.create(owner_node, "WhipSfx", WHIP_SOUND_PATH, -5.0)
	item_get_sfx = player_factory.create(owner_node, "ItemGetSfx", ITEM_GET_SOUND_PATH, -5.0)
	drink_sfx = player_factory.create(owner_node, "DrinkSfx", DRINK_SOUND_PATH, -5.0)
	throw_before_sfx = player_factory.create(owner_node, "ThrowBeforeSfx", THROW_BEFORE_SOUND_PATH, -5.0)
	throw_sfx = player_factory.create(owner_node, "ThrowSfx", THROW_SOUND_PATH, -5.0)
	grenade_sfx = player_factory.create(owner_node, "GrenadeSfx", GRENADE_SOUND_PATH, -4.0)
	power_smash_sfx = player_factory.create(owner_node, "PowerSmashSfx", POWER_SMASH_SOUND_PATH, -4.0)
	power_smash_launch_sfx = player_factory.create(owner_node, "PowerSmashLaunchSfx", POWER_SMASH_LAUNCH_SOUND_PATH, -4.0)
	round_set_sfx = player_factory.create(owner_node, "RoundSetSfx", ROUND_SET_SOUND_PATH, SCOREBOARD_SOUND_VOLUME_DB)
	stage1_bgm = player_factory.create(
		owner_node,
		"Stage1Bgm",
		STAGE1_BGM_PATH,
		linear_to_db(DEFAULT_BGM_VOLUME * STAGE1_BGM_GAIN)
	)
	_enable_loop(stage1_bgm)


func update(delta: float) -> void:
	paddle_sound_cooldown = max(0.0, paddle_sound_cooldown - delta)
	wall_sound_cooldown = max(0.0, wall_sound_cooldown - delta)


func play_drive() -> void:
	_play_with_pitch(drive_sfx, randf_range(0.98, 1.02))


func play_whip() -> void:
	_play_with_pitch(whip_sfx, randf_range(0.98, 1.02))


func stop_whip() -> void:
	if whip_sfx != null and whip_sfx.playing:
		whip_sfx.stop()


func play_item_get() -> void:
	_play_with_pitch(item_get_sfx, randf_range(0.98, 1.02))


func play_drink() -> void:
	_play_with_pitch(drink_sfx, randf_range(0.98, 1.02))


func play_throw_before() -> void:
	_play_with_pitch(throw_before_sfx, randf_range(0.98, 1.02))


func play_throw() -> void:
	_play_with_pitch(throw_sfx, randf_range(0.98, 1.02))


func play_grenade_explosion() -> void:
	_play_with_pitch(grenade_sfx, randf_range(0.98, 1.02))


func play_power_smash() -> void:
	_play_with_pitch(power_smash_sfx, randf_range(0.98, 1.02))


func play_power_smash_launch() -> void:
	_play_with_pitch(power_smash_launch_sfx, randf_range(0.98, 1.02))


func play_paddle_hit() -> void:
	if paddle_sound_cooldown > 0.0:
		return
	if _play_with_pitch(paddle_hit_sfx, randf_range(0.98, 1.02)):
		paddle_sound_cooldown = PADDLE_HIT_SOUND_COOLDOWN


func play_serve(ball_visual_type: String = "") -> void:
	var player: AudioStreamPlayer = serve_sfx
	if ball_visual_type == "pingpong" and pingpong_serve_sfx != null and pingpong_serve_sfx.stream != null:
		player = pingpong_serve_sfx
	_play_with_pitch(player, randf_range(0.98, 1.02))


func play_dash_start(is_half: bool) -> void:
	var player: AudioStreamPlayer = half_dash_sfx if is_half else dash_sfx
	_play_with_pitch(player, randf_range(0.98, 1.02))


func sync_dash_delay(recovering: bool) -> void:
	if recovering:
		play_dash_delay()
	else:
		stop_dash_delay()


func play_dash_delay() -> void:
	if dash_delay_sfx == null or dash_delay_sfx.stream == null:
		return
	if dash_delay_sfx.playing:
		return
	dash_delay_sfx.pitch_scale = 1.0
	dash_delay_sfx.play()


func stop_dash_delay() -> void:
	if dash_delay_sfx != null and dash_delay_sfx.playing:
		dash_delay_sfx.stop()


func play_wall_hit(impact_speed: float) -> void:
	if wall_sound_cooldown > 0.0:
		return
	var pitch: float = clamp(0.94 + impact_speed / 90.0, 0.94, 1.22) * randf_range(0.98, 1.02)
	if _play_with_pitch(wall_hit_sfx, pitch):
		wall_sound_cooldown = WALL_HIT_SOUND_COOLDOWN


func play_round_set() -> void:
	if round_set_sfx == null or round_set_sfx.stream == null:
		return
	if round_set_sfx.playing:
		round_set_sfx.stop()
	round_set_sfx.play()


func play_stage_bgm(stage: int) -> bool:
	if stage == 1:
		return play_bgm("stage1")
	stop_bgm()
	return false


func play_bgm(bgm_name: String) -> bool:
	var player: AudioStreamPlayer = _get_bgm_player(bgm_name)
	if player == null or player.stream == null:
		return false
	if current_bgm_name == bgm_name and player.playing:
		return true
	stop_bgm()
	player.pitch_scale = 1.0
	player.play()
	current_bgm_name = bgm_name
	return true


func stop_bgm() -> void:
	var player: AudioStreamPlayer = _get_bgm_player(current_bgm_name)
	if player != null and player.playing:
		player.stop()
	current_bgm_name = ""


func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
	if player == null or player.stream == null:
		return false
	player.pitch_scale = pitch
	if player.playing:
		player.stop()
	player.play()
	return true


func _get_bgm_player(bgm_name: String) -> AudioStreamPlayer:
	if bgm_name == "stage1":
		return stage1_bgm
	return null


func _enable_loop(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	var stream: AudioStream = player.stream
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = -1
	elif stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		mp3_stream.loop = true
	elif stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = stream
		ogg_stream.loop = true
