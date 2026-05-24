extends RefCounted

const CommandoFirearmFireResultState := preload("res://scripts/characters/commando_firearm_fire_result_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")

const TIMER_FIELDS := [
	"slingshot_control_lock_frames",
	"pistol_cooldown_frames",
	"pistol_control_lock_frames",
	"ak47_fire_interval_frames",
	"bazooka_cooldown_frames",
	"bazooka_control_lock_frames",
	"bazooka_fire_animation_frames",
	"bazooka_firing_pose_frames",
	"bazooka_muzzle_flash_frames",
	"net_gun_cooldown_frames",
	"net_gun_control_lock_frames",
	"net_gun_throw_pose_frames",
	"net_gun_harpoon_flash_frames",
	"bowling_trap_cooldown_frames",
	"bowling_trap_control_lock_frames",
	"bowling_trap_install_pose_frames",
	"suicide_drone_cooldown_frames",
	"pistol_post_fire_animation_frames",
	"weapon_fire_sheet_timer_frames",
]


static func advance_runtime_timers(
	target: Object,
	step: float,
	ak47_recoil_recovery_per_frame: float
) -> void:
	if target == null:
		return
	var safe_step: float = max(0.0, step)
	if safe_step <= 0.0:
		return
	for field_value in TIMER_FIELDS:
		var field_name := str(field_value)
		target.set(field_name, max(0.0, float(target.get(field_name)) - safe_step))
	if not bool(target.get("ak47_trigger_held")):
		target.set(
			"ak47_recoil_accumulation",
			max(0.0, float(target.get("ak47_recoil_accumulation")) - ak47_recoil_recovery_per_frame * safe_step)
		)
	if float(target.get("weapon_fire_sheet_timer_frames")) <= 0.0:
		target.set("weapon_fire_sheet_id", "")
		target.set("weapon_fire_sheet_max_frames", 0.0)


static func advance_pending_pistol_fire(
	target: Object,
	config: Dictionary,
	step: float,
	pending_geometry_keys: Array,
	base_weapon_id: String
) -> Dictionary:
	if target == null:
		return {}
	var safe_step: float = max(0.0, step)
	if safe_step <= 0.0:
		return {}
	var fire_delay_frames: float = float(target.get("pistol_fire_delay_frames"))
	if fire_delay_frames <= 0.0:
		return {}
	var pending_config: Dictionary = CommandoFirearmValueUtils.get_dict(target.get("pistol_pending_config"))
	CommandoFirearmValueUtils.refresh_pending_fire_geometry(
		pending_config,
		config,
		pending_geometry_keys
	)
	fire_delay_frames = max(0.0, fire_delay_frames - safe_step)
	target.set("pistol_fire_delay_frames", fire_delay_frames)
	var weapon_id: String = str(target.get("pistol_pending_weapon_id"))
	if weapon_id == "":
		weapon_id = base_weapon_id
	if fire_delay_frames > 0.0:
		return {
			"pending": true,
			"result": CommandoFirearmFireResultState.build_pistol_shot_pending_result(
				weapon_id,
				fire_delay_frames,
				float(target.get("pistol_control_lock_frames"))
			),
		}
	var shot_config: Dictionary = pending_config.duplicate(true)
	if shot_config.is_empty():
		shot_config = config
	pending_config.clear()
	target.set("pistol_pending_config", pending_config)
	target.set("pistol_pending_weapon_id", "")
	return {
		"ready": true,
		"weapon_id": weapon_id,
		"shot_config": shot_config,
		"result": CommandoFirearmFireResultState.build_pistol_delayed_fire_result(
			weapon_id,
			float(target.get("pistol_cooldown_frames")),
			float(target.get("pistol_control_lock_frames"))
		),
	}
