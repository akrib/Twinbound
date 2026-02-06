extends Node
## GameRoot - Point d'entrée unique du jeu
## Scène autoload principale qui instancie et expose tous les systèmes globaux
##
## Configuration : Ajouter GameRoot.tscn comme autoload nommé "GameRoot"
## Accès : GameRoot.event_bus, GameRoot.scene_loader, etc.

class_name GameRootClass


# === AUTOLOADS ===
const EventBusClass        = preload("res://core/autoloads/event_bus.gd")
const SceneLoaderClass     = preload("res://core/autoloads/scene_loader.gd")
const UIManagerClass       = preload("res://core/autoloads/ui_manager.gd")
const DialogueManagerClass = preload("res://core/autoloads/dialogue_manager.gd")
const TeamManagerClass     = preload("res://core/autoloads/team_manager.gd")
const BattleDataManagerClass = preload("res://core/autoloads/battle_data_manager.gd")
const CampaignManagerClass = preload("res://core/autoloads/campaign_manager.gd")
const GlobalLoggerClass    = preload("res://core/autoloads/global_logger.gd")
const VersionManagerClass  = preload("res://core/autoloads/version_manager.gd")
const GameManagerClass     = preload("res://core/autoloads/game_manager.gd")
const DebugOverlayClass    = preload("res://core/autoloads/debug_overlay.gd")

# === DATA / HELPERS ===
const SceneRegistry        = preload("res://core/data/scene_registry.gd")
const JSONDataLoader       = preload("res://core/data/json_data_loader.gd")
const ModelValidator       = preload("res://core/data/model_validator.gd")
const ValidationResult     = preload("res://core/data/validation_result.gd")
const AbilityDataLoader    = preload("res://core/data/ability_data_loader.gd")

# === DIALOGUE SYSTEM ===
const DialogueData         = preload("res://core/dialogue/dialogue_data.gd")
const DialogueDataLoader   = preload("res://core/dialogue/dialogue_data_loader.gd")
const DialogueBoxClass     = preload("res://core/dialogue/dialogue_box.gd")
const BarkSystem           = preload("res://core/dialogue/bark_system.gd")

# === FEATURES ===
const DebugVersionPanel    = preload("res://features/debug/debug_version_panel.gd")
#const MainMenuClass        = preload("res://features/menu/main_menu.gd")
const WorldMapClass        = preload("res://features/world_map/logic/world_map.gd")


# ============================================================================
# RÉFÉRENCES EXPOSÉES (accès via GameRoot.xxx)
# ============================================================================

var event_bus: EventBusClass = null
var scene_loader: SceneLoaderClass = null
var game_manager: GameManagerClass = null
var ui_manager: UIManagerClass = null
var debug_overlay: DebugOverlayClass = null
var global_logger: GlobalLoggerClass = null
var battle_data_manager: BattleDataManagerClass = null
var dialogue_manager: DialogueManagerClass = null
var version_manager: VersionManagerClass = null
var team_manager : TeamManagerClass = null  # TeamManager n'a pas de class_name typé
var dialogue_data : DialogueData = null
var campaign_manager: CampaignManagerClass = null
# ============================================================================
# CONTENEUR DE SCÈNES
# ============================================================================

var scene_container: Node = null
var current_scene: Node = null

# ============================================================================
# CONFIGURATION DES SCRIPTS
# ============================================================================

const SCRIPTS = {
	"event_bus": "res://core/autoloads/event_bus.gd",
	"global_logger": "res://core/autoloads/global_logger.gd",
	"scene_loader": "res://core/autoloads/scene_loader.gd",
	"game_manager": "res://core/autoloads/game_manager.gd",
	"ui_manager": "res://core/autoloads/ui_manager.gd",
	"debug_overlay": "res://core/autoloads/debug_overlay.gd",
	"battle_data_manager": "res://core/autoloads/battle_data_manager.gd",
	"dialogue_manager": "res://core/autoloads/dialogue_manager.gd",
	"version_manager": "res://core/autoloads/version_manager.gd",
	"team_manager": "res://core/autoloads/team_manager.gd",
	"dialogue_data": "res://core/dialogue/dialogue_data.gd",
	"campaign_manager": "res://core/autoloads/campaign_manager.gd"
}




# ============================================================================
# ÉTAT
# ============================================================================

