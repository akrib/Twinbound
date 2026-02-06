extends Node3D
## TerrainModule3D - Gère le terrain 3D avec des cases cubiques
## Version 3D du module original avec MeshInstance3D

class_name TerrainModule3D

# ============================================================================
# SIGNAUX
# ============================================================================

signal generation_complete()
signal tile_changed(grid_pos: Vector2i, tile_type: int)

# ============================================================================
# ENUMS
# ============================================================================

enum TileType {
	GRASS,       # Plaine
	FOREST,      # Forêt
	MOUNTAIN,    # Montagne
	WATER,       # Eau
	ROAD,        # Route
	WALL,        # Mur
	BRIDGE,      # Pont
	CASTLE,      # Château
}

# ============================================================================
# CONFIGURATION
# ============================================================================

var tile_size: float = 1.0  # Taille d'une case en unités 3D
var tile_height: float = 0.2  # Hauteur des cases
var grid_width: int = 20
var grid_height: int = 15

# Coûts et bonus (identiques à la version 2D)
const MOVEMENT_COSTS: Dictionary = {
	TileType.GRASS: 1.0,
	TileType.FOREST: 2.0,
	TileType.MOUNTAIN: 3.0,
	TileType.WATER: INF,
	TileType.ROAD: 0.5,
	TileType.WALL: INF,
	TileType.BRIDGE: 1.0,
	TileType.CASTLE: 1.0,
}

const DEFENSE_BONUS: Dictionary = {
	TileType.GRASS: 0,
	TileType.FOREST: 10,
	TileType.MOUNTAIN: 20,
	TileType.WATER: 0,
	TileType.ROAD: 0,
	TileType.WALL: 0,
	TileType.BRIDGE: 0,
	TileType.CASTLE: 30,
}

# Couleurs des tuiles
const TILE_COLORS: Dictionary = {
	TileType.GRASS: Color(0.2, 0.7, 0.2),
	TileType.FOREST: Color(0.1, 0.5, 0.1),
	TileType.MOUNTAIN: Color(0.5, 0.5, 0.5),
	TileType.WATER: Color(0.2, 0.4, 0.8),
	TileType.ROAD: Color(0.6, 0.5, 0.4),
	TileType.WALL: Color(0.3, 0.3, 0.3),
	TileType.BRIDGE: Color(0.5, 0.4, 0.3),
	TileType.CASTLE: Color(0.7, 0.7, 0.8),
}

# Hauteurs des tuiles (pour variation de terrain)
const TILE_HEIGHTS: Dictionary = {
	TileType.GRASS: 0.0,
	TileType.FOREST: 0.1,
	TileType.MOUNTAIN: 0.5,
	TileType.WATER: -0.1,
	TileType.ROAD: 0.0,
	TileType.WALL: 0.3,
	TileType.BRIDGE: 0.0,
	TileType.CASTLE: 0.2,
}

# ============================================================================
# DONNÉES
# ============================================================================

var grid: Array[Array] = []  # Array 2D de TileType
var tile_meshes: Array[Array] = []  # Array 2D de MeshInstance3D
var tile_materials: Array[Array] = []  # Array 2D de StandardMaterial3D

# Meshes réutilisables
var box_mesh: BoxMesh
var plane_mesh: PlaneMesh

# Presets (identiques à la version 2D)
const PRESETS: Dictionary = {
	"plains": {
		"base": TileType.GRASS,
		"features": [
			{"type": TileType.FOREST, "density": 0.1},
			{"type": TileType.ROAD, "density": 0.05}
		]
	},
	"forest": {
		"base": TileType.FOREST,
		"features": [
			{"type": TileType.GRASS, "density": 0.2},
			{"type": TileType.MOUNTAIN, "density": 0.05}
		]
	},
	"castle": {
		"base": TileType.GRASS,
		"features": [
			{"type": TileType.CASTLE, "positions": [Vector2i(10, 7)]},
			{"type": TileType.WALL, "density": 0.15},
			{"type": TileType.ROAD, "density": 0.1}
		]
	},
	"mountain": {
		"base": TileType.MOUNTAIN,
		"features": [
			{"type": TileType.GRASS, "density": 0.15},
			{"type": TileType.FOREST, "density": 0.1},
			{"type": TileType.ROAD, "density": 0.05}
		]
	}
}

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_setup_meshes()
	_initialize_grid()
	print("[TerrainModule3D] Initialisé (", grid_width, "x", grid_height, ")")

func _setup_meshes() -> void:
	"""Prépare les meshes réutilisables"""
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(tile_size * 0.98, tile_height, tile_size * 0.98)
	
	plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(tile_size * 0.95, tile_size * 0.95)

