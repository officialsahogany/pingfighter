extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")
const ResultContext := preload("res://scripts/core/battle_draw_actor_result_context.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const CommandoWeaponAnchorTable := preload("res://scripts/characters/commando_weapon_anchor_table.gd")
const ViperHoverSheetOverride := preload("res://scripts/core/viper_hover_sheet_override.gd")

const PLAYER_DIRECTIONAL_WALK_FRAME_COUNT := 8
const PLAYER_DIRECTIONAL_WALK_GRID_COLS := 4
const PLAYER_DIRECTIONAL_DASH_FRAME_COUNT := 8
const PLAYER_DIRECTIONAL_DASH_GRID_COLS := 4
const PLAYER_IDLE_FRAME_COUNT := 8
const PLAYER_IDLE_GRID_COLS := 4
const PLAYER_IDLE_GRID_ROWS := 2
const BLACKSMITH_PLAYER_DRAW_SIZE := Vector2(128.0, 128.0)
const COMMANDO_IDLE_FRAME_COUNT := 8
const COMMANDO_IDLE_GRID_COLS := 4
const COMMANDO_IDLE_GRID_ROWS := 2
const BOSS_WALK_FRAME_COUNT := 16
const BOSS_WALK_GRID_COLS := 4
const PLAYER_DIRECTIONAL_ATTACK_ANIM_DURATION := 0.72
const PLAYER_LEGACY_ATTACK_ANIM_DURATION := 0.40
const BLACKSMITH_THOR_SHIELD_ANIM_SECONDS := 0.70
const BLACKSMITH_THOR_SHIELD_DEPLOY_FRAME_COUNT := 16

var character_runtime: Object = PlayerCharacterRuntime.new()
var commando_weapon_anchor_table: Object = CommandoWeaponAnchorTable.new()


func build(context: Dictionary, deps: Dictionary, perf_logger: Object = null) -> Dictionary:
	var actor_sample_start: int = _perf_begin(perf_logger)
	var current_stage: int = int(context.get("current_stage", 1))
	var character_type: String = character_runtime.normalize(context.get("selected_character_type", "smasher"))
	var is_viper: bool = character_type == PlayerCharacterRuntime.VIPER
	var is_commando: bool = character_type == PlayerCharacterRuntime.COMMANDO
	var is_smasher: bool = character_type == PlayerCharacterRuntime.SMASHER
	var is_optimus: bool = character_type == PlayerCharacterRuntime.OPTIMUS
	var is_blacksmith: bool = character_type == PlayerCharacterRuntime.BLACKSMITH
	var animation_state = deps.get("animation_state", null)
	var animation_context: Dictionary = animation_state.get_draw_context() if animation_state != null else {}
	var boss_ai_state = deps.get("boss_ai_state", null)
	var boss_dash_context: Dictionary = boss_ai_state.get_dash_draw_context() if boss_ai_state != null and boss_ai_state.has_method("get_dash_draw_context") else {}

	var whip_context: Dictionary = {}
	var spinning_top_context: Dictionary = {}
	var dalji_cooldown_context: Dictionary = {}
	var stage1_wall_flash_context: Dictionary = {}
	if current_stage == 1:
		var whip_state = deps.get("stage1_dalji_whip_skill_state", null)
		whip_context = whip_state.get_draw_context() if whip_state != null and whip_state.has_method("get_draw_context") else {}
		var spinning_top_state = deps.get("stage1_dalji_spinning_top_skill_state", null)
		spinning_top_context = spinning_top_state.get_draw_context() if spinning_top_state != null and spinning_top_state.has_method("get_draw_context") else {}
		var dalji_cooldown_state = deps.get("stage1_dalji_boss_skill_cooldown_state", null)
		dalji_cooldown_context = dalji_cooldown_state.get_hud_context() if dalji_cooldown_state != null and dalji_cooldown_state.has_method("get_hud_context") else {}
		stage1_wall_flash_context = _get_stage1_wall_flash_context(deps.get("impact_effects", null))

	var stage2_context: Dictionary = {}
	var stage2_skill_context: Dictionary = {}
	if current_stage == 2:
		var stage2_background = deps.get("stage2_pillar_background", null)
		stage2_context = stage2_background.get_actor_draw_context() if stage2_background != null and stage2_background.has_method("get_actor_draw_context") else {}
		var stage2_skill_state = deps.get("stage2_boss_skill_state", null)
		stage2_skill_context = stage2_skill_state.get_actor_draw_context() if stage2_skill_state != null and stage2_skill_state.has_method("get_actor_draw_context") else {}

	var stage3_skill_context: Dictionary = {}
	if current_stage == 3:
		var stage3_skill_state = deps.get("stage3_boss_skill_state", null)
		stage3_skill_context = stage3_skill_state.get_actor_draw_context() if stage3_skill_state != null and stage3_skill_state.has_method("get_actor_draw_context") else {}

	var stage4_map_context: Dictionary = {}
	var stage4_wall_flash_context: Dictionary = {}
	if current_stage == 4:
		var stage4_map_state = deps.get("stage4_map_state", null)
		stage4_map_context = stage4_map_state.get_actor_draw_context({
			"stage4_temple_destruction_event": deps.get("stage4_temple_destruction_event", null),
			"stage4_moon_event": deps.get("stage4_moon_event", null),
			"stage4_bird_event": deps.get("stage4_bird_event", null),
			"stage4_brazier_monk_event": deps.get("stage4_brazier_monk_event", null),
			"stage4_ponk_skill_state": deps.get("stage4_ponk_skill_state", null),
		}) if stage4_map_state != null and stage4_map_state.has_method("get_actor_draw_context") else {}
		stage4_wall_flash_context = _get_stage4_wall_flash_context(deps.get("impact_effects", null))

	var stage5_hongryun_context: Dictionary = {}
	var stage5_hongryun_fire_machine_context: Dictionary = {}
	if current_stage == 5:
		var stage5_hongryun_state = deps.get("stage5_hongryun_state", null)
		stage5_hongryun_context = stage5_hongryun_state.get_actor_draw_context() if stage5_hongryun_state != null and stage5_hongryun_state.has_method("get_actor_draw_context") else {}
		var stage5_hongryun_fire_machine_event = deps.get("stage5_hongryun_fire_machine_event", null)
		stage5_hongryun_fire_machine_context = stage5_hongryun_fire_machine_event.get_actor_draw_context() if _should_read_actor_draw_context(stage5_hongryun_fire_machine_event) else {}

	var stage6_tetriser_context: Dictionary = {}
	if current_stage == 6:
		var stage6_tetriser_state = deps.get("stage6_tetriser_state", null)
		stage6_tetriser_context = stage6_tetriser_state.get_actor_draw_context() if stage6_tetriser_state != null and stage6_tetriser_state.has_method("get_actor_draw_context") else {}

	var active_item_runtime = deps.get("active_item_runtime", null)
	var active_item_context: Dictionary = active_item_runtime.get_actor_draw_context() if _should_read_actor_draw_context(active_item_runtime) else {}
	var mythic_item_runtime = deps.get("mythic_item_runtime", null)
	var mythic_item_context: Dictionary = mythic_item_runtime.get_actor_draw_context() if _should_read_actor_draw_context(mythic_item_runtime) else {}
	var status_effect_state = deps.get("status_effect_state", null)
	var status_effect_context: Dictionary = status_effect_state.get_actor_draw_context() if status_effect_state != null and status_effect_state.has_method("get_actor_draw_context") else {}
	var player_draw_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_draw_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2.ZERO)
	var boss_current_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_draw_pos: Vector2 = _get_render_boss_pos(context, boss_current_pos)

	var warp_gate_context: Dictionary = {}
	var smasher_wheel_context: Dictionary = {}
	# Ghost-smashing possession: Mika is sucked into the ball, so the field
	# paddle is hidden while riding and streaks home on the boss return.
	var ghost_possession_paddle_hidden: bool = false
	var ghost_possession_player_override: Dictionary = {}
	if is_smasher:
		var warp_gate_state = deps.get("smasher_warp_gate_state", null)
		warp_gate_context = warp_gate_state.get_actor_draw_context(player_draw_pos, player_draw_size) if warp_gate_state != null and warp_gate_state.has_method("get_actor_draw_context") else {}
		var smasher_wheel_state = deps.get("smasher_wheel_state", null)
		var smasher_actor_current_msec: int = int(context.get("current_msec", -1))
		smasher_wheel_context = smasher_wheel_state.get_actor_draw_context(smasher_actor_current_msec) if smasher_wheel_state != null and smasher_wheel_state.has_method("get_actor_draw_context") else {}
		var power_smash_state = deps.get("power_state", null)
		if power_smash_state == null:
			power_smash_state = deps.get("smasher_power_smash_state", null)
		if power_smash_state != null and power_smash_state.has_method("is_ghost_possession_paddle_hidden"):
			ghost_possession_paddle_hidden = bool(power_smash_state.is_ghost_possession_paddle_hidden())
			ghost_possession_player_override = power_smash_state.get_ghost_possession_player_override()

	var commando_firearm_context: Dictionary = {}
	var commando_current_weapon_id: String = "pistol"
	if is_commando:
		var commando_firearm_runtime = deps.get("commando_firearm_runtime", null)
		commando_firearm_context = commando_firearm_runtime.get_actor_draw_context() if commando_firearm_runtime != null and commando_firearm_runtime.has_method("get_actor_draw_context") else {}
		var commando_weapon_controller_obj = deps.get("commando_weapon_controller", null)
		if commando_weapon_controller_obj != null and "current_weapon_id" in commando_weapon_controller_obj:
			commando_current_weapon_id = String(commando_weapon_controller_obj.current_weapon_id)

	var viper_jetpack_context: Dictionary = {}
	var viper_skill_context: Dictionary = {}
	if is_viper:
		var viper_jetpack_state = deps.get("viper_jetpack_state", null)
		viper_jetpack_context = viper_jetpack_state.get_actor_draw_context() if viper_jetpack_state != null and viper_jetpack_state.has_method("get_actor_draw_context") else {}
		var viper_skill_runtime = deps.get("viper_skill_runtime", null)
		viper_skill_context = viper_skill_runtime.get_actor_draw_context() if viper_skill_runtime != null and viper_skill_runtime.has_method("get_actor_draw_context") else {}
	_perf_end(perf_logger, "context.actor.sources", actor_sample_start)

	actor_sample_start = _perf_begin(perf_logger)
	var texture_sample_start: int = _perf_begin(perf_logger)
	var dash_context: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	var boss_result_context: Dictionary = ResultContext.get_boss_result_context(deps, current_stage)
	var result_state_active: bool = ResultContext.has_result_state(boss_result_context)
	_perf_end(perf_logger, "context.actor.textures.base", texture_sample_start)
	if result_state_active:
		texture_sample_start = _perf_begin(perf_logger)
		textures = ResultContext.sync_cached_result_textures(
			textures,
			deps.get("battle_resources", null),
			character_type,
			current_stage,
			boss_result_context
		)
		_perf_end(perf_logger, "context.actor.textures.result_cache", texture_sample_start)
	texture_sample_start = _perf_begin(perf_logger)
	var player_render_context: Dictionary = character_runtime.get_player_render_context(character_type)
	var use_smasher_textures: bool = bool(player_render_context.get("use_smasher_sprite_textures", true))
	var player_sprite_texture: Variant = _get_value(textures, "player_sprite_texture") if use_smasher_textures else null
	if is_viper:
		player_sprite_texture = _get_value(textures, "viper_player_sprite_texture")
	elif is_commando:
		player_sprite_texture = _get_value(textures, "commando_player_walk_back_sheet")
	elif is_blacksmith:
		player_sprite_texture = _get_value(textures, "blacksmith_player_idle_sheet")
	var player_walk_left_texture: Variant = _get_value(textures, "player_walk_left_texture") if use_smasher_textures else null
	var player_walk_right_texture: Variant = _get_value(textures, "player_walk_right_texture") if use_smasher_textures else null
	var player_dash_left_texture: Variant = _get_value(textures, "player_dash_left_texture") if use_smasher_textures else null
	var player_dash_right_texture: Variant = _get_value(textures, "player_dash_right_texture") if use_smasher_textures else null
	if not use_smasher_textures:
		if is_commando:
			player_walk_left_texture = _get_value(textures, "commando_player_walk_left_sheet")
			player_walk_right_texture = _get_value(textures, "commando_player_walk_right_sheet")
		elif is_viper:
			player_walk_left_texture = _get_value(textures, "viper_player_walk_left_sheet")
			player_walk_right_texture = _get_value(textures, "viper_player_walk_right_sheet")
		elif is_optimus:
			player_walk_left_texture = _get_value(textures, "optimus_player_walk_left_sheet")
			player_walk_right_texture = _get_value(textures, "optimus_player_walk_right_sheet")
		elif is_blacksmith:
			player_walk_left_texture = _get_value(textures, "blacksmith_player_walk_left_sheet")
			player_walk_right_texture = _get_value(textures, "blacksmith_player_walk_right_sheet")
			player_dash_left_texture = _get_value(textures, "blacksmith_player_dash_left_sheet")
			player_dash_right_texture = _get_value(textures, "blacksmith_player_dash_right_sheet")
	var has_player_directional_walk_sheet: bool = (use_smasher_textures or is_commando or is_viper or is_optimus or is_blacksmith) and (
		player_walk_left_texture is Texture2D
		or player_walk_right_texture is Texture2D
	)
	var has_player_directional_dash_sheet: bool = (use_smasher_textures or is_blacksmith) and (
		player_dash_left_texture is Texture2D
		or player_dash_right_texture is Texture2D
	)
	_perf_end(perf_logger, "context.actor.textures.player_core", texture_sample_start)
	texture_sample_start = _perf_begin(perf_logger)
	var commando_attack_sheet: Variant = _get_value(textures, "commando_player_attack_sheet") if is_commando else null
	var commando_pistol_fire_sheet: Variant = _get_value(textures, "commando_player_pistol_fire_sheet") if is_commando else null
	var commando_weapon_fire_state: Dictionary = _get_dict(commando_firearm_context.get("commando_firearm_weapon_fire_sheet_state", {})) if is_commando else {}
	var commando_weapon_fire_id: String = str(commando_weapon_fire_state.get("weapon_id", ""))
	var commando_weapon_fire_sheet: Variant = _get_commando_weapon_fire_sheet(textures, commando_weapon_fire_id) if is_commando else null
	var commando_weapon_fire_active: bool = (
		is_commando
		and bool(commando_weapon_fire_state.get("active", false))
		and commando_weapon_fire_sheet is Texture2D
	)
	var commando_weapon_fire_frame: int = _get_commando_weapon_fire_frame(commando_weapon_fire_state) if commando_weapon_fire_active else 0
	var pistol_state_dict: Dictionary = _get_dict(commando_firearm_context.get("commando_firearm_pistol_state", {})) if is_commando else {}
	var pistol_fire_delay_frames: float = float(pistol_state_dict.get("fire_delay_frames", 0.0))
	var pistol_fire_delay_max_frames: float = max(1.0, float(pistol_state_dict.get("fire_delay_max_frames", 1.0)))
	var pistol_post_fire_frames: float = float(pistol_state_dict.get("post_fire_animation_frames", 0.0))
	var pistol_post_fire_max_frames: float = max(1.0, float(pistol_state_dict.get("post_fire_animation_max_frames", 1.0)))
	var commando_pistol_fire_active: bool = (
		is_commando
		and commando_pistol_fire_sheet is Texture2D
		and not commando_weapon_fire_active
		and (pistol_fire_delay_frames > 0.0 or pistol_post_fire_frames > 0.0)
	)
	var has_commando_attack_sheet: bool = is_commando and commando_attack_sheet is Texture2D
	var commando_attack_active: bool = (
		has_commando_attack_sheet
		and bool(animation_context.get("player_hit_active", false))
		and not commando_weapon_fire_active
		and not commando_pistol_fire_active
	)
	var commando_pistol_fire_frame: int = 0
	if commando_pistol_fire_active:
		if pistol_fire_delay_frames > 0.0:
			# Windup phase: 24-frame delay maps onto sheet frames 0..3
			# (low-ready -> raise -> mid -> peak aim).
			var windup_progress: float = clamp(
				1.0 - pistol_fire_delay_frames / pistol_fire_delay_max_frames,
				0.0,
				1.0
			)
			commando_pistol_fire_frame = clamp(int(windup_progress * 4.0), 0, 3)
		else:
			# Post-shot phase: 18-frame window maps onto sheet frames 4..7
			# (muzzle flash -> smoke -> lower -> ready). Frame 4 fires on the
			# same tick `_play_fire_audio()` is triggered, so the visible
			# muzzle flash and gunshot.wav are aligned.
			var post_progress: float = clamp(
				1.0 - pistol_post_fire_frames / pistol_post_fire_max_frames,
				0.0,
				1.0
			)
			commando_pistol_fire_frame = clamp(4 + int(post_progress * 4.0), 4, 7)
	_perf_end(perf_logger, "context.actor.textures.commando", texture_sample_start)
	texture_sample_start = _perf_begin(perf_logger)
	var player_idle_sheet: Variant = _get_value(textures, "player_idle_back_sheet") if use_smasher_textures else null
	if not use_smasher_textures:
		if is_commando:
			player_idle_sheet = _get_value(textures, "commando_player_idle_sheet")
		elif is_viper:
			player_idle_sheet = _get_value(textures, "viper_player_idle_sheet")
		elif is_optimus:
			player_idle_sheet = _get_value(textures, "optimus_player_idle_sheet")
		elif is_blacksmith:
			player_idle_sheet = _get_value(textures, "blacksmith_player_idle_sheet")
	var has_player_idle_sheet: bool = player_idle_sheet is Texture2D
	var player_victory_sheet: Variant = _get_value(textures, "player_victory_sheet") if use_smasher_textures or is_viper or is_blacksmith else null
	var has_player_victory_sheet: bool = player_victory_sheet is Texture2D
	var player_defeat_sheet: Variant = _get_value(textures, "player_defeat_sheet") if use_smasher_textures or is_viper or is_blacksmith else null
	var has_player_defeat_sheet: bool = player_defeat_sheet is Texture2D
	var player_wheel_spin_sheet: Variant = _get_value(textures, "player_wheel_spin_sheet") if use_smasher_textures else null
	var has_player_wheel_spin_sheet: bool = player_wheel_spin_sheet is Texture2D
	var player_idle_sprite_texture: Variant = player_idle_sheet if has_player_idle_sheet else null
	if not has_player_idle_sheet:
		if use_smasher_textures:
			player_idle_sprite_texture = _get_value(textures, "player_idle_sprite_texture")
		elif is_viper:
			player_idle_sprite_texture = _get_value(textures, "viper_player_idle_sprite_texture")
	var player_hit_sprite_texture: Variant = _get_value(textures, "player_hit_sprite_texture") if use_smasher_textures else null
	var player_hit_left_strip_texture: Variant = _get_value(textures, "player_hit_left_strip_texture") if use_smasher_textures else (_get_value(textures, "viper_player_hit_left_strip_texture") if is_viper else null)
	var player_hit_right_strip_texture: Variant = _get_value(textures, "player_hit_right_strip_texture") if use_smasher_textures else (_get_value(textures, "viper_player_hit_right_strip_texture") if is_viper else null)
	var player_attack_left_sheet: Variant = _get_value(textures, "player_attack_left_sheet") if use_smasher_textures else (_get_value(textures, "viper_player_attack_left_sheet") if is_viper else (_get_value(textures, "optimus_player_attack_left_sheet") if is_optimus else (_get_value(textures, "blacksmith_player_attack_left_sheet") if is_blacksmith else null)))
	var player_attack_right_sheet: Variant = _get_value(textures, "player_attack_right_sheet") if use_smasher_textures else (_get_value(textures, "viper_player_attack_right_sheet") if is_viper else (_get_value(textures, "optimus_player_attack_right_sheet") if is_optimus else (_get_value(textures, "blacksmith_player_attack_right_sheet") if is_blacksmith else null)))
	var player_attack_sheet: Variant = _get_value(textures, "player_attack_sheet") if use_smasher_textures else null
	var blacksmith_thor_shield_deploy_sheet: Variant = _get_value(textures, "blacksmith_player_thor_shield_deploy_sheet") if is_blacksmith else null
	var has_blacksmith_thor_shield_deploy_sheet: bool = blacksmith_thor_shield_deploy_sheet is Texture2D
	var blacksmith_thor_shield_stretch_texture: Variant = _get_value(textures, "blacksmith_thor_shield_stretch_texture") if is_blacksmith else null
	var has_blacksmith_thor_shield_stretch_texture: bool = blacksmith_thor_shield_stretch_texture is Texture2D
	var blacksmith_thor_shield_open_ratio: float = _get_blacksmith_thor_shield_open_ratio(context)
	var blacksmith_thor_shield_deploy_active: bool = (
		is_blacksmith
		and has_blacksmith_thor_shield_deploy_sheet
		and (
			bool(context.get("blacksmith_umbrella_open", false))
			or bool(context.get("blacksmith_umbrella_retracting", false))
			or blacksmith_thor_shield_open_ratio > 0.001
		)
	)
	var blacksmith_thor_shield_deploy_frame: int = clamp(
		int(round(blacksmith_thor_shield_open_ratio * float(BLACKSMITH_THOR_SHIELD_DEPLOY_FRAME_COUNT - 1))),
		0,
		BLACKSMITH_THOR_SHIELD_DEPLOY_FRAME_COUNT - 1
	)
	var viper_wall_cling_left_sheet: Variant = _get_value(textures, "viper_player_wall_cling_left_sheet") if is_viper else null
	var viper_wall_cling_right_sheet: Variant = _get_value(textures, "viper_player_wall_cling_right_sheet") if is_viper else null
	var has_viper_wall_cling_sheet: bool = is_viper and (viper_wall_cling_left_sheet is Texture2D or viper_wall_cling_right_sheet is Texture2D)
	var viper_wall_flight_left_sheet: Variant = _get_value(textures, "viper_player_wall_flight_left_sheet") if is_viper else null
	var viper_wall_flight_right_sheet: Variant = _get_value(textures, "viper_player_wall_flight_right_sheet") if is_viper else null
	var has_viper_wall_flight_sheet: bool = is_viper and (viper_wall_flight_left_sheet is Texture2D or viper_wall_flight_right_sheet is Texture2D)
	var viper_flying_kick_left_sheet: Variant = _get_value(textures, "viper_player_flying_kick_left_sheet") if is_viper else null
	var viper_flying_kick_right_sheet: Variant = _get_value(textures, "viper_player_flying_kick_right_sheet") if is_viper else null
	var has_viper_flying_kick_sheet: bool = is_viper and (viper_flying_kick_left_sheet is Texture2D or viper_flying_kick_right_sheet is Texture2D)
	var viper_tumble_sheet: Variant = _get_value(textures, "viper_player_tumble_sheet") if is_viper else null
	var has_viper_tumble_sheet: bool = is_viper and viper_tumble_sheet is Texture2D
	var viper_blade_fire_sheet: Variant = _get_value(textures, "viper_player_blade_fire_sheet") if is_viper else null
	var has_viper_blade_fire_sheet: bool = is_viper and viper_blade_fire_sheet is Texture2D
	var viper_throw_sheet: Variant = _get_value(textures, "viper_player_throw_sheet") if is_viper else null
	var has_viper_throw_sheet: bool = is_viper and viper_throw_sheet is Texture2D
	var viper_hover_left_sheet: Variant = _get_value(textures, "viper_player_hover_left_sheet") if is_viper else null
	var viper_hover_right_sheet: Variant = _get_value(textures, "viper_player_hover_right_sheet") if is_viper else null
	var has_viper_hover_sheet: bool = (
		is_viper
		and (viper_hover_left_sheet is Texture2D or viper_hover_right_sheet is Texture2D)
		and not ViperHoverSheetOverride.is_hover_sheet_force_disabled()
	)
	var viper_up_kick_left_sheet: Variant = _get_value(textures, "viper_player_up_kick_left_sheet") if is_viper else null
	var viper_up_kick_right_sheet: Variant = _get_value(textures, "viper_player_up_kick_right_sheet") if is_viper else null
	var has_viper_up_kick_sheet: bool = is_viper and (viper_up_kick_left_sheet is Texture2D or viper_up_kick_right_sheet is Texture2D)
	var viper_stun_sheet: Variant = _get_value(textures, "viper_player_stun_sheet") if is_viper else null
	var has_viper_stun_sheet: bool = is_viper and viper_stun_sheet is Texture2D
	var viper_confusion_sheet: Variant = _get_value(textures, "viper_player_confusion_sheet") if is_viper else null
	var has_viper_confusion_sheet: bool = is_viper and viper_confusion_sheet is Texture2D
	var viper_venom_edge_strike_sheet: Variant = _get_value(textures, "viper_player_venom_edge_strike_sheet") if is_viper else null
	var has_viper_venom_edge_strike_sheet: bool = is_viper and viper_venom_edge_strike_sheet is Texture2D
	_perf_end(perf_logger, "context.actor.textures.extra_sheets", texture_sample_start)
	_perf_end(perf_logger, "context.actor.textures", actor_sample_start)

	actor_sample_start = _perf_begin(perf_logger)
	var has_player_directional_attack_sheet: bool = (use_smasher_textures or is_viper or is_optimus or is_blacksmith) and (
		player_attack_left_sheet is Texture2D
		or player_attack_right_sheet is Texture2D
	)
	var player_directional_attack_frame_count: int = 16 if is_blacksmith else (8 if (is_viper or is_optimus) else 16)
	var player_directional_attack_grid_rows: int = 4 if is_blacksmith else (2 if (is_viper or is_optimus) else 4)
	var has_player_legacy_attack_sheet: bool = use_smasher_textures and textures.get("player_attack_sheet", null) is Texture2D
	var _has_player_attack_sheet: bool = has_player_directional_attack_sheet or has_player_legacy_attack_sheet
	var player_speed: float = float(context.get("player_speed", 0.0))
	var dash_direction: float = float(dash_context.get("direction", 0.0))
	var player_walk_direction := -1 if player_speed < -0.2 or (abs(player_speed) <= 0.2 and dash_direction < 0.0) else 1
	var commando_b2_animation_state: String = _get_commando_b2_animation_state(
		is_commando,
		player_speed,
		bool(dash_context.get("active", false)),
		player_walk_direction
	)
	var commando_b2_frame_index: int = _get_commando_b2_frame_index(
		commando_b2_animation_state,
		animation_context
	)
	var commando_b2_frame_anchor: Dictionary = commando_weapon_anchor_table.get_frame_anchor(
		commando_b2_animation_state,
		commando_b2_frame_index
	) if is_commando else {}
	var commando_b2_weapon_pivot: Dictionary = commando_weapon_anchor_table.get_weapon_pivot(
		commando_current_weapon_id
	) if is_commando else {}
	var commando_b2_texture_key: String = String(commando_b2_weapon_pivot.get("texture_key", ""))
	var commando_b2_texture: Variant = _get_value(textures, commando_b2_texture_key) if is_commando else null
	var commando_b2_anchor: Vector2 = _get_commando_b2_anchor(
		commando_b2_frame_anchor,
		commando_b2_weapon_pivot,
		commando_b2_animation_state
	)
	var commando_b2_renderable: bool = (
		is_commando
		and commando_b2_texture is Texture2D
		and commando_weapon_anchor_table.is_overlay_renderable(
			commando_b2_animation_state,
			commando_b2_frame_index,
			commando_current_weapon_id
		)
	)
	var commando_b2_flip_h: bool = (
		commando_b2_renderable
		and commando_b2_animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT
	)
	var player_base_hit_duration: float = float(animation_context.get(
		"player_hit_anim_duration",
		(
			PLAYER_DIRECTIONAL_ATTACK_ANIM_DURATION
			if has_player_directional_attack_sheet
			else (
				PLAYER_DIRECTIONAL_ATTACK_ANIM_DURATION
				if has_commando_attack_sheet
				else (PLAYER_LEGACY_ATTACK_ANIM_DURATION if has_player_legacy_attack_sheet else 0.36)
			)
		)
	))
	var player_effective_hit_duration: float = float(animation_context.get(
		"player_hit_effective_anim_duration",
		player_base_hit_duration
	))
	var player_customization_overlay_textures: Dictionary = _get_player_customization_overlay_textures(
		context,
		textures
	)
	var player_customization_overlay_slots: Dictionary = _get_player_customization_overlay_slots(
		context,
		player_customization_overlay_textures,
		character_type
	)
	var player_default_draw_size := Vector2(160.0, 160.0)
	var player_runtime_draw_size: Vector2 = BLACKSMITH_PLAYER_DRAW_SIZE if is_blacksmith else player_default_draw_size
	var _player_victory_frame_count: int = ResultContext.get_player_victory_frame_count(is_blacksmith)
	var _player_victory_grid_cols: int = ResultContext.get_player_victory_grid_cols(is_blacksmith)
	var _player_defeat_frame_count: int = ResultContext.get_player_defeat_frame_count(is_blacksmith, is_viper)
	var _player_defeat_grid_cols: int = ResultContext.get_player_defeat_grid_cols(is_blacksmith, is_viper)
	var _player_defeat_frame_key: String = ResultContext.get_player_defeat_frame_key(is_viper)
	_perf_end(perf_logger, "context.actor.customization", actor_sample_start)

	actor_sample_start = _perf_begin(perf_logger)
	var player_energy_ratio: float = clampf(float(context.get(
		"player_energy_ratio",
		context.get("optimus_energy_ratio", 1.0)
	)), 0.0, 1.0)
	var actor_context := {
		"shake_offset": _get_vector2(context, "shake_offset", Vector2.ZERO),
		"width": float(context.get("width", 760.0)),
		"height": float(context.get("height", 750.0)),
		"game_offset": _get_vector2(context, "game_offset", Vector2.ZERO),
		"game_size": _get_vector2(context, "game_size", Vector2(float(context.get("width", 760.0)), float(context.get("height", 750.0)))),
		"render_scale": max(0.001, float(context.get("render_scale", 1.0))),
		"current_stage": int(context.get("current_stage", 1)),
		"play_left": float(context.get("play_left", 0.0)),
		"play_right": float(context.get("play_right", 760.0)),
		"ball_active": bool(context.get("ball_active", false)),
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"ball_size": float(context.get("ball_size", 28.6)),
		"selected_character_type": character_type,
		"player_customization_overlays_enabled": bool(context.get("player_customization_overlays_enabled", true)),
		"player_customization_debug_overlay_enabled": bool(context.get("player_customization_debug_overlay_enabled", false)),
		"player_customization_overlay_slots": player_customization_overlay_slots,
		"player_customization_overlay_textures": player_customization_overlay_textures,
		"dash_active": dash_context.get("active", false),
		"dash_timer": float(dash_context.get("timer", 0.0)),
		"dash_elapsed_frames": float(dash_context.get("elapsed_frames", 0.0)),
		"dash_is_half": dash_context.get("is_half", false),
		"dash_direction": dash_context.get("direction", 0.0),
		"dash_recovering": dash_context.get("recovering", false),
		"dash_stun_timer": float(dash_context.get("stun_timer", 0.0)),
		"dash_recovery_total_frames": float(dash_context.get("recovery_total_frames", 0.0)),
		"dash_recovery_progress": float(dash_context.get("recovery_progress", 1.0)),
		"dash_tokens": int(dash_context.get("tokens", 0)),
		"dash_max_tokens": max(1, int(dash_context.get("max_tokens", 1))),
		"dash_charge_timer": float(dash_context.get("charge_timer", 0.0)),
		"dash_recharge_frames": max(1.0, float(dash_context.get("recharge_frames", 300.0))),
		"pillar_drawer": deps.get("pillar_drawer", null),
		"player_pos": player_draw_pos,
		"ghost_possession_paddle_hidden": ghost_possession_paddle_hidden,
		"ghost_possession_player_override": ghost_possession_player_override,
		"player_speed": player_speed,
		"player_walk_direction": player_walk_direction,
		"player_anim_clock": animation_context.get("player_anim_clock", 0.0),
		"player_paddle_size": player_draw_size,
		"player_paddle_scale": float(context.get("player_paddle_scale", 1.0)),
		"player_energy_ratio": player_energy_ratio,
		"player_hit_active": animation_context.get("player_hit_active", false),
		"player_hit_timer": animation_context.get("player_hit_timer", 0.0),
		"player_hit_side": animation_context.get("player_hit_side", -1),
		"player_hit_center": animation_context.get("player_hit_center", false),
		"player_hit_frame": animation_context.get("player_hit_frame", 0),
		"player_hit_frame_count": player_directional_attack_frame_count if has_player_directional_attack_sheet else (8 if has_player_legacy_attack_sheet else (8 if has_commando_attack_sheet else 4)),
		"player_directional_attack_grid_cols": 4,
		"player_directional_attack_grid_rows": player_directional_attack_grid_rows,
		"player_directional_attack_cell_width": 160.0,
		"player_directional_attack_cell_height": 160.0,
		"player_directional_attack_draw_size": player_runtime_draw_size,
		"player_hit_anim_duration": player_base_hit_duration,
		"player_hit_effective_anim_duration": player_effective_hit_duration,
		"player_idle_frame": animation_context.get("player_idle_frame", 0),
		"player_idle_frame_count": (COMMANDO_IDLE_FRAME_COUNT if is_commando else PLAYER_IDLE_FRAME_COUNT) if has_player_idle_sheet else 8,
		"player_idle_grid_cols": (COMMANDO_IDLE_GRID_COLS if is_commando else PLAYER_IDLE_GRID_COLS) if has_player_idle_sheet else 1,
		"player_idle_grid_rows": (COMMANDO_IDLE_GRID_ROWS if is_commando else PLAYER_IDLE_GRID_ROWS) if has_player_idle_sheet else 1,
		"player_idle_cell_width": 160.0 if has_player_idle_sheet else 250.0,
		"player_idle_cell_height": 160.0 if has_player_idle_sheet else 120.0,
		"player_idle_draw_size": player_runtime_draw_size,
		"player_victory_active": bool(boss_result_context.get("player_victory_active", false)) and has_player_victory_sheet,
		"player_victory_frame": clamp(
			int(boss_result_context.get("player_victory_frame", 0)),
			0,
			max(0, _player_victory_frame_count - 1)
		),
		"player_victory_sheet": player_victory_sheet,
		"player_victory_cell_width": 160.0,
		"player_victory_cell_height": 160.0,
		"player_victory_frame_count": _player_victory_frame_count,
		"player_victory_grid_cols": _player_victory_grid_cols,
		"player_victory_draw_size": player_runtime_draw_size,
		"player_wheel_spin_active": bool(smasher_wheel_context.get("player_wheel_spin_active", false)) and has_player_wheel_spin_sheet,
		"player_wheel_spin_frame": int(smasher_wheel_context.get("player_wheel_spin_frame", 0)),
		"player_wheel_spin_sheet": player_wheel_spin_sheet,
		"player_wheel_spin_cell_width": float(smasher_wheel_context.get("player_wheel_spin_cell_width", 160.0)),
		"player_wheel_spin_cell_height": float(smasher_wheel_context.get("player_wheel_spin_cell_height", 160.0)),
		"player_wheel_spin_frame_count": int(smasher_wheel_context.get("player_wheel_spin_frame_count", 16)),
		"player_wheel_spin_grid_cols": int(smasher_wheel_context.get("player_wheel_spin_grid_cols", 4)),
		"player_wheel_spin_draw_size": smasher_wheel_context.get("player_wheel_spin_draw_size", Vector2(160.0, 160.0)),
		"player_defeat_active": bool(boss_result_context.get("player_defeat_active", false)) and has_player_defeat_sheet,
		"player_defeat_frame": clamp(
			int(boss_result_context.get(_player_defeat_frame_key, 0)),
			0,
			max(0, _player_defeat_frame_count - 1)
		),
		"player_defeat_sheet": player_defeat_sheet,
		"player_defeat_cell_width": 160.0,
		"player_defeat_cell_height": 160.0,
		"player_defeat_frame_count": _player_defeat_frame_count,
		"player_defeat_grid_cols": _player_defeat_grid_cols,
		"player_defeat_draw_size": player_runtime_draw_size if is_blacksmith else Vector2(160.0, 160.0),
		"player_sprite_frame": animation_context.get("player_sprite_frame", 0),
		"player_directional_walk_cell_width": 160.0,
		"player_directional_walk_cell_height": 160.0,
		"player_directional_walk_frame_count": PLAYER_DIRECTIONAL_WALK_FRAME_COUNT if has_player_directional_walk_sheet else 8,
		"player_directional_walk_grid_cols": PLAYER_DIRECTIONAL_WALK_GRID_COLS if has_player_directional_walk_sheet else 4,
		"player_directional_walk_draw_size": player_runtime_draw_size,
		"has_player_directional_dash_sheet": has_player_directional_dash_sheet,
		"player_directional_dash_cell_width": 160.0,
		"player_directional_dash_cell_height": 160.0,
		"player_directional_dash_frame_count": PLAYER_DIRECTIONAL_DASH_FRAME_COUNT if has_player_directional_dash_sheet else 8,
		"player_directional_dash_grid_cols": PLAYER_DIRECTIONAL_DASH_GRID_COLS if has_player_directional_dash_sheet else 4,
		"player_directional_dash_draw_size": player_runtime_draw_size,
		# Smasher contact-animation state ported from pingfighter.py
		# (`smasher_swing_intensity`, `smasher_shield_raise_timer`,
		# `smasher_left_raise_timer`). Renderers can read intensity to scale
		# lunge / squash, and the bell-strength fields drive procedural
		# shield / left-arm raise overlays during the follow-through window.
		"player_swing_intensity": animation_context.get("player_swing_intensity", 1.0),
		"player_hit_pose_timer": animation_context.get("player_hit_pose_timer", 0.0),
		"player_shield_raise_timer": animation_context.get("player_shield_raise_timer", 0.0),
		"player_left_raise_timer": animation_context.get("player_left_raise_timer", 0.0),
		"player_shield_raise_strength": animation_context.get("player_shield_raise_strength", 0.0),
		"player_left_raise_strength": animation_context.get("player_left_raise_strength", 0.0),
		"player_hit_pose_strength": animation_context.get("player_hit_pose_strength", 0.0),
		"player_color": player_render_context.get("player_color", Color(0.25, 0.45, 1.0)),
		"player_color_light": player_render_context.get("player_color_light", Color(0.40, 0.60, 1.0)),
		"player_sprite_texture": player_sprite_texture,
		"player_walk_left_texture": player_walk_left_texture,
		"player_walk_right_texture": player_walk_right_texture,
		"player_dash_left_texture": player_dash_left_texture,
		"player_dash_right_texture": player_dash_right_texture,
		"player_idle_sprite_texture": player_idle_sprite_texture,
		"player_hit_sprite_texture": player_hit_sprite_texture,
		"player_hit_left_strip_texture": player_hit_left_strip_texture,
		"player_hit_right_strip_texture": player_hit_right_strip_texture,
		"player_attack_left_sheet": player_attack_left_sheet,
		"player_attack_right_sheet": player_attack_right_sheet,
		"player_attack_sheet": player_attack_sheet,
		"blacksmith_thor_shield_deploy_sheet": blacksmith_thor_shield_deploy_sheet,
		"has_blacksmith_thor_shield_deploy_sheet": has_blacksmith_thor_shield_deploy_sheet,
		"blacksmith_thor_shield_stretch_texture": blacksmith_thor_shield_stretch_texture,
		"has_blacksmith_thor_shield_stretch_texture": has_blacksmith_thor_shield_stretch_texture,
		"blacksmith_thor_shield_deploy_active": blacksmith_thor_shield_deploy_active,
		"blacksmith_thor_shield_deploy_frame": blacksmith_thor_shield_deploy_frame,
		"blacksmith_thor_shield_deploy_frame_count": BLACKSMITH_THOR_SHIELD_DEPLOY_FRAME_COUNT,
		"blacksmith_thor_shield_deploy_grid_cols": 4,
		"blacksmith_thor_shield_deploy_grid_rows": 4,
		"blacksmith_thor_shield_deploy_cell_width": 160.0,
		"blacksmith_thor_shield_deploy_cell_height": 160.0,
		"blacksmith_thor_shield_deploy_draw_size": player_runtime_draw_size,
		"blacksmith_umbrella_open_ratio": blacksmith_thor_shield_open_ratio,
		"blacksmith_thor_shield_open_ratio": blacksmith_thor_shield_open_ratio,
		"blacksmith_umbrella_visual_state": str(context.get("blacksmith_umbrella_visual_state", "closed")),
		"viper_wall_cling_left_sheet": viper_wall_cling_left_sheet,
		"viper_wall_cling_right_sheet": viper_wall_cling_right_sheet,
		"has_viper_wall_cling_sheet": has_viper_wall_cling_sheet,
		"viper_wall_cling_frame_count": 8,
		"viper_wall_cling_grid_cols": 4,
		"viper_wall_cling_cell_width": 160.0,
		"viper_wall_cling_cell_height": 160.0,
		"viper_wall_flight_left_sheet": viper_wall_flight_left_sheet,
		"viper_wall_flight_right_sheet": viper_wall_flight_right_sheet,
		"has_viper_wall_flight_sheet": has_viper_wall_flight_sheet,
		"viper_wall_flight_frame_count": 8,
		"viper_wall_flight_grid_cols": 4,
		"viper_wall_flight_cell_width": 160.0,
		"viper_wall_flight_cell_height": 160.0,
		"viper_flying_kick_left_sheet": viper_flying_kick_left_sheet,
		"viper_flying_kick_right_sheet": viper_flying_kick_right_sheet,
		"has_viper_flying_kick_sheet": has_viper_flying_kick_sheet,
		"viper_flying_kick_frame_count": 8,
		"viper_flying_kick_grid_cols": 4,
		"viper_flying_kick_cell_width": 160.0,
		"viper_flying_kick_cell_height": 160.0,
		"viper_tumble_sheet": viper_tumble_sheet,
		"has_viper_tumble_sheet": has_viper_tumble_sheet,
		"viper_tumble_frame_count": 8,
		"viper_tumble_grid_cols": 4,
		"viper_tumble_cell_width": 160.0,
		"viper_tumble_cell_height": 160.0,
		"viper_blade_fire_sheet": viper_blade_fire_sheet,
		"has_viper_blade_fire_sheet": has_viper_blade_fire_sheet,
		"viper_blade_fire_frame_count": 8,
		"viper_blade_fire_grid_cols": 4,
		"viper_blade_fire_cell_width": 160.0,
		"viper_blade_fire_cell_height": 160.0,
		"viper_throw_sheet": viper_throw_sheet,
		"has_viper_throw_sheet": has_viper_throw_sheet,
		"viper_throw_frame_count": 8,
		"viper_throw_grid_cols": 4,
		"viper_throw_cell_width": 160.0,
		"viper_throw_cell_height": 160.0,
		"viper_hover_left_sheet": viper_hover_left_sheet,
		"viper_hover_right_sheet": viper_hover_right_sheet,
		"has_viper_hover_sheet": has_viper_hover_sheet,
		"viper_up_kick_left_sheet": viper_up_kick_left_sheet,
		"viper_up_kick_right_sheet": viper_up_kick_right_sheet,
		"has_viper_up_kick_sheet": has_viper_up_kick_sheet,
		"viper_up_kick_frame_count": 8,
		"viper_up_kick_grid_cols": 4,
		"viper_up_kick_cell_width": 160.0,
		"viper_up_kick_cell_height": 160.0,
		"viper_hover_frame_count": 8,
		"viper_hover_grid_cols": 4,
		"viper_hover_cell_width": 160.0,
		"viper_hover_cell_height": 160.0,
		"viper_stun_sheet": viper_stun_sheet,
		"has_viper_stun_sheet": has_viper_stun_sheet,
		"viper_stun_frame_count": 8,
		"viper_stun_grid_cols": 4,
		"viper_stun_cell_width": 160.0,
		"viper_stun_cell_height": 160.0,
		"viper_confusion_sheet": viper_confusion_sheet,
		"has_viper_confusion_sheet": has_viper_confusion_sheet,
		"viper_confusion_frame_count": 8,
		"viper_confusion_grid_cols": 4,
		"viper_confusion_cell_width": 160.0,
		"viper_confusion_cell_height": 160.0,
		"viper_venom_edge_strike_sheet": viper_venom_edge_strike_sheet,
		"has_viper_venom_edge_strike_sheet": has_viper_venom_edge_strike_sheet,
		"viper_venom_edge_strike_frame_count": 8,
		"viper_venom_edge_strike_grid_cols": 4,
		"viper_venom_edge_strike_cell_width": 160.0,
		"viper_venom_edge_strike_cell_height": 160.0,
		"commando_weapon_fire_sheet": commando_weapon_fire_sheet if commando_weapon_fire_active else null,
		"commando_weapon_fire_active": commando_weapon_fire_active,
		"commando_weapon_fire_id": commando_weapon_fire_id if commando_weapon_fire_active else "",
		"commando_weapon_fire_frame": commando_weapon_fire_frame,
		"commando_weapon_fire_flip_h": _get_commando_weapon_fire_flip_h(
			commando_weapon_fire_active,
			commando_weapon_fire_id,
			player_walk_direction,
			player_draw_pos,
			player_draw_size,
			commando_firearm_context
		),
		"commando_weapon_fire_grid_cols": 4,
		"commando_weapon_fire_grid_rows": 2,
		"commando_weapon_fire_frame_count": 8,
		"commando_ak47_fire_active": commando_weapon_fire_active and commando_weapon_fire_id == "ak47",
		"commando_bazooka_fire_active": commando_weapon_fire_active and commando_weapon_fire_id == "bazooka",
		"commando_net_gun_fire_active": commando_weapon_fire_active and commando_weapon_fire_id == "net_gun",
		"commando_bowling_trap_place_active": commando_weapon_fire_active and commando_weapon_fire_id == "bowling_trap",
		"commando_suicide_drone_control_active": commando_weapon_fire_active and commando_weapon_fire_id == "suicide_drone",
		"commando_pistol_fire_sheet": commando_pistol_fire_sheet,
		"commando_pistol_fire_active": commando_pistol_fire_active,
		"commando_pistol_fire_frame": commando_pistol_fire_frame,
		"commando_pistol_fire_flip_h": commando_pistol_fire_active and player_walk_direction < 0,
		"commando_pistol_fire_grid_cols": 4,
		"commando_pistol_fire_grid_rows": 2,
		"commando_pistol_fire_frame_count": 8,
		"commando_attack_sheet": commando_attack_sheet,
		"commando_attack_active": commando_attack_active,
		"commando_attack_flip_h": commando_attack_active and int(animation_context.get("player_hit_side", -1)) < 0,
		"commando_attack_grid_cols": 4,
		"commando_attack_grid_rows": 2,
		"commando_attack_frame_count": 8,
		"commando_attack_cell_width": 160.0,
		"commando_attack_cell_height": 160.0,
		"player_commando_attack_draw_size": Vector2(160.0, 160.0),
		# Commando weapon overlay system (Phase 3 of per-firearm visual swap).
		# When `commando_current_weapon_id` is anything other than "pistol", the
		# matching overlay sprite is drawn on top of the base character sheet at
		# a per-direction anchor so the rifle / launcher / trap / drone visually
		# replaces the pistol that is baked into the idle/walk_* sheets. Pistol
		# is the default visual and needs no overlay.
		# Anchors are authored in 160x160 reference-cell coordinates. The
		# renderer scales them to the actual `player_visual_rect` size.
		"commando_current_weapon_id": commando_current_weapon_id if is_commando else "pistol",
		"commando_weapon_b2_animation_state": commando_b2_animation_state,
		"commando_weapon_b2_frame_index": commando_b2_frame_index,
		"commando_weapon_b2_frame_anchor": commando_b2_frame_anchor,
		"commando_weapon_b2_weapon_pivot": commando_b2_weapon_pivot,
		"commando_weapon_b2_texture": commando_b2_texture if commando_b2_renderable else null,
		"commando_weapon_b2_anchor": commando_b2_anchor,
		"commando_weapon_b2_frame_rot": float(commando_b2_frame_anchor.get("rot", 0.0)),
		"commando_weapon_b2_draw_size": commando_b2_weapon_pivot.get("draw_size", Vector2.ZERO),
		"commando_weapon_b2_pivot_primary": commando_b2_weapon_pivot.get("pivot_primary", Vector2.ZERO),
		"commando_weapon_b2_base_rot": float(commando_b2_weapon_pivot.get("base_rot", 0.0)),
		"commando_weapon_b2_flip_h": commando_b2_flip_h,
		"commando_weapon_b2_renderable": commando_b2_renderable,
		"commando_weapon_overlay_texture": _get_value(textures, _commando_weapon_overlay_texture_key(commando_current_weapon_id)) if is_commando else null,
		"commando_weapon_overlay_anchor_back": _commando_weapon_overlay_anchor_back(commando_current_weapon_id),
		"commando_weapon_overlay_anchor_left": _commando_weapon_overlay_anchor_left(commando_current_weapon_id),
		"commando_weapon_overlay_anchor_right": _commando_weapon_overlay_anchor_right(commando_current_weapon_id),
		"commando_weapon_overlay_draw_size": _commando_weapon_overlay_draw_size(commando_current_weapon_id),
		"commando_weapon_overlay_flip_h_for_walk_left": _commando_weapon_overlay_flip_h_for_walk_left(commando_current_weapon_id),
		# Pistol-fire dest rect: 160x160 matches the standardized v4 sheet
		# (640x320 / cell 160x160) — same dest size as idle/walk for unified
		# scale. Body lands at ~99-100px, matching idle exactly. Previous
		# 80x107 was needed for the legacy v3 sheet (1264x848 / cell 316x424)
		# that has been replaced with the standardized v4 layout.
		"player_commando_weapon_fire_draw_size": Vector2(160.0, 160.0),
		"player_pistol_fire_draw_size": Vector2(160.0, 160.0),
		"stage1_center_background_texture": _get_value(textures, "stage1_center_background_texture"),
		"stage1_center_border_texture": _get_value(textures, "stage1_center_border_texture"),
		"boss_pos": boss_draw_pos,
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2.ZERO),
		"boss_hitbox_height": float(context.get("boss_hitbox_height", 0.0)),
		"boss_max_health": max(0, int(context.get("boss_max_health", 0))),
		"boss_current_health": clamp(int(context.get("boss_current_health", 0)), 0, max(0, int(context.get("boss_max_health", 0)))),
		"boss_health_damage_units": max(0, int(context.get("boss_health_damage_units", 0))),
		"boss_health_visible": max(0, int(context.get("boss_max_health", 0))) > 0,
		"boss_health_ratio": _get_boss_health_ratio(context),
		"boss_last_damage_source": str(context.get("boss_last_damage_source", "")),
		"boss_defeated_by_health": bool(context.get("boss_defeated_by_health", false)),
		"boss_sprite_frame": animation_context.get("boss_sprite_frame", 0),
		"boss_walk_frame_count": BOSS_WALK_FRAME_COUNT,
		"boss_walk_grid_cols": BOSS_WALK_GRID_COLS,
		"boss_facing": animation_context.get("boss_facing", 1),
		"boss_is_walking": animation_context.get("boss_is_walking", false),
		"boss_idle_frame": animation_context.get("boss_idle_frame", 0),
		"boss_hit_active": animation_context.get("boss_hit_active", false),
		"boss_hit_frame": animation_context.get("boss_hit_frame", 0),
		"boss_hit_facing": animation_context.get("boss_hit_facing", 1),
		"boss_walk_left_sheet": _get_value(textures, "boss_walk_left_sheet"),
		"boss_walk_right_sheet": _get_value(textures, "boss_walk_right_sheet"),
		"boss_idle_sheet": _get_value(textures, "boss_idle_sheet"),
		"boss_attack_sheet": _get_value(textures, "boss_attack_sheet"),
		"boss_quake_stomp_sheet": _get_value(textures, "boss_quake_stomp_sheet"),
		"boss_dash_sheet": _get_value(textures, "boss_dash_sheet"),
		"boss_turn_sheet": _get_value(textures, "boss_turn_sheet"),
		"boss_victory_sheet": _get_value(textures, "boss_victory_sheet"),
		"boss_defeat_sheet": _get_value(textures, "boss_defeat_sheet"),
		"boss_stun_sheet": _get_value(textures, "boss_stun_sheet"),
		"boss_whip_sheet": _get_value(textures, "boss_whip_sheet"),
		"boss_paengi_top_whip_sheet": _get_value(textures, "boss_paengi_top_whip_sheet"),
		"boss_sprite_sheet": _get_value(textures, "boss_sprite_sheet"),
		"boss_hit_sprite_sheet": _get_value(textures, "boss_hit_sprite_sheet"),
	}
	_perf_end(perf_logger, "context.actor.compose", actor_sample_start)

	actor_sample_start = _perf_begin(perf_logger)
	actor_context.merge(boss_result_context, true)
	actor_context.merge(boss_dash_context, true)
	actor_context.merge(whip_context, true)
	actor_context.merge(spinning_top_context, true)
	actor_context.merge(dalji_cooldown_context, true)
	actor_context.merge(stage1_wall_flash_context, true)
	if current_stage == 2:
		actor_context.merge(stage2_context, true)
		actor_context.merge(stage2_skill_context, true)
	if current_stage == 3:
		actor_context.merge(stage3_skill_context, true)
	if current_stage == 4:
		actor_context.merge(stage4_map_context, true)
		actor_context.merge(stage4_wall_flash_context, true)
	if current_stage == 5:
		actor_context.merge(stage5_hongryun_context, true)
		actor_context.merge(stage5_hongryun_fire_machine_context, true)
	if current_stage == 6:
		actor_context.merge(stage6_tetriser_context, true)
	actor_context.merge(active_item_context, true)
	actor_context.merge(mythic_item_context, true)
	actor_context.merge(status_effect_context, true)
	actor_context.merge(warp_gate_context, true)
	if character_type == "soldier":
		actor_context.merge(commando_firearm_context, true)
	if character_type == "viper":
		actor_context.merge(viper_jetpack_context, true)
		actor_context.merge(viper_skill_context, true)
	if _is_stage2_speed_defense_status_immune(actor_context):
		_suppress_boss_disable_draw_context(actor_context)
	actor_context.merge(_get_paddle_hologram_context(deps), true)
	_perf_end(perf_logger, "context.actor.merge", actor_sample_start)
	return actor_context


