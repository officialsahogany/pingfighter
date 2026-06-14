extends RefCounted

const MODULES := {
	"active_item_runtime": {
		"path": "res://scripts/items/active_item_runtime.gd",
		"label": "active item runtime",
	},
	"active_item_brick_wall_particles": {
		"path": "res://scripts/items/active_item_brick_wall_particles.gd",
		"label": "Brick Wall particle lifecycle",
	},
	"active_item_brick_wall_particle_payload_factory": {
		"path": "res://scripts/items/active_item_brick_wall_particle_payload_factory.gd",
		"label": "Brick Wall particle payload factory",
	},
	"active_item_dash_boost_particles": {
		"path": "res://scripts/items/active_item_dash_boost_particles.gd",
		"label": "Dash Boost particle lifecycle",
	},
	"active_item_dash_boost_particle_payload_factory": {
		"path": "res://scripts/items/active_item_dash_boost_particle_payload_factory.gd",
		"label": "Dash Boost particle payload factory",
	},
	"active_item_holy_barrier_particles": {
		"path": "res://scripts/items/active_item_holy_barrier_particles.gd",
		"label": "Holy Barrier particle lifecycle",
	},
	"active_item_holy_barrier_particle_payload_factory": {
		"path": "res://scripts/items/active_item_holy_barrier_particle_payload_factory.gd",
		"label": "Holy Barrier particle payload factory",
	},
	"active_item_magnet_field_particles": {
		"path": "res://scripts/items/active_item_magnet_field_particles.gd",
		"label": "Magnet Field particle lifecycle",
	},
	"active_item_magnet_field_particle_payload_factory": {
		"path": "res://scripts/items/active_item_magnet_field_particle_payload_factory.gd",
		"label": "Magnet Field particle payload factory",
	},
	"active_item_life_elixir_particles": {
		"path": "res://scripts/items/active_item_life_elixir_particles.gd",
		"label": "Life Elixir particle helper",
	},
	"active_item_life_elixir_particle_payload_factory": {
		"path": "res://scripts/items/active_item_life_elixir_particle_payload_factory.gd",
		"label": "Life Elixir particle payload factory",
	},
	"active_item_regeneration_potion_effect": {
		"path": "res://scripts/items/active_item_regeneration_potion_effect.gd",
		"label": "Regeneration Potion effect lifecycle",
	},
	"active_item_regeneration_potion_payload_factory": {
		"path": "res://scripts/items/active_item_regeneration_potion_payload_factory.gd",
		"label": "Regeneration Potion payload factory",
	},
	"active_item_pickup_effect_state": {
		"path": "res://scripts/items/active_item_pickup_effect_state.gd",
		"label": "active item pickup effect state",
	},
	"active_item_pickup_effect_payload_factory": {
		"path": "res://scripts/items/active_item_pickup_effect_payload_factory.gd",
		"label": "active item pickup effect payload factory",
	},
	"mythic_item_catalog": {
		"path": "res://scripts/items/mythic_item_catalog.gd",
		"label": "mythic item catalog",
	},
	"mythic_item_runtime": {
		"path": "res://scripts/items/mythic_item_runtime.gd",
		"label": "mythic item runtime",
	},
	"treasure_hunt_runtime": {
		"path": "res://scripts/items/treasure_hunt_runtime.gd",
		"label": "treasure hunt runtime",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
