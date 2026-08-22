extends RefCounted

const CurseChestOwnerScript := preload("res://scripts/stages/stage3/stage3_curse_chest_state.gd")
const KuromiAwakeningOwnerScript := preload("res://scripts/stages/stage3/stage3_kuromi_awakening_state.gd")
const KuromiEatingOwnerScript := preload("res://scripts/stages/stage3/stage3_kuromi_eating_state.gd")
const PrismBurstOwnerScript := preload("res://scripts/stages/stage3/stage3_prism_burst_state.gd")
const PsychoballOwnerScript := preload("res://scripts/stages/stage3/stage3_psychoball_state.gd")
const TailWhipOwnerScript := preload("res://scripts/stages/stage3/stage3_tail_whip_state.gd")
const TearShowerOwnerScript := preload("res://scripts/stages/stage3/stage3_tear_shower_state.gd")

## Static compatibility surface for Stage3BossSkillState's legacy public
## properties. The runtime host constructs and coordinates the focused owners;
## these accessors only route reads/writes to those exact owner instances.

var _tear_shower_state: TearShowerOwnerScript = null
var _curse_chest_state: CurseChestOwnerScript = null
var _psychoball_state: PsychoballOwnerScript = null
var _tail_whip_state: TailWhipOwnerScript = null
var _kuromi_awakening_state: KuromiAwakeningOwnerScript = null
var _kuromi_eating_state: KuromiEatingOwnerScript = null
var _prism_burst_state: PrismBurstOwnerScript = null

var tears_active: bool:
	get: return _tear_shower_state.tears_active
	set(value): _tear_shower_state.tears_active = value
var tears_timer: float:
	get: return _tear_shower_state.tears_timer
	set(value): _tear_shower_state.tears_timer = value
var tears_cooldown: float:
	get: return _tear_shower_state.tears_cooldown
	set(value): _tear_shower_state.tears_cooldown = value
var falling_tears: Array:
	get: return _tear_shower_state.falling_tears
	set(value): _tear_shower_state.falling_tears = value

var curse_phase: String:
	get: return _curse_chest_state.curse_phase
	set(value): _curse_chest_state.curse_phase = value
var curse_cooldown: float:
	get: return _curse_chest_state.curse_cooldown
	set(value): _curse_chest_state.curse_cooldown = value
var curse_windup_timer: float:
	get: return _curse_chest_state.curse_windup_timer
	set(value): _curse_chest_state.curse_windup_timer = value
var curse_throw_progress: float:
	get: return _curse_chest_state.curse_throw_progress
	set(value): _curse_chest_state.curse_throw_progress = value
var curse_throw_start: Vector2:
	get: return _curse_chest_state.curse_throw_start
	set(value): _curse_chest_state.curse_throw_start = value
var curse_throw_pos: Vector2:
	get: return _curse_chest_state.curse_throw_pos
	set(value): _curse_chest_state.curse_throw_pos = value
var curse_target: Vector2:
	get: return _curse_chest_state.curse_target
	set(value): _curse_chest_state.curse_target = value
var curse_pos: Vector2:
	get: return _curse_chest_state.curse_pos
	set(value): _curse_chest_state.curse_pos = value
var curse_lifetime: float:
	get: return _curse_chest_state.curse_lifetime
	set(value): _curse_chest_state.curse_lifetime = value
var curse_open_timer: float:
	get: return _curse_chest_state.curse_open_timer
	set(value): _curse_chest_state.curse_open_timer = value
var curse_reverse_timer: float:
	get: return _curse_chest_state.curse_reverse_timer
	set(value): _curse_chest_state.curse_reverse_timer = value
var curse_smoke: Array:
	get: return _curse_chest_state.curse_smoke
	set(value): _curse_chest_state.curse_smoke = value
var curse_explosion_timer: float:
	get: return _curse_chest_state.curse_explosion_timer
	set(value): _curse_chest_state.curse_explosion_timer = value
var curse_explosion_particles: Array:
	get: return _curse_chest_state.curse_explosion_particles
	set(value): _curse_chest_state.curse_explosion_particles = value
var curse_nudge_vx: float:
	get: return _curse_chest_state.curse_nudge_vx
	set(value): _curse_chest_state.curse_nudge_vx = value
