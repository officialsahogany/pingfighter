extends RefCounted

const SETTINGS_PATH := "user://language_settings.cfg"
const SETTINGS_SCHEMA_VERSION := 1
const SETTINGS_SECTION := "language"
const SETTINGS_SCHEMA_KEY := "schema_version"
const SETTINGS_LANGUAGE_KEY := "locale"

const LANGUAGE_KOREAN := "ko"
const LANGUAGE_ENGLISH := "en"
const DEFAULT_LANGUAGE := LANGUAGE_KOREAN
const SUPPORTED_LANGUAGES: Array[String] = [
	LANGUAGE_KOREAN,
	LANGUAGE_ENGLISH,
]

const LANGUAGE_NATIVE_NAMES := {
	LANGUAGE_KOREAN: "한국어",
	LANGUAGE_ENGLISH: "English",
}

const ITEM_DISPLAY_EN := {
	"gauge_charge": "Energy Drink",
	"life_elixir": "Life Elixir",
	"ammo_box": "Ammo Box",
	"doping_potion": "Doping Injector",
	"vitamin_pill": "Vitamin Drink",
	"strange_vial": "Strange Vial",
	"aipill": "AI Pill",
	"pandora_box": "Pandora's Box",
	"grenade": "Grenade",
	"flare": "Flare",
	"tear_gas": "Tear Gas",
	"dynamite": "Dynamite",
	"molotov": "Molotov",
	"stopwatch": "Stopwatch",
	"magnet_field": "Magnetic Field",
	"long_boost": "Growth Potion",
	"regeneration_potion": "Regeneration Potion",
	"holy_barrier": "Holy Barrier",
	"dash_boost": "Dash Boost",
	"wall": "Brick Wall",
	"boomerang": "Boomerang",
	"banana": "Banana",
	"soap": "Soap",
	"spider_mine": "Spider Mine",
	"elixir_of_mastery": "Elixir of Mastery",
	"speedboots": "Speed Boots",
	"speedgear": "Correction Belt",
	"gravitybelt": "Zero-G Belt",
	"sensor": "Danger Sensor Belt",
	"spikeboots": "Spike Boots",
	"dowsing_pendulum": "Dowsing Pendulum",
	"dowsing_goggles": "Dowsing Goggles",
	"yachaman_soul": "Yachaman's Helm",
	"slot_add": "Backpack",
	"chargebag": "Charge Bag",
	"battery": "Battery Pack",
	"revival": "Reincarnation Charm",
	"master": "Repairman's Hammer",
	"gold_digger": "Gold Digger",
	"gold_bar": "Gold Bar",
	"lucky_coin": "Lucky Coin",
	"adversity_armor": "Adversity Armor",
	"shrapnel_armor": "Shrapnel Armor",
	"sage_ring": "Sage Ring",
	"cooltime": "Cooling Ball",
	"timer_belt": "Timer Belt",
	"fuel_pouch": "Fuel Pouch",
	"bluetooth_ring": "Bluetooth Ring",
	"star_detector": "Star Detector",
	"foul_whistle": "Foul Whistle",
	"smartphone": "Smartphone",
	"neural_helmet": "Neural Helmet",
	"venom_mist_gauntlet": "Venom Mist Gauntlet",
	"reinforced_boomerang_gauntlet": "Reinforced Boomerang Glove",
	"commando_arm": "Commando Arm",
	"rainbow_fur_glove": "Rainbow Fur Glove",
	"knee_pads": "Kick Charger",
	"dashgear": "Dash Gear",
	"soul_burst": "Soul Burst",
	"bulkup": "Bulk-Up Suit",
	"dashholder": "Dash Holder",
	"bulletproof_hat": "Bulletproof Hat",
	"spiked_helmet": "Spiked Helm",
	"pandora_legacy": "Pandora's Legacy",
	"megingjord": "Megingjord",
	"ragnarok_hammer": "Ragnarok Hammer",
	"hermes_shoes": "Hermes Shoes",
	"poseidon_trident": "Poseidon's Trident",
	"sacred_laurel": "Sacred Laurel",
	"transcendent_crown": "Transcendent Crown",
	"heavenly_cape": "Heavenly Cape",
	"horn_strawberry_mask": "Horn Strawberry Mask",
	"celestial_armor": "Celestial Immovable Armor",
	"baal_boots": "Baal's Boots",
}

const MYTHIC_DESCRIPTION_EN := {
	"speedboots": "While equipped, increases player movement speed by the rolled option value.",
	"speedgear": "While equipped, left/right turning deceleration is increased by 2.5x.",
	"gravitybelt": "Movement input instantly reaches max speed, and releasing input stops you immediately.",
	"sensor": "Automatically dashes in danger. Auto-dash consumes no gauge or dash tokens.",
	"spikeboots": "Reduces dash recovery and dash-token recharge time by the rolled option value.",
	"dowsing_pendulum": "Pulls field items within the rolled range toward the player's paddle.",
	"dowsing_goggles": "Adds one extra common perk choice at a set chance on perk selection screens.",
	"yachaman_soul": "Just before conceding, may transform you into a bomb warrior form and block the score. During transformation, move speed is 3 and paddle size is 70%.",
	"slot_add": "While equipped, increases active item slots by the rolled option value.",
	"chargebag": "While equipped, gain extra gauge whenever the ball touches a wall.",
	"battery": "While equipped, preserves part of your gauge when moving to the next stage.",
	"revival": "Triggers once before defeat, prevents game over, and restarts the stage from the beginning.",
	"master": "While equipped, lengthens the Brick Wall active item, reduces active item cooldowns, and increases Brick Wall field spawn weight.",
	"gold_digger": "While equipped, increases gold gain and some gauge gain by the rolled option value.",
	"gold_bar": "A sell-only treasure. While held, move speed is reduced by 30%, but it can be sold for 2000 gold.",
	"lucky_coin": "While equipped, field item spawns may create one extra bonus item.",
	"adversity_armor": "After conceding, may create an invincible wall next round and increase ball speed on the next serve.",
	"shrapnel_armor": "When the player's paddle hits the ball, may spend gauge to fire upward shrapnel that briefly stuns and knocks back the boss.",
	"sage_ring": "While equipped, raises the effective level of every invested perk by 1. Move speed and body size are reduced by the rolled option value.",
	"cooltime": "While equipped, reduces active item reuse cooldowns by the rolled option value.",
	"timer_belt": "While equipped, reduces all character skill cooldowns by the rolled option value.",
	"fuel_pouch": "While equipped, increases the player's maximum gauge by the rolled option value.",
	"bluetooth_ring": "While equipped, increases gauge gained when the paddle hits the ball.",
	"star_detector": "While equipped, star point drops may create one extra bonus star point drop.",
	"foul_whistle": "When a round is lost, may cancel the score and restart the round.",
	"smartphone": "Automatically uses recovery items at low gauge and can auto-trigger Stopwatch or Holy Barrier in emergencies.",
	"neural_helmet": "Reduces AI Pill gauge cost and increases AI Pill spawn rate. Direction input cancels AI Pill immediately while active.",
	"venom_mist_gauntlet": "Viper only. Hwarang Kick loads poison into the ball; if the boss guards the infected ball, venom mist forms around the boss and slows movement and special gauge.",
	"reinforced_boomerang_gauntlet": "Upgrades Boomerang into a metal version and improves launch speed, homing, spawn rate, knockback, and stun time.",
	"commando_arm": "Supports thrown combat items. Grenade, Flare, and Molotov fly faster and explode wider; Dynamite, Banana, Soap, and Boomerang ready faster; tear gas lasts longer.",
	"rainbow_fur_glove": "When the paddle hits the ball, may instantly reduce cooldowns on equipped character skills.",
	"knee_pads": "While equipped, hitting the ball with half-dash charges gauge based on base gauge gain.",
	"dashgear": "Increases dash distance and may cancel the next dash-token cost.",
	"soul_burst": "When no dash token is available, spends special gauge to trigger full dash instead of half dash.",
	"bulkup": "While equipped, increases the player's paddle body size.",
	"dashholder": "While equipped, increases maximum dash tokens by 1.",
	"bulletproof_hat": "While equipped, reduces stun duration on the player.",
	"spiked_helmet": "While equipped, reduces knockback speed applied to the player.",
	"pandora_legacy": "May trigger on round victory and lets you choose one of three items.",
	"megingjord": "Grants extra perk selection chances, up to two chained triggers per choice bundle.",
	"ragnarok_hammer": "When returning the ball, spends gauge to create a stun ball that knocks back and stuns the boss on return.",
	"hermes_shoes": "Winged shoes worn by a divine messenger. Increases player movement speed by the rolled option value.",
	"poseidon_trident": "On dash recovery, creates giant whirlpools on both sides that strongly bounce boss-smash balls upward.",
	"sacred_laurel": "Laurel leaves orbit the player and provide protection.",
	"transcendent_crown": "Increases the effect level of all already invested perks by the rolled option value.",
	"heavenly_cape": "Adds one skill orb slot and reduces all player skill cooldowns.",
	"horn_strawberry_mask": "Use the A-D-A-D-A-D command once per Stage 1 run to transform into Horn Strawberry.",
	"celestial_armor": "May ignore incoming stun by spending gauge when it triggers.",
	"baal_boots": "When weather starts, absorbs the current weather with Baal's power and restores gauge. The absorbed weather grants an extra effect for the round.",
	"elixir_of_mastery": "On use, randomly selects one owned perk and raises it to Lv.5. This mythic active item is consumed after use.",
}