var _is_initialized: bool = false

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	if _is_initialized:
		push_warning("[GameRoot] Déjà initialisé, skip")
		return
	
	name = "GameRoot"
	
	print("========================================")
	print("  GAME ROOT - Initialisation")
	print("========================================")
	
	# Ordre d'initialisation important !
	_setup_scene_container()
	_initialize_core_systems()
	_initialize_managers()
	_initialize_ui_systems()
	_connect_systems()
	_check_migrations()
	
	_is_initialized = true
	
	print("========================================")
	print("  GAME ROOT - Prêt !")
	print("========================================")
	
	# Charger la scène initiale
	call_deferred("_load_initial_scene")

func _setup_scene_container() -> void:
	"""Configure le conteneur de scènes (créé dans la .tscn ou dynamiquement)"""
	scene_container = get_node_or_null("SceneContainer")
	
	if not scene_container:
		scene_container = Node.new()
		scene_container.name = "SceneContainer"
		add_child(scene_container)
		print("[GameRoot]   → SceneContainer créé dynamiquement")
	else:
		print("[GameRoot]   → SceneContainer trouvé dans la scène")

func _initialize_core_systems() -> void:
	"""Initialise les systèmes de base (EventBus, Logger)"""
	global_logger = _create_system("global_logger", "GlobalLogger") as GlobalLoggerClass
	event_bus = _create_system("event_bus", "EventBus") as EventBusClass
	print("[GameRoot] ✅ Systèmes de base initialisés")

func _initialize_managers() -> void:
	"""Initialise les managers principaux"""
	
	# SceneLoader
	scene_loader = _create_system("scene_loader", "SceneLoader") as SceneLoaderClass
	scene_loader.scene_container = scene_container
	
	# GameManager
	game_manager = _create_system("game_manager", "GameManager") as GameManagerClass
	game_manager.scene_loader = scene_loader
	
	# BattleDataManager
	battle_data_manager = _create_system("battle_data_manager", "BattleDataManager") as BattleDataManagerClass
	
	# DialogueManager
	dialogue_manager = _create_system("dialogue_manager", "DialogueManager") as DialogueManagerClass
	
	# VersionManager
	version_manager = _create_system("version_manager", "VersionManager") as VersionManagerClass
	
	# TeamManager
	team_manager = _create_system("team_manager", "TeamManager")
	
	# CampaignManager (après les autres car il les utilise)
	campaign_manager = _create_system("campaign_manager", "CampaignManager") as CampaignManagerClass
	
	print("[GameRoot] ✅ Managers initialisés")

func _initialize_ui_systems() -> void:
	"""Initialise les systèmes UI (au-dessus des scènes)"""
	ui_manager = _create_system("ui_manager", "UIManager") as UIManagerClass
	
	if OS.is_debug_build():
		debug_overlay = _create_system("debug_overlay", "DebugOverlay") as DebugOverlayClass
	
	# Connecter DialogueManager à la DialogueBox persistante de UIManager
	if dialogue_manager and ui_manager:
		GameRoot.dialogue_manager.set_persistent_dialogue_box(ui_manager.get_dialogue_box())
	
	print("[GameRoot] ✅ Systèmes UI initialisés")

func _create_system(key: String, node_name: String) -> Node:
	"""Crée et ajoute un système depuis son script."""
	var script_path = SCRIPTS.get(key, "")
	
	if script_path == "":
		push_error("[GameRoot] Clé de script introuvable : %s" % key)
		return null
	
	if not ResourceLoader.exists(script_path):
		push_error("[GameRoot] Script introuvable : %s" % script_path)
		return null
	
	var script = load(script_path)
	if not script:
		push_error("[GameRoot] Échec du chargement du script : %s" % script_path)
		return null
	
	var base_type: String = script.get_instance_base_type()
	var instance: Node
	
	match base_type:
		"CanvasLayer":
			instance = CanvasLayer.new()
		"Control":
			instance = Control.new()
		"Node2D":
			instance = Node2D.new()
		"Node3D":
			instance = Node3D.new()
		_:
			instance = Node.new()
	
	instance.set_script(script)
	instance.name = node_name
	add_child(instance)
	
	print("[GameRoot]   → %s chargé (%s)" % [node_name, base_type])
	return instance

