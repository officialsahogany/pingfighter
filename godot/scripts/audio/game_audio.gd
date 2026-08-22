extends RefCounted

# Core match feedback must not advance gameplay's global RNG stream.
var _core_match_feedback_rng := RandomNumberGenerator.new()
var _core_match_feedback_rng_ready := false

const GameAudioPlayerFactory := preload("res://scripts/audio/game_audio_player_factory.gd")
const BlacksmithThorShieldAudio := preload("res://scripts/audio/blacksmith_thor_shield_audio.gd")
const PerkFusionCombatAudio := preload("res://scripts/audio/perk_fusion_combat_audio.gd")
const CommandoSkillAudio := preload("res://scripts/audio/commando_skill_audio.gd")
const CoreBallDashAudio := preload("res://scripts/audio/core_ball_dash_audio.gd")
const PaddleHitAudioLayers := preload("res://scripts/audio/paddle_hit_audio_layers.gd")
const ElementalCombatAudio := preload("res://scripts/audio/elemental_combat_audio.gd")
const GameAudioBusController := preload("res://scripts/audio/game_audio_bus_controller.gd")
const GameAudioSetupController := preload(
	"res://scripts/audio/game_audio_setup_controller.gd"
)
const GameUiFeedbackAudio := preload("res://scripts/audio/game_ui_feedback_audio.gd")
const ItemRewardFeedbackAudio := preload("res://scripts/audio/item_reward_feedback_audio.gd")
const ProjectileItemAudio := preload("res://scripts/audio/projectile_item_audio.gd")
const SharedStageFeedbackAudio := preload("res://scripts/audio/shared_stage_feedback_audio.gd")
const StageBgmAudio := preload("res://scripts/audio/stage_bgm_audio.gd")
const StageBgmPlaybackController := preload("res://scripts/audio/stage_bgm_playback_controller.gd")
const TransformationItemAudio := preload("res://scripts/audio/transformation_item_audio.gd")
const SmasherSkillAudio := preload("res://scripts/audio/smasher_skill_audio.gd")
const Stage1BossSkillAudio := preload("res://scripts/audio/stage1_boss_skill_audio.gd")
const ViperSkillAudio := preload("res://scripts/audio/viper_skill_audio.gd")
const LingpetAcquisitionAudio := preload("res://scripts/audio/lingpet_acquisition_audio.gd")
const LingpetClickVoiceAudio := preload("res://scripts/audio/lingpet_click_voice_audio.gd")
const LingpetCombatAudio := preload("res://scripts/audio/lingpet_combat_audio.gd")
const Stage2BattleAudio := preload("res://scripts/audio/stage2_battle_audio.gd")
const Stage3BattleAudio := preload("res://scripts/audio/stage3_battle_audio.gd")
const Stage4PonkAudio := preload("res://scripts/audio/stage4_ponk_audio.gd")
const Stage5HongryunAudio := preload("res://scripts/audio/stage5_hongryun_audio.gd")
const Stage6TetriserAudio := preload("res://scripts/audio/stage6_tetriser_audio.gd")
const Stage7AkamuAudio := preload("res://scripts/audio/stage7_akamu_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const ITEM_GET_SOUND_PATH := ItemRewardFeedbackAudio.ITEM_GET_SOUND_PATH
const DRINK_SOUND_PATH := ItemRewardFeedbackAudio.DRINK_SOUND_PATH
const ACTIVE_ITEM_SOUND_PATH := ItemRewardFeedbackAudio.ACTIVE_ITEM_SOUND_PATH
const TRADE_SOUND_PATH := ItemRewardFeedbackAudio.TRADE_SOUND_PATH
const TRADE_SOUND_GAIN_DB := ItemRewardFeedbackAudio.TRADE_SOUND_GAIN_DB
const BRICK_WALL_DESTROY_SOUND_PATH := ItemRewardFeedbackAudio.BRICK_WALL_DESTROY_SOUND_PATH
const BRICK_WALL_DESTROY_GAIN_DB := ItemRewardFeedbackAudio.BRICK_WALL_DESTROY_GAIN_DB
const ALCHEMY_SOUND_PATH := ItemRewardFeedbackAudio.ALCHEMY_SOUND_PATH
const PANDORA_SOUND_PATH := ItemRewardFeedbackAudio.PANDORA_SOUND_PATH
const LUCKY_COIN_SPAWN_SOUND_PATH := ItemRewardFeedbackAudio.LUCKY_COIN_SPAWN_SOUND_PATH
const FOUL_WHISTLE_SOUND_PATH := ItemRewardFeedbackAudio.FOUL_WHISTLE_SOUND_PATH
const MEGINGJORD_SOUND_PATH := ItemRewardFeedbackAudio.MEGINGJORD_SOUND_PATH
const LEGENDARY_OPEN_SOUND_PATH := ItemRewardFeedbackAudio.LEGENDARY_OPEN_SOUND_PATH
const ANGEL_BLESSING_ROLL_SOUND_PATH := ItemRewardFeedbackAudio.ANGEL_BLESSING_ROLL_SOUND_PATH
const ANGEL_BLESSING_ABSORB_SOUND_PATH := ItemRewardFeedbackAudio.ANGEL_BLESSING_ABSORB_SOUND_PATH
const ANGEL_BLESSING_ABSORB_POOL_SIZE := ItemRewardFeedbackAudio.ANGEL_BLESSING_ABSORB_POOL_SIZE
const ANGEL_BLESSING_ROLL_GAIN_DB := ItemRewardFeedbackAudio.ANGEL_BLESSING_ROLL_GAIN_DB
const ANGEL_BLESSING_ABSORB_GAIN_DB := ItemRewardFeedbackAudio.ANGEL_BLESSING_ABSORB_GAIN_DB
const RESULT_BOX_OPEN_SOUND_PATH := ItemRewardFeedbackAudio.RESULT_BOX_OPEN_SOUND_PATH
const DEFEAT_JEWEL_SOUND_PATH := ItemRewardFeedbackAudio.DEFEAT_JEWEL_SOUND_PATH
const DEFEAT_GEM_SHATTER_SOUND_PATH := ItemRewardFeedbackAudio.DEFEAT_GEM_SHATTER_SOUND_PATH
const COLD_BOOT_CHNK_LATCH_SOUND_PATH := ItemRewardFeedbackAudio.COLD_BOOT_CHNK_LATCH_SOUND_PATH
const COLD_BOOT_POST_RAMP_SOUND_PATH := ItemRewardFeedbackAudio.COLD_BOOT_POST_RAMP_SOUND_PATH
const COLD_BOOT_IGNITION_THUNK_SOUND_PATH := ItemRewardFeedbackAudio.COLD_BOOT_IGNITION_THUNK_SOUND_PATH
const COLD_BOOT_AWAKEN_FANFARE_SOUND_PATH := ItemRewardFeedbackAudio.COLD_BOOT_AWAKEN_FANFARE_SOUND_PATH
const LEGENDARY_AFTER_SOUND_PATH := ItemRewardFeedbackAudio.LEGENDARY_AFTER_SOUND_PATH
const LEGENDARY_ENDING_SOUND_PATH := ItemRewardFeedbackAudio.LEGENDARY_ENDING_SOUND_PATH
const RAGNAROK_SHOT_SOUND_PATH := ElementalCombatAudio.RAGNAROK_SHOT_SOUND_PATH
const RAGNAROK_BOOM_SOUND_PATH := ElementalCombatAudio.RAGNAROK_BOOM_SOUND_PATH
const RAGNAROK_SHOCK_SOUND_PATH := ElementalCombatAudio.RAGNAROK_SHOCK_SOUND_PATH
const ELECTRIC_SHOCK_SOUND_PATH := ElementalCombatAudio.ELECTRIC_SHOCK_SOUND_PATH
const ELECTRIC_SHOCK_GAIN_DB := ElementalCombatAudio.ELECTRIC_SHOCK_GAIN_DB
const THUNDER_ORB_SHOT_SOUND_PATH := ElementalCombatAudio.THUNDER_ORB_SHOT_SOUND_PATH
const THUNDER_ORB_BOOM_SOUND_PATH := ElementalCombatAudio.THUNDER_ORB_BOOM_SOUND_PATH
const THUNDER_ORB_SHOT_GAIN_DB := ElementalCombatAudio.THUNDER_ORB_SHOT_GAIN_DB
const THUNDER_ORB_BOOM_GAIN_DB := ElementalCombatAudio.THUNDER_ORB_BOOM_GAIN_DB
# Parity with original PingFighter SolarBolt (천둥 낙뢰): plays devinethunder.wav,
# the same divine-thunder cue DivineShield's lightning interception uses. Gain
# -6.0206 dB matches the original's pygame volume 0.5.
const SOLAR_BOLT_STRIKE_SOUND_PATH := ElementalCombatAudio.SOLAR_BOLT_STRIKE_SOUND_PATH
# Lumion Thunder Orb (천둥 뇌구) Lv.3+ mini-spark crackle. Each spark instance plays
# a RANDOM one of these three short zaps (pitch-jittered) so the scattered
# post-stun sparks read audibly distinct. Streams are loaded eagerly at setup via
# the elemental owner and retained in mini_spark_streams (no hot-path
# lazy load), mirroring the mika_*_voice multi-variant pattern.
const MINI_SPARK_SOUND_PATHS := ElementalCombatAudio.MINI_SPARK_SOUND_PATHS
const MINI_SPARK_GAIN_DB := ElementalCombatAudio.MINI_SPARK_GAIN_DB
const SOLAR_BOLT_STRIKE_GAIN_DB := ElementalCombatAudio.SOLAR_BOLT_STRIKE_GAIN_DB
const POSEIDON_WAVE_SOUND_PATH := ElementalCombatAudio.POSEIDON_WAVE_SOUND_PATH
const POSEIDON_CHARGE_SOUND_PATH := ElementalCombatAudio.POSEIDON_CHARGE_SOUND_PATH
const TIMEWATCH_SOUND_PATH := ItemRewardFeedbackAudio.TIMEWATCH_SOUND_PATH
const THROW_BEFORE_SOUND_PATH := ItemRewardFeedbackAudio.THROW_BEFORE_SOUND_PATH
const THROW_SOUND_PATH := ItemRewardFeedbackAudio.THROW_SOUND_PATH
const HORN_STRAWBERRY_CHANGE_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_CHANGE_SOUND_PATH
const ODINS_EYE_CHANGE_SOUND_PATH := TransformationItemAudio.ODINS_EYE_CHANGE_SOUND_PATH
const ODINS_EYE_DEATH_SOUND_PATH := TransformationItemAudio.ODINS_EYE_DEATH_SOUND_PATH
const ODINS_EYE_SPIRIT_SOUND_PATH := TransformationItemAudio.ODINS_EYE_SPIRIT_SOUND_PATH
const ODINS_EYE_ATTACK_SOUND_PATH := TransformationItemAudio.ODINS_EYE_ATTACK_SOUND_PATH
const ODINS_EYE_SHADOW_SOUND_PATH := TransformationItemAudio.ODINS_EYE_SHADOW_SOUND_PATH
const HORN_STRAWBERRY_EAT_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_EAT_SOUND_PATH
const HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH
const HORN_STRAWBERRY_STEM_HIT_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_STEM_HIT_SOUND_PATH
const HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH
const HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH
const HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH
const HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH
const HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH := TransformationItemAudio.HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH
const HORN_STRAWBERRY_CHANGE_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_CHANGE_GAIN_DB
const HORN_STRAWBERRY_EAT_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_EAT_GAIN_DB
const HORN_STRAWBERRY_STEM_FIRE_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_STEM_FIRE_GAIN_DB
# Python parity: stem hit plays bullethit at 0.3 (pingfighter play_cached_sound), not the
# module's unused 0.4 loader. 20*log10(0.3) = -10.4576.
const HORN_STRAWBERRY_STEM_HIT_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_STEM_HIT_GAIN_DB
const HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB
const HORN_STRAWBERRY_FIELD_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_FIELD_GAIN_DB
const HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB
const HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB := TransformationItemAudio.HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB
const GRENADE_SOUND_PATH := ProjectileItemAudio.GRENADE_SOUND_PATH
const FLASHBOMB_SOUND_PATH := ProjectileItemAudio.FLASHBOMB_SOUND_PATH
const SMOKEBOMB_SOUND_PATH := ProjectileItemAudio.SMOKEBOMB_SOUND_PATH
const DYNAMITE_FUSE_SOUND_PATH := ProjectileItemAudio.DYNAMITE_FUSE_SOUND_PATH
const FIREBOMB_SOUND_PATH := ProjectileItemAudio.FIREBOMB_SOUND_PATH
const BOOMERANG_SOUND_PATH := ProjectileItemAudio.BOOMERANG_SOUND_PATH
const BOOMERANG_HIT_SOUND_PATH := ProjectileItemAudio.BOOMERANG_HIT_SOUND_PATH
const BOOMERANG_BREAK_SOUND_PATH := ProjectileItemAudio.BOOMERANG_BREAK_SOUND_PATH
const SHRAPNEL_ARMOR_FIRE_SOUND_PATH := ProjectileItemAudio.SHRAPNEL_ARMOR_FIRE_SOUND_PATH
const SHRAPNEL_ARMOR_HIT_SOUND_PATH := ProjectileItemAudio.SHRAPNEL_ARMOR_HIT_SOUND_PATH
const BANANA_THROW_SOUND_PATH := ProjectileItemAudio.BANANA_THROW_SOUND_PATH
const BANANA_SLIP_SOUND_PATH := ProjectileItemAudio.BANANA_SLIP_SOUND_PATH
const SOAP_THROW_SOUND_PATH := ProjectileItemAudio.SOAP_THROW_SOUND_PATH
const SOAP_LAND_SOUND_PATH := ProjectileItemAudio.SOAP_LAND_SOUND_PATH
const SOAP_SLIP_SOUND_PATH := ProjectileItemAudio.SOAP_SLIP_SOUND_PATH
const SPIDER_MINE_WALK_SOUND_PATH := ProjectileItemAudio.SPIDER_MINE_WALK_SOUND_PATH
const SPIDER_MINE_SETUP_SOUND_PATH := ProjectileItemAudio.SPIDER_MINE_SETUP_SOUND_PATH
const BOMB_SURPRISE_ATTACH_SOUND_PATH := ProjectileItemAudio.BOMB_SURPRISE_ATTACH_SOUND_PATH
const BOMB_SURPRISE_TICK1_SOUND_PATH := ProjectileItemAudio.BOMB_SURPRISE_TICK1_SOUND_PATH
const BOMB_SURPRISE_TICK2_SOUND_PATH := ProjectileItemAudio.BOMB_SURPRISE_TICK2_SOUND_PATH
const BOMB_SURPRISE_URGENT_TICK_SOUND_PATH := ProjectileItemAudio.BOMB_SURPRISE_URGENT_TICK_SOUND_PATH
const BOMB_SURPRISE_SELF_EXPLOSION_SOUND_PATH := ProjectileItemAudio.BOMB_SURPRISE_SELF_EXPLOSION_SOUND_PATH
const BOMB_SURPRISE_ATTACH_GAIN_DB := ProjectileItemAudio.BOMB_SURPRISE_ATTACH_GAIN_DB
const BOMB_SURPRISE_TRANSFER_GAIN_DB := ProjectileItemAudio.BOMB_SURPRISE_TRANSFER_GAIN_DB
const BOMB_SURPRISE_URGENT_TICK_GAIN_DB := ProjectileItemAudio.BOMB_SURPRISE_URGENT_TICK_GAIN_DB
const BOMB_SURPRISE_EXPLOSION_GAIN_DB := ProjectileItemAudio.BOMB_SURPRISE_EXPLOSION_GAIN_DB
const ROUND_SET_SOUND_PATH := SharedStageFeedbackAudio.ROUND_SET_SOUND_PATH
const ROUND_DEFEAT_SOUND_PATH := SharedStageFeedbackAudio.ROUND_DEFEAT_SOUND_PATH
const STAGE_CLEAR_GONG_SOUND_PATH := SharedStageFeedbackAudio.STAGE_CLEAR_GONG_SOUND_PATH
const BALL_SPAWN_INTRO_SOUND_PATH := SharedStageFeedbackAudio.BALL_SPAWN_INTRO_SOUND_PATH
const STAGE_LANDING_ZOOM_INTRO_SOUND_PATH := SharedStageFeedbackAudio.STAGE_LANDING_ZOOM_INTRO_SOUND_PATH
const BALLOON_POP_SOUND_PATH := SharedStageFeedbackAudio.BALLOON_POP_SOUND_PATH
const STAGE1_BALLOON_DOOR_SOUND_PATH := SharedStageFeedbackAudio.STAGE1_BALLOON_DOOR_SOUND_PATH
const STAGE1_BALLOON_MACHINE_SOUND_PATH := SharedStageFeedbackAudio.STAGE1_BALLOON_MACHINE_SOUND_PATH
const STAR_COLLECT_SOUND_PATH := SharedStageFeedbackAudio.STAR_COLLECT_SOUND_PATH
const LEAF_SHIELD_SOUND_PATH := SharedStageFeedbackAudio.LEAF_SHIELD_SOUND_PATH
# 트램펄린(trampoline) 액티브 아이템이 공을 위로 튕겨내는(launch) 순간 재생하는 "보잉" 큐.
const TRAMPOLINE_BOUNCE_SOUND_PATH := SharedStageFeedbackAudio.TRAMPOLINE_BOUNCE_SOUND_PATH
const TRAMPOLINE_BOUNCE_GAIN_DB := SharedStageFeedbackAudio.TRAMPOLINE_BOUNCE_GAIN_DB
# 스테이지1 BGM 단일화(2026-07-21): Shamanic Bell Rite.
# 구 3곡 랜덤 풀(stage1bgm.mp3/stage1bgm2.ogg/stage1bgm3.ogg)은 에셋 삭제,
# 조선의 달북 제2악장(stage1_joseon_dalbuk_mv2_bgm.wav)은 미배선 예비 에셋.
# 풀 선택 머신(STAGE1_BGM_NAMES)은 단일 원소로 유지 — 추후 풀 재확장 가능.
const STAGE1_BGM_PATH := StageBgmAudio.STAGE1_BGM_PATH
const STAGE2_BGM_PATH := StageBgmAudio.STAGE2_BGM_PATH
const STAGE2_ALT_BGM_PATH := StageBgmAudio.STAGE2_ALT_BGM_PATH
const STAGE3_BGM_PATH := StageBgmAudio.STAGE3_BGM_PATH
const STAGE4_BGM_PATH := StageBgmAudio.STAGE4_BGM_PATH
const STAGE4_PHASE2_BGM_PATH := StageBgmAudio.STAGE4_PHASE2_BGM_PATH
const STAGE5_BGM_PATH := StageBgmAudio.STAGE5_BGM_PATH
const STAGE6_BGM_PATH := StageBgmAudio.STAGE6_BGM_PATH
const STAGE7_BGM_PATH := StageBgmAudio.STAGE7_BGM_PATH
const PADDLE_HIT_SOUND_COOLDOWN := 0.06
const WALL_HIT_SOUND_COOLDOWN := 0.035
const SCOREBOARD_SOUND_VOLUME_DB := SharedStageFeedbackAudio.ROUND_SET_GAIN_DB
const UI_MOVE_SOUND_PATH := GameUiFeedbackAudio.UI_MOVE_SOUND_PATH
const UI_CONFIRM_SOUND_PATH := GameUiFeedbackAudio.UI_CONFIRM_SOUND_PATH
const UI_BACK_SOUND_PATH := GameUiFeedbackAudio.UI_BACK_SOUND_PATH
# 퍽 선택화면에서 퍽을 확정(선택)했을 때 재생하는 마법 보상 확인음. 일반 퍽 픽에 쓰인다
	# (액티브 언락 퍽은 오브로 날아가는 비행 연출 사운드를 유지).
const UI_PERK_SELECT_SOUND_PATH := GameUiFeedbackAudio.UI_PERK_SELECT_SOUND_PATH
const CHARACTER_INFO_TOGGLE_SOUND_PATH := GameUiFeedbackAudio.CHARACTER_INFO_TOGGLE_SOUND_PATH
const UI_MOVE_GAIN_DB := GameUiFeedbackAudio.UI_MOVE_GAIN_DB
const UI_CONFIRM_GAIN_DB := GameUiFeedbackAudio.UI_CONFIRM_GAIN_DB
const UI_BACK_GAIN_DB := GameUiFeedbackAudio.UI_BACK_GAIN_DB
const UI_PERK_SELECT_GAIN_DB := GameUiFeedbackAudio.UI_PERK_SELECT_GAIN_DB
const CHARACTER_INFO_TOGGLE_GAIN_DB := GameUiFeedbackAudio.CHARACTER_INFO_TOGGLE_GAIN_DB
const DEFAULT_BGM_VOLUME := GameAudioBusController.DEFAULT_BGM_VOLUME
const DEFAULT_SFX_VOLUME := GameAudioBusController.DEFAULT_SFX_VOLUME
# 0.75는 구 주력 mp3(-9.9 LUFS)의 과열을 깎던 값 — 신곡은 -15.1 LUFS라
# 타 스테이지 표준 게인으로 복귀. 라이브 청감에서 재튜닝 가능.
const STAGE1_BGM_GAIN := StageBgmAudio.STAGE1_BGM_GAIN
const STAGE2_BGM_GAIN := StageBgmAudio.STAGE2_BGM_GAIN
const STAGE3_BGM_GAIN := StageBgmAudio.STAGE3_BGM_GAIN
const STAGE4_BGM_GAIN := StageBgmAudio.STAGE4_BGM_GAIN
const STAGE5_BGM_GAIN := StageBgmAudio.STAGE5_BGM_GAIN
const STAGE6_BGM_GAIN := StageBgmAudio.STAGE6_BGM_GAIN
const STAGE7_BGM_GAIN := StageBgmAudio.STAGE7_BGM_GAIN
const STAGE1_BGM_NAMES := StageBgmAudio.STAGE1_BGM_NAMES
const STAGE2_BGM_NAMES := StageBgmAudio.STAGE2_BGM_NAMES
const BGM_BUS_NAME := GameAudioBusController.BGM_BUS_NAME
const SFX_BUS_NAME := GameAudioBusController.SFX_BUS_NAME
const SFX_PAN_PADDLE_BUS_NAME := GameAudioBusController.PADDLE_PAN_BUS_NAME
const SFX_PAN_WALL_BUS_NAME := GameAudioBusController.WALL_PAN_BUS_NAME
const CHARACTER_INFO_BGM_MUFFLE_CUTOFF_HZ := GameAudioBusController.CHARACTER_INFO_BGM_MUFFLE_CUTOFF_HZ
const SPELLBREAKER_GUARD_PARRY_SOUND_PATH := PerkFusionCombatAudio.SPELLBREAKER_GUARD_PARRY_SOUND_PATH
const SPELLBREAKER_GUARD_PARRY_GAIN_DB := PerkFusionCombatAudio.SPELLBREAKER_GUARD_PARRY_GAIN_DB
const AUDIO_SETUP_STEP_COUNT := 7
const BGM_SETUP_STEP_COUNT := StageBgmAudio.SETUP_STEP_COUNT
const PLAYFIELD_LEFT_X := GameAudioBusController.PLAYFIELD_LEFT_X
const PLAYFIELD_RIGHT_X := GameAudioBusController.PLAYFIELD_RIGHT_X
const PLAYFIELD_CENTER_X := GameAudioBusController.PLAYFIELD_CENTER_X
const HIT_PAN_STRENGTH := GameAudioBusController.HIT_PAN_STRENGTH
const HAN_MIRYANG_PROLOGUE_TABLET_CRACK_SOUND_PATH := "res://assets/sounds/blocking.wav"
const HAN_MIRYANG_PROLOGUE_TABLET_CRACK_PITCH := 0.45
const HAN_MIRYANG_PROLOGUE_TABLET_CRACK_TAIL_PITCH := 0.325

var owner_node: Node
var player_factory: Object = GameAudioPlayerFactory.new()
var han_miryang_prologue_tablet_crack_sfx: AudioStreamPlayer
var han_miryang_prologue_tablet_crack_tail_sfx: AudioStreamPlayer
var blacksmith_thor_shield_audio: Object = BlacksmithThorShieldAudio.new()
var perk_fusion_combat_audio: Object = PerkFusionCombatAudio.new()
var commando_skill_audio: Object = CommandoSkillAudio.new()
var core_ball_dash_audio: Object = CoreBallDashAudio.new()
var paddle_hit_audio_layers: Object = PaddleHitAudioLayers.new()
var elemental_combat_audio: Object = ElementalCombatAudio.new()
var game_audio_bus_controller: Object = GameAudioBusController.new()
var game_audio_setup_controller: Object = GameAudioSetupController.new()
var game_ui_feedback_audio: Object = GameUiFeedbackAudio.new()
var item_reward_feedback_audio: Object = ItemRewardFeedbackAudio.new()
var projectile_item_audio: Object = ProjectileItemAudio.new()
var shared_stage_feedback_audio: Object = SharedStageFeedbackAudio.new()
var stage_bgm_audio: Object = StageBgmAudio.new()
var stage_bgm_playback_controller: Object = StageBgmPlaybackController.new()
var transformation_item_audio: Object = TransformationItemAudio.new()
var smasher_skill_audio: Object = SmasherSkillAudio.new()
var stage1_boss_skill_audio: Object = Stage1BossSkillAudio.new()
var viper_skill_audio: Object = ViperSkillAudio.new()
var lingpet_acquisition_audio: Object = LingpetAcquisitionAudio.new()
var lingpet_click_voice_audio: Object = LingpetClickVoiceAudio.new()
var lingpet_combat_audio: Object = LingpetCombatAudio.new()
var stage2_battle_audio: Object = Stage2BattleAudio.new()
var stage3_battle_audio: Object = Stage3BattleAudio.new()
var stage4_ponk_audio: Object = Stage4PonkAudio.new()
var stage5_hongryun_audio: Object = Stage5HongryunAudio.new()
var stage6_tetriser_audio: Object = Stage6TetriserAudio.new()
var stage7_akamu_audio: Object = Stage7AkamuAudio.new()
var paddle_sound_cooldown := 0.0
var wall_sound_cooldown := 0.0
var current_bgm_name: String:
	get:
		return stage_bgm_playback_controller.get_current_bgm_name()
	set(value):
		stage_bgm_playback_controller.set_current_bgm_name(value)
var primed_bgm_volumes: Dictionary:
	get:
		return stage_bgm_playback_controller.get_primed_bgm_volumes()
	set(value):
		stage_bgm_playback_controller.set_primed_bgm_volumes(value)
var bgm_volume: float:
	get:
		return game_audio_bus_controller.get_bgm_volume()
	set(value):
		game_audio_bus_controller.set_bgm_volume_state(value)
var sfx_volume: float:
	get:
		return game_audio_bus_controller.get_sfx_volume()
	set(value):
		game_audio_bus_controller.set_sfx_volume_state(value)
var audio_bus_volumes_adopted: bool:
	get:
		return game_audio_bus_controller.get_audio_bus_volumes_adopted()
	set(value):
		game_audio_bus_controller.set_audio_bus_volumes_adopted(value)
var bgm_muted: bool:
	get:
		return stage_bgm_playback_controller.is_bgm_muted()
	set(value):
		stage_bgm_playback_controller.set_bgm_muted_state(value)
var muted_bgm_name: String:
	get:
		return stage_bgm_playback_controller.get_muted_bgm_name()
	set(value):
		stage_bgm_playback_controller.set_muted_bgm_name(value)
var ui_move_sfx: AudioStreamPlayer:
	get:
		return game_ui_feedback_audio.get_player("ui_move") as AudioStreamPlayer
	set(value):
		game_ui_feedback_audio.set_player("ui_move", value)
var ui_confirm_sfx: AudioStreamPlayer:
	get:
		return game_ui_feedback_audio.get_player("ui_confirm") as AudioStreamPlayer
	set(value):
		game_ui_feedback_audio.set_player("ui_confirm", value)
var ui_back_sfx: AudioStreamPlayer:
	get:
		return game_ui_feedback_audio.get_player("ui_back") as AudioStreamPlayer
	set(value):
		game_ui_feedback_audio.set_player("ui_back", value)
var ui_perk_select_sfx: AudioStreamPlayer:
	get:
		return game_ui_feedback_audio.get_player("ui_perk_select") as AudioStreamPlayer
	set(value):
		game_ui_feedback_audio.set_player("ui_perk_select", value)
var character_info_toggle_sfx: AudioStreamPlayer:
	get:
		return game_ui_feedback_audio.get_player("character_info_toggle") as AudioStreamPlayer
	set(value):
		game_ui_feedback_audio.set_player("character_info_toggle", value)
var paddle_hit_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("paddle_hit") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("paddle_hit", value)
var serve_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("serve") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("serve", value)
var pingpong_serve_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("pingpong_serve") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("pingpong_serve", value)
var wall_hit_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("wall_hit") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("wall_hit", value)
var dash_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("dash") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("dash", value)
var half_dash_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("half_dash") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("half_dash", value)
var dash_delay_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("dash_delay") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("dash_delay", value)
var dash_charge_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("dash_charge") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("dash_charge", value)
var bust_up_dash_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("bust_up_dash") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("bust_up_dash", value)
var boost_charging_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("boost_charging") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("boost_charging", value)
var soul_burst_dash_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("soul_burst_dash") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("soul_burst_dash", value)
var dash_spirit_delete_sfx: AudioStreamPlayer:
	get:
		return core_ball_dash_audio.get_player("dash_spirit_delete") as AudioStreamPlayer
	set(value):
		core_ball_dash_audio.set_player("dash_spirit_delete", value)
var drive_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("drive") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("drive", value)
var mika_drive_voice_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("drive_voice") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("drive_voice", value)
var mika_drive_voice_streams: Array[AudioStream]:
	get:
		return smasher_skill_audio.get_byeokryeokta_voice_streams()
	set(value):
		smasher_skill_audio.set_byeokryeokta_voice_streams(value)
var plasma_charge_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("plasma_charge") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("plasma_charge", value)
var plasma_shoot_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("plasma_shoot") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("plasma_shoot", value)
var plasma_shock_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("plasma_shock") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("plasma_shock", value)
var recovery_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("recovery") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("recovery", value)
var cleanse_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("cleanse") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("cleanse", value)
var warp_gate_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("warp_gate") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("warp_gate", value)
var magnum_grip_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("magnum_grip") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("magnum_grip", value)
var smasher_wheel_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("smasher_wheel") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("smasher_wheel", value)
var mika_smasher_wheel_voice_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("smasher_wheel_voice") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("smasher_wheel_voice", value)
var mika_smasher_wheel_voice_streams: Array[AudioStream]:
	get:
		return smasher_skill_audio.get_pungun_cheonseonmu_voice_streams()
	set(value):
		smasher_skill_audio.set_pungun_cheonseonmu_voice_streams(value)
var smasher_overdrive_activation_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("smasher_overdrive_activation") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("smasher_overdrive_activation", value)
var mika_smasher_overdrive_voice_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("smasher_overdrive_voice") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("smasher_overdrive_voice", value)
var mika_smasher_overdrive_voice_streams: Array[AudioStream]:
	get:
		return smasher_skill_audio.get_smasher_overdrive_voice_streams()
	set(value):
		smasher_skill_audio.set_smasher_overdrive_voice_streams(value)
var mika_void_phantom_voice_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("void_phantom_voice") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("void_phantom_voice", value)
var mika_void_phantom_voice_streams: Array[AudioStream]:
	get:
		return smasher_skill_audio.get_void_phantom_voice_streams()
	set(value):
		smasher_skill_audio.set_void_phantom_voice_streams(value)
var void_phantom_charge_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("void_phantom_charge") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("void_phantom_charge", value)
var void_phantom_launch_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("void_phantom_launch") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("void_phantom_launch", value)
var shield_kiting_wind_up_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("shield_kiting_wind_up") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("shield_kiting_wind_up", value)
var shield_kiting_launch_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("shield_kiting_launch") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("shield_kiting_launch", value)
var shield_kiting_hit_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("shield_kiting_hit") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("shield_kiting_hit", value)
var whip_sfx: AudioStreamPlayer:
	get:
		return stage1_boss_skill_audio.get_player("whip") as AudioStreamPlayer
	set(value):
		stage1_boss_skill_audio.set_player("whip", value)
var gaksital_fan_sfx: AudioStreamPlayer:
	get:
		return stage1_boss_skill_audio.get_player("gaksital_fan") as AudioStreamPlayer
	set(value):
		stage1_boss_skill_audio.set_player("gaksital_fan", value)
var gaksital_fan_sfx_layers: Array:
	get:
		return stage1_boss_skill_audio.get_fan_layers()
	set(value):
		stage1_boss_skill_audio.set_fan_layers(value)
var gaksital_fan_sfx_cursor := 0
var whipcrack_sfx: AudioStreamPlayer:
	get:
		return stage1_boss_skill_audio.get_player("whipcrack") as AudioStreamPlayer
	set(value):
		stage1_boss_skill_audio.set_player("whipcrack", value)
var thor_shield_open_sfx: AudioStreamPlayer:
	get:
		return blacksmith_thor_shield_audio.get_player("open") as AudioStreamPlayer
	set(value):
		blacksmith_thor_shield_audio.set_player("open", value)
var thor_shield_close_sfx: AudioStreamPlayer:
	get:
		return blacksmith_thor_shield_audio.get_player("close") as AudioStreamPlayer
	set(value):
		blacksmith_thor_shield_audio.set_player("close", value)
var thor_shield_swing_sfx: AudioStreamPlayer:
	get:
		return blacksmith_thor_shield_audio.get_player("swing") as AudioStreamPlayer
	set(value):
		blacksmith_thor_shield_audio.set_player("swing", value)
var thor_shield_block_sfx: AudioStreamPlayer:
	get:
		return blacksmith_thor_shield_audio.get_player("block") as AudioStreamPlayer
	set(value):
		blacksmith_thor_shield_audio.set_player("block", value)
var spellbreaker_guard_parry_sfx: AudioStreamPlayer:
	get:
		return perk_fusion_combat_audio.get_player("spellbreaker_guard_parry") as AudioStreamPlayer
	set(value):
		perk_fusion_combat_audio.set_player("spellbreaker_guard_parry", value)
var viper_jetpack_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("jetpack") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("jetpack", value)
var viper_backstep_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("backstep") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("backstep", value)
var viper_shadow_kick_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("shadow_kick") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("shadow_kick", value)
var viper_marshal_kick_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("marshal_kick") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("marshal_kick", value)
var viper_dive_prep_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("dive_prep") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("dive_prep", value)
var viper_dive_strike_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("dive_strike") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("dive_strike", value)
var viper_ignition_aura_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("ignition_aura") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("ignition_aura", value)
var viper_ignition_aura_fallback_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("ignition_aura_fallback") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("ignition_aura_fallback", value)
var viper_phantom_show_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("phantom_show") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("phantom_show", value)
var viper_phantom_kick_hit_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("phantom_kick_hit") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("phantom_kick_hit", value)
var viper_blade_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("blade") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("blade", value)
var viper_blade_spin_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("blade_spin") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("blade_spin", value)
var viper_venom_moving_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("venom_moving") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("venom_moving", value)
var viper_venom_attack_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("venom_attack") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("venom_attack", value)
var viper_hwarang_kick_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("hwarang_kick") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("hwarang_kick", value)
var viper_kick_guard_knockback_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("kick_guard_knockback") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("kick_guard_knockback", value)
var viper_dual_glitch_windup_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("dual_glitch_windup") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("dual_glitch_windup", value)
var viper_dual_glitch_split_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("dual_glitch_split") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("dual_glitch_split", value)
var chaos_spear_windup_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("chaos_spear_windup") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("chaos_spear_windup", value)
var chaos_spear_flying_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("chaos_spear_flying") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("chaos_spear_flying", value)
var chaos_spear_impact_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("chaos_spear_impact") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("chaos_spear_impact", value)
var chaos_spear_blackhole_sfx: AudioStreamPlayer:
	get:
		return viper_skill_audio.get_player("chaos_spear_blackhole") as AudioStreamPlayer
	set(value):
		viper_skill_audio.set_player("chaos_spear_blackhole", value)
var commando_supply_radio_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("supply_radio") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("supply_radio", value)
var commando_supply_radio_loop_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("supply_radio_loop") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("supply_radio_loop", value)
var commando_supply_aircraft_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("supply_aircraft") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("supply_aircraft", value)
var commando_weapon_change_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("weapon_change") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("weapon_change", value)
var commando_fire_support_radio_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("fire_support_radio") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("fire_support_radio", value)
var commando_fire_support_aircraft_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("fire_support_aircraft") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("fire_support_aircraft", value)
var commando_slingshot_fire_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("slingshot_fire") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("slingshot_fire", value)
var commando_pistol_ready_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("pistol_ready") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("pistol_ready", value)
var commando_pistol_fire_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("pistol_fire") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("pistol_fire", value)
var commando_pistol_reload_start_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("pistol_reload_start") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("pistol_reload_start", value)
var commando_pistol_reload_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("pistol_reload") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("pistol_reload", value)
var commando_reload_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("reload") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("reload", value)
var commando_ak47_fire_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("ak47_fire") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("ak47_fire", value)
var commando_ak47_fire_sfx_layers: Array:
	get:
		return commando_skill_audio.get_ak47_fire_layers()
	set(value):
		commando_skill_audio.set_ak47_fire_layers(value)
var commando_ak47_fire_sfx_cursor := 0
var commando_bazooka_fire_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("bazooka_fire") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("bazooka_fire", value)
var commando_net_capture_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("net_capture") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("net_capture", value)
var commando_net_constrict_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("net_constrict") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("net_constrict", value)
var commando_bowling_trap_install_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("bowling_trap_install") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("bowling_trap_install", value)
var commando_bowling_trap_snap_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("bowling_trap_snap") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("bowling_trap_snap", value)
var commando_suicide_drone_sfx: AudioStreamPlayer:
	get:
		return commando_skill_audio.get_player("suicide_drone") as AudioStreamPlayer
	set(value):
		commando_skill_audio.set_player("suicide_drone", value)
var item_get_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("item_get") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("item_get", value)
var drink_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("drink") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("drink", value)
var active_item_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("active_item") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("active_item", value)
var trade_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("trade") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("trade", value)
var brick_wall_destroy_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("brick_wall_destroy") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("brick_wall_destroy", value)
var alchemy_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("alchemy") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("alchemy", value)
var pandora_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("pandora") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("pandora", value)
var lucky_coin_spawn_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("lucky_coin_spawn") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("lucky_coin_spawn", value)
var foul_whistle_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("foul_whistle") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("foul_whistle", value)
var megingjord_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("megingjord") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("megingjord", value)
var legendary_open_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("legendary_open") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("legendary_open", value)
var angel_blessing_roll_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("angel_blessing_roll") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("angel_blessing_roll", value)
var angel_blessing_absorb_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("angel_blessing_absorb") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("angel_blessing_absorb", value)
var angel_blessing_absorb_sfx_layers: Array:
	get:
		return item_reward_feedback_audio.get_absorb_layers()
	set(value):
		item_reward_feedback_audio.set_absorb_layers(value)
var angel_blessing_absorb_sfx_cursor := 0
var result_box_open_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("result_box_open") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("result_box_open", value)
var defeat_jewel_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("defeat_jewel") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("defeat_jewel", value)
var defeat_gem_shatter_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("defeat_gem_shatter") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("defeat_gem_shatter", value)
var cold_boot_chnk_latch_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("cold_boot_chnk_latch") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("cold_boot_chnk_latch", value)
var cold_boot_post_ramp_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("cold_boot_post_ramp") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("cold_boot_post_ramp", value)
var cold_boot_ignition_thunk_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("cold_boot_ignition_thunk") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("cold_boot_ignition_thunk", value)
var cold_boot_awaken_fanfare_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("cold_boot_awaken_fanfare") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("cold_boot_awaken_fanfare", value)
var lingpet_acquire_cutin_sfx: AudioStreamPlayer:
	get:
		return lingpet_acquisition_audio.get_player("cutin") as AudioStreamPlayer
	set(value):
		lingpet_acquisition_audio.set_player("cutin", value)
var lingpet_acquire_click_deep_bass_sfx: AudioStreamPlayer:
	get:
		return lingpet_acquisition_audio.get_player("click_deep_bass") as AudioStreamPlayer
	set(value):
		lingpet_acquisition_audio.set_player("click_deep_bass", value)
var lingpet_acquire_click_crackle_sweep_sfx: AudioStreamPlayer:
	get:
		return lingpet_acquisition_audio.get_player("click_crackle_sweep") as AudioStreamPlayer
	set(value):
		lingpet_acquisition_audio.set_player("click_crackle_sweep", value)
var lingpet_guardian_enhance_roll_loop_sfx: AudioStreamPlayer:
	get:
		return lingpet_acquisition_audio.get_player("guardian_enhance_roll_loop") as AudioStreamPlayer
	set(value):
		lingpet_acquisition_audio.set_player("guardian_enhance_roll_loop", value)
var lingpet_guardian_enhance_stamp_sfx: AudioStreamPlayer:
	get:
		return lingpet_acquisition_audio.get_player("guardian_enhance_stamp") as AudioStreamPlayer
	set(value):
		lingpet_acquisition_audio.set_player("guardian_enhance_stamp", value)
var lingpet_guardian_enhance_result_tail_sfx: AudioStreamPlayer:
	get:
		return lingpet_acquisition_audio.get_player("guardian_enhance_result_tail") as AudioStreamPlayer
	set(value):
		lingpet_acquisition_audio.set_player("guardian_enhance_result_tail", value)
var lingpet_lunabi_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("lunabi") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("lunabi", value)
var lingpet_volty_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("volty") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("volty", value)
var lingpet_milkring_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("milkring") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("milkring", value)
var lingpet_red_dragon_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("red_dragon") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("red_dragon", value)
var lingpet_maribo_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("maribo") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("maribo", value)
var lingpet_rabi_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("rabi") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("rabi", value)
var lingpet_lumion_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("lumion") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("lumion", value)
var lingpet_monkeyring_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("monkeyring") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("monkeyring", value)
var lingpet_onimaru_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("onimaru") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("onimaru", value)
var lingpet_orosha_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("orosha") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("orosha", value)
var lingpet_koyora_click_voice_sfx: AudioStreamPlayer:
	get:
		return lingpet_click_voice_audio.get_player("koyora") as AudioStreamPlayer
	set(value):
		lingpet_click_voice_audio.set_player("koyora", value)
var legendary_after_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("legendary_after") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("legendary_after", value)
var legendary_ending_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("legendary_ending") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("legendary_ending", value)
var ragnarok_shot_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("ragnarok_shot") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("ragnarok_shot", value)
var ragnarok_boom_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("ragnarok_boom") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("ragnarok_boom", value)
var ragnarok_shock_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("ragnarok_shock") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("ragnarok_shock", value)
var electric_shock_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("electric_shock") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("electric_shock", value)
var thunder_orb_shot_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("thunder_orb_shot") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("thunder_orb_shot", value)
var thunder_orb_boom_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("thunder_orb_boom") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("thunder_orb_boom", value)
var solar_bolt_strike_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("solar_bolt_strike") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("solar_bolt_strike", value)
var mini_spark_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("mini_spark") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("mini_spark", value)
var mini_spark_streams: Array[AudioStream]:
	get:
		return elemental_combat_audio.get_candidate_streams("mini_spark") as Array[AudioStream]
	set(value):
		elemental_combat_audio.set_candidate_streams("mini_spark", value)
var poseidon_wave_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("poseidon_wave") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("poseidon_wave", value)
var poseidon_charge_sfx: AudioStreamPlayer:
	get:
		return elemental_combat_audio.get_player("poseidon_charge") as AudioStreamPlayer
	set(value):
		elemental_combat_audio.set_player("poseidon_charge", value)
var timewatch_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("timewatch") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("timewatch", value)
var throw_before_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("throw_before") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("throw_before", value)
var throw_sfx: AudioStreamPlayer:
	get:
		return item_reward_feedback_audio.get_player("throw") as AudioStreamPlayer
	set(value):
		item_reward_feedback_audio.set_player("throw", value)
var horn_strawberry_change_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_change") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_change", value)
var horn_strawberry_eat_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_eat") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_eat", value)
var horn_strawberry_stem_fire_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_stem_fire") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_stem_fire", value)
var horn_strawberry_stem_hit_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_stem_hit") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_stem_hit", value)
var horn_strawberry_horn_charge_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_horn_charge") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_horn_charge", value)
var horn_strawberry_field_build_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_field_build") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_field_build", value)
var horn_strawberry_field_break_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_field_break") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_field_break", value)
var horn_strawberry_field_build_break_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_field_build_break") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_field_build_break", value)
var odins_eye_change_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("odins_eye_change") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("odins_eye_change", value)
var odins_eye_death_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("odins_eye_death") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("odins_eye_death", value)
var odins_eye_spirit_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("odins_eye_spirit") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("odins_eye_spirit", value)
var odins_eye_attack_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("odins_eye_attack") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("odins_eye_attack", value)
var odins_eye_shadow_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("odins_eye_shadow") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("odins_eye_shadow", value)
var horn_strawberry_bomb_trigger_sfx: AudioStreamPlayer:
	get:
		return transformation_item_audio.get_player("horn_strawberry_bomb_trigger") as AudioStreamPlayer
	set(value):
		transformation_item_audio.set_player("horn_strawberry_bomb_trigger", value)
