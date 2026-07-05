extends RefCounted

# Stage 1 boss = Dalji. Walk uses two separate baked 16-frame AutoSprite run
# sheets with full keyposes, lifted knees, and a light bounce. No runtime mirror.
const DALJI_BOSS_WALK_LEFT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_run_left_16f_fullkeypose_autosprite_v15.png"
const DALJI_BOSS_WALK_RIGHT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_run_right_16f_fullkeypose_autosprite_v15.png"
const DALJI_BOSS_IDLE_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_idle.png"
const DALJI_BOSS_ATTACK_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_attack.png"
const DALJI_BOSS_DASH_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_dash.png"
const DALJI_BOSS_VICTORY_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_victory.png"
const DALJI_BOSS_DEFEAT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_defeat.png"
const DALJI_BOSS_STUN_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_stun.png"
const DALJI_BOSS_WHIP_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_whip.png"
const DALJI_BOSS_PAENGI_TOP_WHIP_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_paengi_top_whip_32f_autosprite_v2.png"

# Stage 1 boss variant = Gaksital. Walk left is a baked cell-wise mirror of
# the front-biased right sidestep; do not runtime-flip the whole atlas.
const GAKSITAL_BOSS_WALK_LEFT_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_walk_left_front_sidestep_16f_mirrored_from_right_v3_pro.png"
const GAKSITAL_BOSS_WALK_RIGHT_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_walk_right_front_sidestep_16f_autosprite_v3_pro.png"
const GAKSITAL_BOSS_IDLE_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_idle_8f_autosprite_v1_pro.png"
const GAKSITAL_BOSS_ATTACK_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_attack_8f_autosprite_v1_pro.png"
const GAKSITAL_BOSS_DASH_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_dash_8f_autosprite_v1_pro.png"
const GAKSITAL_BOSS_STUN_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_stun_8f_autosprite_v1_pro.png"
const GAKSITAL_BOSS_VICTORY_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_victory_round_8f_autosprite_v2_pro.png"
const GAKSITAL_BOSS_DEFEAT_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_defeat_round_8f_autosprite_v2_pro.png"
const GAKSITAL_BOSS_FAN_THROW_PATH := "res://assets/sprites/stage1/gaksital/gaksital_boss_fan_throw_16f_autosprite_v1_pro.png"
const GAKSITAL_FAN_PROJECTILE_PATH := "res://assets/sprites/stage1/gaksital/gaksital_fan_projectile_imagegen_v1.png"
const GAKSITAL_FAN_WIND_SHEET_PATH := "res://assets/sprites/stage1/gaksital/gaksital_fan_wind_vortex_16f_autosprite_v1.png"

# Stage 1 boss variant = Pododaejang. The walk is one front-facing sheet used
# for both horizontal movement directions; do not runtime-mirror it.
const PODODAEJANG_BOSS_WALK_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_walk_16f_autosprite_v1_pro.png"
const PODODAEJANG_BOSS_IDLE_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_idle_8f_autosprite_v1_pro.png"
const PODODAEJANG_BOSS_ATTACK_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_attack_8f_autosprite_v1_pro.png"
const PODODAEJANG_BOSS_DASH_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_dash_8f_autosprite_v1_pro.png"
const PODODAEJANG_BOSS_STUN_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_stun_8f_autosprite_v1_pro.png"
const PODODAEJANG_BOSS_VICTORY_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_victory_8f_autosprite_v1_pro.png"
const PODODAEJANG_BOSS_DEFEAT_PATH := "res://assets/sprites/stage1/pododaejang/pododaejang_boss_defeat_8f_autosprite_v1_pro.png"
const PODODAEJANG_POJOL_PATROL_WALK_PATH := "res://assets/sprites/stage1/pojol/pojol_patrol_walk_8f_autosprite_v1_pro.png"

const STAGE2_BOSS_WALK_LEFT_PATH := "res://assets/sprites/stage2/stage2_boss_run_left_angled_autosprite_v1_16f.png"
const STAGE2_BOSS_WALK_RIGHT_PATH := "res://assets/sprites/stage2/stage2_boss_run_right_angled_autosprite_v1_16f.png"
const STAGE2_BOSS_IDLE_PATH := "res://assets/sprites/stage2/stage2_boss_idle_combat_breath_autosprite_v2_8f.png"
const STAGE2_BOSS_ATTACK_PATH := "res://assets/sprites/stage2/stage2_boss_attack_front_paddle_autosprite_v1_16f.png"
const STAGE2_BOSS_QUAKE_STOMP_PATH := "res://assets/sprites/stage2/stage2_boss_jungle_quake_stomp_autosprite_v1_16f.png"
const STAGE2_BOSS_VICTORY_PATH := "res://assets/sprites/stage2/stage2_boss_victory_hop_autosprite_v1_64f.png"
const STAGE2_BOSS_DEFEAT_PATH := "res://assets/sprites/stage2/stage2_boss_defeat_collapse_autosprite_v1_64f.png"

const STAGE3_MENHERA_BOSS_WALK_PATH := "res://assets/sprites/stage3/menhera_boss_sheet.png"
const STAGE3_MENHERA_BOSS_ATTACK_PATH := "res://assets/sprites/stage3/menhera_boss_attack.png"
const STAGE3_MENHERA_BOSS_DASH_PATH := "res://assets/sprites/stage3/menhera_boss_dash.png"
const STAGE3_MENHERA_BOSS_VICTORY_PATH := "res://assets/sprites/stage3/menhera_boss_victory.png"
const STAGE3_MENHERA_BOSS_DEFEAT_PATH := "res://assets/sprites/stage3/menhera_boss_defeat.png"

const STAGE4_PONK_BOSS_VICTORY_PATH := "res://assets/sprites/stage4/stage4_ponk_boss_victory.png"

const STAGE5_HONGRYUN_BOSS_SHEET_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_sheet.png"
const STAGE5_HONGRYUN_BOSS_ATTACK_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_attack.png"
const STAGE5_HONGRYUN_BOSS_DASH_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_dash.png"
const STAGE5_HONGRYUN_BOSS_TURN_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_turn.png"
const STAGE5_HONGRYUN_BOSS_VICTORY_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_victory.png"

const STAGE6_TETRISER_BOSS_VICTORY_PATH := "res://assets/sprites/bosses/stage6_tetriser/stage6_tetriser_boss_victory_4x2.png"
