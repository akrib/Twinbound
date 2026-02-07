extends PanelContainer
class_name ThemedPanel
## Panel avec style uniforme appliqué automatiquement
## Utilisé comme base pour tous les panels du jeu

# ============================================================================
# CONFIGURATION
# ============================================================================

enum PanelStyle {
	DEFAULT,
	LIGHT,
	DARK,
	DIALOGUE,
	NOTIFICATION,
}

@export var panel_style: PanelStyle = PanelStyle.DEFAULT
@export var auto_margin: bool = true
@export var margin_size: int = 20

# ============================================================================
# CONTENEUR
# ============================================================================

var content_container: MarginContainer = null

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_apply_style()
	
	# Créer le margin container si nécessaire et pas déjà fait
	if auto_margin and not content_container:
		_create_margin_container()

func _apply_style() -> void:
	"""Applique le style selon le type de panel"""
	
	var bg_color: Color
	var border_color: Color
	
	match panel_style:
		PanelStyle.DEFAULT:
			bg_color = UITheme.COLORS.panel_bg
			border_color = UITheme.COLORS.border_default
		
		PanelStyle.LIGHT:
			bg_color = UITheme.COLORS.panel_bg_light
			border_color = UITheme.COLORS.border_light
		
		PanelStyle.DARK:
			bg_color = UITheme.COLORS.panel_bg_dark
			border_color = UITheme.COLORS.border_dark
		
		PanelStyle.DIALOGUE:
			bg_color = UITheme.COLORS.dialogue_bg
			border_color = UITheme.COLORS.dialogue_border
		
		PanelStyle.NOTIFICATION:
			bg_color = UITheme.COLORS.panel_bg
			border_color = UITheme.COLORS.notif_info
	
	var style = UITheme.create_panel_style(bg_color, border_color)
	add_theme_stylebox_override("panel", style)

func _create_margin_container() -> void:
	"""Crée un MarginContainer automatique"""
	
	# Si déjà des enfants, ne rien faire
	if get_child_count() > 0:
		return
	
	content_container = MarginContainer.new()
	content_container.name = "MarginContainer"  # ← Nom explicite pour l'accès
	content_container.add_theme_constant_override("margin_left", margin_size)
	content_container.add_theme_constant_override("margin_top", margin_size)
	content_container.add_theme_constant_override("margin_right", margin_size)
	content_container.add_theme_constant_override("margin_bottom", margin_size)
	add_child(content_container)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func set_panel_style(style: PanelStyle) -> void:
	"""Change le style du panel"""
	panel_style = style
	_apply_style()

func get_content_container() -> MarginContainer:
	"""Retourne le conteneur de contenu (avec marges)"""
	return content_container

func get_first_content_child() -> Node:
	"""Retourne le premier enfant du content_container (utile pour accéder au HBoxContainer, etc.)"""
	if content_container and content_container.get_child_count() > 0:
		return content_container.get_child(0)
	elif get_child_count() > 0:
		return get_child(0)
	return null

func add_content(node: Node) -> void:
	"""Ajoute du contenu au panel (dans le MarginContainer)"""
	
	# Si auto_margin est activé mais que le container n'existe pas encore,
	# le créer maintenant (avant que _ready() soit appelé)
	if auto_margin and not content_container:
		_create_margin_container()
	
	# Ajouter le nœud
	if content_container:
		content_container.add_child(node)
	else:
		add_child(node)
