extends SceneTree

# S3 curve-and-ceiling seal for the 37 three-star Mugong progression owner.
# LEGACY_LANES freezes the eb116e595 five-level tables/overflow. S3_AUTHORED
# independently freezes the approved three authored values. Every lane proves
# new Lv.3 == legacy Lv.5 and new Lv.4-10 == legacy Lv.6-12.

const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const ElixirOfMasteryRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LINEAR := "linear"
const HOLD := "hold"
const STAIRCASE := "staircase"

# These six max_level=1 catalog choices are route/meta systems added beside
# the 40 unlock-only Bigeup/Firearm/Mythic entries; they were never five-star
# Mugong and are outside the user's 40-entry exclusion count.
const NON_MUGONG_SINGLE_LEVEL_CHOICES := {
	"unlock_soul_summon_art": true,
	"unlock_dalji_vision_chain_top": true,
	"unlock_cheongringwi_vision_dragon_torrent": true,
	"unlock_yeonmyo_vision_bonghongwe": true,
	"unlock_gaksital_vision_fan_throw": true,
	"lingpet_guardian_enhance": true,
}

# Additive post-migration lanes are intentionally outside the frozen five-star
# fixture. They must be present in the owner without changing the exact 37-id
# migration family or retroactively rewriting its legacy/S3 evidence tables.
const POST_MIGRATION_ADDITIVE_LANES := {
	"downtown_treasure_map": {
		"fusion_muhon_cost_reduction": true,
	},
}

# Ratio/rounding fixture classification. Every non-structural lane is checked
# from its legacy ceiling instead of merely copying the S3 table. Float lanes
# retain raw precision; integer/count/percentage lanes round. Lower-is-better
# lanes project the improvement from neutral and then return to the raw domain.
const FLOAT_RATIO_LANES := {
	"dash_acceleration/vertical_scale_bonus": true,
	"dash_acceleration/horizontal_scale_bonus": true,
	"item_luck/spawn_wait_reduction": true,
	"item_caffeine/duration_bonus": true,
	"item_polish/general_amplify": true,
	"item_polish/mythic_roll_bonus": true,
	"item_recycle/retain_chance": true,
	"downtown_treasure_map/mythic_offer_bonus": true,
	"downtown_treasure_map/vision_box_chance_bonus": true,
	"training_mastery/training_amplify": true,
	"dash_spirit/laser_chance": true,
	"extension_gear/duration_bonus": true,
	"combo_amplifier_chip/drive_speed_bonus": true,
	"combo_amplifier_chip/drive_curve_bonus": true,
	"combo_amplifier_chip/smash_speed_bonus": true,
	"combo_amplifier_chip/initial_boost_decay_reduction": true,
	"jetpack_enhance/max_gauge_bonus": true,
	"jetpack_enhance/airborne_gauge_gain_bonus": true,
	"kick_enhance/runtime_aim_gain": true,
	"kick_enhance/runtime_hit_speed_bonus": true,
	"kick_enhance/prep_reduction": true,
	"kick_enhance/furnace_knockback_chance": true,
	"blade_amp/range_width_bonus": true,
	"blade_amp/projectile_speed_bonus": true,
	"blade_amp/hit_speed_bonus": true,
	"adversity_armor/invincible_duration_sec": true,
	"venom_mist_gauntlet/mist_duration_sec": true,
	"sage_ring/duration_sec": true,
}
const LOWER_INTEGER_NEUTRALS := {
	"pistol_enhance/spread_degrees": 15.0,
	"sensor/auto_dash_cooldown_sec": 33.75,
	"shrapnel_armor/gauge_cost": 56.25,
	"soul_burst/soul_burst_gauge_cost": 187.5,
}
const HIGHER_INTEGER_NEUTRALS := {
	"kick_enhance/runtime_aim_candidate_count": 3.0,
}
const RATIO_START_LEVELS := {
	"jetpack_enhance/airborne_gauge_gain_bonus": 2,
	"kick_enhance/furnace_knockback_chance": 2,
	"blade_amp/followup_chance_pct": 2,
	"four_poisons/cooldown_reduction_pct": 2,
}
const STRUCTURAL_LANES := {
	"perk_boost_charge/free_dash_count": true,
	"perk_boost_charge/recharge_reduction_pct": true,
	"kick_enhance/guard_fire_knockback_pct": true,
	"blade_amp/homing_tier": true,
	"four_poisons/clone_hp": true,
	"four_poisons/superarmor": true,
	"four_poisons/clone_replication": true,
	"pistol_enhance/magazine_size": true,
	"sage_ring/trigger_chance_pct": true,
	"sage_ring/perk_level_bonus": true,
}

