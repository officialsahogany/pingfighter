extends RefCounted

const MODULES := {
	"lingpet_egg_runtime": {
		"path": "res://scripts/lingpet/lingpet_egg_runtime.gd",
		"label": "lingpet egg runtime",
	},
	"lingpet_save_store": {
		"path": "res://scripts/lingpet/lingpet_save_store.gd",
		"label": "lingpet save store",
	},
	"lingpet_affinity_store": {
		"path": "res://scripts/lingpet/lingpet_affinity_store.gd",
		"label": "lingpet affinity store",
	},
	"lingpet_banana_slice_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_banana_slice_payload_factory.gd",
		"label": "lingpet Banana Slice payload factory",
	},
	"lingpet_gatling_burst_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_gatling_burst_payload_factory.gd",
		"label": "lingpet Gatling Burst payload factory",
	},
	"lingpet_hydro_sphere_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_hydro_sphere_payload_factory.gd",
		"label": "lingpet Hydro Sphere payload factory",
	},
	"lingpet_moon_orbit_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_moon_orbit_payload_factory.gd",
		"label": "lingpet Moon Orbit payload factory",
	},
	"lingpet_bubble_trap_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_bubble_trap_payload_factory.gd",
		"label": "lingpet Bubble Trap payload factory",
	},
	"lingpet_bomb_surprise_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_bomb_surprise_payload_factory.gd",
		"label": "lingpet Bomb Surprise payload factory",
	},
	"lingpet_dragon_wing_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_dragon_wing_payload_factory.gd",
		"label": "lingpet Dragon Wing payload factory",
	},
	"lingpet_doll_curse_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_doll_curse_payload_factory.gd",
		"label": "lingpet Doll Curse payload factory",
	},
	"lingpet_thunder_orb_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_thunder_orb_payload_factory.gd",
		"label": "lingpet Thunder Orb payload factory",
	},
	"lingpet_dragon_breath_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_dragon_breath_payload_factory.gd",
		"label": "lingpet Dragon Breath payload factory",
	},
	"lingpet_soul_clone_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_soul_clone_payload_factory.gd",
		"label": "lingpet Soul Clone payload factory",
	},
	"lingpet_ghost_summon_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_ghost_summon_payload_factory.gd",
		"label": "lingpet Ghost Summon payload factory",
	},
	"lingpet_skeleton_archer_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_skeleton_archer_payload_factory.gd",
		"label": "lingpet Skeleton Archer payload factory",
	},
	"lingpet_bone_barrier_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_bone_barrier_payload_factory.gd",
		"label": "lingpet Bone Barrier payload factory",
	},
	"lingpet_puppet_grab_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_puppet_grab_payload_factory.gd",
		"label": "lingpet Puppet Grab payload factory",
	},
	"lingpet_afterglow_leak_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_afterglow_leak_payload_factory.gd",
		"label": "lingpet Afterglow Leak payload factory",
	},
	"lingpet_affinity_feedback_payload_factory": {
		"path": "res://scripts/lingpet/lingpet_affinity_feedback_payload_factory.gd",
		"label": "lingpet affinity feedback payload factory",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