const PERK_NAME_EN := {
	"dash_lightweight": "Lightweight",
	"dash_module_control": "Module Control",
	"dash_jump": "Leap",
	"dash_amplification": "Amplification",
	"item_luck": "Luck",
	"item_cooldown_mastery": "Mastery",
	"item_gauge_mastery": "Expertise",
	"active_duration_boost": "Caffeine",
	"passive_polish": "Polish",
	"alchemy": "Alchemy",
	"treasure_map": "Treasure Map",
	"active_slot_expand": "Bag Expansion",
	"move_speed": "Swift",
	"accessory_slot_expand": "Expansion",
	"paddle_bulk": "Bulk Up",
	"boost_charging": "Boost Charging",
	"sacred_laurel": "Laurel Leaf",
	"skill_cooldown_training": "Training",
	"smasher_burst_up": "Burst Up",
	"smasher_dash_spirit": "Dash Spirit",
	"smasher_unlock_magnetic_grip": "Unlock Magnum Grip",
	"smasher_unlock_plasma": "Unlock Plasma",
	"smasher_unlock_recovery": "Unlock Recovery",
	"smasher_unlock_cleanse": "Unlock Cleanse",
	"smasher_unlock_shield_kiting": "Unlock Shield Kiting",
	"smasher_unlock_ghost_shot": "Unlock Ghost Shot",
	"smasher_unlock_warp_gate": "Unlock Warp Gate",
	"smasher_unlock_smasher_wheel": "Unlock Smasher Wheel",
	"smasher_extension_gear": "Extension Gear",
	"viper_unlock_venom_edge": "Unlock Venom Edge",
	"viper_unlock_emp": "Unlock EMP Strike",
	"viper_unlock_chaos_spear": "Unlock Chaos Spear",
	"viper_unlock_dual_glitch": "Unlock Dual Glitch",
	"viper_unlock_ignition_aura": "Unlock Ignition Aura",
	"viper_phantom_kick": "Phantom Kick",
	"viper_hwarang_kick": "Hwarang Kick",
	"viper_dark_blade": "Dark Blade",
	"viper_jetpack_enhance": "Jetpack Upgrade",
	"viper_kick_enhance": "Kick Upgrade",
	"viper_blade_amp": "Blade Amplifier",
	"viper_four_poisons": "Four Poisons",
	"soldier_unlock_net_gun": "Net Trap Gun",
	"soldier_unlock_fire_support": "Fire Support",
	"soldier_unlock_bowling_trap": "Bowling Trap",
	"soldier_unlock_suicide_drone": "Suicide Drone",
	"soldier_unlock_bazooka": "Bazooka",
	"soldier_unlock_ak47": "AK-47",
	"soldier_unlock_beretta": "Beretta",
	"instant_full_gauge": "Full Gauge",
	"instant_dimension_gate": "Dimension Gate",
	"instant_treasure_hunt": "Treasure Hunt",
	"instant_monkey_grace": "Monkey's Grace",
	"instant_refresh": "Refresh",
	"convert_to_gold": "Convert to Gold",
}

const PERK_SUMMARY_EN := {
	"dash_lightweight": "Dash cooldown reduced.",
	"dash_module_control": "Dash recovery reduced.",
	"dash_jump": "Dash distance increased.",
	"dash_amplification": "Maximum dash tokens increased.",
	"item_luck": "Field item spawn delay reduced.",
	"item_cooldown_mastery": "Active item cooldown reduced.",
	"item_gauge_mastery": "Gain skill gauge when using active items.",
	"active_duration_boost": "Timed active item effects last longer.",
	"passive_polish": "Passive effects are strengthened.",
	"alchemy": "Used items may be retained.",
	"treasure_map": "Improves mythic reward odds and passive drop share.",
	"active_slot_expand": "Store more active items.",
	"move_speed": "Movement speed increased.",
	"accessory_slot_expand": "Adds accessory slots.",
	"paddle_bulk": "Paddle size increased.",
	"boost_charging": "Next dash may cost no token and recharge faster.",
	"sacred_laurel": "Protective laurel leaves block the ball.",
	"skill_cooldown_training": "Player skills recharge faster.",
	"smasher_burst_up": "Dash briefly expands the paddle.",
	"smasher_dash_spirit": "Laser afterimages may block the ball during dash.",
	"smasher_unlock_magnetic_grip": "Unlocks Magnum Grip.",
	"smasher_unlock_plasma": "Unlocks Plasma.",
	"smasher_unlock_recovery": "Unlocks Recovery.",
	"smasher_unlock_cleanse": "Unlocks Cleanse.",
	"smasher_unlock_shield_kiting": "Unlocks Shield Kiting.",
	"smasher_unlock_ghost_shot": "Unlocks Ghost Shot.",
	"smasher_unlock_warp_gate": "Unlocks Warp Gate.",
	"smasher_unlock_smasher_wheel": "Unlocks Smasher Wheel.",
	"smasher_extension_gear": "Smasher utility skill durations increased.",
	"viper_unlock_venom_edge": "Unlocks Venom Edge.",
	"viper_unlock_emp": "Unlocks EMP Strike.",
	"viper_unlock_chaos_spear": "Unlocks Chaos Spear.",
	"viper_unlock_dual_glitch": "Unlocks Dual Glitch.",
	"viper_unlock_ignition_aura": "Unlocks Ignition Aura.",
	"viper_phantom_kick": "Enables Phantom Kick follow-up after Martial Kick.",
	"viper_hwarang_kick": "Enables Hwarang Kick after dash-hit timing.",
	"viper_dark_blade": "Enables Dark Blade after Viper combo hits.",
	"viper_jetpack_enhance": "Improves Viper's aerial control.",
	"viper_kick_enhance": "Improves Viper kick skills.",
	"viper_blade_amp": "Strengthens Air Blade and Dark Blade slashes.",
	"viper_four_poisons": "Enhances EMP, Venom Edge, Chaos Spear, and Dual Glitch.",
	"soldier_unlock_net_gun": "Unlocks Net Trap Gun.",
	"soldier_unlock_fire_support": "Unlocks Fire Support.",
	"soldier_unlock_bowling_trap": "Unlocks Bowling Trap.",
	"soldier_unlock_suicide_drone": "Unlocks Suicide Drone.",
	"soldier_unlock_bazooka": "Unlocks Bazooka.",
	"soldier_unlock_ak47": "Unlocks AK-47.",
	"soldier_unlock_beretta": "Unlocks Beretta.",
	"instant_full_gauge": "Instantly fills all gauge and cooldowns.",
	"instant_dimension_gate": "Briefly boosts item spawn flow.",
	"instant_treasure_hunt": "Searches for treasure rewards.",
	"instant_monkey_grace": "Fills empty active slots with supplies.",
	"instant_refresh": "Refreshes the perk choices one more time.",
	"convert_to_gold": "Skip the perk and gain 500 in-game gold.",
}