func _get_blacksmith_thor_shield_open_ratio(context: Dictionary) -> float:
	if context.has("blacksmith_umbrella_open_ratio"):
		return clamp(float(context.get("blacksmith_umbrella_open_ratio", 0.0)), 0.0, 1.0)
	if context.has("blacksmith_thor_shield_open_ratio"):
		return clamp(float(context.get("blacksmith_thor_shield_open_ratio", 0.0)), 0.0, 1.0)
	var anim_timer: float = max(0.0, float(context.get("blacksmith_umbrella_anim_timer", 0.0)))
	if bool(context.get("blacksmith_umbrella_retracting", false)):
		return clamp(anim_timer / BLACKSMITH_THOR_SHIELD_ANIM_SECONDS, 0.0, 1.0)
	if bool(context.get("blacksmith_umbrella_open", false)):
		if anim_timer <= 0.0:
			return 1.0
		return clamp(1.0 - anim_timer / BLACKSMITH_THOR_SHIELD_ANIM_SECONDS, 0.0, 1.0)
	return 0.0


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


# Mirror of Python's `get_paddle_hologram_state()` from pingfighter.py §122551:
# during the ball spawn intro the player and boss paddles are first hidden,
# then materialize with a glitch reveal in the last `PADDLE_HOLOGRAM_DURATION`
# of the intro. Stage 1 actor renderers consult these keys to gate visibility
# and apply the materialize effect; outside the intro the keys default to
# "fully visible" and the renderers run unchanged.
func _get_paddle_hologram_context(deps: Dictionary) -> Dictionary:
	var ball_spawn_intro: Object = deps.get("stage_ball_spawn_intro", null)
	if ball_spawn_intro == null or not ball_spawn_intro.has_method("get_paddle_hologram_state"):
		return {
			"paddle_hologram_should_draw": true,
			"paddle_hologram_progress": 1.0,
			"paddle_hologram_active": false,
		}
	var state: Dictionary = ball_spawn_intro.get_paddle_hologram_state()
	return {
		"paddle_hologram_should_draw": bool(state.get("should_draw", true)),
		"paddle_hologram_progress": float(state.get("progress", 1.0)),
		"paddle_hologram_active": bool(state.get("active", false)),
	}


