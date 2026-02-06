extends Node
## GameManager - Orchestration du cycle de vie du jeu
## Gère l'état du jeu, les sauvegardes, la pause
##
## Le démarrage de nouvelle partie est délégué à CampaignManager
## (qui gère la séquence d'intro via DialogueManager + UIManager)
##
## Accès via : GameRoot.game_manager

class_name GameManagerClass

# ============================================================================
# RÉFÉRENCES (assignées par GameRoot)
# ============================================================================

var scene_loader: SceneLoaderClass = null

# ============================================================================
# ÉTAT DU JEU
# ============================================================================

var game_state: Dictionary = {}
var is_paused: bool = false

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	print("[GameManager] ✅ Initialisé")

# ============================================================================
# GESTION DE LA PAUSE
# ============================================================================

func pause_game(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.game_paused.emit(paused)
	
	print("[GameManager] Jeu %s" % ("en pause" if paused else "repris"))

func toggle_pause() -> void:
	pause_game(not is_paused)

# ============================================================================
# SAUVEGARDE / CHARGEMENT
# ============================================================================

func save_game(save_name: String) -> void:
	game_state["timestamp"] = Time.get_unix_time_from_system()
	game_state["scene_id"] = scene_loader.current_scene_id if scene_loader else -1
	
	# Sauvegarder l'état de la campagne
	if GameRoot and GameRoot.campaign_manager:
		game_state["campaign"] = GameRoot.campaign_manager.get_campaign_state()
	
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	
	var save_path = "user://saves/%s.save" % save_name
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		file.store_string(JSON.stringify(game_state, "\t"))
		file.close()
		
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.game_saved.emit(save_name)
			GameRoot.event_bus.notify("Partie sauvegardée : %s" % save_name, "success")
		
		print("[GameManager] 💾 Sauvegarde : %s" % save_name)
	else:
		push_error("[GameManager] Impossible de sauvegarder")

func load_game(save_name: String) -> void:
	var save_path = "user://saves/%s.save" % save_name
	
	if not FileAccess.file_exists(save_path):
		push_error("[GameManager] Sauvegarde introuvable : %s" % save_name)
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		game_state = json.data
		
		var saved_scene_id = game_state.get("scene_id", -1)
		if saved_scene_id != -1 and scene_loader:
			scene_loader.load_scene_by_id(saved_scene_id)
		
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.game_loaded.emit(save_name)
			GameRoot.event_bus.notify("Partie chargée : %s" % save_name, "success")
		
		print("[GameManager] 📂 Chargement : %s" % save_name)
	else:
		push_error("[GameManager] Erreur lors du chargement de la sauvegarde")

func has_save(save_name: String) -> bool:
	return FileAccess.file_exists("user://saves/%s.save" % save_name)

func get_save_list() -> Array[String]:
	var saves: Array[String] = []
	var save_dir = "user://saves/"
	
	if not DirAccess.dir_exists_absolute(save_dir):
		return saves
	
	var dir = DirAccess.open(save_dir)
	dir.list_dir_begin()
	
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".save"):
			saves.append(file_name.get_basename())
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return saves

# ============================================================================
# CALLBACKS EVENTBUS
# ============================================================================

func _on_game_started() -> void:
	"""Callback quand une nouvelle partie démarre.
	La séquence d'intro est entièrement gérée par CampaignManager
	(qui utilise DialogueManager + UIManager pour les dialogues et l'UI)."""
	
	print("[GameManager] 🎮 Nouvelle partie démarrée")
	
	# CampaignManager reçoit aussi game_started et gère la séquence d'intro
	# Pas besoin de charger une scène intro ici - CampaignManager s'en occupe

func _on_game_paused(paused: bool) -> void:
	if paused != is_paused:
		is_paused = paused
		get_tree().paused = paused
	print("[GameManager] %s" % ("⏸️ Pause" if paused else "▶️ Reprise"))

func _on_quit_game_requested() -> void:
	print("[GameManager] 🚪 Fermeture du jeu...")
	get_tree().quit()

func _on_return_to_menu_requested() -> void:
	print("[GameManager] 🏠 Retour au menu principal")
	
	is_paused = false
	get_tree().paused = false
	
	if scene_loader:
		scene_loader.load_scene_by_id(SceneRegistry.SceneID.MAIN_MENU)

# ============================================================================
# GETTERS
# ============================================================================

func get_current_scene() -> Node:
	return scene_loader.current_scene if scene_loader else null

func get_current_scene_id() -> int:
	return scene_loader.current_scene_id if scene_loader else -1

func is_loading() -> bool:
	return scene_loader.is_loading if scene_loader else false

# ============================================================================
# DEBUG
# ============================================================================

func _input(event: InputEvent) -> void:
	if OS.is_debug_build():
		if event.is_action_pressed("ui_end"):
			print_status()

func print_status() -> void:
	print("\n=== GameManager Status ===")
	print("  Scène : %s" % (SceneRegistry.get_scene_name(get_current_scene_id()) if get_current_scene_id() != -1 else "N/A"))
	print("  Pause : %s" % is_paused)
	print("  Loading : %s" % is_loading())
	print("===========================\n")