# Fixture lane fields: v=authored Lv.1-5, s=legacy overflow step, m=mode,
# lo/hi=legacy clamp. Converted lanes omit s: their legacy step was
# (Lv.5-Lv.1)/4. Structural converted lanes explicitly hold.
const LEGACY_LANES := {
	"dash_acceleration": {
		"vertical_scale_bonus": {"v": [0.70, 1.40, 2.10, 2.80, 3.50], "s": 0.70},
		"horizontal_scale_bonus": {"v": [0.10, 0.20, 0.30, 0.40, 0.50], "s": 0.10},
	},
	"item_luck": {"spawn_wait_reduction": {"v": [0.12, 0.24, 0.36, 0.48, 0.60], "s": 0.12}},
	"item_gauge_mastery": {"gauge_gain": {"v": [15.0, 30.0, 45.0, 60.0, 75.0], "s": 15.0}},
	"item_caffeine": {"duration_bonus": {"v": [0.30, 0.60, 0.90, 1.20, 1.50], "s": 0.30}},
	"item_polish": {
		"general_amplify": {"v": [0.05, 0.10, 0.15, 0.20, 0.25], "s": 0.05},
		"mythic_roll_bonus": {"v": [0.12, 0.24, 0.36, 0.48, 0.60], "s": 0.12},
	},
	"item_recycle": {"retain_chance": {"v": [0.07, 0.14, 0.21, 0.28, 0.35], "s": 0.07, "hi": 0.90}},
	"downtown_treasure_map": {
		"mythic_offer_bonus": {"v": [1.5, 3.0, 4.5, 6.0, 7.5], "s": 1.5},
		"vision_box_chance_bonus": {"v": [0.03, 0.06, 0.09, 0.12, 0.15], "s": 0.03},
	},
	"training_mastery": {"training_amplify": {"v": [0.2, 0.4, 0.6, 0.8, 1.0], "s": 0.2}},
	"perk_boost_charge": {
		"trigger_chance_pct": {"v": [7.0, 14.0, 21.0, 28.0, 35.0], "s": 7.0, "hi": 100.0},
		"free_dash_count": {"v": [1.0, 1.0, 1.0, 1.0, 1.0], "m": HOLD},
		"recharge_reduction_pct": {"v": [90.0, 90.0, 90.0, 90.0, 90.0], "m": HOLD},
	},
	"perk_laurel_shield": {"leaf_count": {"v": [1.0, 2.0, 3.0, 4.0, 5.0], "s": 1.0}},
	"dash_spirit": {"laser_chance": {"v": [0.07, 0.14, 0.21, 0.28, 0.35], "s": 0.07}},
	"extension_gear": {"duration_bonus": {"v": [0.25, 0.50, 0.75, 1.00, 1.25], "s": 0.25}},
	"combo_amplifier_chip": {
		"drive_speed_bonus": {"v": [0.9, 1.8, 2.7, 3.6, 4.5], "s": 0.9},
		"drive_curve_bonus": {"v": [0.05, 0.10, 0.15, 0.15, 0.15], "m": HOLD},
		"smash_speed_bonus": {"v": [0.45, 0.90, 1.35, 1.80, 2.25], "s": 0.45},
		"initial_boost_decay_reduction": {"v": [0.1, 0.2, 0.3, 0.4, 0.5], "s": 0.1, "hi": 0.5},
	},
	"jetpack_enhance": {
		"max_gauge_bonus": {"v": [0.2, 0.4, 0.6, 0.8, 1.0], "s": 0.2},
		"airborne_gauge_gain_bonus": {"v": [0.0, 0.0, 0.1, 0.2, 0.3], "s": 0.1},
	},
	"kick_enhance": {
		"authored_precision_pct": {"v": [8.0, 16.0, 24.0, 32.0, 40.0], "s": 8.0},
		"authored_speed_pct": {"v": [12.0, 24.0, 36.0, 48.0, 60.0], "s": 12.0},
		"runtime_aim_gain": {"v": [0.09, 0.18, 0.27, 0.36, 0.45], "s": 0.09, "hi": 0.90},
		"runtime_aim_candidate_count": {"v": [4.0, 5.0, 6.0, 7.0, 8.0], "m": HOLD},
		"runtime_hit_speed_bonus": {"v": [0.04, 0.08, 0.12, 0.16, 0.20], "s": 0.04},
		"prep_reduction": {"v": [0.07, 0.14, 0.21, 0.28, 0.35], "s": 0.07, "hi": 0.90},
		"furnace_knockback_chance": {"v": [0.0, 0.0, 0.1, 0.2, 0.3], "s": 0.1, "hi": 1.0},
		"guard_fire_knockback_pct": {"v": [0.0, 0.0, 150.0, 150.0, 150.0], "m": HOLD},
	},
	"blade_amp": {
		"range_width_bonus": {"v": [0.1, 0.2, 0.3, 0.4, 0.5], "m": HOLD},
		"projectile_speed_bonus": {"v": [0.1, 0.2, 0.3, 0.4, 0.5], "s": 0.1},
		"hit_speed_bonus": {"v": [0.15, 0.30, 0.45, 0.60, 0.75], "s": 0.15},
		"gauge_cost_reduction": {"v": [10.0, 20.0, 30.0, 40.0, 50.0], "s": 10.0, "hi": 100.0},
		"homing_tier": {"v": [0.0, 0.0, 1.0, 1.0, 2.0], "m": HOLD},
		"followup_chance_pct": {"v": [0.0, 0.0, 10.0, 20.0, 30.0], "s": 10.0, "hi": 100.0},
	},
	"four_poisons": {
		"prep_reduction_pct": {"v": [8.0, 16.0, 25.0, 33.0, 40.0], "s": 4.0, "hi": 70.0},
		"sleep_pct": {"v": [5.0, 10.0, 15.0, 20.0, 25.0], "s": 5.0, "hi": 50.0},
		"confusion_pct": {"v": [12.0, 24.0, 36.0, 48.0, 70.0], "s": 10.0, "hi": 150.0},
		"dual_duration_pct": {"v": [7.0, 14.0, 20.0, 27.0, 33.0], "s": 5.0, "hi": 45.0},
		"cooldown_reduction_pct": {"v": [0.0, 0.0, 10.0, 15.0, 20.0], "s": 4.0, "hi": 40.0},
		"clone_hp": {"v": [2.0, 2.0, 3.0, 3.0, 4.0], "m": STAIRCASE, "s": 1.0, "every": 2, "origin": 4, "steps": 2, "hi": 6.0},
		"superarmor": {"v": [0.0, 0.0, 1.0, 1.0, 1.0], "m": HOLD},
		"clone_replication": {"v": [0.0, 0.0, 0.0, 0.0, 1.0], "m": HOLD},
	},
	"pistol_enhance": {
		"spread_degrees": {"v": [12.0, 9.0, 6.0, 3.0, 1.0], "m": HOLD},
		"speed_bonus_pct": {"v": [10.0, 20.0, 30.0, 40.0, 50.0], "m": HOLD},
		"knockback_bonus_pct": {"v": [30.0, 60.0, 90.0, 120.0, 150.0], "m": HOLD},
		"magazine_size": {"v": [5.0, 5.0, 6.0, 6.0, 7.0], "s": 1.0},
	},
	"star_detector": {"star_bonus_pct": {"v": [5.0, 10.0, 15.0, 20.0, 25.0]}},
	"adversity_armor": {
		"trigger_chance_pct": {"v": [20.0, 25.0, 30.0, 35.0, 40.0], "hi": 100.0},
		"invincible_duration_sec": {"v": [5.0, 8.0, 10.0, 13.0, 15.0]},
	},
	"reinforced_boomerang_gauntlet": {
		"boomerang_knockback_pct": {"v": [20.0, 28.0, 35.0, 43.0, 50.0]},
		"boomerang_stun_pct": {"v": [20.0, 35.0, 50.0, 65.0, 80.0]},
		"boomerang_launch_speed_pct": {"v": [15.0, 24.0, 33.0, 41.0, 50.0]},
		"boomerang_homing_pct": {"v": [10.0, 20.0, 30.0, 40.0, 50.0]},
		"boomerang_spawn_bonus_pct": {"v": [50.0, 88.0, 125.0, 163.0, 200.0]},
	},
	"sensor": {
		"auto_dash_token_count": {"v": [1.0, 1.0, 2.0, 2.0, 2.0]},
		"auto_dash_cooldown_sec": {"v": [30.0, 26.0, 23.0, 19.0, 15.0], "lo": 1.0},
	},
	"dowsing_pendulum": {"attraction_range": {"v": [120.0, 160.0, 200.0, 240.0, 280.0]}},
	"chargebag": {"chargebag_pct": {"v": [15.0, 25.0, 35.0, 45.0, 55.0]}},
	"battery": {"gauge_preserve_pct": {"v": [40.0, 55.0, 70.0, 85.0, 100.0], "hi": 100.0}},
	"master": {
		"wall_length_pct": {"v": [12.0, 20.0, 29.0, 37.0, 45.0]},
		"item_cooldown_pct": {"v": [3.0, 5.0, 8.0, 10.0, 12.0], "hi": 95.0},
		"wall_spawn_bonus_pct": {"v": [100.0, 158.0, 215.0, 273.0, 330.0]},
	},
	"gold_digger": {"gold_bonus_pct": {"v": [15.0, 25.0, 35.0, 45.0, 55.0]}},
	"lucky_coin": {"double_spawn_pct": {"v": [3.0, 7.0, 10.0, 14.0, 17.0], "hi": 100.0}},
	"shrapnel_armor": {
		"trigger_chance_pct": {"v": [6.0, 9.0, 12.0, 14.0, 17.0], "hi": 100.0},
		"shard_count": {"v": [4.0, 5.0, 6.0, 7.0, 8.0]},
		"knockback_level": {"v": [1.0, 2.0, 3.0, 3.0, 4.0]},
		"gauge_cost": {"v": [50.0, 44.0, 38.0, 31.0, 25.0], "lo": 0.0},
	},
	"foul_whistle": {"negate_chance_pct": {"v": [3.0, 5.0, 7.0, 9.0, 11.0], "hi": 100.0}},
	"neural_helmet": {
		"aipill_gauge_reduction": {"v": [10.0, 15.0, 20.0, 25.0, 30.0], "hi": 90.0},
		"aipill_ball_speed_bonus_pct": {"v": [2.0, 4.0, 6.0, 8.0, 10.0]},
		"aipill_spawn_bonus_pct": {"v": [100.0, 158.0, 215.0, 273.0, 330.0]},
	},
	"commando_arm": {
		"throw_speed_pct": {"v": [6.0, 11.0, 15.0, 20.0, 24.0]},
		"explosion_range_pct": {"v": [3.0, 7.0, 11.0, 14.0, 18.0]},
		"smoke_duration_pct": {"v": [12.0, 21.0, 30.0, 39.0, 48.0]},
		"prep_reduction_pct": {"v": [12.0, 21.0, 30.0, 39.0, 48.0], "hi": 95.0},
	},
	"rainbow_fur_glove": {
		"rainbow_glove_trigger_chance_pct": {"v": [3.0, 4.0, 5.0, 6.0, 7.0], "hi": 100.0},
		"rainbow_glove_cooldown_reduction_pct": {"v": [8.0, 11.0, 14.0, 17.0, 20.0], "hi": 95.0},
	},
	"knee_pads": {"knee_charge_pct": {"v": [20.0, 33.0, 45.0, 58.0, 70.0]}},
	"soul_burst": {"soul_burst_gauge_cost": {"v": [170.0, 153.0, 135.0, 118.0, 100.0], "lo": 0.0}},
	"venom_mist_gauntlet": {
		"mist_trigger_chance_pct": {"v": [20.0, 29.0, 38.0, 46.0, 55.0], "hi": 100.0},
		"mist_duration_sec": {"v": [1.5, 2.5, 3.5, 4.5, 5.5]},
	},
	"sage_ring": {
		"trigger_chance_pct": {"v": [5.0, 5.0, 5.0, 5.0, 5.0]},
		"perk_level_bonus": {"v": [1.0, 1.0, 2.0, 2.0, 3.0]},
		"duration_sec": {"v": [6.0, 7.0, 8.0, 9.0, 10.0]},
	},
}

