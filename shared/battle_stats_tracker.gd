extends Node
## BattleStatsTracker - Enregistre toutes les statistiques du combat
## MVP, efficacité, actions, etc.

class_name BattleStatsTracker

# ============================================================================
# SIGNAUX
# ============================================================================

signal stat_recorded(stat_name: String, value: Variant)

# ============================================================================
# STATISTIQUES GLOBALES
# ============================================================================

var global_stats: Dictionary = {
	"turns_elapsed": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"total_healing": 0,
	"units_killed": 0,
	"units_lost": 0,
	"total_movements": 0,
	"total_actions": 0,
	"abilities_used": 0,
	"start_time": 0,
	"end_time": 0
}

# ============================================================================
# STATISTIQUES PAR UNITÉ
# ============================================================================

var unit_stats: Dictionary = {}
# Format: unit_id -> {damage_dealt, damage_taken, kills, movements, actions, ...}

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	global_stats.start_time = Time.get_unix_time_from_system()

# ============================================================================
# ENREGISTREMENT DES UNITÉS
# ============================================================================

func register_unit(unit: BattleUnit3D) -> void:
	unit_stats[unit.unit_id] = {
		# ❌ plus de référence au node
		"id": unit.unit_id,
		"name": unit.unit_name,
		"is_player": unit.is_player_unit,

		"damage_dealt": 0,
		"damage_taken": 0,
		"healing_done": 0,
		"healing_received": 0,
		"kills": 0,
		"deaths": 0,
		"movements": 0,
		"actions": 0,
		"abilities_used": 0,
		"turns_survived": 0,
		"was_alive": true
	}
# ============================================================================
# ENREGISTREMENT DES ACTIONS
# ============================================================================

func record_movement(unit: BattleUnit3D, path: Array) -> void:
	"""Enregistre un déplacement"""
	
	if not unit_stats.has(unit.unit_id):
		return
	
	unit_stats[unit.unit_id].movements += 1
	global_stats.total_movements += 1
	
	stat_recorded.emit("movement", unit.unit_id)

func record_action(attacker: BattleUnit3D, target: BattleUnit3D, action_type: String) -> void:
	"""Enregistre une action (attaque, capacité, etc.)"""
	
	if not unit_stats.has(attacker.unit_id):
		return
	
	unit_stats[attacker.unit_id].actions += 1
	global_stats.total_actions += 1
	
	if action_type != "attack":
		unit_stats[attacker.unit_id].abilities_used += 1
		global_stats.abilities_used += 1
	
	stat_recorded.emit("action", attacker.unit_id)

func record_damage(attacker: BattleUnit3D, target: BattleUnit3D, damage: int) -> void:
	"""Enregistre des dégâts infligés"""
	
	if unit_stats.has(attacker.unit_id):
		unit_stats[attacker.unit_id].damage_dealt += damage
		global_stats.total_damage_dealt += damage
	
	if unit_stats.has(target.unit_id):
		unit_stats[target.unit_id].damage_taken += damage
		
		if target.is_player_unit:
			global_stats.total_damage_taken += damage
	
	stat_recorded.emit("damage", damage)

func record_healing(healer: BattleUnit3D, target: BattleUnit3D, amount: int) -> void:
	"""Enregistre des soins"""
	
	if unit_stats.has(healer.unit_id):
		unit_stats[healer.unit_id].healing_done += amount
	
	if unit_stats.has(target.unit_id):
		unit_stats[target.unit_id].healing_received += amount
		global_stats.total_healing += amount
	
	stat_recorded.emit("healing", amount)

func record_kill(killer: BattleUnit3D, victim: BattleUnit3D) -> void:
	"""Enregistre une élimination"""
	
	if unit_stats.has(killer.unit_id):
		unit_stats[killer.unit_id].kills += 1
		global_stats.units_killed += 1
	
	stat_recorded.emit("kill", killer.unit_id)

