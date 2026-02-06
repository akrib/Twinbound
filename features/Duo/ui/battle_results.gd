# scenes/battle/battle_results.gd
extends Control
class_name BattleResults

# ============================================================================
# RÉFÉRENCES UI
# ============================================================================

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var winner_label: Label = $MarginContainer/VBoxContainer/WinnerLabel
@onready var fallen_units_container: VBoxContainer = $MarginContainer/VBoxContainer/Panel/MarginContainer/ScrollContainer/FallenUnitsList
@onready var xp_label: Label = $MarginContainer/VBoxContainer/XPLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton

# ============================================================================
# DONNÉES
# ============================================================================

var battle_results: Dictionary = {}

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	# Connecter le bouton
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	# Récupérer les résultats depuis BattleDataManager ou autre
	# Pour l'instant, on va utiliser des données de test si non disponibles
	if GameRoot.battle_data_manager.has_battle_data():
		var battle_data = GameRoot.battle_data_manager.get_battle_data()
		battle_results = battle_data.get("results", {})
	
	# Afficher les résultats
	_display_results()

# ============================================================================
# AFFICHAGE
# ============================================================================

func _display_results() -> void:
	"""Affiche tous les résultats du combat"""
	
	# Titre du combat
	var battle_title = battle_results.get("battle_title", "Combat Terminé")
	if title_label:
		title_label.text = battle_title
	
	# Équipe gagnante
	var is_victory = battle_results.get("victory", false)
	var winner_team = "L'Équipe du Joueur" if is_victory else "L'Équipe Ennemie"
	
	if winner_label:
		winner_label.text = "Vainqueur : " + winner_team
		
		# Colorer selon le résultat
		if is_victory:
			winner_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Vert
		else:
			winner_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Rouge
	
	# Unités tombées au combat
	_display_fallen_units()
	
	# XP gagné
	var xp_earned = battle_results.get("xp_earned", 0)
	
	# Si pas de calcul d'XP, inventer un chiffre basé sur les stats
	if xp_earned == 0 and is_victory:
		var stats = battle_results.get("stats", {})
		var global_stats = stats.get("global", {})
		var turns = global_stats.get("turns_elapsed", 1)
		var enemies_killed = global_stats.get("units_killed", 0)
		
		# Formule simple : 50 XP de base + 10 par ennemi tué + bonus de rapidité
		xp_earned = 50 + (enemies_killed * 10)
		
		# Bonus si victoire rapide (moins de 10 tours)
		if turns < 10:
			xp_earned += 50
	
	if xp_label:
		xp_label.text = "XP Gagné : " + str(xp_earned)

func _display_fallen_units() -> void:
	"""Affiche la liste des unités tombées au combat"""
	
	if not fallen_units_container:
		return
	
	# Nettoyer le conteneur
	for child in fallen_units_container.get_children():
		child.queue_free()
	
	# Récupérer les stats des unités
	var stats = battle_results.get("stats", {})
	var unit_summaries = stats.get("units", [])
	
	# Filtrer les unités mortes
	var fallen: Array[Dictionary] = []
	
	for unit_summary in unit_summaries:
		if not unit_summary.get("is_alive", true):
			fallen.append(unit_summary)
	
	# Afficher un message si aucune unité n'est tombée
	if fallen.is_empty():
		var no_casualties_label = Label.new()
		no_casualties_label.text = "Aucune perte !"
		no_casualties_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_casualties_label.add_theme_font_size_override("font_size", 18)
		no_casualties_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		fallen_units_container.add_child(no_casualties_label)
		return
	
	# Créer une entrée pour chaque unité tombée
	for unit in fallen:
		var unit_entry = _create_fallen_unit_entry(unit)
		fallen_units_container.add_child(unit_entry)

func _create_fallen_unit_entry(unit: Dictionary) -> HBoxContainer:
	"""Crée une entrée visuelle pour une unité tombée"""
	
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)
	
	# Icône (skull emoji)
	var icon_label = Label.new()
	icon_label.text = "💀"
	icon_label.custom_minimum_size = Vector2(40, 0)
	container.add_child(icon_label)
	
	# Nom de l'unité
	var name_label = Label.new()
	var unit_name = unit.get("name", "Inconnu")
	var is_player = unit.get("is_player", false)
	var team_tag = "[Joueur]" if is_player else "[Ennemi]"
	
	name_label.text = unit_name + " " + team_tag
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Colorer selon l'équipe
	if is_player:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	
	container.add_child(name_label)
	
	# Stats finales (dégâts infligés, etc.)
	var stats_label = Label.new()
	var damage_dealt = unit.get("damage_dealt", 0)
	var kills = unit.get("kills", 0)
	
	stats_label.text = "DMG: %d | Kills: %d" % [damage_dealt, kills]
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(stats_label)
	
	return container

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_continue_pressed() -> void:
	"""Retour à la carte du monde"""
	GameRoot.event_bus.change_scene(SceneRegistry.SceneID.WORLD_MAP)

# ============================================================================
# SETUP EXTERNE
# ============================================================================

func setup_results(results: Dictionary) -> void:
	"""Configure les résultats depuis l'extérieur"""
	battle_results = results
	
	if is_inside_tree():
		_display_results()
