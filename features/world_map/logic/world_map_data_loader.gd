# scripts/core/world_map_data_loader.gd
extends Node
class_name WorldMapDataLoader

const WORLD_MAP_PATH := "res://data/maps/"

static var _map_cache: Dictionary = {}
static var _location_cache: Dictionary = {}

# ============================================================================
# CHARGEMENT DE LA CARTE PRINCIPALE
# ============================================================================

## Charge les données complètes de la world map
static func load_world_map_data(map_id: String = "world_map_data", use_cache: bool = true) -> Dictionary:
	var json_path = WORLD_MAP_PATH + map_id + ".json"
	return GameRoot.json_data_loader.load_typed(json_path, "world_map", "WorldMapDataLoader")

# ============================================================================
# CHARGEMENT DES LOCATIONS
# ============================================================================

## Charge les données d'une location spécifique
static func load_location_data(location_id: String, use_cache: bool = true) -> Dictionary:
	var json_path = WORLD_MAP_PATH + "locations/" + location_id + ".json"
	
	var raw_data = GameRoot.json_data_loader.load_json_file(json_path, use_cache)
	
	if typeof(raw_data) != TYPE_DICTIONARY or raw_data.is_empty():
		push_error("[WorldMapDataLoader] ❌ Impossible de charger location : ", json_path)
		return {}
	
	return raw_data


# ============================================================================
# QUERIES
# ============================================================================

## Retourne toutes les locations d'une carte
static func get_all_locations(map_id: String = "world_map_data") -> Array:
	var map_data = load_world_map_data(map_id)
	return map_data.get("locations", [])

## Retourne une location spécifique par ID
static func get_location_by_id(location_id: String, map_id: String = "world_map_data") -> Dictionary:
	var locations = get_all_locations(map_id)
	
	for location in locations:
		if location.get("id") == location_id:
			return location
	
	return {}

## Retourne les locations déverrouillées jusqu'à un certain step
static func get_unlocked_locations(current_step: int, map_id: String = "world_map_data") -> Array:
	var all_locations = get_all_locations(map_id)
	var unlocked: Array = []
	
	for location in all_locations:
		if location.get("unlocked_at_step", 0) <= current_step:
			unlocked.append(location)
	
	return unlocked

## Vérifie si une location est déverrouillée
static func is_location_unlocked(location_id: String, current_step: int, map_id: String = "world_map_data") -> bool:
	var location = get_location_by_id(location_id, map_id)
	
	if location.is_empty():
		return false
	
	return location.get("unlocked_at_step", 0) <= current_step

# ============================================================================
# NPCs
# ============================================================================

## Trouve un NPC dans une location et retourne où il se trouve
static func find_npc_location(npc_id: String, location_id: String) -> Dictionary:
	var location_data = load_location_data(location_id)
	var npcs = location_data.get("npcs", [])
	
	for npc in npcs:
		if npc.get("id") == npc_id:
			# Calculer où le NPC se trouve (probabilité)
			return _calculate_npc_position(npc)
	
	return {}

## Calcule où se trouve un NPC selon les probabilités
static func _calculate_npc_position(npc: Dictionary) -> Dictionary:
	var locations = npc.get("locations", [])
	
	if locations.is_empty():
		return {}
	
	# Générer un nombre aléatoire
	var roll = randf() * 100.0
	var cumulative = 0.0
	
	for loc in locations:
		cumulative += loc.get("chance", 0)
		
		if roll <= cumulative:
			return {
				"npc": npc,
				"place_id": loc.get("place_id"),
				"place_name": loc.get("place_name")
			}
	
	# Fallback : première location
	return {
		"npc": npc,
		"place_id": locations[0].get("place_id"),
		"place_name": locations[0].get("place_name")
	}

# ============================================================================
# CACHE
# ============================================================================

static func clear_cache() -> void:
	_map_cache.clear()
	_location_cache.clear()
	print("[WorldMapDataLoader] Cache vidé")

static func clear_location_cache(location_id: String) -> void:
	_location_cache.erase(location_id)