const CHARACTER_EN := {
	"smasher": {
		"name": "Smasher",
		"character_name": "Mika",
		"class_name": "Smasher",
		"role": "Core Striker",
		"tagline": "Gauge-burst chain smashes",
		"description": "A frontal breakthrough character who pushes the flow with full-power smashes.",
		"special": "Smasher-exclusive skill tree",
	},
	"commando": {
		"name": "Commando",
		"character_name": "Rena",
		"class_name": "Commando",
		"role": "Tactical Control",
		"tagline": "Weapon-switching tactician",
		"description": "A military tactician who reshapes the battlefield with supply calls and weapon swaps.",
		"special": "Combat experience and tactical superiority",
	},
	"baltor": {
		"name": "Baltor",
		"character_name": "Kohaku",
		"class_name": "Baltor",
		"role": "Forge Guardian",
		"tagline": "Forge guardian spacing control",
		"description": "A compact defender who holds low, controls spacing with a forge-lit hammer and Thor Shield, and improves both offense and defense.",
		"special": "Thor Shield and turret synergy modules",
	},
	"optimus": {
		"name": "Optimus",
		"character_name": "Io",
		"class_name": "Optimus",
		"role": "Card Cycler",
		"tagline": "Mechanical comeback breakthrough",
		"description": "Turns crisis momentum around by cycling card-style skills with separate cooldowns.",
		"special": "Smasher-line exclusive equipment",
	},
	"viper": {
		"name": "Viper",
		"character_name": "Serin",
		"class_name": "Viper",
		"role": "Cyber Assassin",
		"tagline": "Chain-slash assassin",
		"description": "A fast combo character who slips through openings with blades and Phantom Kick.",
		"special": "Plasma Blade-exclusive skill tree",
	},
}

