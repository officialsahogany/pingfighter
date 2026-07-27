extends RefCounted

const MythicItemCatalogBaseMetadata := preload("res://scripts/items/mythic_item_catalog_base_metadata.gd")
const MythicItemCatalogIconMetadata := preload("res://scripts/items/mythic_item_catalog_icon_metadata.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var base_metadata_helper: Object = MythicItemCatalogBaseMetadata.new()
var icon_metadata_helper: Object = MythicItemCatalogIconMetadata.new()

const ITEM_BUILD_METHODS := {
	"speedboots": "_build_speedboots",
	"speedgear": "_build_speedgear",
	"gravitybelt": "_build_gravitybelt",
	"sensor": "_build_sensor",
	"spikeboots": "_build_spikeboots",
	"dowsing_pendulum": "_build_dowsing_pendulum",
	"dowsing_goggles": "_build_dowsing_goggles",
	"slot_add": "_build_slot_add",
	"chargebag": "_build_chargebag",
	"battery": "_build_battery",
	"revival": "_build_revival",
	"master": "_build_master",
	"gold_digger": "_build_gold_digger",
	"gold_bar": "_build_gold_bar",
	"lucky_coin": "_build_lucky_coin",
	"adversity_armor": "_build_adversity_armor",
	"shrapnel_armor": "_build_shrapnel_armor",
	"sage_ring": "_build_sage_ring",
	"cooltime": "_build_cooltime",
	"timer_belt": "_build_timer_belt",
	"fuel_pouch": "_build_fuel_pouch",
	"bluetooth_ring": "_build_bluetooth_ring",
	"star_detector": "_build_star_detector",
	"foul_whistle": "_build_foul_whistle",
	"smartphone": "_build_smartphone",
	"neural_helmet": "_build_neural_helmet",
	"venom_mist_gauntlet": "_build_venom_mist_gauntlet",
	"reinforced_boomerang_gauntlet": "_build_reinforced_boomerang_gauntlet",
	"commando_arm": "_build_commando_arm",
	"rainbow_fur_glove": "_build_rainbow_fur_glove",
	"knee_pads": "_build_knee_pads",
	"dashgear": "_build_dashgear",
	"soul_burst": "_build_soul_burst",
	"bulkup": "_build_bulkup",
	"dashholder": "_build_dashholder",
	"bulletproof_hat": "_build_bulletproof_hat",
	"spiked_helmet": "_build_spiked_helmet",
	"pandora_legacy": "_build_pandora_legacy",
	"megingjord": "_build_megingjord",
	"ragnarok_hammer": "_build_ragnarok_hammer",
	"hermes_shoes": "_build_hermes_shoes",
	"poseidon_trident": "_build_poseidon_trident",
	"sacred_laurel": "_build_sacred_laurel",
	"transcendent_crown": "_build_transcendent_crown",
	"heavenly_cape": "_build_heavenly_cape",
	"horn_strawberry_mask": "_build_horn_strawberry_mask",
	"odins_eye": "_build_odins_eye",
	"celestial_armor": "_build_celestial_armor",
	"baal_boots": "_build_baal_boots",
	"elixir_of_mastery": "_build_elixir_of_mastery",
}


func build_item_by_name(catalog: Object, item_name: String) -> Dictionary:
	var method_name: String = str(ITEM_BUILD_METHODS.get(item_name, ""))
	if catalog == null or method_name == "" or not has_method(method_name):
		return {}
	var result: Variant = call(method_name, catalog)
	if result is Dictionary:
		return LanguageSettings.localize_item_data(result)
	return {}

func _with_mythic_icon_item(
	catalog: Object,
	item_data: Dictionary,
	item_name: String,
	slot: String,
	include_fixed_options: bool = false
) -> Dictionary:
	return icon_metadata_helper.with_mythic_icon_sheet(
		base_metadata_helper.with_rolled_item_base(
			item_data,
			catalog,
			item_name,
			"mythic",
			slot,
			catalog.get_field_chance(item_name),
			include_fixed_options
		),
		catalog.get_icon_sheet_path(item_name)
	)


func _build_speedboots(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "스피드부츠",
		"korean_name": "스피드부츠",
		"description": "장착 중 플레이어의 이동 속도를 롤옵션만큼 높입니다.",
		"color": Color(0.0, 1.0, 100.0 / 255.0),
	}, catalog, "speedboots", "passive", "shoes", catalog.get_field_chance("speedboots"))


