extends SceneTree

const LingpetAcquireCutinOverlayHostResolver := preload("res://scripts/lingpet/lingpet_acquire_cutin_overlay_host_resolver.gd")

var _failures: Array[String] = []


class FakeHost:
	extends RefCounted


class ReadyHost:
	extends RefCounted

	var ready := false
	var calls := 0
	var last_pet_id := ""

	func is_pet_cutin_anim_ready(pet_id: String) -> bool:
		calls += 1
		last_pet_id = pet_id
		return ready


class FakeRegistry:
	extends RefCounted

	var cached_value: Variant = null
	var instance_value: Variant = null
	var cached_calls := 0
	var instance_calls := 0

	func _init(next_cached: Variant = null, next_instance: Variant = null) -> void:
		cached_value = next_cached
		instance_value = next_instance

	func get_cached_instance(key: String) -> Variant:
		cached_calls += 1
		if key == "lingpet_acquire_cutin_overlay_host":
			return cached_value
		return null

	func get_instance(key: String) -> Variant:
		instance_calls += 1
		if key == "lingpet_acquire_cutin_overlay_host":
			return instance_value
		return null


class InstanceOnlyRegistry:
	extends RefCounted

	var instance_value: Variant = null
	var instance_calls := 0

	func _init(next_instance: Variant = null) -> void:
		instance_value = next_instance

	func get_instance(key: String) -> Variant:
		instance_calls += 1
		if key == "lingpet_acquire_cutin_overlay_host":
			return instance_value
		return null


func _init() -> void:
	_verify_lookup_order_and_guards()
	_verify_anim_ready_fallback_and_forwarding()
	_verify_runtime_delegates_overlay_host_resolver()

	if _failures.is_empty():
		print("lingpet_acquire_cutin_overlay_host_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lookup_order_and_guards() -> void:
	var resolver := LingpetAcquireCutinOverlayHostResolver.new()
	_expect(resolver.resolve(null) == null, "null registry should resolve to null")

	var cached_host := FakeHost.new()
	var instance_host := FakeHost.new()
	var cached_registry := FakeRegistry.new(cached_host, instance_host)
	_expect(resolver.resolve(cached_registry) == cached_host, "cached host should win over normal instance lookup")
	_expect(cached_registry.cached_calls == 1 and cached_registry.instance_calls == 0, "cached hit should not call get_instance")

	var fallback_registry := FakeRegistry.new("bad cached value", instance_host)
	_expect(resolver.resolve(fallback_registry) == instance_host, "invalid cached value should fall back to get_instance")
	_expect(fallback_registry.cached_calls == 1 and fallback_registry.instance_calls == 1, "fallback path should try both lookup methods")

	var instance_only := InstanceOnlyRegistry.new(instance_host)
	_expect(resolver.resolve(instance_only) == instance_host, "registries without get_cached_instance should still use get_instance")
	_expect(instance_only.instance_calls == 1, "instance-only registry should call get_instance once")

	var invalid_registry := FakeRegistry.new("bad cached value", "bad instance value")
	_expect(resolver.resolve(invalid_registry) == null, "non-object host values should resolve to null")


func _verify_anim_ready_fallback_and_forwarding() -> void:
	var resolver := LingpetAcquireCutinOverlayHostResolver.new()
	_expect(resolver.is_anim_ready(null, "maribo"), "null registry should treat acquire cut-in anim as ready")
	_expect(resolver.is_anim_ready(FakeRegistry.new(FakeHost.new(), null), "maribo"), "host without readiness query should not gate static/fallback cut-ins")
	_expect(resolver.is_anim_ready(FakeRegistry.new("bad cached value", "bad instance value"), "maribo"), "missing host should treat acquire cut-in anim as ready")

	var host := ReadyHost.new()
	host.ready = false
	_expect(not resolver.is_anim_ready(FakeRegistry.new(host, null), "rabi"), "readiness host false result should hold the reveal gate")
	_expect(host.calls == 1, "readiness host should be called once for false result")
	_expect(host.last_pet_id == "rabi", "readiness host should receive the pet id")

	host.ready = true
	_expect(resolver.is_anim_ready(FakeRegistry.new(host, null), "rabi"), "readiness host true result should release the reveal gate")
	_expect(host.calls == 2, "readiness host should be called again for true result")


func _verify_runtime_delegates_overlay_host_resolver() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_acquire_cutin_overlay_host_resolver.gd")
	var prewarm_state_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd")
	_expect(runtime_source.find("LingpetAcquireCutinOverlayHostResolver") >= 0, "egg runtime should preload the overlay host resolver")
	_expect(runtime_source.find("func _get_acquire_cutin_overlay_host") < 0, "runtime should not reintroduce the single-use acquire cut-in host lookup wrapper")
	_expect(runtime_source.find("_acquire_cutin_asset_prewarm_state.prewarm_registry_step") >= 0, "runtime prewarm path should delegate registry prewarm to the acquire cut-in prewarm owner")
	_expect(prewarm_state_source.find("overlay_host_resolver.resolve") >= 0, "acquire cut-in prewarm owner should call the overlay host resolver directly")
	_expect(runtime_source.find("func _is_acquire_cutin_anim_ready") < 0, "runtime should not reintroduce the single-use acquire cut-in readiness wrapper")
	_expect(runtime_source.find("_acquire_cutin_overlay_host_resolver.is_anim_ready") >= 0, "runtime reveal-readiness query should delegate")
	_expect(runtime_source.find("has_method(\"is_pet_cutin_anim_ready\")") < 0, "runtime should not keep acquire cut-in readiness method guards inline")
	_expect(resolver_source.find("HOST_KEY") >= 0 and resolver_source.find("lingpet_acquire_cutin_overlay_host") >= 0, "resolver should own the overlay host registry key")
	_expect(resolver_source.find("get_cached_instance") >= 0 and resolver_source.find("get_instance") >= 0, "resolver should own cached-then-instance lookup order")
	_expect(resolver_source.find("has_method(\"is_pet_cutin_anim_ready\")") >= 0, "resolver should own optional readiness method guard")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
