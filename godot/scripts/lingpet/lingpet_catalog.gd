extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_PET_ID := "maribo"
const REQUIRED_STAT_KEYS := [
	"patrol_speed_default",
	"patrol_speed_min",
	"patrol_speed_max",
	"catch_width",
	"catch_height",
	"defense_rate",
	"hit_gauge_gain",
	"gauge_gain_bonus_pct",
]
const REQUIRED_VISUAL_KEYS := [
	"egg",
	"egg_crack_1",
	"egg_crack_2",
	"companion_walk",
	"companion_strike",
	"companion_cast",
	"cutin_art",
	"cutin_anim",
	"cutin_dismiss_anim",
	"click_reaction_anim",
]
const REQUIRED_ACTIVE_SKILL_KEYS := [
	"id",
	"runtime_kind",
	"name",
	"description",
	"cooldown",
	"card_texture_path",
]
const REQUIRED_PASSIVE_SKILL_KEYS := [
	"id",
	"name",
	"description",
]

const SKILL_LEVEL_MIN := 1
const SKILL_LEVEL_MAX := 5
const DEFAULT_ACTIVE_SKILL_LEVEL := 1
const DEFAULT_PASSIVE_SKILL_LEVEL := 1
const DEFAULT_ACTIVE_SLOT_COUNT := 1
const MAX_ACTIVE_SLOT_COUNT := 2
const DEFAULT_PASSIVE_SLOT_COUNT := 1
const MAX_PASSIVE_SLOT_COUNT := 2
const DEFAULT_ACTIVE_SKILL_SENTINEL := "__default_active_skill__"
const ACTIVE_COOLDOWN_REDUCTION_PCT_BY_LEVEL := [0.0, 3.0, 6.0, 9.0, 12.0]
const ACTIVE_WINDUP_REDUCTION_PCT_BY_LEVEL := [0.0, 2.0, 4.0, 6.0, 8.0]
const LEGACY_PASSIVE_ID_ALIASES := {
	"gauge_gain_bonus": "lingpet_resonance_boost",
	"maribo_resonance_boost": "lingpet_resonance_boost",
	"milkring_lactose_charge": "lingpet_resonance_boost",
	"lumion_circuit_resonance": "lingpet_resonance_boost",
	"red_dragon_core_resonance": "lingpet_resonance_boost",
	"lingpet_guard_instinct": "lingpet_afterglow_leak",
	"lingpet_direct_charge": "lingpet_afterglow_leak",
	"lingpet_swift_patrol": "lingpet_afterglow_leak",
	"lingpet_broad_guard": "lingpet_afterglow_leak",
	"lingpet_quick_cycle": "lingpet_afterglow_leak",
	"lingpet_fast_cast": "lingpet_afterglow_leak",
	"lingpet_focus_link": "lingpet_afterglow_leak",
	"lingpet_steady_body": "lingpet_afterglow_leak",
	"lingpet_intercept_rhythm": "lingpet_afterglow_leak",
}
const COMMON_PASSIVE_SKILL_POOL := [
	{
		"id": "lingpet_resonance_boost",
		"name": "공명 증폭",
		"description": "플레이어가 공을 받아칠 때 링펫 게이지 획득량이 증가합니다.",
		"icon_texture_path": "res://assets/sprites/lingpet/maribo_resonance_boost_passive_icon_imagegen_v1.png",
		"category": "게이지 증폭",
		"gauge_gain_bonus_pct_by_level": [4.0, 7.0, 10.0, 13.0, 16.0],
	},
	{
		"id": "lingpet_afterglow_leak",
		"name": "잔광 유출",
		"description": "링펫이 공을 받아칠 때 빛나는 공명 유체를 흘립니다. 플레이어 패들이 가까이 가면 유체를 흡수해 게이지를 빠르게 얻고, 시간이 지나면 바닥으로 스며들어 사라집니다.",
		"icon_texture_path": "res://assets/sprites/lingpet/lingpet_afterglow_leak_passive_icon_imagegen_v1.png",
		"category": "게이지 회수 / 필드 잔류물",
		"afterglow_total_gauge_by_level": [20.0, 40.0, 60.0, 80.0, 100.0],
		"afterglow_duration_seconds_by_level": [2.4, 2.6, 2.8, 3.0, 3.2],
		"afterglow_absorb_radius_by_level": [52.0, 56.0, 60.0, 64.0, 68.0],
		"afterglow_tick_count": 6,
	},
	{
		"id": "lingpet_tailwind_steps",
		"name": "순풍 발산",
		"description": "링펫이 순풍의 기운을 발산해 플레이어의 이동 속도가 증가합니다.",
		"icon_texture_path": "res://assets/sprites/lingpet/lingpet_tailwind_steps_passive_icon_imagegen_v1.png",
		"category": "이동 속도",
		"player_speed_bonus_pct_by_level": [4.0, 7.0, 10.0, 13.0, 16.0],
	},
	{
		"id": "lingpet_starlight_tracking",
		"name": "별빛 추적",
		"description": "스타포인트가 드랍될 때 일정 확률로 링펫이 별빛을 추적해 달려가고, 주운 뒤 잠깐 머뭇거리다가 플레이어에게 가져다주면 보상을 획득합니다.",
		"icon_texture_path": "res://assets/sprites/lingpet/lingpet_starlight_tracking_passive_icon_imagegen_v1.png",
		"category": "보상 회수",
		"starpoint_tracking_chance_pct_by_level": [20.0, 30.0, 40.0, 50.0, 60.0],
		"starpoint_tracking_chase_speed_by_level": [420.0, 470.0, 520.0, 570.0, 640.0],
		"starpoint_tracking_collect_radius_by_level": [24.0, 27.0, 30.0, 33.0, 36.0],
	},
	{
		"id": "lingpet_ring_dash",
		"name": "링크포트",
		"description": "플레이어가 받기 어려운 공이 내려오고 링펫도 멀리 떨어져 있을 때, 일정 확률로 링펫이 잠깐 사라졌다가 공 앞에 재등장해 막아냅니다.",
		"icon_texture_path": "res://assets/sprites/lingpet/lingpet_ring_dash_passive_icon_imagegen_v1.png",
		"category": "긴급 수비",
		"ring_dash_chance_pct_by_level": [25.0, 32.5, 40.0, 47.5, 55.0],
		"ring_dash_reappear_delay_seconds_by_level": [0.080, 0.070, 0.060, 0.050, 0.040],
		"ring_dash_cooldown_seconds_by_level": [13.0, 12.0, 11.0, 10.0, 9.0],
		"ring_dash_min_distance_by_level": [150.0, 138.0, 126.0, 114.0, 102.0],
		"ring_dash_lookahead_gap_by_level": [72.0, 84.0, 96.0, 108.0, 120.0],
	},
]