var grenade_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("grenade") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("grenade", value)
var flashbomb_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("flashbomb") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("flashbomb", value)
var smokebomb_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("smokebomb") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("smokebomb", value)
var firebomb_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("firebomb") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("firebomb", value)
var boomerang_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("boomerang") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("boomerang", value)
var boomerang_hit_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("boomerang_hit") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("boomerang_hit", value)
var boomerang_break_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("boomerang_break") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("boomerang_break", value)
var shrapnel_armor_fire_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("shrapnel_armor_fire") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("shrapnel_armor_fire", value)
var shrapnel_armor_hit_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("shrapnel_armor_hit") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("shrapnel_armor_hit", value)
var banana_throw_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("banana_throw") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("banana_throw", value)
var banana_slip_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("banana_slip") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("banana_slip", value)
var soap_throw_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("soap_throw") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("soap_throw", value)
var soap_land_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("soap_land") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("soap_land", value)
var soap_slip_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("soap_slip") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("soap_slip", value)
var spider_mine_walk_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("spider_mine_walk") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("spider_mine_walk", value)
var spider_mine_setup_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("spider_mine_setup") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("spider_mine_setup", value)
var bomb_surprise_attach_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_attach") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_attach", value)
var bomb_surprise_transfer_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_transfer") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_transfer", value)
var bomb_surprise_tick1_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_tick1") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_tick1", value)
var bomb_surprise_tick2_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_tick2") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_tick2", value)
var bomb_surprise_urgent_tick_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_urgent_tick") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_urgent_tick", value)
var bomb_surprise_explosion_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_explosion") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_explosion", value)
var bomb_surprise_self_explosion_sfx: AudioStreamPlayer:
	get:
		return projectile_item_audio.get_player("bomb_surprise_self_explosion") as AudioStreamPlayer
	set(value):
		projectile_item_audio.set_player("bomb_surprise_self_explosion", value)
