extends RefCounted
class_name ValidationResult
## Résultat d'une validation de données

var is_valid: bool = true
var errors: Array[String] = []
var data: Variant = null

func add_error(message: String) -> void:
	"""Ajoute une erreur et marque le résultat comme invalide"""
	errors.append(message)
	is_valid = false

func has_errors() -> bool:
	"""Vérifie si des erreurs sont présentes"""
	return not errors.is_empty()

func get_errors_string() -> String:
	"""Retourne toutes les erreurs en une seule chaîne"""
	return "\n".join(errors)

func clear() -> void:
	"""Réinitialise le résultat"""
	is_valid = true
	errors.clear()
	data = null
