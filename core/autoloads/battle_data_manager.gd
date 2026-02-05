# scripts/core/battle_data_manager.gd
extends Node
## BattleDataManager - Gestionnaire centralisé des données de combat
## Autoload dédié au stockage et à la validation des données de bataille
## 
## Responsabilités :
## - Stocker les données du combat actuel
## - Valider la structure des données
## - Fournir un accès thread-safe
## - Nettoyer après usage
##
## Accès via : GameRoot.battle_data_manager

class_name BattleDataManagerClass

# ============================================================================
# SIGNAUX
# ============================================================================

signal battle_data_stored(battle_id: String)
signal battle_data_cleared()
signal battle_data_invalid(errors: Array)

# ============================================================================
# DONNÉES
# ============================================================================

var _current_battle_data: Dictionary = {}
var _is_data_valid: bool = false
var _battle_id: String = ""

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	# Attendre que GameRoot soit prêt
	call_deferred("_connect_signals")
	print("[BattleDataManager] ✅ Initialisé")

func _connect_signals() -> void:
	"""Connexion aux signaux de GameRoot"""
	await get_tree().process_frame
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.safe_connect("battle_ended", _on_battle_ended)

# ============================================================================
# STOCKAGE
# ============================================================================

## Stocke les données d'un combat
func set_battle_data(data: Dictionary) -> bool:
	"""
	Stocke les données de combat après validation
	
	@param data : Dictionnaire contenant les données de combat
	@return true si stockage réussi, false si données invalides
	"""
	
	var result = ModelValidator.validate(data, "battle")

	if not result.is_valid:
		if GameRoot and GameRoot.global_logger:
			GameRoot.global_logger.error("BATTLE_DATA", "Validation échouée : " + str(result.errors))
		push_error("[BattleDataManager] ❌ Données invalides : ", result.errors)
		battle_data_invalid.emit(result.errors)
		return false

	# 🔥 IMPORTANT : récupérer les données normalisées
	_current_battle_data = result.data.duplicate(true)
	_is_data_valid = true
	_battle_id = data.get("battle_id", "unknown_" + str(Time.get_unix_time_from_system()))
	
	print("[BattleDataManager] ✅ Données stockées : ", _battle_id)
	battle_data_stored.emit(_battle_id)
	
	return true

## Récupère les données du combat actuel
func get_battle_data() -> Dictionary:
	"""
	Retourne les données du combat actuel
	
	@return Dictionary avec les données, ou {} si aucune donnée valide
	"""
	
	if not _is_data_valid:
		push_warning("[BattleDataManager] ⚠️ Aucune donnée de combat valide")
		return {}
	
	print("[BattleDataManager] 📦 Récupération des données : ", _battle_id)
	return _current_battle_data.duplicate(true)

## Vérifie si des données sont disponibles
func has_battle_data() -> bool:
	"""Vérifie si des données de combat valides sont stockées"""
	return _is_data_valid and not _current_battle_data.is_empty()

## Récupère l'ID du combat actuel
func get_battle_id() -> String:
	"""Retourne l'ID du combat actuel"""
	return _battle_id

# ============================================================================
# NETTOYAGE
# ============================================================================

## Efface les données du combat actuel
func clear_battle_data() -> void:
	"""
	Nettoie les données de combat
	Appelé automatiquement après la bataille
	"""
	
	if _is_data_valid:
		print("[BattleDataManager] 🧹 Nettoyage des données : ", _battle_id)
	
	_current_battle_data.clear()
	_is_data_valid = false
	_battle_id = ""
	
	battle_data_cleared.emit()

## Efface les données de manière forcée (emergency)
func force_clear() -> void:
	"""Nettoyage forcé en cas d'erreur critique"""
	push_warning("[BattleDataManager] ⚠️ Nettoyage forcé des données")
	clear_battle_data()


# ============================================================================
# DEBUG
# ============================================================================

## Affiche les données actuelles (debug)
func debug_print_data() -> void:
	"""Affiche les données de combat pour debug"""
	
	if not _is_data_valid:
		print("[BattleDataManager] 🐛 Aucune donnée à afficher")
		return
	
	print("\n=== BattleDataManager DEBUG ===")
	print("Battle ID : ", _battle_id)
	print("Player Units : ", _current_battle_data.get("player_units", []).size())
	print("Enemy Units : ", _current_battle_data.get("enemy_units", []).size())
	print("Terrain : ", _current_battle_data.get("terrain", "N/A"))
	print("================================\n")

## Retourne les statistiques du combat actuel
func get_battle_stats() -> Dictionary:
	"""Retourne des statistiques sur le combat actuel"""
	
	if not _is_data_valid:
		return {}
	
	return {
		"battle_id": _battle_id,
		"player_unit_count": _current_battle_data.get("player_units", []).size(),
		"enemy_unit_count": _current_battle_data.get("enemy_units", []).size(),
		"has_objectives": _current_battle_data.has("objectives"),
		"has_scenario": _current_battle_data.has("scenario"),
		"terrain_type": _current_battle_data.get("terrain", "unknown")
	}

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_battle_ended(_results: Dictionary) -> void:
	"""Nettoyage automatique après la fin du combat"""
	clear_battle_data()

func _exit_tree() -> void:
	"""Nettoyage à la fermeture"""
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.disconnect_all(self)
	
func _normalize_battle_data(data: Dictionary) -> void:
	# Player units
	if data.has("player_units"):
		for unit in data.player_units:
			# HP → int
			unit.current_hp = int(unit.current_hp)
			unit.max_hp = int(unit.max_hp)

			# Position [x, y] → Vector2i
			if unit.has("position") and unit.position is Array and unit.position.size() == 2:
				unit.position = Vector2i(
					int(unit.position[0]),
					int(unit.position[1])
				)

	# Enemy units
	if data.has("enemy_units"):
		for unit in data.enemy_units:
			unit.current_hp = int(unit.current_hp)
			unit.max_hp = int(unit.max_hp)

			if unit.has("position") and unit.position is Array and unit.position.size() == 2:
				unit.position = Vector2i(
					int(unit.position[0]),
					int(unit.position[1])
				)

	# Obstacles
	if data.has("terrain_obstacles"):
		for obs in data.terrain_obstacles:
			if obs.has("position") and obs.position is Array and obs.position.size() == 2:
				obs.position = Vector2i(
					int(obs.position[0]),
					int(obs.position[1])
				)