var power_smash_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("power_smash") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("power_smash", value)
var mika_power_smashing_voice_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("power_smashing_voice") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("power_smashing_voice", value)
var mika_power_smashing_voice_streams: Array[AudioStream]:
	get:
		return smasher_skill_audio.get_power_smashing_voice_streams()
	set(value):
		smasher_skill_audio.set_power_smashing_voice_streams(value)
var mika_ghost_smashing_voice_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("ghost_smashing_voice") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("ghost_smashing_voice", value)
var mika_ghost_smashing_voice_streams: Array[AudioStream]:
	get:
		return smasher_skill_audio.get_ghost_smashing_voice_streams()
	set(value):
		smasher_skill_audio.set_ghost_smashing_voice_streams(value)
var power_smash_launch_sfx: AudioStreamPlayer:
	get:
		return smasher_skill_audio.get_player("power_smash_launch") as AudioStreamPlayer
	set(value):
		smasher_skill_audio.set_player("power_smash_launch", value)
var round_set_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("round_set") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("round_set", value)
var round_defeat_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("round_defeat") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("round_defeat", value)
var stage_clear_gong_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("stage_clear_gong") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("stage_clear_gong", value)
var ball_spawn_intro_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("ball_spawn_intro") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("ball_spawn_intro", value)
var stage_landing_zoom_intro_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("stage_landing_zoom_intro") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("stage_landing_zoom_intro", value)
var balloon_pop_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("balloon_pop") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("balloon_pop", value)
var stage1_balloon_door_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("stage1_balloon_door") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("stage1_balloon_door", value)
var stage1_balloon_machine_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("stage1_balloon_machine") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("stage1_balloon_machine", value)
var star_collect_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("star_collect") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("star_collect", value)
var stage2_hydro_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("hydro") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("hydro", value)
var stage2_stonebreak_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("stonebreak") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("stonebreak", value)
var stage2_rockhit_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("rockhit") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("rockhit", value)
var stage2_rock_spawn_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("rock_spawn") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("rock_spawn", value)
var stage2_quake_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("quake") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("quake", value)
var stage2_boss_cry_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("boss_cry") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("boss_cry", value)
var stage2_speed_defense_start_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("speed_defense_start") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("speed_defense_start", value)
var stage2_speed_defense_hit_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("speed_defense_hit") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("speed_defense_hit", value)
var stage2_speed_defense_block_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("speed_defense_block") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("speed_defense_block", value)
var stage2_molewang_tunnel_start_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("molewang_tunnel_start") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("molewang_tunnel_start", value)
var stage2_molewang_tunnel_spike_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("molewang_tunnel_spike") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("molewang_tunnel_spike", value)
var stage2_molewang_tunnel_impact_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("molewang_tunnel_impact") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("molewang_tunnel_impact", value)
var stage2_molewang_spinning_claw_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("molewang_spinning_claw") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("molewang_spinning_claw", value)
var stage2_friend_mole_spawn_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("friend_mole_spawn") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("friend_mole_spawn", value)
var stage2_friend_mole_hit_sfx: AudioStreamPlayer:
	get:
		return stage2_battle_audio.get_player("friend_mole_hit") as AudioStreamPlayer
	set(value):
		stage2_battle_audio.set_player("friend_mole_hit", value)
var stage3_tail_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("tail") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("tail", value)
var stage3_psychoball_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("psychoball") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("psychoball", value)
var stage3_dollcurse_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("dollcurse") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("dollcurse", value)
var stage3_tears_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("tears") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("tears", value)
var stage3_chest_land_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("chest_land") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("chest_land", value)
var stage3_curse_explode_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("curse_explode") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("curse_explode", value)
var stage3_kuromi_awake_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("kuromi_awake") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("kuromi_awake", value)
var stage3_kuromi_stonebreak_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("kuromi_stonebreak") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("kuromi_stonebreak", value)
var stage3_kuromi_tongue_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("kuromi_tongue") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("kuromi_tongue", value)
var stage3_kuromi_swallow_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("kuromi_swallow") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("kuromi_swallow", value)
var stage3_kuromi_spit_sfx: AudioStreamPlayer:
	get:
		return stage3_battle_audio.get_player("kuromi_spit") as AudioStreamPlayer
	set(value):
		stage3_battle_audio.set_player("kuromi_spit", value)
var stage4_moon_shoot_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("moon_shoot") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("moon_shoot", value)
var stage4_fragment_shoot_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("fragment_shoot") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("fragment_shoot", value)
var stage4_temple_hit_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("temple_hit") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("temple_hit", value)
var stage4_birdkill_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("birdkill") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("birdkill", value)
var stage4_magnetic_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("magnetic") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("magnetic", value)
var stage4_meditation_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("meditation") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("meditation", value)
var stage4_meditation_after_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("meditation_after") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("meditation_after", value)
var stage4_illusion_sfx: AudioStreamPlayer:
	get:
		return stage4_ponk_audio.get_player("illusion") as AudioStreamPlayer
	set(value):
		stage4_ponk_audio.set_player("illusion", value)
var stage5_hongryun_fireball_sfx: AudioStreamPlayer:
	get:
		return stage5_hongryun_audio.get_primary_player("fireball") as AudioStreamPlayer
	set(value):
		stage5_hongryun_audio.set_primary_player("fireball", value)
var stage5_hongryun_charge_sfx: AudioStreamPlayer:
	get:
		return stage5_hongryun_audio.get_primary_player("charge") as AudioStreamPlayer
	set(value):
		stage5_hongryun_audio.set_primary_player("charge", value)
var stage5_hongryun_shoot_sfx: AudioStreamPlayer:
	get:
		return stage5_hongryun_audio.get_primary_player("shoot") as AudioStreamPlayer
	set(value):
		stage5_hongryun_audio.set_primary_player("shoot", value)
var stage6_tetriser_break_sfx: AudioStreamPlayer:
	get:
		return stage6_tetriser_audio.get_player("break") as AudioStreamPlayer
	set(value):
		stage6_tetriser_audio.set_player("break", value)
var stage6_tetriser_wall_sfx: AudioStreamPlayer:
	get:
		return stage6_tetriser_audio.get_player("wall") as AudioStreamPlayer
	set(value):
		stage6_tetriser_audio.set_player("wall", value)
var stage6_tetriser_super_sfx: AudioStreamPlayer:
	get:
		return stage6_tetriser_audio.get_player("super") as AudioStreamPlayer
	set(value):
		stage6_tetriser_audio.set_player("super", value)
var stage6_tetriser_big_sfx: AudioStreamPlayer:
	get:
		return stage6_tetriser_audio.get_player("big") as AudioStreamPlayer
	set(value):
		stage6_tetriser_audio.set_player("big", value)
var stage6_tetriser_shield_sfx: AudioStreamPlayer:
	get:
		return stage6_tetriser_audio.get_player("shield") as AudioStreamPlayer
	set(value):
		stage6_tetriser_audio.set_player("shield", value)
var stage6_tetriser_laser_sfx: AudioStreamPlayer:
	get:
		return stage6_tetriser_audio.get_player("laser") as AudioStreamPlayer
	set(value):
		stage6_tetriser_audio.set_player("laser", value)
var stage7_akamu_shuriken_shoot_sfx: AudioStreamPlayer:
	get:
		return stage7_akamu_audio.get_player("shuriken_shoot") as AudioStreamPlayer
	set(value):
		stage7_akamu_audio.set_player("shuriken_shoot", value)
var stage7_akamu_shuriken_hit_sfx: AudioStreamPlayer:
	get:
		return stage7_akamu_audio.get_player("shuriken_hit") as AudioStreamPlayer
	set(value):
		stage7_akamu_audio.set_player("shuriken_hit", value)
var stage7_akamu_cloud_sfx: AudioStreamPlayer:
	get:
		return stage7_akamu_audio.get_player("cloud") as AudioStreamPlayer
	set(value):
		stage7_akamu_audio.set_player("cloud", value)
var stage7_akamu_aura_block_sfx: AudioStreamPlayer:
	get:
		return stage7_akamu_audio.get_player("aura_block") as AudioStreamPlayer
	set(value):
		stage7_akamu_audio.set_player("aura_block", value)
var stage7_akamu_clone_spawn_sfx: AudioStreamPlayer:
	get:
		return stage7_akamu_audio.get_player("clone_spawn") as AudioStreamPlayer
	set(value):
		stage7_akamu_audio.set_player("clone_spawn", value)
var stage7_akamu_clone_out_sfx: AudioStreamPlayer:
	get:
		return stage7_akamu_audio.get_player("clone_out") as AudioStreamPlayer
	set(value):
		stage7_akamu_audio.set_player("clone_out", value)
var stage5_hongryun_hurt_sfx: Array:
	get:
		return stage5_hongryun_audio.get_hurt_players()
	set(value):
		stage5_hongryun_audio.set_hurt_players(value)
var leaf_shield_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("leaf_shield") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("leaf_shield", value)
var trampoline_bounce_sfx: AudioStreamPlayer:
	get:
		return shared_stage_feedback_audio.get_player("trampoline_bounce") as AudioStreamPlayer
	set(value):
		shared_stage_feedback_audio.set_player("trampoline_bounce", value)
