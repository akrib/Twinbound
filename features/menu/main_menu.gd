extends Control
## Menu Principal - Point d'entrée du jeu
##
## Le bouton "Nouvelle Partie" émet game_started via EventBus.
## CampaignManager reçoit ce signal et orchestre la séquence d'intro
## (dialogues via DialogueManager, UI via UIManager, puis transition vers WorldMap)

class_name MainMenu

# Références aux nœuds UI
@onready var start_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/StartButton
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/ContinueButton
@onready var options_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/OptionsButton
@onready var credits_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/CreditsButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/QuitButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var version_label: Label = $MarginContainer/VBoxContainer/VersionLabel

var has_save: bool = false

func _ready() -> void:
	_check_save_availability()
	_connect_buttons()
	_play_intro_animation()
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.safe_connect("game_started", _on_game_started)
		GameRoot.event_bus.safe_connect("game_loaded", _on_game_loaded)
	
	print("[MainMenu] ✅ Initialisé")

func _connect_buttons() -> void:
	"""Connecte les boutons manuellement"""
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _check_save_availability() -> void:
	has_save = false
	if GameRoot and GameRoot.game_manager:
		has_save = GameRoot.game_manager.has_save("auto_save")
	
	continue_button.disabled = not has_save
	if not has_save:
		continue_button.modulate.a = 0.5

func _play_intro_animation() -> void:
	title_label.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "position:y", title_label.position.y, 0.8).from(title_label.position.y - 50).set_ease(Tween.EASE_OUT)

# ============================================================================
# CALLBACKS BOUTONS
# ============================================================================

func _on_start_pressed() -> void:
	"""Nouvelle partie : émet game_started, CampaignManager gère la suite"""
	print("[MainMenu] ▶ Nouvelle partie")
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Démarrage d'une nouvelle partie...", "info")
		# CampaignManager écoute ce signal et lance la séquence d'intro
		# puis transite vers la WorldMap automatiquement
		GameRoot.event_bus.game_started.emit()

func _on_continue_pressed() -> void:
	if not has_save:
		return
	
	print("[MainMenu] ↻ Chargement de la dernière sauvegarde")
	
	if GameRoot:
		GameRoot.event_bus.notify("Chargement de la partie...", "info")
		GameRoot.game_manager.load_game("auto_save")

func _on_options_pressed() -> void:
	print("[MainMenu] ⚙ Options")
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Options (à implémenter)", "info")

func _on_credits_pressed() -> void:
	print("[MainMenu] ℹ Crédits")
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.notify("Crédits (à implémenter)", "info")

func _on_quit_pressed() -> void:
	print("[MainMenu] ✕ Quitter le jeu")
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.quit_game_requested.emit()

# ============================================================================
# CALLBACKS EVENTBUS
# ============================================================================

func _on_game_started() -> void:
	print("[MainMenu] Le jeu démarre (EventBus)")

func _on_game_loaded(save_name: String) -> void:
	print("[MainMenu] Sauvegarde chargée : %s" % save_name)

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if OS.is_debug_build():
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			_on_start_pressed()

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	if GameRoot and GameRoot.event_bus:
		GameRoot.event_bus.disconnect_all(self)