func _should_read_actor_draw_context(source: Object) -> bool:
	if source == null or not source.has_method("get_actor_draw_context"):
		return false
	if source.has_method("has_actor_draw_context"):
		return bool(source.has_actor_draw_context())
	return true


func _get_player_customization_overlay_textures(context: Dictionary, textures: Dictionary) -> Dictionary:
	var overlay_textures: Dictionary = _get_dict(context.get("player_customization_overlay_textures", {})).duplicate(true)
	var debug_paddle_sheet: Variant = _get_value(textures, "smasher_debug_paddle_overlay_sheet")
	if debug_paddle_sheet is Texture2D and not overlay_textures.has("smasher_debug_paddle_overlay_sheet"):
		overlay_textures["smasher_debug_paddle_overlay_sheet"] = debug_paddle_sheet
	for optimus_key in [
		"optimus_overlay_paddle",
		"optimus_overlay_core_glow",
		"optimus_overlay_back",
		"optimus_overlay_accessory",
		"optimus_overlay_outfit_accent",
	]:
		var sheet: Variant = _get_value(textures, optimus_key)
		if sheet is Texture2D and not overlay_textures.has(optimus_key):
			overlay_textures[optimus_key] = sheet
	return overlay_textures


func _get_player_customization_overlay_slots(
	context: Dictionary,
	overlay_textures: Dictionary,
	character_type: String
) -> Dictionary:
	var overlay_slots: Dictionary = _get_dict(context.get("player_customization_overlay_slots", {})).duplicate(true)
	if character_type == "optimus":
		_inject_optimus_default_overlay_slots(overlay_slots, overlay_textures)
	if not bool(context.get("player_customization_debug_overlay_enabled", false)):
		return overlay_slots
	if character_type != "smasher":
		return overlay_slots
	if overlay_slots.has("paddle"):
		return overlay_slots
	if not (overlay_textures.get("smasher_debug_paddle_overlay_sheet", null) is Texture2D):
		return overlay_slots
	overlay_slots["paddle"] = _build_smasher_debug_paddle_overlay_slot()
	return overlay_slots