var stage1_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage1") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage1", value)
var stage2_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage2") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage2", value)
var stage2_alt_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage2_alt") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage2_alt", value)
var stage3_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage3") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage3", value)
var stage4_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage4") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage4", value)
var stage4_phase2_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage4_phase2") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage4_phase2", value)
var stage5_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage5") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage5", value)
var stage6_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage6") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage6", value)
var stage7_bgm: AudioStreamPlayer:
	get:
		return stage_bgm_audio.get_player("stage7") as AudioStreamPlayer
	set(value):
		stage_bgm_audio.set_player("stage7", value)
var stage1_bgm_rng: RandomNumberGenerator:
	get:
		return stage_bgm_playback_controller.get_stage1_bgm_rng() as RandomNumberGenerator
	set(value):
		stage_bgm_playback_controller.set_stage1_bgm_rng(value)
var stage1_bgm_rng_ready: bool:
	get:
		return stage_bgm_playback_controller.is_stage1_bgm_rng_ready()
	set(value):
		stage_bgm_playback_controller.set_stage1_bgm_rng_ready(value)
var stage2_bgm_rng: RandomNumberGenerator:
	get:
		return stage_bgm_playback_controller.get_stage2_bgm_rng() as RandomNumberGenerator
	set(value):
		stage_bgm_playback_controller.set_stage2_bgm_rng(value)
var stage2_bgm_rng_ready: bool:
	get:
		return stage_bgm_playback_controller.is_stage2_bgm_rng_ready()
	set(value):
		stage_bgm_playback_controller.set_stage2_bgm_rng_ready(value)
var _audio_setup_step: int:
	get:
		return game_audio_setup_controller.get_audio_setup_step()
	set(value):
		game_audio_setup_controller.set_audio_setup_step(value)
var _audio_setup_stream_prewarm_group: int:
	get:
		return game_audio_setup_controller.get_audio_setup_stream_prewarm_group()
	set(value):
		game_audio_setup_controller.set_audio_setup_stream_prewarm_group(value)
var _audio_setup_stream_prewarm_index: int:
	get:
		return game_audio_setup_controller.get_audio_setup_stream_prewarm_index()
	set(value):
		game_audio_setup_controller.set_audio_setup_stream_prewarm_index(value)
var _bgm_setup_step: int:
	get:
		return game_audio_setup_controller.get_bgm_setup_step()
	set(value):
		game_audio_setup_controller.set_bgm_setup_step(value)
var paddle_hit_panner: AudioEffectPanner:
	get:
		return game_audio_bus_controller.get_paddle_hit_panner() as AudioEffectPanner
	set(value):
		game_audio_bus_controller.set_paddle_hit_panner(value)
var wall_hit_panner: AudioEffectPanner:
	get:
		return game_audio_bus_controller.get_wall_hit_panner() as AudioEffectPanner
	set(value):
		game_audio_bus_controller.set_wall_hit_panner(value)


func setup(parent: Node) -> void:
	while not setup_step(parent):
		pass


func get_setup_progress() -> float:
	var setup_complete := _is_setup_complete()
	if not setup_complete:
		_ensure_audio_setup_stream_paths(_audio_setup_step)
	return game_audio_setup_controller.get_setup_progress(
		AUDIO_SETUP_STEP_COUNT,
		BGM_SETUP_STEP_COUNT,
		setup_complete
	)


func setup_step(parent: Node) -> bool:
	if owner_node == parent and _is_setup_complete():
		return true
	if owner_node != parent:
		owner_node = parent
		game_audio_setup_controller.reset()

	if not _prewarm_audio_setup_streams_step():
		return false

	match _audio_setup_step:
		0:
			_setup_core_ball_sfx()
		1:
			_setup_smasher_skill_sfx()
		2:
			_setup_commando_skill_sfx()
		3:
			_setup_item_command_sfx()
		4:
			_setup_projectile_item_sfx()
		5:
			_setup_stage_feedback_sfx()
		6:
			if not _setup_bgm_players_step():
				_apply_audio_buses_and_volumes()
				return false
		_:
			return _is_setup_complete()

	_apply_audio_buses_and_volumes()
	game_audio_setup_controller.advance_audio_setup_step()
	return _is_setup_complete()


func _setup_core_ball_sfx() -> void:
	_ensure_hit_pan_buses()
	game_ui_feedback_audio.setup(owner_node, player_factory)
	core_ball_dash_audio.setup(owner_node, player_factory)
	paddle_hit_audio_layers.setup(
		owner_node,
		paddle_hit_sfx.stream if paddle_hit_sfx != null else null,
		SFX_PAN_PADDLE_BUS_NAME
	)
	_enable_loop(dash_delay_sfx)


func _setup_smasher_skill_sfx() -> void:
	smasher_skill_audio.setup_skill_players(owner_node, player_factory)
	_enable_loop(plasma_charge_sfx)
	_enable_loop(plasma_shock_sfx)
	_enable_loop(warp_gate_sfx)
	_enable_loop(magnum_grip_sfx)
	_enable_loop(smasher_wheel_sfx)
	stage1_boss_skill_audio.setup(owner_node, player_factory, Callable(self, "_create_optional_sfx"))
	gaksital_fan_sfx_cursor = 0
	blacksmith_thor_shield_audio.setup(owner_node, player_factory)
	viper_skill_audio.setup(owner_node, player_factory)
	_enable_loop(viper_jetpack_sfx)
	_enable_loop(chaos_spear_blackhole_sfx)


func _setup_commando_skill_sfx() -> void:
	commando_skill_audio.setup(Callable(self, "_create_optional_sfx"))
	# Python parity (supply_drop.py start_radio_loop): radio.wav (~3.5s) plays
	# exactly once per hold session and runs to its natural end -- the "loop"
	# name is historical. Do not _enable_loop this player; with the state-side
	# tail no longer force-stopping it, a looping stream would never end.
	_enable_loop(commando_supply_aircraft_sfx)
	_enable_loop(commando_fire_support_aircraft_sfx)
	commando_ak47_fire_sfx_cursor = 0
	_enable_loop(commando_suicide_drone_sfx)


func _setup_item_command_sfx() -> void:
	item_reward_feedback_audio.setup(owner_node, player_factory, Callable(self, "_create_optional_sfx"))
	angel_blessing_absorb_sfx_cursor = 0
	lingpet_acquisition_audio.setup(owner_node, player_factory)
	_enable_loop(lingpet_guardian_enhance_roll_loop_sfx)
	lingpet_click_voice_audio.setup(owner_node, player_factory)
	lingpet_combat_audio.setup_item_players(owner_node, player_factory)
	_enable_loop(lingpet_combat_audio.get_player("star_coil_move"))
	item_reward_feedback_audio.setup_cinematic(owner_node, player_factory)
	elemental_combat_audio.setup(owner_node, player_factory)
	_enable_loop(ragnarok_shock_sfx)
	_enable_loop(electric_shock_sfx)
	item_reward_feedback_audio.setup_item_actions(owner_node, player_factory)
	transformation_item_audio.setup(owner_node, player_factory)


func _setup_projectile_item_sfx() -> void:
	projectile_item_audio.setup_pre_loop_players(owner_node, player_factory)
	_enable_loop(boomerang_sfx)
	projectile_item_audio.setup_post_loop_players(owner_node, player_factory)
	lingpet_combat_audio.setup_projectile_players(owner_node, player_factory)
	_enable_loop(spider_mine_walk_sfx)
	_enable_loop(lingpet_combat_audio.get_player("gatling_loop"))


func _setup_stage_feedback_sfx() -> void:
	smasher_skill_audio.setup_stage_feedback_players(owner_node, player_factory)
	shared_stage_feedback_audio.setup_primary(owner_node, player_factory)
	stage2_battle_audio.setup(owner_node, player_factory)
	stage3_battle_audio.setup(owner_node, player_factory, Callable(self, "_create_optional_sfx"))
	lingpet_combat_audio.setup_stage_players(owner_node, player_factory)
	stage4_ponk_audio.setup(owner_node, player_factory)
	stage5_hongryun_audio.setup_primary_players(owner_node, player_factory)
	stage6_tetriser_audio.setup(owner_node, player_factory)
	stage7_akamu_audio.setup(owner_node, player_factory)
	stage5_hongryun_audio.setup_hurt_players(owner_node, player_factory)
	shared_stage_feedback_audio.setup_tail(owner_node, player_factory)
	han_miryang_prologue_tablet_crack_sfx = _configure_sfx_player(player_factory.create(
		owner_node,
		"HanMiryangPrologueTabletCrackSfx",
		HAN_MIRYANG_PROLOGUE_TABLET_CRACK_SOUND_PATH,
		-7.0
	))
	han_miryang_prologue_tablet_crack_tail_sfx = _configure_sfx_player(player_factory.create(
		owner_node,
		"HanMiryangPrologueTabletCrackTailSfx",
		HAN_MIRYANG_PROLOGUE_TABLET_CRACK_SOUND_PATH,
		-15.0
	))
	perk_fusion_combat_audio.setup(owner_node, player_factory)
	_enable_loop(stage2_quake_sfx)
	_enable_loop(stage3_psychoball_sfx)
	_enable_loop(stage4_magnetic_sfx)
	_enable_loop(stage4_illusion_sfx)


func _setup_bgm_players() -> void:
	for bgm_name: String in stage_bgm_audio.get_bgm_ids():
		_ensure_bgm_player(str(bgm_name))
	_bgm_setup_step = BGM_SETUP_STEP_COUNT
	_restore_bgm_muted()
	_apply_audio_buses_and_volumes()


func _setup_bgm_players_step() -> bool:
	var bgm_ids: Array[String] = stage_bgm_audio.get_bgm_ids()
	if _bgm_setup_step < bgm_ids.size():
		var bgm_id := bgm_ids[_bgm_setup_step]
		if _should_setup_bgm_player(bgm_id):
			_ensure_bgm_player(bgm_id)
	elif _bgm_setup_step == bgm_ids.size():
		_restore_bgm_muted()
	else:
		return true
	_bgm_setup_step += 1
	return _bgm_setup_step >= BGM_SETUP_STEP_COUNT


func _prewarm_audio_setup_streams_step() -> bool:
	_ensure_audio_setup_stream_paths(_audio_setup_step)
	return game_audio_setup_controller.prewarm_streams_step(_audio_setup_step)


func _get_audio_setup_step_progress(step: int) -> float:
	var stream_paths: Array[String] = _get_audio_setup_stream_paths(step)
	return game_audio_setup_controller.get_audio_setup_step_progress(
		step,
		AUDIO_SETUP_STEP_COUNT,
		BGM_SETUP_STEP_COUNT,
		stream_paths.size()
	)


func _ensure_audio_setup_stream_paths(step: int) -> void:
	if not game_audio_setup_controller.needs_stream_paths(step):
		return
	game_audio_setup_controller.set_stream_paths(
		step,
		_get_audio_setup_stream_paths(step)
	)


func _get_audio_setup_stream_paths(step: int) -> Array[String]:
	match step:
		0:
			var core_paths: Array[String] = game_ui_feedback_audio.get_prewarm_stream_paths()
			core_paths.append_array(core_ball_dash_audio.get_prewarm_stream_paths())
			return core_paths
		1:
			var skill_paths: Array[String] = smasher_skill_audio.get_skill_prewarm_stream_paths()
			skill_paths.append_array(stage1_boss_skill_audio.get_prewarm_stream_paths())
			skill_paths.append_array(viper_skill_audio.get_prewarm_stream_paths())
			return skill_paths
		2:
			return commando_skill_audio.get_prewarm_stream_paths()
		3:
			var item_paths: Array[String] = item_reward_feedback_audio.get_prewarm_stream_paths()
			item_paths.append_array(lingpet_acquisition_audio.get_prewarm_stream_paths())
			item_paths.append_array(lingpet_click_voice_audio.get_prewarm_stream_paths())
			item_paths.append_array(lingpet_combat_audio.get_item_prewarm_stream_paths())
			item_paths.append_array(item_reward_feedback_audio.get_cinematic_prewarm_stream_paths())
			item_paths.append_array(elemental_combat_audio.get_prewarm_stream_paths())
			item_paths.append_array(item_reward_feedback_audio.get_item_action_prewarm_stream_paths())
			item_paths.append_array(transformation_item_audio.get_prewarm_stream_paths())
			return item_paths
		4:
			return projectile_item_audio.get_prewarm_stream_paths()
		5:
			var stage_paths: Array[String] = smasher_skill_audio.get_stage_primary_prewarm_stream_paths()
			stage_paths.append_array(shared_stage_feedback_audio.get_primary_prewarm_stream_paths())
			stage_paths.append_array(stage2_battle_audio.get_prewarm_stream_paths())
			stage_paths.append_array(stage3_battle_audio.get_prewarm_stream_paths())
			stage_paths.append_array(lingpet_combat_audio.get_stage_prewarm_stream_paths())
			stage_paths.append_array(stage4_ponk_audio.get_prewarm_stream_paths())
			stage_paths.append_array(stage5_hongryun_audio.get_primary_prewarm_stream_paths())
			stage_paths.append_array(stage7_akamu_audio.get_prewarm_stream_paths())
			stage_paths.append_array(shared_stage_feedback_audio.get_tail_prewarm_stream_paths())
			stage_paths.append_array(smasher_skill_audio.get_voice_prewarm_stream_paths())
			stage_paths.append_array(stage5_hongryun_audio.get_hurt_prewarm_stream_paths())
			stage_paths.append_array(perk_fusion_combat_audio.get_prewarm_stream_paths())
			return stage_paths
		6:
			return _get_required_bgm_stream_paths()
	return []


func _get_required_bgm_stream_paths() -> Array[String]:
	return stage_bgm_audio.get_required_stream_paths(Callable(self, "_should_setup_bgm_player"))


func _get_bgm_stream_path(bgm_name: String) -> String:
	return stage_bgm_audio.get_stream_path(bgm_name)


func _is_setup_complete() -> bool:
	var all_bgm_players_ready := false
	var required_bgm_player_ready := false
	if _bgm_setup_step >= BGM_SETUP_STEP_COUNT:
		all_bgm_players_ready = _are_all_bgm_players_ready()
		if not all_bgm_players_ready and _audio_setup_step >= AUDIO_SETUP_STEP_COUNT:
			required_bgm_player_ready = _is_required_bgm_player_ready()
	return game_audio_setup_controller.is_setup_complete(
		AUDIO_SETUP_STEP_COUNT,
		BGM_SETUP_STEP_COUNT,
		all_bgm_players_ready,
		required_bgm_player_ready
	)


func _should_setup_bgm_player(bgm_name: String) -> bool:
	var setup_stage := _get_owner_current_stage()
	if setup_stage == 1:
		return STAGE1_BGM_NAMES.has(bgm_name)
	if setup_stage == 2:
		return bgm_name == "stage2" or bgm_name == "stage2_alt"
	if setup_stage == 3:
		return bgm_name == "stage3"
	if setup_stage == 4:
		return bgm_name == "stage4" or bgm_name == "stage4_phase2"
	if setup_stage == 5:
		return bgm_name == "stage5"
	if setup_stage == 6:
		return bgm_name == "stage6"
	if setup_stage == 7:
		return bgm_name == "stage7"
	return true


func _is_required_bgm_player_ready() -> bool:
	for bgm_id: String in stage_bgm_audio.get_bgm_ids():
		if _should_setup_bgm_player(bgm_id) and not _is_owned_player_ready(_get_bgm_player(bgm_id)):
			return false
	return true


func _are_all_bgm_players_ready() -> bool:
	for bgm_id: String in stage_bgm_audio.get_bgm_ids():
		if not _is_owned_player_ready(_get_bgm_player(bgm_id)):
			return false
	return true


func _get_owner_current_stage() -> int:
	if owner_node == null:
		return 1
	var value: Variant = owner_node.get("current_stage")
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return 1


func update(delta: float) -> void:
	paddle_sound_cooldown = max(0.0, paddle_sound_cooldown - delta)
	wall_sound_cooldown = max(0.0, wall_sound_cooldown - delta)


func play_drive() -> void:
	_play_with_pitch(drive_sfx, randf_range(0.98, 1.02))
	_play_random_stream_with_pitch(mika_drive_voice_sfx, mika_drive_voice_streams, 1.0)


func play_plasma_charge() -> void:
	if plasma_charge_sfx == null or plasma_charge_sfx.stream == null:
		return
	if plasma_charge_sfx.playing:
		return
	plasma_charge_sfx.pitch_scale = 1.0
	plasma_charge_sfx.play()


func stop_plasma_charge() -> void:
	if plasma_charge_sfx != null and plasma_charge_sfx.playing:
		plasma_charge_sfx.stop()


func sync_plasma_charge(active: bool) -> void:
	if active:
		play_plasma_charge()
	else:
		stop_plasma_charge()


func play_plasma_shoot() -> void:
	_play_with_pitch(plasma_shoot_sfx, randf_range(0.98, 1.02))


func play_plasma_shock() -> void:
	if plasma_shock_sfx == null or plasma_shock_sfx.stream == null:
		return
	if plasma_shock_sfx.playing:
		return
	plasma_shock_sfx.pitch_scale = 1.0
	plasma_shock_sfx.play()


func stop_plasma_shock() -> void:
	if plasma_shock_sfx != null and plasma_shock_sfx.playing:
		plasma_shock_sfx.stop()


func sync_plasma_shock(active: bool) -> void:
	if active:
		play_plasma_shock()
	else:
		stop_plasma_shock()


func play_recovery() -> void:
	_play_with_pitch(recovery_sfx, randf_range(0.98, 1.02))


# 콜드부트 §9 전이 SFX: B1 트위스트락 CHNK / B2 부팅 램프(0.85s 원샷) /
# B3 이그니션 THUNK / B4 각성 팡파르(부산물 전개 시에만 — 호출측 게이트).
func play_cold_boot_chnk_latch() -> void:
	_play_with_pitch(cold_boot_chnk_latch_sfx, randf_range(0.97, 1.03))


func play_cold_boot_post_ramp() -> void:
	_play_with_pitch(cold_boot_post_ramp_sfx, randf_range(0.99, 1.01))


func play_cold_boot_ignition_thunk() -> void:
	_play_with_pitch(cold_boot_ignition_thunk_sfx, randf_range(0.97, 1.03))


func play_cold_boot_awaken_fanfare() -> void:
	_play_with_pitch(cold_boot_awaken_fanfare_sfx, randf_range(0.99, 1.01))


func play_defeat_jewel() -> void:
	_play_with_pitch(defeat_jewel_sfx, randf_range(0.98, 1.02))


func play_defeat_gem_shatter() -> void:
	_play_with_pitch(defeat_gem_shatter_sfx, randf_range(0.97, 1.03))


func play_cleanse() -> void:
	_play_with_pitch(cleanse_sfx, randf_range(0.98, 1.02))


func play_warp_gate_loop() -> void:
	if warp_gate_sfx == null or warp_gate_sfx.stream == null:
		return
	if warp_gate_sfx.playing:
		return
	warp_gate_sfx.pitch_scale = 1.0
	warp_gate_sfx.play()


