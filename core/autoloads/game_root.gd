extends Node
## GameRoot - Point d'entrée unique du jeu
## Scène autoload principale qui instancie et expose tous les systèmes globaux
##
## Configuration : Ajouter GameRoot.tscn comme autoload nommé "GameRoot"
## Accès : GameRoot.event_bus, GameRoot.scene_loader, etc.

class_name GameRootClass

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
var team_manager = null  # TeamManager n'a pas de class_name typé

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
	"team_manager": "res://core/autoloads/team_manager.gd"
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
	
	# Chercher le SceneContainer existant dans la scène
	scene_container = get_node_or_null("SceneContainer")
	
	if not scene_container:
		# Créer dynamiquement si non présent dans la scène
		scene_container = Node.new()
		scene_container.name = "SceneContainer"
		add_child(scene_container)
		print("[GameRoot]   → SceneContainer créé dynamiquement")
	else:
		print("[GameRoot]   → SceneContainer trouvé dans la scène")

func _initialize_core_systems() -> void:
	"""Initialise les systèmes de base (EventBus, Logger)"""
	
	# 1. Global Logger (en premier pour les logs)
	global_logger = _create_system("global_logger", "GlobalLogger") as GlobalLoggerClass
	
	# 2. Event Bus (communication globale)
	event_bus = _create_system("event_bus", "EventBus") as EventBusClass
	
	print("[GameRoot] ✅ Systèmes de base initialisés")

func _initialize_managers() -> void:
	"""Initialise les managers principaux"""
	
	# 3. Scene Loader
	scene_loader = _create_system("scene_loader", "SceneLoader") as SceneLoaderClass
	scene_loader.scene_container = scene_container
	
	# 4. Game Manager
	game_manager = _create_system("game_manager", "GameManager") as GameManagerClass
	game_manager.scene_loader = scene_loader
	
	# 5. Battle Data Manager
	battle_data_manager = _create_system("battle_data_manager", "BattleDataManager") as BattleDataManagerClass
	
	# 6. Dialogue Manager
	dialogue_manager = _create_system("dialogue_manager", "DialogueManager") as DialogueManagerClass
	
	# 7. Version Manager
	version_manager = _create_system("version_manager", "VersionManager") as VersionManagerClass
	
	# 8. Team Manager
	team_manager = _create_system("team_manager", "TeamManager")
	
	print("[GameRoot] ✅ Managers initialisés")

func _initialize_ui_systems() -> void:
	"""Initialise les systèmes UI (au-dessus des scènes)"""
	
	# 9. UI Manager (CanvasLayer pour UI globale)
	ui_manager = _create_system("ui_manager", "UIManager") as UIManagerClass
	
	# 10. Debug Overlay (en dernier, layer le plus haut) - seulement en debug
	if OS.is_debug_build():
		debug_overlay = _create_system("debug_overlay", "DebugOverlay") as DebugOverlayClass
	
	print("[GameRoot] ✅ Systèmes UI initialisés")

func _create_system(key: String, node_name: String) -> Node:
	"""Crée et ajoute un système depuis son script"""
	
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
	
	var instance = Node.new()
	instance.set_script(script)
	instance.name = node_name
	
	add_child(instance)
	
	print("[GameRoot]   → %s chargé" % node_name)
	return instance

func _connect_systems() -> void:
	"""Connecte les systèmes entre eux via l'EventBus"""
	
	if not event_bus:
		push_error("[GameRoot] EventBus non initialisé, impossible de connecter les systèmes")
		return
	
	# Connecter SceneLoader aux événements
	if scene_loader:
		event_bus.safe_connect("scene_change_requested", scene_loader._on_scene_change_requested)
	
	# Connecter GameManager aux événements
	if game_manager:
		event_bus.safe_connect("game_started", game_manager._on_game_started)
		event_bus.safe_connect("game_paused", game_manager._on_game_paused)
		event_bus.safe_connect("quit_game_requested", game_manager._on_quit_game_requested)
		event_bus.safe_connect("return_to_menu_requested", game_manager._on_return_to_menu_requested)
	
	# Connecter UIManager aux notifications
	if ui_manager:
		event_bus.safe_connect("notification_posted", ui_manager._on_notification_posted)
	
	print("[GameRoot] ✅ Systèmes connectés")

