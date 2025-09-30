"""레거시 전역 상태를 GameLoop 상태에 동기화하기 위한 브릿지."""
from __future__ import annotations

from contextlib import contextmanager
from types import ModuleType
from typing import Any, Iterable, MutableMapping, Sequence, Set

_MISSING = object()


PLAYER_KEYS: Set[str] = {
    "LONG_BOOST_DURATION", "LONG_BOOST_TRANSITION_TIME", "PADDLE_WIDTH", "PLAYER", "acceleration_active", "acceleration_flash_particles", "acceleration_height_bonus", "acceleration_skill_level",
    "aipill_active", "ball_angle", "ball_vel", "ball_x", "ball_y", "bazooka_recoil_direction", "bazooka_recoil_strength", "bazooka_recoil_timer",
    "blacksmith_shield_swing_active", "blacksmith_shield_swing_timer", "blacksmith_turret_active", "blacksmith_turret_blueprint_active", "blacksmith_turret_blueprint_rect", "blacksmith_turret_build_progress", "blacksmith_turret_manual_cooldown", "blacksmith_turret_partial_drain",
    "blacksmith_turret_projectiles", "blacksmith_turret_state", "blacksmith_walk_direction", "blacksmith_walking_active", "blacksmith_walking_timer", "chapter4_dialogue_completed", "chapter4_first_hit_after_dialogue", "chapter4_power_helper_shown",
    "chapter4_power_helper_timer", "chapter4_serve_reminder_active", "chapter4_serve_reminder_timer", "current_speed", "current_stage", "dashholder_obtained", "flare_throw_timer", "flare_throwing",
    "gauge_charge_animation_timer", "gravitybelt_obtained", "grenade_throw_timer", "grenade_throwing", "half_dash_effect_timer", "half_dash_used_flag", "hermes_star_particles", "hit_animation_active",
    "hit_animation_timer", "is_danger_sensor_dash", "is_half_dash_active", "is_player_serve", "is_waiting_for_serve", "kuromi_spit_trail_active", "kuromi_spit_trail_positions", "last_hit_by",
    "last_paddle_hit_time", "last_paddle_x", "last_wall_hit", "legendary_manager", "long_boost_active", "long_boost_animating", "long_boost_growing", "long_boost_scale", "long_boost_shrinking", "long_boost_target_scale", "long_boost_timer",
    "molotov_throw_timer", "molotov_throwing", "optimus_walking_active", "optimus_walking_timer", "player_burn_effect", "player_burn_timer", "player_collision_cooldown", "player_collision_handled",
    "player_flame_zone_knockback_cooldown", "player_flame_zone_knockback_vel", "player_in_flame_zone", "player_knockback_vel", "player_knockback_y", "player_missile_knockback_vel", "player_missile_stunned_timer", "player_slow_timer",
    "player_sound_cooldown", "player_stun_immunity_timer", "player_stunned_timer", "player_up_pressed", "poseidon_dash_pending", "poseidon_dash_x", "poseidon_dash_y", "power_smashing_direction",
    "recent_dash_success_window", "recent_dash_time", "recent_half_dash_time", "rolling_active", "rolling_charge_timer", "rolling_charges",
    "rolling_consecutive_count", "rolling_consecutive_timer", "rolling_cooldown", "rolling_dash_available_timer", "rolling_direction", "rolling_speed", "rolling_stun_timer", "rolling_timer",
    "round_start_time", "selected_character_type", "serve_completed_timer", "short_shot_active", "short_shot_counter_pending", "short_shot_counter_window", "short_shot_current_angle", "short_shot_curve_elapsed_frames",
    "short_shot_curve_started", "short_shot_extra_vertical_frames", "short_shot_original_speed", "short_shot_speed", "short_shot_target_angle", "short_shot_target_vx", "short_shot_target_vy", "short_shot_target_y",
    "short_shot_timer", "short_shot_vertical_timer", "smasher_hit_pose_timer", "smasher_left_raise_timer", "smasher_shield_raise_timer", "smasher_walking_active", "smasher_walking_timer", "soldier_control_lock_timer",
    "soldier_gun_cooldown", "soldier_gun_drawn", "soldier_right_hook_active", "soldier_right_hook_phase", "soldier_right_hook_timer", "soldier_swing_active", "soldier_swing_timer", "soldier_walking_active",
    "soldier_walking_timer", "special_active", "special_gauge", "special_gauge_max", "special_ready", "speedboots_obtained", "speedgear_obtained", "stage5_boss_hurt_active",
    "stage5_boss_hurt_timer", "stopwatch_active", "stopwatch_original_ball_vel", "stopwatch_recovery_timer", "token_states", "tutorial_boss_returned", "tutorial_chapter1_max_gauge", "tutorial_chapter2_max_gauge",
    "tutorial_consecutive_dash_count", "tutorial_consecutive_dash_pending", "tutorial_current_chapter", "tutorial_dash_already_counted", "tutorial_dash_completion_dialogue_shown", "tutorial_dash_count", "tutorial_dash_counter_active", "tutorial_dash_helper_active",
    "tutorial_dash_helper_start_time", "tutorial_dash_token_dialogue_shown", "tutorial_displayed_drive_count", "tutorial_displayed_left_drive_count", "tutorial_displayed_power_count", "tutorial_displayed_right_drive_count", "tutorial_drive_chapter_max_gauge", "tutorial_drive_completion_dialogue_shown",
    "tutorial_drive_count", "tutorial_drive_counter_active", "tutorial_drive_helper_dialogue_shown", "tutorial_drive_practice_shown", "tutorial_drive_reminder_active", "tutorial_drive_reminder_timer", "tutorial_gauge_tutorial_shown", "tutorial_half_dash_count",
    "tutorial_half_dash_pending", "tutorial_hit_counter_celebration", "tutorial_hit_counter_celebration_timer", "tutorial_left_drive_count", "tutorial_needs_dash_practice", "tutorial_needs_drive_practice", "tutorial_needs_power_practice", "tutorial_pause_for_dialogue",
    "tutorial_player_hit_count", "tutorial_power_center_done", "tutorial_power_completion_dialogue_shown", "tutorial_power_count", "tutorial_power_counter_active", "tutorial_power_helper_dialogue_shown", "tutorial_power_left_done", "tutorial_power_practice_shown",
    "tutorial_power_reminder_active", "tutorial_power_reminder_timer", "tutorial_power_right_done", "tutorial_practice_mode", "tutorial_right_drive_count", "tutorial_saved_ball_vel", "tutorial_serve_reminder_active", "tutorial_speed_dialogue_shown",
    "tutorial_token_just_added", "wall_bounce_count", "wall_installing"
}

