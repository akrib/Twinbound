# features/world_map/logic/world_map.gd
extends Node2D
## World Map - Carte du monde
## Scène chargée dans le SceneContainer par SceneLoader
##
## Les dialogues utilisent DialogueManager + UIManager (persistants)
## Les combats sont délégués à CampaignManager

class_name WorldMap

# ============================================================================
# RÉFÉRENCES
# ============================================================================

@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: CanvasLayer = $UI
@onready var locations_container: Node2D = $LocationsContainer
@onready var connections_container: Node2D = $ConnectionsContainer
@onready var player_container: Node2D = $PlayerContainer

# Labels UI existants
@onready var info_label: Label = $UI/BottomBar/MarginContainer/HBoxContainer/InfoLabel
@onready var party_button: Button = $UI/BottomBar/MarginContainer/HBoxContainer/ButtonsContainer/PartyButton
@onready var inventory_button: Button = $UI/BottomBar/MarginContainer/HBoxContainer/ButtonsContainer/InventoryButton
@onready var menu_button: Button = $UI/BottomBar/MarginContainer/HBoxContainer/ButtonsContainer/MenuButton
@onready var notification_panel: PanelContainer = $UI/NotificationPanel
@onready var notification_label: Label = $UI/NotificationPanel/MarginContainer/NotificationLabel

# ============================================================================
# DONNÉES
# ============================================================================

var world_map_data: Dictionary = {}
var locations: Dictionary = {}  # location_id -> WorldMapLocation
var player: WorldMapPlayer = null
var connections: Dictionary = {}  # connection_id -> WorldMapConnection

# ============================================================================
# ÉTAT
# ============================================================================

var current_step: int = 0
var selected_location: WorldMapLocation = null

# Menu d'actions
var action_menu: PopupPanel = null
var action_menu_container: VBoxContainer = null

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_create_action_menu()
	_connect_ui_buttons()
	_load_world_map_data()
	_generate_map()
	_spawn_player()
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.safe_connect("notification_posted", _on_notification_posted)
	
	print("[WorldMap] ✅ Carte générée")