const PETS := {
	"maribo": {
		"id": "maribo",
		"display_name": "마리보",
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 120.0,
			"patrol_speed_min": 70.0,
			"patrol_speed_max": 135.0,
			"catch_width": 100.0,
			"catch_height": 44.0,
			"defense_rate": 0.30,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/maribo_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/maribo_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/maribo_companion_hydro_cast.png",
			"cutin_art": "res://assets/sprites/lingpet/maribo_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/maribo_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/maribo_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/maribo_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/maribo_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"companion_walk_draw_size": 104.0,
		},
		"active_skill": {
			"id": "maribo_hydro_sphere",
			"runtime_kind": "hydro_sphere",
			"name": "하이드로 스피어",
			"description": "물의 기운이 담긴 창을 던집니다. 상대 진영 벽에 닿으면 5초 동안 가로로 넓은 물장판을 만듭니다.",
			"cooldown": 40.0,
			"windup_seconds": 1.0,
			"card_texture_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png",
			"icon_texture_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "maribo_hydro_sphere",
				"runtime_kind": "hydro_sphere",
				"name": "하이드로 스피어",
				"description": "물의 기운이 담긴 창을 던집니다. 상대 진영 벽에 닿으면 5초 동안 가로로 넓은 물장판을 만듭니다.",
				"cooldown": 40.0,
				"windup_seconds": 1.0,
				"card_texture_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png",
				"icon_texture_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skill_icon_imagegen_v1.png",
			},
			{
				"id": "maribo_bubble_trap",
				"runtime_kind": "bubble_trap",
				"name": "물방울트랩",
				"description": "천천히 앞으로 전진하는 물방울을 발사합니다. 상대 패들이 닿으면 2.5~3초 동안 물방울에 갇혀 움직일 수 없고, 물방울은 좌우로 떠다닙니다. 공에 닿으면 즉시 터집니다.",
				"cooldown": 25.0,
				"windup_seconds": 0.75,
				"card_texture_path": "res://assets/sprites/lingpet/maribo_bubble_trap_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/maribo_bubble_trap_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "링펫이 공을 직접 튕기면 게이지 +40 / 하이드로 스피어 또는 물방울트랩 중 획득 시 선택된 액티브를 자동 사용합니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
	},
	"lunabi": {
		"id": "lunabi",
		"display_name": "달벳",
		"motion_style": "sortie_flight",
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 285.0,
			"patrol_speed_min": 210.0,
			"patrol_speed_max": 390.0,
			"catch_width": 88.0,
			"catch_height": 58.0,
			"defense_rate": 0.0,
			# Flight-style lingpet: appearance_rate (출현율) shortens the hidden wait
			# between vanish and reappear. Defense is patrol-only so defense_rate stays 0.
			"appearance_rate": 0.30,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/lunabi_companion_wing_flap.png",
			"companion_strike": "res://assets/sprites/lingpet/lunabi_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/lunabi_companion_strike.png",
			"cutin_art": "res://assets/sprites/lingpet/lunabi_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/lunabi_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/lunabi_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/lunabi_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/lunabi_companion_click_reaction_98f.png",
		},
		"active_skill": {
			"id": "lunabi_headbutt",
			"runtime_kind": "headbutt",
			"name": "박치기",
			"description": "달벳이 상대 패들을 향해 돌진해 밀쳐냅니다. 레벨이 오를수록 넉백 거리가 10~40% 늘어나고, Lv.3부터 박치기를 2회, Lv.5부터 3회 연속으로 먹입니다. Lv.3부터는 20% 확률로 2초간 기를 모아 단일 메가박치기(넉백 +30%·1초 기절)를 날리고, Lv.5에서는 25% 확률·넉백 +50%·1.5초 기절로 강화됩니다. 상대가 이동 중이면 빗나갈 수 있습니다.",
			"cooldown": 30.0,
			"windup_seconds": 0.45,
			"knockback_scale_by_level": [1.10, 1.175, 1.25, 1.325, 1.40],
			"headbutt_count_by_level": [1, 1, 2, 2, 3],
			"mega_chance_by_level": [0.0, 0.0, 0.20, 0.20, 0.25],
			"mega_knockback_bonus_pct_by_level": [0.0, 0.0, 0.30, 0.30, 0.50],
			"mega_stun_seconds_by_level": [0.0, 0.0, 1.0, 1.0, 1.5],
			"card_texture_path": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/lunabi_headbutt_skill_icon_imagegen_v1.png",
		},
		"effect_text": "전장 전체를 자유비행합니다. 가끔 화면 밖으로 사라졌다가 다시 들어오며, 공과 겹치면 날개로 받아칩니다. 박치기: 30초마다 상대 패들에 돌진해 넉백시키며, 레벨이 오를수록 넉백 거리(+10~40%)와 연속 박치기 횟수(Lv.3 2회·Lv.5 3회)가 늘어납니다. Lv.3부터 일정 확률로 기를 모은 메가박치기(강한 넉백+기절)가 발동합니다.",
	},
	"milkring": {
		"id": "milkring",
		"display_name": "밀쿠",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 124.0,
			"patrol_speed_min": 76.0,
			"patrol_speed_max": 144.0,
			"catch_width": 98.0,
			"catch_height": 48.0,
			"defense_rate": 0.24,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/milkring_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/milkring_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/milkring_milk_production_autosprite_25f.png",
			"cutin_art": "res://assets/sprites/lingpet/milkring_futuristic_milk_blaster_concept_imagegen_v5.png",
			"cutin_anim": "res://assets/sprites/lingpet/milkring_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/milkring_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/milkring_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/milkring_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"companion_walk_draw_size": 104.0,
			"companion_strike_draw_size": 104.0,
			"companion_cast_draw_size": 104.0,
		},
		"active_skill": {
			"id": "milkring_milk_production",
			"runtime_kind": "milk_production",
			"name": "우유생산",
			"description": "밀쿠가 3초 동안 우유병을 제조합니다. 우유병은 스킬 레벨에 따라 플레이어 패들과 이미지 크기를 12~20% 키우며, Lv.3부터는 생산마다 30% 확률로 우유병 대신 게이지구슬을 회복하는 치즈가 나옵니다.",
			"cooldown": 50.0,
			"cooldown_by_level": [50.0, 47.0, 44.0, 41.0, 37.0],
			"windup_seconds": 3.0,
			"paddle_scale_multiplier_by_level": [1.12, 1.14, 1.16, 1.18, 1.20],
			"cheese_chance_by_level": [0.0, 0.0, 0.30, 0.30, 0.30],
			"card_texture_path": "res://assets/sprites/lingpet/milkring_milk_production_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/milkring_milk_production_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "milkring_milk_production",
				"runtime_kind": "milk_production",
				"name": "우유생산",
				"description": "밀쿠가 3초 동안 우유병을 제조합니다. 우유병은 스킬 레벨에 따라 플레이어 패들과 이미지 크기를 12~20% 키우며, Lv.3부터는 생산마다 30% 확률로 우유병 대신 게이지구슬을 회복하는 치즈가 나옵니다.",
				"cooldown": 50.0,
				"cooldown_by_level": [50.0, 47.0, 44.0, 41.0, 37.0],
				"windup_seconds": 3.0,
				"paddle_scale_multiplier_by_level": [1.12, 1.14, 1.16, 1.18, 1.20],
				"cheese_chance_by_level": [0.0, 0.0, 0.30, 0.30, 0.30],
				"card_texture_path": "res://assets/sprites/lingpet/milkring_milk_production_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/milkring_milk_production_skill_icon_imagegen_v1.png",
			},
			{
				"id": "milkring_milk_shot",
				"runtime_kind": "milk_shot",
				"name": "우유발사",
				"description": "밀쿠가 보스를 향해 빠른 우유 투사체를 연속 발사합니다. 맞은 보스는 스킬 레벨에 따라 0.5~1.0초 기절하고, Lv.1~5에서 코만도 권총 기준 넉백 8~16을 받습니다. Lv.3부터는 발사마다 30% 확률로 일반 사격 대신 메가 우유 난사가 나갑니다.",
				"cooldown": 30.0,
				"cooldown_by_level": [30.0, 27.5, 25.0, 22.5, 20.0],
				"windup_seconds": 0.0,
				"stun_duration_seconds_by_level": [0.3, 0.4, 0.5, 0.6, 0.7],
				"knockback_power_by_level": [8.0, 10.0, 12.0, 14.0, 16.0],
				"projectile_count_by_level": [8, 8, 10, 10, 12],
				"fire_duration_seconds_by_level": [0.8, 0.92, 1.05, 1.18, 1.3],
				"mega_chance_by_level": [0.0, 0.0, 0.30, 0.30, 0.30],
				"mega_projectile_count_by_level": [0, 0, 30, 40, 50],
				"mega_duration_seconds_by_level": [0.0, 0.0, 1.0, 1.25, 1.5],
				"card_texture_path": "res://assets/sprites/lingpet/milkring_milk_shot_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/milkring_milk_shot_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 우유생산은 50/47/44/41/37초마다 우유병을 제조하고, 우유발사는 30/27.5/25/22.5/20초마다 보스를 향해 우유 투사체를 발사합니다. 우유발사 Lv.3부터는 30% 확률로 메가 우유 난사가 나갑니다.",
		"concept_art_path": "res://assets/sprites/lingpet/milkring_futuristic_milk_blaster_concept_imagegen_v5.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/milkring_futuristic_milk_blaster_concept_imagegen_v5_magenta_source.png",
		"note": "Milkring has two active skill candidates: Milk Production uses the milk_production runtime, and Milk Shot uses the milk_shot projectile runtime.",
	},
	"volty": {
		"id": "volty",
		"display_name": "볼탄",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 162.0,
			"patrol_speed_min": 108.0,
			"patrol_speed_max": 216.0,
			"catch_width": 94.0,
			"catch_height": 48.0,
			"defense_rate": 0.16,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/volty_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/volty_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/volty_companion_strike.png",
			"cutin_art": "res://assets/sprites/lingpet/volty_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/volty_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/volty_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/volty_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/volty_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"companion_walk_draw_size": 104.0,
			"companion_strike_draw_size": 104.0,
			"companion_cast_draw_size": 104.0,
		},
		"active_skill": {
			"id": "volty_bomb_surprise",
			"runtime_kind": "bomb_surprise",
			"name": "폭탄 서프라이즈",
			"description": "볼탄이 시한폭탄을 공에 부착합니다. 폭탄은 공과 패들 사이를 오가다가 폭발하며, 플레이어 쪽에서는 약한 스턴과 넉백, 상대 쪽에서는 강한 스턴과 넉백을 일으킵니다.",
			"cooldown": 60.0,
			"windup_seconds": 0.45,
			"card_texture_path": "res://assets/sprites/lingpet/volty_bomb_surprise_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/volty_bomb_surprise_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "volty_bomb_surprise",
				"runtime_kind": "bomb_surprise",
				"name": "폭탄 서프라이즈",
				"description": "볼탄이 시한 폭탄을 공에 부착합니다. 폭탄은 공과 양쪽 패들 사이를 오가며, 플레이어 쪽에서는 약한 스턴과 넉백, 상대 쪽에서는 강한 스턴과 넉백을 일으킵니다.",
				"cooldown": 60.0,
				"windup_seconds": 0.45,
				"card_texture_path": "res://assets/sprites/lingpet/volty_bomb_surprise_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/volty_bomb_surprise_skill_icon_imagegen_v1.png",
			},
			{
				"id": "volty_gatling_burst",
				"runtime_kind": "gatling_burst",
				"name": "개틀링 버스트",
				"description": "볼탄이 개틀링 탱크로 변신해 1초 동안 전개한 뒤 3초 동안 상대를 향해 난사합니다. 맞은 대상은 코만도 AK-47과 같은 짧은 스턴과 넉백을 받습니다.",
				"cooldown": 50.0,
				"windup_seconds": 0.0,
				"card_texture_path": "res://assets/sprites/lingpet/volty_gatling_burst_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/volty_gatling_burst_skill_icon.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 폭탄 서프라이즈는 60초마다 공에 시한폭탄을 붙여 상대 쪽 폭발 시 강한 스턴+넉백, 플레이어 쪽 폭발 시 약한 스턴+넉백을 일으킵니다.",
		"concept_art_path": "res://assets/sprites/lingpet/volty_cutin_art.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/volty_cutin_art_magenta_source.png",
		"note": "Volty Bomb Surprise ports the original Android bomb-surprise ball attachment and side-based weak/strong stun plus knockback behavior to the lingpet runtime.",
	},
	"lumion": {
		"id": "lumion",
		"display_name": "루미온",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 132.0,
			"patrol_speed_min": 82.0,
			"patrol_speed_max": 156.0,
			"catch_width": 96.0,
			"catch_height": 48.0,
			"defense_rate": 0.26,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/lumion_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/lumion_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/lumion_companion_strike.png",
			"cutin_art": "res://assets/sprites/lingpet/lumion_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/lumion_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/lumion_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/lumion_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/lumion_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.68,
			"cutin_dismiss_view_h_ratio": 0.68,
			"click_reaction_draw_size": 83.2,
			"companion_walk_draw_size": 104.0,
			"companion_strike_draw_size": 104.0,
			"companion_cast_draw_size": 104.0,
		},
		"active_skill": {
			"id": "lumion_thunder_orb",
			"runtime_kind": "thunder_orb",
			"name": "천둥 뇌구",
			"description": "루미온이 일직선 번개 구체를 발사합니다. 뇌구는 처음 빠르게 날아간 뒤 점점 느려지고, 상대 진영에서 폭발해 전기 스파크에 닿은 보스를 감전시킵니다. Lv.3부터는 감전이 풀린 뒤 폭발 자리 주변에 미니 스파크가 0.3초 간격으로 튀어(Lv.3=3·Lv.4=4·Lv.5=5회), 근처에 남은 보스가 닿으면 0.5초 추가 감전됩니다.",
			"cooldown": 25.0,
			"windup_seconds": 0.55,
			"stun_duration_seconds": 1.4,
			"stun_duration_seconds_by_level": [0.8, 1.0, 1.2, 1.4, 1.6],
			"explosion_radius": 170.0,
			"explosion_radius_by_level": [136.0, 144.5, 153.0, 161.5, 170.0],
			"card_texture_path": "res://assets/sprites/lingpet/lumion_thunder_orb_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/lumion_thunder_orb_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "lumion_thunder_orb",
				"runtime_kind": "thunder_orb",
				"name": "천둥 뇌구",
				"description": "루미온이 일직선 번개 구체를 발사합니다. 뇌구는 처음 빠르게 날아간 뒤 점점 느려지고, 상대 진영에서 폭발해 전기 스파크에 닿은 보스를 감전시킵니다. Lv.3부터는 감전이 풀린 뒤 폭발 자리 주변에 미니 스파크가 0.3초 간격으로 튀어(Lv.3=3·Lv.4=4·Lv.5=5회), 근처에 남은 보스가 닿으면 0.5초 추가 감전됩니다.",
				"cooldown": 25.0,
				"windup_seconds": 0.55,
				"stun_duration_seconds": 1.4,
				"stun_duration_seconds_by_level": [0.8, 1.0, 1.2, 1.4, 1.6],
				"explosion_radius": 170.0,
				"explosion_radius_by_level": [136.0, 144.5, 153.0, 161.5, 170.0],
				"card_texture_path": "res://assets/sprites/lingpet/lumion_thunder_orb_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/lumion_thunder_orb_skill_icon_imagegen_v1.png",
			},
			{
				"id": "lumion_solar_bolt",
				"runtime_kind": "solar_bolt",
				"name": "천둥 낙뢰",
				"description": "하강하는 공이 플레이어가 막기 어려운 궤도에 들어오면 루미온이 낙뢰를 내려 공을 보스 쪽으로 되받아칩니다. 속도는 보존되며, Lv.3부터 후속 낙뢰가 발동할 수 있습니다.",
				"cooldown": 22.0,
				"windup_seconds": 0.0,
				"refire_chance_pct": 50.0,
				"card_texture_path": "res://assets/sprites/lingpet/lumion_solar_bolt_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/lumion_solar_bolt_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 천둥 뇌구는 25초마다 일직선으로 발사되어 상대 진영에서 폭발하고 닿은 보스를 0.8~1.6초(레벨별) 감전시킵니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
		"concept_art_path": "res://assets/sprites/lingpet/lumion_cutin_art.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/lumion_cutin_art_magenta_source.png",
		"note": "Lumion companion visuals and Thunder Orb skill card/icon are live. Dedicated egg art is still pending; the active-skill runtime is wired with Horus-style straight-line deceleration, explosion, and electric stun.",
	},
	"orbi": {
		"id": "orbi",
		"display_name": "세라비",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 176.0,
			"patrol_speed_min": 118.0,
			"patrol_speed_max": 228.0,
			"catch_width": 88.0,
			"catch_height": 50.0,
			"defense_rate": 0.14,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/orbi_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/orbi_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/orbi_companion_strike.png",
			"cutin_art": "res://assets/sprites/lingpet/orbi_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/orbi_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/orbi_cutin_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/orbi_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/orbi_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"companion_walk_draw_size": 104.0,
			"companion_strike_draw_size": 104.0,
			"companion_cast_draw_size": 104.0,
		},
		"active_skill": {
			"id": "orbi_ring_orbit",
			"runtime_kind": "moon_orbit",
			"name": "링 오비트",
			"description": "세라비가 푸른 링 궤도를 전개합니다. 상대 진영 벽에 닿으면 4초 동안 가로로 넓은 둔화장을 만듭니다.",
			"cooldown": 36.0,
			"windup_seconds": 0.8,
			"card_texture_path": "res://assets/sprites/lingpet/orbi_ring_orbit_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/orbi_ring_orbit_skill_icon_imagegen_v1.png",
		},
		"effect_text": "공을 직접 받아치면 게이지 +40 / 링 오비트는 36초마다 푸른 링 궤도를 쏘아 상대 진영에 4초 둔화장을 만듭니다.",
		"concept_art_path": "res://assets/sprites/lingpet/orbi_cutin_art.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/orbi_cutin_art_magenta_source.png",
		"note": "Serabi companion/cut-in/click visuals and Ring Orbit skill card/icon are live. Dedicated egg, cast sheet, dismiss sheet, and custom skill runtime are still pending; catalog temporarily reuses the shared egg, strike art for cast, cut-in animation for dismiss, and the supported moon_orbit runtime.",
	},
	"red_dragon": {
		"id": "red_dragon",
		"display_name": "파루키라스",
		"motion_style": "sortie_flight",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 168.0,
			"patrol_speed_min": 112.0,
			"patrol_speed_max": 224.0,
			"catch_width": 92.0,
			"catch_height": 50.0,
			# Flight-style lingpet (sortie_flight): defense intercept is patrol-only, so
			# this stays 0 — a nonzero value would be dead data that only misleads the UI.
			"defense_rate": 0.0,
			# appearance_rate (출현율) shortens the hidden wait between sorties.
			"appearance_rate": 0.30,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/red_dragon_companion_wing_flap.png",
			"companion_strike": "res://assets/sprites/lingpet/red_dragon_companion_wing_flap.png",
			"companion_cast": "res://assets/sprites/lingpet/red_dragon_companion_wing_flap.png",
			"cutin_art": "res://assets/sprites/lingpet/red_dragon_lingpet_live2d_front_redesign_imagegen_v6.png",
			"cutin_anim": "res://assets/sprites/lingpet/red_dragon_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/red_dragon_cutin_dismiss_anim.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/red_dragon_lingpet_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/red_dragon_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"companion_walk_draw_size": 83.2,
			"companion_strike_draw_size": 83.2,
			"companion_cast_draw_size": 83.2,
			"companion_wing_flap_max_speed_ratio": 0.55,
			"cutin_anim_view_h_ratio": 0.568,
			"cutin_dismiss_view_h_ratio": 0.568,
			"click_reaction_draw_size": 64.0,
		},
		"active_skill": {
			"id": "red_dragon_dragon_breath",
			"runtime_kind": "dragon_breath",
			"name": "드래곤 브레스",
			"description": "파루키라스가 용의 화염을 뿜어 공을 타격하고 가속시킵니다. 사라진 불꽃은 짧은 화염 지대를 남겨 보스를 둔화시키고 바깥으로 밀어냅니다.",
			"cooldown": 40.0,
			"windup_seconds": 0.65,
			"card_texture_path": "res://assets/sprites/lingpet/red_dragon_dragon_breath_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/red_dragon_dragon_breath_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "red_dragon_dragon_breath",
				"runtime_kind": "dragon_breath",
				"name": "드래곤 브레스",
				"description": "파루키라스가 용의 화염을 뿜어 공을 타격하고 가속시킵니다. 사라진 불꽃은 짧은 화염 지대를 남겨 보스를 둔화시키고 바깥으로 밀어냅니다.",
				"cooldown": 40.0,
				"windup_seconds": 0.65,
				"card_texture_path": "res://assets/sprites/lingpet/red_dragon_dragon_breath_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/red_dragon_dragon_breath_skill_icon_imagegen_v1.png",
			},
			{
				"id": "red_dragon_dragon_wing",
				"runtime_kind": "dragon_wing",
				"name": "용의 날개",
				"description": "파루키라스가 거대한 날갯짓으로 2.5초 동안 좌우 횡풍과 완만한 상승풍을 일으킵니다. 공은 회오리에 감긴 듯 빙글빙글 휩쓸리며 보스 쪽으로 떠밀려 가고, 날아가는 용 그림자가 닿으면 보스 방향으로 되받아칩니다.",
				"cooldown": 15.0,
				"windup_seconds": 0.45,
				"card_texture_path": "res://assets/sprites/lingpet/red_dragon_dragon_wing_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/red_dragon_dragon_wing_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 획득 시 드래곤 브레스 또는 용의 날개 중 하나를 액티브 스킬로 얻습니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
		"concept_art_path": "res://assets/sprites/lingpet/red_dragon_lingpet_live2d_front_redesign_imagegen_v6.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/red_dragon_lingpet_live2d_front_redesign_imagegen_v6_magenta_source.png",
		"companion_sd_source_path": "res://assets/sprites/lingpet/red_dragon_companion_sd_back.png",
		"note": "Red Dragon has a dedicated rear-three-quarter SD wing-flap sheet for sortie_flight movement, acquisition cut-in/dismiss sheets, a dedicated click_reaction_anim, and Dragon Breath / Dragon Wing active runtimes ported from the original Ignis hero skill kit.",
	},
	"koyora": {
		"id": "koyora",
		"display_name": "코요라",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 168.0,
			"patrol_speed_min": 108.0,
			"patrol_speed_max": 222.0,
			"catch_width": 88.0,
			"catch_height": 52.0,
			"defense_rate": 0.16,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_idle": "res://assets/sprites/lingpet/koyora_companion_idle.png",
			"companion_move_left": "res://assets/sprites/lingpet/koyora_companion_move_left.png",
			"companion_move_right": "res://assets/sprites/lingpet/koyora_companion_move_right.png",
			"companion_walk": "res://assets/sprites/lingpet/koyora_companion_move_right.png",
			"companion_strike": "res://assets/sprites/lingpet/koyora_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/koyora_companion_idle.png",
			"companion_puppet_control": "res://assets/sprites/lingpet/koyora_puppet_control_cast.png",
			"cutin_art": "res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png",
			"cutin_anim": "res://assets/sprites/lingpet/koyora_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/koyora_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/koyora_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.62,
			"cutin_dismiss_view_h_ratio": 0.56,
			"cutin_dismiss_seconds": 4.25,
			"cutin_dismiss_action_portion": 0.86,
			"cutin_dismiss_fade_start": 0.70,
			"click_reaction_draw_size": 84.0,
			"companion_walk_draw_size": 92.0,
			"companion_strike_draw_size": 92.0,
			"companion_cast_draw_size": 92.0,
			"companion_puppet_control_draw_size": 112.0,
		},
		"active_skill": {
			"id": "koyora_puppet_control",
			"runtime_kind": "puppet_grab",
			"name": "꼭두각시 조종",
			"description": "분홍 인형실을 빠르게 던져 락온된 보스를 코요라 앞까지 끌어당겨 뽀뽀한 뒤 제자리로 돌려놓습니다. 조종 중 줄이 공에 닿으면 줄이 끊기고 보스가 즉시 원래 위치로 되돌아갑니다. 줄이 도착하기 전에 보스가 락온 지점을 벗어나면 MISS. Lv.3부터 MISS 시 50% 확률로 0.5초 뒤 1회 재발사하고, Lv.5에서는 이 재시도를 최대 2회까지 이어갑니다.",
			"cooldown": 25.0,
			"windup_seconds": 0.8,
			"card_texture_path": "res://assets/sprites/lingpet/koyora_puppet_control_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/koyora_puppet_control_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "koyora_puppet_control",
				"runtime_kind": "puppet_grab",
				"name": "꼭두각시 조종",
				"description": "분홍 인형실을 빠르게 던져 락온된 보스를 코요라 앞까지 끌어당겨 뽀뽀한 뒤 제자리로 돌려놓습니다. 조종 중 줄이 공에 닿으면 줄이 끊기고 보스가 즉시 원래 위치로 되돌아갑니다. 줄이 도착하기 전에 보스가 락온 지점을 벗어나면 MISS. Lv.3부터 MISS 시 50% 확률로 0.5초 뒤 1회 재발사하고, Lv.5에서는 이 재시도를 최대 2회까지 이어갑니다.",
				"cooldown": 25.0,
				"windup_seconds": 0.8,
				"card_texture_path": "res://assets/sprites/lingpet/koyora_puppet_control_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/koyora_puppet_control_skill_icon_imagegen_v1.png",
			},
			{
				"id": "koyora_doll_curse",
				"runtime_kind": "doll_curse",
				"name": "인형의 저주",
				"description": "코요라가 플레이어 쪽 좌우에 줄에 묶인 목각 저주 인형을 내려보냅니다. 인형은 등대처럼 흔들리는 빛을 위로 쏘며, 빛은 Lv.1~5에 따라 35~95% 확률로 보스를 유도하고 고레벨일수록 더 집중적으로 비춥니다. 빛에 닿고 있는 동안만 보스가 혼란에 빠집니다. 하강하는 공이 인형에 맞으면 공은 위로 튕기고 해당 인형은 파괴됩니다.",
				"cooldown": 30.0,
				"windup_seconds": 0.5,
				"beam_homing_chance_pct_by_level": [35.0, 50.0, 65.0, 80.0, 95.0],
				"card_texture_path": "res://assets/sprites/lingpet/koyora_doll_curse_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/koyora_doll_curse_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 획득 시 꼭두각시 조종 또는 인형의 저주 중 하나를 액티브 스킬로 얻습니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
		"concept_art_path": "res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/puppet_miko_ringpet_cutin_art_imagegen_v3_magenta_source.png",
		"note": "Koyora is a live hatch-pool pet sharing the common resonance egg art. Puppet Control and Doll Curse now use dedicated skill-card/icon art. Acquisition cut-in uses the 4x4 / 16-frame AutoSprite sheet; acquisition click-dismiss and character-info click use the full 14x7 / 98-frame click Live2D sheet; in-battle companion click uses the downscaled 14x7 / 98-frame 128px companion sheet. In-game SD companion rendering uses dedicated rear-view idle, move-left, move-right, and strike 5x5 / 25-frame sheets.",
	},
	"nekuring": {
		"id": "nekuring",
		"display_name": "네쿠링",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 150.0,
			"patrol_speed_min": 96.0,
			"patrol_speed_max": 204.0,
			"catch_width": 88.0,
			"catch_height": 52.0,
			"defense_rate": 0.14,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_idle": "res://assets/sprites/lingpet/nekuring_companion_idle.png",
			"companion_move_left": "res://assets/sprites/lingpet/nekuring_companion_move_left.png",
			"companion_move_right": "res://assets/sprites/lingpet/nekuring_companion_move_right.png",
			"companion_walk": "res://assets/sprites/lingpet/nekuring_companion_idle.png",
			"companion_strike": "res://assets/sprites/lingpet/nekuring_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/nekuring_companion_idle.png",
			"cutin_art": "res://assets/sprites/lingpet/nekuring_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/nekuring_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/nekuring_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/nekuring_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.56,
			"cutin_dismiss_view_h_ratio": 0.56,
			"cutin_dismiss_seconds": 3.75,
			"cutin_dismiss_action_portion": 0.90,
			"cutin_dismiss_fade_start": 0.82,
			"click_reaction_draw_size": 73.6,
			"companion_walk_draw_size": 92.0,
			"companion_strike_draw_size": 92.0,
			"companion_cast_draw_size": 92.0,
		},
		"active_skill": {
			"id": "nekuring_skeleton_archer",
			"runtime_kind": "skeleton_archer",
			"name": "해골궁수",
			"description": "네쿠링이 플레이어 진영에 해골 궁수를 불러냅니다. 레벨이 오를수록 화살 발사 간격이 짧아지며, Lv.3부터 황금 궁수가 나타나 3발을 동시에 쏠 수 있습니다. Lv.5는 30% 확률로 궁수 2마리를 소환합니다.",
			"cooldown": 11.7,
			"windup_seconds": 0.45,
			"arrow_draw_time_by_level": [1.00, 0.92, 0.84, 0.76, 0.68],
			"arrow_cooldown_min_by_level": [1.30, 1.17, 0.98, 0.81, 0.65],
			"arrow_cooldown_max_by_level": [3.90, 3.38, 2.86, 2.34, 1.95],
			"golden_chance_pct_by_level": [0.0, 0.0, 20.0, 30.0, 30.0],
			"bonus_summon_chance_pct_by_level": [0.0, 0.0, 0.0, 0.0, 30.0],
			"card_texture_path": "res://assets/sprites/lingpet/nekuring_skeleton_archer_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/nekuring_skeleton_archer_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "nekuring_skeleton_archer",
				"runtime_kind": "skeleton_archer",
				"name": "해골궁수",
				"description": "네쿠링이 플레이어 진영에 해골 궁수를 불러냅니다. 레벨이 오를수록 화살 발사 간격이 짧아지며, Lv.3부터 황금 궁수가 나타나 3발을 동시에 쏠 수 있습니다. Lv.5는 30% 확률로 궁수 2마리를 소환합니다.",
				"cooldown": 11.7,
				"windup_seconds": 0.45,
				"arrow_draw_time_by_level": [1.00, 0.92, 0.84, 0.76, 0.68],
				"arrow_cooldown_min_by_level": [1.30, 1.17, 0.98, 0.81, 0.65],
				"arrow_cooldown_max_by_level": [3.90, 3.38, 2.86, 2.34, 1.95],
				"golden_chance_pct_by_level": [0.0, 0.0, 20.0, 30.0, 30.0],
				"bonus_summon_chance_pct_by_level": [0.0, 0.0, 0.0, 0.0, 30.0],
				"card_texture_path": "res://assets/sprites/lingpet/nekuring_skeleton_archer_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/nekuring_skeleton_archer_skill_icon_imagegen_v1.png",
			},
			{
				"id": "nekuring_bone_barrier",
				"runtime_kind": "bone_barrier",
				"name": "해골장막",
				"description": "네쿠링이 원본 핑파이터 네크로의 해골장막을 불러냅니다. 레벨이 오를수록 장막 폭이 넓어지며, Lv.3부터 20%/30%/40% 확률로 장막을 1개 더 설치합니다.",
				"cooldown": 21.0,
				"windup_seconds": 0.0,
				"build_time": 3.0,
				"barrier_width": 72.0,
				"barrier_width_by_level": [72.0, 84.0, 96.0, 108.0, 120.0],
				"barrier_height": 12.0,
				"bonus_barrier_chance_pct": 0.0,
				"bonus_barrier_chance_pct_by_level": [0.0, 0.0, 20.0, 30.0, 40.0],
				"card_texture_path": "res://assets/sprites/lingpet/nekuring_bone_barrier_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/nekuring_bone_barrier_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 획득 시 해골궁수 또는 해골장막 중 하나를 액티브 스킬로 얻습니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
		"concept_art_path": "res://assets/sprites/lingpet/nekuring_cutin_art.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/nekuring_cutin_art_magenta_source.png",
		"note": "Nekuring is a live hatch-pool pet sharing the common resonance egg art. Ghost Summon now uses dedicated skill-card/icon art. Acquisition cut-in uses the 4x4 / 16-frame AutoSprite sheet; acquisition click-dismiss and character-info click use the full 14x7 / 98-frame click Live2D sheet; in-battle companion click uses the downscaled 14x7 / 98-frame 128px companion sheet; in-game SD companion rendering uses the ringpart-matched rear idle 5x5 / 25-frame sheet, Maribo-style rear-3/4 move-left and move-right 5x5 / 25-frame sheets, and a dedicated rear staff-strike 5x5 / 25-frame sheet.",
	},
	"monkeyring": {
		"id": "monkeyring",
		"display_name": "빠나몽",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 170.0,
			"patrol_speed_min": 112.0,
			"patrol_speed_max": 232.0,
			"catch_width": 90.0,
			"catch_height": 54.0,
			"defense_rate": 0.16,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_idle": "res://assets/sprites/lingpet/monkeyring_companion_idle.png",
			"companion_move_left": "res://assets/sprites/lingpet/monkeyring_companion_move_left.png",
			"companion_move_right": "res://assets/sprites/lingpet/monkeyring_companion_move_right.png",
			"companion_walk": "res://assets/sprites/lingpet/monkeyring_companion_move_right.png",
			"companion_strike": "res://assets/sprites/lingpet/monkeyring_companion_strike.png",
			"companion_cast": "res://assets/sprites/lingpet/monkeyring_companion_wild_roar_cast.png",
			"cutin_art": "res://assets/sprites/lingpet/monkeyring_cutin_art.png",
			"cutin_anim": "res://assets/sprites/lingpet/monkeyring_cutin_anim.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.58,
			"cutin_dismiss_view_h_ratio": 0.58,
			"cutin_dismiss_seconds": 4.0,
			"cutin_dismiss_action_portion": 0.92,
			"cutin_dismiss_fade_start": 0.82,
			"cutin_dismiss_frame_blend_alpha": 0.38,
			"click_reaction_draw_size": 74.0,
			"companion_click_reaction_frame_interval": 0.05,
			"companion_click_reaction_frame_blend_alpha": 0.38,
			"panel_live2d_frame_blend_alpha": 0.38,
			"companion_walk_draw_size": 92.0,
			"companion_strike_draw_size": 92.0,
			"companion_cast_draw_size": 92.0,
		},
		"active_skill": {
			"id": "monkeyring_banana_slice",
			"runtime_kind": "banana_slice",
			"name": "바나나 슬라이스",
			"description": "빠나몽이 배 주머니에서 바나나를 꺼내 보스 진영 바닥에 던집니다. 레벨이 오르면 바나나가 두 개로 늘고 더 멀리 미끄러집니다.",
			"cooldown": 18.0,
			"windup_seconds": 0.45,
			"banana_count_by_level": [1, 1, 2, 2, 2],
			"slip_seconds_by_level": [0.45, 0.55, 0.65, 0.72, 0.80],
			"slip_speed_by_level": [15.0, 16.25, 17.5, 18.75, 20.0],
			"card_texture_path": "res://assets/sprites/lingpet/monkeyring_banana_slice_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/monkeyring_banana_slice_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "monkeyring_banana_slice",
				"runtime_kind": "banana_slice",
				"name": "바나나 슬라이스",
				"description": "빠나몽이 배 주머니에서 바나나를 꺼내 보스 진영 바닥에 던집니다. 레벨이 오르면 바나나가 두 개로 늘고 더 멀리 미끄러집니다.",
				"cooldown": 18.0,
				"windup_seconds": 0.45,
				"banana_count_by_level": [1, 1, 2, 2, 2],
				"slip_seconds_by_level": [0.45, 0.55, 0.65, 0.72, 0.80],
				"slip_speed_by_level": [15.0, 16.25, 17.5, 18.75, 20.0],
				"card_texture_path": "res://assets/sprites/lingpet/monkeyring_banana_slice_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/monkeyring_banana_slice_skill_icon_imagegen_v1.png",
			},
			{
				"id": "monkeyring_wild_roar",
				"runtime_kind": "wild_roar",
				"name": "야생의 포효",
				"description": "빠나몽이 야생의 포효로 접근하는 공을 위쪽으로 튕겨냅니다. 레벨이 오르면 포효 반경과 순간 반사 배율이 커집니다.",
				"cooldown": 27.0,
				"windup_seconds": 0.0,
				"roar_radius_by_level": [180.0, 198.0, 216.0, 234.0, 252.0],
				"ball_boost_by_level": [2.6, 2.85, 3.1, 3.35, 3.6],
				"card_texture_path": "res://assets/sprites/lingpet/monkeyring_wild_roar_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/monkeyring_wild_roar_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 획득 시 바나나 슬라이스 또는 야생의 포효 중 하나를 액티브 스킬로 얻습니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
		"concept_art_path": "res://assets/sprites/lingpet/monkeyring_cutin_art.png",
		"concept_green_source_path": "res://assets/sprites/lingpet/monkey_lingpet_banana_pouch_tailtip_concept_imagegen_v1_green_source.png",
		"note": "Monkeyring is a live hatch-pool pet sharing the common resonance egg art. Banana Slice ports Monkey King's original banana throw/slip skill into the lingpet active-skill runtime, but Lv.1 now starts at a shorter 0.45s slip and scales back to the legacy 0.80s duration by Lv.5. Acquisition cut-in uses the 4x4 / 16-frame AutoSprite sheet; acquisition click-dismiss and character-info click use the full 14x7 / 98-frame click Live2D sheet; in-battle companion click uses the downscaled 14x7 / 98-frame 128px companion sheet. In-game SD companion rendering uses a rear-view idle breathing 5x5 / 25-frame sheet, Maribo-style rear-3Q move-left and move-right 5x5 / 25-frame sheets, a dedicated rear tail-slap strike 5x5 / 25-frame sheet, and a Wild Roar rear cast 5x5 / 25-frame sheet.",
	},
	"rabi": {
		"id": "rabi",
		"display_name": "모락모랑",
		"motion_style": "free_flight",
		"enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 168.0,
			"patrol_speed_min": 108.0,
			"patrol_speed_max": 222.0,
			"catch_width": 90.0,
			"catch_height": 50.0,
			# Flight-style lingpet (free_flight): defense intercept is patrol-only, so
			# this stays 0 — a nonzero value would be dead data that only misleads the UI.
			"defense_rate": 0.0,
			# appearance_rate (출현율) shortens the ghost's hidden wait between blinks.
			"appearance_rate": 0.30,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_walk": "res://assets/sprites/lingpet/rabi_companion_walk.png",
			"companion_strike": "res://assets/sprites/lingpet/rabi_companion_walk.png",
			"companion_cast": "res://assets/sprites/lingpet/rabi_companion_walk.png",
			"cutin_art": "res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v3_clean.png",
			"cutin_anim": "res://assets/sprites/lingpet/rabi_cutin_anim_sd_identity_32f_hq_clean.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/rabi_click_live2d_pingpong_98f.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/rabi_click_live2d_pingpong_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/rabi_companion_click_reaction_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.62,
			"cutin_dismiss_view_h_ratio": 0.62,
			"cutin_dismiss_seconds": 3.35,
			"cutin_dismiss_action_portion": 0.92,
			"cutin_dismiss_fade_start": 0.82,
			"click_reaction_draw_size": 64.0,
			"companion_walk_draw_size": 92.0,
			"companion_strike_draw_size": 92.0,
			"companion_cast_draw_size": 92.0,
		},
		"active_skill": {
			"id": "rabi_soul_clone",
			"runtime_kind": "soul_clone",
			"name": "영혼분신",
			"description": "모락모랑의 영혼 분신을 소환합니다. Lv.3부터 2마리, Lv.5부터 3마리가 나타나고 레벨이 오를수록 지속시간도 조금씩 늘어납니다. 분신은 플레이어 진영을 자유롭게 떠다니며 공을 패들처럼 튕겨냅니다.",
			"cooldown": 55.0,
			"windup_seconds": 0.8,
			"clone_count_by_level": [1, 1, 2, 2, 3],
			"duration_seconds_by_level": [15.0, 16.0, 17.0, 18.0, 20.0],
			"card_texture_path": "res://assets/sprites/lingpet/rabi_soul_clone_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/rabi_soul_clone_skill_icon_imagegen_v1.png",
		},
		"active_skill_pool": [
			{
				"id": "rabi_soul_clone",
				"runtime_kind": "soul_clone",
				"name": "영혼분신",
				"description": "모락모랑의 영혼 분신을 소환합니다. Lv.3부터 2마리, Lv.5부터 3마리가 나타나고 레벨이 오를수록 지속시간도 조금씩 늘어납니다. 분신은 플레이어 진영을 자유롭게 떠다니며 공을 패들처럼 튕겨냅니다.",
				"cooldown": 55.0,
				"windup_seconds": 0.8,
				"clone_count_by_level": [1, 1, 2, 2, 3],
				"duration_seconds_by_level": [15.0, 16.0, 17.0, 18.0, 20.0],
				"card_texture_path": "res://assets/sprites/lingpet/rabi_soul_clone_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/rabi_soul_clone_skill_icon_imagegen_v1.png",
			},
			{
				"id": "rabi_ghost_summon",
				"runtime_kind": "ghost_summon",
				"name": "유령소환",
				"description": "모락모랑이 맵 중앙에 유령 패들 2개를 소환하여 공을 삼킨 뒤 상대 방향으로 다시 쏘아냅니다.",
				"cooldown": 40.0,
				"windup_seconds": 1.0,
				"card_texture_path": "res://assets/sprites/lingpet/rabi_ghost_summon_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/rabi_ghost_summon_skill_icon_imagegen_v1.png",
			},
		],
		"effect_text": "공을 직접 받아치면 게이지 +40 / 획득 시 영혼분신 또는 유령소환 중 하나를 액티브 스킬로 얻습니다. 패시브 효과는 획득 시 공용 풀에서 결정됩니다.",
		"concept_art_path": "res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v3_clean.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/rabi_cutin_art_sd_identity_v2_magenta_source.png",
		"note": "Rabi is a live hatch-pool pet sharing the common resonance egg art. Soul Clone and Ghost Summon now use dedicated skill-card/icon art. Static Live2D source art and the 32-frame acquisition cut-in now use the v3 clean alpha-matte variants that remove connected dark cutout artifacts around the face/body while preserving the accepted SD identity with large ear/wing side appendages. The acquisition click-dismiss cut-in reuses the dedicated 98-frame full-size click Live2D sheet, while in-game companion click uses the downscaled Rabi click-reaction sheet. In-game companion walk/strike/cast currently share the dedicated 25-frame rear-view SD flight movement loop, and the active runtime ports Banshee's Ghost Summon at a 40-second cooldown.",
	},
	"onimaru": {
		"id": "onimaru",
		"display_name": "오니마루",
		"enabled": false,
		"debug_enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 166.0,
			"patrol_speed_min": 108.0,
			"patrol_speed_max": 222.0,
			"catch_width": 88.0,
			"catch_height": 52.0,
			"defense_rate": 0.16,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_idle": "res://assets/sprites/lingpet/onimaru_companion_standing_idle_25f.png",
			"companion_move_left": "res://assets/sprites/lingpet/onimaru_companion_move_left_25f.png",
			"companion_move_right": "res://assets/sprites/lingpet/onimaru_companion_move_right_25f.png",
			"companion_walk": "res://assets/sprites/lingpet/onimaru_companion_move_right_25f.png",
			"companion_strike": "res://assets/sprites/lingpet/onimaru_companion_strike_25f.png",
			"companion_cast": "res://assets/sprites/lingpet/onimaru_companion_standing_idle_25f.png",
			"cutin_art": "res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber.png",
			"cutin_anim": "res://assets/sprites/lingpet/onimaru_cutin_live2d_autosprite_32f_amber.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/onimaru_click_live2d_autosprite_98f_amber_gripfix.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/onimaru_companion_click_reaction_autosprite_98f_amber_gripfix.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.66,
			"cutin_dismiss_view_h_ratio": 0.66,
			"cutin_dismiss_seconds": 3.35,
			"cutin_dismiss_action_portion": 0.92,
			"cutin_dismiss_fade_start": 0.82,
			"click_reaction_draw_size": 82.0,
			"companion_walk_draw_size": 92.0,
			"companion_strike_draw_size": 92.0,
			"companion_cast_draw_size": 92.0,
		},
		"active_skill": [],
		"effect_text": "오니마루는 F7 디버그용 붉은 도깨비 링펫입니다. v2 원화 앵커 기반 라투디/클릭 시트와 전용 스탠딩, 좌/우 이동, 방망이 공격 동행 시트를 연결했으며, 스킬 런타임은 아직 부화 풀에 넣기 전 단계입니다.",
		"concept_art_path": "res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/onimaru_lingpet_live2d_anchor_v2_amber_magenta_source.png",
		"note": "Onimaru is debug-only and uses the accepted v2 transparent Live2D anchor recolored to the amber/gold first-choice ring-part gem palette as the source for a dedicated AutoSprite-derived 8x4 / 32-frame acquisition Live2D loop, a dedicated identity-locked standing companion idle sheet, a dedicated AutoSprite left/right companion movement pair, a dedicated AutoSprite-derived kanabo strike sheet aligned to the runtime impact frame, and a dedicated AutoSprite-derived 14x7 click reaction sheet shared by acquisition dismiss and panel click. The click sheet uses the grip-fix retime that removes early frames where the kanabo reads as dropped, with a downscaled companion click sheet for battle. Keep it out of the random hatch pool until active-skill runtime is accepted.",
	},
	"rahoset": {
		"id": "rahoset",
		"display_name": "라호세트",
		"motion_style": "sortie_flight",
		"enabled": false,
		"debug_enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 168.0,
			"patrol_speed_min": 112.0,
			"patrol_speed_max": 224.0,
			"catch_width": 92.0,
			"catch_height": 50.0,
			# Flight-style lingpet (sortie_flight): defense intercept is patrol-only,
			# so this stays 0 and the F7 slider routes to appearance_rate instead.
			"defense_rate": 0.0,
			"appearance_rate": 0.30,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_idle": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
			"companion_move_left": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
			"companion_move_right": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
			"companion_walk": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
			"companion_strike": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
			"companion_cast": "res://assets/sprites/lingpet/rahoset_companion_front_hover_autosprite_25f.png",
			"cutin_art": "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png",
			"cutin_anim": "res://assets/sprites/lingpet/rahoset_cutin_acquire_ready_v2_autosprite_32f.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/rahoset_click_ritual_linked_v2_autosprite_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/rahoset_companion_click_ritual_linked_v2_autosprite_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.66,
			"cutin_dismiss_view_h_ratio": 0.66,
			"cutin_dismiss_seconds": 3.35,
			"cutin_dismiss_action_portion": 0.86,
			"cutin_dismiss_fade_start": 0.72,
			"click_reaction_draw_size": 82.0,
			"companion_walk_draw_size": 92.0,
			"companion_strike_draw_size": 92.0,
			"companion_cast_draw_size": 92.0,
		},
		"active_skill": [],
		"effect_text": "라호세트는 F7 디버그용 이집트 사막 신 컨셉의 공중 링펫입니다. 현재는 정식 스킬 런타임과 전용 라투디 제작 전 단계라, 획득/클릭/동행 시트는 accepted 원화 앵커에서 만든 정적 임시 시트를 사용합니다.",
		"concept_art_path": "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/rahoset_lingpet_live2d_anchor_v1_magenta_source.png",
		"note": "Rahoset is debug-only until dedicated sand/desert active-skill runtime and egg assets are accepted. The first AutoSprite desert-hover branch was rejected for a persistent right-facing drift, so acquisition and companion hover use the accepted AutoSprite front-hover retry. Click/dismiss/panel playback uses the AutoSprite-derived staff-action transition sheet: frame 0 matches the acquisition hover angle, then eases into the raised-staff, open-wing expression/action pose so the click does not pop to a different angle. Keep it out of the random hatch pool until the active-skill runtime is accepted.",
	},
	"orosha": {
		"id": "orosha",
		"display_name": "오로샤",
		"motion_style": "patrol",
		"enabled": false,
		"debug_enabled": true,
		"hatch_weight": 1.0,
		"required_hits": 1,
		"unlock": {
			"league_mode": "junior",
			"character_type": "smasher",
		},
		"stats": {
			"patrol_speed_default": 172.0,
			"patrol_speed_min": 112.0,
			"patrol_speed_max": 232.0,
			"catch_width": 96.0,
			"catch_height": 54.0,
			# Ground patrol lingpet: defense intercept uses the normal patrol path.
			"defense_rate": 0.16,
			"hit_gauge_gain": 40.0,
			"gauge_gain_bonus_pct": 0.0,
		},
		"visuals": {
			"egg": "res://assets/sprites/lingpet/maribo_egg_v002.png",
			"egg_crack_1": "res://assets/sprites/lingpet/maribo_egg_v002_crack1.png",
			"egg_crack_2": "res://assets/sprites/lingpet/maribo_egg_v002_crack2.png",
			"companion_idle": "res://assets/sprites/lingpet/orosha_companion_idle_ground_autosprite_25f.png",
			"companion_move_left": "res://assets/sprites/lingpet/orosha_companion_move_left_ground_roll_autosprite_48f.png",
			"companion_move_right": "res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f.png",
			"companion_walk": "res://assets/sprites/lingpet/orosha_companion_move_right_ground_roll_autosprite_48f.png",
			"companion_distance_roll_source": "res://assets/sprites/lingpet/orosha_companion_round_roll_source_v1.png",
			"companion_strike": "res://assets/sprites/lingpet/orosha_companion_static_25f.png",
			"companion_cast": "res://assets/sprites/lingpet/orosha_companion_static_25f.png",
			"companion_star_coil_bind": "res://assets/sprites/lingpet/orosha_star_coil_bind_autosprite_16f.png",
			"cutin_art": "res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1.png",
			"cutin_anim": "res://assets/sprites/lingpet/orosha_cutin_live2d_rigid_v2_autosprite_32f.png",
			"cutin_vfx_anim": "res://assets/sprites/lingpet/orosha_acquire_vfx_autosprite_16f.png",
			"cutin_dismiss_anim": "res://assets/sprites/lingpet/orosha_click_rolling_autosprite_98f.png",
			"click_reaction_anim": "res://assets/sprites/lingpet/orosha_click_rolling_autosprite_98f.png",
			"companion_click_reaction_anim": "res://assets/sprites/lingpet/orosha_companion_click_reaction_rolling_98f.png",
		},
		"visual_layout": {
			"cutin_anim_view_h_ratio": 0.66,
			"cutin_vfx_cols": 4.0,
			"cutin_vfx_rows": 4.0,
			"cutin_vfx_frame_count": 16.0,
			"cutin_vfx_fps": 16.0,
			"cutin_vfx_view_h_ratio": 1.05,
			"cutin_vfx_alpha": 0.82,
			"cutin_dismiss_view_h_ratio": 0.66,
			"cutin_dismiss_seconds": 3.35,
			"cutin_dismiss_action_portion": 0.86,
			"cutin_dismiss_fade_start": 0.72,
			"click_reaction_draw_size": 84.0,
			"companion_walk_draw_size": 98.0,
			"companion_distance_roll_enabled": 1.0,
			"companion_distance_roll_radius": 49.0,
			"companion_distance_roll_stop_deceleration": 16.0,
			"companion_distance_roll_max_angular_velocity": 6.0,
			"companion_star_coil_bind_cols": 4.0,
			"companion_star_coil_bind_rows": 4.0,
			"companion_star_coil_bind_frame_count": 16.0,
			"companion_star_coil_bind_draw_size": 150.0,
			"companion_stop_freeze_move_frame": 1.0,
			"companion_move_left_cols": 8.0,
			"companion_move_left_rows": 6.0,
			"companion_move_left_frame_count": 48.0,
			"companion_move_right_cols": 8.0,
			"companion_move_right_rows": 6.0,
			"companion_move_right_frame_count": 48.0,
			"companion_walk_cols": 8.0,
			"companion_walk_rows": 6.0,
			"companion_walk_frame_count": 48.0,
			"companion_strike_draw_size": 98.0,
			"companion_cast_draw_size": 98.0,
		},
		"active_skill": {
			"id": "orosha_star_coil",
			"runtime_kind": "star_coil",
			"name": "별똬리",
			"description": "오로샤가 가까운 벽을 굴러 올라가 보스를 별자리 고리로 휘감아 1.5~3.5초 동안 이동 속도를 60% 늦춥니다. 둔화가 끝나면 반대편 벽으로 굴러 내려옵니다.",
			"cooldown": 40.0,
			"cooldown_by_level": [40.0, 35.0, 30.0, 30.0, 30.0],
			"windup_seconds": 0.3,
			"slow_duration": 1.5,
			"slow_duration_by_level": [1.5, 2.0, 2.5, 3.0, 3.5],
			"slow_multiplier": 0.4,
			"card_texture_path": "res://assets/sprites/lingpet/orosha_star_coil_skillcard_imagegen_v1.png",
			"icon_texture_path": "res://assets/sprites/lingpet/orosha_star_coil_skill_icon_imagegen_v1.png",
			"motion_hint": "patrol_auto_boss_slow",
			"how_to_use": "랠리 중 자동 발동합니다. 공 하강 조건 없이 보스에게 둔화를 겁니다.",
		},
		"active_skill_pool": [
			{
				"id": "orosha_star_coil",
				"runtime_kind": "star_coil",
				"name": "별똬리",
				"description": "오로샤가 가까운 벽을 굴러 올라가 보스를 별자리 고리로 휘감아 1.5~3.5초 동안 이동 속도를 60% 늦춥니다. 둔화가 끝나면 반대편 벽으로 굴러 내려옵니다.",
				"cooldown": 40.0,
				"cooldown_by_level": [40.0, 35.0, 30.0, 30.0, 30.0],
				"windup_seconds": 0.3,
				"slow_duration": 1.5,
				"slow_duration_by_level": [1.5, 2.0, 2.5, 3.0, 3.5],
				"slow_multiplier": 0.4,
				"card_texture_path": "res://assets/sprites/lingpet/orosha_star_coil_skillcard_imagegen_v1.png",
				"icon_texture_path": "res://assets/sprites/lingpet/orosha_star_coil_skill_icon_imagegen_v1.png",
				"motion_hint": "patrol_auto_boss_slow",
				"how_to_use": "랠리 중 자동 발동합니다. 공 하강 조건 없이 보스에게 둔화를 겁니다.",
			},
		],
		"effect_text": "오로샤는 가까운 벽을 타고 올라가 보스를 별자리 고리뱀으로 휘감는 별똬리를 자동 발동합니다. 보스 위치는 고정하지 않고 이동 속도만 잠시 늦춥니다.",
		"concept_art_path": "res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1.png",
		"concept_magenta_source_path": "res://assets/sprites/lingpet/orosha_lingpet_live2d_anchor_v1_magenta_source.png",
		"note": "Orosha is debug-only until Star Coil card/icon assets, audio, and final hatch-pool QA are accepted. Orosha is a grounded rolling-hoop pet: companion movement now uses an AutoSprite-generated complete circular hoop redraw as a distance-based full runtime roll with a short visual deceleration coast on stop, avoiding the lumpy full rotation from the non-circular rear-view source art; the native left/right 8x6 / 48-frame AutoSprite ground-roll sheets remain as fallback assets. Star Coil is a patrol-auto boss slow skill that keeps boss movement AI authoritative and writes only live slow flags. Acquisition uses the rigid v2 AutoSprite Live2D sheet that avoids face-only rotation plus a separate AutoSprite VFX layer, and click/dismiss/panel playback uses the rolling-hoop AutoSprite sheet. Keep it out of the random hatch pool until the active-skill runtime and assets are accepted.",
	},
}