BALL_KEYS: Set[str] = {
    "PADDLE_WIDTH", "acceleration_active", "acceleration_height_bonus", "aipill_active", "angle_correction_strength", "ball_angle", "ball_boost_decay_rate", "ball_impact_boost",
    "ball_min_boost", "ball_spin_decay", "ball_spin_direction", "ball_spin_strength", "ball_vel", "boss_collision_cooldown", "boss_current_health", "boss_fail_timer",
    "boss_fire_hit_timer", "boss_hit_animation_active", "boss_hit_animation_timer", "boss_hit_timer", "boss_knockback_timer", "boss_knockback_vel", "boss_red_intensity", "boss_special_gauge",
    "boss_special_gauge_stage4", "boss_special_ready", "boss_special_ready_stage4", "boss_speed_boost_timer", "boss_stun_timer", "boss_stunned_after_whip", "boss_stunned_after_whip_timer", "boss_stunned_timer",
    "boss_throw_timer", "boss_throwing", "danger_sensor_auto_dash_cooldown", "danger_sensor_last_auto_dash_time", "danger_sensor_obtained", "dashholder_obtained", "deuce_losses", "deuce_wins",
    "drive_active", "drive_ball_active", "drive_hit_boss", "drive_speed_increase", "drive_spin_speed", "fireball_cooldown", "fireball_last_cast", "fireball_speed",
    "fireballs", "flame_particles", "flame_trail_active", "flame_trail_base_vel", "flame_trail_phase", "flame_trail_positions", "flame_trail_rng", "flame_trail_start_time",
    "flame_trail_timer", "game_state", "gauge_charge_animation_amount", "gauge_charge_animation_timer", "half_dash_effect_timer", "hit_animation_active", "hit_animation_timer", "hongryun_hit_count",
    "hongryun_ready", "horizontal_bounce_count", "horizontal_movement_timer", "horizontal_threshold", "is_danger_sensor_dash", "is_half_dash_active", "is_waiting_for_serve", "kuromi_spit_trail_active",
    "kuromi_spit_trail_color_phase", "kuromi_spit_trail_positions", "last_hit_by", "last_paddle_hit_time", "last_tears_cast_time", "last_wall_hit", "magnet_curve_angle", "max_horizontal_time",
    "meditation_active", "meditation_angle", "meditation_timer", "mega_smashing_active", "mega_smashing_bonus_applied", "mega_smashing_boss_defense_count", "mega_smashing_ghost_scatter", "mega_smashing_ghost_scatter_time",
    "mega_smashing_ghosts", "mega_smashing_meteor_trail", "original_speed", "player_burn_effect", "player_burn_timer", "player_collision_cooldown", "player_collision_handled", "player_knockback_vel",
    "player_knockback_y", "player_last_shot_speed", "player_sound_cooldown", "player_stunned_timer", "power_smashing_arc_strength", "power_smashing_boost_duration", "power_smashing_direction", "power_smashing_freeze_active",
    "power_smashing_initial_boost", "power_smashing_original_speed", "power_smashing_parabola_active", "power_smashing_rng", "power_smashing_start_time", "power_smashing_target_speed", "quake_last_used_time", "ragnarok_speed_boost_active",
    "ragnarok_stun_attempted_this_rally", "ragnarok_stun_pending", "rolling_active", "rolling_charge_timer", "rolling_charges", "rolling_direction", "rolling_stun_timer", "rolling_timer",
    "round_losses", "round_wins", "screen_shake_intensity", "screen_shake_timer", "short_shot_active", "short_shot_counter_pending", "short_shot_counter_window", "short_shot_current_angle",
    "short_shot_curve_elapsed_frames", "short_shot_curve_started", "short_shot_extra_vertical_frames", "short_shot_original_speed", "short_shot_speed", "short_shot_target_angle", "short_shot_target_vx", "short_shot_target_vy",
    "short_shot_target_y", "short_shot_timer", "short_shot_vertical_timer", "slow_ball_timer", "soldier_right_hook_active", "soldier_right_hook_phase", "soldier_right_hook_timer", "soldier_swing_active",
    "soldier_swing_timer", "special_active", "special_gauge", "special_ready", "speed_defense_active", "speed_defense_checked", "speed_defense_timer", "stage4_magnetic_active",
    "stage4_magnetic_radius", "stage4_magnetic_timer", "stage6_barrier_flash_timer", "stage6_boss_hit_flash", "stage6_boss_hit_timer", "stopwatch_active", "stopwatch_original_ball_vel", "stopwatch_recovery_timer",
    "tutorial_boss_return_dialogue_shown", "tutorial_boss_returned", "tutorial_consecutive_dash_count", "tutorial_consecutive_dash_pending", "tutorial_dash_counter_active", "tutorial_gauge_tutorial_shown", "tutorial_half_dash_count", "tutorial_half_dash_pending",
    "tutorial_pause_for_dialogue", "tutorial_player_hit_count", "tutorial_player_returned_ball", "tutorial_practice_mode", "tutorial_saved_ball_vel", "tutorial_speed_dialogue_shown", "wall_bounce_count", "walls",
    "whip_active", "whip_angle", "whip_deactivation_active", "whip_deactivation_timer", "whip_hit_by_player", "whip_original_ball_speed", "whip_rotation_speed"
}

