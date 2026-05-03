extends RefCounted

const CARD_ROOT := "res://assets/ui/character_cards/"
const LIVE2D_ROOT := "res://assets/ui/character_live2d/"


static func get_characters() -> Array:
	return [
		{
			"id": "ufo_player",
			"runtime_id": "smasher",
			"name": "스매셔",
			"role": "Core Striker",
			"description": "게이지 폭발로 연속 파워스매시.\n공격 템포를 쥐는 핵심 스트라이커.",
			"special": "스매시 전용 스킬트리 보유",
			"stats": {"속도": 4, "파워": 7, "방어": 4},
			"unlocked": true,
			"card_color": Color8(0, 230, 255),
			"glow_color": Color8(0, 200, 255),
			"portrait_path": CARD_ROOT + "smasher_card_back_otaku_anime_imagegen_v3.png",
			"live2d_preview_still_path": LIVE2D_ROOT + "smasher_live2d_fullframe_sheet_v2.png",
			"live2d_fullframe_sheet_path": LIVE2D_ROOT + "smasher_live2d_fullframe_sheet_v2.png",
			"live2d_fullframe_cols": 1,
			"live2d_fullframe_rows": 1,
			"live2d_fullframe_count": 1,
			"live2d_fullframe_interval": 0.16,
			"live2d_canvas_locked": false,
			"live2d_layers": {},
		},
		{
			"id": "soldier",
			"runtime_id": "soldier",
			"name": "코만도",
			"role": "Tactical Control",
			"description": "보급 호출로 전장을 재구성.\n화기 전환으로 템포를 조율.",
			"special": "전투 경험과 전술적 우위",
			"stats": {"속도": 6, "파워": 6, "방어": 6},
			"unlocked": true,
			"card_color": Color8(95, 145, 68),
			"glow_color": Color8(120, 180, 82),
			"portrait_path": CARD_ROOT + "commando_card_back_otaku_anime_imagegen_v3.png",
			"live2d_layers": _layer_paths("commando"),
		},
		{
			"id": "blacksmith",
			"runtime_id": "blacksmith",
			"name": "발토르",
			"role": "Forge Defender",
			"description": "토르쉴드로 거리 제어.\n단조 버프로 공수 동시 강화.",
			"special": "토르쉴드·포탑 시너지 모듈",
			"stats": {"속도": 5, "파워": 7, "방어": 5},
			"unlocked": true,
			"card_color": Color8(190, 137, 76),
			"glow_color": Color8(235, 180, 95),
			"portrait_path": CARD_ROOT + "baltor_card_back_otaku_anime_imagegen_v3.png",
			"live2d_layers": _layer_paths("baltor"),
		},
		{
			"id": "optimus",
			"runtime_id": "optimus",
			"name": "옵티머스",
			"role": "Mecha Breaker",
			"description": "배터리가 닳아 위기의 순간,\n기계 강화로 역전을 노린다.",
			"special": "스매셔 계열 전용 장비",
			"stats": {"속도": 5, "파워": 7, "방어": 5},
			"unlocked": true,
			"card_color": Color8(120, 200, 255),
			"glow_color": Color8(150, 220, 255),
			"portrait_path": CARD_ROOT + "optimus_card_back_otaku_anime_imagegen_v3.png",
			"live2d_layers": _layer_paths("optimus"),
		},
		{
			"id": "viper",
			"runtime_id": "viper",
			"name": "바이퍼",
			"role": "Cyber Assassin",
			"description": "빠른 연속 슬래시로 적을 베어내는\n사이버 어쌔신.",
			"special": "플라즈마 블레이드 전용 스킬트리",
			"stats": {"속도": 4, "파워": 5, "방어": 3},
			"unlocked": true,
			"card_color": Color8(178, 76, 255),
			"glow_color": Color8(190, 90, 255),
			"portrait_path": CARD_ROOT + "viper_card_back_otaku_anime_imagegen_v3.png",
			"live2d_layers": _layer_paths("viper"),
		},
	]


static func _layer_paths(character_key: String) -> Dictionary:
	return {
		"back_hair": LIVE2D_ROOT + character_key + "_back_hair.png",
		"body": LIVE2D_ROOT + character_key + "_body.png",
		"arm_back": LIVE2D_ROOT + character_key + "_arm_back.png",
		"head": LIVE2D_ROOT + character_key + "_head.png",
		"eyes_open": LIVE2D_ROOT + character_key + "_eyes_open.png",
		"eyes_closed": LIVE2D_ROOT + character_key + "_eyes_closed.png",
		"mouth": LIVE2D_ROOT + character_key + "_mouth.png",
		"front_hair": LIVE2D_ROOT + character_key + "_front_hair.png",
		"arm_front": LIVE2D_ROOT + character_key + "_arm_front.png",
		"accessory": LIVE2D_ROOT + character_key + "_accessory.png",
	}


static func _registered_layer_paths(character_key: String) -> Dictionary:
	return {
		"back_hair": LIVE2D_ROOT + character_key + "_registered_back_hair.png",
		"body": LIVE2D_ROOT + character_key + "_registered_body.png",
		"arm_back": LIVE2D_ROOT + character_key + "_registered_arm_back.png",
		"head": LIVE2D_ROOT + character_key + "_registered_head.png",
		"eyes_open": LIVE2D_ROOT + character_key + "_registered_eyes_open.png",
		"eyes_closed": LIVE2D_ROOT + character_key + "_registered_eyes_closed.png",
		"mouth": LIVE2D_ROOT + character_key + "_registered_mouth.png",
		"front_hair": LIVE2D_ROOT + character_key + "_registered_front_hair.png",
		"arm_front": LIVE2D_ROOT + character_key + "_registered_arm_front.png",
		"accessory": LIVE2D_ROOT + character_key + "_registered_accessory.png",
	}