func _create_action_menu() -> void:
	action_menu = PopupPanel.new()
	action_menu.name = "ActionMenu"
	action_menu.visible = false
	action_menu.popup_window = false
	action_menu.transparent_bg = false
	action_menu.borderless = false
	
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.9, 0.9, 0.9)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	action_menu.add_theme_stylebox_override("panel", stylebox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	action_menu.add_child(margin)
	
	action_menu_container = VBoxContainer.new()
	action_menu_container.custom_minimum_size = Vector2(220, 100)
	action_menu_container.add_theme_constant_override("separation", 5)
	margin.add_child(action_menu_container)
	
	ui_layer.add_child(action_menu)

func _connect_ui_buttons() -> void:
	if party_button:
		party_button.pressed.connect(_on_party_pressed)
	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

# ============================================================================
# CHARGEMENT DES DONNÉES
# ============================================================================

func _load_world_map_data() -> void:
	world_map_data = WorldMapDataLoader.load_world_map_data("world_map_data", true)
	
	if world_map_data.is_empty():
		push_error("[WorldMap] ❌ Impossible de charger les données de la carte")
		return
	
	print("[WorldMap] 📦 Données chargées : %s" % world_map_data.get("name", "???"))

# ============================================================================
# GÉNÉRATION DE LA CARTE
# ============================================================================

func _generate_map() -> void:
	if world_map_data.is_empty():
		return
	
	_create_locations()
	_create_connections()
	
	print("[WorldMap] ✅ Carte générée : %d locations" % locations.size())

func _create_locations() -> void:
	var locations_data = world_map_data.get("locations", [])
	
	for location_data in locations_data:
		var location = WorldMapLocation.new()
		locations_container.add_child(location)
		location.setup(location_data)
		
		var unlocked = location_data.get("unlocked_at_step", 0) <= current_step
		location.set_unlocked(unlocked)
		
		location.clicked.connect(_on_location_clicked)
		location.hovered.connect(_on_location_hovered)
		location.unhovered.connect(_on_location_unhovered)
		
		locations[location_data.id] = location

func _create_connections() -> void:
	var visual_config = world_map_data.get("connections_visual", {})
	
	if visual_config.has("width"):
		WorldMapConnection.default_line_width = visual_config.width
	if visual_config.has("dash_length"):
		WorldMapConnection.default_dash_length = visual_config.dash_length
	
	if visual_config.has("color"):
		var c = visual_config.color
		WorldMapConnection.default_color_unlocked = Color(
			c.get("r", 0.7), c.get("g", 0.7), c.get("b", 0.7), c.get("a", 0.8)
		)
	
	if visual_config.has("color_locked"):
		var c = visual_config.color_locked
		WorldMapConnection.default_color_locked = Color(
			c.get("r", 0.3), c.get("g", 0.3), c.get("b", 0.3), c.get("a", 0.4)
		)
	
	var connection_states = world_map_data.get("connection_states", {})
	
	for location_id in locations:
		var location = locations[location_id]
		var location_connections = location.get_connections()
		
		for target_id in location_connections:
			if not locations.has(target_id):
				continue
			
			var target_location = locations[target_id]
			var connection_id = _get_connection_id(location_id, target_id)
			if connections.has(connection_id):
				continue
			
			var connection = WorldMapConnection.new()
			var initial_state = _get_connection_state(location_id, target_id, connection_states)
			connection.setup(location, target_location, initial_state)
			connections_container.add_child(connection)
			connections[connection_id] = connection
	
	print("[WorldMap] ✅ %d connexions créées" % connections.size())

# ============================================================================
# HELPERS CONNEXIONS
# ============================================================================

func _get_connection_id(from_id: String, to_id: String) -> String:
	var ids = [from_id, to_id]
	ids.sort()
	return ids[0] + "_to_" + ids[1]

func _get_connection_state(from_id: String, to_id: String, states: Dictionary) -> WorldMapConnection.ConnectionState:
	var connection_id = _get_connection_id(from_id, to_id)
	
	if states.has(connection_id):
		var state_str = states[connection_id]
		match state_str:
			"unlocked":
				return WorldMapConnection.ConnectionState.UNLOCKED
			"locked":
				return WorldMapConnection.ConnectionState.LOCKED
			"hidden":
				return WorldMapConnection.ConnectionState.HIDDEN
	
	var from_loc = locations.get(from_id)
	var to_loc = locations.get(to_id)
	
	if from_loc and to_loc and from_loc.is_unlocked and to_loc.is_unlocked:
		return WorldMapConnection.ConnectionState.UNLOCKED
	
	return WorldMapConnection.ConnectionState.HIDDEN

# ============================================================================
# API CONNEXIONS
# ============================================================================

func unlock_connection(from_id: String, to_id: String) -> void:
	var connection_id = _get_connection_id(from_id, to_id)
	if connections.has(connection_id):
		connections[connection_id].unlock()

func lock_connection(from_id: String, to_id: String) -> void:
	var connection_id = _get_connection_id(from_id, to_id)
	if connections.has(connection_id):
		connections[connection_id].lock()

func hide_connection(from_id: String, to_id: String) -> void:
	var connection_id = _get_connection_id(from_id, to_id)
	if connections.has(connection_id):
		connections[connection_id].hide_connection()

func reveal_connection(from_id: String, to_id: String, locked: bool = true) -> void:
	var connection_id = _get_connection_id(from_id, to_id)
	if connections.has(connection_id):
		if locked:
			connections[connection_id].lock()
		else:
			connections[connection_id].unlock()

# ============================================================================
# JOUEUR
# ============================================================================

func _spawn_player() -> void:
	player = WorldMapPlayer.new()
	player_container.add_child(player)
	
	var player_config = world_map_data.get("player", {})
	player.setup(player_config)
	
	var start_location_id = player_config.get("start_location", "")
	
	if locations.has(start_location_id):
		player.set_location(locations[start_location_id])
	else:
		push_warning("[WorldMap] Location de départ introuvable : %s" % start_location_id)
		for loc_id in locations:
			if locations[loc_id].is_unlocked:
				player.set_location(locations[loc_id])
				break
	
	player.movement_completed.connect(_on_player_movement_completed)

# ============================================================================
# INTERACTIONS LOCATIONS
# ============================================================================

func _on_location_clicked(location: WorldMapLocation) -> void:
	if player.current_location_id == location.location_id:
		_open_location_menu(location)
		return
	
	var current_loc = locations.get(player.current_location_id)
	if not current_loc:
		return
	
	var location_connections = current_loc.get_connections()
	
	if location.location_id in location_connections:
		player.move_to_location(location)
	else:
		show_notification("Impossible d'aller directement à " + location.location_name, 2.0)

func _on_player_movement_completed() -> void:
	var current_loc = locations.get(player.current_location_id)
	if current_loc:
		show_notification("Arrivée à " + current_loc.location_name, 2.0)
		await get_tree().create_timer(0.5).timeout
		_open_location_menu(current_loc)

func _on_location_hovered(location: WorldMapLocation) -> void:
	info_label.text = location.location_name

func _on_location_unhovered(_location: WorldMapLocation) -> void:
	info_label.text = ""

# ============================================================================
# MENU D'ACTIONS
# ============================================================================

func _open_location_menu(location: WorldMapLocation) -> void:
	selected_location = location
	
	var location_data = WorldMapDataLoader.load_location_data(location.location_id)
	if location_data.is_empty():
		show_notification("Aucune action disponible ici", 2.0)
		return
	
	for child in action_menu_container.get_children():
		child.queue_free()
	
	var actions = location_data.get("actions", [])
	
	for action in actions:
		if action.has("unlocked_at_step") and action.unlocked_at_step > current_step:
			continue
		
		var button = Button.new()
		button.text = action.get("label", "Action")
		button.custom_minimum_size = Vector2(200, 40)
		
		if action.has("icon"):
			var icon_path = action.icon
			if ResourceLoader.exists(icon_path):
				button.icon = load(icon_path)
		
		var action_data = action.duplicate()
		button.pressed.connect(func(): _on_action_selected(action_data))
		action_menu_container.add_child(button)
	
	var close_button = Button.new()
	close_button.text = "✕ Fermer"
	close_button.custom_minimum_size = Vector2(200, 40)
	close_button.pressed.connect(_close_location_menu)
	action_menu_container.add_child(close_button)
	
	action_menu.popup_centered()

func _close_location_menu() -> void:
	action_menu.hide()
	selected_location = null

func _on_action_selected(action: Dictionary) -> void:
	_close_location_menu()
	
	match action.get("type"):
		"team_management":
			_handle_team_management_action()
		"battle":
			_handle_battle_action(action)
		"exploration":
			_handle_exploration_action(action)
		"building":
			_handle_building_action(action)
		"shop":
			_handle_shop_action(action)
		"quest_board":
			_handle_quest_board_action(action)
		"dialogue":
			_handle_dialogue_action(action)
		"custom":
			_handle_custom_action(action)
		_:
			show_notification("Type d'action non géré : " + action.get("type"), 2.0)

# ============================================================================
# GESTION DES ACTIONS
# ============================================================================

func _handle_battle_action(action: Dictionary) -> void:
	"""Délègue au CampaignManager pour le lancement de combat"""
	var battle_id = action.get("battle_id", "")
	
	if battle_id == "":
		show_notification("ID de combat manquant", 2.0)
		return
	
	print("[WorldMap] ⚔️ Lancement du combat : %s" % battle_id)
	
	# Déléguer à CampaignManager (gère chargement JSON, merge team, stockage)
	if GameRoot and GameRoot.campaign_manager:
		GameRoot.campaign_manager.start_battle(battle_id)
	else:
		push_error("[WorldMap] CampaignManager non disponible")

func _handle_dialogue_action(action: Dictionary) -> void:
	"""Utilise DialogueManager + UIManager (DialogueBox persistante)"""
	var dialogue_id = action.get("dialogue_id", "")
	
	if dialogue_id == "":
		show_notification("ID de dialogue manquant", 2.0)
		return
	
	print("[WorldMap] 💬 Lancement du dialogue : %s" % dialogue_id)
	
	var dialogue_loader = DialogueDataLoader.new()
	var dialogue_data_dict = dialogue_loader.load_dialogue(dialogue_id)
	
	if dialogue_data_dict.is_empty():
		show_notification("Dialogue introuvable : " + dialogue_id, 2.0)
		return
	
	# Convertir en DialogueData
	var dialogue_data = _convert_dialogue_dict_to_data(dialogue_data_dict)
	
	# Démarrer via DialogueManager (utilise la DialogueBox persistante de UIManager)
	if GameRoot and GameRoot.dialogue_manager:
		GameRoot.dialogue_manager.start_dialogue(dialogue_data)

func _handle_team_management_action() -> void:
	var roster_ui = load("res://scenes/team/team_roster_ui.tscn").instantiate()
	ui_layer.add_child(roster_ui)

func _handle_exploration_action(action: Dictionary) -> void:
	show_notification("Exploration (à implémenter)", 2.0)
	if action.has("event"):
		var event_data = action.event
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.emit_event(event_data.get("type"), [event_data])

func _handle_building_action(action: Dictionary) -> void:
	if action.has("scene"):
		show_notification("Entrée dans " + action.get("label"), 1.5)

func _handle_shop_action(action: Dictionary) -> void:
	var shop_id = action.get("shop_id", "")
	show_notification("Magasin : " + shop_id + " (à implémenter)", 2.0)

func _handle_quest_board_action(action: Dictionary) -> void:
	show_notification("Panneau de quêtes (à implémenter)", 2.0)

func _handle_custom_action(action: Dictionary) -> void:
	if action.has("event"):
		var event_data = action.event
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.emit_event(event_data.get("type"), [event_data])

# ============================================================================
# CONVERSIONS
# ============================================================================

func _convert_dialogue_dict_to_data(data_dict: Dictionary) -> DialogueData:
	var dialogue = DialogueData.new(data_dict.get("id", ""))
	
	if data_dict.has("sequences"):
		for sequence in data_dict.sequences:
			if sequence.has("lines"):
				for line in sequence.lines:
					dialogue.add_line({
						"speaker": line.get("speaker", ""),
						"text": line.get("text", ""),
						"emotion": line.get("emotion", "neutral"),
						"auto_advance": false
					})
	
	if data_dict.has("lines"):
		for line in data_dict.lines:
			dialogue.add_line(line)
	
	return dialogue

# ============================================================================
# PROGRESSION
# ============================================================================

func set_current_step(step: int) -> void:
	if step == current_step:
		return
	current_step = step
	_update_unlocked_locations()

func _update_unlocked_locations() -> void:
	for location_id in locations:
		var location = locations[location_id]
		var location_ref = _get_location_ref(location_id)
		if location_ref.is_empty():
			continue
		var unlocked = location_ref.get("unlocked_at_step", 0) <= current_step
		location.set_unlocked(unlocked)
	_refresh_connections()

func _get_location_ref(location_id: String) -> Dictionary:
	var locations_data = world_map_data.get("locations", [])
	for loc in locations_data:
		if loc.get("id") == location_id:
			return loc
	return {}

func _refresh_connections() -> void:
	for child in connections_container.get_children():
		child.queue_free()
	_create_connections()

# ============================================================================
# UI CALLBACKS
# ============================================================================

func _on_party_pressed() -> void:
	show_notification("Menu Équipe (à implémenter)", 2.0)

func _on_inventory_pressed() -> void:
	show_notification("Inventaire (à implémenter)", 2.0)

func _on_menu_pressed() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.game_paused.emit(true)

# ============================================================================
# NOTIFICATIONS
# ============================================================================

func show_notification(message: String, duration: float = 2.0) -> void:
	notification_label.text = message
	notification_panel.visible = true
	notification_panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(notification_panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(notification_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): notification_panel.visible = false)

func _on_notification_posted(message: String, type: String) -> void:
	var duration = 2.0
	if type == "warning":
		duration = 3.0
	elif type == "error":
		duration = 4.0
	show_notification(message, duration)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.disconnect_all(self)
