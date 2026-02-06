extends Node3D
## BattleMapManager3D - Gestionnaire principal du combat en 3D
## VERSION COMPLÈTE : Transitions + Zoom + Rosace + Repos intégré au déplacement

class_name BattleMapManager3D

# ============================================================================
# SIGNAUX
# ============================================================================

signal battle_map_ready()
signal turn_phase_changed(phase: TurnPhase)
signal unit_selected(unit: BattleUnit3D)
signal unit_deselected()
signal action_completed()

# ============================================================================
# ENUMS
# ============================================================================

enum TurnPhase {
	PLAYER_TURN,
	ENEMY_TURN,
	CUTSCENE,
	VICTORY,
	DEFEAT
}

enum ActionState {
	IDLE,
	UNIT_SELECTED,
	CHOOSING_DUO,
	SHOWING_MOVE,
	SHOWING_ATTACK,
	EXECUTING_ACTION,
	USING_REST,
	SELECTING_ITEM_TARGET 
}

enum CompassDirection {
	NORTH = 0,
	NORTH_EAST = 45,
	EAST = 90,
	SOUTH_EAST = 135,
	SOUTH = 180,
	SOUTH_WEST = 225,
	WEST = 270,
	NORTH_WEST = 315
}

# ============================================================================
# CONFIGURATION
# ============================================================================

const TILE_SIZE: float = 1.0
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 15

# Configuration caméra
const CAMERA_ROTATION_SPEED: float = 135.0
const CAMERA_DISTANCE: float = 15.0
const CAMERA_HEIGHT: float = 12.0
const CAMERA_ANGLE: float = 45.0

# Zoom caméra
const CAMERA_ZOOM_MIN: float = 8.0
const CAMERA_ZOOM_MAX: float = 25.0
const CAMERA_ZOOM_STEP: float = 2.0

# Couleurs de highlight
const MOVEMENT_COLOR: Color = Color(0.3, 0.6, 1.0, 0.5)
const ATTACK_COLOR: Color = Color(1.0, 0.3, 0.3, 0.5)

# Scènes préchargées
const DUO_ATTACK_OPTION_SCENE = preload("res://features/Duo/ui/duo_attack_option.tscn")
const CHARACTER_MINI_CARD_SCENE = preload("res://features/Duo/ui/character_mini_card.tscn")

# ============================================================================
# RÉFÉRENCES UI
# ============================================================================

@onready var grid_container: Node3D = $GridContainer
@onready var units_container: Node3D = $UnitsContainer
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ui_layer: CanvasLayer = $UILayer
@onready var battle_ui: Control = $UILayer/BattleUI

# Menu d'actions
@onready var action_popup: PopupPanel = $UILayer/BattleUI/ActionPopup
@onready var move_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/MoveButton
@onready var attack_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/AttackButton
@onready var defend_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/DefendButton
@onready var draw_mana_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/DrawManaButton
#@onready var abilities_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/AbilitiesButton
@onready var items_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/ItemsButton
@onready var prepare_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/PrepareButton
#@onready var wait_action_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/WaitActionButton
@onready var cancel_button: Button = $UILayer/BattleUI/ActionPopup/VBoxContainer/CancelButton

# Menu de duo
@onready var duo_popup: PopupPanel = $UILayer/BattleUI/DuoSelectionPopup
@onready var support_card_container: PanelContainer = $UILayer/BattleUI/DuoSelectionPopup/MarginContainer/HBoxContainer/SupportMiniCard
@onready var leader_card_container: PanelContainer = $UILayer/BattleUI/DuoSelectionPopup/MarginContainer/HBoxContainer/LeaderMiniCard
@onready var duo_options_container: VBoxContainer = $UILayer/BattleUI/DuoSelectionPopup/MarginContainer/HBoxContainer/CenterContainer/DuoOptionsContainer
@onready var solo_button_duo: Button = $UILayer/BattleUI/DuoSelectionPopup/MarginContainer/HBoxContainer/CenterContainer/ButtonsContainer/SoloButton
@onready var cancel_duo_button: Button = $UILayer/BattleUI/DuoSelectionPopup/MarginContainer/HBoxContainer/CenterContainer/ButtonsContainer/CancelDuoButton

# Labels d'info
@onready var info_unit_name_label: Label = $UILayer/BattleUI/UnitInfoPanel/MarginContainer/VBoxContainer/UnitNameLabel
@onready var info_class_label: Label = $UILayer/BattleUI/UnitInfoPanel/MarginContainer/VBoxContainer/ClassLabel
@onready var info_hp_value: Label = $UILayer/BattleUI/UnitInfoPanel/MarginContainer/VBoxContainer/StatsGrid/HPValue
@onready var info_atk_value: Label = $UILayer/BattleUI/UnitInfoPanel/MarginContainer/VBoxContainer/StatsGrid/ATKValue
@onready var info_def_value: Label = $UILayer/BattleUI/UnitInfoPanel/MarginContainer/VBoxContainer/StatsGrid/DEFValue
@onready var info_mov_value: Label = $UILayer/BattleUI/UnitInfoPanel/MarginContainer/VBoxContainer/StatsGrid/MOVValue
@onready var turn_label: Label = $UILayer/BattleUI/TopBar/MarginContainer/HBoxContainer/TurnLabel
@onready var phase_label: Label = $UILayer/BattleUI/TopBar/MarginContainer/HBoxContainer/PhaseLabel

# Boutons de contrôle
@onready var end_turn_button: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/ButtonsContainer/EndTurnButton

# Rosace de caméra
@onready var compass_n: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/NButton
@onready var compass_ne: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/NEButton
@onready var compass_e: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/EButton
@onready var compass_se: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/SEButton
@onready var compass_s: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/SButton
@onready var compass_sw: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/SWButton
@onready var compass_w: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/WButton
@onready var compass_nw: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/NWButton
@onready var compass_center: Button = $UILayer/BattleUI/BottomBar/MarginContainer/HBoxContainer/CameraCompass/CenterButton

# Dialogue
# Dialogue et objets
#@onready var dialogue_box: DialogueBox = $UILayer/DialogueBox
@onready var item_popup: PopupPanel = $UILayer/BattleUI/ItemPopup
@onready var item_list_container: VBoxContainer = $UILayer/BattleUI/ItemPopup/MarginContainer/VBoxContainer/ScrollContainer/ItemListContainer
# ============================================================================
# MODULES
# ============================================================================

var terrain_module: TerrainModule3D
var unit_manager: UnitManager3D
var movement_module: MovementModule3D
var action_module: ActionModule3D
var objective_module: ObjectiveModule
var stats_tracker: BattleStatsTracker
var ai_module: AIModule3D
var json_scenario_module: JSONScenarioModule
var battle_state_machine: BattleStateMachine
var duo_system: DuoSystem
var ring_system: RingSystem
#var data_validation: DataValidationModule
var rest_module: RestModule  # ✅ Module de repos
var last_man_stand_module: LastManStandModule
var item_module: ItemModule

# ============================================================================
# ÉTAT
# ============================================================================

var battle_data: Dictionary = {}
var current_turn: int = 1
var selected_unit: BattleUnit3D = null
var duo_partner: BattleUnit3D = null
var hovered_unit: BattleUnit3D = null
var is_battle_active: bool = false
var current_action_state: ActionState = ActionState.IDLE
var current_attack_profile: Dictionary = {}

# Caméra
var camera_rotation_target: float = 0.0
var camera_rotation_current: float = 0.0
var is_camera_rotating: bool = false
var camera_zoom_distance: float = CAMERA_DISTANCE
var battle_center: Vector3 = Vector3.ZERO

# Transition
var transition_overlay: CanvasLayer
var transition_panel: ColorRect
var transition_label: Label

# Raycasting
const MOUSE_RAY_LENGTH: float = 1000.0

# Instances des cartes
var support_mini_card: CharacterMiniCard = null
var leader_mini_card: CharacterMiniCard = null

var is_finishing_animations := false
var _animation_trackers: Array = []  

# ============================================================================
# SYSTÈME DE TRANSITION DE TOUR
# ============================================================================

