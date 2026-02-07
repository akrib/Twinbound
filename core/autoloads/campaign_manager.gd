extends Node
## CampaignManager - Gestion de la campagne et séquences narratives
## Autoload qui orchestre la progression, les combats et les séquences d'intro
##
## Absorbe la logique de IntroDialogue (séquences de démarrage)
## Les dialogues sont délégués à DialogueManager
## L'UI (DialogueBox) est gérée par UIManager (persistante)
##
## Accès via : GameRoot.campaign_manager

class_name CampaignManagerClass

# ============================================================================
# SIGNAUX
# ============================================================================

signal campaign_sequence_started(sequence_id: String)
signal campaign_sequence_ended(sequence_id: String)
signal battle_requested(battle_id: String)

# ============================================================================
# CONFIGURATION
# ============================================================================
#const DialogueData = preload("res://core/dialogue/dialogue_data.gd")
const BATTLE_DATA_PATHS: Dictionary = {
	"tutorial": "res://data/battles/tutorial.json",
	"forest_battle": "res://data/battles/forest_battle.json",
	"village_defense": "res://data/battles/village_defense.json",
	"boss_fight": "res://data/battles/boss_fight.json"
}

const CAMPAIGN_START_PATH: String = "res://data/campaign/campaign_start.json"

# ============================================================================
# ÉTAT
# ============================================================================

var campaign_state: Dictionary = {
	"current_chapter": 1,
	"current_battle": 1,
	"battles_won": 0
}

var campaign_start_data: Dictionary = {}
var current_sequence_index: int = 0
var is_sequence_running: bool = false

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	print("[CampaignManager] ✅ Initialisé (mode JSON)")

# ============================================================================
# CALLBACKS EVENTBUS (connectés par GameRoot)
# ============================================================================

func _on_game_started() -> void:
	"""Appelé quand le joueur lance 'Nouvelle Partie'"""
	print("[CampaignManager] 🎮 Nouvelle partie - démarrage campagne")
	start_new_campaign()

func _on_battle_ended(results: Dictionary) -> void:
	"""Appelé à la fin d'un combat"""
	print("[CampaignManager] Combat terminé")
	
	if results.get("victory", false):
		campaign_state.battles_won += 1
		_advance_campaign()

# ============================================================================
# DÉMARRAGE DE CAMPAGNE
# ============================================================================

func start_new_campaign() -> void:
	"""Démarre une nouvelle campagne avec la séquence d'intro"""
	print("[CampaignManager] 🎬 Démarrage nouvelle campagne")
	
	# Charger les données de campagne
	campaign_start_data = _load_campaign_start_from_json()
	
	if campaign_start_data.is_empty():
		push_warning("[CampaignManager] Pas de campaign_start.json, fallback direct")
		_fallback_to_world_map()
		return
	
	# Initialiser l'état de la campagne
	if campaign_start_data.has("initial_state"):
		var initial_state = campaign_start_data.initial_state
		campaign_state.current_chapter = initial_state.get("chapter", 1)
		campaign_state.current_battle = initial_state.get("battle_index", 0)
		campaign_state.battles_won = initial_state.get("battles_won", 0)
	
	# Émettre l'événement
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.campaign_started.emit()
	
	# Exécuter la séquence de démarrage
	if campaign_start_data.has("start_sequence"):
		await _execute_start_sequence()
	else:
		push_warning("[CampaignManager] Pas de start_sequence, fallback")
		_fallback_to_world_map()

# ============================================================================
# EXÉCUTION DE SÉQUENCES (ex-IntroDialogue)
# ============================================================================

func _execute_start_sequence() -> void:
	"""Exécute la séquence de démarrage définie dans le JSON"""
	
	var sequence = campaign_start_data.start_sequence
	current_sequence_index = 0
	is_sequence_running = true
	
	campaign_sequence_started.emit("campaign_start")
	print("[CampaignManager] 🎬 Début de la séquence (", sequence.size(), " étapes)")
	
	await _execute_next_step()
	
	is_sequence_running = false
	campaign_sequence_ended.emit("campaign_start")

func _execute_next_step() -> void:
	"""Exécute l'étape suivante de la séquence"""
	
	var sequence = campaign_start_data.start_sequence
	
	if current_sequence_index >= sequence.size():
		print("[CampaignManager] ✅ Séquence terminée")
		return
	
	var step = sequence[current_sequence_index]
	var step_type = step.get("type", "")
	
	print("[CampaignManager] 📋 Étape %d/%d : %s" % [
		current_sequence_index + 1, sequence.size(), step_type
	])
	
	match step_type:
		"dialogue":
			await _execute_dialogue_step(step)
		"transition":
			await _execute_transition_step(step)
		"notification":
			_execute_notification_step(step)
		"unlock_location":
			_execute_unlock_location_step(step)
		_:
			push_warning("[CampaignManager] Type d'étape inconnu : %s" % step_type)
	
	current_sequence_index += 1
	await _execute_next_step()