func stop_warp_gate_loop() -> void:
	if warp_gate_sfx != null and warp_gate_sfx.playing:
		warp_gate_sfx.stop()


func sync_warp_gate_loop(active: bool) -> void:
	if active:
		play_warp_gate_loop()
	else:
		stop_warp_gate_loop()


func play_magnum_grip() -> void:
	if magnum_grip_sfx == null or magnum_grip_sfx.stream == null:
		return
	if magnum_grip_sfx.playing:
		return
	magnum_grip_sfx.pitch_scale = 1.0
	magnum_grip_sfx.play()


func stop_magnum_grip() -> void:
	if magnum_grip_sfx != null and magnum_grip_sfx.playing:
		magnum_grip_sfx.stop()


func sync_magnum_grip(active: bool) -> void:
	if active:
		play_magnum_grip()
	else:
		stop_magnum_grip()


func play_smasher_wheel_loop() -> void:
	if smasher_wheel_sfx == null or smasher_wheel_sfx.stream == null:
		return
	if smasher_wheel_sfx.playing:
		return
	smasher_wheel_sfx.pitch_scale = 1.0
	smasher_wheel_sfx.play()


func stop_smasher_wheel_loop() -> void:
	if smasher_wheel_sfx != null and smasher_wheel_sfx.playing:
		smasher_wheel_sfx.stop()


func sync_smasher_wheel_loop(active: bool) -> void:
	if active:
		play_smasher_wheel_loop()
	else:
		stop_smasher_wheel_loop()


# 풍운천선무 컷인 한미량 보이스. 발동마다 후보 2개 중 1개를 무작위로 고른다.
func play_smasher_wheel_cutin_voice() -> void:
	_play_random_stream_with_pitch(mika_smasher_wheel_voice_sfx, mika_smasher_wheel_voice_streams, 1.0)


func play_smasher_overdrive_activation() -> void:
	_play_with_pitch(smasher_overdrive_activation_sfx, randf_range(0.98, 1.02))
	_play_random_stream_with_pitch(
		mika_smasher_overdrive_voice_sfx,
		mika_smasher_overdrive_voice_streams,
		1.0
	)


func play_shield_kiting_wind_up() -> void:
	_play_with_pitch(shield_kiting_wind_up_sfx, randf_range(0.98, 1.02))


func stop_shield_kiting_wind_up() -> void:
	if shield_kiting_wind_up_sfx != null and shield_kiting_wind_up_sfx.playing:
		shield_kiting_wind_up_sfx.stop()


func is_shield_kiting_wind_up_playing() -> bool:
	return shield_kiting_wind_up_sfx != null and shield_kiting_wind_up_sfx.playing


func play_shield_kiting_launch() -> void:
	_play_with_pitch(shield_kiting_launch_sfx, randf_range(0.98, 1.02))


func play_shield_kiting_hit() -> void:
	_play_with_pitch(shield_kiting_hit_sfx, randf_range(0.98, 1.02))


func play_whip() -> void:
	_play_with_pitch(whip_sfx, randf_range(0.98, 1.02))


func play_gaksital_fan(volume: float = 0.35) -> void:
	_play_gaksital_fan_layer(volume, randf_range(0.98, 1.02))


func play_whipcrack(volume: float = 0.6) -> void:
	_set_sfx_player_linear_volume(whipcrack_sfx, volume)
	_play_with_pitch(whipcrack_sfx, randf_range(0.98, 1.02))


func stop_whip() -> void:
	if whip_sfx != null and whip_sfx.playing:
		whip_sfx.stop()


func play_viper_jetpack_loop() -> void:
	if viper_jetpack_sfx == null or viper_jetpack_sfx.stream == null:
		return
	if viper_jetpack_sfx.playing:
		return
	viper_jetpack_sfx.pitch_scale = 1.0
	viper_jetpack_sfx.play()


func stop_viper_jetpack_loop() -> void:
	if viper_jetpack_sfx != null and viper_jetpack_sfx.playing:
		viper_jetpack_sfx.stop()


func sync_viper_jetpack_loop(active: bool) -> void:
	if active:
		play_viper_jetpack_loop()
	else:
		stop_viper_jetpack_loop()


func play_thor_shield_open() -> void:
	_play_with_pitch(thor_shield_open_sfx, randf_range(0.98, 1.02))


func play_thor_shield_close() -> void:
	_play_with_pitch(thor_shield_close_sfx, randf_range(0.98, 1.02))


func play_thor_shield_swing() -> void:
	_play_with_pitch(thor_shield_swing_sfx, randf_range(0.98, 1.02))


func play_thor_shield_block() -> void:
	_play_with_pitch(thor_shield_block_sfx, randf_range(0.98, 1.02))


func play_spellbreaker_guard_parry() -> void:
	_play_with_pitch(spellbreaker_guard_parry_sfx, 1.0)


func play_viper_backstep() -> void:
	if not _play_with_pitch(viper_backstep_sfx, randf_range(0.98, 1.02)):
		play_dash_start(true)


func play_viper_shadow_kick() -> void:
	_play_with_pitch(viper_shadow_kick_sfx, randf_range(0.98, 1.02))


func play_viper_marshal_kick() -> void:
	_play_with_pitch(viper_marshal_kick_sfx, randf_range(0.98, 1.02))


func play_viper_dive_prep() -> void:
	_play_with_pitch(viper_dive_prep_sfx, randf_range(0.98, 1.02))


func play_viper_dive_strike() -> void:
	_play_with_pitch(viper_dive_strike_sfx, randf_range(0.98, 1.02))


func play_viper_ignition_aura() -> void:
	if not _play_with_pitch(viper_ignition_aura_sfx, 1.0):
		_play_with_pitch(viper_ignition_aura_fallback_sfx, 1.0)


func play_viper_phantom_show() -> void:
	_play_with_pitch(viper_phantom_show_sfx, randf_range(0.98, 1.02))


func play_viper_phantom_kick_hit() -> void:
	_play_with_pitch(viper_phantom_kick_hit_sfx, randf_range(0.98, 1.02))


func play_viper_blade() -> void:
	_play_with_pitch(viper_blade_sfx, randf_range(0.98, 1.02))


func play_viper_blade_spin() -> void:
	_play_with_pitch(viper_blade_spin_sfx, randf_range(0.98, 1.02))


func stop_viper_blade_spin() -> void:
	if viper_blade_spin_sfx != null and viper_blade_spin_sfx.playing:
		viper_blade_spin_sfx.stop()


func play_viper_venom_moving() -> void:
	_play_with_pitch(viper_venom_moving_sfx, randf_range(0.98, 1.02))


func play_viper_venom_attack() -> void:
	_play_with_pitch(viper_venom_attack_sfx, randf_range(0.98, 1.02))


func play_viper_hwarang_kick() -> void:
	if not _play_with_pitch(viper_hwarang_kick_sfx, randf_range(0.98, 1.02)):
		play_viper_marshal_kick()


func play_viper_kick_guard_knockback() -> void:
	if not _play_with_pitch(viper_kick_guard_knockback_sfx, randf_range(0.98, 1.02)):
		play_stage2_speed_defense_hit()


func play_viper_dual_glitch_windup() -> void:
	_play_with_pitch(viper_dual_glitch_windup_sfx, randf_range(0.98, 1.02))


func stop_viper_dual_glitch_windup() -> void:
	if viper_dual_glitch_windup_sfx != null:
		viper_dual_glitch_windup_sfx.stop()


func play_viper_dual_glitch_split() -> void:
	_play_with_pitch(viper_dual_glitch_split_sfx, randf_range(0.98, 1.02))


func play_chaos_spear_windup() -> void:
	_play_with_pitch(chaos_spear_windup_sfx, randf_range(0.98, 1.02))


func stop_chaos_spear_windup() -> void:
	if chaos_spear_windup_sfx != null and chaos_spear_windup_sfx.playing:
		chaos_spear_windup_sfx.stop()


func play_chaos_spear_flying() -> void:
	_play_with_pitch(chaos_spear_flying_sfx, randf_range(0.98, 1.02))


func stop_chaos_spear_flying() -> void:
	if chaos_spear_flying_sfx != null and chaos_spear_flying_sfx.playing:
		chaos_spear_flying_sfx.stop()


func play_chaos_spear_impact() -> void:
	_play_with_pitch(chaos_spear_impact_sfx, randf_range(0.98, 1.02))


func stop_chaos_spear_impact() -> void:
	if chaos_spear_impact_sfx != null and chaos_spear_impact_sfx.playing:
		chaos_spear_impact_sfx.stop()


func play_chaos_spear_blackhole_loop() -> void:
	if chaos_spear_blackhole_sfx == null or chaos_spear_blackhole_sfx.stream == null:
		return
	if chaos_spear_blackhole_sfx.playing:
		return
	chaos_spear_blackhole_sfx.pitch_scale = 1.0
	chaos_spear_blackhole_sfx.play()


func stop_chaos_spear_blackhole_loop() -> void:
	if chaos_spear_blackhole_sfx != null and chaos_spear_blackhole_sfx.playing:
		chaos_spear_blackhole_sfx.stop()


func sync_chaos_spear_blackhole_loop(active: bool) -> void:
	if active:
		play_chaos_spear_blackhole_loop()
	else:
		stop_chaos_spear_blackhole_loop()