func _build_speedgear(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "보정벨트",
		"korean_name": "보정벨트",
		"description": "장착 중 좌우 방향 전환 감속이 2.5배 증가합니다.",
		"color": Color(1.0, 150.0 / 255.0, 0.0),
	}, catalog, "speedgear", "passive", "belt", catalog.get_field_chance("speedgear"))


func _build_gravitybelt(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "무중력벨트",
		"korean_name": "무중력벨트",
		"description": "이동 입력 즉시 최대 속도로 전환하고, 입력을 떼면 바로 정지합니다.",
		"color": Color(120.0 / 255.0, 90.0 / 255.0, 1.0),
	}, catalog, "gravitybelt", "passive", "belt", catalog.get_field_chance("gravitybelt"))


func _build_sensor(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "위험감지벨트",
		"korean_name": "위험감지벨트",
		"description": "위험 상황에서 자동으로 대쉬합니다. 자동대쉬는 게이지와 대쉬토큰을 소모하지 않습니다.",
		"color": Color(150.0 / 255.0, 150.0 / 255.0, 1.0),
	}, catalog, "sensor", "passive", "belt", catalog.get_field_chance("sensor"))


func _build_spikeboots(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "스파이크부츠",
		"korean_name": "스파이크부츠",
		"description": "대쉬 후딜 시간과 대쉬 토큰 재충전 시간을 롤옵션만큼 줄입니다.",
		"color": Color(1.0, 100.0 / 255.0, 1.0),
	}, catalog, "spikeboots", "passive", "shoes", catalog.get_field_chance("spikeboots"))


func _build_dowsing_pendulum(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "다우징팬들럼",
		"korean_name": "다우징팬들럼",
		"description": "롤옵션 범위 안의 필드 아이템과 스타포인트를 플레이어 패들 쪽으로 끌어당깁니다.",
		"color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
	}, catalog, "dowsing_pendulum", "passive", "belt2", catalog.get_field_chance("dowsing_pendulum"))


func _build_dowsing_goggles(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "다우징 고글",
		"korean_name": "다우징 고글",
		"description": "퍽 선택 화면에서 일정 확률로 일반 퍽 선택지가 1장 추가됩니다.",
		"color": Color(60.0 / 255.0, 200.0 / 255.0, 180.0 / 255.0),
	}, catalog, "dowsing_goggles", "passive", "head", catalog.get_field_chance("dowsing_goggles"))


func _build_slot_add(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "배낭",
		"korean_name": "배낭",
		"description": "장착 중 액티브 아이템 슬롯을 롤옵션만큼 늘립니다.",
		"color": Color(1.0, 180.0 / 255.0, 80.0 / 255.0),
	}, catalog, "slot_add", "passive", "belt2", catalog.get_field_chance("slot_add"))


func _build_chargebag(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "충전가방",
		"korean_name": "충전가방",
		"description": "장착 중 공이 벽에 닿을 때마다 기본 게이지 충전량의 일부를 추가로 얻습니다.",
		"color": Color(100.0 / 255.0, 1.0, 100.0 / 255.0),
	}, catalog, "chargebag", "passive", "belt2", catalog.get_field_chance("chargebag"))


func _build_battery(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "배터리팩",
		"korean_name": "배터리팩",
		"description": "장착 중 다음 스테이지로 넘어갈 때 게이지를 롤옵션 비율만큼 보존합니다.",
		"color": Color(1.0, 1.0, 0.0),
	}, catalog, "battery", "passive", "belt2", catalog.get_field_chance("battery"))


func _build_revival(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "윤회의 부적",
		"korean_name": "윤회의 부적",
		"description": "장착 중 패배 직전 한 번 발동해 게임 오버를 막고 스테이지를 처음부터 다시 시작합니다.",
		"color": Color(1.0, 0.0, 1.0),
	}, catalog, "revival", "passive", "accessory", catalog.get_field_chance("revival"))


