extends RefCounted

const GameAudioPlayerFactory := preload("res://scripts/audio/game_audio_player_factory.gd")

const PADDLE_HIT_SOUND_PATH := "res://assets/sounds/paddle_hit.wav"
const SERVE_SOUND_PATH := "res://assets/sounds/serve.wav"
const PINGPONG_SERVE_SOUND_PATH := "res://assets/sounds/pong_paddle.wav"
const WALL_HIT_SOUND_PATH := "res://assets/sounds/wall_hit.wav"
const DASH_SOUND_PATH := "res://assets/sounds/dash.wav"
const HALF_DASH_SOUND_PATH := "res://assets/sounds/halfdash.wav"
const DRIVE_SOUND_PATH := "res://assets/sounds/drive.wav"
const DRINK_SOUND_PATH := "res://assets/sounds/drink.wav"
const POWER_SMASH_SOUND_PATH := "res://assets/sounds/power_smash.wav"
const POWER_SMASH_LAUNCH_SOUND_PATH := "res://assets/sounds/power_smash_launch.wav"
const ROUND_SET_SOUND_PATH := "res://assets/sounds/roundset.wav"
const PADDLE_HIT_SOUND_COOLDOWN := 0.06
const WALL_HIT_SOUND_COOLDOWN := 0.035
const SCOREBOARD_SOUND_VOLUME_DB := -8.0

var owner_node: Node
var player_factory: Object = GameAudioPlayerFactory.new()
var paddle_sound_cooldown := 0.0
var wall_sound_cooldown := 0.0
var paddle_hit_sfx: AudioStreamPlayer
var serve_sfx: AudioStreamPlayer
var pingpong_serve_sfx: AudioStreamPlayer
var wall_hit_sfx: AudioStreamPlayer
var dash_sfx: AudioStreamPlayer
var half_dash_sfx: AudioStreamPlayer
var drive_sfx: AudioStreamPlayer
var drink_sfx: AudioStreamPlayer
var power_smash_sfx: AudioStreamPlayer
var power_smash_launch_sfx: AudioStreamPlayer
var round_set_sfx: AudioStreamPlayer


func setup(parent: Node) -> void:
	owner_node = parent
	paddle_hit_sfx = player_factory.create(owner_node, "PaddleHitSfx", PADDLE_HIT_SOUND_PATH, -5.0)
	serve_sfx = player_factory.create(owner_node, "ServeSfx", SERVE_SOUND_PATH, -5.0)
	pingpong_serve_sfx = player_factory.create(owner_node, "PingpongServeSfx", PINGPONG_SERVE_SOUND_PATH, -5.0)
	wall_hit_sfx = player_factory.create(owner_node, "WallHitSfx", WALL_HIT_SOUND_PATH, -7.0)
	dash_sfx = player_factory.create(owner_node, "DashSfx", DASH_SOUND_PATH, -6.0)
	half_dash_sfx = player_factory.create(owner_node, "HalfDashSfx", HALF_DASH_SOUND_PATH, -6.0)
	drive_sfx = player_factory.create(owner_node, "DriveSfx", DRIVE_SOUND_PATH, -5.0)
	drink_sfx = player_factory.create(owner_node, "DrinkSfx", DRINK_SOUND_PATH, -5.0)
	power_smash_sfx = player_factory.create(owner_node, "PowerSmashSfx", POWER_SMASH_SOUND_PATH, -4.0)
	power_smash_launch_sfx = player_factory.create(owner_node, "PowerSmashLaunchSfx", POWER_SMASH_LAUNCH_SOUND_PATH, -4.0)
	round_set_sfx = player_factory.create(owner_node, "RoundSetSfx", ROUND_SET_SOUND_PATH, SCOREBOARD_SOUND_VOLUME_DB)


func update(delta: float) -> void:
	paddle_sound_cooldown = max(0.0, paddle_sound_cooldown - delta)
	wall_sound_cooldown = max(0.0, wall_sound_cooldown - delta)


func play_drive() -> void:
	_play_with_pitch(drive_sfx, randf_range(0.98, 1.02))


func play_drink() -> void:
	_play_with_pitch(drink_sfx, randf_range(0.98, 1.02))


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


func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
	if player == null or player.stream == null:
		return false
	player.pitch_scale = pitch
	if player.playing:
		player.stop()
	player.play()
	return true