func _check_migrations() -> void:
	"""Vérifie et applique les migrations de données si nécessaire"""
	
	if version_manager:
		version_manager.check_and_migrate()

func _load_initial_scene() -> void:
	"""Charge la scène initiale (menu principal)"""
	
	if scene_loader:
		# Vérifier si le menu principal existe
		if SceneRegistry.scene_exists(SceneRegistry.SceneID.MAIN_MENU):
			scene_loader.load_scene_by_id(SceneRegistry.SceneID.MAIN_MENU, false)
		else:
			push_warning("[GameRoot] Menu principal non trouvé, aucune scène chargée")

# ============================================================================
# API PUBLIQUE (Raccourcis)
# ============================================================================

## Raccourci pour changer de scène
func change_scene(scene_id: int, transition: bool = true) -> void:
	if scene_loader:
		scene_loader.load_scene_by_id(scene_id, transition)

## Raccourci pour changer de scène par chemin
func change_scene_by_path(scene_path: String, transition: bool = true) -> void:
	if scene_loader:
		scene_loader.load_scene(scene_path, transition)

## Raccourci pour émettre une notification
func notify(message: String, type: String = "info") -> void:
	if event_bus:
		event_bus.notify(message, type)

## Raccourci pour logger
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
# GETTERS POUR COMPATIBILITÉ
# ============================================================================

func get_current_scene() -> Node:
	"""Retourne la scène actuellement chargée"""
	return current_scene

func get_current_scene_id() -> int:
	"""Retourne l'ID de la scène actuelle"""
	return scene_loader.current_scene_id if scene_loader else -1

func is_loading() -> bool:
	"""Vérifie si un chargement est en cours"""
	return scene_loader.is_loading if scene_loader else false

func is_initialized() -> bool:
	"""Vérifie si GameRoot est complètement initialisé"""
	return _is_initialized

# ============================================================================
# ACCÈS AUX SYSTÈMES (pour compatibilité avec l'ancien code)
# ============================================================================

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

# ============================================================================
# DEBUG
# ============================================================================

func _input(event: InputEvent) -> void:
	if OS.is_debug_build():
		# Toggle debug overlay avec F3
		if event.is_action_pressed("debug_toggle") and debug_overlay:
			debug_overlay.toggle_visibility()

func print_status() -> void:
	"""Affiche l'état de tous les systèmes"""
	
	print("\n=== GameRoot Status ===")
	print("  Initialized: ", _is_initialized)
	print("  EventBus: ", "OK" if event_bus else "NULL")
	print("  GlobalLogger: ", "OK" if global_logger else "NULL")
	print("  SceneLoader: ", "OK" if scene_loader else "NULL")
	print("  GameManager: ", "OK" if game_manager else "NULL")
	print("  UIManager: ", "OK" if ui_manager else "NULL")
	print("  BattleDataManager: ", "OK" if battle_data_manager else "NULL")
	print("  DialogueManager: ", "OK" if dialogue_manager else "NULL")
	print("  VersionManager: ", "OK" if version_manager else "NULL")
	print("  TeamManager: ", "OK" if team_manager else "NULL")
	print("  DebugOverlay: ", "OK" if debug_overlay else "N/A (release)")
	print("  SceneContainer: ", "OK" if scene_container else "NULL")
	print("  CurrentScene: ", current_scene.name if current_scene else "None")
	print("========================\n")

func debug_list_children() -> void:
	"""Liste tous les enfants de GameRoot (debug)"""
	
	print("\n=== GameRoot Children ===")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	print("=========================\n")