var curse_wobble_angle: float:
	get: return _curse_chest_state.curse_wobble_angle
	set(value): _curse_chest_state.curse_wobble_angle = value
var curse_wobble_vel: float:
	get: return _curse_chest_state.curse_wobble_vel
	set(value): _curse_chest_state.curse_wobble_vel = value

var overdrive_active: bool:
	get:
		return _psychoball_state.overdrive_active
	set(value):
		_psychoball_state.overdrive_active = value
var psycho_cooldown: float:
	get:
		return _psychoball_state.psycho_cooldown
	set(value):
		_psychoball_state.psycho_cooldown = value
var overdrive_timer: float:
	get:
		return _psychoball_state.overdrive_timer
	set(value):
		_psychoball_state.overdrive_timer = value
var overdrive_flash_timer: float:
	get:
		return _psychoball_state.overdrive_flash_timer
	set(value):
		_psychoball_state.overdrive_flash_timer = value
var psycho_bg_timer: float:
	get:
		return _psychoball_state.psycho_bg_timer
	set(value):
		_psychoball_state.psycho_bg_timer = value
var overdrive_trails: Array:
	get:
		return _psychoball_state.overdrive_trails
	set(value):
		_psychoball_state.overdrive_trails = value
var psycho_neutralize_particles: Array:
	get:
		return _psychoball_state.psycho_neutralize_particles
	set(value):
		_psychoball_state.psycho_neutralize_particles = value
var psychoball_hitstop_timer: float:
	get:
		return _psychoball_state.psychoball_hitstop_timer
	set(value):
		_psychoball_state.psychoball_hitstop_timer = value

var tail_whip_active: bool:
	get:
		return _tail_whip_state.tail_whip_active
	set(value):
		_tail_whip_state.tail_whip_active = value
var tail_whip_timer: float:
	get:
		return _tail_whip_state.tail_whip_timer
	set(value):
		_tail_whip_state.tail_whip_timer = value
var tail_whip_cooldown: float:
	get:
		return _tail_whip_state.tail_whip_cooldown
	set(value):
		_tail_whip_state.tail_whip_cooldown = value
var tail_hit_ball: bool:
	get:
		return _tail_whip_state.tail_hit_ball
	set(value):
		_tail_whip_state.tail_hit_ball = value
var tail_curve_active: bool:
	get:
		return _tail_whip_state.tail_curve_active
	set(value):
		_tail_whip_state.tail_curve_active = value
var tail_curve_timer: float:
	get:
		return _tail_whip_state.tail_curve_timer
	set(value):
		_tail_whip_state.tail_curve_timer = value
var tail_curve_direction: int:
	get:
		return _tail_whip_state.tail_curve_direction
	set(value):
		_tail_whip_state.tail_curve_direction = value
var tail_whip_target: Vector2:
	get:
		return _tail_whip_state.tail_whip_target
	set(value):
		_tail_whip_state.tail_whip_target = value
var tail_has_target: bool:
	get:
		return _tail_whip_state.tail_has_target
	set(value):
		_tail_whip_state.tail_has_target = value
var tail_points: Array[Vector2]:
	get:
		return _tail_whip_state.tail_points
	set(value):
		_tail_whip_state.tail_points = value
var tail_hit_bursts: Array:
	get:
		return _tail_whip_state.tail_hit_bursts
	set(value):
		_tail_whip_state.tail_hit_bursts = value

var kuromi_petrified: bool:
	get: return _kuromi_awakening_state.kuromi_petrified
	set(value): _kuromi_awakening_state.kuromi_petrified = value
var kuromi_awakening: bool:
	get: return _kuromi_awakening_state.kuromi_awakening
	set(value): _kuromi_awakening_state.kuromi_awakening = value
var kuromi_awakening_timer: float:
	get: return _kuromi_awakening_state.kuromi_awakening_timer
	set(value): _kuromi_awakening_state.kuromi_awakening_timer = value
var kuromi_awakening_explosion_spawned: bool:
	get: return _kuromi_awakening_state.kuromi_awakening_explosion_spawned
	set(value): _kuromi_awakening_state.kuromi_awakening_explosion_spawned = value
