extends SceneTree

const RuntimePerkRegistryLookup := preload("res://scripts/characters/runtime_perk_registry_lookup.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_registry_lookup_contract()
	_verify_state_callback_wrappers_delegate_to_lookup()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_registry_lookup_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_registry_lookup_contract() -> void:
	var lookup := RuntimePerkRegistryLookup.new()
	var registry := FakeRegistry.new()
	_expect(lookup.get_instance(registry, "runtime_perk_catalog") == registry.catalog, "registry lookup should resolve existing keys")
	_expect(lookup.get_catalog(registry) == registry.catalog, "registry lookup should expose runtime perk catalog shortcut")
	_expect(lookup.get_instance(registry, "missing") == null, "registry lookup should return null for missing keys")
	_expect(lookup.get_instance(registry, "") == null, "registry lookup should reject empty keys")
	_expect(lookup.get_instance(null, "runtime_perk_catalog") == null, "registry lookup should reject null registry")
	_expect(lookup.get_instance(NoRegistry.new(), "runtime_perk_catalog") == null, "registry lookup should reject registries without get_instance")


func _verify_state_callback_wrappers_delegate_to_lookup() -> void:
	var state := RuntimePerkState.new()
	var registry := FakeRegistry.new()
	_expect(state._get_instance(registry, "runtime_perk_catalog") == registry.catalog, "state get-instance callback should preserve registry lookup")
	_expect(state._get_catalog(registry) == registry.catalog, "state catalog callback should preserve catalog lookup")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var lookup_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_registry_lookup.gd")
	var get_instance_body: String = _function_body(state_source, "func _get_instance(")
	var get_catalog_body: String = _function_body(state_source, "func _get_catalog(")
	_expect(state_source.find("RuntimePerkRegistryLookup") >= 0, "state should preload registry lookup helper")
	_expect(lookup_source.find("func get_instance(") >= 0, "registry lookup helper should own generic get-instance policy")
	_expect(lookup_source.find("func get_catalog(") >= 0, "registry lookup helper should own catalog shortcut policy")
	_expect(get_instance_body.find("_registry_lookup.get_instance") >= 0, "state get-instance callback should delegate to registry lookup helper")
	_expect(get_instance_body.find("registry == null") < 0, "state get-instance callback should not inline null-registry policy")
	_expect(get_instance_body.find("has_method(\"get_instance\")") < 0, "state get-instance callback should not inline registry API policy")
	_expect(get_catalog_body.find("_registry_lookup.get_catalog") >= 0, "state catalog callback should delegate to registry lookup helper")
	_expect(get_catalog_body.find("\"runtime_perk_catalog\"") < 0, "state catalog callback should not inline catalog key")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRegistry:
	extends RefCounted

	var catalog := RefCounted.new()

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_catalog":
			return catalog
		return null


class NoRegistry:
	extends RefCounted