func _build_master(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "수리공망치",
		"korean_name": "수리공망치",
		"description": "장착 중 벽돌 액티브의 길이를 늘리고, 액티브 아이템 쿨타임을 줄이며, 벽돌 아이템의 필드 스폰 가중치를 높입니다.",
		"color": Color(1.0, 215.0 / 255.0, 0.0),
	}, catalog, "master", "passive", "arm", catalog.get_field_chance("master"))


func _build_gold_digger(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "골드디거",
		"korean_name": "골드디거",
		"description": "장착 중 골드 획득량과 일부 게이지 획득량을 롤옵션만큼 늘립니다.",
		"color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
	}, catalog, "gold_digger", "passive", "arm", catalog.get_field_chance("gold_digger"))


func _build_gold_bar(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "금괴",
		"korean_name": "금괴",
		"description": "판매 전용 귀금속입니다. 보유 중 이동속도가 30% 감소하지만 상점에서 2000골드에 판매할 수 있습니다.",
		"sell_price": 2000,
		"color": Color(1.0, 215.0 / 255.0, 0.0),
	}, catalog, "gold_bar", "passive", "accessory", catalog.get_field_chance("gold_bar"))


func _build_lucky_coin(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "럭키코인",
		"korean_name": "럭키코인",
		"description": "장착 중 필드 아이템이 스폰될 때 롤옵션 확률로 보너스 아이템을 1개 더 생성합니다.",
		"color": Color(1.0, 223.0 / 255.0, 0.0),
	}, catalog, "lucky_coin", "passive", "accessory", catalog.get_field_chance("lucky_coin"))


func _build_adversity_armor(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "역경의 갑옷",
		"korean_name": "역경의 갑옷",
		"description": "실점 후 그다음 라운드에 일정 확률로 사용자를 보호하는 무적의 벽이 생성됩니다. 다음 서브 시 공 속도도 증가합니다.",
		"color": Color(0.96, 0.58, 0.18),
	}, catalog, "adversity_armor", "passive", "top", catalog.get_field_chance("adversity_armor"))


func _build_shrapnel_armor(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "파편갑옷",
		"korean_name": "파편갑옷",
		"description": "플레이어 패들이 공을 칠 때 일정 확률로 게이지를 소모해 위쪽으로 가시 파편을 발사하고, 보스에게 맞으면 짧은 스턴과 넉백을 줍니다.",
		"color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
	}, catalog, "shrapnel_armor", "passive", "top", catalog.get_field_chance("shrapnel_armor"))


func _build_sage_ring(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "현자의 반지",
		"korean_name": "현자의 반지",
		"description": "장착 중 모든 투자된 퍽의 유효 레벨을 1 올립니다. 대신 이동속도와 몸집크기가 롤옵션만큼 감소합니다.",
		"color": Color(180.0 / 255.0, 140.0 / 255.0, 1.0),
	}, catalog, "sage_ring", "passive", "accessory", catalog.get_field_chance("sage_ring"), true)


func _build_cooltime(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "쿨링볼",
		"korean_name": "쿨링볼",
		"description": "장착 중 액티브 아이템 재사용 쿨타임을 롤옵션만큼 줄입니다.",
		"color": Color(0.0, 230.0 / 255.0, 1.0),
	}, catalog, "cooltime", "passive", "accessory", catalog.get_field_chance("cooltime"))


func _build_timer_belt(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "타이머벨트",
		"korean_name": "타이머벨트",
		"description": "장착 중 모든 캐릭터 스킬의 쿨타임을 롤옵션만큼 줄입니다.",
		"color": Color(90.0 / 255.0, 220.0 / 255.0, 230.0 / 255.0),
	}, catalog, "timer_belt", "passive", "belt", catalog.get_field_chance("timer_belt"))


func _build_fuel_pouch(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "연료파우치",
		"korean_name": "연료파우치",
		"description": "장착 중 플레이어의 최대 게이지를 롤옵션 수치만큼 늘립니다.",
		"color": Color(180.0 / 255.0, 100.0 / 255.0, 40.0 / 255.0),
	}, catalog, "fuel_pouch", "passive", "accessory", catalog.get_field_chance("fuel_pouch"))