func _inject_optimus_default_overlay_slots(overlay_slots: Dictionary, overlay_textures: Dictionary) -> void:
	if overlay_textures.get("optimus_overlay_paddle", null) is Texture2D and not overlay_slots.has("paddle"):
		overlay_slots["paddle"] = _optimus_overlay_slot_spec("optimus_overlay_paddle", {"scale_from_player_paddle": true})
	if overlay_textures.get("optimus_overlay_core_glow", null) is Texture2D and not overlay_slots.has("core_glow"):
		overlay_slots["core_glow"] = _optimus_overlay_slot_spec("optimus_overlay_core_glow", {"alpha_from_energy_ratio": true})
	if overlay_textures.get("optimus_overlay_back", null) is Texture2D and not overlay_slots.has("back"):
		overlay_slots["back"] = _optimus_overlay_slot_spec("optimus_overlay_back", {})
	if overlay_textures.get("optimus_overlay_accessory", null) is Texture2D and not overlay_slots.has("accessory"):
		overlay_slots["accessory"] = _optimus_overlay_slot_spec("optimus_overlay_accessory", {})
	if overlay_textures.get("optimus_overlay_outfit_accent", null) is Texture2D and not overlay_slots.has("outfit_accent"):
		overlay_slots["outfit_accent"] = _optimus_overlay_slot_spec("optimus_overlay_outfit_accent", {})