static func get_default_pet_id() -> String:
	return DEFAULT_PET_ID


static func has_pet(pet_id: String) -> bool:
	return is_pet_available_for_runtime_from_entries(PETS, pet_id)


static func get_pet_ids(include_disabled: bool = false) -> Array[String]:
	var result: Array[String] = []
	for pet_id in PETS.keys():
		var entry: Variant = PETS.get(pet_id, {})
		if include_disabled or (entry is Dictionary and _is_entry_enabled(entry as Dictionary)):
			result.append(str(pet_id))
	return result


static func get_debug_pet_ids() -> Array[String]:
	var result: Array[String] = []
	for pet_id in PETS.keys():
		var entry: Variant = PETS.get(pet_id, {})
		if entry is Dictionary and (_is_entry_enabled(entry as Dictionary) or _is_entry_debug_enabled(entry as Dictionary)):
			result.append(str(pet_id))
	return result


static func is_pet_enabled(pet_id: String) -> bool:
	return is_pet_enabled_from_entries(PETS, pet_id)


static func is_pet_enabled_from_entries(entries: Dictionary, pet_id: String) -> bool:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = _get_entry_from_entries(entries, normalized)
	return entry is Dictionary and _is_entry_enabled(entry as Dictionary)


static func is_pet_available_for_runtime_from_entries(entries: Dictionary, pet_id: String) -> bool:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = _get_entry_from_entries(entries, normalized)
	return entry is Dictionary and (
		_is_entry_enabled(entry as Dictionary)
		or _is_entry_debug_enabled(entry as Dictionary)
	)


