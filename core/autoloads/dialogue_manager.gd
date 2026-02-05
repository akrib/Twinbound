extends Node
## Dialogue_Manager - Gestionnaire central du système de dialogue
## Autoload qui orchestre tous les dialogues du jeu
##
## Accès via : GameRoot.dialogue_manager

class_name DialogueManagerClass

# ============================================================================
# SIGNAUX
# ============================================================================

signal dialogue_started(dialogue_id: String)
signal dialogue_line_shown(line_data: Dictionary)
signal dialogue_choices_shown(choices: Array)
signal dialogue_choice_selected(choice_index: int)
signal dialogue_ended(dialogue_id: String)
signal bark_requested(speaker: String, text: String, position: Vector2)

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var default_text_speed: float = 50.0  # Caractères par seconde
@export var default_auto_advance_delay: float = 2.0
@export var enable_skip: bool = true
@export var enable_auto_mode: bool = false
@export var dialogue_sfx_volume: float = 0.0  # dB

# Configuration du temps de lecture
@export var reading_speed_chars_per_second: float = 15.0
@export var minimum_reading_time: float = 1.5
@export var maximum_reading_time: float = 8.0

# ============================================================================
# ÉTAT
# ============================================================================

var current_dialogue = null  # DialogueData
var current_line_index: int = 0
var is_dialogue_active: bool = false
var dialogue_box = null  # DialogueBox
var bark_system = null  # BarkSystem

var text_speed: float = 50.0
var auto_mode: bool = false
var is_skippable: bool = true

# Historique
var dialogue_history: Array[Dictionary] = []
var max_history_size: int = 100

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	text_speed = default_text_speed
	auto_mode = enable_auto_mode
	
	# Créer le BarkSystem si la classe existe
	if ClassDB.class_exists("BarkSystem"):
		bark_system = ClassDB.instantiate("BarkSystem")
		add_child(bark_system)
	
	call_deferred("_connect_to_event_bus")
	
	print("[DialogueManager] ✅ Initialisé - auto_mode: ", auto_mode)

func _connect_to_event_bus() -> void:
	"""Connexion aux événements globaux"""
	await get_tree().process_frame
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.safe_connect("dialogue_started", _on_eventbus_dialogue_started)
		GameRoot.event_bus.safe_connect("dialogue_ended", _on_eventbus_dialogue_ended)

# ============================================================================
# CHARGEMENT DE DIALOGUES
# ============================================================================

func start_dialogue(dialogue, dialogue_box_instance = null) -> void:
	"""Démarre un nouveau dialogue"""
	
	if is_dialogue_active:
		push_warning("[DialogueManager] Un dialogue est déjà en cours")
		return
	
	if not dialogue or dialogue.lines.is_empty():
		push_error("[DialogueManager] Dialogue invalide ou vide")
		return
	
	current_dialogue = dialogue
	current_line_index = 0
	is_dialogue_active = true
	
	# Utiliser la DialogueBox fournie
	dialogue_box = dialogue_box_instance
	
	if not dialogue_box:
		push_error("[DialogueManager] Aucune DialogueBox fournie")
		end_dialogue()
		return
	
	# Configurer la DialogueBox
	dialogue_box.dialogue_manager = self
	dialogue_box.show_dialogue_box()
	
	# Se connecter au signal de révélation du texte
	if dialogue_box.has_signal("text_reveal_completed"):
		if not dialogue_box.text_reveal_completed.is_connected(_on_text_reveal_completed):
			dialogue_box.text_reveal_completed.connect(_on_text_reveal_completed)
	
	# Émettre les signaux
	dialogue_started.emit(dialogue.dialogue_id)
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.dialogue_started.emit(dialogue.dialogue_id)
	
	# Afficher la première ligne
	show_current_line()
	
	print("[DialogueManager] ✅ Dialogue démarré : ", dialogue.dialogue_id)
	
