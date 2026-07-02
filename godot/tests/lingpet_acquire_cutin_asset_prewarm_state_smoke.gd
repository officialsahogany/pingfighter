extends SceneTree

const LingpetAcquireCutinAssetPrewarmState := preload("res://scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd")

var _failures: Array[String] = []


class FakeCutinHost:
	extends RefCounted

	var calls: Array[String] = []
	var done_after := 2

	func prewarm_pet_assets_step(
		pet_id: String,
		_allow_sync_fallback: bool = false,
		_perf_logger: Object = null,
		_perf_label_prefix: String = ""
	) -> bool:
		calls.append(pet_id)
		return calls.size() >= done_after


class FakeResolver:
	extends RefCounted

	var host: Object = null
	var resolve_calls := 0

	func _init(host_arg: Object = null) -> void:
		host = host_arg

	func resolve(_registry: Object) -> Object:
		resolve_calls += 1
		return host


func _init() -> void:
	_verify_prewarm_done_bookkeeping()
	_verify_registry_host_resolution()
	_verify_runtime_delegates_acquire_cutin_asset_prewarm_state()

	if _failures.is_empty():
		print("lingpet_acquire_cutin_asset_prewarm_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_done_bookkeeping() -> void:
	var state := LingpetAcquireCutinAssetPrewarmState.new()
	var host := FakeCutinHost.new()

	_expect(state.prewarm_step("", host), "empty pet id should be treated as no-op complete")
	_expect(host.calls.is_empty(), "empty pet id should not touch the cut-in host")
	_expect(not state.prewarm_step("maribo", null), "missing host should report not complete")
	_expect(state.done_for_pet_id == "", "missing host should not mark the pet complete")

	_expect(not state.prewarm_step("maribo", host), "first host pass should keep streaming until the host reports done")
	_expect(state.done_for_pet_id == "", "unfinished host pass should not mark the pet complete")
	_expect(state.prewarm_step("maribo", host), "second host pass should complete once the host reports done")
	_expect(state.done_for_pet_id == "maribo", "completed host pass should remember the pet id")
	_expect(host.calls == ["maribo", "maribo"], "host should receive the target pet id for each active streaming pass")

	var calls_after_done := host.calls.size()
	_expect(state.prewarm_step("maribo", host), "already completed pet should short-circuit as complete")
	_expect(host.calls.size() == calls_after_done, "already completed pet should not re-drive host prewarm")

	state.reset()
	_expect(state.done_for_pet_id == "", "reset should clear the completed pet id")


func _verify_registry_host_resolution() -> void:
	var state := LingpetAcquireCutinAssetPrewarmState.new()
	var host := FakeCutinHost.new()
	host.done_after = 1
	var resolver := FakeResolver.new(host)
	var registry := RefCounted.new()

	_expect(not state.prewarm_registry_step("maribo", null, resolver), "missing registry should not resolve a host")
	_expect(resolver.resolve_calls == 0, "missing registry should not call the resolver")
	_expect(not state.prewarm_registry_step("maribo", registry, null), "missing resolver should report not complete")
	_expect(state.prewarm_registry_step("maribo", registry, resolver), "registry prewarm should resolve the host and complete when the host is done")
	_expect(resolver.resolve_calls == 1, "registry prewarm should resolve exactly once for the active pass")
	_expect(host.calls == ["maribo"], "registry prewarm should forward the target pet id to the host")


func _verify_runtime_delegates_acquire_cutin_asset_prewarm_state() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_acquire_cutin_asset_prewarm_state.gd")
	var transition_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_pet_transition.gd")
	_expect(runtime_source.find("LingpetAcquireCutinAssetPrewarmState") >= 0, "egg runtime should preload the acquire cut-in asset prewarm owner")
	_expect(runtime_source.find("_acquire_cutin_asset_prewarm_state.prewarm_registry_step") >= 0, "egg runtime should delegate acquire cut-in asset prewarm ticking with registry host resolution")
	_expect(runtime_source.find("func _prewarm_acquire_cutin_assets_step") < 0, "runtime should not keep a private acquire cut-in asset-prewarm wrapper")
	_expect(runtime_source.find("func _prewarm_item_egg_cutin_assets_step") < 0, "runtime should not keep a private incubator-egg cut-in asset-prewarm wrapper")
	_expect(runtime_source.find("LingpetCurrentPetTransition") >= 0, "egg runtime should delegate pet-id transition cleanup to the current-pet transition owner")
	_expect(transition_source.find("acquire_cutin_asset_prewarm_state.reset") >= 0, "pet-id changes should reset acquire cut-in prewarm completion state")
	_expect(runtime_source.find("var _acquire_cutin_assets_prewarm_done_for") < 0, "runtime should not keep acquire cut-in prewarm done state locally")
	_expect(owner_source.find("prewarm_registry_step") >= 0 and owner_source.find("overlay_host_resolver.resolve") >= 0, "prewarm owner should own registry host resolution")
	_expect(owner_source.find("done_for_pet_id") >= 0, "prewarm owner should own completed pet bookkeeping")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