static func is_pet_debug_enabled(pet_id: String) -> bool:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = _get_entry_from_entries(PETS, normalized)
	return entry is Dictionary and _is_entry_debug_enabled(entry as Dictionary)


static func get_entry(pet_id: String) -> Dictionary:
	# Public, mutation-safe entry accessor: returns a deep copy so external
	# callers can store / mutate freely. Hot read-only getters must NOT use this
	# -- they go through _get_entry_ref() to avoid a full PETS-entry deep copy on
	# every per-frame draw/update call (see the perf note on _get_entry_ref).
	return _get_entry_ref(pet_id).duplicate(true)


# Read-only, non-copying entry accessor for per-frame hot paths. The companion
# draw/update loop resolves visuals, layout, stats, display name, and the active
# skill pool every frame; routing those through the deep-copying get_entry()
# duplicated the (large, multi-skill) PETS entry dozens of times per frame.
# Callers here only READ from the returned dict (or duplicate downstream via
# _normalize_skill_pool / _apply_skill_level_values), so sharing the const ref
# is safe. Do NOT mutate the returned dictionary.
static func _get_entry_ref(pet_id: String) -> Dictionary:
	var normalized := _normalize_pet_id(pet_id)
	if PETS.has(normalized):
		return PETS[normalized] as Dictionary
	return PETS[DEFAULT_PET_ID] as Dictionary