func _optimus_overlay_slot_spec(texture_key: String, extras: Dictionary) -> Dictionary:
	var spec: Dictionary = {
		"texture_key": texture_key,
		"mirror_policy": "mirror_ok",
		"grid_cols": 4,
		"grid_rows": 2,
		"frame_count": 8,
		"cell_width": 160.0,
		"cell_height": 160.0,
		"motions": _optimus_overlay_motion_specs(),
	}
	for key in extras.keys():
		spec[key] = extras[key]
	return spec


func _optimus_overlay_motion_specs() -> Dictionary:
	return {
		"idle": {
			"directions": {
				"back": {},
			},
		},
		"walk": {
			"directions": {
				"right": {},
			},
		},
		"dash": {
			"directions": {
				"right": {},
			},
		},
		"attack": {
			"directions": {
				"right": {},
			},
		},
	}


func _build_smasher_debug_paddle_overlay_slot() -> Dictionary:
	var right_spec: Dictionary = _smasher_debug_paddle_overlay_direction_spec()
	return {
		"mirror_policy": "mirror_ok",
		"motions": {
			"idle": {
				"directions": {
					"back": right_spec,
				},
			},
			"walk": {
				"directions": {
					"right": right_spec,
				},
			},
			"dash": {
				"directions": {
					"right": right_spec,
				},
			},
			"attack": {
				"directions": {
					"right": right_spec,
				},
			},
		},
	}