func _connect_systems() -> void:
	"""Connecte les systèmes entre eux via l'EventBus"""
	if not event_bus:
		push_error("[GameRoot] EventBus non initialisé")
		return
	
	# SceneLoader
	if scene_loader:
		event_bus.safe_connect("scene_change_requested", scene_loader._on_scene_change_requested)
	
	# GameManager
	if game_manager:
		event_bus.safe_connect("game_started", game_manager._on_game_started)
		event_bus.safe_connect("game_paused", game_manager._on_game_paused)
		event_bus.safe_connect("quit_game_requested", game_manager._on_quit_game_requested)
		event_bus.safe_connect("return_to_menu_requested", game_manager._on_return_to_menu_requested)
	
	# UIManager
	if ui_manager:
		event_bus.safe_connect("notification_posted", ui_manager._on_notification_posted)
	
	# CampaignManager
	if campaign_manager:
		event_bus.safe_connect("game_started", campaign_manager._on_game_started)
		event_bus.safe_connect("battle_ended", campaign_manager._on_battle_ended)
	
	print("[GameRoot] ✅ Systèmes connectés")

func _check_migrations() -> void:
	if version_manager:
		version_manager.check_and_migrate()

func _load_initial_scene() -> void:
	"""Charge la scène initiale (menu principal)"""
	if scene_loader:
		if SceneRegistry.scene_exists(SceneRegistry.SceneID.MAIN_MENU):
			scene_loader.load_scene_by_id(SceneRegistry.SceneID.MAIN_MENU, false)
		else:
			push_warning("[GameRoot] Menu principal non trouvé")

# ============================================================================
# CALLBACKS SCÈNE
# ============================================================================

func _on_scene_loaded(scene: Node) -> void:
	current_scene = scene
	if global_logger:
		global_logger.info("SCENE", "Scène chargée : %s" % scene.name)

func _on_scene_unloaded() -> void:
	current_scene = null

# ============================================================================
# API PUBLIQUE
# ============================================================================

func change_scene(scene_id: int, transition: bool = true) -> void:
	if scene_loader:
		scene_loader.load_scene_by_id(scene_id, transition)

func change_scene_by_path(scene_path: String, transition: bool = true) -> void:
	if scene_loader:
		scene_loader.load_scene(scene_path, transition)

func notify(message: String, type: String = "info") -> void:
	if event_bus:
		event_bus.notify(message, type)

func log_info(category: String, message: String) -> void:
	if global_logger:
		global_logger.info(category, message)

func log_debug(category: String, message: String) -> void:
	if global_logger:
		global_logger.debug(category, message)

func log_warning(category: String, message: String) -> void:
	if global_logger:
		global_logger.warning(category, message)

func log_error(category: String, message: String) -> void:
	if global_logger:
		global_logger.error(category, message)

# ============================================================================
# GETTERS
# ============================================================================

func get_current_scene() -> Node:
	return current_scene

func get_current_scene_id() -> int:
	return scene_loader.current_scene_id if scene_loader else -1

func is_loading() -> bool:
	return scene_loader.is_loading if scene_loader else false

func is_initialized() -> bool:
	return _is_initialized

func get_event_bus() -> EventBusClass:
	return event_bus

func get_scene_loader() -> SceneLoaderClass:
	return scene_loader

func get_game_manager() -> GameManagerClass:
	return game_manager

func get_ui_manager() -> UIManagerClass:
	return ui_manager

func get_global_logger() -> GlobalLoggerClass:
	return global_logger

func get_battle_data_manager() -> BattleDataManagerClass:
	return battle_data_manager

func get_dialogue_manager() -> DialogueManagerClass:
	return dialogue_manager

func get_campaign_manager() -> CampaignManagerClass:
	return campaign_manager

# ============================================================================
# DEBUG
# ============================================================================

func _input(event: InputEvent) -> void:
	if OS.is_debug_build():
		if event.is_action_pressed("debug_toggle") and debug_overlay:
			debug_overlay.toggle_visibility()

func print_status() -> void:
	print("\n=== GameRoot Status ===")
	print("  Initialized: ", _is_initialized)
	print("  EventBus: ", "OK" if event_bus else "NULL")
	print("  GlobalLogger: ", "OK" if global_logger else "NULL")
	print("  SceneLoader: ", "OK" if scene_loader else "NULL")
	print("  GameManager: ", "OK" if game_manager else "NULL")
	print("  UIManager: ", "OK" if ui_manager else "NULL")
	print("  BattleDataManager: ", "OK" if battle_data_manager else "NULL")
	print("  DialogueManager: ", "OK" if dialogue_manager else "NULL")
	print("  CampaignManager: ", "OK" if campaign_manager else "NULL")
	print("  VersionManager: ", "OK" if version_manager else "NULL")
	print("  TeamManager: ", "OK" if team_manager else "NULL")
	print("  DebugOverlay: ", "OK" if debug_overlay else "N/A (release)")
	print("  SceneContainer: ", "OK" if scene_container else "NULL")
	print("  CurrentScene: ", current_scene.name if current_scene else "None")
	print("========================\n")
