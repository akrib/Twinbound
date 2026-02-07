extends RefCounted
class_name UITheme
## Thème centralisé pour toutes les UI du jeu
## Permet de modifier l'apparence globale en un seul endroit

# ============================================================================
# COULEURS
# ============================================================================

const COLORS = {
	# Backgrounds
	"panel_bg": Color(0.1, 0.1, 0.12, 0.95),
	"panel_bg_light": Color(0.15, 0.15, 0.2, 0.95),
	"panel_bg_dark": Color(0.05, 0.05, 0.08, 0.95),
	
	# Borders
	"border_default": Color(0.4, 0.6, 0.9),
	"border_light": Color(0.7, 0.7, 0.8),
	"border_dark": Color(0.3, 0.3, 0.4),
	
	# Buttons
	"button_normal": Color(0.2, 0.25, 0.35),
	"button_hover": Color(0.3, 0.35, 0.45),
	"button_pressed": Color(0.15, 0.2, 0.3),
	"button_disabled": Color(0.15, 0.15, 0.2),
	
	# Text
	"text_normal": Color(0.9, 0.9, 0.9),
	"text_title": Color(0.9, 0.85, 0.7),
	"text_disabled": Color(0.5, 0.5, 0.5),
	"text_highlight": Color(1.0, 1.0, 0.5),
	
	# Notifications
	"notif_info": Color(0.4, 0.6, 0.9),
	"notif_success": Color(0.3, 0.8, 0.3),
	"notif_warning": Color(0.9, 0.7, 0.2),
	"notif_error": Color(0.9, 0.3, 0.3),
	
	# Dialogue
	"dialogue_bg": Color(0.08, 0.08, 0.12, 0.95),
	"dialogue_border": Color(0.4, 0.4, 0.6),
	"dialogue_speaker": Color(1.0, 0.85, 0.5),
}

# ============================================================================
# TAILLES DE POLICE
# ============================================================================

const FONT_SIZES = {
	"title": 32,
	"subtitle": 24,
	"normal": 20,
	"small": 16,
	"tiny": 14,
}

# ============================================================================
# DIMENSIONS
# ============================================================================

const SIZES = {
	"border_width": 3,
	"corner_radius": 8,
	"margin": 20,
	"margin_small": 10,
	"margin_large": 30,
	"button_min_height": 40,
	"button_min_width": 150,
}

# ============================================================================
# CRÉATION DE STYLES
# ============================================================================

static func create_panel_style(
	bg_color: Color = COLORS.panel_bg,
	border_color: Color = COLORS.border_default,
	border_width: int = SIZES.border_width,
	corner_radius: int = SIZES.corner_radius
) -> StyleBoxFlat:
	"""Crée un style de panel standardisé"""
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	
	return style

static func create_button_style(state: String = "normal") -> StyleBoxFlat:
	"""Crée un style de bouton selon son état"""
	
	var colors_map = {
		"normal": COLORS.button_normal,
		"hover": COLORS.button_hover,
		"pressed": COLORS.button_pressed,
		"disabled": COLORS.button_disabled,
	}
	
	var bg_color = colors_map.get(state, COLORS.button_normal)
	return create_panel_style(bg_color, COLORS.border_light, 2, SIZES.corner_radius)

static func apply_theme_to_control(control: Control, theme_type: String = "panel") -> void:
	"""Applique le thème à un Control"""
	
	match theme_type:
		"panel":
			if control is PanelContainer:
				control.add_theme_stylebox_override("panel", create_panel_style())
		
		"button":
			if control is Button:
				control.add_theme_stylebox_override("normal", create_button_style("normal"))
				control.add_theme_stylebox_override("hover", create_button_style("hover"))
				control.add_theme_stylebox_override("pressed", create_button_style("pressed"))
				control.add_theme_stylebox_override("disabled", create_button_style("disabled"))
				control.add_theme_color_override("font_color", COLORS.text_normal)
				control.add_theme_font_size_override("font_size", FONT_SIZES.normal)