func start_dialogue_from_id(dialogue_id: String, dialogue_box_instance = null) -> void:
	"""Démarre un dialogue à partir de son ID"""
	
	# TODO: Implémenter un système de registre de dialogues
	push_warning("[DialogueManager] start_dialogue_from_id non implémenté")

# ============================================================================
# AFFICHAGE DES LIGNES
# ============================================================================

func show_current_line() -> void:
	"""Affiche la ligne actuelle du dialogue"""
	
	if not current_dialogue or current_line_index >= current_dialogue.lines.size():
		end_dialogue()
		return
	
	var line = current_dialogue.lines[current_line_index]
	
	print("[DialogueManager] 📖 Ligne ", current_line_index + 1, "/", current_dialogue.lines.size())
	
	# Ajouter à l'historique
	_add_to_history(line)
	
	# Si c'est un choix
	if line.has("choices") and not line.choices.is_empty():
		show_choices(line.choices)
		return
	
	# Si c'est un événement
	if line.has("event"):
		_trigger_event(line.event)
		advance_dialogue()
		return
	
	# Affichage normal
	dialogue_box.display_line(line)
	
	# Émettre le signal
	dialogue_line_shown.emit(line)

func _calculate_reading_time(line: Dictionary) -> float:
	"""Calcule le temps de lecture optimal pour une ligne de dialogue"""
	
	if line.has("auto_delay"):
		return line.auto_delay
	
	var text = line.get("text", "")
	var text_key = line.get("text_key", "")
	
	if text_key:
		text = tr(text_key)
	
	var clean_text = _strip_bbcode(text)
	var char_count = clean_text.length()
	
	var reveal_speed = line.get("speed", default_text_speed)
	var reveal_time = char_count / reveal_speed
	var reading_time = char_count / reading_speed_chars_per_second
	var total_time = reveal_time + reading_time
	
	total_time = clamp(total_time, minimum_reading_time, maximum_reading_time)
	
	return total_time

func _strip_bbcode(text: String) -> String:
	"""Retire les balises BBCode pour obtenir le texte brut"""
	var regex = RegEx.new()
	regex.compile("\\[[\\/]?[^\\]]*\\]")
	return regex.sub(text, "", true)

func show_choices(choices: Array) -> void:
	"""Affiche des choix au joueur"""
	
	dialogue_box.display_choices(choices)
	dialogue_choices_shown.emit(choices)

func select_choice(choice_index: int) -> void:
	"""Sélectionne un choix"""
	
	var line = current_dialogue.lines[current_line_index]
	
	if not line.has("choices") or choice_index >= line.choices.size():
		push_error("[DialogueManager] Index de choix invalide")
		return
	
	var choice = line.choices[choice_index]
	
	# Émettre le signal
	dialogue_choice_selected.emit(choice_index)
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.choice_made.emit(current_dialogue.dialogue_id, choice_index)
	
	# Exécuter l'action du choix
	if choice.has("next_line"):
		current_line_index = choice.next_line
		show_current_line()
	elif choice.has("end_dialogue") and choice.end_dialogue:
		end_dialogue()
	else:
		advance_dialogue()

# ============================================================================
# NAVIGATION
# ============================================================================

func advance_dialogue() -> void:
	"""Avance à la ligne suivante"""
	
	if not is_dialogue_active:
		return
	
	# Si le texte est en train d'apparaître, le compléter
	if dialogue_box and dialogue_box.is_text_revealing:
		dialogue_box.complete_text()
		return
	
	current_line_index += 1
	
	if current_line_index >= current_dialogue.lines.size():
		end_dialogue()
	else:
		show_current_line()

func skip_dialogue() -> void:
	"""Skip le dialogue entier (si autorisé)"""
	
	if not is_skippable or not enable_skip:
		return
	
	end_dialogue()

