extends Node
class_name ModelValidator
## Validateur de modèles de données JSON

static var _models: Dictionary = {}

# ======================================================
# PUBLIC API
# ======================================================

static func validate(data: Variant, model_id: String) -> ValidationResult:
	var result := ValidationResult.new()
	var model := _load_model(model_id)

	if model.is_empty():
		result.add_error("Model not found: %s" % model_id)
		return result

	_validate_value(data, model, "", result)

	result.data = data
	return result


# ======================================================
# MODEL LOADING
# ======================================================

static func _load_model(model_id: String) -> Dictionary:
	if _models.has(model_id):
		return _models[model_id]

	var path := "res://data/models/%s_model.json" % model_id
	if not FileAccess.file_exists(path):
		push_error("[ModelValidator] Model file not found: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[ModelValidator] Invalid model format: " + model_id)
		return {}

	_models[model_id] = parsed
	return parsed


# ======================================================
# CORE VALIDATION
# ======================================================

static func _validate_value(value: Variant, model: Dictionary, path: String, result: ValidationResult) -> void:
	match model.get("type"):
		"object":
			_validate_object(value, model, path, result)

		"array":
			_validate_array(value, model, path, result)

		"vector2i":
			_validate_vector2i(value, path, result)

		_:
			result.add_error("%s: Unknown model type" % path)


# ======================================================
# OBJECT
# ======================================================

static func _validate_object(value, model, path, result):
	if typeof(value) != TYPE_DICTIONARY:
		result.add_error("%s must be an object" % path)
		return

	var fields: Dictionary = model.get("fields", {})

	for field_name in fields.keys():
		var rule = fields[field_name]
		var field_path = field_name if path == "" else "%s.%s" % [path, field_name]

		if rule.get("required", false) and not value.has(field_name):
			result.add_error("Missing field: %s" % field_path)
			continue

		if not value.has(field_name):
			continue

		_validate_field(value, field_name, rule, field_path, result)


# ======================================================
# ARRAY
# ======================================================

static func _validate_array(value, model, path, result):
	if typeof(value) != TYPE_ARRAY:
		result.add_error("%s must be an array" % path)
		return

	var item_model_id = model.get("items", {}).get("model", "")
	if item_model_id == "":
		return

	var item_model = _load_model(item_model_id)

	for i in range(value.size()):
		var item_path = "%s[%d]" % [path, i]
		_validate_value(value[i], item_model, item_path, result)


# ======================================================
# VECTOR2I
# ======================================================

static func _validate_vector2i(value, path, result):
	if typeof(value) != TYPE_DICTIONARY or not value.has("x") or not value.has("y"):
		result.add_error("%s must be a Vector2i-like object" % path)
		return

	value.x = int(value.x)
	value.y = int(value.y)


# ======================================================
# FIELD
# ======================================================

static func _validate_field(obj, key, rule, path, result):
	var v = obj[key]

	match rule.get("type"):
		"string":
			if typeof(v) != TYPE_STRING:
				result.add_error("%s must be a string" % path)

		"number":
			if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
				result.add_error("%s must be a number" % path)
				return

			if rule.get("integer", false) and typeof(v) == TYPE_FLOAT and v != int(v):
				result.add_error("%s must be an integer (got %s)" % [path, v])

			if rule.has("min") and v < rule.min:
				result.add_error("%s < min (%s)" % [path, rule.min])

			if rule.has("max") and v > rule.max:
				result.add_error("%s > max (%s)" % [path, rule.max])

			if rule.get("normalize") == "int":
				obj[key] = int(v)

		"object":
			var sub_model = rule.get("model", "")
			if sub_model != "":
				_validate_value(v, _load_model(sub_model), path, result)

		"array":
			if typeof(v) != TYPE_ARRAY:
				result.add_error("%s must be an array" % path)
				return
			
			var item_rule = rule.get("items", {})
			if not item_rule.is_empty():
				for i in range(v.size()):
					var item_path = "%s[%d]" % [path, i]
					if item_rule.has("model"):
						var item_model = _load_model(item_rule.model)
						_validate_value(v[i], item_model, item_path, result)

		"boolean":
			if typeof(v) != TYPE_BOOL:
				result.add_error("%s must be a boolean" % path)

# ======================================================
# CACHE MANAGEMENT
# ======================================================

static func clear_cache() -> void:
	"""Vide le cache des modèles"""
	_models.clear()

static func reload_model(model_id: String) -> void:
	"""Recharge un modèle spécifique"""
	_models.erase(model_id)
	_load_model(model_id)