func _create_transition_overlay() -> void:
	"""Crée l'overlay pour les transitions de tour"""
	
	transition_overlay = CanvasLayer.new()
	transition_overlay.layer = 100
	add_child(transition_overlay)
	
	transition_panel = ColorRect.new()
	transition_panel.color = Color(0, 0, 0, 0)
	transition_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.add_child(transition_panel)
	
	transition_label = Label.new()
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_label.set_anchors_preset(Control.PRESET_CENTER)
	transition_label.pivot_offset = transition_label.size / 2
	
	transition_label.add_theme_font_size_override("font_size", 120)
	transition_label.add_theme_color_override("font_color", Color.WHITE)
	transition_label.add_theme_color_override("font_outline_color", Color.BLACK)
	transition_label.add_theme_constant_override("outline_size", 8)
	
	transition_overlay.add_child(transition_label)
	
	GameRoot.global_logger.debug("BATTLE", "Overlay de transition créé")

func _calculate_battle_center() -> Vector3:
	"""Calcule le centre géométrique de toutes les unités vivantes"""
	
	var alive_units = unit_manager.get_all_units().filter(func(u): return u.is_alive())
	
	if alive_units.is_empty():
		return Vector3.ZERO
	
	var sum_pos = Vector3.ZERO
	for unit in alive_units:
		sum_pos += unit.global_position
	
	var center = sum_pos / alive_units.size()
	center.y = camera_rig.position.y
	
	return center

