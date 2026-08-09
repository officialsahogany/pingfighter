extends RefCounted

# Single canonical "may this candidate pool offer a Guardian Spirit item?" policy.
#
# Guardian Spirit actives are only usable behind Soul Summoning Art (영혼소환술).
# Every INDEPENDENT candidate pool must ask this before offering one, because the
# use-site guards only stop the item from doing anything — they do not stop a pool
# from spending a card / capsule / drop slot on an item the player cannot use.
#
# Known consumers: pandora_legacy_pool_builder (금기개함 selection cards),
# plaza_gacha_transactions (광장 액티브 캡슐), and — through
# lingpet_egg_runtime.can_offer_spirit_water_drop / .can_offer_egg_item —
# active_item_field_spawn_pool (field drops + stage-clear reward candidates).
#
# Prefer the live runtime's own gate when it is already instantiated: it adds
# transient runtime conditions (incubation in progress, overflow choice open,
# acquire cut-in playing) that a static policy cannot see. The static fallback is
# only for pools that run before the lingpet runtime exists, where those transient
# conditions cannot be true yet anyway. Reads are non-instantiating peeks: this
# runs from candidate builders, never from a hot draw/physics path.

const GuardianEggAccessPolicy := preload("res://scripts/lingpet/guardian_egg_access_policy.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")

const LINGPET_EGG := "lingpet_egg"
const LINGPET_SPIRIT_WATER := "lingpet_spirit_water"


static func is_access_gated_item(item_name: String) -> bool:
	return item_name == LINGPET_EGG or item_name == LINGPET_SPIRIT_WATER


# Returns true for every item this policy does not own, so callers can use it as a
# blanket candidate filter without enumerating the gated names themselves.
static func can_offer_item(item_name: String, owner: Object, registry: Object) -> bool:
	match item_name:
		LINGPET_EGG:
			return can_offer_egg(owner, registry)
		LINGPET_SPIRIT_WATER:
			return can_offer_spirit_water(owner, registry)
	return true


static func can_offer_egg(owner: Object, registry: Object) -> bool:
	var lingpet_runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime != null and lingpet_runtime.has_method("can_offer_egg_item"):
		return bool(lingpet_runtime.can_offer_egg_item(owner, registry))
	# Mirrors can_offer_egg_item's league semantics: the junior auto-present league
	# already owns its guardian, so an egg there is redundant rather than blocked.
	return (
		GuardianEggAccessPolicy.has_egg_access(owner, registry)
		and not LingpetCollectionState.new().is_auto_present_league(owner)
	)


static func can_offer_spirit_water(owner: Object, registry: Object) -> bool:
	var lingpet_runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime != null and lingpet_runtime.has_method("can_offer_spirit_water_item"):
		return bool(lingpet_runtime.can_offer_spirit_water_item(owner, registry))
	# Unlike the egg, spirit water stays useful in the auto-present league (that
	# guardian still spends duration), so only access + an owned guardian matter.
	return (
		GuardianEggAccessPolicy.has_egg_access(owner, registry)
		and not LingpetCollectionState.new().get_owned_pet_ids_from_owner(owner).is_empty()
	)


static func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	return registry.get_cached_instance(key)
