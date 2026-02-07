extends Button
class_name ThemedButton
## Bouton avec style uniforme appliqué automatiquement

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var button_text: String = "Button"
@export var icon_path: String = ""
@export var min_width: int = 150
@export var min_height: int = 40

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	text = button_text
	custom_minimum_size = Vector2(min_width, min_height)
	
	_apply_theme()
	_load_icon()

func _apply_theme() -> void:
	"""Applique le thème standardisé"""
	UITheme.apply_theme_to_control(self, "button")

func _load_icon() -> void:
	"""Charge l'icône si spécifiée"""
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon = load(icon_path)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func set_button_text(new_text: String) -> void:
	"""Change le texte du bouton"""
	button_text = new_text
	text = new_text

func set_icon_path(path: String) -> void:
	"""Change l'icône du bouton depuis un chemin de fichier"""
	icon_path = path
	_load_icon()

func set_icon_texture(texture: Texture2D) -> void:
	"""Change l'icône du bouton avec une texture"""
	icon = texture
