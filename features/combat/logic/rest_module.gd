extends Node
## RestModule - Gère le système de repos (inertie) global
## Jauge commune par faction, permet de parcourir des cases supplémentaires

class_name RestModule

# ============================================================================
# SIGNAUX
# ============================================================================

signal rest_points_changed(is_player_faction: bool, new_value: int)
signal rest_point_used(unit: BattleUnit3D)
signal rest_depleted(is_player_faction: bool)

# ============================================================================
# CONFIGURATION
# ============================================================================

const MAX_REST_POINTS: int = 2
const INITIAL_REST_POINTS: int = 2

# ============================================================================
# DONNÉES
# ============================================================================

var player_rest_points: int = INITIAL_REST_POINTS
var enemy_rest_points: int = INITIAL_REST_POINTS

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	GameRoot.global_logger.info("REST_MODULE", "Module de repos initialisé (Max: %d points)" % MAX_REST_POINTS)

func reset_for_new_battle() -> void:
	"""Réinitialise les jauges de repos pour un nouveau combat"""
	player_rest_points = INITIAL_REST_POINTS
	enemy_rest_points = INITIAL_REST_POINTS
	
	rest_points_changed.emit(true, player_rest_points)
	rest_points_changed.emit(false, enemy_rest_points)
	
	GameRoot.global_logger.info("REST_MODULE", "Jauges de repos réinitialisées (%d points chacune)" % INITIAL_REST_POINTS)

# ============================================================================
# GETTERS
# ============================================================================

func get_rest_points(is_player: bool) -> int:
	"""Retourne les points de repos d'une faction"""
	return player_rest_points if is_player else enemy_rest_points

func can_use_rest(unit: BattleUnit3D) -> bool:
	"""Vérifie si une unité peut utiliser le repos"""
	if not unit or not unit.is_alive():
		return false
	
	var rest = get_rest_points(unit.is_player_unit)
	return rest > 0

# ============================================================================
# ACTIONS
# ============================================================================

func use_rest_point(unit: BattleUnit3D) -> bool:
	"""
	Consomme un point de repos pour une unité
	
	@return true si succès, false si impossible
	"""
	if not can_use_rest(unit):
		GameRoot.global_logger.warning("REST_MODULE", "%s : impossible d'utiliser le repos" % unit.unit_name)
		return false
	
	# Consommer le point
	if unit.is_player_unit:
		player_rest_points -= 1
		rest_points_changed.emit(true, player_rest_points)
		
		if player_rest_points == 0:
			rest_depleted.emit(true)
	else:
		enemy_rest_points -= 1
		rest_points_changed.emit(false, enemy_rest_points)
		
		if enemy_rest_points == 0:
			rest_depleted.emit(false)
	
	rest_point_used.emit(unit)
	
	GameRoot.global_logger.info("REST_MODULE", "%s utilise 1 repos (reste: %d)" % [
		unit.unit_name,
		get_rest_points(unit.is_player_unit)
	])
	
	return true

func add_rest_point(is_player: bool, amount: int = 1) -> void:
	"""
	Ajoute des points de repos (via conditions de combat)
	
	@param is_player : Faction concernée
	@param amount : Nombre de points à ajouter
	"""
	if is_player:
		player_rest_points = min(MAX_REST_POINTS, player_rest_points + amount)
		rest_points_changed.emit(true, player_rest_points)
	else:
		enemy_rest_points = min(MAX_REST_POINTS, enemy_rest_points + amount)
		rest_points_changed.emit(false, enemy_rest_points)
	
	GameRoot.global_logger.info("REST_MODULE", "Faction %s : +%d repos (total: %d)" % [
		"Joueur" if is_player else "Ennemi",
		amount,
		get_rest_points(is_player)
	])

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_state() -> void:
	"""Affiche l'état actuel des jauges de repos"""
	print("\n=== RestModule - État ===")
	print("Joueur : %d/%d" % [player_rest_points, MAX_REST_POINTS])
	print("Ennemi : %d/%d" % [enemy_rest_points, MAX_REST_POINTS])
	print("=========================\n")