# Integer, percentage-point, and count lanes round the positive effect amount
# with roundi. Float lanes keep runtime precision. Lower-is-better lanes apply
# the ratios to the improvement from their legacy level-zero neutral, never to
# the raw value. Individual unlocks use migrated milestones (old Lv.3 -> new
# Lv.2, old Lv.5 -> new Lv.3) instead of fractional unlock values.
const S3_AUTHORED := {
	"dash_acceleration": {"vertical_scale_bonus": [0.875, 2.03, 3.50], "horizontal_scale_bonus": [0.125, 0.29, 0.50]},
	"item_luck": {"spawn_wait_reduction": [0.15, 0.348, 0.60]},
	"item_gauge_mastery": {"gauge_gain": [19.0, 44.0, 75.0]},
	"item_caffeine": {"duration_bonus": [0.375, 0.87, 1.50]},
	"item_polish": {"general_amplify": [0.0625, 0.145, 0.25], "mythic_roll_bonus": [0.15, 0.348, 0.60]},
	"item_recycle": {"retain_chance": [0.0875, 0.203, 0.35]},
	"downtown_treasure_map": {"mythic_offer_bonus": [1.875, 4.35, 7.50], "vision_box_chance_bonus": [0.0375, 0.087, 0.15]},
	"training_mastery": {"training_amplify": [0.25, 0.58, 1.00]},
	"perk_boost_charge": {"trigger_chance_pct": [9.0, 20.0, 35.0], "free_dash_count": [1.0, 1.0, 1.0], "recharge_reduction_pct": [90.0, 90.0, 90.0]},
	"perk_laurel_shield": {"leaf_count": [1.0, 3.0, 5.0]},
	"dash_spirit": {"laser_chance": [0.0875, 0.203, 0.35]},
	"extension_gear": {"duration_bonus": [0.3125, 0.725, 1.25]},
	"combo_amplifier_chip": {"drive_speed_bonus": [1.125, 2.61, 4.50], "drive_curve_bonus": [0.0375, 0.087, 0.15], "smash_speed_bonus": [0.5625, 1.305, 2.25], "initial_boost_decay_reduction": [0.125, 0.29, 0.50]},
	"jetpack_enhance": {"max_gauge_bonus": [0.25, 0.58, 1.00], "airborne_gauge_gain_bonus": [0.0, 0.174, 0.30]},
	"kick_enhance": {"authored_precision_pct": [10.0, 23.0, 40.0], "authored_speed_pct": [15.0, 35.0, 60.0], "runtime_aim_gain": [0.1125, 0.261, 0.45], "runtime_aim_candidate_count": [4.0, 6.0, 8.0], "runtime_hit_speed_bonus": [0.05, 0.116, 0.20], "prep_reduction": [0.0875, 0.203, 0.35], "furnace_knockback_chance": [0.0, 0.174, 0.30], "guard_fire_knockback_pct": [0.0, 150.0, 150.0]},
	"blade_amp": {"range_width_bonus": [0.125, 0.29, 0.50], "projectile_speed_bonus": [0.125, 0.29, 0.50], "hit_speed_bonus": [0.1875, 0.435, 0.75], "gauge_cost_reduction": [13.0, 29.0, 50.0], "homing_tier": [0.0, 1.0, 2.0], "followup_chance_pct": [0.0, 17.0, 30.0]},
	"four_poisons": {"prep_reduction_pct": [10.0, 23.0, 40.0], "sleep_pct": [6.0, 15.0, 25.0], "confusion_pct": [18.0, 41.0, 70.0], "dual_duration_pct": [8.0, 19.0, 33.0], "cooldown_reduction_pct": [0.0, 12.0, 20.0], "clone_hp": [2.0, 3.0, 4.0], "superarmor": [0.0, 1.0, 1.0], "clone_replication": [0.0, 0.0, 1.0]},
	"pistol_enhance": {"spread_degrees": [11.0, 7.0, 1.0], "speed_bonus_pct": [13.0, 29.0, 50.0], "knockback_bonus_pct": [38.0, 87.0, 150.0], "magazine_size": [5.0, 6.0, 7.0]},
	"star_detector": {"star_bonus_pct": [6.0, 15.0, 25.0]},
	"adversity_armor": {"trigger_chance_pct": [10.0, 23.0, 40.0], "invincible_duration_sec": [3.75, 8.70, 15.0]},
	"reinforced_boomerang_gauntlet": {"boomerang_knockback_pct": [13.0, 29.0, 50.0], "boomerang_stun_pct": [20.0, 46.0, 80.0], "boomerang_launch_speed_pct": [13.0, 29.0, 50.0], "boomerang_homing_pct": [13.0, 29.0, 50.0], "boomerang_spawn_bonus_pct": [50.0, 116.0, 200.0]},
	"sensor": {"auto_dash_token_count": [1.0, 1.0, 2.0], "auto_dash_cooldown_sec": [29.0, 23.0, 15.0]},
	"dowsing_pendulum": {"attraction_range": [70.0, 162.0, 280.0]},
	"chargebag": {"chargebag_pct": [14.0, 32.0, 55.0]},
	"battery": {"gauge_preserve_pct": [25.0, 58.0, 100.0]},
	"master": {"wall_length_pct": [11.0, 26.0, 45.0], "item_cooldown_pct": [3.0, 7.0, 12.0], "wall_spawn_bonus_pct": [83.0, 191.0, 330.0]},
	"gold_digger": {"gold_bonus_pct": [14.0, 32.0, 55.0]},
	"lucky_coin": {"double_spawn_pct": [4.0, 10.0, 17.0]},
	"shrapnel_armor": {"trigger_chance_pct": [4.0, 10.0, 17.0], "shard_count": [2.0, 5.0, 8.0], "knockback_level": [1.0, 2.0, 4.0], "gauge_cost": [48.0, 38.0, 25.0]},
	"foul_whistle": {"negate_chance_pct": [3.0, 6.0, 11.0]},
	"neural_helmet": {"aipill_gauge_reduction": [8.0, 17.0, 30.0], "aipill_ball_speed_bonus_pct": [3.0, 6.0, 10.0], "aipill_spawn_bonus_pct": [83.0, 191.0, 330.0]},
	"commando_arm": {"throw_speed_pct": [6.0, 14.0, 24.0], "explosion_range_pct": [5.0, 10.0, 18.0], "smoke_duration_pct": [12.0, 28.0, 48.0], "prep_reduction_pct": [12.0, 28.0, 48.0]},
	"rainbow_fur_glove": {"rainbow_glove_trigger_chance_pct": [2.0, 4.0, 7.0], "rainbow_glove_cooldown_reduction_pct": [5.0, 12.0, 20.0]},
	"knee_pads": {"knee_charge_pct": [18.0, 41.0, 70.0]},
	"soul_burst": {"soul_burst_gauge_cost": [166.0, 137.0, 100.0]},
	"venom_mist_gauntlet": {"mist_trigger_chance_pct": [14.0, 32.0, 55.0], "mist_duration_sec": [1.375, 3.19, 5.5]},
	"sage_ring": {"trigger_chance_pct": [5.0, 5.0, 5.0], "perk_level_bonus": [1.0, 2.0, 3.0], "duration_sec": [2.5, 5.8, 10.0]},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_test_exact_target_and_lane_sets()
	_test_post_migration_additive_lanes()
	_test_catalog_population_boundaries()
	_test_authored_curve_and_ceiling()
	_test_overflow_mapping()
	_test_primary_runtime_consumer()
	_test_catalog_descriptions()
	_test_known_distinct_lanes()
	_test_elixir_candidate_equivalence()
	_test_elixir_cinematic_level_derivation()
	_test_corrupted_fixture_goes_red()
	_test_real_snapshot_projection()
	LanguageSettings.set_test_locale_override("")
	if not _failures.is_empty():
		ProjectResourceLoader.clear_caches()
		quit(1)
		return
	print("runtime_perk_progression_equivalence_smoke: ok TARGETS=37 CURVE=0.25/0.58/1.00 OVERFLOW=Lv4-10==legacyLv6-12 NEGATIVE=RED ELIXIR=47")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _test_exact_target_and_lane_sets() -> void:
	_expect(LEGACY_LANES.size() == 37, "frozen target fixture must contain exactly 37 ids")
	_expect(S3_AUTHORED.size() == 37, "S3 authored fixture must contain exactly 37 ids")
	_expect(_string_set(RuntimePerkProgression.TARGET_PERK_IDS.keys()) == _string_set(LEGACY_LANES.keys()), "owner target ids must equal the frozen 37-id set")
	_expect(_string_set(S3_AUTHORED.keys()) == _string_set(LEGACY_LANES.keys()), "S3 fixture ids must equal the frozen 37-id set")
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		var expected_lanes: Dictionary = LEGACY_LANES[perk_id]
		var owner_lanes := _string_set(RuntimePerkProgression.get_lane_ids(perk_id))
		var additive_lanes: Dictionary = POST_MIGRATION_ADDITIVE_LANES.get(perk_id, {})
		for additive_lane_value in additive_lanes.keys():
			var additive_lane := str(additive_lane_value)
			_expect(owner_lanes.has(additive_lane), "%s must retain additive lane %s" % [perk_id, additive_lane])
			owner_lanes.erase(additive_lane)
		_expect(owner_lanes == _string_set(expected_lanes.keys()), "%s frozen lane ids must remain unchanged after additive lanes are removed" % perk_id)
		_expect(_string_set((S3_AUTHORED[perk_id] as Dictionary).keys()) == _string_set(expected_lanes.keys()), "%s S3 lane ids must match the frozen baseline" % perk_id)
		for lane_id_value in expected_lanes.keys():
			var lane_id := str(lane_id_value)
			var owner_lane: Dictionary = (RuntimePerkProgression.PROGRESSIONS[perk_id]["lanes"] as Dictionary)[lane_id]
			_expect(owner_lane.has("overflow"), "%s/%s must declare overflow" % [perk_id, lane_id])
			_expect(owner_lane.has("milestones"), "%s/%s must declare milestones" % [perk_id, lane_id])
			_expect(owner_lane.has("polarity"), "%s/%s must declare polarity" % [perk_id, lane_id])


func _test_post_migration_additive_lanes() -> void:
	const PERK_ID := "downtown_treasure_map"
	const LANE_ID := "fusion_muhon_cost_reduction"
	var lane: Dictionary = (RuntimePerkProgression.PROGRESSIONS[PERK_ID]["lanes"] as Dictionary).get(LANE_ID, {})
	var overflow: Dictionary = lane.get("overflow", {})
	_expect(not lane.is_empty(), "Treasure Map fusion-cost lane must be registered")
	_expect(RuntimePerkProgression.TARGET_PERK_IDS.size() == 37, "additive Treasure Map lane must not change the frozen 37-id family")
	_expect(RuntimePerkProgression.get_authored_level_count(PERK_ID, LANE_ID) == 3, "Treasure Map fusion-cost lane must keep three authored stars")
	_expect_close(RuntimePerkProgression.get_value(PERK_ID, LANE_ID, 0), 0.0, "Treasure Map unowned fusion-cost reduction")
	_expect_close(RuntimePerkProgression.get_value(PERK_ID, LANE_ID, 1), 1.0, "Treasure Map fusion-cost reduction Lv.1")
	_expect_close(RuntimePerkProgression.get_value(PERK_ID, LANE_ID, 2), 3.0, "Treasure Map fusion-cost reduction Lv.2")
	_expect_close(RuntimePerkProgression.get_value(PERK_ID, LANE_ID, 3), 3.0, "Treasure Map fusion-cost reduction Lv.3")
	_expect_close(RuntimePerkProgression.get_value(PERK_ID, LANE_ID, 4), 3.0, "Treasure Map fusion-cost reduction overflow must hold")
	_expect(RuntimePerkProgression.get_lane_polarity(PERK_ID, LANE_ID) == RuntimePerkProgression.POLARITY_STRUCTURAL, "Treasure Map fusion-cost lane must remain structural")
	_expect(RuntimePerkProgression.get_milestone_level(PERK_ID, LANE_ID, "free") == 3, "Treasure Map hard-free milestone must remain Lv.3")
	_expect(str(overflow.get("mode", "")) == HOLD, "Treasure Map fusion-cost overflow must hold at the authored ceiling")


func _test_catalog_population_boundaries() -> void:
	var all_data: Dictionary = RuntimePerkCatalog.new().get_all_perk_data()
	var target_three_star := 0
	var training_five_star := 0
	var unlock_only := 0
	var preexisting_three_or_four := 0
	var unexpected_five_plus := 0
	var unlock_ids: Array[String] = []
	var preexisting_ids: Array[String] = []
	for perk_id_value in all_data.keys():
		var perk_id := str(perk_id_value)
		var max_level := int((all_data[perk_id] as Dictionary).get("max_level", 0))
		if RuntimePerkProgression.TARGET_PERK_IDS.has(perk_id):
			_expect(max_level == 3, "%s target Mugong max_level must migrate to 3" % perk_id)
			target_three_star += 1
		elif RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(perk_id):
			_expect(max_level == 5, "%s training max_level must remain 5" % perk_id)
			training_five_star += 1
		elif max_level == 1 and not NON_MUGONG_SINGLE_LEVEL_CHOICES.has(perk_id):
			unlock_only += 1
			unlock_ids.append(perk_id)
		elif max_level in [3, 4]:
			preexisting_three_or_four += 1
			preexisting_ids.append(perk_id)
		elif max_level >= 5:
			unexpected_five_plus += 1
	_expect(target_three_star == 37, "catalog must contain exactly 37 migrated three-star Mugong")
	_expect(training_five_star == 10, "catalog must preserve exactly 10 five-level training perks")
	_expect(unlock_only == 40, "catalog must preserve exactly 40 max_level=1 unlock-only entries, got %d: %s" % [unlock_only, unlock_ids])
	var raw_expansion_max := int((RuntimePerkCatalog.COMMON_PERKS["common_expansion"] as Dictionary).get("max_level", 0))
	_expect(raw_expansion_max == 4, "common_expansion raw max_level must remain 4 even when the compatibility flag projects level 2")
	_expect(preexisting_three_or_four + 1 == 3, "catalog must preserve exactly 3 pre-existing max_level=3/4 entries including raw common_expansion, got %d: %s" % [preexisting_three_or_four + 1, preexisting_ids])
	_expect(unexpected_five_plus == 0, "no non-target/non-training max_level>=5 entry may remain")

func _test_authored_curve_and_ceiling() -> void:
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		for lane_id_value in (LEGACY_LANES[perk_id] as Dictionary).keys():
			var lane_id := str(lane_id_value)
			var expected_values: Array = (S3_AUTHORED[perk_id] as Dictionary)[lane_id]
			_expect(expected_values.size() == 3, "%s/%s must define exactly three authored values" % [perk_id, lane_id])
			_expect(RuntimePerkProgression.get_authored_level_count(perk_id, lane_id) == 3, "%s/%s owner must define exactly three authored values" % [perk_id, lane_id])
			for level in range(1, 4):
				_expect_close(RuntimePerkProgression.get_value(perk_id, lane_id, level), float(expected_values[level - 1]), "%s/%s S3 authored Lv.%d" % [perk_id, lane_id, level])
				_expect_close(RuntimePerkProgression.get_value(perk_id, lane_id, level), _ratio_contract_value(perk_id, lane_id, level), "%s/%s ratio/rounding contract Lv.%d" % [perk_id, lane_id, level])
			_expect_close(RuntimePerkProgression.get_value(perk_id, lane_id, 3), _legacy_value(perk_id, lane_id, 5), "%s/%s ceiling legacy Lv.5 -> S3 Lv.3" % [perk_id, lane_id])


func _test_overflow_mapping() -> void:
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		for lane_id_value in (LEGACY_LANES[perk_id] as Dictionary).keys():
			var lane_id := str(lane_id_value)
			for new_level in range(4, 11):
				var legacy_level := new_level + 2
				_expect_close(RuntimePerkProgression.get_value(perk_id, lane_id, new_level), _legacy_value(perk_id, lane_id, legacy_level), "%s/%s new Lv.%d == legacy Lv.%d" % [perk_id, lane_id, new_level, legacy_level])


func _test_primary_runtime_consumer() -> void:
	var queries: Object = RuntimePerkEffectiveLevels.new()
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		if not RuntimePerkProgression.has_primary_runtime_bonus(perk_id):
			continue
		var progression: Dictionary = RuntimePerkProgression.PROGRESSIONS[perk_id]
		var lane_id := str(progression.get("primary_runtime_lane", ""))
		for level in range(1, 11):
			var actual: float = queries.get_runtime_skill_bonus({perk_id: level}, 0, false, perk_id)
			var expected := _s3_value(perk_id, lane_id, level)
			_expect_close(actual, expected, "%s primary runtime Lv.%d" % [perk_id, level])
	for perk_id_value in LEGACY_LANES.keys():
		var converted_id := str(perk_id_value)
		if not RuntimePerkProgression.is_converted_perk(converted_id):
			continue
		for lane_id_value in (LEGACY_LANES[converted_id] as Dictionary).keys():
			var lane_id := str(lane_id_value)
			for level in range(1, 11):
				_expect_close(PerkConversionValues.get_value(converted_id, lane_id, level), _s3_value(converted_id, lane_id, level), "%s/%s converted consumer Lv.%d" % [converted_id, lane_id, level])


func _test_catalog_descriptions() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var all_data: Dictionary = catalog.get_all_perk_data()
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		_expect(all_data.has(perk_id), "%s must remain registered" % perk_id)
		if not all_data.has(perk_id):
			continue
		var perk_data: Dictionary = all_data[perk_id]
		_expect(int(perk_data.get("max_level", 0)) == 3, "%s max_level must be 3 in S3" % perk_id)
		var descriptions: Dictionary = perk_data.get("descriptions", {})
		_expect(descriptions.size() == 3, "%s must expose exactly three authored descriptions" % perk_id)
		for level in range(1, 4):
			var authored := str(descriptions.get(level, descriptions.get(str(level), "")))
			var generated := RuntimePerkOverflowDescriptions.generate_stats_text(perk_id, level)
			_expect(generated == authored and not generated.is_empty(), "%s Lv.%d catalog/runtime description drift: generated='%s' authored='%s'" % [perk_id, level, generated, authored])


func _test_known_distinct_lanes() -> void:
	for level in range(1, 11):
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "authored_precision_pct", level), _s3_value("kick_enhance", "authored_precision_pct", level), "kick authored precision Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "authored_speed_pct", level), _s3_value("kick_enhance", "authored_speed_pct", level), "kick authored speed Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "runtime_aim_gain", level), _s3_value("kick_enhance", "runtime_aim_gain", level), "kick runtime aim Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "runtime_hit_speed_bonus", level), _s3_value("kick_enhance", "runtime_hit_speed_bonus", level), "kick runtime hit speed Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("item_polish", "general_amplify", level), _s3_value("item_polish", "general_amplify", level), "item_polish general Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("item_polish", "mythic_roll_bonus", level), _s3_value("item_polish", "mythic_roll_bonus", level), "item_polish mythic Lv.%d" % level)
	_expect(not is_equal_approx(RuntimePerkProgression.get_value("kick_enhance", "authored_precision_pct", 3), RuntimePerkProgression.get_value("kick_enhance", "runtime_aim_gain", 3)), "kick authored/runtime lanes must remain explicitly distinct")
	_expect(not is_equal_approx(RuntimePerkProgression.get_value("item_polish", "general_amplify", 3), RuntimePerkProgression.get_value("item_polish", "mythic_roll_bonus", 3)), "item_polish general/mythic lanes must remain explicitly distinct")


