extends RefCounted
class_name Command
## Interface pour le pattern Command
## Permet undo/redo, replay, logging automatique

var is_executed: bool = false
var timestamp: float = 0.0
var description: String = ""

func execute() -> bool:
	"""Exécute la commande"""
	if is_executed:
		push_warning("[Command] Commande déjà exécutée : ", description)
		return false
	
	timestamp = Time.get_unix_time_from_system()
	var success = _do_execute()
	
	if success:
		is_executed = true
	
	return success

func undo() -> bool:
	"""Annule la commande"""
	if not is_executed:
		push_warning("[Command] Impossible d'annuler une commande non exécutée")
		return false
	
	var success = _do_undo()
	
	if success:
		is_executed = false
	
	return success

func _do_execute() -> bool:
	"""À surcharger : implémentation de l'exécution"""
	push_error("[Command] _do_execute() non implémenté")
	return false

func _do_undo() -> bool:
	"""À surcharger : implémentation de l'annulation"""
	push_error("[Command] _do_undo() non implémenté")
	return false

func get_description() -> String:
	return description
