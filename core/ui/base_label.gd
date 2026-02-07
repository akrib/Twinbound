extends Label
class_name ThemedLabel
## Label avec style uniforme appliqué automatiquement

# ============================================================================
# CONFIGURATION
# ============================================================================

enum LabelStyle {
	NORMAL,
	TITLE,
	SUBTITLE,
	SMALL,
	HIGHLIGHT,
}

@export var label_style: LabelStyle = LabelStyle.NORMAL
@export var label_text: String = ""

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	text = label_text
	_apply_style()

func _apply_style() -> void:
	"""Applique le style selon le type"""
	
	var font_size: int
	var font_color: Color
	
	match label_style:
		LabelStyle.NORMAL:
			font_size = UITheme.FONT_SIZES.normal
			font_color = UITheme.COLORS.text_normal
		
		LabelStyle.TITLE:
			font_size = UITheme.FONT_SIZES.title
			font_color = UITheme.COLORS.text_title
		
		LabelStyle.SUBTITLE:
			font_size = UITheme.FONT_SIZES.subtitle
			font_color = UITheme.COLORS.text_title
		
		LabelStyle.SMALL:
			font_size = UITheme.FONT_SIZES.small
			font_color = UITheme.COLORS.text_normal
		
		LabelStyle.HIGHLIGHT:
			font_size = UITheme.FONT_SIZES.normal
			font_color = UITheme.COLORS.text_highlight
	
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", font_color)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func set_label_style(style: LabelStyle) -> void:
	"""Change le style du label"""
	label_style = style
	_apply_style()

func set_label_text(new_text: String) -> void:
	"""Change le texte du label"""
	label_text = new_text
	text = new_text
