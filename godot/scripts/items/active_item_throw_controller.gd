extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemThrowActivation := preload("res://scripts/items/active_item_throw_activation.gd")
const ActiveItemThrowBanana := preload("res://scripts/items/active_item_throw_banana.gd")
const ActiveItemThrowBoomerang := preload("res://scripts/items/active_item_throw_boomerang.gd")
const ActiveItemThrowDynamite := preload("res://scripts/items/active_item_throw_dynamite.gd")
const ActiveItemThrowGrenadeFlare := preload("res://scripts/items/active_item_throw_grenade_flare.gd")
const ActiveItemThrowMolotov := preload("res://scripts/items/active_item_throw_molotov.gd")
const ActiveItemThrowQuery := preload("res://scripts/items/active_item_throw_query.gd")
const ActiveItemThrowReset := preload("res://scripts/items/active_item_throw_reset.gd")
const ActiveItemThrowSoap := preload("res://scripts/items/active_item_throw_soap.gd")
const ActiveItemThrowSpiderMine := preload("res://scripts/items/active_item_throw_spider_mine.gd")
const ActiveItemThrowTearGas := preload("res://scripts/items/active_item_throw_tear_gas.gd")
const ActiveItemThrowWindup := preload("res://scripts/items/active_item_throw_windup.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const THROW_LOCK_MSEC := 0
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_SPEED_PER_FRAME := 12.0
const GRENADE_AIM_ERROR_DEGREES := 15.0
const GRENADE_TARGET_RANDOM_X := 30.0
const GRENADE_TARGET_REACHED_DISTANCE := 30.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const GRENADE_SCREEN_SHAKE_AMOUNT := 40.0 / 30.0
const GRENADE_SCREEN_SHAKE_INTENSITY := 9.0
const GRENADE_BOSS_STUN_FRAMES := 126.0
const GRENADE_BOSS_KNOCKBACK_FRAMES := 18.0
const GRENADE_BOSS_KNOCKBACK_POWER := 38.4
const GRENADE_BOSS_KNOCKBACK_DECAY := 0.88
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_SPEED_PER_FRAME := 9.6
const FLARE_AIM_ERROR_DEGREES := 15.0
const FLARE_TARGET_RANDOM_X := 50.0
const FLARE_TARGET_BELOW_BOSS := 40.0
const FLARE_TARGET_REACHED_DISTANCE := 10.0
const FLARE_ARMED_DELAY_FRAMES := 90.0
const FLARE_RADIUS := 180.0
const FLARE_ZONE_DURATION_FRAMES := 9.0
const FLARE_BOSS_CONFUSION_FRAMES := 180.0
const TEAR_GAS_THROW_LOCK_MSEC := 0
const TEAR_GAS_THROW_WINDUP_MSEC := 600
const TEAR_GAS_SPEED_PER_FRAME := 9.6
const TEAR_GAS_AIM_ERROR_DEGREES := 12.0
const TEAR_GAS_TARGET_RANDOM_X := 55.0
# Auto-aim lands the smoke cloud just below the boss so the billowing gas
# visibly ENVELOPS the boss (the item's whole read is "gas the boss to freeze
# its skill cooldown"). This offset must stay <= the visible cloud's upward
# reach (~TEAR_GAS_MAX_RADIUS * 0.32) or the rendered smoke tops out short of
# the boss and the pause fires on a boss the cloud never touches — the exact
# "boss not in the gas but skill-stop icon shows" bug. Sealed by
# active_item_tear_gas_tuning_smoke.
const TEAR_GAS_TARGET_BELOW_BOSS := 30.0
const TEAR_GAS_TARGET_REACHED_DISTANCE := 12.0
const TEAR_GAS_ARMED_DELAY_FRAMES := 180.0
const TEAR_GAS_ZONE_DURATION_FRAMES := 960.0
const TEAR_GAS_MAX_RADIUS := 180.0
const TEAR_GAS_MAX_RADIUS_X := 240.0
# Boss skill-cooldown pause must fire only while the boss touches the VISIBLE
# smoke. The rendered cloud fades out well inside the full expansion radius, so
# the contact test uses a tightened ellipse (matched to the visible body via a
# viewport overlay). The cloud is NOT axis-uniform: it is drawn much FLATTER
# vertically (visible half-height ~= radius_y * 0.34) than it is wide (visible
# half-width ~= radius_x * 0.74), so one shared scale cannot match both axes.
# A single 0.66 left the vertical reach (radius_y * 0.66 ~= 119px) ~2x the
# visible cloud body — and because the boss lives at the very top of the field,
# that vertical over-reach flagged the boss as "in gas" while it was rendered
# ABOVE the cloud. Keep X ~0.66 (already inside the wide visible body) and use a
# tighter Y matched to the flat vertical body.
const TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_X := 0.66
const TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_Y := 0.40
const TEAR_GAS_EXPANSION_RATE := 5.0
const TEAR_GAS_EXPANSION_RATE_X := 6.7
const TEAR_GAS_MAX_OPACITY := 0.82
const TEAR_GAS_PARTICLE_CAP := 32
const TEAR_GAS_PARTICLE_SPAWN_INTERVAL_FRAMES := 12.0
const TEAR_GAS_PARTICLE_SPAWN_COUNT := 1
const TEAR_GAS_BOSS_PAUSE_LATCH_FRAMES := 2.0
# Grace window the ⏸ pause marker stays visible after the boss LEAVES the gas.
# The gameplay pause itself is the 2-frame latch above (re-armed every frame in
# contact), so anything long here draws the marker while the cooldown is
# already running again. The original 60f (1s) let a dashing boss carry the
# icon across the field after leaving the cloud — read in-game as "skill-stop
# icon with no gas contact". Keep this a short anti-flicker grace only.
const TEAR_GAS_TEXT_DURATION_FRAMES := 12.0
const TEAR_GAS_BURST_FRAMES := 12.0
const DYNAMITE_THROW_LOCK_MSEC := 0
const DYNAMITE_THROW_WINDUP_MSEC := 500
const DYNAMITE_THROW_SPEED_PER_FRAME := 18.0
const DYNAMITE_GRAVITY_PER_FRAME := 0.15
const DYNAMITE_LAND_Y := 120.0
const DYNAMITE_PLACED_MIN_Y := 40.0
const DYNAMITE_PLACED_MAX_Y := 65.0
const DYNAMITE_COUNTDOWN_FRAMES := 420.0
const DYNAMITE_EXPLOSION_RADIUS := 350.0
const DYNAMITE_EXPLOSION_DURATION_FRAMES := 36.0
const DYNAMITE_BOSS_STUN_FRAMES := 180.0
const DYNAMITE_BOSS_KNOCKBACK_FRAMES := 18.0
const DYNAMITE_BOSS_KNOCKBACK_POWER := 104.0
const DYNAMITE_PUSH_RANGE := 80.0
const DYNAMITE_PUSH_STRENGTH := 1.8
const DYNAMITE_EXPLOSION_FIRE_PARTICLE_COUNT := 36
const DYNAMITE_EXPLOSION_SPARK_COUNT := 14
const DYNAMITE_EXPLOSION_SMOKE_CLOUD_COUNT := 5
const DYNAMITE_PARTICLE_COLOR_TYPES := ["fire", "fire", "spark", "ember"]
const MOLOTOV_THROW_LOCK_MSEC := 0
const MOLOTOV_THROW_WINDUP_MSEC := 600
const MOLOTOV_SPEED_PER_FRAME := 14.4
const MOLOTOV_AIM_ERROR_DEGREES := 15.0
const MOLOTOV_TARGET_RANDOM_X := 50.0
const MOLOTOV_TARGET_BEHIND_BOSS_Y := -10.0
const MOLOTOV_FIRE_WIDTH := 150.0
const MOLOTOV_FIRE_HEIGHT := 60.0
const MOLOTOV_FIRE_MIN_CENTER_Y := 45.0
const MOLOTOV_FIRE_DURATION_FRAMES := 150.0
const MOLOTOV_FIRE_PUSH_INTERVAL_FRAMES := 30.0
const MOLOTOV_FIRE_PUSH_FORCE := 60.0
# Smooth bounce knockback (replaces the instant teleport that read as a jitter).
# A contact arms an outward VELOCITY that decays each frame, so the boss eases
# out and is pulled back by its own AI over time instead of snapping.
const MOLOTOV_FIRE_KNOCKBACK_SPEED := 17.0  # initial outward px/frame on contact
const MOLOTOV_FIRE_KNOCKBACK_DECAY_PER_FRAME := 0.88  # per-frame velocity falloff
const MOLOTOV_FIRE_KNOCKBACK_REARM_SPEED := 3.5  # only re-bounce once residual vel drops below this
# Short re-arm cooldown: the boss is bounced again on EACH fresh contact so it can
# never power through the fire. Kept just long enough (with the velocity gate) to
# avoid a same-bounce double-fire.
const MOLOTOV_FIRE_KNOCKBACK_COOLDOWN_FRAMES := 8.0
# 화염 감속: while the boss is in (or just left) the fire it moves at this fraction
# of its speed, so its return is sluggish — no jitter, no power-through crossing.
const MOLOTOV_FIRE_SLOW_FACTOR := 0.5
const MOLOTOV_FIRE_SLOW_DURATION_FRAMES := 36.0  # slow lingers this long after leaving the fire
const MOLOTOV_FIRE_INITIAL_FLAMES := 8
const MOLOTOV_FIRE_MAX_FLAMES := 14
const MOLOTOV_FIRE_SPAWN_INTERVAL_FRAMES := 8.0
const MOLOTOV_FIRE_SPAWN_COUNT := 2
const BOOMERANG_THROW_WINDUP_MSEC := 400
const BOOMERANG_SPEED_PER_FRAME := 9.8
const BOOMERANG_RETURN_SPEED_PER_FRAME := 8.4
const BOOMERANG_STUN_FRAMES := 36.0
const BOOMERANG_KNOCKBACK_FRAMES := 15.0
const BOOMERANG_KNOCKBACK_POWER := 28.0
const BOOMERANG_ITEM_PICKUP_RADIUS := 55.0
const BOOMERANG_COLLISION_SIZE := 31.0
const BOOMERANG_MAX_TRAVEL_Y := 25.0
const BOOMERANG_CURVE_AMPLITUDE := 60.0
const BOOMERANG_HOMING_STRENGTH := 0.35
const BOOMERANG_ROTATION_SPEED := 18.0
const BOOMERANG_TRAIL_MAX_POINTS := 10
const BOOMERANG_BREAK_PARTICLE_COUNT := 22
const BOOMERANG_BREAK_PARTICLE_DURATION_SEC := 0.86
const BANANA_THROW_LOCK_MSEC := 0
const BANANA_THROW_WINDUP_MSEC := 500
const BANANA_THROW_SPEED_PER_FRAME := 20.0
const BANANA_LAND_Y := 45.0
const BANANA_LAND_DURATION_FRAMES := 180.0
const BANANA_SLIP_DURATION_FRAMES := 48.0
const BANANA_SLIP_BASE_SPEED := 15.0
const BANANA_SLIP_DECAY_SPEED := 15.0
const BANANA_COLLISION_RECT := Vector2(80.0, 50.0)
const BANANA_BURST_PARTICLE_COUNT := 6
const BANANA_PARTICLE_CAP := 12
const SOAP_THROW_LOCK_MSEC := 0
const SOAP_THROW_WINDUP_MSEC := 500
const SOAP_THROW_SPEED_PER_FRAME := 18.0
const SOAP_LAND_Y := 45.0
const SOAP_LAND_DURATION_FRAMES := 240.0
const SOAP_DEBUFF_DURATION_FRAMES := 240.0
const SOAP_BLEND_FACTOR := 0.18
const SOAP_FRICTION := 0.985
const SOAP_COLLISION_RECT := Vector2(70.0, 50.0)
const SOAP_BURST_PARTICLE_COUNT := 8
const SOAP_FOAM_SPAWN_INTERVAL_FRAMES := 7.0
const SOAP_FOAM_TRAIL_CAP := 28
const SOAP_BURST_PARTICLE_COLORS := [
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0, 1.0),
	Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 1.0),
	Color(180.0 / 255.0, 220.0 / 255.0, 1.0, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(200.0 / 255.0, 1.0, 240.0 / 255.0, 1.0),
]
const SPIDER_MINE_THROW_LOCK_MSEC := 0
const SPIDER_MINE_THROW_WINDUP_MSEC := 600
const SPIDER_MINE_SIZE := 26.0
const SPIDER_MINE_START_DELAY_FRAMES := 60.0
const SPIDER_MINE_EMBED_DELAY_FRAMES := 60.0
const SPIDER_MINE_TRAVEL_SPEED := 11.0
const SPIDER_MINE_CLIMB_SPEED := 8.4
const SPIDER_MINE_EXPLOSION_DURATION_FRAMES := 22.0
const SPIDER_MINE_SELF_DESTRUCT_WARNING_FRAMES := 120.0
const SPIDER_MINE_SELF_DESTRUCT_FAST_FRAMES := 180.0
const SPIDER_MINE_SELF_DESTRUCT_FRAMES := 240.0
const SPIDER_MINE_SLOW_DURATION_FRAMES := 180.0
const SPIDER_MINE_SLOW_FACTOR := 0.4
const SPIDER_MINE_TEXT_DURATION_FRAMES := 60.0
const SPIDER_MINE_WALL_OFFSET := 18.0
const SPIDER_MINE_FLOOR_CLEARANCE := 10.0
const SPIDER_MINE_CORNER_OFFSET_Y := 12.0
const SPIDER_MINE_FLASH_INTERVAL_FRAMES := 6.0
const SPIDER_MINE_MAX_EMBED_DEPTH := 6.0
const SPIDER_MINE_BOSS_STUN_FRAMES := 6.0
const SPIDER_MINE_BOSS_KNOCKBACK_POWER := 33.33
const SPIDER_MINE_PARTICLE_COUNT := 16
const THROW_POSE_HOLD_ANGLE_DEGREES := 30.0
const THROW_POSE_RELEASE_ANGLE_DEGREES := -20.0
const BOSS_STUN_FRAME_MSEC := 100
const COMMANDO_ARM_PREP_REDUCTION_THROW_NAMES := {
	"grenade": true,
	"flare": true,
	"dynamite": true,
	"molotov": true,
	"boomerang": true,
	"banana": true,
	"soap": true,
}

