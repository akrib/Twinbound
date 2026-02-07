extends CanvasLayer
## UIManager - Gestion de l'interface utilisateur globale
## Gère les notifications, l'écran de chargement, les menus globaux
## et la DialogueBox persistante (toujours en mémoire)
##
## Fournit des méthodes pour créer des UI standardisées
##
## Accès via : GameRoot.ui_manager

class_name UIManagerClass

# ============================================================================
# DÉPENDANCES
# ============================================================================

const UITheme = preload("res://core/ui/ui_theme.gd")
const ThemedPanel = preload("res://core/ui/base_panel.gd")
const ThemedButton = preload("res://core/ui/base_button.gd")
const ThemedLabel = preload("res://core/ui/base_label.gd")

# ============================================================================
# CONFIGURATION
# ============================================================================

const NOTIFICATION_DURATION: float = 3.0
const NOTIFICATION_FADE: float = 0.3
const MAX_NOTIFICATIONS: int = 5

# ============================================================================
# RÉFÉRENCES UI GLOBALES
# ============================================================================

var notification_container: VBoxContainer = null
var loading_screen: Control = null
var loading_progress_bar: ProgressBar = null
var loading_label: Label = null
var pause_menu: Control = null
var transition_overlay: ColorRect = null
var dialogue_box: DialogueBoxClass = null

# ============================================================================
# CONTENEURS POUR UI DE SCÈNE
# ============================================================================

var scene_ui_container: Control = null  # Conteneur pour les UI spécifiques aux scènes
var scene_ui_cache: Dictionary = {}  # Cache des UI de scène

# ============================================================================
# ÉTAT
# ============================================================================

var active_notifications: Array[Control] = []
var is_loading_visible: bool = false

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	layer = 90
	name = "UIManager"
	
	_create_scene_ui_container()
	_create_transition_layer()
	_create_notification_system()
	_create_loading_screen()
	_create_pause_menu()
	_create_dialogue_box()
	
	print("[UIManager] ✅ Initialisé (avec DialogueBox persistante et UI factory)")

func _create_scene_ui_container() -> void:
	"""Crée le conteneur pour les UI spécifiques aux scènes"""
	scene_ui_container = Control.new()
	scene_ui_container.name = "SceneUIContainer"
	scene_ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_ui_container.z_index = 50  # Entre les scènes et les menus globaux
	add_child(scene_ui_container)

# ============================================================================
# DIALOGUE BOX PERSISTANTE (identique à l'original)
# ============================================================================

func _create_dialogue_box() -> void:
	"""Crée la DialogueBox persistante accessible par DialogueManager"""
	
	var dialogue_box_scene_path = "res://core/dialogue/dialogue_box.tscn"
	
	if ResourceLoader.exists(dialogue_box_scene_path):
		var packed = load(dialogue_box_scene_path)
		dialogue_box = packed.instantiate() as DialogueBoxClass
		print("[UIManager]   → DialogueBox chargée depuis .tscn")
	else:
		dialogue_box = DialogueBoxClass.new()
		dialogue_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("[UIManager]   → DialogueBox créée dynamiquement")
	
	dialogue_box.name = "PersistentDialogueBox"
	dialogue_box.visible = false
	dialogue_box.z_index = 60
	add_child(dialogue_box)

func get_dialogue_box() -> DialogueBoxClass:
	return dialogue_box

func show_dialogue_box() -> void:
	if dialogue_box:
		dialogue_box.show_dialogue_box()

func hide_dialogue_box() -> void:
	if dialogue_box:
		dialogue_box.hide_dialogue_box()

# ============================================================================
# SYSTÈMES GLOBAUX (identiques à l'original)
# ============================================================================

func _create_transition_layer() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = Color.BLACK
	transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.modulate.a = 0.0
	transition_overlay.z_index = 100
	add_child(transition_overlay)

func _create_notification_system() -> void:
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notification_container.anchor_left = 1.0
	notification_container.anchor_right = 1.0
	notification_container.offset_left = -320
	notification_container.offset_top = 20
	notification_container.offset_right = -20
	notification_container.add_theme_constant_override("separation", 10)
	add_child(notification_container)

func _create_loading_screen() -> void:
	loading_screen = Control.new()
	loading_screen.name = "LoadingScreen"
	loading_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_screen.visible = false
	loading_screen.z_index = 50
	add_child(loading_screen)
	
	var bg = ColorRect.new()
	bg.color = UITheme.COLORS.panel_bg_dark
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_screen.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_screen.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	loading_label = Label.new()
	loading_label.text = "Chargement..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", UITheme.FONT_SIZES.title)
	vbox.add_child(loading_label)
	
	loading_progress_bar = ProgressBar.new()
	loading_progress_bar.custom_minimum_size = Vector2(400, 30)
	loading_progress_bar.value = 0
	vbox.add_child(loading_progress_bar)