const EXACT_TEXT_EN := {
	"체력": "HP",
	"스테이지 진입 준비 중": "Preparing Stage Entry",
	"잠시만 기다려 주세요": "Please wait",
	"전투 데이터 준비 중": "Preparing Battle Data",
	"전투 상태 초기화 중": "Initializing Battle State",
	"스테이지 입장 연출 준비 중": "Preparing Stage Intro",
	"준비 완료": "Ready",
	"스테이지 전환 중": "Changing Stage",
	"다음 보스 예고": "Next Boss Preview",
	"게임 데이터 준비 중": "Preparing Game Data",
	"데이터를 준비하는 중입니다": "Preparing data",
	"나노 조각을 동기화하는 중": "Synchronizing nano shards",
	"전투 준비 완료": "Battle Ready",
	"전투 화면 준비 중": "Preparing Battle Screen",
	"인트로 리소스 확인 중": "Checking Intro Resources",
	"핵심 전투 리소스 불러오는 중": "Loading Core Battle Resources",
	"플레이어 리소스 불러오는 중": "Loading Player Resources",
	"보스 리소스 불러오는 중": "Loading Boss Resources",
	"스매셔 스킬 아이콘 준비 중": "Preparing Smasher Skill Icons",
	"바이퍼 스킬 아이콘 준비 중": "Preparing Viper Skill Icons",
	"전투 캐시 정리 중": "Finalizing Battle Cache",
	"오디오 장치 준비 중": "Preparing Audio Device",
	"스테이지 BGM 준비 중": "Preparing Stage BGM",
	"전투 리소스 마무리 중": "Finishing Battle Resources",
	"시작 모듈 준비 중": "Preparing Startup Modules",
	"아이템 런타임 준비 중": "Preparing Item Runtime",
	"업데이트 런타임 준비 중": "Preparing Update Runtime",
	"공 물리 런타임 준비 중": "Preparing Ball Physics Runtime",
	"드로우 런타임 준비 중": "Preparing Draw Runtime",
	"스테이지 인트로 준비 중": "Preparing Stage Intro",
	"스테이지 런타임 준비 중": "Preparing Stage Runtime",
	"결과 화면 리소스 준비 중": "Preparing Result Screen Resources",
	"첫 프레임 정리 중": "Finalizing First Frame",
	"캐릭터 선택": "Character Select",
	"대표 스킬": "Signature Skills",
	"뒤로": "Back",
	"챔피언리그": "Champion League",
	"신화리그": "Mythic League",
	"난이도": "Difficulty",
	"전신 LIVE2D": "Full-body Live2D",
	"준비중": "Preparing",
	"속도": "Speed",
	"파워": "Power",
	"방어": "Defense",
	"아이템 상자 1개": "1 Item Box",
	"아이템 상자 2개": "2 Item Boxes",
	"아이템 상자 3개": "3 Item Boxes",
	"아이템 상자 4개": "4 Item Boxes",
	"아이템 상자 5개": "5 Item Boxes",
	"액티브 아이템": "Active Item",
	"패시브 아이템": "Passive Item",
	"신화 아이템": "Mythic Item",
	"액티브": "Active",
	"패시브": "Passive",
	"신화": "Mythic",
	"스타포인트": "Star Points",
	"퍽": "Perk",
	"보상": "Reward",
	"획득 퍽": "Acquired Perks",
	"퍽 선택": "Perk Choice",
	"퍽 선택권": "Perk Choice",
	"퍽 정보": "Perk Info",
	"획득 퍽 없음": "No Acquired Perks",
	"이번 결과는 아이템 보상만 획득했습니다.": "This result gained item rewards only.",
	"획득한 퍽 없음": "No acquired perks",
	"획득 보상 없음": "No rewards acquired",
	"획득 아이템": "Acquired Items",
	"획득 골드": "Gold Acquired",
	"다음 스테이지": "Next Stage",
	"나가기": "Exit",
	"획득!": "Acquired!",
	"플레이어 승리": "Player Victory",
	"Live2D 포즈": "Live2D Pose",
	"승리 연출 테스트": "Victory Sequence Test",
	"건들지마": "Don't Touch Me",
	"일반상자": "Normal Box",
	"고급상자": "Advanced Box",
	"신화 확정상자": "Guaranteed Mythic Box",
	"인게임": "In Game",
	"상자 보상": "Box Reward",
	"획득한 퍽 효과를 적용합니다.": "Applies the acquired perk effect.",
	"보물탐색": "Treasure Hunt",
	"아무것도 찾지 못했습니다": "Nothing found",
	"보물탐색: 꽝": "Treasure Hunt: Nothing",
	"목록 준비 중": "Preparing List",
	"리소스 준비 중": "Preparing Resources",
	"캐릭터": "Character",
	"캐릭터 정보": "Character Info",
	"장비": "Gear",
	"장비 슬롯": "Gear Slots",
	"패시브 보관함": "Passive Storage",
	"패시브 아이템 없음": "No Passive Items",
	"능력치": "Stats",
	"롤 옵션": "Roll Options",
	"미장착": "Unequipped",
	"패시브 장비가 연결되면 이 슬롯에 표시됩니다.": "Passive gear appears in this slot when equipped.",
	"보유": "Owned",
	"장착": "Equipped",
	"해금": "Unlock",
	"부위": "Part",
	"머리": "Head",
	"상의": "Top",
	"왼팔": "Left Arm",
	"오른팔": "Right Arm",
	"팔": "Arm",
	"벨트": "Belt",
	"등": "Back",
	"무릎": "Knee",
	"신발": "Shoes",
	"장신구": "Accessory",
	"장신구 1": "Accessory 1",
	"장신구 2": "Accessory 2",
	"장신구 3": "Accessory 3",
	"장신구 4": "Accessory 4",
	"장신": "Acc.",
	"뿔딸기": "Horn Strawberry",
	"이그니션": "Ignition",
	"듀얼": "Dual",
	"팬텀 킥": "Phantom Kick",
	"EMP 스트라이크": "EMP Strike",
	"연금술!": "Alchemy!",
	"재시작!": "Restart!",
	"무효!": "Blocked!",
	"윤회의 부적 발동!": "Reincarnation Charm Activated!",
	"메긴교르드의 효과 발동!": "Megingjord Effect Activated!",
	"판도라의 유산": "Pandora's Legacy",
	"아이템을 선택하세요": "Choose an item",
	"선택": "Select",
	"←/→ / 클릭 / Enter": "←/→ / Click / Enter",
	"엘릭서 오브 마스터리": "Elixir of Mastery",
	"퍽의 운명이 결정됩니다...": "A perk's fate is being decided...",
	"[ Space / Click 으로 계속 ]": "[ Space / Click to Continue ]",
	"Lv.5 달성!": "Lv.5 Reached!",
	"뿔딸기변신!": "Horn Strawberry Transform!",
	"스매셔": "Smasher",
	"바이퍼": "Viper",
	"코만도": "Commando",
	"발토르": "Baltor",
	"옵티머스": "Optimus",
	"미카": "Mika",
	"레나": "Rena",
	"코하쿠": "Kohaku",
	"이오": "Io",
	"세린": "Serin",
	"달지": "Dalji",
	"악어장군": "Alligator General",
	"홍련": "Hongryun",
	"인왕": "Inwang",
	"소림사": "Shaolin Temple",
	"정글": "Jungle",
	"멘헤라": "Menhera",
	"테트리서": "Tetrisser",
	"아카무 리고": "Akamu Rigo",
	"미노타우로스": "Minotaur",
	"최종 관문": "Final Gate",
	"4천왕": "Four Kings",
	"진엔딩": "True Ending",
	"헤드샷!": "Headshot!",
	"레그샷!": "Leg Shot!",
	"상모돌리기": "Sangmo Spin",
	"팽이치기": "Top Strike",
	"타격발동": "On Hit",
	"즉시발동": "Instant",
	"타격": "Hit",
	"즉시": "Instant",
	"공을 휘감아 아래로 몰아붙입니다. 플레이어가 가드하면 즉시 멈춥니다.": "Wraps the ball and drives it downward. Stops immediately if the player guards.",
	"달지가 팽이를 소환합니다. 팽이에 닿은 공은 무작위 방향으로 튕깁니다.": "Dalji summons a spinning top. Balls touching it bounce in random directions.",
	"정글지진": "Jungle Quake",
	"물대포": "Water Cannon",
	"스피드디펜스": "Speed Defense",
	"자동 / 바위 등장 후": "Auto / After Rocks Appear",
	"쿨타임 30초": "Cooldown 30s",
	"쿨타임 40초": "Cooldown 40s",
	"바닥을 흔들어 바위와 충격을 일으킵니다. 압박 단계가 높을수록 낙석이 늘어납니다.": "Shakes the ground to create rocks and impact waves. Higher pressure adds more falling rocks.",
	"물대포를 충전해 전장을 가로지르는 물줄기를 발사합니다.": "Charges a water cannon and fires a stream across the arena.",
	"짧은 시간 동안 보스 이동과 반응이 빨라지고 상태 이상을 막습니다.": "Briefly increases boss movement and reaction, and blocks status effects.",
	"스피드디펜스!": "Speed Defense!",
	"분노 발구르기!": "Rage Stomp!",
	"물대포 충전!": "Water Cannon Charging!",
	"물대포 발사!": "Water Cannon Fire!",
	"정글지진!": "Jungle Quake!",
	"물대포 준비!": "Water Cannon Ready!",
	"지진 준비!": "Quake Ready!",
	"방어 준비!": "Defense Ready!",
	"물대포 조준 중": "Aiming Water Cannon",
	"정글을 흔든다": "Shaking the Jungle",
	"악어장군 분노!": "Alligator General Rage!",
	"물대포 조준!": "Water Cannon Aiming!",
	"물대포 중단!": "Water Cannon Canceled!",
	"방어벽 낙하!": "Barrier Falling!",
	"파편 주의!": "Watch the Shrapnel!",
	"멘헤라걸": "Menhera Girl",
	"눈물샤워": "Tear Shower",
	"저주상자": "Curse Chest",
	"사이코볼": "Psycho Ball",
	"전장 위로 눈물을 떨어뜨려 공을 둔화시키고 보스 쪽 압박을 만듭니다.": "Drops tears across the arena to slow the ball and create boss-side pressure.",
	"저주 상자를 던져 폭발과 연기를 남기고 공의 흐름을 어지럽힙니다.": "Throws a cursed chest that leaves an explosion and smoke, disrupting the ball flow.",
	"사이코볼 상태로 전장을 흔들며 공 충돌에 강한 히트스톱을 겁니다.": "Shakes the arena in Psycho Ball state and applies heavy hitstop on ball collisions.",
	"굴절 자기장": "Refraction Magnetic Field",
	"자기장": "Magnetic Field",
	"25초마다 자동 발동": "Auto every 25s",
	"공을 보스 주변에서 굴절시키고 종료 시 감속 구체를 발사합니다.": "Refracts the ball around the boss and fires a slowing orb when it ends.",
	"위빠사나 명상": "Vipassana Meditation",
	"명상": "Meditation",
	"18초 쿨타임 후 보스 타격": "Boss hit after 18s cooldown",
	"공을 숫자 8 궤도로 붙잡고 명상 종료 후 추가 가속으로 플레이어 쪽으로 쏩니다.": "Holds the ball in a figure-eight path, then fires it toward the player with extra acceleration.",
	"홍련 화염탄": "Hongryun Fireball",
	"홍련 화염구": "Hongryun Fireball",
	"홍련 인페르노": "Hongryun Inferno",
	"홍련폭염": "Hongryun Inferno",
	"화염탄": "Fireball",
	"화염기관": "Flame Machine",
	"인페르노 예열": "Inferno Charging",
	"폭염 예열": "Inferno Charging",
	"쿨타임 3.5~5.0초": "Cooldown 3.5-5.0s",
	"구슬 5칸 / 보스 적중": "5 Orbs / Boss Hit",
	"용 구슬 5칸": "5 Dragon Orbs",
	"쿨타임 변동": "Variable Cooldown",
	"홍련이 화염구를 발사합니다. 맞으면 용 구슬 게이지가 1칸 충전됩니다.": "Hongryun fires a fireball. Taking a hit charges the dragon orb gauge by 1.",
	"5번 맞으면 홍련이 공을 화염 용처럼 돌진시킵니다. 가드와 진입 각도를 흔듭니다.": "After 5 hits, Hongryun sends the ball charging like a fire dragon, disrupting guard timing and entry angles.",
	"전장에 화염 장치를 가동해 불길과 연기로 플레이어 진영을 압박합니다.": "Activates flame devices across the arena, pressuring the player's side with fire and smoke.",
	"자동": "Auto",
	"보스 타격": "Boss Hit",
	"상태": "Status",
	"없음": "None",
	"내구": "Durability",
	"좌클릭": "Left Click",
	"클릭": "Click",
	"즉시 발동": "Instant",
	"발동 중": "Casting",
	"사용됨": "Used",
	"대기": "Waiting",
	"잠김": "Locked",
	"충전": "Charge",
	"쿨타임 25초": "Cooldown 25s",
	"쿨타임 35초": "Cooldown 35s",
	"쿨타임 70초": "Cooldown 70s",
	"탄약": "Ammo",
	"탄환": "Rounds",
	"호출권": "Calls",
	"무제한": "Unlimited",
	"재장전": "Reload",
	"게이지": "Gauge",
	"장착 스킬": "Equipped Skills",
	"대시 거리": "Dash Distance",
	"대시 후딜시간": "Dash Recovery",
	"대시 토큰": "Dash Tokens",
	"퍽 골드": "Perk Gold",
	"방향 전환": "Turn Control",
	"이동 반응": "Movement Response",
	"감속": "Deceleration",
	"패배 방지": "Defeat Prevention",
	"판매가": "Sell Price",
	"이동속도": "Move Speed",
	"이동 속도": "Move Speed",
	"넉백 거리": "Knockback Distance",
	"스턴 시간": "Stun Time",
	"대쉬 개수": "Dash Count",
	"모든 퍽 레벨": "All Perk Levels",
	"스킬 구슬 슬롯": "Skill Orb Slot",
	"변신 비용": "Transform Cost",
	"공 타격 게이지": "Ball-Hit Gauge",
	"추가 선택 확률": "Extra Choice Chance",
	"매직찬스": "Magic Chance",
	"승리시 유산 발동률": "Legacy Trigger on Win",
	"발동 확률": "Trigger Chance",
	"발동확률": "Trigger Chance",
	"공속 증가": "Ball Speed Increase",
	"게이지 소모": "Gauge Cost",
	"월계수 잎": "Laurel Leaves",
	"모든 퍽 레벨 증가": "All Perk Level Increase",
	"쿨타임": "Cooldown",
	"소용돌이 크기": "Whirlpool Size",
	"스킬 쿨타임 감소": "Skill Cooldown Reduction",
	"게이지 회복": "Gauge Recovery",
	"변신 지속시간": "Transform Duration",
	"끌어당기는 범위": "Pull Range",
	"추가 퍽 등장 확률": "Extra Perk Appearance Chance",
	"변신 부활 확률": "Transform Revival Chance",
	"자동대쉬 쿨타임": "Auto-Dash Cooldown",
	"슬롯 추가": "Slot Add",
	"벽 반사 게이지": "Wall-Bounce Gauge",
	"게이지 보존": "Gauge Preservation",
	"벽돌 길이": "Brick Wall Length",
	"아이템 쿨타임": "Item Cooldown",
	"벽돌 스폰율": "Brick Wall Spawn Rate",
	"골드 획득량": "Gold Gain",
	"더블 스폰 확률": "Double Spawn Chance",
	"보호 지속시간": "Protection Duration",
	"파편 개수": "Shrapnel Count",
	"넉백 단계": "Knockback Level",
	"이동속도 감소": "Move Speed Reduction",
	"몸집크기 감소": "Body Size Reduction",
	"스킬 쿨타임": "Skill Cooldown",
	"최대 게이지": "Max Gauge",
	"게이지 획득량": "Gauge Gain",
	"스타포인트 드랍율": "Star Point Drop Rate",
	"라운드 패배 시 무효화 확률": "Round-Loss Cancel Chance",
	"AI알약 게이지 소모": "AI Pill Gauge Cost",
	"AI알약 스폰율": "AI Pill Spawn Rate",
	"독안개 지속시간": "Venom Mist Duration",
	"부메랑 발사속도": "Boomerang Launch Speed",
	"부메랑 유도성능": "Boomerang Homing",
	"부메랑 스폰율": "Boomerang Spawn Rate",
	"투척 속도": "Throw Speed",
	"폭발 범위": "Explosion Radius",
	"연막탄 지속시간": "Tear Gas Duration",
	"준비시간 단축": "Ready Time Reduction",
	"대쉬 거리": "Dash Distance",
	"부스트차징 발동확률": "Boost Charging Chance",
	"하프대쉬 게이지": "Half-Dash Gauge",
	"대쉬토큰 회복 시간": "Dash Token Recovery Time",
	"몸집크기": "Body Size",
	"넉백 저항력": "Knockback Resistance",
	"대시쿨타임": "Dash Cooldown",
	"아이템쿨타임": "Item Cooldown",
	"화재": "Fire",
	"빙판": "Ice",
	"소나기": "Shower",
	"우박": "Hail",
	"사막화": "Desertification",
	"화재가 번집니다": "Fire spreads",
	"빙판이 깔립니다": "Ice spreads across the field",
	"소나기가 쏟아집니다": "A shower pours down",
	"우박이 떨어집니다": "Hail starts falling",
	"사막화가 시작됩니다": "Desertification begins",
	"미풍이 잦아들었습니다": "The breeze fades",
	"강풍이 멎었습니다": "The gust stops",
	"불길이 꺼졌습니다": "The flames go out",
	"빙판이 녹았습니다": "The ice melts",
	"소나기가 그쳤습니다": "The shower stops",
	"우박이 그쳤습니다": "The hail stops",
	"모래가 가라앉았습니다": "The sand settles",
	"제한 없음": "Unlimited",
	"약함": "Weak",
	"낮음": "Low",
	"보통": "Normal",
	"강함": "Strong",
	"최대": "Max",
	"절대적인": "Absolute",
	"궁극의": "Ultimate",
	"초신성의": "Supernova",
	"신화적인": "Mythic",
	"절대무쌍한": "Peerless",
	"고대영웅의": "Ancient Hero's",
	"고급": "Advanced",
	"장인의": "Artisan",
	"고품질의": "High-Quality",
	"신성한": "Divine",
	"명장의": "Masterwork",
	"완벽한": "Perfect",
	"영롱한": "Radiant",
	"찬란한": "Brilliant",
	"비범한": "Exceptional",
	"고성능의": "High-Performance",
	"세련된": "Refined",
	"괜찮은": "Solid",
	"평범한": "Standard",
	"무난한": "Reliable",
	"실용적인": "Practical",
	"준수한": "Balanced",
	"보강된": "Reinforced",
	"균형 잡힌": "Well-Balanced",
	"낡은": "Old",
	"오래된": "Aged",
	"녹슨": "Rusty",
	"손상된": "Damaged",
	"떼묻은": "Worn",
	"싸구려": "Cheap",
	"저급의": "Low-Grade",
	"부실한": "Flimsy",
	"회": "time(s)",
	"개": "pc",
	"칸": "slot(s)",
	"골드": "gold",
	"초": "s",
}

