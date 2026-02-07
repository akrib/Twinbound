extends Node
## MovementModule3D - Gère le déplacement des unités en 3D

class_name MovementModule3D

signal movement_started(unit: BattleUnit3D)
signal movement_completed(unit: BattleUnit3D, path: Array)

var terrain: TerrainModule3D
var unit_manager: UnitManager3D

const MOVEMENT_SPEED: float = 3.0  # unités/sec
const MOVEMENT_COLOR: Color = Color(0.3, 0.6, 1.0, 0.5)

# ============================================================================
# VALIDATION
# ============================================================================

func can_move_to(unit: BattleUnit3D, target: Vector2i, bypass_movement_check: bool = false) -> bool:
	if not bypass_movement_check and not unit.can_move():
		return false
	if not terrain.is_in_bounds(target):
		return false
	if not terrain.is_walkable(target):
		return false
	if unit_manager.is_position_occupied(target):
		return false
	
	# ✅ En mode repos (bypass), portée = 1, sinon portée normale
	var max_range = 1 if bypass_movement_check else unit.movement_range
	var path = calculate_path(unit.grid_position, target, max_range)
	return not path.is_empty()
# ============================================================================
# MOUVEMENT
# ============================================================================

func move_unit(unit: BattleUnit3D, target: Vector2i, bypass_movement_check: bool = false) -> void:
	if not can_move_to(unit, target, bypass_movement_check):
		push_warning("[MovementModule3D] Mouvement invalide")
		return
	
	# ✅ Utiliser la portée correcte selon le mode
	var max_range = 1 if bypass_movement_check else unit.movement_range
	var path = calculate_path(unit.grid_position, target, max_range)
	if path.is_empty():
		return
	
	movement_started.emit(unit)
	await _animate_movement_3d(unit, path)
	unit_manager.move_unit(unit, target)
	movement_completed.emit(unit, path)
	GameRoot.global_logger.debug("MOVEMENT_MODULE", "%s déplacé à %s" % [unit.unit_name,target])

func _animate_movement_3d(unit: BattleUnit3D, path: Array) -> void:
	"""Anime le déplacement 3D le long d'un chemin"""
	for i in range(1, path.size()):
		var next_pos = path[i]
		var world_2d = terrain.grid_to_world(next_pos)
		var world_3d = Vector3(world_2d.x, unit.position.y, world_2d.y)
		
		var distance = unit.position.distance_to(world_3d)
		var duration = distance / MOVEMENT_SPEED
		
		var tween = unit.create_tween()
		tween.tween_property(unit, "position", world_3d, duration).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		
		await unit.get_tree().create_timer(0.05).timeout

# ============================================================================
# PORTÉE & PATHFINDING
# ============================================================================

func calculate_reachable_positions(unit: BattleUnit3D) -> Array[Vector2i]:
	"""Calcule toutes les positions accessibles"""
	var start = unit.grid_position
	var max_movement = unit.movement_range
	
	var reachable: Array[Vector2i] = []
	var visited: Dictionary = {start: 0}
	var frontier: Array = [start]
	
	while not frontier.is_empty():
		var current = frontier.pop_front()
		var current_cost = visited[current]
		
		for neighbor in terrain.get_neighbors(current):
			if not terrain.is_walkable(neighbor):
				continue
			
			var move_cost = terrain.get_movement_cost(neighbor)
			var new_cost = current_cost + move_cost
			
			if new_cost > max_movement:
				continue
			
			if visited.has(neighbor) and visited[neighbor] <= new_cost:
				continue
			
			if neighbor != start and unit_manager.is_position_occupied(neighbor):
				continue
			
			visited[neighbor] = new_cost
			frontier.append(neighbor)
	
	for pos in visited.keys():
		if pos != start:
			reachable.append(pos)
	
	return reachable

func calculate_path(from: Vector2i, to: Vector2i, max_movement: float) -> Array:
	"""Calcule le chemin optimal avec A*"""
	if from == to:
		return [from]
	
	var open_set: Array[Vector2i] = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var f_score: Dictionary = {from: _heuristic(from, to)}
	
	while not open_set.is_empty():
		var current = _get_lowest_f_score(open_set, f_score)
		
		if current == to:
			return _reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		for neighbor in terrain.get_neighbors(current):
			if not terrain.is_walkable(neighbor):
				continue
			
			if neighbor != to and unit_manager.is_position_occupied(neighbor):
				continue
			
			var move_cost = terrain.get_movement_cost(neighbor)
			var tentative_g_score = g_score[current] + move_cost
			
			if neighbor != to and tentative_g_score > max_movement:
				continue
			
			if not g_score.has(neighbor) or tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, to)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return []

func _heuristic(from: Vector2i, to: Vector2i) -> float:
	return abs(to.x - from.x) + abs(to.y - from.y)

func _get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2i:
	var lowest = open_set[0]
	var lowest_score = f_score.get(lowest, INF)
	
	for node in open_set:
		var score = f_score.get(node, INF)
		if score < lowest_score:
			lowest = node
			lowest_score = score
	
	return lowest

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	return path

# ============================================================================
# REPOS : DÉPLACEMENT D'UNE CASE (NOUVEAU - AJOUTER)
# ============================================================================

func calculate_single_step_positions(unit: BattleUnit3D) -> Array[Vector2i]:
	"""
	Calcule les positions accessibles à exactement 1 case de distance
	Utilisé pour le système de repos (inertie)
	
	@param unit : Unité qui utilise le repos
	@return Array de positions accessibles en 1 déplacement
	"""
	
	if not unit:
		GameRoot.global_logger.warning("MOVEMENT_MODULE", "calculate_single_step_positions : unité nulle")
		return []
	
	var positions: Array[Vector2i] = []
	
	# Les 4 directions cardinales
	var directions = [
		Vector2i(1, 0),   # Droite
		Vector2i(-1, 0),  # Gauche
		Vector2i(0, 1),   # Bas
		Vector2i(0, -1)   # Haut
	]
	
	for dir in directions:
		var neighbor = unit.grid_position + dir
		
		# Vérifier les limites de la carte
		if not terrain.is_in_bounds(neighbor):
			continue
		
		# Vérifier si la case est marchable
		if not terrain.is_walkable(neighbor):
			continue
		
		# Vérifier le coût de déplacement (doit être ≤ 1)
		var move_cost = terrain.get_movement_cost(neighbor)
		if move_cost > 1.0:
			GameRoot.global_logger.debug("MOVEMENT_MODULE", "Case %s ignorée (coût: %.1f > 1)" % [neighbor, move_cost])
			continue
		
		# Vérifier que la case n'est pas occupée
		if unit_manager.is_position_occupied(neighbor):
			GameRoot.global_logger.debug("MOVEMENT_MODULE", "Case %s occupée" % neighbor)
			continue
		
		# Case valide !
		positions.append(neighbor)
	
	GameRoot.global_logger.debug("MOVEMENT_MODULE", "%s : %d case(s) accessible(s) avec repos" % [
		unit.unit_name,
		positions.size()
	])
	
	return positions
