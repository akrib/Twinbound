extends Node
class_name DataNormalizer
## DataNormalizer - Normalisation centralisée des données JSON
## Convertit les données JSON brutes en types Godot natifs

# ============================================================================
# POSITIONS
# ============================================================================

## Convertit une position JSON (Array ou Dictionary) en Vector2i
static func normalize_position(pos: Variant) -> Vector2i:
	if pos is Vector2i:
		return pos
	
	if pos is Array and pos.size() >= 2:
		return Vector2i(int(pos[0]), int(pos[1]))
	
	if pos is Dictionary:
		return Vector2i(
			int(pos.get("x", 0)),
			int(pos.get("y", 0))
		)
	
	push_warning("[DataNormalizer] Position invalide : %s" % str(pos))
	return Vector2i.ZERO

## Convertit une taille de grille en Vector2i
static func normalize_grid_size(size: Variant) -> Vector2i:
	if size is Vector2i:
		return size
	
	if size is Dictionary:
		return Vector2i(
			int(size.get("width", 0)),
			int(size.get("height", 0))
		)
	
	if size is Array and size.size() >= 2:
		return Vector2i(int(size[0]), int(size[1]))
	
	push_warning("[DataNormalizer] Grid size invalide : %s" % str(size))
	return Vector2i.ZERO

# ============================================================================
# UNITÉS DE COMBAT
# ============================================================================

## Normalise les données d'une unité (HP, position, etc.)
static func normalize_unit(unit: Dictionary) -> void:
	# HP
	if unit.has("current_hp"):
		unit.current_hp = int(unit.current_hp)
	
	if unit.has("max_hp"):
		unit.max_hp = int(unit.max_hp)
	
	# Position
	if unit.has("position"):
		unit.position = normalize_position(unit.position)
	
	# Stats (conversion en int si nécessaire)
	if unit.has("stats"):
		for stat_key in unit.stats:
			var stat_value = unit.stats[stat_key]
			if stat_value is float or stat_value is String:
				unit.stats[stat_key] = int(stat_value)
	
	# Level
	if unit.has("level"):
		unit.level = int(unit.level)

## Normalise un tableau d'unités
static func normalize_units(units: Array) -> void:
	for unit in units:
		if unit is Dictionary:
			normalize_unit(unit)

# ============================================================================
# OBSTACLES DE TERRAIN
# ============================================================================

## Normalise un obstacle de terrain
static func normalize_obstacle(obstacle: Dictionary) -> void:
	if obstacle.has("position"):
		obstacle.position = normalize_position(obstacle.position)
	
	if obstacle.has("height"):
		obstacle.height = int(obstacle.height)

## Normalise un tableau d'obstacles
static func normalize_obstacles(obstacles: Array) -> void:
	for obstacle in obstacles:
		if obstacle is Dictionary:
			normalize_obstacle(obstacle)

# ============================================================================
# DONNÉES DE BATAILLE COMPLÈTES
# ============================================================================

## Normalise toutes les données de bataille
static func normalize_battle_data(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	
	# Unités joueur
	if result.has("player_units"):
		normalize_units(result.player_units)
	
	# Unités ennemies
	if result.has("enemy_units"):
		normalize_units(result.enemy_units)
	
	# Obstacles
	if result.has("terrain_obstacles"):
		normalize_obstacles(result.terrain_obstacles)
	
	# Taille de grille
	if result.has("grid_size"):
		result.grid_size = normalize_grid_size(result.grid_size)
	
	return result

# ============================================================================
# DONNÉES DE CAMPAGNE
# ============================================================================

## Normalise les positions dans les données de campagne
static func normalize_campaign_data(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	
	# Sequences de démarrage
	if result.has("start_sequence"):
		for step in result.start_sequence:
			if step.has("position"):
				step.position = normalize_position(step.position)
	
	return result

# ============================================================================
# WORLD MAP
# ============================================================================

## Normalise les données de world map
static func normalize_world_map_data(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	
	if result.has("locations"):
		for location in result.locations:
			if location.has("position"):
				location.position = normalize_position(location.position)
			
			if location.has("map_position"):
				location.map_position = normalize_position(location.map_position)
	
	return result

# ============================================================================
# COULEURS
# ============================================================================

## Convertit une couleur JSON en Color Godot
static func normalize_color(color_data: Variant) -> Color:
	if color_data is Color:
		return color_data
	
	if color_data is Dictionary:
		return Color(
			color_data.get("r", 1.0),
			color_data.get("g", 1.0),
			color_data.get("b", 1.0),
			color_data.get("a", 1.0)
		)
	
	if color_data is String:
		return Color(color_data)
	
	return Color.WHITE

# ============================================================================
# VALEURS NUMÉRIQUES
# ============================================================================

## Assure qu'une valeur est un int
static func to_int(value: Variant, default: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		return int(value) if value.is_valid_int() else default
	return default

## Assure qu'une valeur est un float
static func to_float(value: Variant, default: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		return float(value) if value.is_valid_float() else default
	return default

## Assure qu'une valeur est un bool
static func to_bool(value: Variant, default: bool = false) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is String:
		return value.to_lower() in ["true", "1", "yes"]
	return default

# ============================================================================
# VALIDATION & NORMALISATION COMBINÉES
# ============================================================================

## Normalise et valide les données selon un type
static func normalize_by_type(data: Variant, data_type: String) -> Variant:
	match data_type:
		"battle":
			if data is Dictionary:
				return normalize_battle_data(data)
		
		"campaign":
			if data is Dictionary:
				return normalize_campaign_data(data)
		
		"world_map":
			if data is Dictionary:
				return normalize_world_map_data(data)
		
		"unit":
			if data is Dictionary:
				var normalized = data.duplicate(true)
				normalize_unit(normalized)
				return normalized
		
		_:
			push_warning("[DataNormalizer] Type inconnu : %s" % data_type)
	
	return data

# ============================================================================
# DEBUG
# ============================================================================

## Affiche les différences entre les données avant/après normalisation
static func debug_compare(before: Variant, after: Variant, label: String = "") -> void:
	if not OS.is_debug_build():
		return
	
	print("\n=== DataNormalizer Debug : %s ===" % label)
	print("Avant : %s" % str(before))
	print("Après : %s" % str(after))
	print("====================================\n")