func _smasher_debug_paddle_overlay_direction_spec() -> Dictionary:
	return {
		"texture_key": "smasher_debug_paddle_overlay_sheet",
		"grid_cols": 4,
		"grid_rows": 2,
		"frame_count": 8,
		"cell_width": 160.0,
		"cell_height": 160.0,
	}


func _get_value(source: Dictionary, key: String) -> Variant:
	return source.get(key, null)


func _get_stage1_wall_flash_context(impact_effects: Object) -> Dictionary:
	if impact_effects == null or not impact_effects.has_method("get_wall_border_flash_timer"):
		return {}
	return {
		"stage1_wall_flash_timer": float(impact_effects.get_wall_border_flash_timer()),
		"stage1_wall_flash_duration": float(impact_effects.get_wall_border_flash_duration()),
		"stage1_wall_flash_position": impact_effects.get_wall_border_flash_position(),
		"stage1_wall_flash_side": str(impact_effects.get_wall_border_flash_side()),
		"stage1_wall_flash_speed": float(impact_effects.get_wall_border_flash_speed()),
	}


func _get_stage4_wall_flash_context(impact_effects: Object) -> Dictionary:
	if impact_effects == null or not impact_effects.has_method("get_wall_border_flash_timer"):
		return {}
	return {
		"stage4_wall_flash_timer": float(impact_effects.get_wall_border_flash_timer()),
		"stage4_wall_flash_duration": float(impact_effects.get_wall_border_flash_duration()),
		"stage4_wall_flash_position": impact_effects.get_wall_border_flash_position(),
		"stage4_wall_flash_side": str(impact_effects.get_wall_border_flash_side()),
		"stage4_wall_flash_speed": float(impact_effects.get_wall_border_flash_speed()),
	}


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _is_stage2_speed_defense_status_immune(context: Dictionary) -> bool:
	if int(context.get("current_stage", 0)) != 2:
		return false
	return (
		bool(context.get("stage2_speed_defense_status_immunity_active", false))
		or bool(context.get("stage2_speed_defense_active", false))
	)


