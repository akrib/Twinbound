extends Node
## ObjectiveModule - Gère les objectifs de mission

class_name ObjectiveModule

# ============================================================================
# SIGNAUX
# ============================================================================

signal objective_completed(objective_id: String)
signal all_objectives_completed()
signal objective_failed(objective_id: String)

# ============================================================================
# DONNÉES
# ============================================================================

var objectives: Dictionary = {}
# Format: objective_id -> {type, status, data, description}

var primary_objectives: Array[String] = []
var secondary_objectives: Array[String] = []

# ============================================================================
# SETUP
# ============================================================================

func setup_objectives(data: Dictionary) -> void:
	"""Configure les objectifs de la mission"""
	
	objectives.clear()
	primary_objectives.clear()
	secondary_objectives.clear()
	
	# Objectifs primaires
	for obj_data in data.get("primary", []):
		var obj_id = _generate_id()
		objectives[obj_id] = {
			"type": obj_data.type,
			"status": "pending",
			"data": obj_data,
			"description": obj_data.get("description", ""),
			"is_primary": true
		}
		primary_objectives.append(obj_id)
	
	# Objectifs secondaires
	for obj_data in data.get("secondary", []):
		var obj_id = _generate_id()
		objectives[obj_id] = {
			"type": obj_data.type,
			"status": "pending",
			"data": obj_data,
			"description": obj_data.get("description", ""),
			"is_primary": false
		}
		secondary_objectives.append(obj_id)
	
	print("[ObjectiveModule] Objectifs chargés: ", objectives.size())

# ============================================================================
# VÉRIFICATION
# ============================================================================

func check_objectives() -> void:
	"""Vérifie l'état de tous les objectifs"""
	
	for obj_id in objectives:
		if objectives[obj_id].status == "completed":
			continue
		
		var obj = objectives[obj_id]
		_check_objective(obj_id, obj)

func _check_objective(obj_id: String, obj: Dictionary) -> void:
	"""Vérifie un objectif spécifique"""
	
	match obj.type:
		"defeat_all_enemies":
			if _check_defeat_all():
				_complete_objective(obj_id)
		
		"survive_turns":
			# Sera vérifié depuis le BattleMapManager
			pass
		
		"reach_position":
			# Sera vérifié via check_position_objectives
			pass
		
		"protect_unit":
			if not _check_unit_alive(obj.data.unit_id):
				_fail_objective(obj_id)

func check_position_objectives(unit: BattleUnit3D, pos: Vector2i) -> void:
	"""Vérifie les objectifs basés sur la position"""
	
	for obj_id in objectives:
		var obj = objectives[obj_id]
		
		if obj.status != "pending":
			continue
		
		if obj.type == "reach_position":
			var target = obj.data.get("position", Vector2i(-1, -1))
			if pos == target and unit.is_player_unit:
				_complete_objective(obj_id)

# ============================================================================
# CHECKS SPÉCIFIQUES
# ============================================================================

func _check_defeat_all() -> bool:
	"""Vérifie si tous les ennemis sont morts"""
	
	# Sera implémenté via référence au UnitManager
	# ou via EventBus
	return false

func _check_unit_alive(unit_id: String) -> bool:
	"""Vérifie si une unité est vivante"""
	
	# À implémenter
	return true

# ============================================================================
# COMPLETION
# ============================================================================

func _complete_objective(obj_id: String) -> void:
	"""Marque un objectif comme complété"""
	
	if not objectives.has(obj_id):
		return
	
	objectives[obj_id].status = "completed"
	objective_completed.emit(obj_id)
	
	print("[ObjectiveModule] Objectif complété: ", objectives[obj_id].description)
	
	# Vérifier si tous les primaires sont complétés
	if are_all_primary_completed():
		all_objectives_completed.emit()

func _fail_objective(obj_id: String) -> void:
	"""Marque un objectif comme échoué"""
	
	if not objectives.has(obj_id):
		return
	
	objectives[obj_id].status = "failed"
	objective_failed.emit(obj_id)
	
	print("[ObjectiveModule] Objectif échoué: ", objectives[obj_id].description)

# ============================================================================
# GETTERS
# ============================================================================

func are_all_completed() -> bool:
	"""Vérifie si tous les objectifs sont complétés"""
	
	for obj_id in objectives:
		if objectives[obj_id].status != "completed":
			return false
	return true

func are_all_primary_completed() -> bool:
	"""Vérifie si tous les objectifs primaires sont complétés"""
	
	for obj_id in primary_objectives:
		if objectives[obj_id].status != "completed":
			return false
	return true

func get_completion_status() -> Dictionary:
	"""Retourne le statut de complétion"""
	
	var completed = 0
	var total = objectives.size()
	
	for obj_id in objectives:
		if objectives[obj_id].status == "completed":
			completed += 1
	
	return {
		"completed": completed,
		"total": total,
		"percentage": float(completed) / float(total) if total > 0 else 0.0
	}

func _generate_id() -> String:
	"""Génère un ID unique"""
	
	return "obj_" + str(Time.get_ticks_msec())