func _execute_dialogue_step(step: Dictionary) -> void:
	"""Exécute une étape de dialogue via DialogueManager + UIManager"""
	
	var dialogue_id = step.get("dialogue_id", "")
	var blocking = step.get("blocking", true)
	
	if dialogue_id == "":
		push_warning("[CampaignManager] dialogue_id vide")
		return
	
	print("[CampaignManager] 💬 Dialogue : %s" % dialogue_id)
	
	# Charger les données du dialogue
	var dialogue_loader = DialogueDataLoader.new()
	var dialogue_data_dict = dialogue_loader.load_dialogue(dialogue_id)
	
	if dialogue_data_dict.is_empty():
		push_error("[CampaignManager] Dialogue introuvable : %s" % dialogue_id)
		return
	
	# Convertir en DialogueData
	var dialogue_data = _convert_to_dialogue_data(dialogue_data_dict)
	
	# Démarrer via DialogueManager (utilise la DialogueBox persistante de UIManager)
	if GameRoot and GameRoot.dialogue_manager:
		GameRoot.dialogue_manager.start_dialogue(dialogue_data)
		
		# Attendre la fin si bloquant
		if blocking:
			await GameRoot.dialogue_manager.dialogue_ended
			print("[CampaignManager] ✅ Dialogue terminé")

func _execute_transition_step(step: Dictionary) -> void:
	"""Exécute une transition vers une autre scène et ATTEND qu'elle soit chargée"""
	
	var target = step.get("target", "")
	
	print("[CampaignManager] 🎞️ Transition vers : %s" % target)
	
	var scene_map = {
		"world_map": SceneRegistry.SceneID.WORLD_MAP,
		"battle": SceneRegistry.SceneID.BATTLE,
		"main_menu": SceneRegistry.SceneID.MAIN_MENU,
		"cutscene": SceneRegistry.SceneID.CUTSCENE
	}
	
	if not scene_map.has(target):
		push_error("[CampaignManager] Cible de transition inconnue : %s" % target)
		return
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.change_scene(scene_map[target])
	
	# ← CRUCIAL : attendre que la scène soit effectivement chargée
	if GameRoot and GameRoot.scene_loader:
		await GameRoot.scene_loader.scene_transition_finished
	
	print("[CampaignManager] ✅ Transition terminée vers : %s" % target)

func _execute_notification_step(step: Dictionary) -> void:
	"""Affiche une notification"""
	var message = step.get("message", "")
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify(message, "info")

func _execute_unlock_location_step(step: Dictionary) -> void:
	"""Déverrouille une location sur la world map"""
	var location = step.get("location", "")
	print("[CampaignManager] 🔓 Déverrouillage : %s" % location)
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.location_discovered.emit(location)

# ============================================================================
# LANCEMENT DE COMBAT
# ============================================================================

func start_battle(battle_id: String) -> void:
	"""Charge et lance un combat depuis son ID"""
	print("[CampaignManager] 🎯 Chargement du combat : %s" % battle_id)
	
	var battle_data = load_battle_data_from_json(battle_id)
	
	if battle_data.is_empty():
		push_error("[CampaignManager] Impossible de charger : %s" % battle_id)
		return
	
	# Merger avec la team du joueur
	battle_data = _merge_player_team(battle_data)
	
	# Ajouter un ID unique
	battle_data["battle_id"] = battle_id + "_" + str(Time.get_unix_time_from_system())
	
	# Stocker dans BattleDataManager
	if not GameRoot or not GameRoot.battle_data_manager:
		push_error("[CampaignManager] BattleDataManager non disponible")
		return
	
	var stored = GameRoot.battle_data_manager.set_battle_data(battle_data)
	
	if stored:
		print("[CampaignManager] ✅ Données de combat stockées")
		GameRoot.event_bus.change_scene(SceneRegistry.SceneID.BATTLE)
	else:
		push_error("[CampaignManager] ❌ Échec du stockage des données")

func load_battle_data_from_json(battle_id: String) -> Dictionary:
	"""Charge un fichier JSON de données de combat"""
	
	# Essayer le chemin depuis BATTLE_DATA_PATHS
	var json_path = BATTLE_DATA_PATHS.get(battle_id, "")
	
	# Sinon essayer le chemin générique
	if json_path == "":
		json_path = "res://data/battles/%s.json" % battle_id
	
	if not FileAccess.file_exists(json_path):
		push_error("[CampaignManager] Fichier de combat introuvable : %s" % json_path)
		return {}
	
	var json_loader = JSONDataLoader.new()
	var battle_data = json_loader.load_json_file(json_path)
	
	if typeof(battle_data) != TYPE_DICTIONARY or battle_data.is_empty():
		push_error("[CampaignManager] Données invalides : %s" % battle_id)
		return {}
	
	# Convertir les positions JSON
	battle_data = _convert_json_positions(battle_data)
	
	print("[CampaignManager] ✅ Battle data chargée : %s" % battle_id)
	return battle_data

