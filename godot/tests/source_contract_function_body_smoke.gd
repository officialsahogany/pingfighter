extends SceneTree

const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_comment_adjacent_function_boundary()
	_verify_static_function_boundary()
	_verify_static_target_to_eof_boundary()
	_verify_crlf_source_boundary()
	_verify_nested_class_method_is_not_boundary()
	_verify_helper_body_delegation_predicate()
	_verify_no_smoke_uses_blank_line_boundary()
	_verify_no_smoke_uses_inline_function_boundary()
	_verify_all_smoke_function_body_helpers_use_shared_extractor()
	_verify_function_body_alias_helpers_use_shared_extractor()

	if _failures.is_empty():
		print("source_contract_function_body_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_comment_adjacent_function_boundary() -> void:
	var source := "func first() -> void:\n\t_call_runtime()\n\n# comment for second that mentions _second_helper\nfunc second() -> void:\n\t_second_helper()\n"
	var body := SourceContractFunctionBody.extract(source, "func first(")
	_expect(body.find("_call_runtime()") >= 0, "extractor should include the target body")
	_expect(body.find("_second_helper") < 0, "extractor should stop before a comment-adjacent next function")
	_expect(body.find("func second") < 0, "extractor should not swallow the next function")
	_expect(body.find("# comment for second") < 0, "extractor should not keep the next function's leading source-contract comments")


func _verify_static_function_boundary() -> void:
	var source := "func first() -> void:\n\t_call_runtime()\n@warning_ignore(\"unused_parameter\")\nstatic func second() -> void:\n\t_second_helper()\n"
	var body := SourceContractFunctionBody.extract(source, "func first(")
	_expect(body.find("_call_runtime()") >= 0, "extractor should include target code before a static function")
	_expect(body.find("static func second") < 0, "extractor should stop before top-level static functions")
	_expect(body.find("@warning_ignore") < 0, "extractor should exclude next-function annotations")


func _verify_static_target_to_eof_boundary() -> void:
	var source := "static func first() -> int:\n\treturn 7\n"
	var body := SourceContractFunctionBody.extract(source, "static func first(")
	_expect(body.find("return 7") >= 0, "extractor should support static target functions")
	_expect(body.strip_edges().ends_with("return 7"), "extractor should keep the final target function through EOF")


func _verify_crlf_source_boundary() -> void:
	var source := "func first() -> void:\r\n\t_call_runtime()\r\n\r\n# comment for second\r\nfunc second() -> void:\r\n\t_second_helper()\r\n"
	var body := SourceContractFunctionBody.extract(source, "func first(")
	_expect(body.find("_call_runtime()") >= 0, "extractor should include target code with CRLF line endings")
	_expect(body.find("_second_helper") < 0, "extractor should stop before a CRLF comment-adjacent next function")
	_expect(body.find("# comment for second") < 0, "extractor should exclude next-function CRLF comments")


func _verify_nested_class_method_is_not_boundary() -> void:
	var source := "func first() -> int:\n\tclass Local:\n\t\tfunc nested() -> int:\n\t\t\treturn 1\n\treturn Local.new().nested()\n\nfunc second() -> void:\n\t_second_helper()\n"
	var body := SourceContractFunctionBody.extract(source, "func first(")
	_expect(body.find("func nested") >= 0, "extractor should keep nested class methods inside the target body")
	_expect(body.find("func second") < 0, "extractor should still stop at the next top-level function")


func _verify_helper_body_delegation_predicate() -> void:
	var false_green_source := "const SourceContractFunctionBody := preload(\"res://tests/source_contract_function_body.gd\")\nfunc _function_body(source: String, signature: String) -> String:\n\tvar start := source.find(signature)\n\tvar next := source.find(\"\\nfunc \", start)\n\treturn source.substr(start, next - start)\n"
	_expect(
		not _helper_body_delegates_to_shared_extractor(false_green_source, "func _function_body("),
		"helper delegation guard should not pass just because the file mentions SourceContractFunctionBody"
	)
	var delegated_source := "func _function_body(source: String, marker: String) -> String:\n\tvar start := source.find(marker)\n\treturn SourceContractFunctionBody.extract(source, marker)\n"
	_expect(
		_helper_body_delegates_to_shared_extractor(delegated_source, "func _function_body("),
		"helper delegation guard should allow local prechecks before shared extraction"
	)


func _verify_no_smoke_uses_blank_line_boundary() -> void:
	for file_name in _smoke_file_names():
		var path := "res://tests/%s" % file_name
		var source := FileAccess.get_file_as_string(path)
		_expect(
			source.find("source.find(\"\\n\\nfunc \"") < 0,
			"%s should not use the blank-line function-boundary heuristic" % file_name
		)


func _verify_no_smoke_uses_inline_function_boundary() -> void:
	for file_name in _smoke_file_names():
		var path := "res://tests/%s" % file_name
		var source := FileAccess.get_file_as_string(path)
		_expect(
			source.find(".find(\"\\nfunc \"") < 0 and source.find(".find(\"\\nstatic func \"") < 0,
			"%s should not parse source-contract function bodies with an inline newline function boundary" % file_name
		)


func _verify_all_smoke_function_body_helpers_use_shared_extractor() -> void:
	for file_name in _smoke_file_names():
		var path := "res://tests/%s" % file_name
		var source := FileAccess.get_file_as_string(path)
		if _has_top_level_helper(source, "func _function_body("):
			_expect(
				_helper_body_delegates_to_shared_extractor(source, "func _function_body("),
				"%s should delegate _function_body to the shared extractor inside the helper body" % file_name
			)


func _verify_function_body_alias_helpers_use_shared_extractor() -> void:
	for file_name in _smoke_file_names():
		var path := "res://tests/%s" % file_name
		var source := FileAccess.get_file_as_string(path)
		for signature in ["func _source_function_body(", "func _extract_function_body("]:
			if _has_top_level_helper(source, signature):
				_expect(
					_helper_body_delegates_to_shared_extractor(source, signature),
					"%s should delegate %s to the shared extractor inside the helper body" % [file_name, signature]
				)


func _helper_body_delegates_to_shared_extractor(source: String, signature: String) -> bool:
	var body := SourceContractFunctionBody.extract(source, signature)
	if body == "":
		return false
	return body.find("SourceContractFunctionBody.extract(source,") >= 0


func _has_top_level_helper(source: String, signature: String) -> bool:
	return source.begins_with(signature) or source.find("\n%s" % signature) >= 0


func _smoke_file_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open("res://tests")
	_expect(dir != null, "tests directory should be readable")
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with("_smoke.gd"):
			names.append(file_name)
	return names


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