func play_commando_supply_radio() -> void:
	if not _play_with_pitch(commando_supply_radio_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_commando_supply_radio_loop() -> void:
	if commando_supply_radio_loop_sfx == null or commando_supply_radio_loop_sfx.stream == null:
		return
	if commando_supply_radio_loop_sfx.playing:
		return
	commando_supply_radio_loop_sfx.pitch_scale = 1.0
	commando_supply_radio_loop_sfx.play()


func stop_commando_supply_radio_loop() -> void:
	if commando_supply_radio_loop_sfx != null and commando_supply_radio_loop_sfx.playing:
		commando_supply_radio_loop_sfx.stop()


func sync_commando_supply_radio_loop(active: bool) -> void:
	if active:
		play_commando_supply_radio_loop()
	else:
		stop_commando_supply_radio_loop()


func play_commando_supply_aircraft_loop() -> void:
	if commando_supply_aircraft_sfx == null or commando_supply_aircraft_sfx.stream == null:
		return
	if commando_supply_aircraft_sfx.playing:
		return
	commando_supply_aircraft_sfx.pitch_scale = 1.0
	commando_supply_aircraft_sfx.play()


func stop_commando_supply_aircraft_loop() -> void:
	if commando_supply_aircraft_sfx != null and commando_supply_aircraft_sfx.playing:
		commando_supply_aircraft_sfx.stop()


func sync_commando_supply_aircraft_loop(active: bool) -> void:
	if active:
		play_commando_supply_aircraft_loop()
	else:
		stop_commando_supply_aircraft_loop()


func play_commando_supply_drop() -> void:
	if not _play_with_pitch(item_get_sfx, randf_range(0.96, 1.03)):
		play_active_item()


func play_commando_weapon_change() -> void:
	if not _play_with_pitch(commando_weapon_change_sfx, randf_range(0.98, 1.02)):
		play_commando_supply_drop()


func play_commando_fire_support_radio() -> void:
	if not _play_with_pitch(commando_fire_support_radio_sfx, randf_range(0.98, 1.02)):
		play_commando_supply_radio()


func play_commando_fire_support_aircraft_loop() -> void:
	if commando_fire_support_aircraft_sfx == null or commando_fire_support_aircraft_sfx.stream == null:
		return
	if commando_fire_support_aircraft_sfx.playing:
		return
	commando_fire_support_aircraft_sfx.pitch_scale = 1.0
	commando_fire_support_aircraft_sfx.play()


func stop_commando_fire_support_aircraft_loop() -> void:
	if commando_fire_support_aircraft_sfx != null and commando_fire_support_aircraft_sfx.playing:
		commando_fire_support_aircraft_sfx.stop()


func sync_commando_fire_support_aircraft_loop(active: bool) -> void:
	if active:
		play_commando_fire_support_aircraft_loop()
	else:
		stop_commando_fire_support_aircraft_loop()


func play_commando_firearm_fire(weapon_id: String) -> void:
	match weapon_id:
		"pistol":
			play_commando_pistol_fire()
		"bazooka":
			play_commando_bazooka_fire()
		"fire_support":
			play_commando_fire_support_radio()
		"suicide_drone":
			play_commando_suicide_drone_launch()
		"net_gun":
			play_commando_net_gun_fire()
		"bowling_trap":
			play_commando_bowling_trap_install()
		"ak47", "commando_pistol":
			if weapon_id == "ak47":
				play_commando_ak47_fire()
			else:
				play_commando_pistol_fire()
		_:
			play_active_item()


func play_commando_firearm_impact(weapon_id: String) -> void:
	match weapon_id:
		"pistol":
			play_commando_bullet_impact()
		"bazooka":
			play_commando_bazooka_impact()
		"fire_support":
			play_commando_fire_support_bomb()
		"suicide_drone":
			play_commando_suicide_drone_explosion()
		"net_gun":
			play_commando_net_gun_capture()
		"bowling_trap":
			play_commando_bowling_trap_snap()
		"ak47", "commando_pistol":
			play_commando_bullet_impact()
		_:
			play_paddle_hit()


func play_commando_slingshot_fire() -> void:
	if not _play_with_pitch(commando_slingshot_fire_sfx, randf_range(0.96, 1.04)):
		play_throw()


func play_commando_pistol_fire() -> void:
	if not _play_with_pitch(commando_pistol_fire_sfx, randf_range(0.98, 1.02)):
		play_shrapnel_armor_fire()


func play_commando_pistol_ready() -> void:
	if not _play_with_pitch(commando_pistol_ready_sfx, randf_range(0.98, 1.02)):
		play_throw_before()


func play_commando_pistol_reload_start() -> void:
	if not _play_with_pitch(commando_pistol_reload_start_sfx, randf_range(0.98, 1.02)):
		if not _play_with_pitch(commando_pistol_reload_sfx, randf_range(0.98, 1.02)):
			play_active_item()


func play_commando_pistol_reload_round() -> void:
	if not _play_with_pitch(commando_pistol_reload_sfx, randf_range(0.98, 1.02)):
		play_commando_pistol_reload_start()


func play_commando_reload() -> void:
	if not _play_with_pitch(commando_reload_sfx, randf_range(0.98, 1.02)):
		play_commando_pistol_reload_start()


func play_commando_ak47_fire() -> void:
	if not _play_commando_ak47_fire_layer(randf_range(0.98, 1.03)):
		play_shrapnel_armor_fire()


func play_commando_bazooka_fire() -> void:
	if not _play_with_pitch(commando_bazooka_fire_sfx, randf_range(0.98, 1.02)):
		play_ragnarok_shot()


func play_commando_net_gun_fire() -> void:
	if not _play_with_pitch(throw_sfx, randf_range(0.90, 0.97)):
		play_throw()


func play_commando_bowling_trap_install() -> void:
	if not _play_with_pitch(commando_bowling_trap_install_sfx, randf_range(0.98, 1.02)):
		play_stage2_rockhit()


func play_commando_suicide_drone_launch() -> void:
	if commando_suicide_drone_sfx != null and commando_suicide_drone_sfx.stream != null:
		if not commando_suicide_drone_sfx.playing:
			commando_suicide_drone_sfx.pitch_scale = 1.0
			commando_suicide_drone_sfx.play()
		return
	if not _play_with_pitch(ragnarok_shot_sfx, randf_range(1.05, 1.12)):
		play_active_item()


func stop_commando_suicide_drone_loop() -> void:
	if commando_suicide_drone_sfx != null and commando_suicide_drone_sfx.playing:
		commando_suicide_drone_sfx.stop()


func sync_commando_suicide_drone_loop(active: bool) -> void:
	if active:
		play_commando_suicide_drone_launch()
	else:
		stop_commando_suicide_drone_loop()


func play_commando_bullet_impact() -> void:
	play_shrapnel_armor_hit()


func play_commando_slingshot_impact() -> void:
	play_stage2_rockhit()


func play_commando_bazooka_impact() -> void:
	play_grenade_explosion()


func play_commando_fire_support_bomb() -> void:
	play_grenade_explosion()


func play_commando_net_gun_capture() -> void:
	if not _play_with_pitch(commando_net_capture_sfx, randf_range(0.98, 1.02)):
		play_boomerang_hit()


func play_commando_net_gun_constrict() -> void:
	if not _play_with_pitch(commando_net_constrict_sfx, randf_range(0.98, 1.02)):
		play_commando_net_gun_capture()


func play_commando_bowling_trap_snap() -> void:
	if not _play_with_pitch(commando_bowling_trap_snap_sfx, randf_range(0.98, 1.02)):
		play_stage2_rockhit()


func play_commando_suicide_drone_explosion() -> void:
	stop_commando_suicide_drone_loop()
	play_grenade_explosion()


func play_item_get() -> void:
	_play_with_pitch(item_get_sfx, randf_range(0.98, 1.02))


func play_drink() -> void:
	_play_with_pitch(drink_sfx, randf_range(0.98, 1.02))


func play_active_item() -> void:
	_play_with_pitch(active_item_sfx, randf_range(0.98, 1.02))


func play_trade() -> void:
	_play_with_pitch(trade_sfx, randf_range(0.98, 1.02))


func play_brick_wall_destroy() -> void:
	if not _play_with_pitch(brick_wall_destroy_sfx, randf_range(0.94, 1.06)):
		play_wall_hit(0.0)


func play_alchemy() -> void:
	if not _play_with_pitch(alchemy_sfx, randf_range(0.98, 1.04)):
		play_active_item()


func play_pandora() -> void:
	if not _play_with_pitch(pandora_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_lucky_coin_spawn() -> void:
	if not _play_with_pitch(lucky_coin_spawn_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_foul_whistle() -> void:
	if not _play_with_pitch(foul_whistle_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_leaf_shield() -> void:
	if not _play_with_pitch(leaf_shield_sfx, randf_range(0.96, 1.04)):
		play_active_item()


func play_megingjord() -> void:
	if not _play_with_pitch(megingjord_sfx, randf_range(0.98, 1.02)):
		play_pandora()


func play_legendary_open() -> void:
	if not _play_with_pitch(legendary_open_sfx, randf_range(0.98, 1.02)):
		play_pandora()


func play_angel_blessing_roll() -> void:
	_play_with_pitch(angel_blessing_roll_sfx, 1.0)


func play_angel_blessing_absorb() -> void:
	_play_angel_blessing_absorb_layer()


func stop_angel_blessing_audio() -> void:
	if angel_blessing_roll_sfx != null and angel_blessing_roll_sfx.playing:
		angel_blessing_roll_sfx.stop()
	var players := [angel_blessing_absorb_sfx]
	players.append_array(angel_blessing_absorb_sfx_layers)
	for value: Variant in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).playing:
			(value as AudioStreamPlayer).stop()


func play_result_box_open() -> void:
	if not _play_with_pitch(result_box_open_sfx, randf_range(0.98, 1.03)):
		play_legendary_open()


func play_lingpet_acquire_cutin() -> void:
	lingpet_acquisition_audio.configure(owner_node, player_factory)
	if not _play_with_pitch(lingpet_acquisition_audio.ensure_player("cutin"), randf_range(0.98, 1.02)):
		play_item_get()


func play_lingpet_acquire_click_reaction_backing() -> void:
	lingpet_acquisition_audio.configure(owner_node, player_factory)
	_play_with_pitch(lingpet_acquisition_audio.ensure_player("click_deep_bass"), 1.0)
	_play_with_pitch(lingpet_acquisition_audio.ensure_player("click_crackle_sweep"), 1.0)


func play_lingpet_guardian_enhance_roll_loop() -> void:
	lingpet_acquisition_audio.configure(owner_node, player_factory)
	var previous_player: AudioStreamPlayer = lingpet_acquisition_audio.get_player("guardian_enhance_roll_loop")
	var player: AudioStreamPlayer = lingpet_acquisition_audio.ensure_player("guardian_enhance_roll_loop")
	if player != previous_player:
		_enable_loop(player)
	if player == null or player.stream == null or player.playing:
		return
	player.pitch_scale = 1.0
	player.play()


func stop_lingpet_guardian_enhance_roll_loop() -> void:
	var player: AudioStreamPlayer = lingpet_acquisition_audio.get_player("guardian_enhance_roll_loop")
	if player != null and player.playing:
		player.stop()


func play_lingpet_guardian_enhance_stamp() -> void:
	lingpet_acquisition_audio.configure(owner_node, player_factory)
	_play_with_pitch(lingpet_acquisition_audio.ensure_player("guardian_enhance_stamp"), 1.0)


func play_lingpet_guardian_enhance_result_tail() -> void:
	lingpet_acquisition_audio.configure(owner_node, player_factory)
	_play_with_pitch(lingpet_acquisition_audio.ensure_player("guardian_enhance_result_tail"), 1.0)


func stop_lingpet_guardian_enhance_cutin_loop() -> void:
	stop_lingpet_guardian_enhance_roll_loop()


# In-battle companion click-reaction voice. Pet-agnostic at the call site; this
# method owns the per-pet sound mapping. Pets without a dedicated click voice
# play nothing (silent), so callers can always pass the current pet id.
func play_lingpet_click_reaction(pet_id: String) -> void:
	lingpet_click_voice_audio.configure(owner_node, player_factory)
	var previous_player: AudioStreamPlayer = lingpet_click_voice_audio.get_player(pet_id)
	var player: AudioStreamPlayer = lingpet_click_voice_audio.ensure_player_for_pet(pet_id)
	if player == null:
		return
	if player != previous_player:
		_configure_sfx_player(player)
	_play_with_pitch(player, randf_range(0.98, 1.02))


func play_lingpet_puppet_grab_cast() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("puppet_grab_cast"), randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_puppet_grab_pull() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("puppet_grab_pull"), randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_puppet_grab_kiss() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("puppet_grab_kiss"), randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_puppet_grab_miss() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("puppet_grab_miss"), randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_sand_prison_cast() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("sand_prison"), randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_wild_roar() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("wild_roar"), randf_range(0.96, 1.04)):
		play_active_item()


func play_lingpet_star_coil_bind() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("star_coil_bind"), randf_range(0.97, 1.03)):
		play_active_item()


func stop_lingpet_star_coil_bind() -> void:
	var player: AudioStreamPlayer = lingpet_combat_audio.get_player("star_coil_bind")
	if player != null and player.playing:
		player.stop()


func play_lingpet_star_coil_move() -> void:
	var player: AudioStreamPlayer = lingpet_combat_audio.get_player("star_coil_move")
	if player == null or player.stream == null:
		return
	if player.playing:
		return
	player.pitch_scale = 1.0
	player.play()


func stop_lingpet_star_coil_move() -> void:
	var player: AudioStreamPlayer = lingpet_combat_audio.get_player("star_coil_move")
	if player != null and player.playing:
		player.stop()


func play_lingpet_dwarf_magic_cast() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("dwarf_magic_cast"), randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_dwarf_magic_hit() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("dwarf_magic_hit"), randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_gravity_accel_cast() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("gravity_accel_cast"), randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_ring_dash() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("ring_dash"), randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_egg_hit() -> void:
	# 수호령 알이 공에 맞을 때: 뼈 부러지는 임팩트 2종 중 하나를 랜덤 재생(피치 지터)해
	# 연속 히트가 똑같이 들리지 않게 한다.
	_play_random_stream_with_pitch(
		lingpet_combat_audio.get_player("egg_hit"),
		lingpet_combat_audio.get_candidate_streams("egg_hit"),
		randf_range(0.94, 1.06)
	)


func play_lingpet_doll_curse() -> void:
	if not _play_with_pitch(stage3_dollcurse_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_legendary_after() -> void:
	if not _play_with_pitch(legendary_after_sfx, randf_range(0.98, 1.02)):
		play_pandora()


func stop_legendary_after() -> void:
	if legendary_after_sfx != null and legendary_after_sfx.playing:
		legendary_after_sfx.stop()


func play_legendary_ending() -> void:
	if not _play_with_pitch(legendary_ending_sfx, randf_range(0.98, 1.02)):
		play_item_get()


func play_rainbow_fur_glove() -> void:
	if not _play_with_pitch(active_item_sfx, randf_range(1.16, 1.28)):
		play_active_item()


func play_poseidon_wave() -> void:
	if not _play_with_pitch(poseidon_wave_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_poseidon_charge() -> void:
	if not _play_with_pitch(poseidon_charge_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_ragnarok_shot() -> void:
	if not _play_with_pitch(ragnarok_shot_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_ragnarok_boom() -> void:
	if not _play_with_pitch(ragnarok_boom_sfx, randf_range(0.96, 1.03)):
		play_grenade_explosion()


func play_thunder_orb_shot() -> void:
	if not _play_with_pitch(thunder_orb_shot_sfx, 1.0):
		play_active_item()


func play_thunder_orb_boom() -> void:
	if not _play_with_pitch(thunder_orb_boom_sfx, 1.0):
		play_grenade_explosion()


func play_solar_bolt_strike() -> void:
	# Parity: original SolarBolt _sound.play() plays at fixed pitch (no modulation).
	if not _play_with_pitch(solar_bolt_strike_sfx, 1.0):
		play_ragnarok_shot()


func play_mini_spark() -> void:
	# One random spark zap (spark1/2/3) per mini-spark appearance, lightly
	# pitch-jittered so consecutive sparks in a chain do not sound identical.
	_play_random_stream_with_pitch(mini_spark_sfx, mini_spark_streams, randf_range(0.92, 1.08))


func play_ragnarok_shock_loop() -> void:
	if ragnarok_shock_sfx == null or ragnarok_shock_sfx.stream == null:
		return
	if ragnarok_shock_sfx.playing:
		return
	ragnarok_shock_sfx.pitch_scale = 1.0
	ragnarok_shock_sfx.play()


func stop_ragnarok_shock_loop() -> void:
	if ragnarok_shock_sfx != null and ragnarok_shock_sfx.playing:
		ragnarok_shock_sfx.stop()


func sync_ragnarok_shock_loop(active: bool) -> void:
	if active:
		play_ragnarok_shock_loop()
	else:
		stop_ragnarok_shock_loop()


func play_electric_shock_loop() -> void:
	if electric_shock_sfx == null or electric_shock_sfx.stream == null:
		return
	if electric_shock_sfx.playing:
		return
	electric_shock_sfx.pitch_scale = 1.0
	electric_shock_sfx.play()


func stop_electric_shock_loop() -> void:
	if electric_shock_sfx != null and electric_shock_sfx.playing:
		electric_shock_sfx.stop()


func sync_electric_shock_loop(active: bool) -> void:
	if active:
		play_electric_shock_loop()
	else:
		stop_electric_shock_loop()


func play_timewatch() -> void:
	_play_with_pitch(timewatch_sfx, randf_range(0.98, 1.02))


func play_throw_before() -> void:
	_play_with_pitch(throw_before_sfx, randf_range(0.98, 1.02))


func play_throw() -> void:
	_play_with_pitch(throw_sfx, randf_range(0.98, 1.02))


# 오딘의 눈 5종 원샷 큐 — 루프 SFX 금지 계약(모달 loop-audio 트랩 자체 회피).
# 변신·사망 큐는 타임라인 원샷(재생 시점=시퀀스 시작)이라 피치 랜덤 없이 1.0.
func play_odins_eye_change() -> void:
	_play_with_pitch(odins_eye_change_sfx, 1.0)


func play_odins_eye_death() -> void:
	_play_with_pitch(odins_eye_death_sfx, 1.0)


func play_odins_eye_spirit() -> void:
	_play_with_pitch(odins_eye_spirit_sfx, randf_range(0.98, 1.02))


func play_odins_eye_attack() -> void:
	_play_with_pitch(odins_eye_attack_sfx, randf_range(0.98, 1.02))


func play_odins_eye_shadow() -> void:
	_play_with_pitch(odins_eye_shadow_sfx, randf_range(0.98, 1.02))


func play_horn_strawberry_change() -> void:
	if not _play_with_pitch(horn_strawberry_change_sfx, 1.0):
		play_megingjord()


func play_horn_strawberry_eat() -> void:
	if not _play_with_pitch(horn_strawberry_eat_sfx, 1.0):
		play_drink()


func stop_horn_strawberry_eat() -> void:
	if horn_strawberry_eat_sfx != null and horn_strawberry_eat_sfx.playing:
		horn_strawberry_eat_sfx.stop()


func play_horn_strawberry_stem_fire() -> void:
	if not _play_with_pitch(horn_strawberry_stem_fire_sfx, 1.0):
		play_shrapnel_armor_fire()


func play_horn_strawberry_stem_hit() -> void:
	if not _play_with_pitch(horn_strawberry_stem_hit_sfx, 1.0):
		play_shrapnel_armor_hit()


func play_horn_strawberry_field() -> void:
	if not _play_with_pitch(horn_strawberry_field_build_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_field_break() -> void:
	if not _play_with_pitch(horn_strawberry_field_break_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_field_build_break() -> void:
	if not _play_with_pitch(horn_strawberry_field_build_break_sfx, 1.0):
		play_active_item()


func play_horn_charge() -> void:
	if not _play_with_pitch(horn_strawberry_horn_charge_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_horn_charge() -> void:
	if not _play_with_pitch(horn_strawberry_horn_charge_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_horn_impact() -> void:
	pass


func play_horn_strawberry_bomb_throw() -> void:
	if not _play_with_pitch(horn_strawberry_bomb_trigger_sfx, 1.0):
		play_horn_strawberry_stem_hit()


func play_horn_strawberry_bomb_explosion() -> void:
	pass


func play_grenade_explosion() -> void:
	_play_with_pitch(grenade_sfx, randf_range(0.98, 1.02))


func play_dynamite_fuse() -> AudioStreamPlayer:
	if owner_node == null:
		return null
	var player: AudioStreamPlayer = player_factory.create(owner_node, "DynamiteFuseSfx", DYNAMITE_FUSE_SOUND_PATH, -4.0)
	if player == null or player.stream == null:
		if player != null:
			player.queue_free()
		return null
	_configure_sfx_player(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.pitch_scale = randf_range(0.98, 1.02)
	player.play()
	return player


func stop_dynamite_fuse(player: Variant) -> void:
	if typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
		return
	if not (player is AudioStreamPlayer):
		return
	var fuse_player: AudioStreamPlayer = player
	if fuse_player.playing:
		fuse_player.stop()
	if fuse_player.is_inside_tree():
		fuse_player.queue_free()


func play_dynamite_explosion() -> void:
	_play_with_pitch(grenade_sfx, randf_range(0.88, 0.96))


func play_molotov_explosion() -> void:
	_play_with_pitch(firebomb_sfx, randf_range(0.95, 1.04))


func play_dragon_breath_fire(_low_volume: bool = false) -> void:
	_play_with_pitch(firebomb_sfx, randf_range(0.92, 1.08))


# Short, higher-pitched fire "deflect" tick for when the breath strikes the ball
# (distinct from the heavier fire whoosh above) so the hit is audibly felt.
func play_dragon_breath_ball_hit() -> void:
	_play_with_pitch(firebomb_sfx, randf_range(1.20, 1.38))


func play_flashbomb() -> void:
	_play_with_pitch(flashbomb_sfx, randf_range(0.98, 1.02))


func play_smokebomb() -> void:
	if not _play_with_pitch(smokebomb_sfx, randf_range(0.96, 1.04)):
		play_active_item()


func play_boomerang_loop() -> void:
	if boomerang_sfx == null or boomerang_sfx.stream == null:
		return
	if boomerang_sfx.playing:
		return
	boomerang_sfx.pitch_scale = 1.0
	boomerang_sfx.play()


func stop_boomerang_loop() -> void:
	if boomerang_sfx != null and boomerang_sfx.playing:
		boomerang_sfx.stop()


func play_boomerang_hit() -> void:
	_play_with_pitch(boomerang_hit_sfx, randf_range(0.98, 1.02))


func play_boomerang_break() -> void:
	_play_with_pitch(boomerang_break_sfx, 1.0)


func play_shrapnel_armor_fire() -> void:
	if not _play_with_pitch(shrapnel_armor_fire_sfx, randf_range(0.96, 1.04)):
		play_throw()


func play_shrapnel_armor_hit() -> void:
	if not _play_with_pitch(shrapnel_armor_hit_sfx, randf_range(0.96, 1.05)):
		play_boomerang_hit()


func play_banana_throw() -> void:
	_play_with_pitch(banana_throw_sfx, randf_range(0.94, 1.02))


func play_banana_slip() -> void:
	_play_with_pitch(banana_slip_sfx, randf_range(0.92, 1.06))


func play_soap_throw() -> void:
	_play_with_pitch(soap_throw_sfx, randf_range(0.94, 1.02))


func play_soap_land() -> void:
	_play_with_pitch(soap_land_sfx, randf_range(0.96, 1.04))


func play_soap_slip() -> void:
	_play_with_pitch(soap_slip_sfx, randf_range(0.92, 1.06))


func play_spider_mine_walk_loop() -> void:
	if spider_mine_walk_sfx == null or spider_mine_walk_sfx.stream == null:
		return
	if spider_mine_walk_sfx.playing:
		return
	spider_mine_walk_sfx.pitch_scale = 1.0
	spider_mine_walk_sfx.play()


func stop_spider_mine_walk_loop() -> void:
	if spider_mine_walk_sfx != null and spider_mine_walk_sfx.playing:
		spider_mine_walk_sfx.stop()


func sync_spider_mine_walk_loop(active: bool) -> void:
	if active:
		play_spider_mine_walk_loop()
	else:
		stop_spider_mine_walk_loop()


func play_spider_mine_setup() -> void:
	_play_with_pitch(spider_mine_setup_sfx, randf_range(0.98, 1.02))


func play_bomb_surprise_attach() -> void:
	_play_with_pitch(bomb_surprise_attach_sfx, 1.0)


func play_bomb_surprise_transfer() -> void:
	_play_with_pitch(bomb_surprise_transfer_sfx, 1.0)


func play_bomb_surprise_tick(use_second_tick: bool, fuse_ratio: float) -> void:
	var player := bomb_surprise_tick2_sfx if use_second_tick else bomb_surprise_tick1_sfx
	var volume_linear := minf(0.4, 0.1 + 0.2 * clampf(fuse_ratio, 0.0, 1.0))
	_set_sfx_player_linear_volume(player, volume_linear)
	_play_with_pitch(player, 1.0)


func play_bomb_surprise_urgent_tick() -> void:
	if bomb_surprise_urgent_tick_sfx == null or bomb_surprise_urgent_tick_sfx.stream == null:
		return
	if bomb_surprise_urgent_tick_sfx.playing:
		return
	bomb_surprise_urgent_tick_sfx.volume_db = BOMB_SURPRISE_URGENT_TICK_GAIN_DB
	bomb_surprise_urgent_tick_sfx.pitch_scale = 1.0
	bomb_surprise_urgent_tick_sfx.play()


func stop_bomb_surprise_urgent_tick() -> void:
	if bomb_surprise_urgent_tick_sfx != null and bomb_surprise_urgent_tick_sfx.playing:
		bomb_surprise_urgent_tick_sfx.stop()


func play_bomb_surprise_explosion(self_explosion: bool) -> void:
	stop_bomb_surprise_urgent_tick()
	var player := bomb_surprise_self_explosion_sfx if self_explosion else bomb_surprise_explosion_sfx
	if not _play_with_pitch(player, 1.0):
		if self_explosion:
			_play_with_pitch(stage3_curse_explode_sfx, 1.0)
		else:
			_play_with_pitch(grenade_sfx, 1.0)


func play_lingpet_gatling_transform() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("gatling_transform"), 1.0):
		play_active_item()


func play_lingpet_gatling_fire() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("gatling_fire"), randf_range(0.98, 1.02))


func play_lingpet_gatling_hit() -> void:
	if not _play_with_pitch(lingpet_combat_audio.get_player("gatling_hit"), randf_range(0.98, 1.02)):
		play_paddle_hit()


func play_lingpet_gatling_loop() -> void:
	var player: AudioStreamPlayer = lingpet_combat_audio.get_player("gatling_loop")
	if player == null or player.stream == null:
		return
	if player.playing:
		return
	player.pitch_scale = 1.0
	player.play()


func stop_lingpet_gatling_loop() -> void:
	var player: AudioStreamPlayer = lingpet_combat_audio.get_player("gatling_loop")
	if player != null and player.playing:
		player.stop()


func sync_lingpet_gatling_loop(active: bool) -> void:
	if active:
		play_lingpet_gatling_loop()
	else:
		stop_lingpet_gatling_loop()


func play_full_skill_cutin() -> void:
	_play_with_pitch(power_smash_sfx, randf_range(0.98, 1.02))


func play_power_smash() -> void:
	# Compatibility facade for older callers and replay presentation.
	play_full_skill_cutin()


func play_power_smashing_cutin_voice() -> void:
	_play_random_stream_with_pitch(mika_power_smashing_voice_sfx, mika_power_smashing_voice_streams, 1.0)


func play_ghost_smashing_cutin_voice() -> void:
	_play_random_stream_with_pitch(mika_ghost_smashing_voice_sfx, mika_ghost_smashing_voice_streams, 1.0)


func play_power_smash_launch() -> void:
	_play_with_pitch(power_smash_launch_sfx, randf_range(0.98, 1.02))


func _core_match_feedback_randf_range(minimum: float, maximum: float) -> float:
	if not _core_match_feedback_rng_ready:
		_core_match_feedback_rng.randomize()
		_core_match_feedback_rng_ready = true
	return _core_match_feedback_rng.randf_range(minimum, maximum)


func play_paddle_hit(source_x: float = PLAYFIELD_CENTER_X) -> void:
	if paddle_sound_cooldown > 0.0:
		return
	_ensure_hit_pan_buses()
	if _play_with_pitch_at(paddle_hit_sfx, _core_match_feedback_randf_range(0.98, 1.02), source_x, paddle_hit_panner):
		paddle_sound_cooldown = PADDLE_HIT_SOUND_COOLDOWN


func play_paddle_hit_profile(
	source_x: float,
	ball_speed: float,
	contact_ratio: float,
	is_player: bool,
	drive_activated: bool = false,
	rally_tier: int = 0
) -> void:
	if paddle_sound_cooldown > 0.0:
		return
	var profile: Dictionary = PaddleHitAudioLayers.build_profile(
		ball_speed,
		contact_ratio,
		is_player,
		not drive_activated,
		rally_tier
	)
	_ensure_hit_pan_buses()
	paddle_hit_audio_layers.stop_layers()
	var pitch: float = float(profile.get("base_pitch", 1.0))
	pitch *= _core_match_feedback_randf_range(0.985, 1.015)
	if _play_with_pitch_at(paddle_hit_sfx, pitch, source_x, paddle_hit_panner):
		paddle_hit_audio_layers.play_layers(profile)
		paddle_sound_cooldown = PADDLE_HIT_SOUND_COOLDOWN


func play_training_strike_hit(source_x: float = PLAYFIELD_CENTER_X) -> void:
	# Training owns the modal presentation lane rather than the combat
	# cooldown. Reuse the production paddle-impact player and presentation RNG,
	# while keeping an explicit stop boundary for GRT-058 modal cancellation.
	_ensure_hit_pan_buses()
	_play_with_pitch_at(
		paddle_hit_sfx,
		_core_match_feedback_randf_range(0.98, 1.02),
		source_x,
		paddle_hit_panner
	)


func stop_training_strike_audio() -> void:
	if paddle_hit_sfx != null and paddle_hit_sfx.playing:
		paddle_hit_sfx.stop()


func play_rally_tier_accent(tier: int, source_x: float = PLAYFIELD_CENTER_X) -> void:
	var clamped_tier: int = clampi(tier, 1, 5)
	var pitch: float = 1.08 + float(clamped_tier) * 0.035
	_ensure_hit_pan_buses()
	_play_with_pitch_at(wall_hit_sfx, pitch, source_x, wall_hit_panner)


func play_serve(ball_visual_type: String = "") -> void:
	var player: AudioStreamPlayer = serve_sfx
	if ball_visual_type == "pingpong" and pingpong_serve_sfx != null and pingpong_serve_sfx.stream != null:
		player = pingpong_serve_sfx
	_play_with_pitch(player, _core_match_feedback_randf_range(0.98, 1.02))


func play_dash_start(is_half: bool) -> void:
	var player: AudioStreamPlayer = half_dash_sfx if is_half else dash_sfx
	_play_with_pitch(player, _core_match_feedback_randf_range(0.98, 1.02))


func play_burst_up_dash() -> void:
	if not _play_with_pitch(bust_up_dash_sfx, randf_range(0.98, 1.03)):
		play_dash_start(false)


func play_dash_charge() -> void:
	_play_with_pitch(dash_charge_sfx, randf_range(0.98, 1.04))


func play_boost_charging() -> void:
	if not _play_with_pitch(boost_charging_sfx, randf_range(0.98, 1.04)):
		play_dash_charge()


func play_soul_burst_dash() -> void:
	if not _play_with_pitch(soul_burst_dash_sfx, randf_range(0.98, 1.03)):
		play_dash_start(false)


func play_dash_spirit_delete() -> void:
	_play_with_pitch(dash_spirit_delete_sfx, randf_range(0.98, 1.02))


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


func play_wall_hit(impact_speed: float = 0.0, source_x: float = PLAYFIELD_CENTER_X) -> void:
	if wall_sound_cooldown > 0.0:
		return
	var pitch: float = clamp(0.94 + impact_speed / 90.0, 0.94, 1.22) * _core_match_feedback_randf_range(0.98, 1.02)
	_ensure_hit_pan_buses()
	if _play_with_pitch_at(wall_hit_sfx, pitch, source_x, wall_hit_panner):
		wall_sound_cooldown = WALL_HIT_SOUND_COOLDOWN


func play_trampoline_bounce(impact_speed: float = 0.0) -> void:
	# Faster incoming ball -> slightly brighter boing, with light per-hit jitter.
	var pitch: float = clamp(0.94 + impact_speed / 90.0, 0.94, 1.14) * randf_range(0.97, 1.03)
	if _play_with_pitch(trampoline_bounce_sfx, pitch):
		return
	# Fallback (asset missing): the original pitched wall-hit springboard cue.
	_ensure_hit_pan_buses()
	var fallback_pitch: float = clamp(1.20 + impact_speed / 60.0, 1.20, 1.48) * randf_range(0.97, 1.03)
	if not _play_with_pitch_at(wall_hit_sfx, fallback_pitch, PLAYFIELD_CENTER_X, wall_hit_panner):
		play_wall_hit(impact_speed)


func play_trampoline_catch() -> void:
	_ensure_hit_pan_buses()
	_play_with_pitch_at(wall_hit_sfx, 0.68 * randf_range(0.96, 1.04), PLAYFIELD_CENTER_X, wall_hit_panner)


func play_round_set() -> void:
	_play_exclusive_round_result_sfx(round_set_sfx)


func play_round_victory() -> void:
	_play_exclusive_round_result_sfx(round_defeat_sfx)


func play_round_defeat() -> void:
	_play_exclusive_round_result_sfx(round_defeat_sfx)


func play_stage_clear_gong() -> void:
	if stage_clear_gong_sfx != null:
		stage_clear_gong_sfx.pitch_scale = 1.0
	_play_exclusive_round_result_sfx(stage_clear_gong_sfx)


func _play_exclusive_round_result_sfx(target: AudioStreamPlayer) -> void:
	if target == null or target.stream == null:
		return
	for player: AudioStreamPlayer in [round_set_sfx, round_defeat_sfx, stage_clear_gong_sfx]:
		if player != null and player.playing:
			player.stop()
	target.play()


func play_ball_spawn_intro() -> void:
	if ball_spawn_intro_sfx == null or ball_spawn_intro_sfx.stream == null:
		return
	if ball_spawn_intro_sfx.playing:
		ball_spawn_intro_sfx.stop()
	ball_spawn_intro_sfx.pitch_scale = 1.0
	ball_spawn_intro_sfx.play()


func stop_ball_spawn_intro() -> void:
	if ball_spawn_intro_sfx != null and ball_spawn_intro_sfx.playing:
		ball_spawn_intro_sfx.stop()


func play_stage_landing_zoom_intro() -> void:
	if stage_landing_zoom_intro_sfx == null or stage_landing_zoom_intro_sfx.stream == null:
		return
	if stage_landing_zoom_intro_sfx.playing:
		stage_landing_zoom_intro_sfx.stop()
	stage_landing_zoom_intro_sfx.pitch_scale = 1.0
	stage_landing_zoom_intro_sfx.play()


func play_stage1_balloon_pop() -> void:
	_play_with_pitch(balloon_pop_sfx, randf_range(0.98, 1.04))


func play_void_phantom_cast() -> void:
	play_active_item()
	_play_random_stream_with_pitch(
		mika_void_phantom_voice_sfx,
		mika_void_phantom_voice_streams,
		1.0
	)


# 허공환영 60프레임 기 모으기 라이저(one-shot ~1.6s). 컷인 동결 동안은 볼-패스가
# 정지라 차징 틱이 돌지 않으므로, 시전(cast)이 아니라 실제 차징 첫 틱에서 부른다.
func play_void_phantom_charge() -> void:
	if void_phantom_charge_sfx == null or void_phantom_charge_sfx.stream == null:
		return
	if void_phantom_charge_sfx.playing:
		void_phantom_charge_sfx.stop()
	void_phantom_charge_sfx.pitch_scale = 1.0
	void_phantom_charge_sfx.play()


func stop_void_phantom_charge() -> void:
	if void_phantom_charge_sfx != null and void_phantom_charge_sfx.playing:
		void_phantom_charge_sfx.stop()


# 차지 60프레임 완료 → 실공+환영 동시 발사 순간의 에너지 블라스트(one-shot).
func play_void_phantom_launch() -> void:
	if void_phantom_launch_sfx == null or void_phantom_launch_sfx.stream == null:
		return
	if void_phantom_launch_sfx.playing:
		void_phantom_launch_sfx.stop()
	void_phantom_launch_sfx.pitch_scale = 1.0
	void_phantom_launch_sfx.play()


func play_void_phantom_pop() -> void:
	play_stage1_balloon_pop()


func play_stage1_balloon_door() -> void:
	_play_with_pitch(stage1_balloon_door_sfx, randf_range(0.98, 1.02))


func play_stage1_balloon_machine() -> void:
	_play_with_pitch(stage1_balloon_machine_sfx, randf_range(0.98, 1.02))


# 한미량 서막은 기존 SFX 플레이어를 전용 타이밍으로 재사용한다. 재생
# 타임라인은 presentation이 소유하고, 버스/사용자 볼륨 보존은 GameAudio가
# 계속 소유한다. 고정 피치는 동일 장면의 반복 감상에서도 큐를 흔들지 않는다.
func play_han_miryang_prologue_opening_drum() -> void:
	_play_with_pitch(stage_clear_gong_sfx, 0.72)


func play_han_miryang_prologue_rays() -> void:
	_play_with_pitch(odins_eye_spirit_sfx, 0.90)


func play_han_miryang_prologue_spirit_bell() -> void:
	_play_with_pitch(stage2_speed_defense_block_sfx, 1.0)


func play_han_miryang_prologue_tablet_crack() -> void:
	_play_with_pitch(han_miryang_prologue_tablet_crack_sfx, HAN_MIRYANG_PROLOGUE_TABLET_CRACK_PITCH)


func play_han_miryang_prologue_tablet_crack_tail() -> void:
	_play_with_pitch(han_miryang_prologue_tablet_crack_tail_sfx, HAN_MIRYANG_PROLOGUE_TABLET_CRACK_TAIL_PITCH)


func stop_han_miryang_prologue_cues() -> void:
	for player: AudioStreamPlayer in [stage_clear_gong_sfx, odins_eye_spirit_sfx, stage2_speed_defense_block_sfx, han_miryang_prologue_tablet_crack_sfx, han_miryang_prologue_tablet_crack_tail_sfx]:
		if player == null:
			continue
		if player.playing:
			player.stop()
		player.pitch_scale = 1.0


func play_starpoint_collect() -> void:
	_play_with_pitch(star_collect_sfx, randf_range(0.98, 1.04))


func play_runtime_perk_choice_open() -> void:
	if not _play_with_pitch(star_collect_sfx, randf_range(1.02, 1.08)):
		play_legendary_open()


func play_stage2_hydro() -> void:
	_play_with_pitch(stage2_hydro_sfx, randf_range(0.98, 1.03))


func play_stage2_stonebreak() -> void:
	_play_with_pitch(stage2_stonebreak_sfx, randf_range(0.94, 1.06))


func play_stage2_stonebreak_for_size(size: float) -> void:
	var pitch := 1.0
	if size <= 45.0:
		pitch = 1.12
	elif size <= 65.0:
		pitch = 1.0
	else:
		pitch = 0.88
	_play_with_pitch(stage2_stonebreak_sfx, pitch + randf_range(-0.04, 0.04))


func play_stage2_rockhit() -> void:
	_play_with_pitch(stage2_rockhit_sfx, randf_range(0.94, 1.08))


func play_stage2_rock_spawn() -> void:
	_play_with_pitch(stage2_rock_spawn_sfx, randf_range(0.95, 1.04))


func play_stage2_boss_cry() -> void:
	_play_with_pitch(stage2_boss_cry_sfx, randf_range(0.96, 1.04))


func play_stage2_speed_defense_start() -> void:
	_play_with_pitch(stage2_speed_defense_start_sfx, randf_range(0.97, 1.03))


func play_stage2_speed_defense_hit() -> void:
	_play_with_pitch(stage2_speed_defense_hit_sfx, randf_range(0.97, 1.04))


func play_stage2_speed_defense_block() -> void:
	_play_with_pitch(stage2_speed_defense_block_sfx, randf_range(0.96, 1.04))


func play_stage2_molewang_tunnel_start() -> void:
	_play_with_pitch(stage2_molewang_tunnel_start_sfx, randf_range(0.96, 1.04))


func play_stage2_molewang_tunnel_spike() -> void:
	_play_with_pitch(stage2_molewang_tunnel_spike_sfx, randf_range(0.97, 1.03))


func play_stage2_molewang_tunnel_impact() -> void:
	_play_with_pitch(stage2_molewang_tunnel_impact_sfx, randf_range(0.94, 1.06))


func play_stage2_molewang_spinning_claw() -> void:
	_play_with_pitch(stage2_molewang_spinning_claw_sfx, randf_range(0.97, 1.04))


func play_stage2_friend_mole_spawn() -> void:
	_play_with_pitch(stage2_friend_mole_spawn_sfx, randf_range(0.96, 1.04))


func play_stage2_friend_mole_hit() -> void:
	_play_with_pitch(stage2_friend_mole_hit_sfx, randf_range(0.96, 1.04))


func play_stage2_quake_loop() -> void:
	if stage2_quake_sfx == null or stage2_quake_sfx.stream == null:
		return
	if stage2_quake_sfx.playing:
		return
	stage2_quake_sfx.pitch_scale = 1.0
	stage2_quake_sfx.play()


func stop_stage2_quake_loop() -> void:
	if stage2_quake_sfx != null and stage2_quake_sfx.playing:
		stage2_quake_sfx.stop()


func sync_stage2_quake_loop(active: bool) -> void:
	if active:
		play_stage2_quake_loop()
	else:
		stop_stage2_quake_loop()


func play_stage3_tail() -> void:
	_play_with_pitch(stage3_tail_sfx, randf_range(0.96, 1.04))


func play_stage3_dollcurse() -> void:
	_play_with_pitch(stage3_dollcurse_sfx, randf_range(0.97, 1.03))


func play_stage3_tears() -> void:
	_play_with_pitch(stage3_tears_sfx, randf_range(0.95, 1.06))


func play_stage3_chest_land() -> void:
	_play_with_pitch(stage3_chest_land_sfx, randf_range(0.94, 1.04))


func play_stage3_curse_explode() -> void:
	_play_with_pitch(stage3_curse_explode_sfx, randf_range(0.94, 1.06))


func play_stage3_kuromi_awake() -> void:
	_play_with_pitch(stage3_kuromi_awake_sfx, 1.0)


func play_stage3_kuromi_stonebreak() -> void:
	_play_with_pitch(stage3_kuromi_stonebreak_sfx, 1.0)


func play_stage3_kuromi_tongue() -> void:
	_play_with_pitch(stage3_kuromi_tongue_sfx, randf_range(0.97, 1.03))


func play_stage3_kuromi_swallow() -> void:
	_play_with_pitch(stage3_kuromi_swallow_sfx, randf_range(0.97, 1.03))


func play_stage3_kuromi_spit() -> void:
	_play_with_pitch(stage3_kuromi_spit_sfx, randf_range(0.97, 1.03))


func play_lingpet_ghost_summon() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("ghost_summon"), randf_range(0.97, 1.03))


func play_lingpet_ghost_summon_out() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("ghost_summon_out"), randf_range(0.97, 1.03))


# Skeleton Archer cues play at native pitch (1.0) to match the original pygame
# Sound.play(), which applies no pitch variation.
func play_lingpet_skeleton_archer_summon() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("skeleton_archer_summon"), 1.0)


func play_lingpet_skeleton_archer_death() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("skeleton_archer_death"), 1.0)


func play_lingpet_skeleton_archer_arrow_fire() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("skeleton_archer_arrow_fire"), 1.0)


func play_lingpet_skeleton_archer_arrow_hit() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("skeleton_archer_arrow_hit"), 1.0)


func play_lingpet_bone_barrier_build() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("bone_barrier_build"), 1.0)


func play_lingpet_bone_barrier_break() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("bone_barrier_break"), 1.0)