var pending_throws: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var flares: Array[Dictionary] = []
var tear_gas_projectiles: Array[Dictionary] = []
var tear_gas_zones: Array[Dictionary] = []
var dynamites: Array[Dictionary] = []
var placed_dynamites: Array[Dictionary] = []
var molotovs: Array[Dictionary] = []
var molotov_fire_zones: Array[Dictionary] = []
# Frames remaining of the molotov fire slow on the boss. Refreshed while the boss
# is in any fire zone and lingers briefly after it leaves, so the boss's return
# stays sluggish (original 화염 감속 parity) — that weight is what keeps the
# bounce from reading as a jitter and stops the boss powering through.
var molotov_fire_slow_timer_frames: float = 0.0
@warning_ignore("unused_private_class_variable")
var _molotov_zone_id_counter: int = 0
var boomerangs: Array[Dictionary] = []
var banana_projectiles: Array[Dictionary] = []
var landed_bananas: Array[Dictionary] = []
var soap_projectiles: Array[Dictionary] = []
var landed_soaps: Array[Dictionary] = []
var boomerang_particles: Array[Dictionary] = []
var banana_particles: Array[Dictionary] = []
var soap_particles: Array[Dictionary] = []
var soap_foam_trails: Array[Dictionary] = []
var spider_mines: Array[Dictionary] = []
var spider_mine_particles: Array[Dictionary] = []
var dynamite_explosions: Array[Dictionary] = []
var explosion_zones: Array[Dictionary] = []
var flare_zones: Array[Dictionary] = []
var grenade_boss_stun_timer_frames: float = 0.0
var grenade_boss_knockback_timer_frames: float = 0.0
var grenade_boss_knockback_vel: float = 0.0
var flare_boss_confused_timer_frames: float = 0.0
var tear_gas_boss_pause_timer_frames: float = 0.0
var tear_gas_boss_pause_text_timer_frames: float = 0.0
var banana_boss_slip_timer_frames: float = 0.0
var banana_boss_slip_direction: float = 0.0
var soap_boss_slip_timer_frames: float = 0.0
var soap_foam_spawn_timer_frames: float = 0.0
var spider_mine_slow_timer_frames: float = 0.0
var spider_mine_slow_text_timer_frames: float = 0.0
var throw_activation: Object = ActiveItemThrowActivation.new()
var throw_banana: Object = ActiveItemThrowBanana.new()
var throw_boomerang: Object = ActiveItemThrowBoomerang.new()
var throw_dynamite: Object = ActiveItemThrowDynamite.new()
var throw_grenade_flare: Object = ActiveItemThrowGrenadeFlare.new()
var throw_molotov: Object = ActiveItemThrowMolotov.new()
var throw_query: Object = ActiveItemThrowQuery.new()
var throw_reset: Object = ActiveItemThrowReset.new()
var throw_soap: Object = ActiveItemThrowSoap.new()
var throw_spider_mine: Object = ActiveItemThrowSpiderMine.new()
var throw_tear_gas: Object = ActiveItemThrowTearGas.new()
var throw_windup: Object = ActiveItemThrowWindup.new()