const QUALITY_PREFIXES_EN := {
	"top": ["Absolute", "Ultimate", "Supernova", "Mythic", "Peerless", "Ancient Hero's"],
	"high": ["Advanced", "Artisan", "High-Quality", "Divine", "Masterwork", "Perfect", "Radiant", "Brilliant", "Exceptional", "High-Performance"],
	"mid": ["Refined", "Solid", "Standard", "Reliable", "Practical", "Balanced", "Reinforced", "Well-Balanced"],
	"low": ["Old", "Aged", "Rusty", "Damaged", "Worn", "Cheap", "Low-Grade", "Flimsy", ""],
}

const TEXT := {
	LANGUAGE_KOREAN: {
		"app.title": "디스크하츠 - 링피아",
		"pause.title": "일시정지",
		"pause.continue": "계속",
		"pause.character_info": "캐릭터정보",
		"pause.options": "옵션",
		"settings.title": "설정",
		"settings.tab.sound": "사운드",
		"settings.tab.display": "디스플레이",
		"settings.tab.controls": "조작",
		"settings.tab.language": "언어",
		"settings.back": "뒤로가기",
		"settings.close": "닫기",
		"settings.save": "저장",
		"sound.bgm_volume": "BGM 볼륨",
		"sound.sfx_volume": "효과음 볼륨",
		"display.mode": "화면 모드",
		"display.mode.fullscreen": "전체화면",
		"display.mode.exclusive": "독점",
		"display.mode.windowed": "창모드",
		"display.desc.exclusive": "DWM 합성을 우회하는 독점 전체화면으로 표시합니다",
		"display.desc.fullscreen": "네이티브 해상도 전체화면으로 표시합니다",
		"display.desc.windowed": "필러 배경 포함 창모드로 표시합니다",
		"display.render_fps": "렌더 FPS",
		"display.fps.unlimited": "제한 없음",
		"display.fps.monitor": "모니터 %d Hz",
		"display.remember.title": "현재 화면 설정 저장",
		"display.remember.subtitle": "다음 실행부터 이 화면 모드와 주사율을 사용",
		"display.auto60.title": "60Hz 모드 자동 전환",
		"display.auto60.subtitle": "특정 모니터에서 60Hz 페이싱이 필요할 때만 사용",
		"display.recommend.apply": "권장값 적용",
		"display.apply60": "60Hz 모드",
		"display.recommendation.ready": "%dHz 모니터 감지: 현재 주사율에 렌더 FPS를 자동으로 맞춥니다.\n모니터를 바꾸면 다음 적용 시 새 주사율을 따라갑니다.",
		"display.recommendation.monitor": "%dHz 모니터 감지: 렌더 FPS는 현재 주사율을 따라갑니다.\n독점 전체화면과 VSync Auto가 가장 깔끔합니다.",
		"display.recommendation.default": "%dHz 모니터 감지: 렌더 FPS를 모니터 Hz로 두면 자동으로 맞춰집니다.\n권장값 적용을 누르면 현재 주사율 기반 설정으로 저장합니다.",
		"display.recommendation.fallback": "렌더 FPS를 모니터 Hz로 두면 현재 주사율에 자동으로 맞춰집니다.\n독점 전체화면과 VSync Auto를 권장합니다.",
		"controls.device": "입력 장치",
		"controls.keyboard_mouse": "키보드+마우스",
		"controls.joypad": "조이패드",
		"controls.vibration": "진동 감도",
		"controls.map.move": "이동",
		"controls.map.dash_skill": "대쉬 / 스킬",
		"controls.map.active_item": "액티브 아이템",
		"controls.map.supply_hold": "보급 홀드",
		"controls.map.weapon_switch": "무기 전환",
		"controls.map.confirm_cancel_pause": "확인 / 취소 / 일시정지",
		"controls.value.joypad.move": "왼스틱 / D-pad",
		"controls.value.joypad.dash_skill": "대쉬: B 또는 아래 / 스킬: A / X / RT",
		"controls.value.joypad.active_item": "LB/RB 또는 오른스틱 좌우 선택 / Y 사용",
		"controls.value.joypad.supply_hold": "LT",
		"controls.value.joypad.weapon_switch": "오른스틱 위/아래 / R3",
		"controls.value.joypad.confirm_cancel_pause": "A / B / 메뉴",
		"controls.value.keyboard.move": "A,D,W,S / 방향키",
		"controls.value.keyboard.dash_skill": "Space / X / 마우스 왼쪽",
		"controls.value.keyboard.active_item": "1 / 2 / 3",
		"controls.value.keyboard.supply_hold": "S / 마우스 오른쪽",
		"controls.value.keyboard.weapon_switch": "마우스 휠 / 가운데",
		"controls.value.keyboard.confirm_cancel_pause": "Enter / Esc",
		"vibration.1": "약함",
		"vibration.2": "낮음",
		"vibration.3": "보통",
		"vibration.4": "강함",
		"vibration.5": "최대",
		"language.title": "언어",
		"language.subtitle": "언어는 즉시 저장되고 적용됩니다.",
		"language.current": "현재 언어: %s",
		"language.ko": "한국어",
		"language.en": "English",
		"main_menu.quit_prompt": "나가시겠습니까?",
		"main_menu.yes": "예",
		"main_menu.no": "아니오",
	},
	LANGUAGE_ENGLISH: {
		"app.title": "DiskHearts - Ringpia",
		"pause.title": "Paused",
		"pause.continue": "Continue",
		"pause.character_info": "Character Info",
		"pause.options": "Options",
		"settings.title": "Settings",
		"settings.tab.sound": "Sound",
		"settings.tab.display": "Display",
		"settings.tab.controls": "Controls",
		"settings.tab.language": "Language",
		"settings.back": "Back",
		"settings.close": "Close",
		"settings.save": "Save",
		"sound.bgm_volume": "BGM Volume",
		"sound.sfx_volume": "SFX Volume",
		"display.mode": "Display Mode",
		"display.mode.fullscreen": "Fullscreen",
		"display.mode.exclusive": "Exclusive",
		"display.mode.windowed": "Windowed",
		"display.desc.exclusive": "Use exclusive fullscreen and bypass DWM composition.",
		"display.desc.fullscreen": "Use native-resolution fullscreen.",
		"display.desc.windowed": "Use windowed mode with pillar backgrounds.",
		"display.render_fps": "Render FPS",
		"display.fps.unlimited": "Unlimited",
		"display.fps.monitor": "Monitor %d Hz",
		"display.remember.title": "Save Current Display Settings",
		"display.remember.subtitle": "Use this display mode and refresh pacing next launch",
		"display.auto60.title": "Auto-Switch to 60Hz",
		"display.auto60.subtitle": "Use only when a monitor needs 60Hz pacing",
		"display.recommend.apply": "Apply Recommended",
		"display.apply60": "60Hz Mode",
		"display.recommendation.ready": "%dHz monitor detected: render FPS will follow the current refresh rate.\nIf you switch monitors, it updates on the next apply.",
		"display.recommendation.monitor": "%dHz monitor detected: render FPS follows the current refresh rate.\nExclusive fullscreen with VSync Auto is recommended.",
		"display.recommendation.default": "%dHz monitor detected: set render FPS to monitor Hz for automatic pacing.\nApply Recommended saves settings based on the current refresh rate.",
		"display.recommendation.fallback": "Set render FPS to monitor Hz for automatic refresh-rate pacing.\nExclusive fullscreen with VSync Auto is recommended.",
		"controls.device": "Input Device",
		"controls.keyboard_mouse": "Keyboard+Mouse",
		"controls.joypad": "Gamepad",
		"controls.vibration": "Vibration Sensitivity",
		"controls.map.move": "Move",
		"controls.map.dash_skill": "Dash / Skill",
		"controls.map.active_item": "Active Item",
		"controls.map.supply_hold": "Hold Supply",
		"controls.map.weapon_switch": "Switch Weapon",
		"controls.map.confirm_cancel_pause": "Confirm / Cancel / Pause",
		"controls.value.joypad.move": "Left Stick / D-pad",
		"controls.value.joypad.dash_skill": "Dash: B or Down / Skill: A / X / RT",
		"controls.value.joypad.active_item": "LB/RB or Right Stick Left/Right to select / Y to use",
		"controls.value.joypad.supply_hold": "LT",
		"controls.value.joypad.weapon_switch": "Right Stick Up/Down / R3",
		"controls.value.joypad.confirm_cancel_pause": "A / B / Menu",
		"controls.value.keyboard.move": "A,D,W,S / Arrow Keys",
		"controls.value.keyboard.dash_skill": "Space / X / Left Mouse",
		"controls.value.keyboard.active_item": "1 / 2 / 3",
		"controls.value.keyboard.supply_hold": "S / Right Mouse",
		"controls.value.keyboard.weapon_switch": "Mouse Wheel / Middle",
		"controls.value.keyboard.confirm_cancel_pause": "Enter / Esc",
		"vibration.1": "Weak",
		"vibration.2": "Low",
		"vibration.3": "Normal",
		"vibration.4": "Strong",
		"vibration.5": "Max",
		"language.title": "Language",
		"language.subtitle": "Language is saved and applied immediately.",
		"language.current": "Current Language: %s",
		"language.ko": "Korean",
		"language.en": "English",
		"main_menu.quit_prompt": "Quit the game?",
		"main_menu.yes": "Yes",
		"main_menu.no": "No",
	},
}

