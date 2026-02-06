extends Node
## AIModule3D - Intelligence artificielle pour les ennemis (version 3D)
## ✅ VERSION MISE À JOUR : Support des attaques en duo

class_name AIModule3D

signal ai_turn_started()
signal ai_turn_completed()
signal ai_action_taken(unit: BattleUnit3D, action: String)

var terrain: TerrainModule3D
var unit_manager: UnitManager3D
var movement_module: MovementModule3D
var action_module: ActionModule3D

# ✅ NOUVEAU : Référence au DuoSystem
var duo_system: DuoSystem

enum AIBehavior {
	AGGRESSIVE,
	DEFENSIVE,
	BALANCED,
	SUPPORT
}

var default_behavior: AIBehavior = AIBehavior.AGGRESSIVE

# ============================================================================
# EXÉCUTION
# ============================================================================

func execute_enemy_turn() -> void:
	ai_turn_started.emit()
	
	var enemies = unit_manager.get_alive_enemy_units()
	print("[AIModule3D] === Tour IA (", enemies.size(), " unités) ===")
	
	enemies.sort_custom(_sort_by_priority)
	
	for enemy in enemies:
		await _execute_unit_turn(enemy)
		await get_tree().create_timer(0.5).timeout
	
	ai_turn_completed.emit()
	print("[AIModule3D] === Fin du tour IA ===")

func _execute_unit_turn(unit: BattleUnit3D) -> void:
	if not unit.is_alive():
		return
	
	print("[AIModule3D] ", unit.unit_name, " joue")
	
	var decision = evaluate_unit_action(unit)
	
	if decision.has("move_to") and unit.can_move():
		var target_pos = decision.move_to
		if movement_module.can_move_to(unit, target_pos):
			await movement_module.move_unit(unit, target_pos)
			unit.movement_used = true
	
	if decision.has("action") and unit.can_act():
		await _execute_ai_action(unit, decision)
		unit.action_used = true

# ============================================================================
# ÉVALUATION
# ============================================================================

func evaluate_unit_action(unit: BattleUnit3D) -> Dictionary:
	var best_decision: Dictionary = {"action": "wait", "score": 0.0}
	
	var target = find_best_attack_target(unit)
	
	if not target:
		var move_pos = find_best_movement(unit)
		return {"action": "wait", "move_to": move_pos, "score": 10.0}
	
	# ✅ NOUVEAU : Vérifier si on peut attaquer en duo
	var duo_partner = find_best_duo_partner(unit)
	
	if action_module.can_attack(unit, target):
		best_decision = {
			"action": "attack",
			"target": target,
			"duo_partner": duo_partner,  # ✅ NOUVEAU
			"score": 100.0
		}
	else:
		var move_pos = find_position_to_attack(unit, target)
		if move_pos != unit.grid_position:
			best_decision = {
				"action": "attack",
				"target": target,
				"duo_partner": duo_partner,  # ✅ NOUVEAU
				"move_to": move_pos,
				"score": 80.0
			}
	
	return best_decision

func find_best_duo_partner(unit: BattleUnit3D) -> BattleUnit3D:
	"""Trouve le meilleur partenaire de duo pour une unité ennemie"""
	
	var enemies = unit_manager.get_alive_enemy_units()
	var best_partner: BattleUnit3D = null
	var best_score: float = -INF
	
	for ally in enemies:
		if ally == unit:
			continue
		
		# ✅ Vérifier l'adjacence cardinale stricte
		if not _is_cardinal_adjacent(unit.grid_position, ally.grid_position):
			continue
		
		var score = _evaluate_duo_synergy(unit, ally)
		
		if score > best_score:
			best_score = score
			best_partner = ally
	
	return best_partner
	
func _evaluate_duo_synergy(unit_a: BattleUnit3D, unit_b: BattleUnit3D) -> float:
	"""Évalue la synergie d'un duo potentiel"""
	
	var score = 0.0
	
	# Préférer les unités avec haute attaque + support
	if unit_a.attack_power > unit_b.attack_power:
		score += 10.0
	
	# Bonus si les deux unités ont des HP élevés
	score += (unit_a.get_hp_percentage() + unit_b.get_hp_percentage()) * 5.0
	
	# Bonus pour diversité de stats
	var stat_diff = abs(unit_a.attack_power - unit_b.defense_power)
	score += stat_diff * 0.5
	
	return score

func find_best_attack_target(unit: BattleUnit3D) -> BattleUnit3D:
	var player_units = unit_manager.get_alive_player_units()
	
	if player_units.is_empty():
		return null
	
	var best_target: BattleUnit3D = null
	var best_score: float = -INF
	
	for target in player_units:
		var score = _evaluate_target(unit, target)
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target

