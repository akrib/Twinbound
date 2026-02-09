extends Node
class_name DataManager
## DataManager - Gestionnaire générique de données JSON
## Remplace ability_data_loader, item_data_loader, enemy_data_loader, dialogue_data_loader
##
## Usage:
##   DataManager.register_type("abilities", "res://data/abilities/")
##   var ability = DataManager.get("abilities", "fireball")
##
## Features:
##   - Chargement automatique depuis dossiers JSON
##   - Cache et validation
##   - Normalisation personnalisable
##   - Organisation par catégories (items)
##   - Instanciation avec scaling (enemies)
##   - Support de structures hiérarchiques (dialogues)

# ============================================================================
# CONFIGURATION DES TYPES DE DONNÉES
# ============================================================================

## Configuration d'un type de données
class DataTypeConfig:
	var id: String
	var directory: String
	var recursive: bool = false
	var normalize_func: Callable = Callable()  # func(data: Dictionary) -> void
	var validate_func: Callable = Callable()   # func(data: Dictionary) -> bool
	var organize_by_category: bool = false
	var support_instancing: bool = false       # Pour enemies
	var support_hierarchy: bool = false        # Pour dialogues
	
	func _init(p_id: String, p_directory: String) -> void:
		id = p_id
		directory = p_directory

# ============================================================================
# STOCKAGE
# ============================================================================

static var _registered_types: Dictionary = {}  # String -> DataTypeConfig
static var _data_cache: Dictionary = {}        # String -> Dictionary (données chargées)
static var _category_cache: Dictionary = {}    # String -> Dictionary (organisation par catégorie)

# ============================================================================
# ENREGISTREMENT DE TYPES
# ============================================================================

## Enregistre un type de données
static func register_type(
	type_id: String,
	directory: String,
	recursive: bool = false,
	normalize_func: Callable = Callable(),
	validate_func: Callable = Callable(),
	organize_by_category: bool = false,
	support_instancing: bool = false,
	support_hierarchy: bool = false
) -> void:
	var config = DataTypeConfig.new(type_id, directory)
	config.recursive = recursive
	config.normalize_func = normalize_func
	config.validate_func = validate_func
	config.organize_by_category = organize_by_category
	config.support_instancing = support_instancing
	config.support_hierarchy = support_hierarchy
	
	_registered_types[type_id] = config
	
	print("[DataManager] ✅ Type enregistré : %s (%s)" % [type_id, directory])

## Initialise tous les types standards du jeu
static func register_standard_types() -> void:
	# Abilities
	register_type(
		"abilities",
		"res://data/abilities/",
		false,
		Callable(),
		_validate_ability
	)
	
	# Items (avec catégories)
	register_type(
		"items",
		"res://data/items/",
		true,
		_normalize_item,
		Callable(),
		true  # organize_by_category
	)
	
	# Enemies (avec instancing et normalisation)
	register_type(
		"enemies",
		"res://data/enemies/",
		true,
		_normalize_enemy,
		Callable(),
		false,
		true  # support_instancing
	)
	
	# Dialogues (avec hiérarchie)
	register_type(
		"dialogues",
		"res://data/dialogues/",
		true,
		Callable(),
		Callable(),
		false,
		false,
		true  # support_hierarchy
	)
	
	print("[DataManager] ✅ Types standards enregistrés")

# ============================================================================
# CHARGEMENT
# ============================================================================

## Charge toutes les données d'un type
static func load_all(type_id: String) -> bool:
	if not _registered_types.has(type_id):
		push_error("[DataManager] Type non enregistré : %s" % type_id)
		return false
	
	var config: DataTypeConfig = _registered_types[type_id]
	
	# Chargement depuis le dossier
	var raw_data = GameRoot.json_data_loader.load_json_directory(
		config.directory,
		config.recursive
	)
	
	if raw_data.is_empty():
		push_warning("[DataManager] Aucune donnée chargée pour : %s" % type_id)
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.data_load_warning.emit(type_id, "No data found")
		return false
	
	# Normalisation
	if config.normalize_func.is_valid():
		_apply_normalization(raw_data, config.normalize_func)
	
	# Stockage
	_data_cache[type_id] = raw_data
	
	# Organisation par catégories si demandé
	if config.organize_by_category:
		_organize_by_category(type_id, raw_data)
	
	print("[DataManager] ✅ Chargé %d éléments : %s" % [_count_items(raw_data), type_id])
	
	# Événement
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.data_loaded.emit(type_id, raw_data)
	
	return true

