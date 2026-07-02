extends SceneTree

const LingpetEffectTextResolver := preload("res://scripts/lingpet/lingpet_effect_text_resolver.gd")

var _failures: Array[String] = []


class FakeProfile:
	extends RefCounted

	var text := ""

	func _init(next_text: String) -> void:
		text = next_text

	func get_effect_text() -> String:
		return text


func _init() -> void:
	_verify_effect_text_resolution()
	_verify_runtime_delegates_effect_text_resolution()

	if _failures.is_empty():
		print("lingpet_effect_text_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_effect_text_resolution() -> void:
	_expect(
		LingpetEffectTextResolver.resolve("egg", 3, null).find("공에 3회") >= 0,
		"egg effect text should describe the unidentified egg hit requirement"
	)
	_expect(
		LingpetEffectTextResolver.resolve("egg", 0, null).find("공에 1회") >= 0,
		"egg effect text should clamp malformed required-hit values to one hit"
	)
	_expect_eq(
		LingpetEffectTextResolver.resolve("companion", 1, FakeProfile.new("동행 설명")),
		"동행 설명",
		"companion effect text should come from the current profile"
	)
	_expect_eq(
		LingpetEffectTextResolver.resolve("none", 1, FakeProfile.new("숨김")),
		"",
		"non-egg/non-companion states should not publish effect text"
	)


func _verify_runtime_delegates_effect_text_resolution() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("LingpetEffectTextResolver") >= 0, "egg runtime should preload the effect-text resolver")
	_expect(runtime_source.find("LingpetEffectTextResolver.resolve") >= 0, "egg runtime owner-sync path should call the effect-text resolver directly")
	_expect(runtime_source.find("func _get_effect_text") < 0, "egg runtime should not reintroduce the single-use effect-text wrapper")
	_expect(runtime_source.find("미확인 알") < 0, "egg runtime should not keep the unidentified-egg copy inline")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