func _test_elixir_candidate_equivalence() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var all_data: Dictionary = catalog.get_all_perk_data()
	var held_levels: Dictionary = {}
	for perk_id_value in all_data.keys():
		var perk_id := str(perk_id_value)
		var data: Dictionary = all_data[perk_id]
		if RuntimePerkProgression.has_perk(perk_id) or RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(perk_id):
			held_levels[perk_id] = 1
	var runtime: Object = ElixirOfMasteryRuntime.new()
	var current_ids := _candidate_id_set(runtime.get_eligible_perks(held_levels, [all_data]))
	var intended_ids := RuntimePerkProgression.TARGET_PERK_IDS.duplicate()
	intended_ids.merge(RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS, true)
	_expect(intended_ids.size() == 47, "Elixir intended family must remain exactly 37 Mugong + 10 training ids")
	_expect(current_ids == intended_ids, "catalog-derived Elixir candidates must retain all 47 ids in S3")

	var retired_literal_ids: Dictionary = {}
	for perk_id_value in all_data.keys():
		if int((all_data[perk_id_value] as Dictionary).get("max_level", 0)) >= 5 and int(held_levels.get(perk_id_value, 0)) < 5:
			retired_literal_ids[str(perk_id_value)] = true
	_expect(retired_literal_ids.size() == 10, "negative literal fixture must demonstrate the silent 37-candidate loss")