func _build_bluetooth_ring(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "블루투스링",
		"korean_name": "블루투스링",
		"description": "장착 중 플레이어가 패들로 공을 칠 때 얻는 게이지를 롤옵션만큼 늘립니다.",
		"color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
	}, catalog, "bluetooth_ring", "passive", "accessory", catalog.get_field_chance("bluetooth_ring"))


func _build_star_detector(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "별탐지기",
		"korean_name": "별탐지기",
		"description": "장착 중 스타포인트 드랍이 생길 때 롤옵션 확률로 보너스 스타포인트 드랍을 1개 더 생성합니다.",
		"color": Color(80.0 / 255.0, 200.0 / 255.0, 220.0 / 255.0),
	}, catalog, "star_detector", "passive", "accessory", catalog.get_field_chance("star_detector"))


func _build_foul_whistle(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "반칙호루라기",
		"korean_name": "반칙호루라기",
		"description": "라운드 패배 시 일정 확률로 심판이 호루라기를 불어 실점을 무효화하고 라운드를 다시 시작합니다.",
		"color": Color(1.0, 235.0 / 255.0, 120.0 / 255.0),
	}, catalog, "foul_whistle", "passive", "accessory", catalog.get_field_chance("foul_whistle"))


func _build_smartphone(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "스마트폰",
		"korean_name": "스마트폰",
		"description": "게이지가 낮으면 회복 아이템을 자동으로 사용하고, 위급할 때 스톱워치 또는 홀리베리어를 자동 발동합니다.",
		"color": Color(100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0),
	}, catalog, "smartphone", "passive", "arm", catalog.get_field_chance("smartphone"), false)


func _build_neural_helmet(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "뉴럴헬멧",
		"korean_name": "뉴럴헬멧",
		"description": "AI알약의 게이지 소모를 줄이고 AI알약 스폰율을 높입니다. AI알약 발동 중 방향키 입력으로 즉시 해제할 수 있습니다.",
		"color": Color(140.0 / 255.0, 180.0 / 255.0, 1.0),
	}, catalog, "neural_helmet", "passive", "head", catalog.get_field_chance("neural_helmet"))


func _build_venom_mist_gauntlet(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "독안개 건틀릿",
		"korean_name": "독안개 건틀릿",
		"description": "바이퍼 전용. 화랑비천각으로 공에 독을 싣고, 보스가 감염된 공을 가드하면 보스 주변에 독안개를 생성합니다. 독안개 안의 보스는 이동속도와 기력이 감소합니다.",
		"character_restriction": "viper",
		"color": Color(80.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0),
	}, catalog, "venom_mist_gauntlet", "passive", "arm", catalog.get_field_chance("venom_mist_gauntlet"))


func _build_reinforced_boomerang_gauntlet(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "강화부메랑 장갑",
		"korean_name": "강화부메랑 장갑",
		"description": "부메랑을 메탈 강화하고 발사속도, 유도성능, 스폰율, 넉백, 스턴 시간을 올립니다.",
		"color": Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	}, catalog, "reinforced_boomerang_gauntlet", "passive", "arm", catalog.get_field_chance("reinforced_boomerang_gauntlet"), true)


func _build_commando_arm(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "코만도암",
		"korean_name": "코만도암",
		"description": "투척류 아이템을 전투용 팔 장비로 보조합니다. 수류탄, 조명탄, 화염병은 더 빠르게 날아가고 폭발 범위가 넓어지며, 다이너마이트, 바나나, 비누, 부메랑의 준비시간이 줄어듭니다. 연막탄 지속시간도 증가합니다.",
		"color": Color(60.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0),
	}, catalog, "commando_arm", "passive", "arm", catalog.get_field_chance("commando_arm"))