func _suppress_boss_disable_draw_context(context: Dictionary) -> void:
	for key in [
		"active_item_boss_stun_active",
		"active_item_boss_stun_frame",
		"active_item_boss_stun_stars_suppressed",
		"boss_electric_stun_active",
		"active_item_boss_confusion_active",
		"ragnarok_hammer_boss_stun_active",
		"ragnarok_hammer_electric_stun_active",
		"ragnarok_hammer_boss_knockback_active",
	]:
		context.erase(key)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)


func _get_render_boss_pos(context: Dictionary, fallback: Vector2) -> Vector2:
	if not bool(context.get("boss_render_interpolation_enabled", true)):
		return fallback
	var previous: Vector2 = _get_vector2(context, "boss_pos_prev", fallback)
	var fraction: float = _get_manual_interpolation_fraction(context, "boss_interp_last_physics_usec")
	return previous.lerp(fallback, fraction)


func _get_manual_interpolation_fraction(context: Dictionary, key: String) -> float:
	var last_physics_usec: int = int(context.get(key, 0))
	if last_physics_usec <= 0:
		return clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var tick_rate: float = float(Engine.physics_ticks_per_second)
	var tick_usec: float = 1000000.0 / max(1.0, tick_rate)
	var elapsed_usec: float = float(Time.get_ticks_usec() - last_physics_usec)
	return clampf(elapsed_usec / tick_usec, 0.0, 1.0)