func _test_elixir_cinematic_level_derivation() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/elixir_of_mastery_cinematic_draw.gd")
	_expect(not source.is_empty(), "Elixir cinematic source must be readable")
	_expect(source.find("format_mugong_level_transition(old_lv, target_level, target_level)") >= 0, "Elixir transition text must derive both target and max from target_level")
	_expect(source.find("format_mugong_level(target_level, target_level)") >= 0, "Elixir badge text must derive both level and max from target_level")
	_expect(source.find("format_mugong_level_transition(old_lv, 5, 5)") < 0, "Elixir transition text must not retain the max-level literal trap")
	_expect(source.find("format_mugong_level(5, 5)") < 0, "Elixir badge text must not retain the max-level literal trap")


func _test_corrupted_fixture_goes_red() -> void:
	var corrupted: Dictionary = RuntimePerkProgression.PROGRESSIONS.duplicate(true)
	var values: Array = (((corrupted["dash_acceleration"] as Dictionary)["lanes"] as Dictionary)["vertical_scale_bonus"] as Dictionary)["values"]
	values[2] = 999.0
	var red_count := _count_index_mismatches(corrupted)
	_expect(red_count > 0, "deliberately corrupted in-memory ceiling fixture must go RED")


func _test_real_snapshot_projection() -> void:
	var state: Object = load("res://scripts/characters/runtime_perk_state.gd").new()
	state.runtime_skill_levels["item_luck"] = 3
	state.item_perk_level_bonus = 1
	var snapshot: Dictionary = state.get_snapshot()
	var projection: Dictionary = snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	_expect(not (projection.get("entries", []) as Array).is_empty(), "real get_snapshot must carry fusion display projection for owned perks")
	_expect(int((snapshot.get("effective_runtime_skill_levels", {}) as Dictionary).get("item_luck", 0)) == 4, "real snapshot must carry item_luck effective Lv.4")
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(state.runtime_skill_levels, RuntimePerkCatalog.new(), state, snapshot)
	var projected_description := ""
	for entry_value in acquired:
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("_draw_id", entry.get("id", ""))) == "item_luck":
			projected_description = str(entry.get("description", ""))
			break
	_expect(projected_description == RuntimePerkOverflowDescriptions.generate_stats_text("item_luck", 4), "real projection branch must consume canonical Lv.4 description, got: %s" % projected_description)