func _build_rainbow_fur_glove(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "무지개털장갑",
		"korean_name": "무지개털장갑",
		"description": "공을 패들로 칠 때 일정 확률로 발동하여 장착한 캐릭터 스킬의 진행 중 쿨타임을 즉시 감소시킵니다.",
		"color": Color(1.0, 170.0 / 255.0, 220.0 / 255.0),
	}, catalog, "rainbow_fur_glove", "passive", "arm", catalog.get_field_chance("rainbow_fur_glove"))


func _build_knee_pads(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "킥차져",
		"korean_name": "킥차져",
		"description": "장착 중 하프대쉬로 공을 맞추면 기본 게이지 획득량을 기준으로 롤옵션 비율만큼 충전합니다.",
		"color": Color(80.0 / 255.0, 80.0 / 255.0, 100.0 / 255.0),
	}, catalog, "knee_pads", "passive", "knee", catalog.get_field_chance("knee_pads"))


func _build_dashgear(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "대쉬기어",
		"korean_name": "대쉬기어",
		"description": "대쉬 거리를 늘리고, 일정 확률로 다음 대쉬 토큰 소모를 무효화합니다.",
		"color": Color(1.0, 150.0 / 255.0, 100.0 / 255.0),
	}, catalog, "dashgear", "passive", "knee", catalog.get_field_chance("dashgear"))


func _build_soul_burst(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "소울버스트",
		"korean_name": "소울버스트",
		"description": "대쉬 토큰이 없을 때 스페셜 게이지를 소모해 하프대쉬 대신 풀대쉬를 발동합니다.",
		"color": Color(150.0 / 255.0, 80.0 / 255.0, 1.0),
	}, catalog, "soul_burst", "passive", "knee", catalog.get_field_chance("soul_burst"))


func _build_bulkup(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "벌크업슈트",
		"korean_name": "벌크업슈트",
		"description": "장착 중 플레이어 패들의 몸집크기를 롤옵션만큼 늘립니다.",
		"color": Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
	}, catalog, "bulkup", "passive", "top", catalog.get_field_chance("bulkup"))


func _build_dashholder(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "대쉬홀더",
		"korean_name": "대쉬홀더",
		"description": "장착 중 대쉬 토큰 최대 개수를 1개 늘립니다.",
		"color": Color(1.0, 150.0 / 255.0, 100.0 / 255.0),
	}, catalog, "dashholder", "passive", "accessory", catalog.get_field_chance("dashholder"))


func _build_bulletproof_hat(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "방탄모자",
		"korean_name": "방탄모자",
		"description": "장착 중 플레이어에게 걸리는 스턴 시간을 롤옵션만큼 줄입니다.",
		"color": Color(0.38, 0.72, 1.0),
	}, catalog, "bulletproof_hat", "passive", "head", catalog.get_field_chance("bulletproof_hat"))


func _build_spiked_helmet(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_rolled_item_base({
		"display_name": "가시투구",
		"korean_name": "가시투구",
		"description": "장착 중 플레이어가 받는 넉백 속도를 롤옵션만큼 줄입니다.",
		"color": Color(1.0, 0.62, 0.32),
	}, catalog, "spiked_helmet", "passive", "head", catalog.get_field_chance("spiked_helmet"))


func _build_pandora_legacy(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "판도라의 유산",
		"korean_name": "판도라의 유산",
		"description": "라운드 승리 시 일정 확률로 발동해 3개의 아이템 중 하나를 선택합니다.",
		"color": Color(150.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0),
	}, "pandora_legacy", "back")


func _build_megingjord(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "메긴교르드",
		"korean_name": "메긴교르드",
		"description": "퍽 선택 시 추가 선택 기회를 얻습니다. 한 선택 묶음에서 최대 2회까지 연속 발동합니다.",
		"color": Color(1.0, 215.0 / 255.0, 75.0 / 255.0),
	}, "megingjord", "belt")


func _build_ragnarok_hammer(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "라그나로크 해머",
		"korean_name": "라그나로크 해머",
		"description": "플레이어가 공을 받아칠 때 게이지를 소모해 스턴공을 만들고, 보스가 받아치면 넉백과 스턴을 겁니다.",
		"color": Color(120.0 / 255.0, 190.0 / 255.0, 1.0),
	}, "ragnarok_hammer", "arm")


