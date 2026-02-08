extends Node
## BattleDataManager - Gestionnaire centralisé des données de combat
## Autoload dédié au stockage et à la validation des données de bataille
##
## Responsabilités :
## - Stocker les données du combat actuel
## - Valider la structure des données
## - Stocker les résultats du combat
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
	call_deferred("_connect_signals")
	print("[BattleDataManager] ✅ Initialisé")

func _connect_signals() -> void:
	await get_tree().process_frame

	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.safe_connect("battle_ended", _on_battle_ended)

# ============================================================================
# STOCKAGE DES DONNÉES DE COMBAT
# ============================================================================

func set_battle_data(data: Dictionary) -> bool:
	var result = ModelValidator.validate(data, "battle")

	if not result.is_valid:
		if GameRoot and GameRoot.global_logger:
			GameRoot.global_logger.error("BATTLE_DATA", "Validation échouée : " + str(result.errors))
		push_error("[BattleDataManager] ❌ Données invalides : ", result.errors)
		battle_data_invalid.emit(result.errors)
		return false

	_current_battle_data = GameRoot.data_normalizer.normalize_battle_data(result.data)
	_is_data_valid = true
	_battle_id = data.get("battle_id", "unknown_" + str(Time.get_unix_time_from_system()))

	print("[BattleDataManager] ✅ Données stockées : ", _battle_id)
	battle_data_stored.emit(_battle_id)

	return true

func get_battle_data() -> Dictionary:
	if not _is_data_valid:
		push_warning("[BattleDataManager] ⚠️ Aucune donnée de combat valide")
		return {}

	print("[BattleDataManager] 📦 Récupération des données : ", _battle_id)
	return _current_battle_data.duplicate(true)

func has_battle_data() -> bool:
	return _is_data_valid and not _current_battle_data.is_empty()

func get_battle_id() -> String:
	return _battle_id

# ============================================================================
# STOCKAGE DES RÉSULTATS DE COMBAT
# ============================================================================

func store_battle_results(results: Dictionary) -> void:
	"""
	Stocke les résultats du combat (victoire, xp, stats, etc.)
	Appelé par BattleMapManager3D avant la transition vers battle_results.
	"""
	if not _is_data_valid:
		push_warning("[BattleDataManager] ⚠️ Impossible de stocker les résultats : aucune donnée active")
		return

	_current_battle_data["results"] = results.duplicate(true)

	print("[BattleDataManager] 📝 Résultats enregistrés :", results)

# ============================================================================
# NETTOYAGE
# ============================================================================

func clear_battle_data() -> void:
	if _is_data_valid:
		print("[BattleDataManager] 🧹 Nettoyage des données : ", _battle_id)

	_current_battle_data.clear()
	_is_data_valid = false
	_battle_id = ""

	battle_data_cleared.emit()

func force_clear() -> void:
	push_warning("[BattleDataManager] ⚠️ Nettoyage forcé des données")
	clear_battle_data()

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_data() -> void:
	if not _is_data_valid:
		print("[BattleDataManager] 🐛 Aucune donnée à afficher")
		return

	print("\n=== BattleDataManager DEBUG ===")
	print("Battle ID : ", _battle_id)
	print("Player Units : ", _current_battle_data.get("player_units", []).size())
	print("Enemy Units : ", _current_battle_data.get("enemy_units", []).size())
	print("Terrain : ", _current_battle_data.get("terrain", "N/A"))
	print("Results : ", _current_battle_data.get("results", {}))
	print("================================\n")

func get_battle_stats() -> Dictionary:
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
	# ⚠️ NE PAS nettoyer ici si battle_results a besoin des données !
	# Tu peux commenter cette ligne si tu veux garder les données après la bataille.
	clear_battle_data()

func _exit_tree() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.disconnect_all(self)
