extends RefCounted

const CoreCatalog := preload("res://scripts/resources/gameplay_core_module_catalog.gd")
const StageCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const HudCatalog := preload("res://scripts/resources/gameplay_hud_module_catalog.gd")
const BallCatalog := preload("res://scripts/resources/gameplay_ball_module_catalog.gd")
const ActorCatalog := preload("res://scripts/resources/gameplay_actor_module_catalog.gd")
const ItemCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const LingpetCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const StatusCatalog := preload("res://scripts/resources/gameplay_status_module_catalog.gd")
const EffectAudioCatalog := preload("res://scripts/resources/gameplay_effect_audio_module_catalog.gd")
const ResourceCatalog := preload("res://scripts/resources/gameplay_resource_module_catalog.gd")
const NetworkCatalog := preload("res://scripts/resources/gameplay_network_module_catalog.gd")

var catalogs: Array = [
	CoreCatalog.new(),
	StageCatalog.new(),
	HudCatalog.new(),
	BallCatalog.new(),
	ActorCatalog.new(),
	ItemCatalog.new(),
	LingpetCatalog.new(),
	StatusCatalog.new(),
	EffectAudioCatalog.new(),
	ResourceCatalog.new(),
	NetworkCatalog.new(),
]


func get_spec(key: String) -> Dictionary:
	for catalog in catalogs:
		var spec: Dictionary = catalog.get_spec(key)
		if not spec.is_empty():
			return spec
	return {}