func _can_form_duo_with_any_ally(unit: BattleUnit3D) -> bool:
	"""Vérifie si l'unité peut former un duo avec AU MOINS un allié vivant"""
	
	var enemies = unit_manager.get_alive_enemy_units()
	
	for ally in enemies:
		if ally == unit:
			continue
		
		# Vérifier si l'allié peut encore agir
		if not ally.can_act():
			continue
		
		# Vérifier l'adjacence cardinale
		if not _is_cardinal_adjacent(unit.grid_position, ally.grid_position):
			continue
		
		# Duo possible trouvé
		return true
	
	# Aucun duo possible
	return false

func _evaluate_target(attacker: BattleUnit3D, target: BattleUnit3D) -> float:
	var score = 0.0
	
	var distance = terrain.get_distance(attacker.grid_position, target.grid_position)
	score += (20.0 - distance) * 10.0
	
	var hp_percent = target.get_hp_percentage()
	score += (1.0 - hp_percent) * 100.0
	
	score += (50.0 - target.defense_power) * 2.0
	
	return score

func find_best_movement(unit: BattleUnit3D) -> Vector2i:
	var player_units = unit_manager.get_alive_player_units()
	
	if player_units.is_empty():
		return unit.grid_position
	
	var closest_enemy: BattleUnit3D = null
	var closest_distance: int = 999999
	
	for player_unit in player_units:
		var dist = terrain.get_distance(unit.grid_position, player_unit.grid_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_enemy = player_unit
	
	if not closest_enemy:
		return unit.grid_position
	
	return find_position_to_attack(unit, closest_enemy)

func find_position_to_attack(attacker: BattleUnit3D, target: BattleUnit3D) -> Vector2i:
	var reachable = movement_module.calculate_reachable_positions(attacker)
	
	if reachable.is_empty():
		return attacker.grid_position
	
	var best_pos: Vector2i = attacker.grid_position
	var best_distance: int = 999999
	
	for pos in reachable:
		var distance = terrain.get_distance(pos, target.grid_position)
		
		if distance <= attacker.attack_range:
			return pos
		
		if distance < best_distance:
			best_distance = distance
			best_pos = pos
	
	return best_pos

# ============================================================================
# EXÉCUTION DES ACTIONS
# ============================================================================

func _execute_ai_action(unit: BattleUnit3D, decision: Dictionary) -> void:
	match decision.get("action", "wait"):
		"attack":
			var target = decision.get("target")
			var duo_partner = decision.get("duo_partner")
			
			if target and action_module.can_attack(unit, target):
				# ✅ NOUVELLE RÈGLE : Si pas de partenaire trouvé, vérifier s'il y a d'autres alliés
				if not duo_partner:
					# Compter les alliés vivants
					var alive_allies = unit_manager.get_alive_enemy_units()
					
					# S'il y a plus d'un ennemi vivant (l'unité elle-même + au moins un autre)
					if alive_allies.size() > 1:
						# Vérifier si on PEUT former un duo avec quelqu'un
						if _can_form_duo_with_any_ally(unit):
							print("[AIModule3D] ⚠️ Attaque solo refusée : duo possible avec un allié")
							# Ne PAS attaquer, passer le tour
							ai_action_taken.emit(unit, "wait")
							return
				
				# Si on arrive ici, soit on a un partenaire, soit on est le dernier survivant
				if duo_partner:
					# Vérifier adjacence et si le partenaire peut agir
					if _is_cardinal_adjacent(unit.grid_position, duo_partner.grid_position):
						if duo_partner.can_act():
							print("[AIModule3D] 💫 Duo IA temporaire : ", unit.unit_name, " + ", duo_partner.unit_name)
							# Marquer le partenaire comme ayant agi
							duo_partner.action_used = true
							duo_partner.movement_used = true
						else:
							# Le partenaire ne peut plus agir
							duo_partner = null
					else:
						duo_partner = null
				
				await action_module.execute_attack(unit, target, duo_partner)
				ai_action_taken.emit(unit, "attack")
		
		"wait":
			ai_action_taken.emit(unit, "wait")

# ============================================================================
# UTILITAIRES
# ============================================================================

func _sort_by_priority(a: BattleUnit3D, b: BattleUnit3D) -> bool:
	var player_units = unit_manager.get_alive_player_units()
	
	if player_units.is_empty():
		return false
	
	var dist_a = _min_distance_to_players(a, player_units)
	var dist_b = _min_distance_to_players(b, player_units)
	
	return dist_a < dist_b

func _min_distance_to_players(unit: BattleUnit3D, players: Array) -> int:
	var min_dist = 999999
	
	for player in players:
		var dist = terrain.get_distance(unit.grid_position, player.grid_position)
		if dist < min_dist:
			min_dist = dist
	
	return min_dist


func _is_cardinal_adjacent(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Vérifie si deux positions sont adjacentes en cardinal"""
	var diff = pos_b - pos_a
	return (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0)
