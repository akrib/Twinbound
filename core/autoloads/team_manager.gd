extends Node
## TeamManager - Gestion de l'équipe du joueur
## Autoload pour gérer le roster, le recrutement, l'XP
##
## Accès via : GameRoot.team_manager

signal team_changed()
signal unit_recruited(unit_id: String)
signal unit_dismissed(unit_id: String)
signal unit_leveled_up(unit_id: String, new_level: int)

# ============================================================================
# CONFIGURATION
# ============================================================================

const MAX_TEAM_SIZE: int = 8
const TEAM_SAVE_PATH: String = "user://team_data.json"
const AVAILABLE_UNITS_PATH: String = "res://data/team/available_units.json"

# ============================================================================
# DONNÉES
# ============================================================================

var current_team: Array[Dictionary] = []  # Équipe active (max 4 en combat)
var roster: Array[Dictionary] = []  # Toutes les unités recrutées
var available_units: Dictionary = {}  # Unités recrutables

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_load_available_units()
	_load_team_from_save()
	print("[TeamManager] ✅ Initialisé - Équipe : ", current_team.size(), " / Roster : ", roster.size())

func _load_available_units() -> void:
	if not FileAccess.file_exists(AVAILABLE_UNITS_PATH):
		push_warning("[TeamManager] Fichier d'unités disponibles non trouvé")
		return
	
	var file = FileAccess.open(AVAILABLE_UNITS_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		available_units = json.data
	else:
		push_warning("[TeamManager] Erreur de parsing des unités disponibles")

# ============================================================================
# GESTION DE L'ÉQUIPE
# ============================================================================

func add_to_team(unit_data: Dictionary) -> bool:
	"""Ajoute une unité à l'équipe active"""
	
	if current_team.size() >= 4:
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.notify("Équipe complète (max 4 en combat)", "warning")
		return false
	
	current_team.append(unit_data)
	team_changed.emit()
	_save_team()
	
	print("[TeamManager] ✅ Ajouté : ", unit_data.get("name"))
	return true

func remove_from_team(unit_id: String) -> bool:
	"""Retire une unité de l'équipe active"""
	
	for i in range(current_team.size()):
		if current_team[i].get("id") == unit_id:
			current_team.remove_at(i)
			team_changed.emit()
			_save_team()
			return true
	
	return false

func recruit_unit(unit_id: String) -> bool:
	"""Recrute une unité (l'ajoute au roster)"""
	
	if roster.size() >= MAX_TEAM_SIZE:
		if GameRoot and GameRoot.event_bus:
			GameRoot.event_bus.notify("Roster complet (max " + str(MAX_TEAM_SIZE) + ")", "warning")
		return false
	
	# Vérifier si déjà recrutée
	for unit in roster:
		if unit.get("id") == unit_id:
			if GameRoot and GameRoot.event_bus:
				GameRoot.event_bus.notify("Unité déjà recrutée", "warning")
			return false
	
	# Créer l'instance depuis les données disponibles
	if not available_units.has(unit_id):
		push_error("[TeamManager] Unité introuvable : ", unit_id)
		return false
	
	var unit_template = available_units[unit_id]
	var new_unit = _create_unit_instance(unit_template)
	
	roster.append(new_unit)
	unit_recruited.emit(unit_id)
	_save_team()
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Recruté : " + new_unit.get("name"), "success")
	return true

func _create_unit_instance(template: Dictionary) -> Dictionary:
	"""Crée une instance d'unité depuis un template"""
	
	var instance = template.duplicate(true)
	instance["instance_id"] = str(Time.get_ticks_msec())  # ID unique
	instance["level"] = 1
	instance["xp"] = 0
	instance["current_hp"] = instance.get("stats", {}).get("hp", 100)
	
	return instance

# ============================================================================
# GETTERS
# ============================================================================

func get_current_team() -> Array[Dictionary]:
	return current_team.duplicate()

func get_roster() -> Array[Dictionary]:
	return roster.duplicate()

func get_unit_by_id(unit_id: String) -> Dictionary:
	for unit in roster:
		if unit.get("id") == unit_id:
			return unit
	return {}

func is_team_full() -> bool:
	return current_team.size() >= 4

# ============================================================================
# XP & LEVEL UP
# ============================================================================

func add_xp(unit_id: String, xp_amount: int) -> void:
	"""Ajoute de l'XP à une unité"""
	
	var unit = get_unit_by_id(unit_id)
	
	if unit.is_empty():
		return
	
	unit.xp += xp_amount
	
	# Check level up
	var xp_needed = _calculate_xp_for_level(unit.level + 1)
	
	if unit.xp >= xp_needed:
		_level_up(unit)

func _level_up(unit: Dictionary) -> void:
	"""Level up d'une unité"""
	
	unit.level += 1
	unit.xp = 0  # Reset XP
	
	# Augmenter les stats (exemple simple)
	var stats = unit.get("stats", {})
	stats.hp = int(stats.get("hp", 100) * 1.1)
	stats.attack = int(stats.get("attack", 20) * 1.1)
	stats.defense = int(stats.get("defense", 10) * 1.1)
	
	unit_leveled_up.emit(unit.get("id"), unit.level)
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify(unit.get("name") + " atteint le niveau " + str(unit.level) + " !", "success")
	
	_save_team()

func _calculate_xp_for_level(level: int) -> int:
	"""Calcul XP nécessaire pour un niveau"""
	return 100 * level  # Formule simple

# ============================================================================
# SAUVEGARDE / CHARGEMENT
# ============================================================================

func _save_team() -> void:
	"""Sauvegarde l'équipe"""
	
	var save_data = {
		"current_team": current_team,
		"roster": roster,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(TEAM_SAVE_PATH, FileAccess.WRITE)
	
	if not file:
		push_error("[TeamManager] Impossible de sauvegarder")
		return
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	print("[TeamManager] 💾 Équipe sauvegardée")

func _load_team_from_save() -> void:
	"""Charge l'équipe depuis la sauvegarde"""
	
	if not FileAccess.file_exists(TEAM_SAVE_PATH):
		# Créer une équipe par défaut
		_create_default_team()
		return
	
	var file = FileAccess.open(TEAM_SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[TeamManager] Erreur de parsing de la sauvegarde")
		_create_default_team()
		return
	
	var data = json.data
	current_team.clear()
	for unit in data.get("current_team", []):
		current_team.append(unit as Dictionary)
	
	roster.clear()
	for unit in data.get("roster", []):
		roster.append(unit as Dictionary)
	
	print("[TeamManager] 📂 Équipe chargée depuis sauvegarde")

func _create_default_team() -> void:
	"""Crée une équipe de départ"""
	
	print("[TeamManager] 🆕 Création équipe par défaut")
	
	# Recruter 2 unités de base si disponibles
	if available_units.has("starter_knight"):
		recruit_unit("starter_knight")
		if roster.size() > 0:
			add_to_team(roster[0])
	
	if available_units.has("starter_mage"):
		recruit_unit("starter_mage")
		if roster.size() > 1:
			add_to_team(roster[1])