func play_lingpet_bone_barrier_build_break() -> void:
	_play_with_pitch(lingpet_combat_audio.get_player("bone_barrier_build_break"), 1.0)


func play_stage3_psychoball_loop() -> void:
	if stage3_psychoball_sfx == null or stage3_psychoball_sfx.stream == null:
		return
	if stage3_psychoball_sfx.playing:
		return
	stage3_psychoball_sfx.pitch_scale = 1.0
	stage3_psychoball_sfx.play()


func stop_stage3_psychoball_loop() -> void:
	if stage3_psychoball_sfx != null and stage3_psychoball_sfx.playing:
		stage3_psychoball_sfx.stop()


func sync_stage3_psychoball_loop(active: bool) -> void:
	if active:
		play_stage3_psychoball_loop()
	else:
		stop_stage3_psychoball_loop()


func play_stage4_moon_shoot() -> void:
	_play_with_pitch(stage4_moon_shoot_sfx, randf_range(0.97, 1.03))


func play_stage4_fragment_shoot() -> void:
	_play_with_pitch(stage4_fragment_shoot_sfx, randf_range(0.96, 1.04))


func play_stage4_temple_hit() -> void:
	_play_with_pitch(stage4_temple_hit_sfx, randf_range(0.94, 1.05))


func play_stage4_birdkill() -> void:
	_play_with_pitch(stage4_birdkill_sfx, randf_range(0.96, 1.04))


func play_stage4_meditation() -> void:
	_play_with_pitch(stage4_meditation_sfx, 1.0)


func play_stage4_meditation_after() -> void:
	_play_with_pitch(stage4_meditation_after_sfx, 1.0)


func play_stage4_magnetic_loop() -> void:
	if stage4_magnetic_sfx == null or stage4_magnetic_sfx.stream == null:
		return
	if stage4_magnetic_sfx.playing:
		return
	stage4_magnetic_sfx.pitch_scale = 1.0
	stage4_magnetic_sfx.play()


func stop_stage4_magnetic_loop() -> void:
	if stage4_magnetic_sfx != null and stage4_magnetic_sfx.playing:
		stage4_magnetic_sfx.stop()


func sync_stage4_magnetic_loop(active: bool) -> void:
	if active:
		play_stage4_magnetic_loop()
	else:
		stop_stage4_magnetic_loop()


# 몽환포영(illusion_ripple) 최면 앰비언스 루프 — 마그네틱 루프 1:1 미러
# (WIP 파괴 후 재배선). 게이트는 illusion_active(별도 release 페이즈 없음).
func play_stage4_illusion_loop() -> void:
	if stage4_illusion_sfx == null or stage4_illusion_sfx.stream == null:
		return
	if stage4_illusion_sfx.playing:
		return
	stage4_illusion_sfx.pitch_scale = 1.0
	stage4_illusion_sfx.play()


func stop_stage4_illusion_loop() -> void:
	if stage4_illusion_sfx != null and stage4_illusion_sfx.playing:
		stage4_illusion_sfx.stop()