## Charge un élément spécifique depuis un fichier
static func load_single(type_id: String, item_id: String) -> Dictionary:
	if not _registered_types.has(type_id):
		push_error("[DataManager] Type non enregistré : %s" % type_id)
		return {}
	
	var config: DataTypeConfig = _registered_types[type_id]
	var file_path = config.directory.path_join(item_id + ".json")
	
	if not FileAccess.file_exists(file_path):
		push_error("[DataManager] Fichier introuvable : %s" % file_path)
		return {}
	
	var data = GameRoot.json_data_loader.load_json_file(file_path)
	
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		push_error("[DataManager] Format invalide pour : %s" % item_id)
		return {}
	
	# Normalisation
	if config.normalize_func.is_valid():
		config.normalize_func.call(data)
	
	# Stockage en cache
	if not _data_cache.has(type_id):
		_data_cache[type_id] = {}
	
	_data_cache[type_id][item_id] = data
	
	return data

# ============================================================================
# RÉCUPÉRATION
# ============================================================================

## Récupère un élément par ID
static func get_data(type_id: String, item_id: String) -> Dictionary:
	# Vérifier le cache
	if _data_cache.has(type_id):
		var data = _data_cache[type_id]
		
		# Recherche directe
		if data.has(item_id):
			return data[item_id]
		
		# Recherche récursive (pour structures imbriquées)
		var found = _find_in_dict(data, item_id)
		if not found.is_empty():
			return found
	
	# Tenter de charger depuis le fichier
	var loaded = load_single(type_id, item_id)
	if not loaded.is_empty():
		return loaded
	
	push_error("[DataManager] Élément introuvable : %s/%s" % [type_id, item_id])
	return {}

## Récupère tous les éléments d'un type
static func get_all(type_id: String) -> Dictionary:
	if _data_cache.has(type_id):
		return _data_cache[type_id]
	
	# Charger si pas encore fait
	if load_all(type_id):
		return _data_cache[type_id]
	
	return {}

## Récupère les éléments par catégorie (pour items)
static func get_by_category(type_id: String, category: String) -> Array:
	if not _category_cache.has(type_id):
		return []
	
	var categories = _category_cache[type_id]
	return categories.get(category, [])

## Vérifie si un élément existe
static func has(type_id: String, item_id: String) -> bool:
	return not get_data(type_id, item_id).is_empty()

# ============================================================================
# INSTANCIATION (pour enemies)
# ============================================================================

## Crée une instance d'un élément (avec scaling pour enemies)
static func create_instance(type_id: String, item_id: String, level: int = 1) -> Dictionary:
	var config: DataTypeConfig = _registered_types.get(type_id)
	
	if not config or not config.support_instancing:
		push_error("[DataManager] L'instancing n'est pas supporté pour : %s" % type_id)
		return {}
	
	var base_data = get_data(type_id, item_id)
	
	if base_data.is_empty():
		return {}
	
	var instance = base_data.duplicate(true)
	
	# Scaling des stats pour enemies
	if instance.has("stats"):
		for stat in instance.stats:
			if instance.stats[stat] is float or instance.stats[stat] is int:
				instance.stats[stat] = _scale_stat(instance.stats[stat], level)
	
	instance["current_level"] = level
	
	return instance

static func _scale_stat(base_value: float, level: int) -> float:
	# Scaling simple : +10% par niveau
	return base_value * (1.0 + (level - 1) * 0.1)

# ============================================================================
# HIÉRARCHIE (pour dialogues)
# ============================================================================

## Récupère un nœud spécifique dans une structure hiérarchique
static func get_nested_data(type_id: String, item_id: String, node_id: String) -> Dictionary:
	var data = get_data(type_id, item_id)
	
	if data.has("nodes") and data.nodes.has(node_id):
		return data.nodes[node_id]
	
	return {}

# ============================================================================
# VALIDATION
# ============================================================================

## Valide un élément
static func validate(type_id: String, data: Dictionary) -> bool:
	if not _registered_types.has(type_id):
		return false
	
	var config: DataTypeConfig = _registered_types[type_id]
	
	if config.validate_func.is_valid():
		return config.validate_func.call(data)
	
	return true

# ============================================================================
# RECHARGEMENT
# ============================================================================