static var _cached_language := ""


static func apply_saved_language() -> String:
	var language := get_language()
	_apply_engine_locale(language)
	return language


static func get_language() -> String:
	if not _cached_language.is_empty():
		return _cached_language
	var config := _load_settings()
	_cached_language = normalize_language(str(config.get_value(SETTINGS_SECTION, SETTINGS_LANGUAGE_KEY, DEFAULT_LANGUAGE)))
	_apply_engine_locale(_cached_language)
	return _cached_language


static func set_language(language: String) -> String:
	var normalized := normalize_language(language)
	_cached_language = normalized
	_apply_engine_locale(normalized)
	var config := _load_settings()
	config.set_value(SETTINGS_SECTION, SETTINGS_SCHEMA_KEY, SETTINGS_SCHEMA_VERSION)
	config.set_value(SETTINGS_SECTION, SETTINGS_LANGUAGE_KEY, normalized)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Failed to save language settings: %s" % SETTINGS_PATH)
	return normalized


static func reset_cache_for_tests() -> void:
	_cached_language = ""


static func normalize_language(language: String) -> String:
	var normalized := language.strip_edges().to_lower()
	if normalized == "en_us" or normalized == "en-us":
		normalized = LANGUAGE_ENGLISH
	if normalized == "ko_kr" or normalized == "ko-kr":
		normalized = LANGUAGE_KOREAN
	if SUPPORTED_LANGUAGES.has(normalized):
		return normalized
	return DEFAULT_LANGUAGE