func _initialize_grid() -> void:
	"""Initialise la grille vide"""
	grid.clear()
	tile_meshes.clear()
	tile_materials.clear()
	
	for y in range(grid_height):
		var row: Array[int] = []
		var mesh_row: Array = []
		var mat_row: Array = []
		
		for x in range(grid_width):
			row.append(TileType.GRASS)
			mesh_row.append(null)
			mat_row.append(null)
		
		grid.append(row)
		tile_meshes.append(mesh_row)
		tile_materials.append(mat_row)

# ============================================================================
# CHARGEMENT
# ============================================================================

func load_preset(preset_name: String) -> void:
	"""Charge un terrain prédéfini"""
	if not PRESETS.has(preset_name):
		push_error("[TerrainModule3D] Preset introuvable: ", preset_name)
		return
	
	var preset = PRESETS[preset_name]
	_generate_from_preset(preset)
	_create_visuals()
	
	generation_complete.emit()
	print("[TerrainModule3D] Preset chargé: ", preset_name)

func load_custom(terrain_data: Dictionary) -> void:
	"""Charge un terrain personnalisé"""
	if terrain_data.has("grid"):
		_load_from_grid(terrain_data.grid)
	elif terrain_data.has("base") and terrain_data.has("features"):
		_generate_from_preset(terrain_data)
	else:
		push_error("[TerrainModule3D] Format de terrain invalide")
		return
	
	_create_visuals()
	generation_complete.emit()
	print("[TerrainModule3D] Terrain personnalisé chargé")

func _generate_from_preset(preset: Dictionary) -> void:
	"""Génère le terrain depuis un preset"""
	var base_type = preset.get("base", TileType.GRASS)
	for y in range(grid_height):
		for x in range(grid_width):
			grid[y][x] = base_type
	
	for feature in preset.get("features", []):
		_add_feature(feature)

func _add_feature(feature: Dictionary) -> void:
	"""Ajoute une feature au terrain"""
	var tile_type = feature.get("type", TileType.GRASS)
	
	if feature.has("positions"):
		for pos in feature.positions:
			if _is_valid_position(pos):
				grid[pos.y][pos.x] = tile_type
		return
	
	var density = feature.get("density", 0.1)
	for y in range(grid_height):
		for x in range(grid_width):
			if randf() < density:
				grid[y][x] = tile_type

func _load_from_grid(grid_data: Array) -> void:
	"""Charge depuis une grille prédéfinie"""
	for y in range(min(grid_height, grid_data.size())):
		for x in range(min(grid_width, grid_data[y].size())):
			grid[y][x] = grid_data[y][x]

# ============================================================================
# VISUELS 3D
# ============================================================================

func _create_visuals() -> void:
	"""Crée les meshes 3D pour chaque tuile"""
	# Nettoyer les anciens meshes
	for child in get_children():
		child.queue_free()
	
	# Créer les nouveaux
	for y in range(grid_height):
		for x in range(grid_width):
			var tile_mesh = _create_tile_mesh(Vector2i(x, y))
			tile_meshes[y][x] = tile_mesh
			add_child(tile_mesh)

func _create_tile_mesh(grid_pos: Vector2i) -> MeshInstance3D:
	"""Crée le mesh 3D d'une tuile"""
	var mesh_instance = MeshInstance3D.new()
	var tile_type = grid[grid_pos.y][grid_pos.x]
	
	# Position 3D (centrer la grille)
	var world_pos = grid_to_world(grid_pos)
	var height_offset = TILE_HEIGHTS.get(tile_type, 0.0)
	mesh_instance.position = Vector3(world_pos.x, height_offset, world_pos.y)
	
	# Mesh
	mesh_instance.mesh = box_mesh
	
	# Matériau
	var material = StandardMaterial3D.new()
	material.albedo_color = TILE_COLORS.get(tile_type, Color.WHITE)
	material.metallic = 0.0
	material.roughness = 0.8
	
	# Effets spéciaux pour certains types
	if tile_type == TileType.WATER:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.7
		material.metallic = 0.3
		material.roughness = 0.2
	elif tile_type == TileType.MOUNTAIN:
		material.roughness = 1.0
	
	mesh_instance.set_surface_override_material(0, material)
	tile_materials[grid_pos.y][grid_pos.x] = material
	
	# Collision pour le raycasting
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(tile_size, tile_height, tile_size)
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	# Métadonnées pour l'identification
	mesh_instance.set_meta("grid_position", grid_pos)
	mesh_instance.set_meta("tile_type", tile_type)
	
	return mesh_instance