func _count_index_mismatches(index: Dictionary) -> int:
	var count := 0
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		for lane_id_value in (LEGACY_LANES[perk_id] as Dictionary).keys():
			var lane_id := str(lane_id_value)
			for level in range(1, 11):
				var actual := RuntimePerkProgression.get_value_from_index(index, perk_id, lane_id, level)
				if not is_equal_approx(actual, _s3_value(perk_id, lane_id, level)):
					count += 1
	return count


func _s3_value(perk_id: String, lane_id: String, level: int) -> float:
	var values: Array = (S3_AUTHORED[perk_id] as Dictionary)[lane_id]
	if level <= values.size():
		return float(values[level - 1])
	return _legacy_value(perk_id, lane_id, level + 2)


func _ratio_contract_value(perk_id: String, lane_id: String, level: int) -> float:
	var key := "%s/%s" % [perk_id, lane_id]
	var authored: Array = (S3_AUTHORED[perk_id] as Dictionary)[lane_id]
	if STRUCTURAL_LANES.has(key):
		return float(authored[level - 1])
	var start_level := int(RATIO_START_LEVELS.get(key, 1))
	if level < start_level:
		return 0.0
	var ratio := float(RuntimePerkProgression.AUTHORED_RATIOS[level - 1])
	var ceiling := _legacy_value(perk_id, lane_id, 5)
	if LOWER_INTEGER_NEUTRALS.has(key):
		var neutral := float(LOWER_INTEGER_NEUTRALS[key])
		var rounded_improvement := _round_positive_contract((neutral - ceiling) * ratio)
		return _round_positive_contract(neutral - rounded_improvement)
	if HIGHER_INTEGER_NEUTRALS.has(key):
		var neutral := float(HIGHER_INTEGER_NEUTRALS[key])
		var rounded_improvement := _round_positive_contract((ceiling - neutral) * ratio)
		return _round_positive_contract(neutral + rounded_improvement)
	if FLOAT_RATIO_LANES.has(key):
		return ceiling * ratio
	return _round_positive_contract(ceiling * ratio)