var kuromi_awakened: bool:
	get: return _kuromi_awakening_state.kuromi_awakened
	set(value): _kuromi_awakening_state.kuromi_awakened = value

var prism_particles: Array:
	get: return _prism_burst_state.prism_particles
	set(value): _prism_burst_state.prism_particles = value

var kuromi_eating_active: bool:
	get: return _kuromi_eating_state.kuromi_eating_active
	set(value): _kuromi_eating_state.kuromi_eating_active = value
var kuromi_eating_timer: float:
	get: return _kuromi_eating_state.kuromi_eating_timer
	set(value): _kuromi_eating_state.kuromi_eating_timer = value
var kuromi_eating_cooldown: float:
	get: return _kuromi_eating_state.kuromi_eating_cooldown
	set(value): _kuromi_eating_state.kuromi_eating_cooldown = value
var kuromi_ball_entered: bool:
	get: return _kuromi_eating_state.kuromi_ball_entered
	set(value): _kuromi_eating_state.kuromi_ball_entered = value
var kuromi_spit_angle: float:
	get: return _kuromi_eating_state.kuromi_spit_angle
	set(value): _kuromi_eating_state.kuromi_spit_angle = value
var kuromi_has_spit_angle: bool:
	get: return _kuromi_eating_state.kuromi_has_spit_angle
	set(value): _kuromi_eating_state.kuromi_has_spit_angle = value
var kuromi_mouth_direction: float:
	get: return _kuromi_eating_state.kuromi_mouth_direction
	set(value): _kuromi_eating_state.kuromi_mouth_direction = value
var kuromi_mouth_open: float:
	get: return _kuromi_eating_state.kuromi_mouth_open
	set(value): _kuromi_eating_state.kuromi_mouth_open = value
var kuromi_chewing_phase: float:
	get: return _kuromi_eating_state.kuromi_chewing_phase
	set(value): _kuromi_eating_state.kuromi_chewing_phase = value
var kuromi_tongue_extended: float:
	get: return _kuromi_eating_state.kuromi_tongue_extended
	set(value): _kuromi_eating_state.kuromi_tongue_extended = value
var kuromi_tongue_angle: float:
	get: return _kuromi_eating_state.kuromi_tongue_angle
	set(value): _kuromi_eating_state.kuromi_tongue_angle = value
var kuromi_tongue_wrap_phase: float:
	get: return _kuromi_eating_state.kuromi_tongue_wrap_phase
	set(value): _kuromi_eating_state.kuromi_tongue_wrap_phase = value
var kuromi_ball_tongue_pos: Vector2:
	get: return _kuromi_eating_state.kuromi_ball_tongue_pos
	set(value): _kuromi_eating_state.kuromi_ball_tongue_pos = value
var kuromi_ball_on_tongue: bool:
	get: return _kuromi_eating_state.kuromi_ball_on_tongue
	set(value): _kuromi_eating_state.kuromi_ball_on_tongue = value
var kuromi_eat_source_pos: Vector2:
	get: return _kuromi_eating_state.kuromi_eat_source_pos
	set(value): _kuromi_eating_state.kuromi_eat_source_pos = value
var kuromi_swallow_sound_played: bool:
	get: return _kuromi_eating_state.kuromi_swallow_sound_played
	set(value): _kuromi_eating_state.kuromi_swallow_sound_played = value
var kuromi_spit_sound_played: bool:
	get: return _kuromi_eating_state.kuromi_spit_sound_played
	set(value): _kuromi_eating_state.kuromi_spit_sound_played = value
var kuromi_eating_particles: Array:
	get: return _kuromi_eating_state.kuromi_eating_particles
	set(value): _kuromi_eating_state.kuromi_eating_particles = value
var kuromi_spit_trail: Array:
	get: return _kuromi_eating_state.kuromi_spit_trail
	set(value): _kuromi_eating_state.kuromi_spit_trail = value
var kuromi_spit_trail_phase: float:
	get: return _kuromi_eating_state.kuromi_spit_trail_phase
	set(value): _kuromi_eating_state.kuromi_spit_trail_phase = value
var kuromi_spit_trail_frame: float:
	get: return _kuromi_eating_state.kuromi_spit_trail_frame
	set(value): _kuromi_eating_state.kuromi_spit_trail_frame = value