func record_death(unit: BattleUnit3D) -> void:
	if unit_stats.has(unit.unit_id):
		unit_stats[unit.unit_id].deaths += 1
		unit_stats[unit.unit_id].was_alive = false

	if unit.is_player_unit:
		global_stats.units_lost += 1

	stat_recorded.emit("death", unit.unit_id)

func record_turn_end() -> void:
	global_stats.turns_elapsed += 1

	for unit_id in unit_stats:
		if unit_stats[unit_id].was_alive:
			unit_stats[unit_id].turns_survived += 11

# ============================================================================
# CALCULS
# ============================================================================

func get_final_stats() -> Dictionary:
	"""Retourne les statistiques finales"""
	
	global_stats.end_time = Time.get_unix_time_from_system()
	var duration = global_stats.end_time - global_stats.start_time
	
	return {
		"global": global_stats.duplicate(),
		"duration_seconds": duration,
		"efficiency": calculate_efficiency(),
		"units": get_unit_summaries()
	}

func calculate_efficiency() -> float:
	"""Calcule un score d'efficacité global"""
	
	var score = 0.0
	
	# Bonus pour les éliminations
	score += global_stats.units_killed * 100
	
	# Malus pour les pertes
	score -= global_stats.units_lost * 200
	
	# Bonus pour les dégâts
	score += global_stats.total_damage_dealt * 0.5
	
	# Malus pour les dégâts reçus
	score -= global_stats.total_damage_taken * 0.3
	
	# Bonus pour l'économie d'actions
	if global_stats.total_actions > 0:
		var action_efficiency = float(global_stats.units_killed) / float(global_stats.total_actions)
		score += action_efficiency * 100
	
	return max(0.0, score)

func get_unit_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []

	for unit_id in unit_stats:
		var stats = unit_stats[unit_id]

		summaries.append({
			"id": stats.id,
			"name": stats.name,
			"is_player": stats.is_player,
			"is_alive": stats.was_alive,
			"damage_dealt": stats.damage_dealt,
			"damage_taken": stats.damage_taken,
			"kills": stats.kills,
			"deaths": stats.deaths,
			"actions": stats.actions,
			"score": _calculate_unit_score(stats)
		})

	return summaries

func _calculate_unit_score(stats: Dictionary) -> float:
	"""Calcule un score individuel pour une unité"""
	
	var score = 0.0
	
	score += stats.damage_dealt * 1.0
	score += stats.kills * 500
	score -= stats.damage_taken * 0.5
	score -= stats.deaths * 1000
	score += stats.healing_done * 2.0
	score += stats.actions * 10
	
	return max(0.0, score)

# ============================================================================
# MVP
# ============================================================================

func get_mvp() -> Dictionary:
	"""Retourne les stats du MVP (data only)"""
	
	var best_stats: Dictionary = {}
	var best_score: float = -INF
	
	for unit_id in unit_stats:
		var stats = unit_stats[unit_id]
		
		if not stats.is_player:
			continue
		
		var score = _calculate_unit_score(stats)
		
		if score > best_score:
			best_score = score
			best_stats = stats
	
	return best_stats


# ============================================================================
# DEBUG
# ============================================================================

func print_stats() -> void:
	"""Affiche toutes les statistiques (debug)"""
	
	print("\n=== STATISTIQUES DE COMBAT ===")
	print("Tours: ", global_stats.turns_elapsed)
	print("Dégâts totaux: ", global_stats.total_damage_dealt)
	print("Éliminations: ", global_stats.units_killed)
	print("Pertes: ", global_stats.units_lost)
	print("Efficacité: ", calculate_efficiency())
	
	print("\nUnités:")
	for summary in get_unit_summaries():
		print("  - ", summary.name, " [Score: ", summary.score, "]")
	
	var mvp = get_mvp()
	if mvp:
		print("\nMVP: ", mvp.unit_name)
	
	print("==============================\n")
	
	
	