func _play_turn_transition(turn_number: int, is_player_turn: bool) -> void:
	"""Joue l'animation de transition de tour"""
	
	battle_center = _calculate_battle_center()
	
	var phase_name = "JOUEUR" if is_player_turn else "ENNEMI"
	var message = "Tour %d - %s" % [turn_number, phase_name]
	transition_label.text = message
	
	var screen_size = get_viewport().get_visible_rect().size
	transition_label.position.x = -screen_size.x
	transition_label.position.y = screen_size.y / 2 - 60
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	tween.set_parallel(true)
	tween.tween_property(transition_panel, "color:a", 0.9, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(transition_label, "position:x", screen_size.x / 2 - transition_label.size.x / 2, 0.5).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	
	tween.tween_interval(0.5)
	tween.tween_method(_move_camera_to_position, camera_rig.position, battle_center, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.5)
	
	tween.set_parallel(true)
	tween.tween_property(transition_label, "position:x", screen_size.x, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(transition_panel, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	
	await tween.finished
	
	GameRoot.global_logger.debug("BATTLE", "Transition de tour terminée")

func _move_camera_to_position(new_position: Vector3) -> void:
	"""Déplace le camera_rig (pour tween)"""
	camera_rig.position = new_position

# ============================================================================
# ZOOM CAMÉRA
# ============================================================================

func _handle_camera_zoom(direction: float) -> void:
	"""Gère le zoom de la caméra"""
	
	camera_zoom_distance = clamp(
		camera_zoom_distance + direction * CAMERA_ZOOM_STEP,
		CAMERA_ZOOM_MIN,
		CAMERA_ZOOM_MAX
	)
	
	var angle_rad = deg_to_rad(CAMERA_ANGLE)
	camera.position.z = camera_zoom_distance
	camera.position.y = CAMERA_HEIGHT * (camera_zoom_distance / CAMERA_DISTANCE)
	
	GameRoot.global_logger.debug("BATTLE", "Zoom caméra : %.1f" % camera_zoom_distance)

# ============================================================================
# ROSACE DE CAMÉRA
# ============================================================================

func _connect_compass_buttons() -> void:
	"""Connecte les boutons de la rosace de caméra"""
	
	compass_n.pressed.connect(func(): set_camera_direction(CompassDirection.NORTH))
	compass_ne.pressed.connect(func(): set_camera_direction(CompassDirection.NORTH_EAST))
	compass_e.pressed.connect(func(): set_camera_direction(CompassDirection.EAST))
	compass_se.pressed.connect(func(): set_camera_direction(CompassDirection.SOUTH_EAST))
	compass_s.pressed.connect(func(): set_camera_direction(CompassDirection.SOUTH))
	compass_sw.pressed.connect(func(): set_camera_direction(CompassDirection.SOUTH_WEST))
	compass_w.pressed.connect(func(): set_camera_direction(CompassDirection.WEST))
	compass_nw.pressed.connect(func(): set_camera_direction(CompassDirection.NORTH_WEST))
	compass_center.pressed.connect(_on_center_camera)
	
	GameRoot.global_logger.debug("BATTLE", "Boutons de la rosace connectés")

func set_camera_direction(direction: CompassDirection) -> void:
	"""Positionne la caméra selon une direction cardinale"""
	
	camera_rotation_target = float(direction)
	is_camera_rotating = true
	
	GameRoot.global_logger.debug("BATTLE", "Caméra orientée vers : %d°" % direction)

func _on_center_camera() -> void:
	"""Centre la caméra sur le centre du combat"""
	
	battle_center = _calculate_battle_center()
	
	var tween = create_tween()
	tween.tween_property(camera_rig, "position", battle_center, 0.5).set_ease(Tween.EASE_IN_OUT)
	
	GameRoot.global_logger.debug("BATTLE", "Caméra centrée")

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	battle_state_machine = BattleStateMachine.new()
	battle_state_machine.debug_mode = true
	add_child(battle_state_machine)
	
	_setup_camera()
	_connect_ui_buttons()
	_connect_compass_buttons()
	_create_transition_overlay()
	
	GameRoot.global_logger.info("BATTLE", "BattleMapManager3D initialisé")
	
	await get_tree().process_frame
	
	if GameRoot.battle_data_manager.has_battle_data():
		var data = GameRoot.battle_data_manager.get_battle_data()
		GameRoot.global_logger.info("BATTLE", "Données récupérées : %s" % data.get("battle_id"))
		call_deferred("initialize_battle", data)
	else:
		GameRoot.global_logger.error("BATTLE", "Aucune donnée de combat disponible")
	
	battle_state_machine.state_changed.connect(_on_battle_state_changed)
	
	support_mini_card = CHARACTER_MINI_CARD_SCENE.instantiate()
	support_card_container.add_child(support_mini_card)
	
	leader_mini_card = CHARACTER_MINI_CARD_SCENE.instantiate()
	leader_card_container.add_child(leader_mini_card)
	
	if GameRoot.debug_overlay:
		GameRoot.debug_overlay.watch_variable("Tour actuel", self, "current_turn")
		GameRoot.debug_overlay.watch_variable("Phase", self, "current_phase")
		GameRoot.debug_overlay.watch_variable("Unités joueur", unit_manager, "player_units")
		GameRoot.debug_overlay.watch_variable("Unités ennemies", unit_manager, "enemy_units")

func _setup_camera() -> void:
	camera_rig.position = Vector3.ZERO
	camera_rotation_current = 0.0
	camera_rotation_target = 0.0
	_update_camera_position()

func _connect_ui_buttons() -> void:
	"""Connecte tous les boutons de l'interface"""
	
	# Menu d'actions
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	draw_mana_button.pressed.connect(_on_draw_mana_pressed)
	items_button.pressed.connect(_on_items_pressed)
	prepare_button.pressed.connect(_on_prepare_pressed)
	cancel_button.pressed.connect(_on_cancel_action_pressed)
	
	# Menu de duo
	solo_button_duo.pressed.connect(_on_solo_attack_pressed)
	cancel_duo_button.pressed.connect(_on_cancel_duo_pressed)
	
	# Boutons de contrôle
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func initialize_battle(data: Dictionary) -> void:
	if is_battle_active:
		GameRoot.global_logger.warning("BATTLE", "Combat déjà en cours")
		return
	
	battle_data = data
	is_battle_active = true
	
	GameRoot.global_logger.info("BATTLE", "Initialisation du combat 3D...")
	
	await _initialize_modules()
	
	if json_scenario_module and GameRoot.ui_manager.dialogue_box:
		json_scenario_module.dialogue_box = GameRoot.ui_manager.dialogue_box
		GameRoot.global_logger.debug("BATTLE", "DialogueBox configurée")
	
	await _load_terrain(data.get("terrain", "plains"))
	await _load_objectives(data.get("objectives", {}))
	await _load_scenario(data.get("scenario", {}))
	await _spawn_units(data.get("player_units", []), data.get("enemy_units", []))
	await _start_battle()
	
	GameRoot.global_logger.info("BATTLE", "Combat prêt !")
	battle_map_ready.emit()

# ============================================================================
# INITIALISATION DES MODULES
# ============================================================================

func _initialize_modules() -> void:
	terrain_module = TerrainModule3D.new()
	terrain_module.tile_size = TILE_SIZE
	terrain_module.grid_width = GRID_WIDTH
	terrain_module.grid_height = GRID_HEIGHT
	grid_container.add_child(terrain_module)
	
	unit_manager = UnitManager3D.new()
	unit_manager.tile_size = TILE_SIZE
	unit_manager.terrain = terrain_module
	units_container.add_child(unit_manager)
	
	movement_module = MovementModule3D.new()
	movement_module.terrain = terrain_module
	movement_module.unit_manager = unit_manager
	add_child(movement_module)
	
	action_module = ActionModule3D.new()
	action_module.unit_manager = unit_manager
	action_module.terrain = terrain_module
	add_child(action_module)
	
	objective_module = ObjectiveModule.new()
	add_child(objective_module)
	
	json_scenario_module = JSONScenarioModule.new()
	add_child(json_scenario_module)
	
	stats_tracker = BattleStatsTracker.new()
	add_child(stats_tracker)
	
	duo_system = DuoSystem.new()
	duo_system.terrain_module = terrain_module
	add_child(duo_system)
	
	ring_system = RingSystem.new()
	add_child(ring_system)
	
	#data_validation = DataValidationModule.new()
	#add_child(data_validation)
	
	ai_module = AIModule3D.new()
	ai_module.terrain = terrain_module
	ai_module.unit_manager = unit_manager
	ai_module.movement_module = movement_module
	ai_module.action_module = action_module
	ai_module.duo_system = duo_system
	add_child(ai_module)
	
	item_module = ItemModule.new()
	item_module.terrain = terrain_module
	item_module.unit_manager = unit_manager
	item_module.duo_system = duo_system
	add_child(item_module)
	
	# Charger l'inventaire depuis BattleDataManager
	var inventory = battle_data.get("inventory", {
		"potion_hp_small": 3,
		"potion_hp_medium": 2,
		"antidote": 2,
		"remedy": 1,
		"mana_elixir": 2
	})
	item_module.setup_inventory(inventory)
	
	item_module.item_used.connect(_on_item_used)
	item_module.item_failed.connect(_on_item_failed)
	
	
	# ✅ Module Last Man Stand
	last_man_stand_module = LastManStandModule.new()
	last_man_stand_module.terrain = terrain_module
	last_man_stand_module.unit_manager = unit_manager
	add_child(last_man_stand_module)
	
	last_man_stand_module.last_man_stand_triggered.connect(_on_last_man_stand_triggered)
	last_man_stand_module.last_man_stand_completed.connect(_on_last_man_stand_completed)

	
	# ✅ Module de repos
	rest_module = RestModule.new()
	add_child(rest_module)
	rest_module.reset_for_new_battle()
	rest_module.rest_points_changed.connect(_on_rest_points_changed)
	
	_connect_modules()
	await get_tree().process_frame
	
	ring_system.load_rings_from_json("res://data/ring/rings.json")
	
	#var validation_report = data_validation.validate_all_data()
	#if not validation_report.is_valid:
		#GameRoot.global_logger.error("BATTLE", "Validation des données échouée !")
		#for error in validation_report.errors:
			#GameRoot.global_logger.error("BATTLE", "  - %s" % error)
	
	_connect_duo_signals()
	
	GameRoot.global_logger.info("BATTLE", "Modules 3D initialisés")

func _connect_modules() -> void:
	unit_manager.unit_died.connect(_on_unit_died)
	unit_manager.unit_moved.connect(_on_unit_moved)
	movement_module.movement_completed.connect(stats_tracker.record_movement)
	action_module.action_executed.connect(stats_tracker.record_action)
	objective_module.objective_completed.connect(_on_objective_completed)
	objective_module.all_objectives_completed.connect(_on_victory)

func _connect_duo_signals() -> void:
	duo_system.duo_formed.connect(_on_duo_formed)
	duo_system.duo_broken.connect(_on_duo_broken)
	duo_system.duo_validation_failed.connect(_on_duo_validation_failed)

# ============================================================================
# CHARGEMENT
# ============================================================================

func _load_terrain(terrain_data: Variant) -> void:
	if typeof(terrain_data) == TYPE_STRING:
		terrain_module.load_preset(terrain_data)
	elif typeof(terrain_data) == TYPE_DICTIONARY:
		terrain_module.load_custom(terrain_data)
	GameRoot.global_logger.info("BATTLE", "Terrain 3D chargé")

func _load_objectives(objectives_data: Dictionary) -> void:
	if objectives_data.is_empty():
		return
	objective_module.setup_objectives(objectives_data)
	await get_tree().process_frame

func _load_scenario(scenario_data: Dictionary) -> void:
	if scenario_data.has("scenario_file"):
		json_scenario_module.setup_scenario(scenario_data.scenario_file)
	else:
		GameRoot.global_logger.warning("BATTLE", "Pas de fichier de scénario fourni")
	await get_tree().process_frame

func _spawn_units(player_units: Array, enemy_units: Array) -> void:
	for unit_data in player_units:
		var unit = unit_manager.spawn_unit(unit_data, true)
		if unit:
			stats_tracker.register_unit(unit)
	
	for unit_data in enemy_units:
		var unit = unit_manager.spawn_unit(unit_data, false)
		if unit:
			stats_tracker.register_unit(unit)
	
	await get_tree().process_frame
	GameRoot.global_logger.info("BATTLE", "Unités 3D spawnées")

# ============================================================================
# DÉMARRAGE
# ============================================================================

func _start_battle() -> void:
	GameRoot.global_logger.info("BATTLE", "Démarrage du combat...")
	
	if json_scenario_module.has_intro():
		change_phase(TurnPhase.CUTSCENE)
		await json_scenario_module.play_intro()
		GameRoot.global_logger.debug("BATTLE", "Intro terminée")
	
	GameRoot.event_bus.battle_started.emit(battle_data)
	change_phase(TurnPhase.PLAYER_TURN)
	_start_player_turn()

# ============================================================================
# GESTION DES TOURS
# ============================================================================

func change_phase(new_phase: TurnPhase) -> void:
	var state_name = TurnPhase.keys()[new_phase]
	battle_state_machine.change_state(state_name)

func _start_player_turn() -> void:
	GameRoot.global_logger.info("BATTLE", "=== Tour %d - JOUEUR ===" % current_turn)
	turn_label.text = "Tour " + str(current_turn)
	
	await _play_turn_transition(current_turn, true)
	
	unit_manager.reset_player_units()
	_update_all_torus_states(true)
	json_scenario_module.trigger_turn_event(current_turn, false)
	set_process_input(true)

func _start_enemy_turn() -> void:
	GameRoot.global_logger.info("BATTLE", "=== Tour %d - ENNEMI ===" % current_turn)
	
	await _play_turn_transition(current_turn, false)
	
	unit_manager.reset_enemy_units()
	_update_all_torus_states(false)
	json_scenario_module.trigger_turn_event(current_turn, false)
	await ai_module.execute_enemy_turn()
	_end_enemy_turn()

func _end_player_turn() -> void:
	GameRoot.global_logger.debug("BATTLE", "Fin du tour joueur")
	set_process_input(false)
	if selected_unit:
		_deselect_unit()
	
	change_phase(TurnPhase.ENEMY_TURN)
	await get_tree().create_timer(0.5).timeout
	_start_enemy_turn()

func _end_enemy_turn() -> void:
	GameRoot.global_logger.debug("BATTLE", "Fin du tour ennemi")
	current_turn += 1
	objective_module.check_objectives()
	change_phase(TurnPhase.PLAYER_TURN)
	await get_tree().create_timer(0.5).timeout
	_start_player_turn()

func _update_all_torus_states(is_player_turn: bool) -> void:
	for unit in unit_manager.get_all_units():
		var is_current_turn = (is_player_turn and unit.is_player_unit) or (not is_player_turn and not unit.is_player_unit)
		unit.update_torus_state(is_current_turn)

func _on_end_turn_pressed() -> void:
	_end_player_turn()

# ============================================================================
# PROCESS & INPUT
# ============================================================================

func _process(delta: float) -> void:
	_process_camera_rotation(delta)
	_update_info_panel()

func _process_camera_rotation(delta: float) -> void:
	if not is_camera_rotating:
		return
	
	var angle_diff = camera_rotation_target - camera_rotation_current
	
	while angle_diff > 180:
		angle_diff -= 360
	while angle_diff < -180:
		angle_diff += 360
	
	if abs(angle_diff) < 0.1:
		camera_rotation_current = camera_rotation_target
		is_camera_rotating = false
	else:
		var rotation_step = CAMERA_ROTATION_SPEED * delta
		
		if abs(angle_diff) < rotation_step:
			camera_rotation_current = camera_rotation_target
			is_camera_rotating = false
		else:
			camera_rotation_current += rotation_step if angle_diff > 0 else -rotation_step
		
		while camera_rotation_current >= 360:
			camera_rotation_current -= 360
		while camera_rotation_current < 0:
			camera_rotation_current += 360
		
		_update_camera_position()

func _update_camera_position() -> void:
	var angle_rad = deg_to_rad(camera_rotation_current)
	camera_rig.rotation.y = angle_rad
	
	var cam_angle_rad = deg_to_rad(CAMERA_ANGLE)
	camera.position = Vector3(0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	camera.rotation.x = -cam_angle_rad

func rotate_camera(degrees: float) -> void:
	camera_rotation_target += degrees
	while camera_rotation_target >= 360:
		camera_rotation_target -= 360
	while camera_rotation_target < 0:
		camera_rotation_target += 360
	is_camera_rotating = true

func _input(event: InputEvent) -> void:
	# Zoom toujours disponible
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_camera_zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_camera_zoom(1.0)
	
	if not is_battle_active or battle_state_machine.current_state != "PLAYER_TURN":
		return
	
	if event.is_action_pressed("ui_home"):
		rotate_camera(-45)
	elif event.is_action_pressed("ui_end"):
		rotate_camera(45)
	
	# Clic souris
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not action_popup.visible and not duo_popup.visible:
			_handle_mouse_click(event.position)

# ============================================================================
# RAYCASTING & SÉLECTION
# ============================================================================

func _handle_mouse_click(mouse_pos: Vector2) -> void:
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * MOUSE_RAY_LENGTH
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 3
	
	var result = space_state.intersect_ray(query)
	
	if result:
		_handle_raycast_hit(result)

func _handle_raycast_hit(result: Dictionary) -> void:
	var collider = result.collider
	
	if collider.has_meta("unit"):
		var unit = collider.get_meta("unit")
		
		if hovered_unit != unit:
			hovered_unit = unit
			_update_info_panel()
		
		_handle_unit_click(unit)
		return
	
	if hovered_unit != null:
		hovered_unit = null
		_update_info_panel()
	
	if collider is StaticBody3D:
		var mesh_parent = collider.get_parent()
		if mesh_parent.has_meta("grid_position"):
			var grid_pos = mesh_parent.get_meta("grid_position")
			_handle_terrain_click(grid_pos)

func _handle_unit_click(unit: BattleUnit3D) -> void:
	if unit.is_player_unit:
		if current_action_state == ActionState.CHOOSING_DUO:
			_select_duo_partner(unit)
		else:
			_select_unit(unit)
	elif selected_unit and selected_unit.can_act():
		if current_action_state == ActionState.SHOWING_ATTACK:
			_attack_unit(selected_unit, unit)
	# Sélection de cible pour objet
	if current_action_state == ActionState.SELECTING_ITEM_TARGET:
		var item_id = get_meta("pending_item_id", "")
		var item_type = get_meta("pending_item_type", "")
		
		match item_type:
			"ally_single":
				if unit.is_player_unit:
					item_module.use_item(selected_unit, item_id, unit)
					_close_all_menus()
					_deselect_unit()
			
			"enemy_single", "enemy_duo":
				if not unit.is_player_unit:
					item_module.use_item(selected_unit, item_id, unit)
					_close_all_menus()
					_deselect_unit()

func _handle_terrain_click(grid_pos: Vector2i) -> void:
	if not selected_unit:
		return
	
	if current_action_state == ActionState.SHOWING_MOVE or current_action_state == ActionState.USING_REST:
		# ✅ FIX : En mode repos, vérifier que la case est dans la liste calculée
		if current_action_state == ActionState.USING_REST:
			# Récupérer les positions accessibles avec repos
			var rest_positions = movement_module.calculate_single_step_positions(selected_unit)
			
			if grid_pos not in rest_positions:
				GameRoot.global_logger.debug("BATTLE", "Clic hors portée de repos - annulation")
				_close_all_menus()
				_deselect_unit()
				return
		
		if movement_module.can_move_to(selected_unit, grid_pos):
			await movement_module.move_unit(selected_unit, grid_pos)
			
			if current_action_state == ActionState.USING_REST:
				GameRoot.global_logger.debug("BATTLE", "Déplacement avec repos terminé")
			
			selected_unit.movement_used = true
			_close_all_menus()
			_deselect_unit()
		else:
			GameRoot.global_logger.debug("BATTLE", "Clic hors portée de déplacement - annulation")
			_close_all_menus()
			_deselect_unit()
	
	elif current_action_state == ActionState.SHOWING_ATTACK:
		var attack_positions = action_module.get_attack_positions(selected_unit)
		
		if grid_pos not in attack_positions:
			GameRoot.global_logger.debug("BATTLE", "Clic hors portée d'attaque - annulation")
			_close_all_menus()
			_deselect_unit()
			
	if current_action_state == ActionState.SELECTING_ITEM_TARGET:
		var item_type = get_meta("pending_item_type", "")
		
		if item_type == "position":
			var item_id = get_meta("pending_item_id", "")
			item_module.use_item(selected_unit, item_id, grid_pos)
			_close_all_menus()
			_deselect_unit()

			
# ============================================================================
# PANEL D'INFORMATION
# ============================================================================

func _update_info_panel() -> void:
	if hovered_unit and hovered_unit != selected_unit:
		_display_unit_info(hovered_unit)
	elif selected_unit:
		_display_unit_info(selected_unit)
	else:
		_display_terrain_info()

func _display_unit_info(unit: BattleUnit3D) -> void:
	info_unit_name_label.text = unit.unit_name
	info_class_label.text = "Classe: " + unit.get_meta("class", "Guerrier")
	
	# HP
	info_hp_value.text = "%d/%d" % [unit.current_hp, unit.max_hp]
	
	# ✅ NOUVEAU : Afficher le mana
	var mana_text = "%d/%d (%s)" % [unit.current_mana, unit.max_mana, unit.mana_type.capitalize()]
	# On peut utiliser un label existant ou en créer un nouveau
	# Pour l'instant, ajoutons-le au label de classe
	info_class_label.text = "Classe: %s | Mana: %s" % [unit.get_meta("class", "Guerrier"), mana_text]
	
	info_atk_value.text = str(unit.attack_power)
	info_def_value.text = str(unit.defense_power)
	info_mov_value.text = str(unit.movement_range)
	
	var hp_percent = unit.get_hp_percentage()
	if hp_percent > 0.6:
		info_hp_value.add_theme_color_override("font_color", Color.GREEN)
	elif hp_percent > 0.3:
		info_hp_value.add_theme_color_override("font_color", Color.YELLOW)
	else:
		info_hp_value.add_theme_color_override("font_color", Color.RED)
		
		
func _display_terrain_info() -> void:
	if not terrain_module:
		info_unit_name_label.text = "[Chargement...]"
		info_class_label.text = ""
		info_hp_value.text = "--"
		info_atk_value.text = "--"
		info_def_value.text = "--"
		info_mov_value.text = "--"
		return
	
	var grid_pos = _get_mouse_grid_position()
	
	if not terrain_module.is_in_bounds(grid_pos):
		grid_pos = Vector2i(0, 0)
	
	var tile_type = terrain_module.get_tile_type(grid_pos)
	var tile_name = TerrainModule3D.TileType.keys()[tile_type]
	
	info_unit_name_label.text = "[Terrain]"
	info_class_label.text = "Type: " + tile_name
	
	var move_cost = terrain_module.get_movement_cost(grid_pos)
	var defense_bonus = terrain_module.get_defense_bonus(grid_pos)
	
	info_hp_value.text = "Coût: " + ("∞" if move_cost == INF else str(move_cost))
	info_atk_value.text = "--"
	info_def_value.text = "+" + str(defense_bonus)
	info_mov_value.text = "--"
	
	info_hp_value.add_theme_color_override("font_color", Color.WHITE)

func _get_mouse_grid_position() -> Vector2i:
	if not terrain_module:
		return Vector2i(-1, -1)
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * MOUSE_RAY_LENGTH
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider is StaticBody3D:
		var mesh_parent = result.collider.get_parent()
		if mesh_parent.has_meta("grid_position"):
			return mesh_parent.get_meta("grid_position")
	
	return Vector2i(-1, -1)

# ============================================================================
# SÉLECTION D'UNITÉ & MENU D'ACTIONS
# ============================================================================

func _select_unit(unit: BattleUnit3D) -> void:
	if selected_unit == unit:
		return
	
	if selected_unit:
		_deselect_unit()
	
	selected_unit = unit
	selected_unit.set_selected(true)
	unit_selected.emit(unit)
	
	_open_action_menu()
	
	current_action_state = ActionState.UNIT_SELECTED
	GameRoot.global_logger.debug("BATTLE", "Unité sélectionnée : %s" % unit.unit_name)

func _deselect_unit() -> void:
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
		duo_partner = null
		unit_deselected.emit()
		terrain_module.clear_all_highlights()
		_close_all_menus()
		current_action_state = ActionState.IDLE

func _open_action_menu() -> void:
	if not selected_unit:
		return
	
	var screen_pos = camera.unproject_position(selected_unit.position)
	action_popup.position = screen_pos + Vector2(50, -100)
	
	# ✅ Logique du bouton Déplacer avec repos
	var can_use_rest = rest_module.can_use_rest(selected_unit)
	var has_moved = selected_unit.movement_used
	
	if has_moved and can_use_rest:
		# L'unité s'est déjà déplacée, proposer le repos
		move_button.text = "🏃 Repos (%d/2)" % rest_module.get_rest_points(selected_unit.is_player_unit)
		move_button.disabled = false
	elif not has_moved:
		# Déplacement normal
		move_button.text = "👣 Déplacer"
		move_button.disabled = not selected_unit.can_move()
	else:
		# Déjà bougé et pas de repos
		move_button.text = "👣 Déplacer"
		move_button.disabled = true
	
	attack_button.disabled = not selected_unit.can_act()
	defend_button.disabled = not selected_unit.can_act()
	draw_mana_button.disabled = not selected_unit.can_act()
	
	action_popup.popup()

func _close_all_menus() -> void:
	action_popup.hide()
	duo_popup.hide()
	terrain_module.clear_all_highlights()

# ============================================================================
# ACTIONS DU MENU
# ============================================================================

func _on_move_pressed() -> void:
	if not selected_unit:
		return
	
	# ✅ Vérifier si on est en mode repos
	if selected_unit.movement_used and rest_module.can_use_rest(selected_unit):
		# Mode repos : consommer le point AVANT de montrer la zone
		if not rest_module.use_rest_point(selected_unit):
			GameRoot.event_bus.notify("❌ Impossible d'utiliser le repos", "error")
			return
		
		GameRoot.event_bus.notify("✨ Repos utilisé : +1 case de déplacement", "success")
		
		action_popup.hide()
		current_action_state = ActionState.USING_REST
		
		# Calculer positions accessibles (1 case uniquement)
		var reachable = movement_module.calculate_single_step_positions(selected_unit)
		
		if reachable.is_empty():
			GameRoot.event_bus.notify("⚠️ Aucune case accessible", "warning")
			terrain_module.clear_all_highlights()
			current_action_state = ActionState.IDLE
			return
		
		terrain_module.highlight_tiles(reachable, MOVEMENT_COLOR)
		GameRoot.global_logger.info("BATTLE", "%s utilise le repos : %d case(s) accessible(s)" % [
			selected_unit.unit_name,
			reachable.size()
		])
	
	else:
		# Déplacement normal
		if not selected_unit.can_move():
			return
		
		action_popup.hide()
		current_action_state = ActionState.SHOWING_MOVE
		
		var reachable = movement_module.calculate_reachable_positions(selected_unit)
		terrain_module.highlight_tiles(reachable, MOVEMENT_COLOR)
		
		GameRoot.global_logger.debug("BATTLE", "Mode déplacement activé")

func _on_attack_pressed() -> void:
	if not selected_unit or not selected_unit.can_act():
		return
	
	action_popup.hide()
	_open_duo_selection_menu()

func _on_defend_pressed() -> void:
	if not selected_unit or not selected_unit.can_act():
		return
	
	GameRoot.global_logger.debug("BATTLE", "%s prend une posture défensive" % selected_unit.unit_name)
	
	# ✅ Marquer l'unité comme défendant
	selected_unit.action_used = true
	selected_unit.movement_used = true
	
	# ✅ Appliquer le bonus de défense de 30% (réduction de dégâts)
	selected_unit.set_meta("is_defending", true)
	selected_unit.set_meta("defense_bonus", 0.30)  # 30% de réduction
	
	selected_unit.update_state_indicators() 
	# ✅ Effet visuel de défense
	_play_defend_animation(selected_unit)
	
	GameRoot.event_bus.notify("🛡 %s : posture défensive (+30%% résistance)" % selected_unit.unit_name, "info")
	
	_close_all_menus()
	_deselect_unit()

func _play_defend_animation(unit: BattleUnit3D) -> void:
	"""Affiche une animation de défense"""
	
	if not unit or not unit.sprite_3d:
		return
	
	# Effet de bouclier bleu
	var tween = unit.create_tween()
	tween.tween_property(unit.sprite_3d, "modulate", Color(0.5, 0.5, 1.5), 0.2)
	tween.tween_property(unit.sprite_3d, "modulate", Color.WHITE, 0.2)

func _on_draw_mana_pressed() -> void:
	"""Action : Puiser du mana (récupération partielle)"""
	
	if not selected_unit or not selected_unit.can_act():
		return
	
	# Récupérer 30% du mana maximum
	var mana_gained = int(selected_unit.max_mana * 0.30)
	selected_unit.restore_mana(mana_gained)
	
	# Marquer l'action comme utilisée
	selected_unit.action_used = true
	selected_unit.movement_used = true
	
	# Animation visuelle
	_play_mana_draw_animation(selected_unit)
	
	GameRoot.event_bus.notify("✨ %s puise du mana : +%d" % [selected_unit.unit_name, mana_gained], "success")
	GameRoot.global_logger.info("BATTLE", "%s puise %d mana (total: %d/%d)" % [
		selected_unit.unit_name,
		mana_gained,
		selected_unit.current_mana,
		selected_unit.max_mana
	])
	
	_close_all_menus()
	_deselect_unit()

func _play_mana_draw_animation(unit: BattleUnit3D) -> void:
	"""Animation de puisage de mana"""
	
	if not unit or not unit.sprite_3d:
		return
	
	# Effet de brille cyan
	var tween = unit.create_tween()
	tween.set_parallel(true)
	
	# Pulsation
	tween.tween_property(unit.sprite_3d, "scale", Vector3(1.2, 1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit.sprite_3d, "scale", Vector3.ONE, 0.3).set_delay(0.3)
	
	# Couleur cyan brillante
	tween.tween_property(unit.sprite_3d, "modulate", Color(0.3, 1.5, 1.5), 0.3)
	tween.tween_property(unit.sprite_3d, "modulate", Color.WHITE, 0.3).set_delay(0.3)
	
	await tween.finished

func _on_prepare_pressed() -> void:
	"""Action : Se préparer (bonus au prochain tour)"""
	
	if not selected_unit or not selected_unit.can_act():
		return
	
	# Marquer comme préparé
	selected_unit.set_meta("is_prepared", true)
	selected_unit.set_meta("prepared_bonus", {
		"attack": 1.2,  # +20% attaque
		"defense": 1.15,  # +15% défense
		"turns_remaining": 1
	})
	
	# Marquer l'action
	selected_unit.action_used = true
	selected_unit.movement_used = true
	
	selected_unit.update_state_indicators()
	# Animation
	_play_prepare_animation(selected_unit)
	
	GameRoot.event_bus.notify("🛡️ %s se prépare (+20%% ATK, +15%% DEF)" % selected_unit.unit_name, "info")
	GameRoot.global_logger.info("BATTLE", "%s se prépare pour le prochain tour" % selected_unit.unit_name)
	
	_close_all_menus()
	_deselect_unit()

func _play_prepare_animation(unit: BattleUnit3D) -> void:
	"""Animation de préparation"""
	
	if not unit or not unit.sprite_3d:
		return
	
	# Effet de concentration (couleur dorée)
	var tween = unit.create_tween()
	tween.tween_property(unit.sprite_3d, "modulate", Color(1.5, 1.5, 0.5), 0.4).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(unit.sprite_3d, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_IN_OUT)

func _on_cancel_action_pressed() -> void:
	_close_all_menus()
	current_action_state = ActionState.IDLE

# ============================================================================
# SYSTÈME DE DUO
# ============================================================================

func _open_duo_selection_menu() -> void:
	if not selected_unit:
		return
	
	var allies = unit_manager.get_alive_player_units()
	var is_last_survivor = allies.size() == 1
	
	for child in duo_options_container.get_children():
		child.queue_free()
	
	if leader_mini_card:
		leader_mini_card.setup_from_unit(selected_unit)
	
	if allies.size() > 1:
		var duo_candidates: Array[BattleUnit3D] = []
		
		for ally in allies:
			if ally == selected_unit:
				continue
			
			if not ally.can_act():
				continue
			
			if not _is_cardinal_adjacent(selected_unit.grid_position, ally.grid_position):
				continue
			
			duo_candidates.append(ally)
		
		if not duo_candidates.is_empty() and support_mini_card:
			support_mini_card.setup_from_unit(duo_candidates[0])
		
		for partner in duo_candidates:
			var leader_ring_data = _get_ring_data_from_unit(selected_unit, "mat")
			var partner_ring_data = _get_ring_data_from_unit(partner, "chan")
			
			var duo_option = DUO_ATTACK_OPTION_SCENE.instantiate()
			duo_options_container.add_child(duo_option)
			
			duo_option.setup(partner_ring_data, leader_ring_data, partner)
			
			duo_option.option_hovered.connect(
				func(hovered_partner: BattleUnit3D):
					if support_mini_card:
						support_mini_card.setup_from_unit(hovered_partner)
					_play_duo_formation_effect(selected_unit, hovered_partner)
			)
			
			duo_option.option_unhovered.connect(
				func(unhovered_partner: BattleUnit3D):
					_stop_blink_effect(selected_unit)
					_stop_blink_effect(unhovered_partner)
			)
			
			duo_option.option_selected.connect(
				func(mana_id, weapon_id):
					_stop_blink_effect(selected_unit)
					_stop_blink_effect(partner)
					
					_on_duo_option_selected(partner, {
						"mana_ring": mana_id,
						"weapon_ring": weapon_id
					})
			)
	if is_last_survivor:
		var lms_check = last_man_stand_module.can_use_last_man_stand(selected_unit)
		
		if lms_check.can_use:
			solo_button_duo.text = "💀 DÉCHAÎNEMENT PROFANE (LMS)"
			solo_button_duo.modulate = Color(1.5, 0.3, 0.3)  # Rouge intense
		else:
			solo_button_duo.text = "❌ Attaque solo impossible"
			solo_button_duo.disabled = true
			
			# Afficher la raison
			var reason_label = Label.new()
			reason_label.text = "⚠️ " + lms_check.reason
			reason_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
			duo_options_container.add_child(reason_label)
	else:
		solo_button_duo.visible = false

	solo_button_duo.visible = is_last_survivor
	if is_last_survivor:
		solo_button_duo.text = "⚔️ Attaquer (Dernier survivant)"
	
	var screen_size = get_viewport().get_visible_rect().size
	duo_popup.position = Vector2(screen_size.x - 1020, 20)
	
	_setup_duo_popup_transparency()
	duo_popup.popup()
	
	current_action_state = ActionState.CHOOSING_DUO

func _setup_duo_popup_transparency() -> void:
	if not duo_popup.has_theme_stylebox_override("panel"):
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
		style.border_color = Color(0.7, 0.7, 0.8, 0.9)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		
		duo_popup.add_theme_stylebox_override("panel", style)
	
	if support_card_container and not support_card_container.has_theme_stylebox_override("panel"):
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.15, 0.15, 0.18, 0.90)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(0.6, 0.6, 0.7, 1)
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_right = 10
		card_style.corner_radius_bottom_left = 10
		
		support_card_container.add_theme_stylebox_override("panel", card_style)
		leader_card_container.add_theme_stylebox_override("panel", card_style)

func _on_duo_option_selected(partner: BattleUnit3D, ring_combo: Dictionary) -> void:
	if not _is_cardinal_adjacent(selected_unit.grid_position, partner.grid_position):
		GameRoot.event_bus.notify("Le partenaire doit être adjacent (N, S, E, O)", "error")
		return
	
	duo_partner = partner
	current_attack_profile = ring_combo
	
	duo_popup.hide()
	_show_attack_range()
	
	GameRoot.event_bus.notify("Duo : %s + %s" % [selected_unit.unit_name, partner.unit_name], "info")

func _play_duo_formation_effect(leader: BattleUnit3D, support: BattleUnit3D) -> void:
	_start_blink_effect(leader)
	_start_blink_effect(support)

func _start_blink_effect(unit: BattleUnit3D) -> void:
	if not unit or not unit.sprite_3d:
		return
	
	if unit.has_meta("blink_tween"):
		var old_tween = unit.get_meta("blink_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	
	var tween = unit.sprite_3d.create_tween()
	tween.set_loops()
	
	tween.tween_property(unit.sprite_3d, "modulate:a", 0.3, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(unit.sprite_3d, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	
	unit.set_meta("blink_tween", tween)

func _stop_blink_effect(unit: BattleUnit3D) -> void:
	if not unit or not unit.sprite_3d:
		return
	
	if unit.has_meta("blink_tween"):
		var tween = unit.get_meta("blink_tween") as Tween
		if tween and tween.is_valid():
			tween.kill()
		unit.remove_meta("blink_tween")
	
	unit.sprite_3d.modulate.a = 1.0

func _select_duo_partner(partner: BattleUnit3D) -> void:
	if partner == selected_unit:
		return
	
	if duo_system.try_form_duo(selected_unit, partner):
		duo_partner = partner
		duo_popup.hide()
		_show_attack_range()
		
		GameRoot.global_logger.info("BATTLE", "Duo formé via DuoSystem")
	else:
		GameRoot.event_bus.notify("Impossible de former ce duo", "warning")

func _on_solo_attack_pressed() -> void:
	"""Gère l'attaque solo - soit Last Man Stand, soit erreur"""
	
	if not selected_unit:
		return
	
	duo_popup.hide()
	duo_partner = null
	
	# ✅ Vérifier si Last Man Stand est possible
	var lms_check = last_man_stand_module.can_use_last_man_stand(selected_unit)
	
	if lms_check.can_use:
		# Demander confirmation
		var confirm_text = "⚠️ DÉCHAÎNEMENT PROFANE ⚠️\n\nVoulez-vous déclencher cette attaque interdite ?\n- Consomme 100%% du mana\n- Frappe toutes les cases adjacentes\n- Acte socialement condamné"
		
		# Vous pourriez créer un dialogue de confirmation ici
		# Pour l'instant, on lance directement
		
		await last_man_stand_module.execute_last_man_stand(selected_unit)
		
		_close_all_menus()
		_deselect_unit()
	else:
		# Attaque solo impossible
		GameRoot.event_bus.notify("❌ Attaque solo impossible : %s" % lms_check.reason, "error")
		GameRoot.global_logger.warning("BATTLE", lms_check.reason)
		
		# Réouvrir le menu de sélection
		_open_action_menu()


func _on_cancel_duo_pressed() -> void:
	duo_popup.hide()
	current_action_state = ActionState.UNIT_SELECTED
	_open_action_menu()

func _show_attack_range() -> void:
	if not selected_unit:
		return
	
	current_action_state = ActionState.SHOWING_ATTACK
	
	var attack_positions = action_module.get_attack_positions(selected_unit)
	terrain_module.highlight_tiles(attack_positions, ATTACK_COLOR)
	
	GameRoot.global_logger.debug("BATTLE", "Portée d'attaque affichée")

# ============================================================================
# ACTIONS DE COMBAT
# ============================================================================

func _attack_unit(attacker: BattleUnit3D, target: BattleUnit3D) -> void:
	if not action_module.can_attack(attacker, target):
		return
	
	current_action_state = ActionState.EXECUTING_ACTION
	
	if duo_partner:
		GameRoot.global_logger.info("BATTLE", "Attaque en duo temporaire !")
	
	await action_module.execute_attack(attacker, target, duo_partner)
	
	attacker.action_used = true
	attacker.movement_used = true
	
	if duo_partner:
		duo_partner.action_used = true
		duo_partner.movement_used = true
		
		attacker.update_torus_state(true)
		duo_partner.update_torus_state(true)
	
	duo_partner = null
	current_attack_profile = {}
	
	_close_all_menus()
	_deselect_unit()

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_unit_died(unit: BattleUnit3D) -> void:
	GameRoot.global_logger.info("BATTLE", "Unité morte : %s" % unit.unit_name)
	GameRoot.event_bus.unit_died.emit(unit)
	stats_tracker.record_death(unit)
	_check_battle_end()

func _on_unit_moved(unit: BattleUnit3D, from: Vector2i, to: Vector2i) -> void:
	json_scenario_module.trigger_position_event(unit, to)
	objective_module.check_position_objectives(unit, to)

func _on_objective_completed(objective_id: String) -> void:
	GameRoot.global_logger.info("BATTLE", "Objectif complété : %s" % objective_id)
	GameRoot.event_bus.notify("Objectif complété!", "success")

func _on_victory() -> void:
	GameRoot.global_logger.info("BATTLE", "=== VICTOIRE ===")
	change_phase(TurnPhase.VICTORY)
	await _end_battle(true)

func _check_battle_end() -> void:
	if unit_manager.get_alive_player_units().is_empty():
		GameRoot.global_logger.info("BATTLE", "=== DÉFAITE ===")
		change_phase(TurnPhase.DEFEAT)
		await _end_battle(false)
		return
	
	if unit_manager.get_alive_enemy_units().is_empty():
		if objective_module.are_all_completed():
			_on_victory()

func _end_battle(victory: bool) -> void:
	is_battle_active = false
	duo_system.clear_all_duos()
	await wait_for_all_animations(2.0)
	if victory:
		_award_xp_to_survivors()
	
	if json_scenario_module.has_outro():
		change_phase(TurnPhase.CUTSCENE)
		await json_scenario_module.play_outro(victory)
	else: 
		await _play_end_dialogue(victory)
	
	
	var battle_stats = stats_tracker.get_final_stats()
	
	var xp_earned = 0
	if victory:
		var global_stats = battle_stats.get("global", {})
		var turns = global_stats.get("turns_elapsed", 1)
		var enemies_killed = global_stats.get("units_killed", 0)
		
		xp_earned = 50 + (enemies_killed * 10)
		
		if turns < 10:
			xp_earned += 50
	
	var results = {
		"victory": victory,
		"battle_title": battle_data.get("battle_title", "Combat Tactique"),
		"turns": current_turn,
		"stats": battle_stats,
		"objectives": objective_module.get_completion_status(),
		"mvp": stats_tracker.get_mvp(),
		"rewards": _calculate_rewards(victory, battle_stats),
		"xp_earned": xp_earned
	}
	
	GameRoot.event_bus.battle_ended.emit(results)
	
	if victory:
		GameRoot.event_bus.notify("Victoire ! Tour %d - MVP: %s" % [current_turn, results.mvp.get("name", "N/A")], "success")
	else:
		GameRoot.event_bus.notify("Défaite...", "error")
	
	GameRoot.battle_data_manager.store_battle_results(results)
	
	await get_tree().create_timer(2.0).timeout
	
	GameRoot.event_bus.change_scene(SceneRegistry.SceneID.BATTLE_RESULTS)

func _award_xp_to_survivors() -> void:
	var player_units = unit_manager.get_alive_player_units()
	var xp_per_unit = 50 + (current_turn * 10)
	
	for unit in player_units:
		unit.award_xp(xp_per_unit)

func _calculate_rewards(victory: bool, stats: Dictionary) -> Dictionary:
	if not victory:
		return {"gold": 0, "exp": 0}
	
	var base_gold = 100
	var base_exp = 50
	var efficiency_bonus = 1.0 + (stats.get("efficiency", 0) * 0.1)
	
	return {
		"gold": int(base_gold * efficiency_bonus),
		"exp": int(base_exp * efficiency_bonus)
	}

func wait_for_all_animations(timeout := 2.0) -> void:
	is_finishing_animations = true
	var start_time := Time.get_ticks_msec()
	while _has_running_animations():
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > int(timeout * 1000):
			print("[Battle] ⏱ Timeout animations, on force la fin.")
			break
	is_finishing_animations = false

func _has_running_animations() -> bool:
	# Vérifie les animations des unités
	for unit in unit_manager.get_all_units().filter(func(u): return u.is_alive()):
		if is_instance_valid(unit):

			# 1) AnimationPlayer
			if unit.has_node("AnimationPlayer"):
				var ap = unit.get_node("AnimationPlayer")
				if ap.is_playing():
					return true

			# 2) Tweens internes
			if unit.has_method("has_active_tweens") and unit.has_active_tweens():
				return true

			# 3) Effets spéciaux (duo aura, hit flash…)
			if unit.has_method("is_effect_running") and unit.is_effect_running():
				return true

	# Vérifie les tweens globaux
	for tween in get_tree().get_processed_tweens():
		if is_instance_valid(tween) and tween.is_running():
			return true
	return false


func _play_end_dialogue(victory: bool) -> void:
	var dialogue_id = null
	if victory:
		dialogue_id = battle_data.get("win_dialogue", null)
	else:
		dialogue_id = battle_data.get("lose_dialogue", null)
	if dialogue_id == null:
		if victory == true:
			dialogue_id = "default_victory" 
		else:
			dialogue_id = "default_defeat"

	print("[Battle] 🎤 Dialogue de fin :", dialogue_id)

	if GameRoot and GameRoot.dialogue_manager:
		GameRoot.dialogue_manager.start_dialogue_by_id(dialogue_id)
		await GameRoot.dialogue_manager.dialogue_ended



# ============================================================================
# CALLBACKS DUO
# ============================================================================




func _on_duo_formed(duo_data: Dictionary) -> void:
	var leader = duo_data.leader as BattleUnit3D
	var support = duo_data.support as BattleUnit3D
	
	GameRoot.global_logger.info("BATTLE", "Duo formé : %s + %s" % [leader.unit_name, support.unit_name])
	GameRoot.event_bus.notify("Duo formé : " + leader.unit_name + " + " + support.unit_name, "success")

func _on_duo_broken(duo_id: String) -> void:
	GameRoot.global_logger.debug("BATTLE", "Duo rompu : %s" % duo_id)

func _on_duo_validation_failed(reason: String) -> void:
	GameRoot.event_bus.notify("Formation de duo impossible : " + reason, "warning")

# ============================================================================
# CALLBACKS REPOS
# ============================================================================

func _on_rest_points_changed(is_player: bool, new_value: int) -> void:
	"""Callback quand les points de repos changent"""
	
	GameRoot.global_logger.debug("BATTLE", "Repos %s : %d/2" % [
		"Joueur" if is_player else "Ennemi",
		new_value
	])

# ============================================================================
# UTILITAIRES
# ============================================================================

func _get_ring_data_from_unit(unit: BattleUnit3D, ring_type: String) -> Dictionary:
	var ring_id: String = ""
	
	if ring_type == "mat":
		ring_id = unit.equipped_materialization_ring
	elif ring_type == "chan":
		ring_id = unit.equipped_channeling_ring
	
	if ring_system:
		if ring_type == "mat":
			var ring = ring_system.get_materialization_ring(ring_id)
			if ring:
				return {
					"ring_id": ring.ring_id,
					"ring_name": ring.ring_name,
					"icon": ""
				}
		elif ring_type == "chan":
			var ring = ring_system.get_channeling_ring(ring_id)
			if ring:
				return {
					"ring_id": ring.ring_id,
					"ring_name": ring.ring_name,
					"icon": ""
				}
	
	var fallback_names = {
		"mat_basic_line": "Lame Basique",
		"mat_cone": "Cône d'Attaque",
		"mat_cross": "Croix Sacrée",
		"chan_fire": "Feu",
		"chan_ice": "Glace",
		"chan_neutral": "Neutre"
	}
	
	return {
		"ring_id": ring_id,
		"ring_name": fallback_names.get(ring_id, ring_id),
		"icon": ""
	}

func _is_cardinal_adjacent(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	var diff = pos_b - pos_a
	return (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _on_battle_state_changed(from: String, to: String) -> void:
	GameRoot.global_logger.debug("BATTLE", "État : %s → %s" % [from, to])
	phase_label.text = "Phase: " + to

func _exit_tree() -> void:
	GameRoot.event_bus.disconnect_all(self)
	GameRoot.global_logger.info("BATTLE", "BattleMapManager3D nettoyé")

func store_battle_results(results: Dictionary) -> void:
	"""Stocke les résultats du combat pour l'écran de résultats"""
	battle_data["results"] = results
	print("[BattleDataManager] Résultats de combat stockés")
	
func _on_last_man_stand_triggered(unit: BattleUnit3D) -> void:
	"""Callback quand Last Man Stand est déclenché"""
	GameRoot.global_logger.info("BATTLE", "💀 %s déclenche le Déchaînement Profane" % unit.unit_name)

func _on_last_man_stand_completed(unit: BattleUnit3D, total_damage: int) -> void:
	"""Callback quand Last Man Stand est terminé"""
	GameRoot.global_logger.info("BATTLE", "✅ Déchaînement Profane terminé : %d dégâts totaux" % total_damage)
	
func _on_items_pressed() -> void:
	if not selected_unit:
		return
	
	action_popup.hide()
	_open_item_menu()

func _open_item_menu() -> void:
	"""Affiche le menu de sélection d'objets"""
	
	if not selected_unit:
		return
	
	# Nettoyer la liste
	for child in item_list_container.get_children():
		child.queue_free()
	
	# Récupérer les objets disponibles
	var available_items = item_module.get_available_items(selected_unit)
	
	if available_items.is_empty():
		var no_items_label = Label.new()
		no_items_label.text = "Aucun objet disponible"
		no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list_container.add_child(no_items_label)
	else:
		for item_info in available_items:
			var item_button = _create_item_button(item_info)
			item_list_container.add_child(item_button)
	
	# Bouton annuler
	var cancel_btn = Button.new()
	cancel_btn.text = "✕ Annuler"
	cancel_btn.custom_minimum_size = Vector2(0, 40)
	cancel_btn.pressed.connect(_on_item_menu_cancel)
	item_list_container.add_child(cancel_btn)
	
	# Positionner et afficher
	var screen_size = get_viewport().get_visible_rect().size
	item_popup.position = Vector2(screen_size.x / 2 - 200, screen_size.y / 2 - 250)
	item_popup.popup()

func _create_item_button(item_info: Dictionary) -> Button:
	"""Crée un bouton pour un objet"""
	
	var button = Button.new()
	button.custom_minimum_size = Vector2(380, 60)
	
	# Texte du bouton
	var item_name = item_info.get("name", "Objet")
	var quantity = item_info.get("quantity", 0)
	var description = item_info.get("description", "")
	
	button.text = "%s (x%d)\n%s" % [item_name, quantity, description]
	
	# Coloration selon la rareté
	var rarity = item_info.get("rarity", ItemModule.ItemRarity.COMMON)
	match rarity:
		ItemModule.ItemRarity.COMMON:
			button.modulate = Color(1.0, 1.0, 1.0)
		ItemModule.ItemRarity.RARE:
			button.modulate = Color(0.5, 0.8, 1.5)
		ItemModule.ItemRarity.VERY_RARE:
			button.modulate = Color(1.5, 0.5, 1.5)
	
	# Connexion
	var item_id = item_info.get("id", "")
	button.pressed.connect(func(): _on_item_selected(item_id, item_info))
	
	return button

# ============================================================================
# SÉLECTION ET UTILISATION D'OBJET
# ============================================================================

func _on_item_selected(item_id: String, item_info: Dictionary) -> void:
	"""Quand un objet est sélectionné"""
	
	item_popup.hide()
	
	var target_type = item_info.get("target_type", "self")
	
	match target_type:
		"self":
			# Utilisation immédiate sur soi
			item_module.use_item(selected_unit, item_id, selected_unit)
			_close_all_menus()
			_deselect_unit()
		
		"ally_single":
			# Sélectionner un allié
			current_action_state = ActionState.SELECTING_ITEM_TARGET
			set_meta("pending_item_id", item_id)
			set_meta("pending_item_type", "ally_single")
			GameRoot.event_bus.notify("Sélectionnez un allié", "info")
		
		"enemy_single", "enemy_duo":
			# Sélectionner un ennemi
			current_action_state = ActionState.SELECTING_ITEM_TARGET
			set_meta("pending_item_id", item_id)
			set_meta("pending_item_type", target_type)
			GameRoot.event_bus.notify("Sélectionnez une cible ennemie", "info")
		
		"ally_single_position":
			# Sélectionner une position
			current_action_state = ActionState.SELECTING_ITEM_TARGET
			set_meta("pending_item_id", item_id)
			set_meta("pending_item_type", "position")
			
			# Highlight des cases accessibles
			var effect = item_info.get("effect", {})
			var range = effect.get("range", 5)
			var positions = _get_positions_in_range(selected_unit.grid_position, range)
			terrain_module.highlight_tiles(positions, MOVEMENT_COLOR)
			
			GameRoot.event_bus.notify("Sélectionnez une destination", "info")

func _on_item_menu_cancel() -> void:
	"""Annule la sélection d'objet"""
	item_popup.hide()
	_open_action_menu()
	
func _on_item_used(unit: BattleUnit3D, item_id: String, target: Variant) -> void:
	"""Callback quand un objet est utilisé"""
	GameRoot.global_logger.info("BATTLE", "%s utilise l'objet %s" % [unit.unit_name, item_id])

func _on_item_failed(unit: BattleUnit3D, item_id: String, reason: String) -> void:
	"""Callback quand l'utilisation d'un objet échoue"""
	GameRoot.event_bus.notify("❌ " + reason, "error")
	
func _get_positions_in_range(center: Vector2i, range: int) -> Array[Vector2i]:
	"""Retourne toutes les positions dans un rayon donné"""
	var positions: Array[Vector2i] = []
	
	for dy in range(-range, range + 1):
		for dx in range(-range, range + 1):
			var manhattan = abs(dx) + abs(dy)
			if manhattan <= range:
				var pos = center + Vector2i(dx, dy)
				if terrain_module.is_in_bounds(pos) and terrain_module.is_walkable(pos):
					positions.append(pos)
	
	return positions