func _get_boss_health_ratio(context: Dictionary) -> float:
	var max_health: int = max(0, int(context.get("boss_max_health", 0)))
	if max_health <= 0:
		return 0.0
	var current_health: int = clamp(int(context.get("boss_current_health", max_health)), 0, max_health)
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)


func _get_commando_b2_animation_state(
	is_commando: bool,
	player_speed: float,
	dash_active: bool,
	player_walk_direction: int
) -> String:
	if not is_commando:
		return ""
	var player_move_active: bool = abs(player_speed) > 0.2 or dash_active
	if not player_move_active:
		return CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK
	if player_walk_direction < 0:
		return CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT
	return CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT


func _get_commando_b2_frame_index(animation_state: String, animation_context: Dictionary) -> int:
	if animation_state == CommandoWeaponAnchorTable.ANIMATION_IDLE_BACK:
		return int(animation_context.get("player_idle_frame", 0))
	if (
		animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_LEFT
		or animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_RIGHT
		or animation_state == CommandoWeaponAnchorTable.ANIMATION_WALK_BACK
	):
		return int(animation_context.get("player_sprite_frame", 0))
	return 0


func _get_commando_weapon_fire_sheet(textures: Dictionary, weapon_id: String) -> Variant:
	match weapon_id:
		"ak47":
			return _get_value(textures, "commando_player_ak47_fire_sheet")
		"bazooka":
			return _get_value(textures, "commando_player_bazooka_fire_sheet")
		"net_gun":
			return _get_value(textures, "commando_player_net_gun_fire_sheet")
		"bowling_trap":
			return _get_value(textures, "commando_player_bowling_trap_place_sheet")
		"suicide_drone":
			return _get_value(textures, "commando_player_suicide_drone_control_sheet")
	return null


func _get_commando_weapon_fire_frame(fire_state: Dictionary) -> int:
	var frame_count: int = max(1, int(fire_state.get("frame_count", 8)))
	var timer_max: float = max(1.0, float(fire_state.get("timer_max_frames", 1.0)))
	var timer: float = clamp(float(fire_state.get("timer_frames", 0.0)), 0.0, timer_max)
	var progress: float = clamp(1.0 - timer / timer_max, 0.0, 1.0)
	return clamp(int(progress * float(frame_count)), 0, frame_count - 1)


func _get_commando_weapon_fire_flip_h(
	active: bool,
	weapon_id: String,
	player_walk_direction: int,
	player_pos: Vector2,
	player_size: Vector2,
	commando_firearm_context: Dictionary
) -> bool:
	if not active:
		return false
	if weapon_id == "suicide_drone":
		return _get_commando_suicide_drone_control_flip_h(
			player_pos,
			player_size,
			commando_firearm_context
		)
	return player_walk_direction < 0


func _get_commando_suicide_drone_control_flip_h(
	player_pos: Vector2,
	player_size: Vector2,
	commando_firearm_context: Dictionary
) -> bool:
	var drone_state: Dictionary = _get_dict(commando_firearm_context.get("commando_firearm_suicide_drone_state", {}))
	if not bool(drone_state.get("active", false)):
		return false
	var drone_pos: Vector2 = _get_vector2(drone_state, "pos", player_pos)
	var player_center_x: float = player_pos.x + max(0.0, player_size.x) * 0.5
	return drone_pos.x < player_center_x - 0.5


func _get_commando_b2_anchor(
	frame_anchor: Dictionary,
	weapon_pivot: Dictionary,
	animation_state: String
) -> Vector2:
	var anchor_overrides: Variant = weapon_pivot.get("anchor_overrides", {})
	if anchor_overrides is Dictionary and anchor_overrides.has(animation_state):
		var override_value: Variant = anchor_overrides[animation_state]
		if override_value is Vector2:
			return override_value
	var primary_anchor: Variant = frame_anchor.get("primary", Vector2.ZERO)
	return primary_anchor if primary_anchor is Vector2 else Vector2.ZERO


# Commando weapon overlay metadata. The 4x2 base sheets (idle / walk_back /
# walk_left / walk_right) each show the chibi at a 100x100-ish body within a
# 160x160 cell, with a small black pistol baked into the right-hand area near
# the lower-right of the body. To swap the visible firearm, the matching
# overlay sprite is drawn on top of the base at a calibrated anchor in
# 160x160 reference-cell coordinates.
#
# Anchor convention: top-left corner of the overlay rectangle, expressed as
# (x, y) within a 160x160 cell. The renderer scales these to the actual
# player_visual_rect size.
#
# Direction split:
# - back: idle + walk_back (pure back-view, weapon held horizontally at hip)
# - left: walk_left (3/4 view facing viewer-left)
# - right: walk_right (3/4 view facing viewer-right)
#
# Bowling trap is held VERTICALLY (taller than wide) and uses different
# overlay geometry. Suicide drone has the controller in hands plus a drone
# hovering above; it occupies more vertical space.
const _COMMANDO_WEAPON_OVERLAY_TABLE := {
	"ak47": {
		"texture_key": "commando_weapon_overlay_ak47",
		"anchor_back": Vector2(40.0, 102.0),
		"anchor_left": Vector2(20.0, 102.0),
		"anchor_right": Vector2(60.0, 102.0),
		"draw_size": Vector2(100.0, 30.0),
		"flip_h_for_walk_left": true,
	},
	"bazooka": {
		"texture_key": "commando_weapon_overlay_bazooka",
		"anchor_back": Vector2(35.0, 95.0),
		"anchor_left": Vector2(15.0, 95.0),
		"anchor_right": Vector2(55.0, 95.0),
		"draw_size": Vector2(110.0, 42.0),
		"flip_h_for_walk_left": true,
	},
	"net_gun": {
		"texture_key": "commando_weapon_overlay_net_gun",
		"anchor_back": Vector2(47.0, 95.0),
		"anchor_left": Vector2(27.0, 95.0),
		"anchor_right": Vector2(67.0, 95.0),
		"draw_size": Vector2(85.0, 47.0),
		"flip_h_for_walk_left": true,
	},
	"bowling_trap": {
		"texture_key": "commando_weapon_overlay_bowling_trap",
		"anchor_back": Vector2(75.0, 75.0),
		"anchor_left": Vector2(70.0, 75.0),
		"anchor_right": Vector2(80.0, 75.0),
		"draw_size": Vector2(31.0, 75.0),
		"flip_h_for_walk_left": false,
	},
	"suicide_drone": {
		"texture_key": "commando_weapon_overlay_suicide_drone",
		"anchor_back": Vector2(35.0, 60.0),
		"anchor_left": Vector2(15.0, 60.0),
		"anchor_right": Vector2(55.0, 60.0),
		"draw_size": Vector2(91.0, 95.0),
		"flip_h_for_walk_left": false,
	},
}


func _commando_weapon_overlay_entry(weapon_id: String) -> Dictionary:
	if _COMMANDO_WEAPON_OVERLAY_TABLE.has(weapon_id):
		return _COMMANDO_WEAPON_OVERLAY_TABLE[weapon_id]
	return {}


func _commando_weapon_overlay_texture_key(weapon_id: String) -> String:
	var entry: Dictionary = _commando_weapon_overlay_entry(weapon_id)
	return String(entry.get("texture_key", ""))


func _commando_weapon_overlay_anchor_back(weapon_id: String) -> Vector2:
	var entry: Dictionary = _commando_weapon_overlay_entry(weapon_id)
	return entry.get("anchor_back", Vector2.ZERO)


func _commando_weapon_overlay_anchor_left(weapon_id: String) -> Vector2:
	var entry: Dictionary = _commando_weapon_overlay_entry(weapon_id)
	return entry.get("anchor_left", Vector2.ZERO)


func _commando_weapon_overlay_anchor_right(weapon_id: String) -> Vector2:
	var entry: Dictionary = _commando_weapon_overlay_entry(weapon_id)
	return entry.get("anchor_right", Vector2.ZERO)


func _commando_weapon_overlay_draw_size(weapon_id: String) -> Vector2:
	var entry: Dictionary = _commando_weapon_overlay_entry(weapon_id)
	return entry.get("draw_size", Vector2.ZERO)


func _commando_weapon_overlay_flip_h_for_walk_left(weapon_id: String) -> bool:
	var entry: Dictionary = _commando_weapon_overlay_entry(weapon_id)
	return bool(entry.get("flip_h_for_walk_left", false))
