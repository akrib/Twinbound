# addons/core/data/dialogue_data_loader.gd

extends Node
class_name DialogueDataLoader
const DIALOGUES_DIR = "res://data/dialogues/"

var _json_loader: JSONDataLoader
var dialogues: Dictionary = {}

func _init():
	_json_loader = JSONDataLoader.new()

func load_all_dialogues() -> void:
	dialogues = _json_loader.load_json_directory(DIALOGUES_DIR, true)
	
	if dialogues.is_empty():
		push_warning("No dialogues loaded")
	else:
		print("Loaded %d dialogue sets" % dialogues.size())
		GameRoot.event_bus.emit_signal("data_loaded", "dialogues", dialogues)

# ✅ NOUVELLE MÉTHODE : Charge un dialogue spécifique
func load_dialogue(dialogue_id: String) -> Dictionary:
	"""
	Charge un dialogue depuis un fichier JSON
	
	@param dialogue_id : ID du dialogue (nom du fichier sans .json)
	@return Dictionary contenant le dialogue, ou {} si introuvable
	"""
	var file_path = DIALOGUES_DIR.path_join(dialogue_id + ".json")
	
	if not FileAccess.file_exists(file_path):
		push_error("[DialogueDataLoader] Fichier introuvable : ", file_path)
		return {}
	
	var data = _json_loader.load_json_file(file_path)
	
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		push_error("[DialogueDataLoader] Format invalide pour : ", dialogue_id)
		return {}
	
	# Stocker en cache
	dialogues[dialogue_id] = data
	
	return data

func get_dialogue(dialogue_id: String) -> Dictionary:
	# Vérifier le cache d'abord
	if dialogues.has(dialogue_id):
		return dialogues[dialogue_id]
	
	# Sinon, charger depuis le fichier
	return load_dialogue(dialogue_id)

func get_dialogue_node(dialogue_id: String, node_id: String) -> Dictionary:
	var dialogue = get_dialogue(dialogue_id)
	if dialogue.has("nodes") and dialogue.nodes.has(node_id):
		return dialogue.nodes[node_id]
	return {}

func reload_dialogue(dialogue_id: String) -> void:
	var file_path = DIALOGUES_DIR.path_join(dialogue_id + ".json")
	_json_loader.clear_cache(file_path)
	var data = load_dialogue(dialogue_id)
	
	if not data.is_empty():
		GameRoot.event_bus.emit_signal("dialogue_reloaded", dialogue_id)
