class_name JSONDataLoader
extends RefCounted
## Chargeur JSON générique avec validation, cache et normalisation
## 
## API Haute-Niveau :
##   - load_dict() : charge et valide qu'on a un Dictionary
##   - load_array() : charge et valide qu'on a un Array
##   - load_typed() : charge et normalise selon un type (battle, campaign, etc.)
##
## API Bas-Niveau :
##   - load_json_file() : charge brut sans validation de type
##   - load_json_directory() : charge un dossier entier

signal data_loaded(data_type: String, data: Dictionary)
signal data_load_failed(data_type: String, error: String)

var _cache: Dictionary = {}
var _schema_validators: Dictionary = {}

# ============================================================================
# API HAUTE-NIVEAU (recommandée)
# ============================================================================

## Charge un fichier JSON et garantit que c'est un Dictionary
## @param file_path : Chemin du fichier
## @param context : Nom du système appelant (pour les logs)
## @param normalize_type : Type de normalisation à appliquer (optionnel)
## @return Dictionary vide si erreur
func load_dict(file_path: String, context: String = "", normalize_type: String = "") -> Dictionary:
	if not FileAccess.file_exists(file_path):
		_log_error(context, "Fichier introuvable : %s" % file_path)
		return {}
	
	var data = load_json_file(file_path)
	
	if data == null:
		_log_error(context, "Erreur de parsing : %s" % file_path)
		return {}
	
	if typeof(data) != TYPE_DICTIONARY:
		_log_error(context, "Données invalides (pas un Dictionary) : %s" % file_path)
		return {}
	
	# Normalisation optionnelle
	if normalize_type != "":
		data = DataNormalizer.normalize_by_type(data, normalize_type)
	
	return data

## Charge un fichier JSON et garantit que c'est un Array
## @param file_path : Chemin du fichier
## @param context : Nom du système appelant
## @return Array vide si erreur
func load_array(file_path: String, context: String = "") -> Array:
	if not FileAccess.file_exists(file_path):
		_log_error(context, "Fichier introuvable : %s" % file_path)
		return []
	
	var data = load_json_file(file_path)
	
	if data == null:
		_log_error(context, "Erreur de parsing : %s" % file_path)
		return []
	
	if typeof(data) != TYPE_ARRAY:
		_log_error(context, "Données invalides (pas un Array) : %s" % file_path)
		return []
	
	return data

## Charge et normalise automatiquement selon le type
## @param file_path : Chemin du fichier
## @param data_type : Type de données ("battle", "campaign", "world_map", etc.)
## @param context : Nom du système appelant
## @return Dictionary normalisé ou {} si erreur
func load_typed(file_path: String, data_type: String, context: String = "") -> Dictionary:
	return load_dict(file_path, context, data_type)

# ============================================================================
# API BAS-NIVEAU (pour compatibilité)
# ============================================================================

## Charge un fichier JSON avec cache optionnel (retour brut, peut être null)
func load_json_file(file_path: String, use_cache: bool = true) -> Variant:
	if use_cache and _cache.has(file_path):
		return _cache[file_path]
	
	if not FileAccess.file_exists(file_path):
		push_error("[JSONDataLoader] File not found: " + file_path)
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[JSONDataLoader] Failed to open: " + file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		var error_msg = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		push_error("[JSONDataLoader] " + error_msg)
		return null
	
	var data = json.data
	
	if use_cache:
		_cache[file_path] = data
	
	return data

## Charge tous les fichiers JSON d'un dossier
func load_json_directory(dir_path: String, recursive: bool = false) -> Dictionary:
	var result = {}
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		push_error("[JSONDataLoader] Failed to open directory: " + dir_path)
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			if recursive:
				var subdir_data = load_json_directory(full_path, true)
				result[file_name] = subdir_data
		elif file_name.ends_with(".json"):
			var data = load_json_file(full_path)
			if data != null:
				var key = file_name.get_basename()
				result[key] = data
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result

## Valide la structure d'un objet JSON selon un schéma basique
func validate_schema(data: Dictionary, required_fields: Array) -> bool:
	for field in required_fields:
		if not data.has(field):
			push_error("[JSONDataLoader] Missing required field: " + field)
			return false
	return true

## Charge et valide un fichier avec schéma
func load_validated_json(file_path: String, required_fields: Array = []) -> Variant:
	var data = load_json_file(file_path)
	
	if data == null:
		return null
	
	if data is Dictionary and required_fields.size() > 0:
		if not validate_schema(data, required_fields):
			return null
	
	return data

# ============================================================================
# CACHE
# ============================================================================

## Nettoie le cache (utile pour rechargement à chaud)
func clear_cache(file_path: String = "") -> void:
	if file_path.is_empty():
		_cache.clear()
	else:
		_cache.erase(file_path)

# ============================================================================
# SAUVEGARDE
# ============================================================================

## Sauvegarde des données en JSON (pour éditeurs/outils)
func save_json_file(file_path: String, data: Variant) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("[JSONDataLoader] Failed to save: " + file_path)
		return false
	
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

# ============================================================================
# HELPERS INTERNES
# ============================================================================

func _log_error(context: String, message: String) -> void:
	var prefix = "[JSONDataLoader]"
	if context != "":
		prefix = "[%s]" % context
	
	push_error("%s %s" % [prefix, message])
	
	if GameRoot and GameRoot.global_logger:
		GameRoot.global_logger.error(context if context != "" else "JSONDataLoader", message)