static func get_display_name(pet_id: String) -> String:
	return str(_get_entry_ref(pet_id).get("display_name", _normalize_pet_id(pet_id)))


static func get_required_hits(pet_id: String, fallback: int = 1) -> int:
	return max(1, int(_get_entry_ref(pet_id).get("required_hits", fallback)))


static func get_stat(pet_id: String, stat_name: String, fallback: float = 0.0) -> float:
	var stats: Variant = _get_entry_ref(pet_id).get("stats", {})
	if stats is Dictionary:
		return float((stats as Dictionary).get(stat_name, fallback))
	return fallback


static func get_visual_layout_value(pet_id: String, layout_key: String, fallback: float = 0.0) -> float:
	var visual_layout: Variant = _get_entry_ref(pet_id).get("visual_layout", {})
	if visual_layout is Dictionary:
		return float((visual_layout as Dictionary).get(layout_key, fallback))
	return fallback


static func clamp_skill_level(level: int) -> int:
	return clampi(level, SKILL_LEVEL_MIN, SKILL_LEVEL_MAX)


static func get_skill_level_value(skill_data: Dictionary, effect_key: String, level: int, fallback: float = 0.0) -> float:
	var normalized_level := clamp_skill_level(level)
	var level_values_key := effect_key + "_by_level"
	var level_values: Variant = skill_data.get(level_values_key, [])
	if level_values is Array and not (level_values as Array).is_empty():
		var index := clampi(normalized_level - 1, 0, (level_values as Array).size() - 1)
		return float((level_values as Array)[index])
	return float(skill_data.get(effect_key, fallback))


