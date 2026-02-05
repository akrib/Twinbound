extends Control
## Menu Principal - Point d'entrée du jeu
## Utilise SceneLoader pour les transitions et EventBus pour la communication

class_name MainMenu

# Références aux nœuds UI
@onready var start_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/StartButton
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/ContinueButton
@onready var options_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/OptionsButton
@onready var credits_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/CreditsButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/ButtonsContainer/QuitButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var version_label: Label = $MarginContainer/VBoxContainer/VersionLabel

# État
var has_save: bool = false

func _ready() -> void:
	# Vérifier les sauvegardes disponibles
	_check_save_availability()
	
	# Connexion à l'EventBus
	GameRoot.event_bus.safe_connect("game_started", _on_game_started)
	GameRoot.event_bus.safe_connect("game_loaded", _on_game_loaded)
	
	# Animation d'entrée
	_play_intro_animation()
	
	print("[MainMenu] Initialisé")

## Auto-connexion des signaux via SceneLoader
func _get_signal_connections() -> Array:
	"""
	Retourne une liste de connexions de signaux pour SceneLoader.
	Cette méthode est appelée automatiquement par SceneLoader.
	"""
	if not is_node_ready():
		return []
	
	return [
		{
			"source": start_button,
			"signal_name": "pressed",
			"target": self,
			"method": "_on_start_pressed"
		},
		{
			"source": continue_button,
			"signal_name": "pressed",
			"target": self,
			"method": "_on_continue_pressed"
		},
		{
			"source": options_button,
			"signal_name": "pressed",
			"target": self,
			"method": "_on_options_pressed"
		},
		{
			"source": credits_button,
			"signal_name": "pressed",
			"target": self,
			"method": "_on_credits_pressed"
		},
		{
			"source": quit_button,
			"signal_name": "pressed",
			"target": self,
			"method": "_on_quit_pressed"
		},
	]

# ============================================================================
# INITIALISATION
# ============================================================================

func _check_save_availability() -> void:
	"""Vérifie si une sauvegarde existe"""
	# TODO: Implémenter la vérification réelle des sauvegardes
	has_save = false
	
	# Désactiver le bouton Continuer si pas de sauvegarde
	continue_button.disabled = not has_save
	
	if not has_save:
		continue_button.modulate.a = 0.5

func _play_intro_animation() -> void:
	"""Animation d'entrée du menu"""
	title_label.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "position:y", title_label.position.y, 0.8).from(title_label.position.y - 50).set_ease(Tween.EASE_OUT)

# ============================================================================
# CALLBACKS BOUTONS
# ============================================================================

func _on_start_pressed() -> void:
	"""Démarrer une nouvelle partie"""
	print("[MainMenu] Nouvelle partie")
	
	# Notification
	GameRoot.event_bus.notify("Démarrage d'une nouvelle partie...", "info")
	
	# Émettre l'événement de début de jeu
	GameRoot.event_bus.game_started.emit()
	
	# Transition vers la carte du monde
	GameRoot.event_bus.change_scene(SceneRegistry.SceneID.WORLD_MAP)

func _on_continue_pressed() -> void:
	"""Continuer la dernière sauvegarde"""
	if not has_save:
		return
	
	print("[MainMenu] Chargement de la dernière sauvegarde")
	
	# TODO: Charger la sauvegarde via GameManager
	GameRoot.event_bus.notify("Chargement de la partie...", "info")
	GameRoot.game_manager.load_game("auto_save")
	
	# Transition vers la scène sauvegardée
	GameRoot.event_bus.change_scene(SceneRegistry.SceneID.WORLD_MAP)

func _on_options_pressed() -> void:
	"""Ouvrir le menu des options"""
	print("[MainMenu] Options")
	GameRoot.event_bus.notify("Options (à implémenter)", "info")
	
	# TODO: Quand la scène options sera créée
	# GameRoot.event_bus.change_scene(SceneRegistry.SceneID.OPTIONS_MENU)

func _on_credits_pressed() -> void:
	"""Afficher les crédits"""
	print("[MainMenu] Crédits")
	GameRoot.event_bus.notify("Crédits (à implémenter)", "info")
	
	# TODO: Quand la scène crédits sera créée
	# GameRoot.event_bus.change_scene(SceneRegistry.SceneID.CREDITS)

func _on_quit_pressed() -> void:
	"""Quitter le jeu"""
	print("[MainMenu] Quitter le jeu")
	
	# Animation de sortie
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Émettre la demande de fermeture via EventBus
	GameRoot.event_bus.quit_game_requested.emit()

# ============================================================================
# CALLBACKS EVENTBUS
# ============================================================================

func _on_game_started() -> void:
	"""Réaction au démarrage du jeu"""
	print("[MainMenu] Le jeu démarre (EventBus)")

func _on_game_loaded(save_name: String) -> void:
	"""Réaction au chargement d'une sauvegarde"""
	print("[MainMenu] Sauvegarde chargée : ", save_name)

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	# Raccourci clavier pour démarrer rapidement (DEBUG)
	if OS.is_debug_build():
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			_on_start_pressed()

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	"""Nettoyage à la fermeture de la scène"""
	GameRoot.event_bus.disconnect_all(self)
	print("[MainMenu] Scène nettoyée")
