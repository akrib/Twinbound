extends Node
## DialogueManager - Gestionnaire central du système de dialogue
## Autoload qui orchestre tous les dialogues du jeu
##
## Utilise la DialogueBox persistante de UIManager (toujours en mémoire)
## Les scènes n'ont plus besoin d'embarquer leur propre DialogueBox
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

@export var default_text_speed: float = 50.0
@export var default_auto_advance_delay: float = 2.0
@export var enable_skip: bool = true
@export var enable_auto_mode: bool = false
@export var dialogue_sfx_volume: float = 0.0

@export var reading_speed_chars_per_second: float = 15.0
@export var minimum_reading_time: float = 1.5
@export var maximum_reading_time: float = 8.0

# ============================================================================
# ÉTAT
# ============================================================================

var current_dialogue = null  # DialogueData
var current_line_index: int = 0
var is_dialogue_active: bool = false

## DialogueBox persistante (assignée par GameRoot depuis UIManager)
var persistent_dialogue_box: DialogueBoxClass = null

## DialogueBox active (persistante ou override temporaire)
var dialogue_box: DialogueBoxClass = null

var bark_system = null

var text_speed: float = 50.0
var auto_mode: bool = false
var is_skippable: bool = true

var dialogue_history: Array[Dictionary] = []
var max_history_size: int = 100

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	text_speed = default_text_speed
	auto_mode = enable_auto_mode
	
	if ClassDB.class_exists("BarkSystem"):
		bark_system = ClassDB.instantiate("BarkSystem")
		add_child(bark_system)
	
	call_deferred("_connect_to_event_bus")
	
	print("[DialogueManager] ✅ Initialisé")

func _connect_to_event_bus() -> void:
	await get_tree().process_frame
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.safe_connect("dialogue_started", _on_eventbus_dialogue_started)
		GameRoot.event_bus.safe_connect("dialogue_ended", _on_eventbus_dialogue_ended)

## Appelé par GameRoot après la création de UIManager
func set_persistent_dialogue_box(box: DialogueBoxClass) -> void:
	"""Configure la DialogueBox persistante de UIManager"""
	persistent_dialogue_box = box
	print("[DialogueManager] 🔗 DialogueBox persistante connectée")

# ============================================================================
# DÉMARRAGE DE DIALOGUE
# ============================================================================

## Démarre un dialogue (utilise la DialogueBox persistante par défaut)
func start_dialogue(dialogue, override_dialogue_box: DialogueBoxClass = null) -> void:
	"""
	Démarre un nouveau dialogue.
	
	@param dialogue : DialogueData à afficher
	@param override_dialogue_box : DialogueBox spécifique (optionnel)
		Si null, utilise la DialogueBox persistante de UIManager
	"""
	
	if is_dialogue_active:
		push_warning("[DialogueManager] Un dialogue est déjà en cours")
		return
	
	if not dialogue or dialogue.lines.is_empty():
		push_error("[DialogueManager] Dialogue invalide ou vide")
		return
	
	current_dialogue = dialogue
	current_line_index = 0
	is_dialogue_active = true
	
	# Sélectionner la DialogueBox à utiliser
	if override_dialogue_box:
		dialogue_box = override_dialogue_box
	elif persistent_dialogue_box:
		dialogue_box = persistent_dialogue_box
	else:
		push_error("[DialogueManager] Aucune DialogueBox disponible")
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
	
	print("[DialogueManager] ✅ Dialogue démarré : %s" % dialogue.dialogue_id)

func start_dialogue_by_id(dialogue_id: String) -> void:
	var loader := DialogueDataLoader.new()
	var data_dict := loader.load_dialogue(dialogue_id)

	if data_dict.is_empty():
		push_warning("[DialogueManager] Dialogue introuvable : %s" % dialogue_id)
		return

	var DialogueData = preload("res://core/dialogue/dialogue_data.gd")
	var dialogue = DialogueData.new(dialogue_id)

	# Séquences
	if data_dict.has("sequences"):
		for sequence in data_dict.sequences:
			if sequence.has("lines"):
				for line in sequence.lines:
					dialogue.add_line(line)

	# Lignes directes
	if data_dict.has("lines"):
		for line in data_dict.lines:
			dialogue.add_line(line)

	start_dialogue(dialogue)


