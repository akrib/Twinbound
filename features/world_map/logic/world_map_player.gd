# scenes/world/world_map_player.gd
extends Node2D
## WorldMapPlayer - Sprite du joueur sur la world map avec animation bounce

class_name WorldMapPlayer

signal movement_started()
signal movement_completed()

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var bounce_speed: float = 1.5
@export var bounce_amount: float = 10.0
@export var bounce_offset: float = 75.0 
@export var scale_variation: float = 0.1  # Variation de scale pour l'effet respiration
@export var move_speed: float = 300.0

# ============================================================================
# ÉTAT
# ============================================================================

var sprite: Sprite2D
var is_moving: bool = false
var current_location_id: String = ""

var bounce_tween: Tween = null
var move_tween: Tween = null

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_create_sprite()
	_start_bounce_animation()

func _create_sprite() -> void:
	"""Crée le sprite du joueur"""
	
	sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	sprite.centered = true
	add_child(sprite)

func setup(player_config: Dictionary) -> void:
	"""Configure le joueur avec les données Lua"""
	
	if player_config.has("icon"):
		var icon_path = player_config.icon
		if ResourceLoader.exists(icon_path):
			sprite.texture = load(icon_path)
	
	if player_config.has("scale"):
		sprite.scale = Vector2.ONE * player_config.scale
	
	bounce_speed = player_config.get("bounce_speed", 1.5)
	bounce_amount = player_config.get("bounce_amount", 10.0)
	move_speed = player_config.get("move_speed", 300.0)

# ============================================================================
# ANIMATION BOUNCE
# ============================================================================

func _start_bounce_animation() -> void:
	"""Démarre l'animation de bounce continue"""
	
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	
	bounce_tween = create_tween()
	bounce_tween.set_loops()
	bounce_tween.set_parallel(true)
	
	# ✅ CHANGEMENT : Bounce entre -bounce_amount-bounce_offset et -bounce_offset
	# (au lieu de -bounce_amount à 0)
	# Cela place le sprite plus haut de façon permanente
	
	var min_y = -bounce_offset  # Position basse du bounce
	var max_y = -bounce_offset - bounce_amount  # Position haute du bounce
	
	# Variation de position Y (bounce)
	bounce_tween.tween_property(
		sprite,
		"position:y",
		max_y,
		bounce_speed / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	bounce_tween.tween_property(
		sprite,
		"position:y",
		min_y,
		bounce_speed / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(bounce_speed / 2.0)
	
	# Variation de scale (respiration) - inchangé
	var base_scale = sprite.scale
	var scale_min = base_scale * (1.0 - scale_variation)
	var scale_max = base_scale * (1.0 + scale_variation)
	
	bounce_tween.tween_property(
		sprite,
		"scale",
		scale_max,
		bounce_speed / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	bounce_tween.tween_property(
		sprite,
		"scale",
		scale_min,
		bounce_speed / 2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_delay(bounce_speed / 2.0)

# ============================================================================
# MOUVEMENT
# ============================================================================

func move_to_location(target_location: WorldMapLocation) -> void:
	"""Déplace le joueur vers une location"""
	
	if is_moving:
		return
	
	is_moving = true
	movement_started.emit()
	
	var target_pos = target_location.position
	var distance = position.distance_to(target_pos)
	var duration = distance / move_speed
	
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_IN_OUT)
	await move_tween.finished
	
	current_location_id = target_location.location_id
	is_moving = false
	movement_completed.emit()

func set_location(location: WorldMapLocation) -> void:
	"""Place directement le joueur à une location (sans animation)"""
	
	position = location.position
	current_location_id = location.location_id