func update_tile_visual(grid_pos: Vector2i) -> void:
	"""Met à jour le visuel d'une tuile"""
	if not _is_valid_position(grid_pos):
		return
	
	var old_mesh = tile_meshes[grid_pos.y][grid_pos.x]
	if old_mesh:
		old_mesh.queue_free()
	
	var new_mesh = _create_tile_mesh(grid_pos)
	tile_meshes[grid_pos.y][grid_pos.x] = new_mesh
	add_child(new_mesh)

# ============================================================================
# HIGHLIGHTING (coloration des cases)
# ============================================================================

func highlight_tile(grid_pos: Vector2i, color: Color) -> void:
	"""Colore une case (pour mouvement/attaque)"""
	if not _is_valid_position(grid_pos):
		return
	
	var material = tile_materials[grid_pos.y][grid_pos.x]
	if material:
		var original_color = TILE_COLORS.get(grid[grid_pos.y][grid_pos.x], Color.WHITE)
		material.albedo_color = original_color.lerp(color, 0.5)
		material.emission_enabled = true
		material.emission = color * 0.3

func clear_highlight(grid_pos: Vector2i) -> void:
	"""Retire la coloration d'une case"""
	if not _is_valid_position(grid_pos):
		return
	
	var material = tile_materials[grid_pos.y][grid_pos.x]
	if material:
		var tile_type = grid[grid_pos.y][grid_pos.x]
		material.albedo_color = TILE_COLORS.get(tile_type, Color.WHITE)
		material.emission_enabled = false

func highlight_tiles(positions: Array[Vector2i], color: Color) -> void:
	"""Colore plusieurs cases"""
	for pos in positions:
		highlight_tile(pos, color)

func clear_all_highlights() -> void:
	"""Retire toutes les colorations"""
	for y in range(grid_height):
		for x in range(grid_width):
			clear_highlight(Vector2i(x, y))

# ============================================================================
# GETTERS (identiques à la version 2D)
# ============================================================================

func get_tile_type(grid_pos: Vector2i) -> int:
	if not _is_valid_position(grid_pos):
		return TileType.WALL
	return grid[grid_pos.y][grid_pos.x]

func get_movement_cost(grid_pos: Vector2i) -> float:
	var tile_type = get_tile_type(grid_pos)
	return MOVEMENT_COSTS.get(tile_type, 1.0)

func get_defense_bonus(grid_pos: Vector2i) -> int:
	var tile_type = get_tile_type(grid_pos)
	return DEFENSE_BONUS.get(tile_type, 0)

func is_walkable(grid_pos: Vector2i) -> bool:
	return get_movement_cost(grid_pos) < INF

func is_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and \
		   grid_pos.y >= 0 and grid_pos.y < grid_height

# ============================================================================
# CONVERSIONS 3D
# ============================================================================

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convertit une position grille en position monde 3D (X, Z)"""
	# Centrer la grille autour de l'origine
	var offset_x = (grid_width - 1) * tile_size / 2.0
	var offset_z = (grid_height - 1) * tile_size / 2.0
	
	return Vector2(
		grid_pos.x * tile_size - offset_x,
		grid_pos.y * tile_size - offset_z
	)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convertit une position monde 3D en position grille"""
	var offset_x = (grid_width - 1) * tile_size / 2.0
	var offset_z = (grid_height - 1) * tile_size / 2.0
	
	var grid_x = int((world_pos.x + offset_x) / tile_size + 0.5)
	var grid_z = int((world_pos.z + offset_z) / tile_size + 0.5)
	
	return Vector2i(grid_x, grid_z)

# ============================================================================
# PATHFINDING HELPERS (identiques à la version 2D)
# ============================================================================

func get_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	for dir in directions:
		var neighbor = grid_pos + dir
		if is_in_bounds(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

func get_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)

# ============================================================================
# SETTERS
# ============================================================================

func set_tile_type(grid_pos: Vector2i, tile_type: int) -> void:
	if not _is_valid_position(grid_pos):
		return
	
	grid[grid_pos.y][grid_pos.x] = tile_type
	update_tile_visual(grid_pos)
	tile_changed.emit(grid_pos, tile_type)

# ============================================================================
# UTILITAIRES
# ============================================================================

func _is_valid_position(grid_pos: Vector2i) -> bool:
	return is_in_bounds(grid_pos)

func get_random_walkable_position() -> Vector2i:
	for attempt in range(100):
		var pos = Vector2i(randi() % grid_width, randi() % grid_height)
		if is_walkable(pos):
			return pos
	return Vector2i(0, 0)

func clear() -> void:
	for child in get_children():
		child.queue_free()
	_initialize_grid()
	print("[TerrainModule3D] Terrain nettoyé")