# ============================================================================
# MERGE TEAM JOUEUR
# ============================================================================

func _merge_player_team(battle_data: Dictionary) -> Dictionary:
	"""Fusionne l'équipe du joueur avec les alliés du scénario"""
	
	var result = battle_data.duplicate(true)
	
	if not GameRoot or not GameRoot.team_manager:
		return result
	
	var team = GameRoot.team_manager.get_current_team()
	var team_units: Array = []
	
	for i in range(team.size()):
		var unit = team[i]
		var battle_unit = _convert_team_unit_to_battle(unit, i)
		team_units.append(battle_unit)
	
	# Décaler les alliés du scénario
	if result.has("player_units"):
		for ally in result.player_units:
			if ally.has("position"):
				ally.position.x += 2
	else:
		result["player_units"] = []
	
	# Ajouter la team au début
	for unit in team_units:
		result.player_units.insert(0, unit)
	
	print("[CampaignManager] ✅ Team mergée : %d + %d alliés" % [
		team_units.size(), result.player_units.size() - team_units.size()
	])
	
	return result

func _convert_team_unit_to_battle(unit: Dictionary, index: int) -> Dictionary:
	return {
		"id": unit.get("instance_id", unit.get("id")),
		"name": unit.get("name"),
		"position": Vector2i(2, 6 + index),
		"stats": unit.get("stats", {}).duplicate(),
		"abilities": unit.get("abilities", []).duplicate(),
		"color": unit.get("color", {"r": 0.5, "g": 0.5, "b": 0.8, "a": 1.0}),
		"level": unit.get("level", 1),
		"xp": unit.get("xp", 0),
		"current_hp": unit.get("current_hp", unit.get("stats", {}).get("hp", 100))
	}

# ============================================================================
# CONVERSIONS JSON
# ============================================================================

func _convert_json_positions(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	
	for key in ["player_units", "enemy_units"]:
		if result.has(key):
			for unit in result[key]:
				if unit.has("position"):
					var pos = unit.position
					if pos is Array and pos.size() == 2:
						unit.position = Vector2i(int(pos[0]), int(pos[1]))
					elif pos is Dictionary:
						unit.position = Vector2i(pos.get("x", 0), pos.get("y", 0))
	
	if result.has("terrain_obstacles"):
		for obs in result.terrain_obstacles:
			if obs.has("position"):
				var pos = obs.position
				if pos is Array and pos.size() == 2:
					obs.position = Vector2i(int(pos[0]), int(pos[1]))
				elif pos is Dictionary:
					obs.position = Vector2i(pos.get("x", 0), pos.get("y", 0))
	
	if result.has("grid_size") and result["grid_size"] is Dictionary:
		var grid = result["grid_size"]
		if grid.has("width") and grid.has("height"):
			result["grid_size"] = Vector2i(int(grid["width"]), int(grid["height"]))
	
	return result

func _convert_to_dialogue_data(data_dict: Dictionary) -> DialogueData:
	"""Convertit un dictionnaire JSON en DialogueData"""
	
	var dialogue = DialogueData.new(data_dict.get("id", ""))
	
	# Traiter les séquences
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
	
	# Traiter les lignes directes
	if data_dict.has("lines"):
		for line in data_dict.lines:
			dialogue.add_line(line)
	
	return dialogue

# ============================================================================
# CHARGEMENT JSON
# ============================================================================

func _load_campaign_start_from_json() -> Dictionary:
	if not FileAccess.file_exists(CAMPAIGN_START_PATH):
		push_warning("[CampaignManager] Fichier introuvable : %s" % CAMPAIGN_START_PATH)
		return {}
	
	var json_loader = JSONDataLoader.new()
	var data = json_loader.load_json_file(CAMPAIGN_START_PATH)
	
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		push_error("[CampaignManager] Format invalide pour campaign_start.json")
		return {}
	
	return data

# ============================================================================
# PROGRESSION
# ============================================================================

func _advance_campaign() -> void:
	campaign_state.current_battle += 1
	# TODO: Logique de progression (chapitres, etc.)

func get_campaign_state() -> Dictionary:
	return campaign_state.duplicate()

# ============================================================================
# FALLBACK
# ============================================================================

func _fallback_to_world_map() -> void:
	"""En cas d'erreur, aller directement à la world map"""
	print("[CampaignManager] ⚠️ Fallback vers World Map")
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Bienvenue dans le jeu !", "info")
	
	await get_tree().create_timer(1.0).timeout
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.change_scene(SceneRegistry.SceneID.WORLD_MAP)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.disconnect_all(self)
