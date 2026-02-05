extends Node
## SceneLoader - Chargement et transition de scènes
## Charge les scènes dans le SceneContainer de GameRoot
##
## Accès via : GameRoot.scene_loader

class_name SceneLoaderClass

# ============================================================================
# SIGNAUX
# ============================================================================

signal scene_loading_started(scene_path: String)
signal scene_loading_progress(progress: float)
signal scene_loaded(scene: Node)
signal scene_transition_finished()

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var fade_duration: float = 0.3
@export var debug_mode: bool = true

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var scene_container: Node = null  # Assigné par GameRoot
var transition_overlay: ColorRect = null

# ============================================================================
# ÉTAT
# ============================================================================

var current_scene: Node = null
var current_scene_id: int = -1
var is_loading: bool = false
var loading_progress: float = 0.0

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	call_deferred("_setup_transition_overlay")
	print("[SceneLoader] ✅ Initialisé")

func _setup_transition_overlay() -> void:
	"""Crée l'overlay de transition dans l'UIManager"""
	
	# Attendre que l'UIManager soit prêt
	await get_tree().process_frame
	
	if GameRoot and GameRoot.ui_manager:
		transition_overlay = GameRoot.ui_manager.create_transition_overlay()
	else:
		# Fallback : créer localement
		_create_local_overlay()
	
	if debug_mode:
		print("[SceneLoader] ✅ Overlay de transition configuré")

func _create_local_overlay() -> void:
	"""Crée un overlay local (fallback)"""
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	transition_overlay = ColorRect.new()
	transition_overlay.color = Color.BLACK
	transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.modulate.a = 0.0
	canvas.add_child(transition_overlay)

# ============================================================================
# CHARGEMENT DE SCÈNE
# ============================================================================

func load_scene_by_id(scene_id: int, transition: bool = true) -> void:
	"""Charge une scène via son ID du registre"""
	
	if not SceneRegistry.scene_exists(scene_id):
		push_error("[SceneLoader] Scène introuvable : %d" % scene_id)
		return
	
	var scene_path = SceneRegistry.get_scene_path(scene_id)
	current_scene_id = scene_id
	
	if debug_mode:
		print("[SceneLoader] 🎬 Chargement : %s" % SceneRegistry.get_scene_name(scene_id))
	
	await load_scene(scene_path, transition)

func load_scene(scene_path: String, transition: bool = true) -> void:
	"""Charge une scène par son chemin"""
	
	if is_loading:
		push_warning("[SceneLoader] Chargement déjà en cours")
		return
	
	if not ResourceLoader.exists(scene_path):
		push_error("[SceneLoader] Scène introuvable : %s" % scene_path)
		return
	
	is_loading = true
	scene_loading_started.emit(scene_path)
	
	if debug_mode:
		print("[SceneLoader] 🎬 Début du chargement : %s" % scene_path)
	
	# Transition sortante
	if transition:
		await _fade_out()
	
	# Nettoyer la scène actuelle
	_cleanup_current_scene()
	
	# Charger la nouvelle scène
	var new_scene = await _load_scene_async(scene_path)
	
	if new_scene == null:
		push_error("[SceneLoader] Échec du chargement : %s" % scene_path)
		is_loading = false
		if transition:
			await _fade_in()
		return
	
	# Ajouter la scène au container
	if scene_container:
		scene_container.add_child(new_scene)
	else:
		push_error("[SceneLoader] SceneContainer non défini !")
		get_tree().root.add_child(new_scene)
	
	current_scene = new_scene
	
	# Mettre à jour la référence dans GameRoot
	if GameRoot:
		GameRoot.current_scene = new_scene
		GameRoot._on_scene_loaded(new_scene)
	
	scene_loaded.emit(new_scene)
	
	# Transition entrante
	if transition:
		await _fade_in()
	
	is_loading = false
	scene_transition_finished.emit()
	
	if debug_mode:
		print("[SceneLoader] ✅ Scène chargée : %s" % scene_path)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _cleanup_current_scene() -> void:
	"""Supprime la scène actuelle"""
	
	if not scene_container:
		return
	
	for child in scene_container.get_children():
		if debug_mode:
			print("[SceneLoader] 🗑️ Suppression : %s" % child.name)
		child.queue_free()
	
	current_scene = null
	
	# Notifier GameRoot
	if GameRoot:
		GameRoot._on_scene_unloaded()
	
	# Attendre le nettoyage
	await get_tree().process_frame

# ============================================================================
# CHARGEMENT ASYNCHRONE
# ============================================================================

func _load_scene_async(scene_path: String) -> Node:
	"""Chargement asynchrone avec progression"""
	
	var status = ResourceLoader.load_threaded_request(scene_path)
	
	if status != OK:
		push_error("[SceneLoader] Erreur lors de la requête de chargement")
		return null
	
	while true:
		var progress_array = []
		status = ResourceLoader.load_threaded_get_status(scene_path, progress_array)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene = ResourceLoader.load_threaded_get(scene_path)
			return packed_scene.instantiate()
		
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("[SceneLoader] Échec du chargement threaded")
			return null
		
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[SceneLoader] Ressource invalide")
			return null
		
		# Mettre à jour la progression
		if progress_array.size() > 0:
			loading_progress = progress_array[0]
			scene_loading_progress.emit(loading_progress)
			
			# Notifier l'UIManager
			if GameRoot and GameRoot.ui_manager:
				GameRoot.ui_manager.update_loading_progress(loading_progress)
		
		await get_tree().process_frame
	
	return null

# ============================================================================
# TRANSITIONS VISUELLES
# ============================================================================

func _fade_out() -> void:
	"""Fondu vers le noir"""
	
	if not transition_overlay:
		return
	
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 1.0, fade_duration)
	await tween.finished

func _fade_in() -> void:
	"""Fondu depuis le noir"""
	
	if not transition_overlay:
		return
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 0.0, fade_duration)
	await tween.finished
	
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ============================================================================
# CALLBACKS EVENTBUS
# ============================================================================

func _on_scene_change_requested(scene_id: int) -> void:
	"""Réaction à une demande de changement de scène"""
	load_scene_by_id(scene_id)

# ============================================================================
# UTILITAIRES
# ============================================================================

func reload_current_scene(transition: bool = true) -> void:
	"""Recharge la scène actuelle"""
	
	if current_scene_id != -1:
		load_scene_by_id(current_scene_id, transition)
	elif current_scene:
		var scene_path = current_scene.scene_file_path
		load_scene(scene_path, transition)

func get_current_scene_name() -> String:
	"""Retourne le nom de la scène actuelle"""
	
	if current_scene_id != -1:
		return SceneRegistry.get_scene_name(current_scene_id)
	elif current_scene:
		return current_scene.name
	return "Aucune"
