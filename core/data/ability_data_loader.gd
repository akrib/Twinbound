class_name AbilityDataLoader
extends Node
## Charge les données d'abilities depuis JSON
## Format: data/abilities/*.json

const ABILITIES_DIR = "res://data/abilities/"

var abilities: Dictionary = {}

func _ready() -> void:
	load_all_abilities()

func load_all_abilities() -> void:
	abilities = GameRoot.json_data_loader.load_json_directory(ABILITIES_DIR, false)
	
	if abilities.is_empty():
		push_warning("No abilities loaded from " + ABILITIES_DIR)
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.data_load_warning.emit("abilities", "No data found")
	else:
		print("[AbilityDataLoader] Loaded %d abilities" % abilities.size())
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.data_loaded.emit("abilities", abilities)

func get_ability(ability_id: String) -> Dictionary:
	if abilities.has(ability_id):
		return abilities[ability_id]
	
	push_error("Ability not found: " + ability_id)
	return {}

func reload_ability(ability_id: String) -> void:
	var file_path = ABILITIES_DIR.path_join(ability_id + ".json")
	GameRoot.json_data_loader.clear_cache(file_path)
	var data = GameRoot.json_data_loader.load_json_file(file_path)
	
	if data:
		abilities[ability_id] = data
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.ability_reloaded.emit(ability_id)

## Valide les champs requis d'une ability
func validate_ability(data: Dictionary) -> bool:
	var required = ["id", "name", "type", "cost"]
	return GameRoot.json_data_loader.validate_schema(data, required)
