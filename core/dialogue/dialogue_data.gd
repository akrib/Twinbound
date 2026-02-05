extends Resource
class_name DialogueData
## Structure de données pour un dialogue

@export var dialogue_id: String = ""
@export var lines: Array[Dictionary] = []
@export var metadata: Dictionary = {}

## Structure d'une ligne de dialogue :
## {
##   "speaker": "nom_du_personnage",
##   "text": "Texte du dialogue",
##   "text_key": "DIALOGUE_KEY",  # Clé de traduction (optionnel)
##   "portrait": "res://path/to/portrait.png",  # (optionnel)
##   "emotion": "happy",  # (optionnel)
##   "speed": 50.0,  # Vitesse du texte (optionnel)
##   "auto_advance": false,  # Auto-avance (optionnel)
##   "auto_delay": 2.0,  # Délai avant auto-avance (optionnel)
##   "choices": [],  # Choix possibles (optionnel)
##   "event": {},  # Événement à déclencher (optionnel)
## }

func _init(id: String = "", dialogue_lines: Array = []) -> void:
	dialogue_id = id
	for line in dialogue_lines:
		lines.append(line)

func add_line(line_data: Dictionary) -> void:
	"""Ajoute une ligne de dialogue"""
	lines.append(line_data)

func get_line(index: int) -> Dictionary:
	"""Récupère une ligne par son index"""
	if index >= 0 and index < lines.size():
		return lines[index]
	return {}

func get_line_count() -> int:
	"""Retourne le nombre de lignes"""
	return lines.size()

## Crée un DialogueData depuis un dictionnaire JSON
static func from_dict(data: Dictionary) -> DialogueData:
	var dialogue = DialogueData.new()
	dialogue.dialogue_id = data.get("dialogue_id", "")
	dialogue.metadata = data.get("metadata", {})
	
	var raw_lines = data.get("lines", [])
	for line in raw_lines:
		dialogue.lines.append(line)
	
	return dialogue

## Convertit en dictionnaire pour sauvegarde
func to_dict() -> Dictionary:
	return {
		"dialogue_id": dialogue_id,
		"lines": lines,
		"metadata": metadata
	}
