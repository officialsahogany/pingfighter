extends RefCounted


const THROW_WINDUP_ITEM_NAMES := {
	"grenade": true,
	"flare": true,
	"tear_gas": true,
	"dynamite": true,
	"molotov": true,
	"boomerang": true,
	"banana": true,
	"soap": true,
}


static func is_throw_windup_item(item_name: String) -> bool:
	return bool(THROW_WINDUP_ITEM_NAMES.get(item_name.strip_edges(), false))


static func get_throw_windup_item_names() -> Array[String]:
	var result: Array[String] = []
	for item_name_value: Variant in THROW_WINDUP_ITEM_NAMES.keys():
		result.append(str(item_name_value))
	result.sort()
	return result