static func get_active_skill(pet_id: String, skill_id: String = DEFAULT_ACTIVE_SKILL_SENTINEL, level: int = DEFAULT_ACTIVE_SKILL_LEVEL) -> Dictionary:
	var active_pool := get_active_skill_pool(pet_id)
	var normalized_skill_id := _normalize_skill_id(skill_id)
	var allow_primary_fallback := normalized_skill_id == DEFAULT_ACTIVE_SKILL_SENTINEL
	if allow_primary_fallback:
		normalized_skill_id = ""
	if normalized_skill_id != "":
		for skill in active_pool:
			if _normalize_skill_id(str(skill.get("id", ""))) == normalized_skill_id:
				return _apply_active_skill_level(skill, level)
	if allow_primary_fallback and not active_pool.is_empty():
		return _apply_active_skill_level(active_pool[0], level)
	return {}


static func get_active_skill_pool(pet_id: String) -> Array[Dictionary]:
	return _get_active_skill_pool_from_entry(_get_entry_ref(pet_id), true)


static func get_active_skill_entry(skill_id: String) -> Dictionary:
	return get_active_skill_entry_from_entries(PETS, skill_id)


static func get_active_skill_entry_from_entries(entries: Dictionary, skill_id: String) -> Dictionary:
	var normalized := _normalize_skill_id(skill_id)
	if normalized == "":
		return {}
	for raw_pet_id in entries.keys():
		var entry: Variant = entries.get(raw_pet_id, {})
		if not (entry is Dictionary):
			continue
		for skill in _get_active_skill_pool_from_entry(entry as Dictionary, true):
			if _normalize_skill_id(str(skill.get("id", ""))) == normalized:
				return skill.duplicate(true)
	return {}


