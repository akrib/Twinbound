# addons/core/data/enemy_data_loader.gd
class_name EnemyDataLoader
extends Node

## Charge les données d'ennemis depuis JSON
## Format: data/enemies/*.json

const ENEMIES_DIR = "res://data/enemies/"

var _json_loader: JSONDataLoader
var enemies: Dictionary = {}

func _init():
	_json_loader = JSONDataLoader.new()

func load_all_enemies() -> void:
	enemies = _json_loader.load_json_directory(ENEMIES_DIR, true)
	
	if enemies.is_empty():
		push_warning("No enemies loaded")
	else:
		print("Loaded %d enemy types" % enemies.size())
		GameRoot.event_bus.emit_signal("data_loaded", "enemies", enemies)

func get_enemy(enemy_id: String) -> Dictionary:
	if enemies.has(enemy_id):
		return enemies[enemy_id]
	
	push_error("Enemy not found: " + enemy_id)
	return {}

func create_enemy_instance(enemy_id: String, level: int = 1) -> Dictionary:
	var base_data = get_enemy(enemy_id).duplicate(true)
	
	if base_data.is_empty():
		return {}
	
	# Application du scaling de niveau
	if base_data.has("stats"):
		for stat in base_data.stats:
			if base_data.stats[stat] is float or base_data.stats[stat] is int:
				base_data.stats[stat] = _scale_stat(base_data.stats[stat], level)
	
	base_data["current_level"] = level
	return base_data

func _scale_stat(base_value: float, level: int) -> float:
	# Scaling simple : +10% par niveau
	return base_value * (1.0 + (level - 1) * 0.1)