# ============================================================================
# AFFICHAGE DES LIGNES
# ============================================================================

func show_current_line() -> void:
	if not current_dialogue or current_line_index >= current_dialogue.lines.size():
		end_dialogue()
		return
	
	var line = current_dialogue.lines[current_line_index]
	
	print("[DialogueManager] 📖 Ligne %d/%d" % [current_line_index + 1, current_dialogue.lines.size()])
	
	_add_to_history(line)
	
	if line.has("choices") and not line.choices.is_empty():
		show_choices(line.choices)
		return
	
	if line.has("event"):
		_trigger_event(line.event)
		advance_dialogue()
		return
	
	dialogue_box.display_line(line)
	dialogue_line_shown.emit(line)

func _calculate_reading_time(line: Dictionary) -> float:
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
	var regex = RegEx.new()
	regex.compile("\\[[\\/]?[^\\]]*\\]")
	return regex.sub(text, "", true)

func show_choices(choices: Array) -> void:
	dialogue_box.display_choices(choices)
	dialogue_choices_shown.emit(choices)

func select_choice(choice_index: int) -> void:
	var line = current_dialogue.lines[current_line_index]
	
	if not line.has("choices") or choice_index >= line.choices.size():
		push_error("[DialogueManager] Index de choix invalide")
		return
	
	var choice = line.choices[choice_index]
	
	dialogue_choice_selected.emit(choice_index)
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.choice_made.emit(current_dialogue.dialogue_id, choice_index)
	
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
	if not is_dialogue_active:
		return
	
	if dialogue_box and dialogue_box.is_text_revealing:
		dialogue_box.complete_text()
		return
	
	current_line_index += 1
	
	if current_line_index >= current_dialogue.lines.size():
		end_dialogue()
	else:
		show_current_line()

func skip_dialogue() -> void:
	if not is_skippable or not enable_skip:
		return
	end_dialogue()

func end_dialogue() -> void:
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
	
	# Remettre la DialogueBox par défaut (persistante)
	dialogue_box = persistent_dialogue_box
	
	print("[DialogueManager] 🏁 Dialogue terminé : %s" % dialogue_id)

# ============================================================================
# BARKS
# ============================================================================

func show_bark(speaker: String, text_key: String, world_position: Vector2, duration: float = 2.0) -> void:
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
	var event_type = event_data.get("type", "")
	
	match event_type:
		"set_variable":
			var key = event_data.get("key", "")
			var value = event_data.get("value", null)
			if key:
				print("[DialogueManager] Variable set : %s = %s" % [key, value])
		
		"play_sound":
			var sound_path = event_data.get("sound", "")
			if sound_path:
				print("[DialogueManager] Play sound : %s" % sound_path)
		
		"trigger_battle":
			var battle_id = event_data.get("battle_id", "")
			if battle_id and GameRoot and GameRoot.campaign_manager:
				GameRoot.campaign_manager.start_battle(battle_id)
		
		_:
			print("[DialogueManager] Événement inconnu : %s" % event_type)

# ============================================================================
# HISTORIQUE
# ============================================================================

func _add_to_history(line: Dictionary) -> void:
	dialogue_history.append(line.duplicate())
	while dialogue_history.size() > max_history_size:
		dialogue_history.pop_front()

func get_history() -> Array[Dictionary]:
	return dialogue_history.duplicate()

func clear_history() -> void:
	dialogue_history.clear()

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_text_speed(speed: float) -> void:
	text_speed = clamp(speed, 10.0, 200.0)

func set_auto_mode(enabled: bool) -> void:
	auto_mode = enabled

func toggle_auto_mode() -> void:
	auto_mode = not auto_mode
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Mode auto: " + ("ON" if auto_mode else "OFF"), "info")

func is_active() -> bool:
	return is_dialogue_active

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_eventbus_dialogue_started(_dialogue_id: String) -> void:
	pass

func _on_eventbus_dialogue_ended(_dialogue_id: String) -> void:
	pass

func _on_text_reveal_completed() -> void:
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