static func get_active_skill_runtime_kind(skill_id: String) -> String:
	return get_active_skill_runtime_kind_from_entries(PETS, skill_id)


static func get_active_skill_runtime_kind_from_entries(entries: Dictionary, skill_id: String) -> String:
	var skill := get_active_skill_entry_from_entries(entries, skill_id)
	return str(skill.get("runtime_kind", "")).strip_edges().to_lower()


static func get_visual_path(pet_id: String, visual_key: String) -> String:
	var visuals: Variant = _get_entry_ref(pet_id).get("visuals", {})
	if visuals is Dictionary:
		return str((visuals as Dictionary).get(visual_key, ""))
	return ""


static func get_passive_icon_path(pet_id: String, passive_id: String) -> String:
	var passive_icons: Variant = _get_entry_ref(pet_id).get("passive_icons", {})
	if passive_icons is Dictionary:
		var icon_path := str((passive_icons as Dictionary).get(passive_id, ""))
		if icon_path != "":
			return icon_path
	var passive := get_passive_skill(pet_id, passive_id)
	return str(passive.get("icon_texture_path", ""))


static func get_passive_skill(_pet_id: String, passive_id: String = "", level: int = DEFAULT_PASSIVE_SKILL_LEVEL) -> Dictionary:
	# Resolve a single passive against the common pool. This used to build the
	# WHOLE level-applied pool (one deep copy per passive) just to pick one entry,
	# then re-apply the level a second time -- and get_active_skill() /
	# current_profile call it several times per frame for cooldown/windup/stat
	# scaling, so the discarded copies dominated the companion hot path. Match the
	# raw const pool directly and apply the level exactly once.
	var normalized_passive_id := _normalize_passive_skill_id_alias(passive_id)
	if normalized_passive_id != "":
		for passive in COMMON_PASSIVE_SKILL_POOL:
			if _normalize_skill_id(str((passive as Dictionary).get("id", ""))) == normalized_passive_id:
				return _apply_skill_level_values(passive as Dictionary, level)
	if not COMMON_PASSIVE_SKILL_POOL.is_empty():
		return _apply_skill_level_values(COMMON_PASSIVE_SKILL_POOL[0] as Dictionary, level)
	return {}