func reset() -> void:
	throw_reset.reset(self, Callable(self, "_stop_all_dynamite_fuses"))


func detonate_placed_dynamites_on_round_end(owner: Object, registry: Object) -> int:
	return int(throw_dynamite.detonate_placed_on_round_end(self, owner, registry))


func clear_round_boss_status_effects() -> void:
	grenade_boss_stun_timer_frames = 0.0
	grenade_boss_knockback_timer_frames = 0.0
	grenade_boss_knockback_vel = 0.0
	flare_boss_confused_timer_frames = 0.0
	tear_gas_boss_pause_timer_frames = 0.0
	tear_gas_boss_pause_text_timer_frames = 0.0
	banana_boss_slip_timer_frames = 0.0
	banana_boss_slip_direction = 0.0
	soap_boss_slip_timer_frames = 0.0
	spider_mine_slow_timer_frames = 0.0
	spider_mine_slow_text_timer_frames = 0.0
	molotov_fire_slow_timer_frames = 0.0
	molotovs.clear()
	molotov_fire_zones.clear()


func update(
	owner: Object,
	registry: Object,
	delta: float,
	collect_items_callback: Callable = Callable(),
	boomerang_return_callback: Callable = Callable()
) -> void:
	if not _has_runtime_update_work():
		return
	_update_throw_windups(owner, registry)
	_update_grenades(owner, registry, delta)
	_update_flares(owner, registry, delta)
	_update_tear_gas_boss_pause(delta)
	_update_tear_gas_projectiles(owner, registry, delta)
	_update_tear_gas_zones(owner, registry, delta)
	_update_dynamites(owner, registry, delta)
	_update_molotovs(owner, registry, delta)
	_update_molotov_fire_zones(owner, registry, delta)
	_update_boomerangs(owner, registry, delta, collect_items_callback, boomerang_return_callback)
	_update_bananas(owner, registry, delta)
	_update_soaps(owner, registry, delta)
	_update_spider_mines(owner, registry, delta)
	_update_boomerang_particles(delta)
	_update_banana_particles(delta)
	_update_soap_particles(delta)
	_update_soap_foam_trails(delta)
	_update_spider_mine_particles(delta)
	_update_dynamite_explosions(delta)
	_update_explosion_zones(delta)
	_update_flare_zones(delta)
	_update_grenade_boss_effect(delta)
	_update_flare_boss_confusion(delta)
	_update_banana_boss_slip(delta)
	_update_soap_boss_slip(owner, delta)
	_clear_boss_disable_effects_if_stage2_speed_defense(registry)


