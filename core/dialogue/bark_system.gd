extends Node
class_name BarkSystem
## Système de "barks" - messages courts au-dessus des personnages

signal bark_shown(speaker: String, text: String)
signal bark_hidden(speaker: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var default_duration: float = 2.0
@export var fade_duration: float = 0.3
@export var max_barks: int = 5
@export var bark_offset: Vector2 = Vector2(0, -50)

# ============================================================================
# ÉTAT
# ============================================================================

var active_barks: Dictionary = {}  # speaker -> BarkLabel
var bark_container: CanvasLayer = null

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_create_bark_container()
	print("[BarkSystem] ✅ Initialisé")

func _create_bark_container() -> void:
	"""Crée le conteneur pour les barks"""
	bark_container = CanvasLayer.new()
	bark_container.layer = 50
	bark_container.name = "BarkContainer"
	add_child(bark_container)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func show_bark(speaker: String, text: String, world_position: Vector2, duration: float = -1.0) -> void:
	"""Affiche un bark au-dessus d'une position"""
	
	if duration < 0:
		duration = default_duration
	
	# Supprimer le bark existant pour ce speaker
	if active_barks.has(speaker):
		_remove_bark(speaker)
	
	# Limiter le nombre de barks
	while active_barks.size() >= max_barks:
		var oldest = active_barks.keys()[0]
		_remove_bark(oldest)
	
	# Créer le nouveau bark
	var bark_label = _create_bark_label(text, world_position)
	active_barks[speaker] = bark_label
	bark_container.add_child(bark_label)
	
	# Animation d'apparition
	bark_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(bark_label, "modulate:a", 1.0, fade_duration)
	
	bark_shown.emit(speaker, text)
	
	# Timer de disparition
	await get_tree().create_timer(duration).timeout
	
	if active_barks.has(speaker) and is_instance_valid(active_barks[speaker]):
		_fade_out_bark(speaker)

func hide_bark(speaker: String) -> void:
	"""Cache immédiatement un bark"""
	_remove_bark(speaker)

func hide_all_barks() -> void:
	"""Cache tous les barks"""
	for speaker in active_barks.keys():
		_remove_bark(speaker)

# ============================================================================
# CRÉATION UI
# ============================================================================

func _create_bark_label(text: String, world_position: Vector2) -> PanelContainer:
	"""Crée un label de bark stylisé"""
	
	var panel = PanelContainer.new()
	
	# Style du panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_top = 5
	style.content_margin_right = 10
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Label
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(50, 0)
	panel.add_child(label)
	
	# Position (convertir world à screen si nécessaire)
	panel.position = world_position + bark_offset
	
	return panel

func _fade_out_bark(speaker: String) -> void:
	"""Fait disparaître un bark avec animation"""
	
	if not active_barks.has(speaker):
		return
	
	var bark = active_barks[speaker]
	if not is_instance_valid(bark):
		active_barks.erase(speaker)
		return
	
	var tween = create_tween()
	tween.tween_property(bark, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func(): _remove_bark(speaker))

func _remove_bark(speaker: String) -> void:
	"""Supprime un bark"""
	
	if not active_barks.has(speaker):
		return
	
	var bark = active_barks[speaker]
	active_barks.erase(speaker)
	
	if is_instance_valid(bark):
		bark.queue_free()
	
	bark_hidden.emit(speaker)

# ============================================================================
# MISE À JOUR POSITION
# ============================================================================

func update_bark_position(speaker: String, world_position: Vector2) -> void:
	"""Met à jour la position d'un bark (pour suivre un personnage)"""
	
	if not active_barks.has(speaker):
		return
	
	var bark = active_barks[speaker]
	if is_instance_valid(bark):
		bark.position = world_position + bark_offset