static func get_passive_skill_pool(_pet_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for passive in COMMON_PASSIVE_SKILL_POOL:
		result.append(_apply_skill_level_values(passive, DEFAULT_PASSIVE_SKILL_LEVEL))
	return result


static func get_passive_skill_entry(passive_id: String) -> Dictionary:
	var normalized := _normalize_passive_skill_id_alias(passive_id)
	if normalized == "":
		return {}
	for passive in get_passive_skill_pool(DEFAULT_PET_ID):
		if _normalize_skill_id(str(passive.get("id", ""))) == normalized:
			return passive.duplicate(true)
	return {}


static func pick_skill_loadout(pet_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var _unused_rng := rng
	return build_empty_loadout(pet_id)


static func build_empty_loadout(_pet_id: String = "") -> Dictionary:
	return {
		"active_skill_id": "",
		"active_skill_level": 0,
		"active_slot_count": 0,
		"active_skill_ids": [],
		"active_skill_levels": {},
		"passive_skill_id": "",
		"passive_skill_level": 0,
		"passive_slot_count": 0,
		"passive_skill_ids": [],
		"passive_skill_levels": {},
	}


static func build_default_loadout(pet_id: String) -> Dictionary:
	var active_skill := get_active_skill(pet_id)
	var passive_skill := get_passive_skill(pet_id)
	var passive_id := str(passive_skill.get("id", ""))
	return {
		"active_skill_id": str(active_skill.get("id", "")),
		"active_skill_level": DEFAULT_ACTIVE_SKILL_LEVEL,
		"active_slot_count": DEFAULT_ACTIVE_SLOT_COUNT,
		"active_skill_ids": [str(active_skill.get("id", ""))] if str(active_skill.get("id", "")) != "" else [],
		"active_skill_levels": {str(active_skill.get("id", "")): DEFAULT_ACTIVE_SKILL_LEVEL} if str(active_skill.get("id", "")) != "" else {},
		"passive_skill_id": passive_id,
		"passive_skill_level": DEFAULT_PASSIVE_SKILL_LEVEL,
		"passive_slot_count": DEFAULT_PASSIVE_SLOT_COUNT,
		"passive_skill_ids": [passive_id] if passive_id != "" else [],
		"passive_skill_levels": {passive_id: DEFAULT_PASSIVE_SKILL_LEVEL} if passive_id != "" else {},
	}


static func normalize_active_skill_id(pet_id: String, skill_id: String) -> String:
	var normalized := _normalize_skill_id(skill_id)
	if normalized == "":
		return ""
	for skill in get_active_skill_pool(pet_id):
		if _normalize_skill_id(str(skill.get("id", ""))) == normalized:
			return str(skill.get("id", "")).strip_edges()
	return ""


static func normalize_passive_skill_id(pet_id: String, passive_id: String) -> String:
	var normalized := _normalize_passive_skill_id_alias(passive_id)
	if normalized == "":
		return ""
	for passive in get_passive_skill_pool(pet_id):
		if _normalize_skill_id(str(passive.get("id", ""))) == normalized:
			return str(passive.get("id", "")).strip_edges()
	return ""


static func get_effect_text(pet_id: String) -> String:
	return str(_get_entry_ref(pet_id).get("effect_text", ""))


static func get_motion_style(pet_id: String) -> String:
	return str(_get_entry_ref(pet_id).get("motion_style", "patrol")).strip_edges().to_lower()


static func validate_catalog(require_existing_files: bool = false) -> Array[String]:
	return validate_entries(PETS, require_existing_files)


static func validate_entries(entries: Dictionary, require_existing_files: bool = false) -> Array[String]:
	var issues: Array[String] = []
	var seen_ids := {}
	_validate_passive_skill_pool("common_passive_skill_pool", get_passive_skill_pool(DEFAULT_PET_ID), issues, require_existing_files)
	for raw_pet_id in entries.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		var entry: Variant = entries.get(raw_pet_id, {})
		if pet_id == "":
			issues.append("entry key is empty")
			continue
		if bool(seen_ids.get(pet_id, false)):
			issues.append("%s: duplicate normalized pet id" % pet_id)
		seen_ids[pet_id] = true
		if not (entry is Dictionary):
			issues.append("%s: entry must be a Dictionary" % pet_id)
			continue
		issues.append_array(validate_entry(pet_id, entry as Dictionary, require_existing_files))
	return issues


static func validate_entry(pet_id: String, entry: Dictionary, require_existing_files: bool = false) -> Array[String]:
	var issues: Array[String] = []
	var normalized := _normalize_pet_id(pet_id)
	var entry_id := _normalize_pet_id(str(entry.get("id", "")))
	if entry_id == "":
		issues.append("%s: missing id" % normalized)
	elif entry_id != normalized:
		issues.append("%s: id mismatch (%s)" % [normalized, entry_id])
	if str(entry.get("display_name", "")).strip_edges() == "":
		issues.append("%s: missing display_name" % normalized)
	if float(entry.get("hatch_weight", 0.0)) <= 0.0:
		issues.append("%s: hatch_weight must be > 0" % normalized)
	if int(entry.get("required_hits", 0)) < 1:
		issues.append("%s: required_hits must be >= 1" % normalized)
	var unlock: Variant = entry.get("unlock", {})
	if not (unlock is Dictionary):
		issues.append("%s: unlock must be a Dictionary" % normalized)
	if not _is_entry_enabled(entry):
		return issues
	_validate_required_stats(normalized, entry, issues)
	_validate_required_visuals(normalized, entry, issues, require_existing_files)
	_validate_active_skill(normalized, entry, issues, require_existing_files)
	_validate_passive_icons(normalized, entry, issues, require_existing_files)
	_validate_passive_skills(normalized, entry, issues, require_existing_files)
	if str(entry.get("effect_text", "")).strip_edges() == "":
		issues.append("%s: missing effect_text" % normalized)
	return issues


static func _validate_required_stats(pet_id: String, entry: Dictionary, issues: Array[String]) -> void:
	var stats: Variant = entry.get("stats", {})
	if not (stats is Dictionary):
		issues.append("%s: stats must be a Dictionary" % pet_id)
		return
	var stats_data: Dictionary = stats as Dictionary
	for key in REQUIRED_STAT_KEYS:
		if not stats_data.has(key):
			issues.append("%s: missing stats.%s" % [pet_id, str(key)])
	if float(stats_data.get("patrol_speed_default", 0.0)) <= 0.0:
		issues.append("%s: stats.patrol_speed_default must be > 0" % pet_id)
	if float(stats_data.get("patrol_speed_min", 0.0)) <= 0.0:
		issues.append("%s: stats.patrol_speed_min must be > 0" % pet_id)
	if float(stats_data.get("patrol_speed_max", 0.0)) < float(stats_data.get("patrol_speed_min", 0.0)):
		issues.append("%s: stats.patrol_speed_max must be >= stats.patrol_speed_min" % pet_id)
	if float(stats_data.get("catch_width", 0.0)) <= 0.0 or float(stats_data.get("catch_height", 0.0)) <= 0.0:
		issues.append("%s: stats.catch_width/height must be > 0" % pet_id)
	var defense_rate := float(stats_data.get("defense_rate", 0.0))
	if defense_rate < 0.0 or defense_rate > 1.0:
		issues.append("%s: stats.defense_rate must be 0..1" % pet_id)


static func _validate_required_visuals(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var visuals: Variant = entry.get("visuals", {})
	if not (visuals is Dictionary):
		issues.append("%s: visuals must be a Dictionary" % pet_id)
		return
	var visuals_data: Dictionary = visuals as Dictionary
	for key in REQUIRED_VISUAL_KEYS:
		var path := str(visuals_data.get(key, "")).strip_edges()
		if path == "":
			issues.append("%s: missing visuals.%s" % [pet_id, str(key)])
		elif require_existing_files and not _texture_resource_exists(path):
			issues.append("%s: missing visual file %s" % [pet_id, path])


static func _validate_active_skill(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var skill: Variant = entry.get("active_skill", {})
	var configured_pool := _get_configured_active_skill_pool_from_entry(entry)
	if not (skill is Dictionary) and configured_pool.is_empty():
		issues.append("%s: active_skill must be a Dictionary" % pet_id)
		return
	if skill is Dictionary:
		_validate_active_skill_data(pet_id, "active_skill", skill as Dictionary, issues, require_existing_files)
	for i in range(configured_pool.size()):
		_validate_active_skill_data(pet_id, "active_skill_pool[%d]" % i, configured_pool[i], issues, require_existing_files)


static func _validate_active_skill_data(pet_id: String, label: String, skill_data: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	for key in REQUIRED_ACTIVE_SKILL_KEYS:
		if str(skill_data.get(key, "")).strip_edges() == "":
			issues.append("%s: missing %s.%s" % [pet_id, label, str(key)])
	if float(skill_data.get("cooldown", 0.0)) <= 0.0:
		issues.append("%s: %s.cooldown must be > 0" % [pet_id, label])
	if skill_data.has("windup_seconds") and float(skill_data.get("windup_seconds", 0.0)) < 0.0:
		issues.append("%s: %s.windup_seconds must be >= 0" % [pet_id, label])
	var card_path := str(skill_data.get("card_texture_path", "")).strip_edges()
	if card_path != "" and require_existing_files and not _texture_resource_exists(card_path):
		issues.append("%s: missing skill-card file %s" % [pet_id, card_path])
	var icon_path := str(skill_data.get("icon_texture_path", "")).strip_edges()
	if icon_path != "" and require_existing_files and not _texture_resource_exists(icon_path):
		issues.append("%s: missing active skill icon file %s" % [pet_id, icon_path])


static func _validate_passive_icons(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var passive_icons: Variant = entry.get("passive_icons", {})
	if passive_icons == null:
		return
	if not (passive_icons is Dictionary):
		issues.append("%s: passive_icons must be a Dictionary" % pet_id)
		return
	for raw_key in (passive_icons as Dictionary).keys():
		var icon_key := str(raw_key).strip_edges()
		var path := str((passive_icons as Dictionary).get(raw_key, "")).strip_edges()
		if icon_key == "":
			issues.append("%s: passive_icons has an empty key" % pet_id)
		if path == "":
			issues.append("%s: missing passive icon path for %s" % [pet_id, icon_key])
		elif require_existing_files and not _texture_resource_exists(path):
			issues.append("%s: missing passive icon file %s" % [pet_id, path])


static func _validate_passive_skills(pet_id: String, entry: Dictionary, issues: Array[String], require_existing_files: bool) -> void:
	var passive_pool := _get_passive_skill_pool_from_entry(entry)
	if passive_pool.is_empty():
		return
	_validate_passive_skill_pool("%s.passive_skill_pool" % pet_id, passive_pool, issues, require_existing_files)


static func _validate_passive_skill_pool(label: String, passive_pool: Array[Dictionary], issues: Array[String], require_existing_files: bool) -> void:
	var seen_ids := {}
	for i in range(passive_pool.size()):
		var passive := passive_pool[i]
		var passive_id := _normalize_skill_id(str(passive.get("id", "")))
		for key in REQUIRED_PASSIVE_SKILL_KEYS:
			if str(passive.get(key, "")).strip_edges() == "":
				issues.append("%s: missing [%d].%s" % [label, i, str(key)])
		if passive_id != "":
			if bool(seen_ids.get(passive_id, false)):
				issues.append("%s: duplicate passive skill id %s" % [label, passive_id])
			seen_ids[passive_id] = true
		var icon_path := str(passive.get("icon_texture_path", "")).strip_edges()
		if icon_path != "" and require_existing_files and not _texture_resource_exists(icon_path):
			issues.append("%s: missing passive skill icon file %s" % [label, icon_path])
		if passive.has("gauge_gain_bonus_pct") and float(passive.get("gauge_gain_bonus_pct", 0.0)) < 0.0:
			issues.append("%s[%d].gauge_gain_bonus_pct must be >= 0" % [label, i])
		if passive.has("player_speed_bonus_pct") and float(passive.get("player_speed_bonus_pct", 0.0)) < 0.0:
			issues.append("%s[%d].player_speed_bonus_pct must be >= 0" % [label, i])


static func _texture_resource_exists(path: String) -> bool:
	return ProjectResourceLoader.texture_resource_exists(path)


static func get_hatch_candidates(context: Dictionary, owned_pet_ids: Array) -> Array[String]:
	return get_hatch_candidates_from_entries(PETS, context, owned_pet_ids)


static func get_hatch_candidates_from_entries(entries: Dictionary, context: Dictionary, owned_pet_ids: Array) -> Array[String]:
	var owned_lookup := {}
	for raw_id in owned_pet_ids:
		var owned_id := _normalize_pet_id(str(raw_id))
		if owned_id != "":
			owned_lookup[owned_id] = true
	var result: Array[String] = []
	for raw_pet_id in entries.keys():
		var pet_id := _normalize_pet_id(str(raw_pet_id))
		var entry: Variant = entries.get(raw_pet_id, {})
		if (
			pet_id != ""
			and entry is Dictionary
			and _is_entry_enabled(entry as Dictionary)
			and not bool(owned_lookup.get(pet_id, false))
			and _matches_unlock(entry as Dictionary, context)
		):
			result.append(pet_id)
	return result


static func pick_hatch_pet_id(context: Dictionary, owned_pet_ids: Array, rng: RandomNumberGenerator = null) -> String:
	return pick_hatch_pet_id_from_entries(PETS, context, owned_pet_ids, rng)


static func pick_hatch_pet_id_from_entries(entries: Dictionary, context: Dictionary, owned_pet_ids: Array, rng: RandomNumberGenerator = null) -> String:
	var candidates := get_hatch_candidates_from_entries(entries, context, owned_pet_ids)
	if candidates.is_empty():
		return ""
	var total_weight := 0.0
	for pet_id in candidates:
		total_weight += _get_entry_weight(entries, pet_id)
	if total_weight <= 0.0:
		return candidates[0]
	var roll := (rng.randf() if rng != null else randf()) * total_weight
	for pet_id in candidates:
		roll -= _get_entry_weight(entries, pet_id)
		if roll <= 0.0:
			return pet_id
	return candidates[candidates.size() - 1]


static func _get_entry_weight(entries: Dictionary, pet_id: String) -> float:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = _get_entry_from_entries(entries, normalized)
	if entry is Dictionary:
		return maxf(0.0, float((entry as Dictionary).get("hatch_weight", 1.0)))
	return 0.0


static func _get_entry_from_entries(entries: Dictionary, pet_id: String) -> Variant:
	var normalized := _normalize_pet_id(pet_id)
	var entry: Variant = entries.get(normalized, null)
	if entry is Dictionary:
		return entry
	for raw_pet_id in entries.keys():
		if _normalize_pet_id(str(raw_pet_id)) == normalized:
			return entries.get(raw_pet_id, null)
	return null


static func _is_entry_enabled(entry: Dictionary) -> bool:
	return bool(entry.get("enabled", true))


static func _is_entry_debug_enabled(entry: Dictionary) -> bool:
	return bool(entry.get("debug_enabled", false))


static func _get_active_skill_pool_from_entry(entry: Dictionary, include_primary_fallback: bool) -> Array[Dictionary]:
	var pool := _get_configured_active_skill_pool_from_entry(entry)
	if not pool.is_empty() or not include_primary_fallback:
		return pool
	var skill: Variant = entry.get("active_skill", {})
	return _normalize_skill_pool(skill)


static func _get_configured_active_skill_pool_from_entry(entry: Dictionary) -> Array[Dictionary]:
	var active_pool: Variant = entry.get("active_skill_pool", entry.get("active_skills", []))
	return _normalize_skill_pool(active_pool)


static func _get_passive_skill_pool_from_entry(entry: Dictionary) -> Array[Dictionary]:
	return _normalize_skill_pool(entry.get("passive_skill_pool", entry.get("passive_skills", [])))


static func _apply_active_skill_level(skill_data: Dictionary, level: int) -> Dictionary:
	var result := _apply_skill_level_values(skill_data, level)
	var normalized_level := clamp_skill_level(level)
	var base_cooldown := float(result.get("cooldown", 0.0))
	var level_cooldown_reduction_pct := _get_array_level_value(ACTIVE_COOLDOWN_REDUCTION_PCT_BY_LEVEL, normalized_level, 0.0)
	var has_explicit_cooldown_by_level := skill_data.has("cooldown_by_level")
	result["active_skill_level_cooldown_reduction_pct"] = 0.0 if has_explicit_cooldown_by_level else level_cooldown_reduction_pct
	result["cooldown_by_level_authoritative"] = has_explicit_cooldown_by_level
	if base_cooldown > 0.0 and level_cooldown_reduction_pct > 0.0 and not has_explicit_cooldown_by_level:
		result["base_cooldown"] = base_cooldown
		result["cooldown"] = base_cooldown * maxf(0.10, 1.0 - level_cooldown_reduction_pct / 100.0)
	var base_windup := float(result.get("windup_seconds", 0.0))
	var level_windup_reduction_pct := _get_array_level_value(ACTIVE_WINDUP_REDUCTION_PCT_BY_LEVEL, normalized_level, 0.0)
	result["active_skill_level_windup_reduction_pct"] = level_windup_reduction_pct
	if base_windup > 0.0 and level_windup_reduction_pct > 0.0:
		result["base_windup_seconds"] = base_windup
		result["windup_seconds"] = base_windup * maxf(0.10, 1.0 - level_windup_reduction_pct / 100.0)
	return result


static func _apply_skill_level_values(skill_data: Dictionary, level: int) -> Dictionary:
	var result := skill_data.duplicate(true)
	var normalized_level := clamp_skill_level(level)
	result["level"] = normalized_level
	result["max_level"] = SKILL_LEVEL_MAX
	result["level_label"] = "Lv.%d" % normalized_level
	for raw_key in skill_data.keys():
		var key_text := str(raw_key)
		if not key_text.ends_with("_by_level"):
			continue
		var base_key := key_text.substr(0, key_text.length() - String("_by_level").length())
		result[base_key] = get_skill_level_value(skill_data, base_key, normalized_level, float(result.get(base_key, 0.0)))
	return result


static func _get_array_level_value(values: Array, level: int, fallback: float = 0.0) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(clamp_skill_level(level) - 1, 0, values.size() - 1)
	return float(values[index])


static func _normalize_passive_skill_id_alias(passive_id: String) -> String:
	var normalized := _normalize_skill_id(passive_id)
	if normalized == "":
		return ""
	return str(LEGACY_PASSIVE_ID_ALIASES.get(normalized, normalized))


static func _normalize_skill_pool(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_skill in (value as Array):
			if raw_skill is Dictionary:
				result.append((raw_skill as Dictionary).duplicate(true))
	elif value is Dictionary:
		result.append((value as Dictionary).duplicate(true))
	return result


static func _pick_skill_from_pool(pool: Array[Dictionary], rng: RandomNumberGenerator = null) -> Dictionary:
	if pool.is_empty():
		return {}
	if pool.size() == 1:
		return pool[0].duplicate(true)
	var index := 0
	if rng != null:
		index = rng.randi_range(0, pool.size() - 1)
	else:
		index = randi_range(0, pool.size() - 1)
	return pool[index].duplicate(true)


static func _matches_unlock(entry: Dictionary, context: Dictionary) -> bool:
	var unlock: Variant = entry.get("unlock", {})
	if not (unlock is Dictionary):
		return true
	var unlock_data: Dictionary = unlock as Dictionary
	var required_league := str(unlock_data.get("league_mode", "")).strip_edges().to_lower()
	if required_league != "" and _normalize_league_mode(str(context.get("league_mode", ""))) != required_league:
		return false
	var required_character := str(unlock_data.get("character_type", "")).strip_edges().to_lower()
	if required_character != "" and _normalize_character_type(str(context.get("character_type", ""))) != required_character:
		return false
	return true


static func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _normalize_skill_id(value: String) -> String:
	return value.strip_edges().to_lower()


static func _normalize_league_mode(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")
	if normalized in ["junior", "juniorleague", "주니어", "주니어리그"]:
		return "junior"
	return normalized


static func _normalize_character_type(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["mika", "미카", "smasher", "스매셔"]:
		return "smasher"
	return normalized