func _round_positive_contract(value: float) -> float:
	return float(round(value + 0.000001))


func _legacy_value(perk_id: String, lane_id: String, level: int) -> float:
	var spec: Dictionary = (LEGACY_LANES[perk_id] as Dictionary)[lane_id]
	var values: Array = spec["v"]
	if level <= values.size():
		return float(values[level - 1])
	var mode := str(spec.get("m", LINEAR))
	var value := float(values[values.size() - 1])
	if mode == STAIRCASE:
		var every := int(spec.get("every", 1))
		var origin := int(spec.get("origin", values.size()))
		var steps := maxi(0, int(floor(float(level - origin) / float(every))))
		steps = mini(steps, int(spec.get("steps", steps)))
		value += float(spec.get("s", 0.0)) * float(steps)
	elif mode != HOLD:
		var step := float(spec.get("s", (float(values[-1]) - float(values[0])) / float(values.size() - 1)))
		value += step * float(level - values.size())
	if spec.has("lo"):
		value = maxf(value, float(spec["lo"]))
	if spec.has("hi"):
		value = minf(value, float(spec["hi"]))
	return value


func _candidate_id_set(candidates: Array) -> Dictionary:
	var result: Dictionary = {}
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		result[str(candidate.get("id", ""))] = true
	return result


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[str(value)] = true
	return result


func _expect_close(actual: float, expected: float, context: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s expected=%s actual=%s" % [context, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("runtime_perk_progression_equivalence_smoke FAIL: " + message)