DRAW_KEYS: Set[str] = {
    "HONGRYUN_MAX_HITS", "PADDLE_WIDTH", "ball_angle", "bazooka_screen_shake_timer", "blacksmith_build_menu_active", "blacksmith_divine_stone_state", "blacksmith_down_hold_frames", "blacksmith_hammer_swing_active",
    "blacksmith_hammer_swing_phase", "blacksmith_shield_swing_active", "blacksmith_shield_swing_timer", "blacksmith_turret_active", "blacksmith_turret_blueprint_active", "blacksmith_turret_blueprint_rect", "blacksmith_turret_build_progress", "blacksmith_turret_projectiles",
    "blacksmith_turret_state", "boss_hit_animation_active", "boss_hit_animation_timer", "boss_prev_x", "boss_throw_timer", "boss_throwing", "boss_trail", "dash_afterimages",
    "earthquake_offset_x", "earthquake_offset_y", "frame_count", "grenade_shake_timer", "hangar_door_open", "hangar_door_timer", "hermes_star_particles", "hit_animation_active",
    "hit_animation_timer", "hongryun_hit_count", "interceptor_cooldown", "interceptor_launch_queue", "interceptor_launch_time", "interceptor_launching", "interceptors", "laser_beam_duration",
    "laser_cannon_active", "laser_cannon_angle", "laser_charge_start", "laser_charging", "laser_cooldown", "laser_rotating_mode", "laser_rotation_direction", "laser_rotation_range",
    "laser_rotation_speed", "last_laser_time", "last_missile_time", "last_shield_time", "long_boost_active", "long_boost_animating", "long_boost_animation_step", "long_boost_growing",
    "long_boost_shrinking", "mega_smashing_meteor_trail", "perfect_timing_active", "perfect_timing_frame_count", "perfect_timing_indicator_active", "perfect_timing_window", "player_missile_invulnerable_time", "player_missile_stunned_timer",
    "player_stun_end_time", "player_stunned", "power_smashing_particles", "power_smashing_trails", "quake_offset_y", "rainbow_index", "rolling_active", "rolling_direction",
    "rolling_timer", "shield_antenna_active", "shield_antenna_cooldown", "shield_antenna_timer", "shield_duration", "shield_fade_alpha", "shield_position", "short_shot_counter_window",
    "smasher_hit_pose_timer", "smasher_left_raise_timer", "smasher_pending_contact_offset", "smasher_shield_raise_timer", "special_gauge", "stage4_magnetic_active", "stage5_boss_hurt_active", "stage5_boss_hurt_timer",
    "tear_particles", "turret_angles", "turret_missiles", "walls"
}