static func get_language_options() -> Array[String]:
	return SUPPORTED_LANGUAGES.duplicate()


static func get_native_language_name(language: String) -> String:
	var normalized := normalize_language(language)
	return str(LANGUAGE_NATIVE_NAMES.get(normalized, normalized))


static func translate(key: String, fallback: String = "") -> String:
	var language := get_language()
	var table: Dictionary = TEXT.get(language, {})
	if table.has(key):
		return str(table[key])
	var fallback_table: Dictionary = TEXT.get(DEFAULT_LANGUAGE, {})
	if fallback_table.has(key):
		return str(fallback_table[key])
	if not fallback.is_empty():
		return fallback
	return key


static func translate_text(text: String, fallback: String = "") -> String:
	if get_language() != LANGUAGE_ENGLISH:
		return text
	if text.is_empty():
		return text
	if EXACT_TEXT_EN.has(text):
		return str(EXACT_TEXT_EN[text])
	if not fallback.is_empty():
		return fallback
	var translated := _translate_known_patterns(text)
	if translated != "":
		return translated
	return text


static func get_quality_prefixes(tier: String, fallback: Array) -> Array:
	if get_language() != LANGUAGE_ENGLISH:
		return fallback
	return _get_array(QUALITY_PREFIXES_EN.get(tier, fallback)).duplicate()


static func localize_character_list(characters: Array) -> Array:
	if get_language() != LANGUAGE_ENGLISH:
		return characters
	var result: Array = []
	for character_value in characters:
		if character_value is Dictionary:
			result.append(localize_character_data(character_value))
		else:
			result.append(character_value)
	return result


static func localize_character_data(character_data: Dictionary) -> Dictionary:
	if get_language() != LANGUAGE_ENGLISH:
		return character_data
	var result := character_data.duplicate(true)
	var key := str(result.get("runtime_id", result.get("key", result.get("id", "")))).strip_edges().to_lower()
	if key == "soldier":
		key = "commando"
	var localized: Dictionary = CHARACTER_EN.get(key, {})
	for field in localized.keys():
		result[str(field)] = localized[field]
	var stats_value: Variant = result.get("stats", {})
	if stats_value is Dictionary:
		var stats: Dictionary = stats_value
		var localized_stats: Dictionary = {}
		for stat_key_value in stats.keys():
			var stat_key := str(stat_key_value)
			localized_stats[translate_text(stat_key)] = stats[stat_key_value]
		result["stats"] = localized_stats
	return result


static func localize_item_data(item_data: Dictionary) -> Dictionary:
	if get_language() != LANGUAGE_ENGLISH:
		return item_data
	var result := _localize_visible_dictionary(item_data.duplicate(true), "")
	var item_name := str(result.get("name", result.get("effect", "")))
	if ITEM_DISPLAY_EN.has(item_name):
		result["display_name"] = str(ITEM_DISPLAY_EN[item_name])
		result["korean_name"] = str(ITEM_DISPLAY_EN[item_name])
	if MYTHIC_DESCRIPTION_EN.has(item_name):
		result["description"] = str(MYTHIC_DESCRIPTION_EN[item_name])
	if result.has("qualified_display_name"):
		result["qualified_display_name"] = format_item_display_name(result)
	return result