func end_dialogue() -> void:
	"""Termine le dialogue actuel"""
	
	if not is_dialogue_active:
		return
	
	var dialogue_id = current_dialogue.dialogue_id if current_dialogue else ""
	
	is_dialogue_active = false
	
	# Déconnecter les signaux
	if dialogue_box and dialogue_box.has_signal("text_reveal_completed"):
		if dialogue_box.text_reveal_completed.is_connected(_on_text_reveal_completed):
			dialogue_box.text_reveal_completed.disconnect(_on_text_reveal_completed)
	
	if dialogue_box:
		dialogue_box.hide_dialogue_box()
	
	# Émettre les signaux
	dialogue_ended.emit(dialogue_id)
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.dialogue_ended.emit(dialogue_id)
	
	# Nettoyer
	current_dialogue = null
	current_line_index = 0
	
	print("[DialogueManager] 🏁 Dialogue terminé : ", dialogue_id)

# ============================================================================
# BARKS (Messages courts)
# ============================================================================

func show_bark(speaker: String, text_key: String, world_position: Vector2, duration: float = 2.0) -> void:
	"""Affiche un bark (message court) au-dessus d'un personnage"""
	
	if not bark_system:
		push_warning("[DialogueManager] BarkSystem non initialisé")
		return
	
	var translated_text = tr(text_key)
	bark_system.show_bark(speaker, translated_text, world_position, duration)
	
	bark_requested.emit(speaker, translated_text, world_position)

# ============================================================================
# ÉVÉNEMENTS
# ============================================================================

func _trigger_event(event_data: Dictionary) -> void:
	"""Déclenche un événement personnalisé"""
	
	var event_type = event_data.get("type", "")
	
	match event_type:
		"set_variable":
			var key = event_data.get("key", "")
			var value = event_data.get("value", null)
			if key:
				print("[DialogueManager] Variable set : ", key, " = ", value)
		
		"play_sound":
			var sound_path = event_data.get("sound", "")
			if sound_path:
				print("[DialogueManager] Play sound : ", sound_path)
		
		"trigger_battle":
			var battle_id = event_data.get("battle_id", "")
			if battle_id and GameRoot and GameRoot.event_bus:
				GameRoot.event_bus.notify("Déclenchement du combat : " + battle_id, "info")
		
		_:
			print("[DialogueManager] Événement inconnu : ", event_type)

# ============================================================================
# HISTORIQUE
# ============================================================================

func _add_to_history(line: Dictionary) -> void:
	"""Ajoute une ligne à l'historique"""
	
	dialogue_history.append(line.duplicate())
	
	while dialogue_history.size() > max_history_size:
		dialogue_history.pop_front()

func get_history() -> Array[Dictionary]:
	"""Retourne l'historique des dialogues"""
	return dialogue_history.duplicate()

func clear_history() -> void:
	"""Efface l'historique"""
	dialogue_history.clear()

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_text_speed(speed: float) -> void:
	"""Change la vitesse du texte"""
	text_speed = clamp(speed, 10.0, 200.0)

func set_auto_mode(enabled: bool) -> void:
	"""Active/désactive le mode auto"""
	auto_mode = enabled

func toggle_auto_mode() -> void:
	"""Bascule le mode auto"""
	auto_mode = not auto_mode
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Mode auto: " + ("ON" if auto_mode else "OFF"), "info")

# ============================================================================
# HELPERS
# ============================================================================

func is_active() -> bool:
	"""Vérifie si un dialogue est actif"""
	return is_dialogue_active

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_eventbus_dialogue_started(_dialogue_id: String) -> void:
	pass

func _on_eventbus_dialogue_ended(_dialogue_id: String) -> void:
	pass

func _on_text_reveal_completed() -> void:
	"""Appelé quand le texte est complètement révélé"""
	
	if not is_dialogue_active or not current_dialogue:
		return
	
	var line = current_dialogue.lines[current_line_index]
	
	if auto_mode and line.get("auto_advance", false):
		var delay = _calculate_reading_time(line)
		
		get_tree().create_timer(delay).timeout.connect(
			func():
				if is_dialogue_active and current_line_index < current_dialogue.lines.size():
					advance_dialogue()
		)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.disconnect_all(self)
