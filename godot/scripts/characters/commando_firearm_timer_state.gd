extends RefCounted

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
