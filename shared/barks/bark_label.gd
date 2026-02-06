extends Control
## BarkLabel - Label individuel pour un message bark
## Affiche un message court au-dessus d'un personnage

class_name BarkLabel

# ============================================================================
# PROPRIÉTÉS
# ============================================================================

var speaker: String = ""
var text: String = ""
var duration: float = 2.0

# ============================================================================
# UI
# ============================================================================

var panel: PanelContainer = null
var label: RichTextLabel = null

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_create_ui()

func _create_ui() -> void:
	"""Crée l'interface du bark"""
	
	# Panel container
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(panel)
	
	# Background style
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.9, 0.9, 0.9, 0.6)
	
	panel.add_theme_stylebox_override("panel", stylebox)
	
	# Label
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_color_override("default_color", Color.WHITE)
	
	panel.add_child(label)
	
	# Définir le texte
	_update_text()

func _update_text() -> void:
	"""Met à jour le texte affiché"""
	
	if not label:
		return
	
	var display_text = text
	
	# Ajouter le nom du speaker si présent
	if speaker != "":
		display_text = "[b][color=#FFD700]" + speaker + ":[/color][/b] " + text
	
	label.text = display_text

# ============================================================================
# POSITIONNEMENT
# ============================================================================

func _process(_delta: float) -> void:
	# Centrer le panel
	if panel:
		panel.position = -panel.size / 2
