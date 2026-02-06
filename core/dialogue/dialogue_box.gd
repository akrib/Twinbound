extends Control
class_name DialogueBoxClass
## Boîte de dialogue UI - à étendre ou utiliser directement

# ============================================================================
# SIGNAUX
# ============================================================================

signal text_reveal_completed()
signal choice_selected(index: int)
signal dialogue_box_shown()
signal dialogue_box_hidden()

# ============================================================================
# RÉFÉRENCES (à connecter dans l'inspecteur ou via code)
# ============================================================================

@export var speaker_label: Label
@export var text_label: RichTextLabel
@export var portrait_texture: TextureRect
@export var choices_container: VBoxContainer
@export var continue_indicator: Control

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var typewriter_speed: float = 50.0  # Caractères par seconde
@export var show_continue_indicator: bool = true
@export var auto_size: bool = true

# ============================================================================
# ÉTAT
# ============================================================================

var dialogue_manager = null  # Référence au DialogueManager
var is_text_revealing: bool = false
var current_text: String = ""
var revealed_characters: int = 0
var _typewriter_timer: float = 0.0

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	# Créer l'UI si pas de références
	if not speaker_label or not text_label:
		_create_default_ui()
	
	# Cacher par défaut
	visible = false
	
	if continue_indicator:
		continue_indicator.visible = false

func _create_default_ui() -> void:
	"""Crée une UI de dialogue par défaut"""
	
	# Panel principal
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.7
	panel.offset_top = 0
	panel.offset_bottom = -20
	panel.offset_left = 20
	panel.offset_right = -20
	add_child(panel)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.4, 0.6)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	# VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Speaker
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 24)
	speaker_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	vbox.add_child(speaker_label)
	
	# Text
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("normal_font_size", 20)
	vbox.add_child(text_label)
	
	# Choices container
	choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 8)
	choices_container.visible = false
	vbox.add_child(choices_container)
	
	# Continue indicator
	continue_indicator = Label.new()
	continue_indicator.text = "▼"
	continue_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_indicator.visible = false
	vbox.add_child(continue_indicator)

# ============================================================================
# AFFICHAGE
# ============================================================================

func show_dialogue_box() -> void:
	"""Affiche la boîte de dialogue"""
	visible = true
	dialogue_box_shown.emit()

func hide_dialogue_box() -> void:
	"""Cache la boîte de dialogue"""
	visible = false
	is_text_revealing = false
	dialogue_box_hidden.emit()

func display_line(line: Dictionary) -> void:
	"""Affiche une ligne de dialogue"""
	
	# Speaker
	var speaker = line.get("speaker", "")
	if speaker_label:
		speaker_label.text = speaker
		speaker_label.visible = speaker != ""
	
	# Portrait
	if portrait_texture and line.has("portrait"):
		var portrait_path = line.get("portrait", "")
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			portrait_texture.texture = load(portrait_path)
			portrait_texture.visible = true
		else:
			portrait_texture.visible = false
	
	# Texte
	var text = line.get("text", "")
	var text_key = line.get("text_key", "")
	
	if text_key != "":
		text = tr(text_key)
	
	current_text = text
	
	# Cacher les choix
	if choices_container:
		choices_container.visible = false
		_clear_choices()
	
	# Cacher l'indicateur de continuation
	if continue_indicator:
		continue_indicator.visible = false
	
	# Démarrer le typewriter
	var speed = line.get("speed", typewriter_speed)
	_start_typewriter(text, speed)

func display_choices(choices: Array) -> void:
	"""Affiche les choix"""
	
	if not choices_container:
		return
	
	_clear_choices()
	
	for i in range(choices.size()):
		var choice = choices[i]
		var button = Button.new()
		
		var choice_text = choice.get("text", "")
		var choice_key = choice.get("text_key", "")
		
		if choice_key != "":
			choice_text = tr(choice_key)
		
		button.text = choice_text
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(func(): _on_choice_pressed(i))
		
		choices_container.add_child(button)
	
	choices_container.visible = true

func _clear_choices() -> void:
	"""Supprime tous les boutons de choix"""
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()

func _on_choice_pressed(index: int) -> void:
	"""Callback quand un choix est sélectionné"""
	choice_selected.emit(index)
	
	if dialogue_manager:
		dialogue_manager.select_choice(index)

# ============================================================================
# TYPEWRITER
# ============================================================================

func _start_typewriter(text: String, speed: float) -> void:
	"""Démarre l'effet typewriter"""
	
	current_text = text
	revealed_characters = 0
	is_text_revealing = true
	typewriter_speed = speed
	_typewriter_timer = 0.0
	
	if text_label:
		text_label.text = ""

func _process(delta: float) -> void:
	if not is_text_revealing:
		return
	
	_typewriter_timer += delta * typewriter_speed
	
	var chars_to_show = int(_typewriter_timer)
	
	if chars_to_show > revealed_characters:
		revealed_characters = chars_to_show
		
		if text_label:
			if revealed_characters >= current_text.length():
				text_label.text = current_text
				complete_text()
			else:
				text_label.text = current_text.substr(0, revealed_characters)

func complete_text() -> void:
	"""Complète immédiatement le texte"""
	
	if text_label:
		text_label.text = current_text
	
	revealed_characters = current_text.length()
	is_text_revealing = false
	
	# Afficher l'indicateur de continuation
	if continue_indicator and show_continue_indicator:
		continue_indicator.visible = true
	
	text_reveal_completed.emit()

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Avancer le dialogue
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if dialogue_manager:
			dialogue_manager.advance_dialogue()
		get_viewport().set_input_as_handled()