## Recharge un élément spécifique
static func reload(type_id: String, item_id: String) -> void:
	if not _registered_types.has(type_id):
		return
	
	var config: DataTypeConfig = _registered_types[type_id]
	var file_path = config.directory.path_join(item_id + ".json")
	
	# Vider le cache pour ce fichier
	GameRoot.json_data_loader.clear_cache(file_path)
	
	# Recharger
	var data = load_single(type_id, item_id)
	
	if not data.is_empty() and GameRoot and GameRoot.event_bus:
		# Émettre un signal spécifique (ability_reloaded, dialogue_reloaded, etc.)
		var signal_name = type_id.trim_suffix("s") + "_reloaded"
		if GameRoot.event_bus.has_signal(signal_name):
			GameRoot.event_bus.emit_signal(signal_name, item_id)

## Recharge tous les éléments d'un type
static func reload_all(type_id: String) -> void:
	clear_cache(type_id)
	load_all(type_id)

# ============================================================================
# CACHE
# ============================================================================

## Vide le cache d'un type
static func clear_cache(type_id: String = "") -> void:
	if type_id.is_empty():
		_data_cache.clear()
		_category_cache.clear()
		print("[DataManager] 🧹 Cache global vidé")
	else:
		_data_cache.erase(type_id)
		_category_cache.erase(type_id)
		print("[DataManager] 🧹 Cache vidé : %s" % type_id)

# ============================================================================
# HELPERS PRIVÉS
# ============================================================================

## Applique la normalisation sur tous les éléments
static func _apply_normalization(data: Dictionary, normalize_func: Callable) -> void:
	for key in data:
		if data[key] is Dictionary:
			if data[key].has("id"):
				# C'est un élément, normaliser
				normalize_func.call(data[key])
			else:
				# C'est un sous-dossier, récursion
				_apply_normalization(data[key], normalize_func)

## Organise les données par catégorie
static func _organize_by_category(type_id: String, data: Dictionary) -> void:
	var categories: Dictionary = {}
	_flatten_and_categorize(data, categories)
	_category_cache[type_id] = categories
	
	print("[DataManager] 📁 Organisé en %d catégories : %s" % [categories.size(), type_id])

static func _flatten_and_categorize(source: Dictionary, categories: Dictionary) -> void:
	for key in source:
		if source[key] is Dictionary:
			if source[key].has("id"):
				# C'est un élément
				var item = source[key]
				var category = item.get("category", "misc")
				
				if not categories.has(category):
					categories[category] = []
				
				categories[category].append(item)
			else:
				# C'est un dossier
				_flatten_and_categorize(source[key], categories)

## Recherche récursive dans un dictionnaire
static func _find_in_dict(data: Dictionary, item_id: String) -> Dictionary:
	for key in data:
		if key == item_id:
			return data[key]
		
		if data[key] is Dictionary:
			if data[key].has("id") and data[key].id == item_id:
				return data[key]
			
			var found = _find_in_dict(data[key], item_id)
			if not found.is_empty():
				return found
	
	return {}

## Compte le nombre d'éléments dans une structure récursive
static func _count_items(dict: Dictionary) -> int:
	var count = 0
	for key in dict:
		if dict[key] is Dictionary:
			if dict[key].has("id"):
				count += 1
			else:
				count += _count_items(dict[key])
	return count

# ============================================================================
# FONCTIONS DE VALIDATION SPÉCIFIQUES
# ============================================================================

static func _validate_ability(data: Dictionary) -> bool:
	var required = ["id", "name", "type", "cost"]
	return GameRoot.json_data_loader.validate_schema(data, required)

# ============================================================================
# FONCTIONS DE NORMALISATION SPÉCIFIQUES
# ============================================================================

static func _normalize_item(item: Dictionary) -> void:
	if item.has("stats"):
		for stat_key in item.stats:
			item.stats[stat_key] = GameRoot.data_normalizer.to_int(item.stats[stat_key], 0)

static func _normalize_enemy(enemy: Dictionary) -> void:
	GameRoot.data_normalizer.normalize_unit(enemy)

# ============================================================================
# DEBUG
# ============================================================================

static func debug_print_stats() -> void:
	print("\n=== DataManager Stats ===")
	print("Types enregistrés : %d" % _registered_types.size())
	
	for type_id in _registered_types:
		var count = _count_items(_data_cache.get(type_id, {}))
		var config: DataTypeConfig = _registered_types[type_id]
		print("  - %s : %d éléments (%s)" % [type_id, count, config.directory])
	
	print("========================\n")
