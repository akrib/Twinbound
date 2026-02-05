extends Node
## EventBus - Hub de communication global découplé
## Permet aux scènes de communiquer sans dépendances directes
##
## Accès via : GameRoot.event_bus

class_name EventBusClass

# ============================================================================
# SIGNAUX GLOBAUX DU JEU
# ============================================================================

# --- Système ---
signal game_started()
signal game_paused(paused: bool)
signal game_saved(save_name: String)
signal game_loaded(save_name: String)
signal settings_changed(settings: Dictionary)

# --- Navigation ---
signal scene_change_requested(scene_id: int)
signal return_to_menu_requested()
signal quit_game_requested()

# --- Combat ---
signal battle_started(battle_data: Variant)
signal battle_ended(results: Dictionary)
signal duo_formed(unit_a: Node, unit_b: Node)
signal duo_broken(unit_a: Node, unit_b: Node)
signal unit_attacked(attacker: Node, target: Node, damage: int)
signal unit_died(unit: Node)
signal turn_started(unit: Node)
signal turn_ended(unit: Node)

# --- Statistiques & Progression ---
signal stats_updated(unit: Node, stat_name: String, new_value: float)
signal threat_level_changed(duo: Array, new_threat: float)
signal legend_gained(duo: Array, legend_type: String)
signal title_unlocked(unit: Node, title: String)
signal mvp_awarded(unit: Node, battle_id: String)

# --- Divinités (Système de Foi) ---
signal divine_points_gained(god_name: String, points: int)
signal divine_threshold_reached(god_name: String, threshold: int)
signal divine_event_triggered(god_name: String, event_data: Dictionary)

# --- Monde & Narration ---
signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)
signal choice_made(choice_id: String, option: int)
signal cutscene_started(cutscene_id: String)
signal cutscene_ended(cutscene_id: String)
signal location_discovered(location_name: String)
signal quest_updated(quest_id: String, status: String)

# --- Ressources ---
signal gold_changed(new_amount: int)
signal item_gained(item_id: String, quantity: int)
signal item_lost(item_id: String, quantity: int)

# --- UI ---
signal notification_posted(message: String, type: String)
signal tooltip_requested(content: String, position: Vector2)
signal tooltip_hidden()

# --- Dialogue ---
signal dialogue_bark_requested(speaker: String, text_key: String, position: Vector2)
signal dialogue_typewriter_completed()
signal dialogue_skip_requested()

# --- Campagne ---
signal campaign_started()
signal campaign_completed()
signal chapter_changed(chapter_id: int)

# --- Data Loading ---
signal data_loaded(data_type: String, data: Dictionary)
signal data_load_warning(data_type: String, warning: String)
signal ability_reloaded(ability_id: String)

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	print("[EventBus] ✅ Initialisé")

# ============================================================================
# MÉTHODES UTILITAIRES
# ============================================================================

func emit_event(event_name: String, args: Array = [], debug: bool = false) -> void:
	"""Émet un signal par son nom avec des arguments"""
	
	if not has_signal(event_name):
		push_warning("[EventBus] Signal introuvable : %s" % event_name)
		return
	
	if debug:
		print("[EventBus] Émission : %s avec args : %s" % [event_name, args])
	
	callv("emit_signal", [event_name] + args)

func safe_connect(signal_name: String, callable: Callable, flags: int = 0) -> void:
	"""Connexion sécurisée avec vérification"""
	
	if not has_signal(signal_name):
		push_error("[EventBus] Impossible de connecter à un signal inexistant : %s" % signal_name)
		return
	
	if is_connected(signal_name, callable):
		push_warning("[EventBus] Déjà connecté : %s" % signal_name)
		return
	
	connect(signal_name, callable, flags)

func safe_disconnect(signal_name: String, callable: Callable) -> void:
	"""Déconnexion sécurisée"""
	
	if not has_signal(signal_name):
		return
	
	if is_connected(signal_name, callable):
		disconnect(signal_name, callable)

func disconnect_all(object: Object) -> void:
	"""Déconnexion de tous les signaux d'un objet"""
	
	for signal_dict in get_signal_list():
		var sig_name = signal_dict["name"]
		var connections = get_signal_connection_list(sig_name)
		
		for connection in connections:
			if connection["callable"].get_object() == object:
				disconnect(sig_name, connection["callable"])

# ============================================================================
# HELPERS SPÉCIFIQUES AU JEU
# ============================================================================

func notify(message: String, type: String = "info") -> void:
	"""Notification simple"""
	notification_posted.emit(message, type)

func change_scene(scene_id: int) -> void:
	"""Changement de scène via EventBus"""
	scene_change_requested.emit(scene_id)

func add_divine_points(god: String, points: int) -> void:
	"""Mise à jour des statistiques divines"""
	divine_points_gained.emit(god, points)

func form_duo(unit_a: Node, unit_b: Node) -> void:
	"""Formation de duo"""
	duo_formed.emit(unit_a, unit_b)

func break_duo(unit_a: Node, unit_b: Node) -> void:
	"""Rupture de duo"""
	duo_broken.emit(unit_a, unit_b)

func attack(attacker: Node, target: Node, damage: int) -> void:
	"""Attaque d'unité"""
	unit_attacked.emit(attacker, target, damage)

func end_battle(results: Dictionary) -> void:
	"""Fin de combat"""
	battle_ended.emit(results)

func show_bark(speaker: String, text_key: String, position: Vector2) -> void:
	"""Affiche un bark de dialogue"""
	dialogue_bark_requested.emit(speaker, text_key, position)

func start_battle(battle_id: String) -> void:
	"""Émet le signal de début de combat"""
	print("[EventBus] 🎬 Début du combat : %s" % battle_id)
	battle_started.emit(battle_id)

# ============================================================================
# DEBUG
# ============================================================================

func debug_list_connections() -> void:
	"""Liste toutes les connexions actives (debug)"""
	
	print("\n=== EventBus - Connexions actives ===")
	
	for signal_dict in get_signal_list():
		var sig_name = signal_dict["name"]
		var connections = get_signal_connection_list(sig_name)
		
		if connections.size() > 0:
			print("\n[%s] : %d connexions" % [sig_name, connections.size()])
			for connection in connections:
				var target = connection["callable"].get_object()
				var method = connection["callable"].get_method()
				print("  -> %s.%s" % [target.name if target else "null", method])
	
	print("\n=====================================\n")