func _create_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.z_index = 80
	add_child(pause_menu)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	var panel = ThemedPanel.new()
	panel.panel_style = ThemedPanel.PanelStyle.DEFAULT
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_content(vbox)
	
	var title = ThemedLabel.new()
	title.label_style = ThemedLabel.LabelStyle.TITLE
	title.label_text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var resume_btn = create_button("Reprendre", _on_resume_pressed)
	vbox.add_child(resume_btn)
	
	var options_btn = create_button("Options", _on_options_pressed)
	vbox.add_child(options_btn)
	
	var menu_btn = create_button("Menu Principal", _on_main_menu_pressed)
	vbox.add_child(menu_btn)
	
	var quit_btn = create_button("Quitter", _on_quit_pressed)
	vbox.add_child(quit_btn)

# ============================================================================
# FACTORY METHODS - CRÉATION D'UI STANDARDISÉES
# ============================================================================

func create_panel(
	style: ThemedPanel.PanelStyle = ThemedPanel.PanelStyle.DEFAULT,
	auto_margin: bool = true
) -> ThemedPanel:
	"""Crée un panel standardisé"""
	var panel = ThemedPanel.new()
	panel.panel_style = style
	panel.auto_margin = auto_margin
	return panel

func create_button(
	button_text: String,
	callback: Callable,
	icon_path: String = "",
	min_width: int = 200,
	min_height: int = 50
) -> ThemedButton:
	"""Crée un bouton standardisé"""
	var button = ThemedButton.new()
	button.button_text = button_text
	button.icon_path = icon_path
	button.min_width = min_width
	button.min_height = min_height
	button.pressed.connect(callback)
	return button

func create_label(
	label_text: String,
	style: ThemedLabel.LabelStyle = ThemedLabel.LabelStyle.NORMAL
) -> ThemedLabel:
	"""Crée un label standardisé"""
	var label = ThemedLabel.new()
	label.label_text = label_text
	label.label_style = style
	return label

func create_action_menu(position: Vector2 = Vector2.ZERO) -> PopupPanel:
	"""Crée un menu d'actions (contexte) standardisé"""
	var popup = PopupPanel.new()
	popup.name = "ActionMenu"
	popup.visible = false
	popup.popup_window = false
	popup.transparent_bg = false
	popup.borderless = false
	
	var style = UITheme.create_panel_style()
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"  # ← Nom explicite
	margin.add_theme_constant_override("margin_left", UITheme.SIZES.margin_small)
	margin.add_theme_constant_override("margin_top", UITheme.SIZES.margin_small)
	margin.add_theme_constant_override("margin_right", UITheme.SIZES.margin_small)
	margin.add_theme_constant_override("margin_bottom", UITheme.SIZES.margin_small)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"  # ← Nom explicite
	vbox.custom_minimum_size = Vector2(220, 100)
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	scene_ui_container.add_child(popup)
	
	if position != Vector2.ZERO:
		popup.position = position
	
	return popup

func create_top_bar(title: String = "") -> Control:
	"""Crée une barre supérieure standardisée"""
	var bar = ThemedPanel.new()
	bar.name = "TopBar"
	bar.panel_style = ThemedPanel.PanelStyle.DARK
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 80
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"  # ← Nom explicite
	hbox.add_theme_constant_override("separation", 40)
	bar.add_content(hbox)
	
	if title != "":
		var title_label = create_label(title, ThemedLabel.LabelStyle.TITLE)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(title_label)
	
	return bar

func create_bottom_bar() -> Control:
	"""Crée une barre inférieure standardisée"""
	var bar = ThemedPanel.new()
	bar.name = "BottomBar"
	bar.panel_style = ThemedPanel.PanelStyle.DARK
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.anchor_top = 1.0
	bar.offset_top = -120
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"  # ← Nom explicite
	hbox.add_theme_constant_override("separation", 20)
	bar.add_content(hbox)
	
	return bar

# ============================================================================
# GESTION DES UI DE SCÈNE
# ============================================================================

func register_scene_ui(scene_id: String, ui_node: Control) -> void:
	"""Enregistre une UI spécifique à une scène"""
	scene_ui_cache[scene_id] = ui_node
	scene_ui_container.add_child(ui_node)
	ui_node.visible = false

