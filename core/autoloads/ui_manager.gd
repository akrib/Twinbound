extends CanvasLayer
## UIManager - Gestion de l'interface utilisateur globale
## Gère les notifications, l'écran de chargement, les menus globaux
## et la DialogueBox persistante (toujours en mémoire)
##
## Accès via : GameRoot.ui_manager

class_name UIManagerClass

# ============================================================================
# CONFIGURATION
# ============================================================================

const NOTIFICATION_DURATION: float = 3.0
const NOTIFICATION_FADE: float = 0.3
const MAX_NOTIFICATIONS: int = 5

# ============================================================================
# RÉFÉRENCES UI
# ============================================================================

var notification_container: VBoxContainer = null
var loading_screen: Control = null
var loading_progress_bar: ProgressBar = null
var loading_label: Label = null
var pause_menu: Control = null
var transition_overlay: ColorRect = null
var dialogue_box: DialogueBoxClass = null  # ← NOUVEAU : DialogueBox persistante

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
	
	_create_transition_layer()
	_create_notification_system()
	_create_loading_screen()
	_create_pause_menu()
	_create_dialogue_box()  # ← NOUVEAU
	
	print("[UIManager] ✅ Initialisé (avec DialogueBox persistante)")

# ============================================================================
# DIALOGUE BOX PERSISTANTE
# ============================================================================

func _create_dialogue_box() -> void:
	"""Crée la DialogueBox persistante accessible par DialogueManager"""
	
	# Charger depuis .tscn si disponible
	var dialogue_box_scene_path = "res://core/dialogue/dialogue_box.tscn"
	
	if ResourceLoader.exists(dialogue_box_scene_path):
		var packed = load(dialogue_box_scene_path)
		dialogue_box = packed.instantiate() as DialogueBoxClass
		print("[UIManager]   → DialogueBox chargée depuis .tscn")
	else:
		# Fallback : créer programmatiquement
		dialogue_box = DialogueBoxClass.new()
		dialogue_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("[UIManager]   → DialogueBox créée dynamiquement")
	
	dialogue_box.name = "PersistentDialogueBox"
	dialogue_box.visible = false
	dialogue_box.z_index = 60  # Au-dessus des scènes, sous le pause menu
	add_child(dialogue_box)

func get_dialogue_box() -> DialogueBoxClass:
	"""Retourne la DialogueBox persistante"""
	return dialogue_box

func show_dialogue_box() -> void:
	"""Affiche la DialogueBox"""
	if dialogue_box:
		dialogue_box.show_dialogue_box()

func hide_dialogue_box() -> void:
	"""Cache la DialogueBox"""
	if dialogue_box:
		dialogue_box.hide_dialogue_box()

# ============================================================================
# TRANSITION LAYER
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

# ============================================================================
# NOTIFICATIONS
# ============================================================================

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
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
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
	loading_label.add_theme_font_size_override("font_size", 32)
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
	
	var panel = PanelContainer.new()
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)
	
	var resume_btn = Button.new()
	resume_btn.text = "Reprendre"
	resume_btn.custom_minimum_size = Vector2(200, 50)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	var options_btn = Button.new()
	options_btn.text = "Options"
	options_btn.custom_minimum_size = Vector2(200, 50)
	options_btn.pressed.connect(_on_options_pressed)
	vbox.add_child(options_btn)
	
	var menu_btn = Button.new()
	menu_btn.text = "Menu Principal"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "Quitter"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

# ============================================================================
# API PUBLIQUE
# ============================================================================

func create_transition_overlay() -> ColorRect:
	return transition_overlay

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
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 4
	
	match type:
		"success":
			style.bg_color = Color(0.1, 0.3, 0.1, 0.95)
			style.border_color = Color(0.3, 0.8, 0.3)
		"warning":
			style.bg_color = Color(0.3, 0.25, 0.1, 0.95)
			style.border_color = Color(0.9, 0.7, 0.2)
		"error":
			style.bg_color = Color(0.3, 0.1, 0.1, 0.95)
			style.border_color = Color(0.9, 0.3, 0.3)
		_:
			style.bg_color = Color(0.1, 0.15, 0.25, 0.95)
			style.border_color = Color(0.4, 0.6, 0.9)
	
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
