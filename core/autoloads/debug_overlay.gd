extends CanvasLayer
## DebugOverlay - Interface de debug en jeu (F3)
## Affiche les informations de debug, FPS, état du jeu
##
## Accès via : GameRoot.debug_overlay

class_name DebugOverlayClass

# ============================================================================
# CONFIGURATION
# ============================================================================

const PANEL_WIDTH: int = 450
const PANEL_MIN_HEIGHT: int = 400

# ============================================================================
# RÉFÉRENCES UI
# ============================================================================

var panel: PanelContainer = null
var info_label: RichTextLabel = null
var log_label: RichTextLabel = null

# ============================================================================
# ÉTAT
# ============================================================================

var overlay_visible: bool = false
var watched_variables: Dictionary = {}  # key -> { object: Node, property: String }
var show_logs: bool = true

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	layer = 110  # Au-dessus de tout
	name = "DebugOverlay"
	
	_create_ui()
	visible = false
	
	print("[DebugOverlay] ✅ Initialisé (F3 pour afficher)")

func _create_ui() -> void:
	"""Crée l'interface de debug"""
	
	# Panel principal
	panel = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_MIN_HEIGHT)
	
	# Style du panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	add_child(panel)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	# VBox pour organiser
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Label d'info principal
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(info_label)
	
	# Séparateur
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Label des logs récents
	var log_title = Label.new()
	log_title.text = "📜 Logs récents"
	log_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	vbox.add_child(log_title)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	log_label.scroll_active = false
	scroll.add_child(log_label)

# ============================================================================
# VISIBILITÉ
# ============================================================================

func toggle_visibility() -> void:
	"""Inverse la visibilité de l'overlay"""
	overlay_visible = not overlay_visible
	visible = overlay_visible

func show_overlay() -> void:
	"""Affiche l'overlay"""
	overlay_visible = true
	visible = true

func hide_overlay() -> void:
	"""Cache l'overlay"""
	overlay_visible = false
	visible = false

# ============================================================================
# MISE À JOUR
# ============================================================================

func _process(_delta: float) -> void:
	if not overlay_visible:
		return
	
	_update_display()

func _update_display() -> void:
	"""Met à jour l'affichage"""
	
	var text = "[b][color=cyan]═══ DEBUG OVERLAY ═══[/color][/b]\n\n"
	
	# Performance
	text += "[b][color=yellow]Performance[/color][/b]\n"
	text += "  FPS: [color=lime]%d[/color]\n" % Engine.get_frames_per_second()
	
	var mem_static = OS.get_static_memory_usage() / 1024.0 / 1024.0
	text += "  Mémoire: [color=lime]%.2f MB[/color]\n\n" % mem_static
	
	# GameRoot Status (via autoload)
	if GameRoot:
		text += "[b][color=yellow]GameRoot[/color][/b]\n"
		text += "  EventBus: %s\n" % _status_icon(GameRoot.event_bus != null)
		text += "  SceneLoader: %s\n" % _status_icon(GameRoot.scene_loader != null)
		text += "  GameManager: %s\n" % _status_icon(GameRoot.game_manager != null)
		text += "  UIManager: %s\n" % _status_icon(GameRoot.ui_manager != null)
		text += "  GlobalLogger: %s\n\n" % _status_icon(GameRoot.global_logger != null)
		
		# Scène actuelle
		if GameRoot.scene_loader:
			var scene_name = GameRoot.scene_loader.get_current_scene_name()
			var is_loading = GameRoot.scene_loader.is_loading
			text += "[b][color=yellow]Scène[/color][/b]\n"
			text += "  Actuelle: [color=white]%s[/color]\n" % scene_name
			text += "  Loading: %s\n\n" % _status_icon(is_loading, "🔄", "✅")
		
		# État du jeu
		if GameRoot.game_manager:
			text += "[b][color=yellow]État[/color][/b]\n"
			text += "  Pause: %s\n\n" % _status_icon(GameRoot.game_manager.is_paused, "⏸️", "▶️")
	
	# Variables surveillées
	if not watched_variables.is_empty():
		text += "[b][color=yellow]Variables[/color][/b]\n"
		
		for key in watched_variables:
			var entry = watched_variables[key]
			var obj = entry.object
			var prop = entry.property
			
			if is_instance_valid(obj):
				var value = obj.get(prop)
				if value != null:
					text += "  [color=cyan]%s:[/color] %s\n" % [key, _format_value(value)]
		
		text += "\n"
	
	info_label.text = text
	
	# Logs récents
	if show_logs and GameRoot and GameRoot.global_logger:
		var log_text = ""
		var recent_logs = GameRoot.global_logger.get_recent_logs(10)
		
		for entry in recent_logs:
			var color = "white"
			match entry.level:
				GlobalLoggerClass.LogLevel.DEBUG:
					color = "gray"
				GlobalLoggerClass.LogLevel.WARNING:
					color = "yellow"
				GlobalLoggerClass.LogLevel.ERROR:
					color = "red"
			
			log_text += "[color=%s][%s] %s[/color]\n" % [color, entry.category, entry.message]
		
		log_label.text = log_text

func _status_icon(condition: bool, true_icon: String = "✅", false_icon: String = "❌") -> String:
	return true_icon if condition else false_icon

func _format_value(value: Variant) -> String:
	"""Formate une valeur pour l'affichage"""
	
	if value is Array:
		return "Array[%d]" % value.size()
	elif value is Dictionary:
		return "Dict[%d]" % value.size()
	elif value is Vector2 or value is Vector2i:
		return "(%s, %s)" % [value.x, value.y]
	elif value is Vector3:
		return "(%.1f, %.1f, %.1f)" % [value.x, value.y, value.z]
	else:
		return str(value)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func watch_variable(key: String, object: Node, property: String) -> void:
	"""Surveille une variable pour l'afficher dans l'overlay"""
	watched_variables[key] = {"object": object, "property": property}

func unwatch_variable(key: String) -> void:
	"""Arrête de surveiller une variable"""
	watched_variables.erase(key)

func clear_watched() -> void:
	"""Supprime toutes les variables surveillées"""
	watched_variables.clear()

func set_show_logs(show: bool) -> void:
	"""Active/désactive l'affichage des logs"""
	show_logs = show

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Le toggle est géré par GameRoot
	pass