BOSS_KEYS: Set[str] = {
    "BOSS_ACCELERATION", "BOSS_DECELERATION", "BOSS_INSTANT_STOP_DECELERATION", "BOSS_MAX_SPEED", "BOSS_SPEED", "SPEED_DEFENSE_INTERVAL", "ball_impact_boost", "ball_vel",
    "boss_current_speed", "boss_fail_timer", "boss_fake_during_player_serve", "boss_fake_move", "boss_fake_start_time", "boss_knockback_distance", "boss_knockback_timer", "boss_knockback_vel",
    "boss_speed_boost_timer", "boss_stun_timer", "boss_stunned_after_whip", "boss_stunned_timer", "boss_throw_timer", "boss_throwing", "fireball_cooldown", "fireball_last_cast",
    "head_shot_active", "head_shot_timer", "is_player_serve", "is_waiting_for_serve", "ragnarok_shock_playing", "ragnarok_stun_pending", "serve_grace_period", "speed_defense_active",
    "speed_defense_last_activation", "speed_defense_timer", "stopwatch_active", "stopwatch_timer", "wait_delay", "waiting_start_time", "whip_deactivation_active"
}

LEGACY_STATE_KEYS: Set[str] = set().union(PLAYER_KEYS, BALL_KEYS, DRAW_KEYS, BOSS_KEYS)


