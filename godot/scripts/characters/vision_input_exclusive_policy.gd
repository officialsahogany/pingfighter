extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const VISION_SKILL_IDS := [
	CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID,
	CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID,
	CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
	CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID,
]
const COMMON_BLOCKED_HOLD_CHANNELS := [
	"up_pressed",
	"down_pressed",
	"action_pressed",
	"mouse_left_pressed",
	"mouse_middle_pressed",
	"secondary_action_pressed",
	"supply_drop_hold_pressed",
	"commando_supply_drop_hold_pressed",
	"mouse_right_pressed",
	"gamepad_supply_hold_pressed",
	"jetpack_pressed",
]
const VISION_SKILL_EXTRA_BLOCKED_HOLD_CHANNELS := {
	CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID: [],
	CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID: [],
	CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID: ["left_pressed", "right_pressed"],
	CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID: [],
}

static var _character_runtime: Object = PlayerCharacterRuntime.new()


static func is_active(modifier_pressed: bool, skill_config: Object) -> bool:
	return modifier_pressed and has_equipped_vision(skill_config)


static func is_active_for_owner(owner: Object, registry: Object) -> bool:
	if not Input.is_action_pressed("vision_modifier"):
		return false
	return has_equipped_vision(_get_owner_skill_config(owner, registry))


static func has_equipped_vision(skill_config: Object) -> bool:
	if skill_config == null or not skill_config.has_method("is_skill_equipped"):
		return false
	for skill_id: String in VISION_SKILL_IDS:
		if bool(skill_config.is_skill_equipped(skill_id)):
			return true
	return false


static func get_blocked_hold_channels(skill_config: Object) -> Dictionary:
	var blocked_channels := {}
	if skill_config == null or not skill_config.has_method("is_skill_equipped"):
		return blocked_channels
	for skill_id: String in VISION_SKILL_IDS:
		if not bool(skill_config.is_skill_equipped(skill_id)):
			continue
		for channel: String in COMMON_BLOCKED_HOLD_CHANNELS:
			blocked_channels[channel] = true
		var extra_channels: Variant = VISION_SKILL_EXTRA_BLOCKED_HOLD_CHANNELS.get(skill_id, [])
		if extra_channels is Array:
			for channel_value: Variant in extra_channels:
				blocked_channels[str(channel_value)] = true
	return blocked_channels


static func blocks_horizontal_movement(skill_config: Object) -> bool:
	var blocked_channels := get_blocked_hold_channels(skill_config)
	return (
		bool(blocked_channels.get("left_pressed", false))
		or bool(blocked_channels.get("right_pressed", false))
	)


static func _get_owner_skill_config(owner: Object, registry: Object) -> Object:
	if owner == null or registry == null:
		return null
	var character_type := str(owner.get("selected_character_type"))
	var skill_config_key: String = _character_runtime.get_skill_config_key(character_type)
	if skill_config_key.is_empty():
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(skill_config_key)
		if typeof(cached) == TYPE_OBJECT and cached != null and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		return registry.get_instance(skill_config_key)
	return null