func sync_stage4_illusion_loop(active: bool) -> void:
	if active:
		play_stage4_illusion_loop()
	else:
		stop_stage4_illusion_loop()


func play_stage5_hongryun_fireball() -> void:
	_play_with_pitch(stage5_hongryun_fireball_sfx, randf_range(0.96, 1.04))


func stop_stage5_hongryun_fireball() -> void:
	if stage5_hongryun_fireball_sfx != null and stage5_hongryun_fireball_sfx.playing:
		stage5_hongryun_fireball_sfx.stop()


func play_stage5_hongryun_charge() -> void:
	_play_with_pitch(stage5_hongryun_charge_sfx, randf_range(0.97, 1.03))


func stop_stage5_hongryun_charge() -> void:
	if stage5_hongryun_charge_sfx != null and stage5_hongryun_charge_sfx.playing:
		stage5_hongryun_charge_sfx.stop()


func play_stage5_hongryun_shoot() -> void:
	_play_with_pitch(stage5_hongryun_shoot_sfx, randf_range(0.96, 1.04))


func stop_stage5_hongryun_shoot() -> void:
	if stage5_hongryun_shoot_sfx != null and stage5_hongryun_shoot_sfx.playing:
		stage5_hongryun_shoot_sfx.stop()


func play_stage6_tetriser_break() -> void:
	_play_with_pitch(stage6_tetriser_break_sfx, randf_range(0.94, 1.06))


func play_stage6_tetriser_wall() -> void:
	_play_with_pitch(stage6_tetriser_wall_sfx, randf_range(0.97, 1.03))


func play_stage6_tetriser_super() -> void:
	_play_with_pitch(stage6_tetriser_super_sfx, 1.0)


func play_stage6_tetriser_big() -> void:
	_play_with_pitch(stage6_tetriser_big_sfx, randf_range(0.96, 1.04))


func play_stage6_tetriser_shield() -> void:
	_play_with_pitch(stage6_tetriser_shield_sfx, randf_range(0.97, 1.03))


func play_stage6_tetriser_laser() -> void:
	_play_with_pitch(stage6_tetriser_laser_sfx, 1.0)


func play_stage7_akamu_shuriken_shoot() -> void:
	_play_with_pitch(stage7_akamu_shuriken_shoot_sfx, randf_range(0.97, 1.03))


func play_stage7_akamu_shuriken_hit() -> void:
	_play_with_pitch(stage7_akamu_shuriken_hit_sfx, randf_range(0.96, 1.04))


func play_stage7_akamu_cloud() -> void:
	_play_with_pitch(stage7_akamu_cloud_sfx, 1.0)


func play_stage7_akamu_wind_aura_block() -> void:
	_play_with_pitch(stage7_akamu_aura_block_sfx, randf_range(0.97, 1.03))


func play_stage7_akamu_clone_spawn() -> void:
	_play_with_pitch(stage7_akamu_clone_spawn_sfx, 1.0)


func play_stage7_akamu_clone_out() -> void:
	_play_with_pitch(stage7_akamu_clone_out_sfx, randf_range(0.96, 1.04))


func play_stage5_hongryun_hurt() -> void:
	var valid_players: Array[AudioStreamPlayer] = []
	for value in stage5_hongryun_hurt_sfx:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return
	_play_with_pitch(valid_players[randi() % valid_players.size()], randf_range(0.96, 1.04))


func play_stage4_phase2_bgm() -> bool:
	return stage_bgm_playback_controller.play_stage4_phase2_bgm(
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func play_stage_bgm(stage: int) -> bool:
	return stage_bgm_playback_controller.play_stage_bgm(
		stage,
		stage_bgm_audio,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func prime_stage_bgm(stage: int) -> bool:
	return stage_bgm_playback_controller.prime_stage_bgm(
		stage,
		stage_bgm_audio,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func prime_bgm(bgm_name: String) -> bool:
	return stage_bgm_playback_controller.prime_bgm(
		bgm_name,
		Callable(self, "_ensure_bgm_player")
	)


func play_bgm(bgm_name: String) -> bool:
	return stage_bgm_playback_controller.play_bgm(
		bgm_name,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func stop_bgm() -> void:
	stage_bgm_playback_controller.stop_bgm(Callable(self, "_get_bgm_player"))
	clear_story_cinematic_bgm_gain()
	set_character_info_bgm_muffled(false)


func toggle_bgm() -> bool:
	return stage_bgm_playback_controller.toggle_bgm(
		owner_node,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func set_bgm_muted(muted: bool) -> bool:
	return stage_bgm_playback_controller.set_bgm_muted(
		muted,
		owner_node,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func is_bgm_muted() -> bool:
	return stage_bgm_playback_controller.is_bgm_muted()


func _restore_bgm_muted() -> void:
	stage_bgm_playback_controller.restore_bgm_muted(owner_node)


func _get_owner_tree() -> SceneTree:
	return stage_bgm_playback_controller.get_owner_tree(owner_node)


func get_current_bgm_name() -> String:
	return stage_bgm_playback_controller.get_current_bgm_name()


func get_bgm_volume() -> float:
	return game_audio_bus_controller.get_bgm_volume()


func set_bgm_volume(value: float) -> float:
	return game_audio_bus_controller.set_bgm_volume(value)


func set_story_cinematic_bgm_gain_db(value: float) -> float:
	return game_audio_bus_controller.set_story_cinematic_bgm_gain_db(value)


func clear_story_cinematic_bgm_gain() -> void:
	game_audio_bus_controller.clear_story_cinematic_bgm_gain()


func get_story_cinematic_bgm_gain_db() -> float:
	return game_audio_bus_controller.get_story_cinematic_bgm_gain_db()


func set_character_info_bgm_muffled(active: bool) -> void:
	game_audio_bus_controller.set_character_info_bgm_muffled(active)


func is_character_info_bgm_muffled() -> bool:
	return game_audio_bus_controller.is_character_info_bgm_muffled()


func get_sfx_volume() -> float:
	return game_audio_bus_controller.get_sfx_volume()


func set_sfx_volume(value: float) -> float:
	return game_audio_bus_controller.set_sfx_volume(value)


func play_ui_move() -> void:
	_play_with_pitch(ui_move_sfx, randf_range(0.96, 1.05))


func play_ui_confirm() -> void:
	_play_with_pitch(ui_confirm_sfx, 1.0)


func play_victory_highlight_transition() -> void:
	# Replay-only semantic cue. Do not re-fire captured paddle/wall sounds.
	_play_with_pitch(ui_move_sfx, 1.08)


func play_victory_highlight_impact() -> void:
	# A single presentation impact at the stored goal marker, independent of
	# the original live score-event audio.
	_play_with_pitch(power_smash_sfx, 1.0)


func play_ui_back() -> void:
	_play_with_pitch(ui_back_sfx, 1.0)


func play_character_info_toggle() -> void:
	_play_with_pitch(character_info_toggle_sfx, 1.0)


func play_runtime_perk_select() -> void:
	# 퍽 확정 순간의 확인음. 살짝의 피치 지터로 연속 픽이 기계적으로 들리지 않게 한다.
	if not _play_with_pitch(ui_perk_select_sfx, randf_range(0.98, 1.03)):
		play_ui_confirm()


func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
	if player == null or player.stream == null:
		return false
	player.pitch_scale = pitch
	if player.playing:
		player.stop()
	player.play()
	return true


func _play_with_pitch_at(player: AudioStreamPlayer, pitch: float, source_x: float, panner: AudioEffectPanner) -> bool:
	if player == null or player.stream == null:
		return false
	if panner != null:
		panner.set_pan(_get_hit_pan_from_source_x(source_x))
	player.pitch_scale = pitch
	if player.playing:
		player.stop()
	player.play()
	return true


func _get_hit_pan_from_source_x(source_x: float) -> float:
	return game_audio_bus_controller.get_hit_pan_from_source_x(source_x)


func _play_random_stream_with_pitch(player: AudioStreamPlayer, streams: Array[AudioStream], pitch: float) -> bool:
	if player == null:
		return false
	var valid_streams: Array[AudioStream] = []
	for stream in streams:
		if stream != null:
			valid_streams.append(stream)
	if valid_streams.is_empty():
		return _play_with_pitch(player, pitch)
	player.stream = valid_streams[randi() % valid_streams.size()]
	return _play_with_pitch(player, pitch)


func _set_sfx_player_linear_volume(player: AudioStreamPlayer, volume: float) -> void:
	if player != null:
		player.volume_db = _volume_to_db(volume)


func _play_gaksital_fan_layer(volume: float, pitch: float) -> bool:
	var players := [gaksital_fan_sfx]
	players.append_array(gaksital_fan_sfx_layers)
	var valid_players: Array[AudioStreamPlayer] = []
	for value in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return false
	var clamped_volume: float = clampf(volume, 0.0, 1.0)
	for offset in range(valid_players.size()):
		var index: int = (gaksital_fan_sfx_cursor + offset) % valid_players.size()
		var player: AudioStreamPlayer = valid_players[index]
		if not player.playing:
			gaksital_fan_sfx_cursor = (index + 1) % valid_players.size()
			_set_sfx_player_linear_volume(player, clamped_volume)
			player.pitch_scale = pitch
			player.play()
			return true
	var fallback_index: int = gaksital_fan_sfx_cursor % valid_players.size()
	var fallback_player: AudioStreamPlayer = valid_players[fallback_index]
	gaksital_fan_sfx_cursor = (fallback_index + 1) % valid_players.size()
	_set_sfx_player_linear_volume(fallback_player, clamped_volume)
	fallback_player.pitch_scale = pitch
	fallback_player.stop()
	fallback_player.play()
	return true


func _play_commando_ak47_fire_layer(pitch: float) -> bool:
	var players := [commando_ak47_fire_sfx]
	players.append_array(commando_ak47_fire_sfx_layers)
	var valid_players: Array[AudioStreamPlayer] = []
	for value in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return false
	for offset in range(valid_players.size()):
		var index: int = (commando_ak47_fire_sfx_cursor + offset) % valid_players.size()
		var player: AudioStreamPlayer = valid_players[index]
		if not player.playing:
			commando_ak47_fire_sfx_cursor = (index + 1) % valid_players.size()
			player.pitch_scale = pitch
			player.play()
			return true
	var fallback_index: int = commando_ak47_fire_sfx_cursor % valid_players.size()
	var fallback_player: AudioStreamPlayer = valid_players[fallback_index]
	commando_ak47_fire_sfx_cursor = (fallback_index + 1) % valid_players.size()
	fallback_player.pitch_scale = pitch
	fallback_player.stop()
	fallback_player.play()
	return true


func _play_angel_blessing_absorb_layer() -> bool:
	var players := [angel_blessing_absorb_sfx]
	players.append_array(angel_blessing_absorb_sfx_layers)
	var valid_players: Array[AudioStreamPlayer] = []
	for value: Variant in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return false
	for offset: int in range(valid_players.size()):
		var index: int = (angel_blessing_absorb_sfx_cursor + offset) % valid_players.size()
		var player: AudioStreamPlayer = valid_players[index]
		if player.playing:
			continue
		angel_blessing_absorb_sfx_cursor = (index + 1) % valid_players.size()
		player.pitch_scale = 1.0
		player.play()
		return true
	var fallback_index: int = angel_blessing_absorb_sfx_cursor % valid_players.size()
	var fallback_player: AudioStreamPlayer = valid_players[fallback_index]
	angel_blessing_absorb_sfx_cursor = (fallback_index + 1) % valid_players.size()
	fallback_player.pitch_scale = 1.0
	fallback_player.stop()
	fallback_player.play()
	return true


func _create_optional_sfx(name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	if FileAccess.file_exists(path) or ProjectResourceLoader.audio_resource_exists(path):
		return _configure_sfx_player(player_factory.create(owner_node, name, path, volume_db))
	var player := AudioStreamPlayer.new()
	player.name = name
	player.bus = "Master"
	player.volume_db = volume_db
	if owner_node != null:
		owner_node.add_child(player)
	return _configure_sfx_player(player)


func _ensure_bgm_player(bgm_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _get_bgm_player(bgm_name)
	if _is_owned_player_ready(player):
		return player
	return stage_bgm_audio.create_and_cache_player(bgm_name, Callable(self, "_create_bgm_player"))


func _create_bgm_player(name: String, path: String, gain: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = player_factory.create(owner_node, name, path, _volume_to_db(gain))
	_enable_loop(player)
	return game_audio_bus_controller.configure_bgm_player(player)


func _get_bgm_player(bgm_name: String) -> AudioStreamPlayer:
	return stage_bgm_audio.get_player(bgm_name)


func _apply_audio_buses_and_volumes() -> void:
	game_audio_bus_controller.apply_audio_buses_and_volumes(
		stage_bgm_audio.get_players(),
		_get_sfx_players(),
		paddle_hit_sfx,
		wall_hit_sfx
	)
	paddle_hit_audio_layers.route_to_bus(SFX_PAN_PADDLE_BUS_NAME)


func _adopt_existing_audio_bus_volumes() -> void:
	game_audio_bus_controller.adopt_existing_audio_bus_volumes()


func _get_existing_audio_bus_volume(bus_name: String, fallback: float) -> float:
	return game_audio_bus_controller.get_existing_audio_bus_volume(bus_name, fallback)


func _apply_bgm_bus_to_players() -> void:
	game_audio_bus_controller.route_bgm_players(stage_bgm_audio.get_players())


func _apply_sfx_bus_to_players() -> void:
	game_audio_bus_controller.route_sfx_players(_get_sfx_players(), paddle_hit_sfx, wall_hit_sfx)
	paddle_hit_audio_layers.route_to_bus(SFX_PAN_PADDLE_BUS_NAME)


func _ensure_hit_pan_buses() -> void:
	game_audio_bus_controller.ensure_hit_pan_buses()


func _ensure_sfx_pan_bus(bus_name: String, current_panner: AudioEffectPanner) -> AudioEffectPanner:
	return game_audio_bus_controller.ensure_sfx_pan_bus(bus_name, current_panner)


func _configure_sfx_player(player: AudioStreamPlayer) -> AudioStreamPlayer:
	return game_audio_bus_controller.configure_sfx_player(player)


func _apply_bgm_bus_volume() -> void:
	game_audio_bus_controller.apply_bgm_bus_volume()


func _apply_sfx_bus_volume() -> void:
	game_audio_bus_controller.apply_sfx_bus_volume()


func _ensure_audio_bus(bus_name: String) -> int:
	return game_audio_bus_controller.ensure_audio_bus(bus_name)


func _volume_to_db(volume: float) -> float:
	return game_audio_bus_controller.volume_to_db(volume)


func _get_sfx_players() -> Array:
	return game_ui_feedback_audio.get_sfx_bus_players() + core_ball_dash_audio.get_players() + smasher_skill_audio.get_skill_players() + stage1_boss_skill_audio.get_primary_players() + blacksmith_thor_shield_audio.get_players() + viper_skill_audio.get_players() + commando_skill_audio.get_sfx_bus_players() + item_reward_feedback_audio.get_sfx_bus_players() + [
		han_miryang_prologue_tablet_crack_sfx,
		han_miryang_prologue_tablet_crack_tail_sfx,
		lingpet_acquire_cutin_sfx,
		lingpet_acquire_click_deep_bass_sfx,
		lingpet_acquire_click_crackle_sweep_sfx,
		lingpet_guardian_enhance_roll_loop_sfx,
		lingpet_guardian_enhance_stamp_sfx,
		lingpet_guardian_enhance_result_tail_sfx,
		lingpet_lunabi_click_voice_sfx,
		lingpet_volty_click_voice_sfx,
		lingpet_milkring_click_voice_sfx,
		lingpet_red_dragon_click_voice_sfx,
		lingpet_maribo_click_voice_sfx,
		lingpet_rabi_click_voice_sfx,
		lingpet_lumion_click_voice_sfx,
		lingpet_monkeyring_click_voice_sfx,
		lingpet_onimaru_click_voice_sfx,
		lingpet_orosha_click_voice_sfx,
		lingpet_koyora_click_voice_sfx,
	] + lingpet_combat_audio.get_players() + item_reward_feedback_audio.get_cinematic_players() + elemental_combat_audio.get_sfx_bus_players() + item_reward_feedback_audio.get_item_action_players() + transformation_item_audio.get_sfx_bus_players() + projectile_item_audio.get_players() + smasher_skill_audio.get_stage_feedback_players() + shared_stage_feedback_audio.get_primary_players() + stage2_battle_audio.get_players() + stage3_battle_audio.get_players() + lingpet_combat_audio.get_stage_sfx_bus_players() + stage4_ponk_audio.get_players() + stage5_hongryun_audio.get_primary_players() + stage6_tetriser_audio.get_players() + stage7_akamu_audio.get_players() + shared_stage_feedback_audio.get_tail_players() + stage1_boss_skill_audio.get_fan_layers() + commando_skill_audio.get_ak47_fire_layers() + item_reward_feedback_audio.get_absorb_layers() + stage5_hongryun_audio.get_hurt_players() + perk_fusion_combat_audio.get_players() + paddle_hit_audio_layers.get_players()


func _select_stage1_bgm_name() -> String:
	return stage_bgm_playback_controller.select_stage_bgm_name(
		1,
		stage_bgm_audio,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func _get_stage1_bgm_candidates() -> Array[String]:
	return stage_bgm_playback_controller.get_stage_bgm_candidates(
		1,
		stage_bgm_audio,
		Callable(self, "_ensure_bgm_player")
	)


func _select_stage2_bgm_name() -> String:
	return stage_bgm_playback_controller.select_stage_bgm_name(
		2,
		stage_bgm_audio,
		Callable(self, "_ensure_bgm_player"),
		Callable(self, "_get_bgm_player")
	)


func _get_stage2_bgm_candidates() -> Array[String]:
	return stage_bgm_playback_controller.get_stage_bgm_candidates(
		2,
		stage_bgm_audio,
		Callable(self, "_ensure_bgm_player")
	)


func _is_owned_player_ready(player: AudioStreamPlayer) -> bool:
	return player != null and is_instance_valid(player) and player.get_parent() == owner_node


func _enable_loop(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	# ProjectResourceLoader.load_audio_stream caches by path and the player factory
	# assigns that cached AudioStream RAW, so one AudioStream instance can back
	# several players (gravityaccel.wav is shared by chaos_spear_blackhole_sfx AND
	# the focused Guardian Spirit gravity-accel cast player). Flipping loop_mode on
	# the shared instance
	# force-loops EVERY player pointing at it -- that is what made Serabi's 중력가속
	# one-shot cast cue loop forever and bleed into the next round. Duplicate first
	# so only THIS player's stream loops; every other user keeps the one-shot cache
	# instance untouched.
	var stream: AudioStream = player.stream.duplicate() as AudioStream
	player.stream = stream
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = max(0, int(round(wav_stream.get_length() * float(wav_stream.mix_rate))))
	elif stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		mp3_stream.loop = true
	elif stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = stream
		ogg_stream.loop = true