static func localize_perk_data(perk_data: Dictionary) -> Dictionary:
	if get_language() != LANGUAGE_ENGLISH:
		return perk_data
	var result := _localize_visible_dictionary(perk_data.duplicate(true), "")
	var perk_id := str(result.get("id", ""))
	if PERK_NAME_EN.has(perk_id):
		result["name"] = str(PERK_NAME_EN[perk_id])
	if PERK_SUMMARY_EN.has(perk_id):
		result["description"] = str(PERK_SUMMARY_EN[perk_id])
		result["detail"] = str(PERK_SUMMARY_EN[perk_id])
	var descriptions_value: Variant = result.get("descriptions", {})
	if descriptions_value is Dictionary:
		var descriptions: Dictionary = descriptions_value
		var localized_descriptions: Dictionary = {}
		for level_value in descriptions.keys():
			localized_descriptions[level_value] = str(PERK_SUMMARY_EN.get(perk_id, translate_text(str(descriptions[level_value]))))
		result["descriptions"] = localized_descriptions
	return result


static func localize_reward_data(reward_data: Dictionary) -> Dictionary:
	if get_language() != LANGUAGE_ENGLISH:
		return reward_data
	return _localize_visible_dictionary(reward_data.duplicate(true), "")


static func format_stage_label(stage: int) -> String:
	if get_language() == LANGUAGE_ENGLISH:
		return "Stage %d" % stage
	return "스테이지 %d" % stage


static func format_stage_character_label(stage: int, character_name: String) -> String:
	var localized_name := translate_text(character_name)
	if get_language() == LANGUAGE_ENGLISH:
		return "Stage %d / %s" % [stage, localized_name]
	return "스테이지 %d  /  %s" % [stage, localized_name]


static func format_stage_result_label(stage: int) -> String:
	if get_language() == LANGUAGE_ENGLISH:
		return "Stage %d Results" % stage
	return "스테이지 %d 결과" % stage


static func format_stage_transition_subtitle(stage: int) -> String:
	if get_language() == LANGUAGE_ENGLISH:
		return "Stage %d / Next Boss Preview" % stage
	return "스테이지 %d  /  다음 보스 예고" % stage


static func format_stage_transition_status(stage: int) -> String:
	if get_language() == LANGUAGE_ENGLISH:
		return "Preparing Stage %d boss data" % stage
	return "스테이지 %d 보스 데이터를 준비 중" % stage


static func format_item_box_summary(count: int) -> String:
	if get_language() == LANGUAGE_ENGLISH:
		return "%d Item Box%s" % [count, "" if count == 1 else "es"]
	return "아이템 상자 %d개" % count


static func format_item_display_name(item_data: Dictionary) -> String:
	var base_name := str(item_data.get("display_name", item_data.get("korean_name", item_data.get("name", "장비"))))
	base_name = translate_text(base_name, base_name)
	var prefix := translate_text(str(item_data.get("name_prefix", "")).strip_edges())
	if prefix == "":
		return base_name
	return "%s %s" % [prefix, base_name]


static func format_select_label(name: String) -> String:
	var localized_name := translate_text(name)
	if get_language() == LANGUAGE_ENGLISH:
		return "Select %s" % localized_name
	return "%s 선택" % localized_name


static func _localize_visible_dictionary(source: Dictionary, parent_key: String) -> Dictionary:
	var result: Dictionary = {}
	for key_value in source.keys():
		var key := str(key_value)
		var value: Variant = source[key_value]
		if value is Dictionary:
			result[key_value] = _localize_visible_dictionary(value, key)
		elif value is Array:
			result[key_value] = _localize_visible_array(value, key)
		elif value is String:
			result[key_value] = _localize_visible_string(key, str(value), parent_key)
		else:
			result[key_value] = value
	return result


static func _localize_visible_array(source: Array, parent_key: String) -> Array:
	var result: Array = []
	for value in source:
		if value is Dictionary:
			result.append(_localize_visible_dictionary(value, parent_key))
		elif value is Array:
			result.append(_localize_visible_array(value, parent_key))
		elif value is String:
			result.append(_localize_visible_string(parent_key, str(value), parent_key))
		else:
			result.append(value)
	return result


static func _localize_visible_string(key: String, value: String, parent_key: String) -> String:
	var visible_keys := {
		"display_name": true,
		"korean_name": true,
		"qualified_display_name": true,
		"description": true,
		"detail": true,
		"label": true,
		"title": true,
		"subtitle": true,
		"eyebrow": true,
		"summary": true,
		"text": true,
		"status": true,
		"hint": true,
		"name_prefix": true,
		"unit": true,
	}
	if visible_keys.has(key) or parent_key == "descriptions":
		return translate_text(value)
	return value


static func _translate_known_patterns(text: String) -> String:
	if text.begins_with("게이지 "):
		return "Gauge %s" % text.substr("게이지 ".length())
	if text.begins_with("대시 토큰 "):
		return "Dash Tokens %s" % text.substr("대시 토큰 ".length())
	if text.begins_with("선택 대기: "):
		return "Choices Waiting: %s" % text.substr("선택 대기: ".length())
	if text.begins_with("선택 대기 "):
		return "Choices Waiting %s" % text.substr("선택 대기 ".length())
	if text.begins_with("퍽 골드: "):
		return "Perk Gold: %s" % text.substr("퍽 골드: ".length())
	if text.begins_with("퍽 골드 "):
		return "Perk Gold %s" % text.substr("퍽 골드 ".length())
	if text.begins_with("추가 ") and text.ends_with("개"):
		return "Extra %s" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
	if text.begins_with("보유 ") and text.find(" / 장착 ") >= 0:
		var parts := text.replace("보유 ", "").split(" / 장착 ", false)
		if parts.size() == 2:
			return "Owned %s / Equipped %s" % [parts[0], parts[1]]
	if text.begins_with("장착: "):
		return "Equipped: %s" % translate_text(text.substr("장착: ".length()))
	if text.begins_with("부위 : "):
		return "Part: %s" % translate_text(text.substr("부위 : ".length()))
	if text.begins_with("슬롯 "):
		return "Slot %s" % text.substr("슬롯 ".length())
	if text.begins_with("비용 ") and text.find("  쿨타임 ") >= 0:
		var skill_parts := text.replace("비용 ", "").split("  쿨타임 ", false)
		if skill_parts.size() == 2:
			return "Cost %s  Cooldown %s" % [skill_parts[0], translate_text(skill_parts[1])]
	if text.begins_with("스테이지 ") and text.ends_with(" 결과 화면"):
		var stage_result := text.replace("스테이지 ", "").replace(" 결과 화면", "")
		return "Stage %s Result Screen" % stage_result
	if text.begins_with("스테이지 ") and text.ends_with(" 결과"):
		var stage_number := text.replace("스테이지 ", "").replace(" 결과", "")
		return "Stage %s Results" % stage_number
	if text.begins_with("스테이지 "):
		var stage_label := text.replace("스테이지 ", "")
		if stage_label.is_valid_int():
			return "Stage %s" % stage_label
	if text.ends_with(" 선택"):
		return "Select %s" % translate_text(text.substr(0, text.length() - 3))
	if text.begins_with("쿨타임 ") and text.ends_with("초"):
		var seconds := text.replace("쿨타임 ", "").replace("초", "")
		return "Cooldown %ss" % seconds
	if text.ends_with("초"):
		var plain_seconds := text.substr(0, text.length() - 1)
		if plain_seconds.is_valid_float():
			return "%ss" % plain_seconds
	if text.ends_with(" 발견"):
		return "%s Found" % translate_text(text.substr(0, text.length() - 3))
	return ""


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _load_settings() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH):
		var result := config.load(SETTINGS_PATH)
		if result != OK:
			return ConfigFile.new()
	return config


static func _apply_engine_locale(language: String) -> void:
	TranslationServer.set_locale(normalize_language(language))
