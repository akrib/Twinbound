# scripts/systems/duo/duo_system.gd
extends Node
class_name DuoSystem

## ⭐ MODULE CRITIQUE : Système de Duo
## Gère la formation, validation et rupture des duos de combat

# ============================================================================
# SIGNAUX
# ============================================================================

signal duo_formed(duo_data: Dictionary)
signal duo_broken(duo_id: String)
signal roles_swapped(duo_id: String)
signal duo_validation_failed(reason: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

const MAX_DUO_DISTANCE: int = 1  # Distance max en cases (adjacence)
const DUO_FORMATION_COST: int = 0  # Coût en action (0 = gratuit)

# ============================================================================
# DONNÉES
# ============================================================================

## Structure d'un duo
class DuoData:
	var duo_id: String
	var leader: BattleUnit3D
	var support: BattleUnit3D
	var formation_time: float
	var is_active: bool = true
	
	func _init(p_leader: BattleUnit3D, p_support: BattleUnit3D):
		leader = p_leader
		support = p_support
		duo_id = _generate_duo_id(leader, support)
		formation_time = Time.get_unix_time_from_system()
	
	static func _generate_duo_id(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> String:
		var ids = [unit_a.unit_id, unit_b.unit_id]
		ids.sort()
		return ids[0] + "_" + ids[1]

## Stockage des duos actifs
var active_duos: Dictionary = {}  # duo_id -> DuoData

## Référence au terrain (injectée)
var terrain_module: TerrainModule3D = null

# ============================================================================
# FORMATION DE DUO
# ============================================================================

func try_form_duo(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> bool:
	"""
	Tente de former un duo entre deux unités
	
	@return true si succès, false sinon
	"""
	
	# Validation
	var validation_result = validate_duo_formation(unit_a, unit_b)
	
	if not validation_result.is_valid:
		duo_validation_failed.emit(validation_result.reason)
		print("[DuoSystem] ❌ Formation échouée : ", validation_result.reason)
		return false
	
	# Créer le duo
	var duo = DuoData.new(unit_a, unit_b)
	active_duos[duo.duo_id] = duo
	
	# Émettre le signal
	var duo_dict = _duo_to_dict(duo)
	duo_formed.emit(duo_dict)
	
	print("[DuoSystem] ✅ Duo formé : ", unit_a.unit_name, " + ", unit_b.unit_name)
	
	return true

func break_duo(duo_id: String) -> void:
	"""Rompt un duo existant"""
	
	if not active_duos.has(duo_id):
		push_warning("[DuoSystem] Duo inexistant : ", duo_id)
		return
	
	var duo = active_duos[duo_id]
	duo.is_active = false
	active_duos.erase(duo_id)
	
	duo_broken.emit(duo_id)
	
	print("[DuoSystem] 💔 Duo rompu : ", duo_id)

func swap_roles(duo_id: String) -> bool:
	"""Inverse les rôles leader/support"""
	
	if not active_duos.has(duo_id):
		return false
	
	var duo = active_duos[duo_id]
	var temp = duo.leader
	duo.leader = duo.support
	duo.support = temp
	
	roles_swapped.emit(duo_id)
	
	print("[DuoSystem] 🔄 Rôles inversés : ", duo_id)
	
	return true

# ============================================================================
# VALIDATION
# ============================================================================

class DuoValidationResult:
	var is_valid: bool = true
	var reason: String = ""

func validate_duo_formation(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> DuoValidationResult:
	"""Valide si deux unités peuvent former un duo"""
	
	var result = DuoValidationResult.new()
	
	# Vérifier que les unités existent
	if not unit_a or not unit_b:
		result.is_valid = false
		result.reason = "Unité nulle"
		return result
	
	# Vérifier que ce sont des unités différentes
	if unit_a == unit_b:
		result.is_valid = false
		result.reason = "Même unité"
		return result
	
	# Vérifier la même équipe
	if not validate_same_team(unit_a, unit_b):
		result.is_valid = false
		result.reason = "Équipes différentes"
		return result
	
	# Vérifier disponibilité
	if not validate_availability(unit_a, unit_b):
		result.is_valid = false
		result.reason = "Unité(s) déjà en duo"
		return result
	
	# Vérifier adjacence
	if not validate_adjacency(unit_a, unit_b):
		result.is_valid = false
		result.reason = "Unités trop éloignées"
		return result
	
	return result

func validate_adjacency(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> bool:
	"""Vérifie si deux unités sont adjacentes"""
	
	if not terrain_module:
		push_error("[DuoSystem] TerrainModule non injecté!")
		return false
	
	var distance = terrain_module.get_distance(
		unit_a.grid_position,
		unit_b.grid_position
	)
	
	return distance <= MAX_DUO_DISTANCE

func validate_same_team(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> bool:
	"""Vérifie si deux unités sont dans la même équipe"""
	return unit_a.is_player_unit == unit_b.is_player_unit

func validate_availability(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> bool:
	"""Vérifie qu'aucune unité n'est déjà en duo"""
	
	for duo_id in active_duos:
		var duo = active_duos[duo_id]
		
		if duo.leader == unit_a or duo.support == unit_a:
			return false
		
		if duo.leader == unit_b or duo.support == unit_b:
			return false
	
	return true

# ============================================================================
# GETTERS
# ============================================================================

func get_duo_for_unit(unit: BattleUnit3D) -> Dictionary:
	"""Retourne le duo contenant cette unité, ou {} si aucun"""
	
	for duo_id in active_duos:
		var duo = active_duos[duo_id]
		
		if duo.leader == unit or duo.support == unit:
			return _duo_to_dict(duo)
	
	return {}

func get_all_active_duos() -> Array[Dictionary]:
	"""Retourne tous les duos actifs"""
	
	var result: Array[Dictionary] = []
	
	for duo_id in active_duos:
		result.append(_duo_to_dict(active_duos[duo_id]))
	
	return result

func is_unit_in_duo(unit: BattleUnit3D) -> bool:
	"""Vérifie si une unité est dans un duo"""
	return not get_duo_for_unit(unit).is_empty()

func get_duo_by_id(duo_id: String) -> Dictionary:
	"""Retourne un duo par son ID"""
	
	if active_duos.has(duo_id):
		return _duo_to_dict(active_duos[duo_id])
	
	return {}

# ============================================================================
# HELPERS
# ============================================================================

func _duo_to_dict(duo: DuoData) -> Dictionary:
	"""Convertit un DuoData en Dictionary"""
	
	return {
		"duo_id": duo.duo_id,
		"leader": duo.leader,
		"support": duo.support,
		"formation_time": duo.formation_time,
		"is_active": duo.is_active
	}

func clear_all_duos() -> void:
	"""Rompt tous les duos (fin de combat)"""
	
	var duo_ids = active_duos.keys()
	
	for duo_id in duo_ids:
		break_duo(duo_id)
	
	print("[DuoSystem] 🧹 Tous les duos rompus")

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_duos() -> void:
	"""Affiche tous les duos actifs (debug)"""
	
	print("\n=== DuoSystem - Duos Actifs ===")
	print("Nombre de duos : ", active_duos.size())
	
	for duo_id in active_duos:
		var duo = active_duos[duo_id]
		print("  - ", duo.leader.unit_name, " + ", duo.support.unit_name)
	
	print("================================\n")