def _ensure_store(state: Any) -> dict:
    store = getattr(state, "legacy_globals", None)
    if store is None:
        store = {}
        setattr(state, "legacy_globals", store)
    return store


def _get(namespace: Any, key: str) -> Any:
    if isinstance(namespace, MutableMapping):
        return namespace.get(key, _MISSING)
    if isinstance(namespace, ModuleType):
        return getattr(namespace, key, _MISSING)
    return getattr(namespace, key, _MISSING)


def _set(namespace: Any, key: str, value: Any) -> None:
    if isinstance(namespace, MutableMapping):
        namespace[key] = value
        return
    setattr(namespace, key, value)


def _sync(state: Any, namespace: Any, keys: Sequence[str] | None, *, direction: str) -> None:
    if namespace is None:
        return
    store = _ensure_store(state)
    selected = keys or LEGACY_STATE_KEYS
    if direction == "to_namespace":
        for key in selected:
            if key in store:
                _set(namespace, key, store[key])
            else:
                value = _get(namespace, key)
                if value is not _MISSING:
                    store[key] = value
    else:
        for key in selected:
            value = _get(namespace, key)
            if value is not _MISSING:
                store[key] = value


def sync_state_to_namespace(state: Any, namespace: Any, keys: Sequence[str] | None = None) -> None:
    _sync(state, namespace, keys, direction="to_namespace")


def sync_namespace_to_state(state: Any, namespace: Any, keys: Sequence[str] | None = None) -> None:
    _sync(state, namespace, keys, direction="to_state")


def prime_store_from_namespace(state: Any, namespace: Any, keys: Iterable[str] | None = None) -> None:
    if namespace is None:
        return
    store = _ensure_store(state)
    selected = keys or LEGACY_STATE_KEYS
    for key in selected:
        if key in store:
            continue
        value = _get(namespace, key)
        if value is not _MISSING:
            store[key] = value


def sync_player_state_to_namespace(state: Any, namespace: Any) -> None:
    sync_state_to_namespace(state, namespace, PLAYER_KEYS)


def sync_namespace_player_state(state: Any, namespace: Any) -> None:
    sync_namespace_to_state(state, namespace, PLAYER_KEYS)


def sync_ball_state_to_namespace(state: Any, namespace: Any) -> None:
    sync_state_to_namespace(state, namespace, BALL_KEYS)


def sync_namespace_ball_state(state: Any, namespace: Any) -> None:
    sync_namespace_to_state(state, namespace, BALL_KEYS)


def sync_draw_state_to_namespace(state: Any, namespace: Any) -> None:
    sync_state_to_namespace(state, namespace, DRAW_KEYS)


def sync_namespace_draw_state(state: Any, namespace: Any) -> None:
    sync_namespace_to_state(state, namespace, DRAW_KEYS)


def sync_boss_state_to_namespace(state: Any, namespace: Any) -> None:
    sync_state_to_namespace(state, namespace, BOSS_KEYS)


def sync_namespace_boss_state(state: Any, namespace: Any) -> None:
    sync_namespace_to_state(state, namespace, BOSS_KEYS)


@contextmanager
def legacy_sync(state: Any, namespace: Any, keys: Sequence[str] | None = None):
    sync_state_to_namespace(state, namespace, keys)
    try:
        yield
    finally:
        sync_namespace_to_state(state, namespace, keys)


@contextmanager
def legacy_player_sync(state: Any, namespace: Any):
    with legacy_sync(state, namespace, PLAYER_KEYS):
        yield


@contextmanager
def legacy_ball_sync(state: Any, namespace: Any):
    with legacy_sync(state, namespace, BALL_KEYS):
        yield


@contextmanager
def legacy_draw_sync(state: Any, namespace: Any):
    with legacy_sync(state, namespace, DRAW_KEYS):
        yield


@contextmanager
def legacy_boss_sync(state: Any, namespace: Any):
    with legacy_sync(state, namespace, BOSS_KEYS):
        yield