func _build_hermes_shoes(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "헤르메스의 신발",
		"korean_name": "헤르메스의 신발",
		"description": "신들의 전령이 신던 날개 신발입니다. 롤 옵션만큼 플레이어 이동속도를 증가시킵니다.",
		"color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
	}, "hermes_shoes", "shoes")


func _build_poseidon_trident(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "포세이돈의 삼지창",
		"korean_name": "포세이돈의 삼지창",
		"description": "대시 회복 순간 좌우에 거대한 물회오리를 생성하여 보스가 내려친 공을 위쪽으로 강하게 튕겨냅니다.",
		"color": Color(70.0 / 255.0, 185.0 / 255.0, 1.0),
	}, "poseidon_trident", "arm")


func _build_sacred_laurel(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "신성 월계수",
		"korean_name": "신성 월계수",
		"description": "월계수 잎이 플레이어 주변을 회전하며 보호합니다.",
		"color": Color(105.0 / 255.0, 215.0 / 255.0, 120.0 / 255.0),
	}, "sacred_laurel", "accessory")


func _build_transcendent_crown(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "초월자의 관",
		"korean_name": "초월자의 관",
		"description": "이미 투자한 모든 퍽의 효과 레벨을 롤 옵션만큼 증가시킵니다.",
		"color": Color(1.0, 215.0 / 255.0, 100.0 / 255.0),
	}, "transcendent_crown", "head")


func _build_heavenly_cape(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "천상의 망토",
		"korean_name": "천상의 망토",
		"description": "스킬 구슬 슬롯을 1칸 늘리고 모든 플레이어 스킬 쿨타임을 줄입니다.",
		"color": Color(190.0 / 255.0, 225.0 / 255.0, 1.0),
	}, "heavenly_cape", "back", true)


func _build_horn_strawberry_mask(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "뿔딸기 변신가면",
		"korean_name": "뿔딸기 변신가면",
		"description": "A→D→A→D→A→D 커맨드로 1스테이지 1회 뿔딸기로 변신합니다.",
		"color": Color(1.0, 72.0 / 255.0, 90.0 / 255.0),
	}, "horn_strawberry_mask", "head", true)


func _build_odins_eye(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "오딘의 눈",
		"korean_name": "오딘의 눈",
		"description": "실점 시 롤 확률로 그 실점을 무효화하고 부활합니다. 부활 후에는 이동과 대시에 페널티를 받으며, 다시 실점하면 패배합니다.",
		"color": Color(110.0 / 255.0, 100.0 / 255.0, 220.0 / 255.0),
	}, "odins_eye", "belt", true)


func _build_celestial_armor(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "천구의 부동 갑주",
		"korean_name": "천구의 부동 갑주",
		"description": "스턴이 들어올 때 롤 확률로 무시하고, 발동 시 게이지를 소모합니다.",
		"color": Color(180.0 / 255.0, 200.0 / 255.0, 1.0),
	}, "celestial_armor", "top")


func _build_baal_boots(catalog: Object) -> Dictionary:
	return _with_mythic_icon_item(catalog, {
		"display_name": "바알의 부츠",
		"korean_name": "바알의 부츠",
		"description": "날씨 이벤트가 시작되면 바알의 힘으로 현재 날씨를 흡수하고 게이지를 회복합니다. 흡수한 날씨에 따라 이번 라운드 동안 추가 효과가 발동합니다.",
		"color": Color(1.0, 90.0 / 255.0, 55.0 / 255.0),
	}, "baal_boots", "shoes")


func _build_elixir_of_mastery(catalog: Object) -> Dictionary:
	return base_metadata_helper.with_static_item_base({
		"display_name": "엘릭서 오브 마스터리",
		"korean_name": "엘릭서 오브 마스터리",
		"description": "사용 시 보유 중인 퍽 중 랜덤으로 1개를 선택해 Lv.5로 만듭니다. 신화급 액티브 아이템으로, 사용 후 소모됩니다.",
		"color": Color(0.47, 0.2, 0.78),
		"consumable": true,
		"mythic_active": true,
	}, catalog, "elixir_of_mastery", "mythic", "", 0.0, false)