func show_scene_ui(scene_id: String) -> void:
	"""Affiche l'UI d'une scène"""
	if scene_ui_cache.has(scene_id):
		scene_ui_cache[scene_id].visible = true

func hide_scene_ui(scene_id: String) -> void:
	"""Cache l'UI d'une scène"""
	if scene_ui_cache.has(scene_id):
		scene_ui_cache[scene_id].visible = false

func hide_all_scene_ui() -> void:
	"""Cache toutes les UI de scène"""
	for ui in scene_ui_cache.values():
		ui.visible = false

func remove_scene_ui(scene_id: String) -> void:
	"""Supprime l'UI d'une scène"""
	if scene_ui_cache.has(scene_id):
		var ui = scene_ui_cache[scene_id]
		ui.queue_free()
		scene_ui_cache.erase(scene_id)

# ============================================================================
# NOTIFICATIONS
# ============================================================================

func show_notification(message: String, type: String = "info", duration: float = NOTIFICATION_DURATION) -> void:
	while active_notifications.size() >= MAX_NOTIFICATIONS:
		var oldest = active_notifications.pop_front()
		if oldest and is_instance_valid(oldest):
			oldest.queue_free()
	
	var notif = _create_notification_panel(message, type)
	notification_container.add_child(notif)
	active_notifications.append(notif)
	
	notif.modulate.a = 0.0
	notif.position.x = 50
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notif, "modulate:a", 1.0, NOTIFICATION_FADE)
	tween.tween_property(notif, "position:x", 0.0, NOTIFICATION_FADE)
	
	await get_tree().create_timer(duration).timeout
	
	if is_instance_valid(notif):
		var fade_tween = create_tween()
		fade_tween.tween_property(notif, "modulate:a", 0.0, NOTIFICATION_FADE)
		fade_tween.tween_callback(func():
			if is_instance_valid(notif):
				active_notifications.erase(notif)
				notif.queue_free()
		)

func _create_notification_panel(message: String, type: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	
	var bg_color: Color
	var border_color: Color
	
	match type:
		"success":
			bg_color = Color(0.1, 0.3, 0.1, 0.95)
			border_color = UITheme.COLORS.notif_success
		"warning":
			bg_color = Color(0.3, 0.25, 0.1, 0.95)
			border_color = UITheme.COLORS.notif_warning
		"error":
			bg_color = Color(0.3, 0.1, 0.1, 0.95)
			border_color = UITheme.COLORS.notif_error
		_:
			bg_color = UITheme.COLORS.panel_bg
			border_color = UITheme.COLORS.notif_info
	
	var style = UITheme.create_panel_style(bg_color, border_color)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)
	
	return panel

# ============================================================================
# LOADING SCREEN
# ============================================================================

func show_loading(text: String = "Chargement...") -> void:
	loading_label.text = text
	loading_progress_bar.value = 0
	loading_screen.visible = true
	is_loading_visible = true

func hide_loading() -> void:
	loading_screen.visible = false
	is_loading_visible = false

func update_loading_progress(progress: float) -> void:
	loading_progress_bar.value = progress * 100

# ============================================================================
# PAUSE MENU
# ============================================================================

func show_pause_menu() -> void:
	pause_menu.visible = true

func hide_pause_menu() -> void:
	pause_menu.visible = false

func toggle_pause_menu() -> void:
	if pause_menu.visible:
		hide_pause_menu()
	else:
		show_pause_menu()

# ============================================================================
# UTILITAIRES
# ============================================================================

func create_transition_overlay() -> ColorRect:
	return transition_overlay

# ============================================================================
# CALLBACKS EVENTBUS
# ============================================================================

func _on_notification_posted(message: String, type: String) -> void:
	show_notification(message, type)

# ============================================================================
# CALLBACKS MENU PAUSE
# ============================================================================

func _on_resume_pressed() -> void:
	hide_pause_menu()
	if GameRoot and GameRoot.game_manager:
		GameRoot.game_manager.pause_game(false)

func _on_options_pressed() -> void:
	show_notification("Options (à implémenter)", "info")

func _on_main_menu_pressed() -> void:
	hide_pause_menu()
	if GameRoot:
		if GameRoot.game_manager:
			GameRoot.game_manager.pause_game(false)
		if GameRoot.event_bus:
			GameRoot.event_bus.return_to_menu_requested.emit()

func _on_quit_pressed() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.quit_game_requested.emit()

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if GameRoot and GameRoot.game_manager:
			var current_id = GameRoot.game_manager.get_current_scene_id()
			if current_id != SceneRegistry.SceneID.MAIN_MENU:
				GameRoot.game_manager.toggle_pause()
				toggle_pause_menu()