func activate_grenade(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_grenade(self, owner, registry)


func activate_flare(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_flare(self, owner, registry)


func activate_tear_gas(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_tear_gas(self, owner, registry)


func activate_dynamite(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_dynamite(self, owner, registry)


func activate_molotov(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_molotov(self, owner, registry)


func activate_boomerang(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_boomerang(
		self,
		owner,
		registry,
		Callable(self, "_get_boomerang_gauntlet_context")
	)


func activate_banana(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_banana(self, owner, registry)


func activate_soap(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_soap(self, owner, registry)


func activate_spider_mine(owner: Object, registry: Object) -> bool:
	return throw_activation.activate_spider_mine(
		self,
		owner,
		registry,
		Callable(self, "_deploy_spider_mine")
	)


func is_throw_windup_active() -> bool:
	return throw_query.is_throw_windup_active(self)


func cancel_pending_throw_windups() -> void:
	pending_throws.clear()


func is_player_control_locked() -> bool:
	return is_throw_windup_active()


func has_visible_effects() -> bool:
	return throw_query.has_visible_effects(self)


func has_actor_draw_context() -> bool:
	return throw_query.has_actor_draw_context(self)


func get_pending_throws() -> Array[Dictionary]:
	return pending_throws


func get_grenades() -> Array[Dictionary]:
	return grenades


func get_flares() -> Array[Dictionary]:
	return flares


func get_tear_gas_projectiles() -> Array[Dictionary]:
	return tear_gas_projectiles


func get_tear_gas_zones() -> Array[Dictionary]:
	return tear_gas_zones


func get_dynamites() -> Array[Dictionary]:
	return dynamites


func get_placed_dynamites() -> Array[Dictionary]:
	return placed_dynamites


func get_molotovs() -> Array[Dictionary]:
	return molotovs


func get_molotov_fire_zones() -> Array[Dictionary]:
	return molotov_fire_zones


func trigger_molotov_fire_zone(
	owner: Object,
	registry: Object,
	center: Vector2,
	play_feedback_audio: bool = true
) -> void:
	throw_molotov.trigger_fire_zone(self, owner, registry, center, play_feedback_audio)


func get_boomerangs() -> Array[Dictionary]:
	return boomerangs


func get_banana_projectiles() -> Array[Dictionary]:
	return banana_projectiles


func get_landed_bananas() -> Array[Dictionary]:
	return landed_bananas


func get_soap_projectiles() -> Array[Dictionary]:
	return soap_projectiles


func get_landed_soaps() -> Array[Dictionary]:
	return landed_soaps


func get_boomerang_particles() -> Array[Dictionary]:
	return boomerang_particles


func get_banana_particles() -> Array[Dictionary]:
	return banana_particles


func get_soap_particles() -> Array[Dictionary]:
	return soap_particles


func get_soap_foam_trails() -> Array[Dictionary]:
	return soap_foam_trails


func get_spider_mines() -> Array[Dictionary]:
	return spider_mines


func get_spider_mine_particles() -> Array[Dictionary]:
	return spider_mine_particles


func get_spider_mine_slow_context() -> Dictionary:
	return {
		"active": spider_mine_slow_timer_frames > 0.0,
		"text_active": spider_mine_slow_text_timer_frames > 0.0,
		"timer_frames": spider_mine_slow_timer_frames,
		"duration_frames": SPIDER_MINE_SLOW_DURATION_FRAMES,
	}


func get_dynamite_explosions() -> Array[Dictionary]:
	return dynamite_explosions


func get_explosion_zones() -> Array[Dictionary]:
	return explosion_zones


func get_flare_zones() -> Array[Dictionary]:
	return flare_zones


func get_actor_draw_context() -> Dictionary:
	if not has_actor_draw_context():
		return {}
	var throw_context: Dictionary = _build_throw_windup_draw_context() if is_throw_windup_active() else {}
	return throw_query.build_actor_draw_context(self, throw_context)


func get_boss_ai_context() -> Dictionary:
	return throw_query.build_boss_ai_context(self)


# Midline of every live molotov fire zone. boss_ai_state uses these as a
# one-sided crossing barrier applied AFTER its movement (including a 40px/frame
# dash), so the boss can never blow through the fire even though the molotov's
# own contact check runs a frame earlier in update_active_items.
#
# center_y MUST travel with center_x: molotov fire zones are reused by the
# Commando suicide drone (commando_firearm_suicide_drone_state), which spawns
# them at the drone's projectile position anywhere on the field. The barrier
# must only block when the boss is in the zone's y-band (mirroring the molotov's
# own `abs(boss_center.y - center.y) < 60` contact test), or a low fire zone
# would become a full-height vertical wall across the boss's x movement.
func get_molotov_fire_barriers() -> Array:
	var barriers: Array = []
	for zone_value in molotov_fire_zones:
		if zone_value is Dictionary:
			var center: Vector2 = zone_value.get("position", Vector2.ZERO)
			barriers.append({"center_x": center.x, "center_y": center.y})
	return barriers


func is_boss_skill_cooldown_paused() -> bool:
	return throw_query.is_boss_skill_cooldown_paused(self)


func get_commando_adjusted_windup_msec(item_name: String, base_msec: int, registry: Object) -> int:
	var clamped_base: int = max(1, int(base_msec))
	if not COMMANDO_ARM_PREP_REDUCTION_THROW_NAMES.has(item_name):
		return clamped_base
	var runtime: Object = _get_mythic_item_runtime(registry)
	if runtime != null and runtime.has_method("get_commando_arm_windup_msec"):
		return max(1, int(runtime.get_commando_arm_windup_msec(clamped_base)))
	return clamped_base


func get_commando_arm_throw_speed_multiplier(registry: Object, use_rolled_speed: bool = false) -> float:
	var runtime: Object = _get_mythic_item_runtime(registry)
	if runtime != null and runtime.has_method("get_commando_arm_throw_speed_multiplier"):
		return max(0.0, float(runtime.get_commando_arm_throw_speed_multiplier(use_rolled_speed)))
	return 1.0


func get_commando_arm_range_value(base_value: float, registry: Object) -> float:
	var runtime: Object = _get_mythic_item_runtime(registry)
	if runtime != null and runtime.has_method("get_commando_arm_range_value"):
		return max(0.0, float(runtime.get_commando_arm_range_value(base_value)))
	return max(0.0, float(base_value))


func get_commando_arm_duration_frames(base_frames: float, registry: Object) -> float:
	var runtime: Object = _get_mythic_item_runtime(registry)
	if runtime != null and runtime.has_method("get_commando_arm_duration_frames"):
		return max(0.0, float(runtime.get_commando_arm_duration_frames(base_frames)))
	return max(0.0, float(base_frames))


func is_commando_arm_equipped(registry: Object) -> bool:
	var runtime: Object = _get_mythic_item_runtime(registry)
	if runtime != null and runtime.has_method("is_commando_arm_equipped"):
		return bool(runtime.is_commando_arm_equipped())
	return false


func _is_throw_locked(registry: Object, lock_msec: int = THROW_LOCK_MSEC) -> bool:
	return throw_activation.is_throw_locked(self, registry, lock_msec)


func _update_throw_windups(owner: Object, registry: Object) -> void:
	pending_throws = throw_windup.update_pending_throws(
		pending_throws,
		owner,
		registry,
		Callable(self, "_release_pending_throw")
	)


func _release_pending_throw(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_windup.release_pending_throw(
		self,
		owner,
		pending_throw,
		registry,
		{
			"flare": Callable(self, "_throw_flare"),
			"tear_gas": Callable(self, "_throw_tear_gas"),
			"dynamite": Callable(self, "_throw_dynamite"),
			"molotov": Callable(self, "_throw_molotov"),
			"boomerang": Callable(self, "_throw_boomerang"),
			"banana": Callable(self, "_throw_banana"),
			"soap": Callable(self, "_throw_soap"),
			"spider_mine": Callable(self, "_throw_spider_mine"),
		},
		Callable(self, "_throw_grenade")
	)


func _throw_grenade(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_grenade_flare.throw_grenade(self, owner, pending_throw, registry)


func _throw_dynamite(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_dynamite.throw_dynamite(self, owner, pending_throw, registry)


func _throw_molotov(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_molotov.throw_molotov(self, owner, pending_throw, registry)


func _get_boomerang_gauntlet_context(registry: Object) -> Dictionary:
	return throw_boomerang.get_gauntlet_context(registry)


func _throw_boomerang(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_boomerang.throw_boomerang(self, owner, pending_throw, registry)


func _throw_banana(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_banana.throw_banana(self, owner, pending_throw, registry)


func _throw_soap(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_soap.throw_soap(self, owner, pending_throw, registry)


func _throw_spider_mine(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_spider_mine.throw_spider_mine(self, owner, pending_throw, registry)


func _deploy_spider_mine(owner: Object, fallback_player_pos: Vector2 = Vector2.ZERO) -> void:
	throw_spider_mine.deploy_mine(self, owner, fallback_player_pos)


func _throw_flare(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_grenade_flare.throw_flare(self, owner, pending_throw, registry)


func _throw_tear_gas(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	throw_tear_gas.throw_tear_gas(self, owner, pending_throw, registry)


func _update_grenades(owner: Object, registry: Object, delta: float) -> void:
	throw_grenade_flare.update_grenades(self, owner, registry, delta)


func _update_flares(owner: Object, registry: Object, delta: float) -> void:
	throw_grenade_flare.update_flares(self, owner, registry, delta)


func _update_tear_gas_projectiles(owner: Object, registry: Object, delta: float) -> void:
	throw_tear_gas.update_projectiles(self, owner, registry, delta)


func _update_tear_gas_zones(owner: Object, registry: Object, delta: float) -> void:
	throw_tear_gas.update_zones(self, owner, registry, delta)


func _update_dynamites(owner: Object, registry: Object, delta: float) -> void:
	throw_dynamite.update_dynamites(self, owner, registry, delta)


func _update_dynamite_projectiles(registry: Object, fps_scale: float) -> void:
	throw_dynamite.update_projectiles(self, registry, fps_scale)


func _place_dynamite(pos: Vector2, registry: Object) -> void:
	throw_dynamite.place_dynamite(self, pos, registry)


func _update_placed_dynamites(owner: Object, registry: Object, fps_scale: float) -> void:
	throw_dynamite.update_placed(self, owner, registry, fps_scale)


func _update_molotovs(owner: Object, registry: Object, delta: float) -> void:
	throw_molotov.update_molotovs(self, owner, registry, delta)


func _trigger_molotov_fire_zone(
	owner: Object,
	registry: Object,
	center: Vector2,
	play_feedback_audio: bool = true
) -> void:
	trigger_molotov_fire_zone(owner, registry, center, play_feedback_audio)


func _update_molotov_fire_zones(owner: Object, registry: Object, delta: float) -> void:
	throw_molotov.update_fire_zones(self, owner, registry, delta)


func _seed_molotov_flames(zone: Dictionary, center: Vector2, count: int, spread_x: float, spread_y: float) -> void:
	throw_molotov.seed_flames(self, zone, center, count, spread_x, spread_y)


func _update_molotov_flames(zone: Dictionary, fps_scale: float) -> void:
	throw_molotov.update_flames(zone, fps_scale)


func _update_boomerangs(
	owner: Object,
	registry: Object,
	delta: float,
	collect_items_callback: Callable,
	boomerang_return_callback: Callable
) -> void:
	throw_boomerang.update_boomerangs(
		self,
		owner,
		registry,
		delta,
		collect_items_callback,
		boomerang_return_callback
	)


func _update_bananas(owner: Object, registry: Object, delta: float) -> void:
	throw_banana.update_bananas(self, owner, registry, delta)


func _update_banana_projectiles(registry: Object, fps_scale: float) -> void:
	throw_banana.update_projectiles(self, registry, fps_scale)


func _land_banana(pos: Vector2, _registry: Object) -> void:
	throw_banana.land_banana(self, pos, _registry)


func _update_landed_bananas(owner: Object, registry: Object, fps_scale: float) -> void:
	throw_banana.update_landed(self, owner, registry, fps_scale)


func _update_soaps(owner: Object, registry: Object, delta: float) -> void:
	throw_soap.update_soaps(self, owner, registry, delta)


func _update_soap_projectiles(registry: Object, fps_scale: float) -> void:
	throw_soap.update_projectiles(self, registry, fps_scale)


func _land_soap(pos: Vector2, registry: Object) -> void:
	throw_soap.land_soap(self, pos, registry)


func _update_landed_soaps(owner: Object, registry: Object, fps_scale: float) -> void:
	throw_soap.update_landed(self, owner, registry, fps_scale)


func _update_spider_mines(owner: Object, registry: Object, delta: float) -> void:
	throw_spider_mine.update_mines(self, owner, registry, delta)


func _move_spider_mine_towards(mine: Dictionary, target: Vector2, speed: float) -> bool:
	return throw_spider_mine.move_towards(mine, target, speed)


func _get_spider_mine_rect(mine: Dictionary) -> Rect2:
	return throw_spider_mine.get_mine_rect(self, mine)


func _trigger_spider_mine_explosion(owner: Object, registry: Object, mine: Dictionary, reason: String) -> void:
	throw_spider_mine.trigger_explosion(self, owner, registry, mine, reason)


func _apply_spider_mine_boss_effect(owner: Object, impact_pos: Vector2) -> void:
	throw_spider_mine.apply_boss_effect(self, owner, impact_pos)


func _update_spider_mine_slow(delta: float) -> void:
	throw_spider_mine.update_slow(self, delta)


func _spawn_spider_mine_particles(pos: Vector2) -> void:
	throw_spider_mine.spawn_particles(self, pos)


func _update_spider_mine_particles(delta: float) -> void:
	throw_spider_mine.update_particles(self, delta)


func _play_spider_mine_setup_audio(registry: Object) -> void:
	throw_spider_mine.play_setup_audio(registry)


func _sync_spider_mine_walk_audio(registry: Object, active: bool) -> void:
	throw_spider_mine.sync_walk_audio(registry, active)


func _update_boomerang_outgoing(boomerang: Dictionary, boss_rect: Rect2, fps_scale: float) -> Vector2:
	return throw_boomerang.update_outgoing(self, boomerang, boss_rect, fps_scale)


func _update_boomerang_returning(boomerang: Dictionary, player_center: Vector2, fps_scale: float) -> Vector2:
	return throw_boomerang.update_returning(self, boomerang, player_center, fps_scale)


func _try_apply_boomerang_boss_hit(boomerang: Dictionary, boss_rect: Rect2, registry: Object) -> void:
	throw_boomerang.try_apply_boss_hit(self, boomerang, boss_rect, registry)


func _collect_boomerang_items(boomerang: Dictionary, pos: Vector2, collect_items_callback: Callable) -> void:
	throw_boomerang.collect_items(self, boomerang, pos, collect_items_callback)


func _boomerang_intersects_rect(pos: Vector2, target_rect: Rect2) -> bool:
	return throw_boomerang.intersects_rect(self, pos, target_rect)


func _add_boomerang_trail_point(boomerang: Dictionary, pos: Vector2) -> void:
	throw_boomerang.add_trail_point(self, boomerang, pos)


func _spawn_boomerang_trail_particle(pos: Vector2, gauntlet_equipped: bool = false) -> void:
	throw_boomerang.spawn_trail_particle(self, pos, gauntlet_equipped)


func _spawn_boomerang_break_particles(pos: Vector2) -> void:
	throw_boomerang.spawn_break_particles(self, pos)


func _update_boomerang_particles(delta: float) -> void:
	throw_boomerang.update_particles(self, delta)


func _get_boss_slip_direction(owner: Object) -> float:
	return throw_banana.get_boss_slip_direction(owner)


func _spawn_banana_burst_particles(pos: Vector2) -> void:
	throw_banana.spawn_burst_particles(self, pos)


func _update_banana_particles(delta: float) -> void:
	throw_banana.update_particles(self, delta)


func _spawn_soap_burst_particles(pos: Vector2) -> void:
	throw_soap.spawn_burst_particles(self, pos)


func _update_soap_particles(delta: float) -> void:
	throw_soap.update_particles(self, delta)


func _update_soap_foam_trails(delta: float) -> void:
	throw_soap.update_foam_trails(self, delta)


func _update_banana_boss_slip(delta: float) -> void:
	throw_banana.update_boss_slip(self, delta)


func _update_soap_boss_slip(owner: Object, delta: float) -> void:
	throw_soap.update_boss_slip(self, owner, delta)


func _play_boomerang_destroyed_audio(registry: Object) -> void:
	throw_boomerang.play_destroyed_audio(registry)


func _play_boomerang_returned_audio(registry: Object) -> void:
	throw_boomerang.play_returned_audio(registry)


func _play_dynamite_fuse(registry: Object) -> Variant:
	return throw_dynamite.play_fuse(registry)


func _stop_all_dynamite_fuses(registry: Object) -> void:
	throw_dynamite.stop_all_fuses(self, registry)


func _stop_dynamite_fuse(placed: Dictionary, registry: Object) -> void:
	throw_dynamite.stop_fuse(placed, registry)


func _trigger_dynamite_explosion(owner: Object, registry: Object, center: Vector2) -> void:
	throw_dynamite.trigger_explosion(self, owner, registry, center)


func _apply_dynamite_boss_effect(owner: Object, center: Vector2) -> void:
	throw_dynamite.apply_boss_effect(self, owner, center)


func _trigger_grenade_explosion(owner: Object, registry: Object, center: Vector2) -> void:
	throw_grenade_flare.trigger_grenade_explosion(self, owner, registry, center)


func _apply_grenade_boss_effect(owner: Object, center: Vector2, radius: float) -> void:
	throw_grenade_flare.apply_grenade_boss_effect(self, owner, center, radius)


func _trigger_flare_flash(owner: Object, registry: Object, center: Vector2) -> void:
	throw_grenade_flare.trigger_flare_flash(self, owner, registry, center)


func _trigger_tear_gas_zone(owner: Object, registry: Object, center: Vector2) -> void:
	throw_tear_gas.trigger_zone(self, registry, center, owner)


func _apply_flare_boss_confusion(owner: Object, center: Vector2, radius: float) -> void:
	throw_grenade_flare.apply_flare_boss_confusion(self, owner, center, radius)


func _update_explosion_zones(delta: float) -> void:
	throw_grenade_flare.update_explosion_zones(self, delta)


func _update_flare_zones(delta: float) -> void:
	throw_grenade_flare.update_flare_zones(self, delta)


func _update_grenade_boss_effect(delta: float) -> void:
	throw_grenade_flare.update_grenade_boss_effect(self, delta)


func _update_flare_boss_confusion(delta: float) -> void:
	throw_grenade_flare.update_flare_boss_confusion(self, delta)


func _clear_boss_disable_effects_if_stage2_speed_defense(registry: Object) -> void:
	throw_grenade_flare.clear_boss_disable_effects_if_stage2_speed_defense(self, registry)


func _has_runtime_update_work() -> bool:
	return (
		not pending_throws.is_empty()
		or not grenades.is_empty()
		or not flares.is_empty()
		or not tear_gas_projectiles.is_empty()
		or not tear_gas_zones.is_empty()
		or not dynamites.is_empty()
		or not placed_dynamites.is_empty()
		or not molotovs.is_empty()
		or not molotov_fire_zones.is_empty()
		or not boomerangs.is_empty()
		or not banana_projectiles.is_empty()
		or not landed_bananas.is_empty()
		or not soap_projectiles.is_empty()
		or not landed_soaps.is_empty()
		or not boomerang_particles.is_empty()
		or not banana_particles.is_empty()
		or not soap_particles.is_empty()
		or not soap_foam_trails.is_empty()
		or not spider_mines.is_empty()
		or not spider_mine_particles.is_empty()
		or not dynamite_explosions.is_empty()
		or not explosion_zones.is_empty()
		or not flare_zones.is_empty()
		or grenade_boss_stun_timer_frames > 0.0
		or grenade_boss_knockback_timer_frames > 0.0
		or abs(grenade_boss_knockback_vel) > 0.0
		or flare_boss_confused_timer_frames > 0.0
		or tear_gas_boss_pause_timer_frames > 0.0
		or tear_gas_boss_pause_text_timer_frames > 0.0
		or banana_boss_slip_timer_frames > 0.0
		or soap_boss_slip_timer_frames > 0.0
		or spider_mine_slow_timer_frames > 0.0
		or spider_mine_slow_text_timer_frames > 0.0
		# Keep updating while the molotov fire slow lingers, so its bleed-off in
		# update_fire_zones actually runs after the last fire zone expires. Without
		# this the timer freezes at its last value and the boss stays slowed forever.
		or molotov_fire_slow_timer_frames > 0.0
	)


func _is_stage2_speed_defense_boss_immune(registry: Object) -> bool:
	return throw_grenade_flare.is_stage2_speed_defense_boss_immune(registry)


func _update_tear_gas_boss_pause(delta: float) -> void:
	throw_tear_gas.update_boss_pause(self, delta)


func _update_dynamite_explosions(delta: float) -> void:
	throw_dynamite.update_explosions(self, delta)


func _build_throw_windup_draw_context() -> Dictionary:
	return throw_windup.build_draw_context(
		pending_throws,
		GRENADE_THROW_WINDUP_MSEC,
		THROW_POSE_HOLD_ANGLE_DEGREES,
		THROW_POSE_RELEASE_ANGLE_DEGREES
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_mythic_item_runtime(registry: Object) -> Object:
	return _get_instance(registry, "mythic_item_runtime")


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
