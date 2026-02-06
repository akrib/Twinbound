# scenes/world/world_map_connection.gd
extends Node2D
class_name WorldMapConnection

## Représente une connexion entre deux locations avec état (unlocked/locked/hidden)

signal state_changed(new_state: ConnectionState)

enum ConnectionState {
	UNLOCKED,   # Accessible, pointillés normaux
	LOCKED,     # Visible mais bloqué, pointillés ternes + croix rouge
	HIDDEN      # Invisible, ne s'affiche pas
}

# ============================================================================
# CONFIGURATION GLOBALE (VARIABLES DE CLASSE)
# ============================================================================

# ✅ AJOUT : Variables de classe statiques pour configuration globale
static var default_line_width: float = 4.0
static var default_dash_length: float = 15.0
static var default_gap_length: float = 10.0
static var default_cross_size: float = 20.0
static var default_color_unlocked: Color = Color(0.7, 0.7, 0.7, 0.8)
static var default_color_locked: Color = Color(0.3, 0.3, 0.3, 0.4)

# ============================================================================
# CONFIGURATION D'INSTANCE
# ============================================================================

@export var line_width: float = 4.0
@export var dash_length: float = 15.0
@export var gap_length: float = 10.0
@export var cross_size: float = 20.0

# Couleurs
var color_unlocked: Color = Color(0.7, 0.7, 0.7, 0.8)
var color_locked: Color = Color(0.3, 0.3, 0.3, 0.4)

# ============================================================================
# ÉTAT
# ============================================================================

var connection_id: String = ""
var from_location: WorldMapLocation = null
var to_location: WorldMapLocation = null
var current_state: ConnectionState = ConnectionState.HIDDEN

# Visuels
var line_segments: Array[Line2D] = []
var cross_sprite: Polygon2D = null

# ============================================================================
# INITIALISATION
# ============================================================================

func setup(from: WorldMapLocation, to: WorldMapLocation, state: ConnectionState = ConnectionState.UNLOCKED) -> void:
	from_location = from
	to_location = to
	current_state = state
	
	connection_id = from.location_id + "_to_" + to.location_id
	
	# ✅ AJOUT : Appliquer les valeurs par défaut globales
	line_width = default_line_width
	dash_length = default_dash_length
	gap_length = default_gap_length
	cross_size = default_cross_size
	color_unlocked = default_color_unlocked
	color_locked = default_color_locked
	
	_create_visuals()

func _create_visuals() -> void:
	_clear_visuals()
	
	if current_state == ConnectionState.HIDDEN:
		visible = false
		return
	
	visible = true
	
	# Créer les segments de ligne pointillée
	_create_dashed_line()
	
	# Ajouter la croix si bloqué
	if current_state == ConnectionState.LOCKED:
		_create_cross()

# ============================================================================
# LIGNE POINTILLÉE
# ============================================================================

func _create_dashed_line() -> void:
	if not from_location or not to_location:
		return
	
	var start_pos = from_location.position
	var end_pos = to_location.position
	var direction = (end_pos - start_pos).normalized()
	var total_distance = start_pos.distance_to(end_pos)
	
	# Couleur selon l'état
	var line_color = color_unlocked if current_state == ConnectionState.UNLOCKED else color_locked
	
	# Calculer le nombre de segments
	var segment_length = dash_length + gap_length
	var num_segments = int(total_distance / segment_length) + 1
	
	var current_distance = 0.0
	
	for i in range(num_segments):
		# Position de début du segment
		var segment_start = start_pos + direction * current_distance
		
		# Position de fin du segment (sans dépasser l'arrivée)
		var dash_end_distance = min(current_distance + dash_length, total_distance)
		var segment_end = start_pos + direction * dash_end_distance
		
		# Créer le segment Line2D
		var line = Line2D.new()
		line.add_point(segment_start)
		line.add_point(segment_end)
		line.width = line_width
		line.default_color = line_color
		line.antialiased = true
		
		# Style arrondi pour les extrémités
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		add_child(line)
		line_segments.append(line)
		
		# Avancer pour le prochain segment
		current_distance += segment_length
		
		# Arrêter si on a atteint la fin
		if current_distance >= total_distance:
			break

# ============================================================================
# CROIX ROUGE (pour chemins bloqués)
# ============================================================================

func _create_cross() -> void:
	if not from_location or not to_location:
		return
	
	# Position au centre de la ligne
	var center = (from_location.position + to_location.position) / 2.0
	
	# Créer un Polygon2D en forme de croix
	cross_sprite = Polygon2D.new()
	cross_sprite.color = Color(0.9, 0.2, 0.2, 0.9)
	
	# Définir les points de la croix (forme de "+")
	var half_size = cross_size / 2.0
	var thickness = cross_size / 5.0
	
	var points = PackedVector2Array([
		# Barre verticale
		Vector2(-thickness, -half_size),
		Vector2(thickness, -half_size),
		Vector2(thickness, -thickness),
		Vector2(half_size, -thickness),
		# Barre horizontale droite
		Vector2(half_size, thickness),
		Vector2(thickness, thickness),
		Vector2(thickness, half_size),
		Vector2(-thickness, half_size),
		# Barre horizontale gauche
		Vector2(-thickness, thickness),
		Vector2(-half_size, thickness),
		Vector2(-half_size, -thickness),
		Vector2(-thickness, -thickness),
	])
	
	cross_sprite.polygon = points
	cross_sprite.position = center
	
	# Contour noir pour meilleure visibilité
	var outline = Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color.BLACK
	cross_sprite.add_child(outline)
	
	add_child(cross_sprite)

# ============================================================================
# GESTION D'ÉTAT
# ============================================================================

func set_state(new_state: ConnectionState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	_create_visuals()
	state_changed.emit(new_state)

func is_accessible() -> bool:
	return current_state == ConnectionState.UNLOCKED

func unlock() -> void:
	set_state(ConnectionState.UNLOCKED)

func lock() -> void:
	set_state(ConnectionState.LOCKED)

func hide_connection() -> void:
	set_state(ConnectionState.HIDDEN)

func reveal() -> void:
	if current_state == ConnectionState.HIDDEN:
		set_state(ConnectionState.LOCKED)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _clear_visuals() -> void:
	# Supprimer les segments de ligne
	for segment in line_segments:
		segment.queue_free()
	line_segments.clear()
	
	# Supprimer la croix
	if cross_sprite:
		cross_sprite.queue_free()
		cross_sprite = null
