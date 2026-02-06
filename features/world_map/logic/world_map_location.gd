# scenes/world/world_map_location.gd
extends Node2D
## WorldMapLocation - Représente un point d'intérêt sur la carte
## Gère l'affichage, l'interaction et le menu d'actions

class_name WorldMapLocation

signal clicked(location: WorldMapLocation)
signal hovered(location: WorldMapLocation)
signal unhovered(location: WorldMapLocation)

# ============================================================================
# PROPRIÉTÉS
# ============================================================================

var location_id: String = ""
var location_name: String = ""
var location_data: Dictionary = {}
var is_unlocked: bool = false
var is_hovered: bool = false

# Visuel
var sprite: Sprite2D
var label: Label
var area: Area2D

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	pass

func setup(data: Dictionary) -> void:
	"""Configure la location avec ses données"""
	
	location_data = data
	location_id = data.get("id", "")
	location_name = data.get("name", "")
	
	# Position
	if data.has("position"):
		var pos = data.position
		if typeof(pos) == TYPE_VECTOR2I:
			position = Vector2(pos.x, pos.y)
		else:
			position = Vector2(pos.get("x", 0), pos.get("y", 0))
	
	# Déverrouillage
	is_unlocked = true
	
	# ✅ Créer les visuels MAINTENANT (avec les bonnes données)
	if not sprite:  # Seulement si pas déjà créés
		_create_visuals()
	
	_update_visuals()
	
	print("[WorldMapLocation] 📍 Setup terminé : ", location_name, " à ", position)
	
func _create_visuals() -> void:
	"""Crée les éléments visuels"""
	
	# ✅ Rectangle de debug avec Polygon2D
	var debug_rect = Polygon2D.new()
	debug_rect.polygon = PackedVector2Array([
		Vector2(-32, -32),
		Vector2(32, -32),
		Vector2(32, 32),
		Vector2(-32, 32)
	])
	debug_rect.color = Color(1, 0, 0, 0.3)  # Rouge transparent
	add_child(debug_rect)
	print("[WorldMapLocation] 🔴 Rectangle debug créé pour ", location_name)
	
	# Sprite principal avec texture de rond jaune
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture = _create_yellow_circle_texture()
	add_child(sprite)
	print("[WorldMapLocation] 🟡 Sprite créé pour ", location_name)
	
	# Label avec le nom
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, 50)
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	print("[WorldMapLocation] 🏷️ Label créé pour ", location_name)
	
	# Zone de collision pour le clic
	area = Area2D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.input_pickable = true
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 64  # ← Plus gros pour debug
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	print("[WorldMapLocation] 📍 Area2D créée pour ", location_name, " avec radius=64")
	
	# Signaux
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	print("[WorldMapLocation] 🔗 Signaux connectés pour ", location_name)
	
# ✅ NOUVELLE FONCTION : Créer un rond jaune programmatiquement
func _create_yellow_circle_texture() -> ImageTexture:
	"""Crée une texture de cercle jaune"""
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = size / 2
	var radius = 28
	
	# Dessiner le cercle jaune
	for y in range(size):
		for x in range(size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(dx*dx + dy*dy)
			
			if dist < radius:
				# Dégradé du centre vers les bords
				var alpha = 1.0 - (dist / radius) * 0.3
				image.set_pixel(x, y, Color(1.0, 0.9, 0.2, alpha))
			
			# Contour plus foncé
			if dist >= radius - 3 and dist < radius:
				image.set_pixel(x, y, Color(0.8, 0.7, 0.0, 1.0))
	
	return ImageTexture.create_from_image(image)

func _update_visuals() -> void:
	"""Met à jour l'apparence selon l'état"""
	
	if not sprite or not label or not area:
		push_warning("[WorldMapLocation] Visuels non initialisés pour: ", location_name)
		return
	
	# ✅ CHANGEMENT : Utiliser un rond jaune par défaut
	var icon_path = location_data.get("icon", "")
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	else:
		# Pas d'icône spécifiée → utiliser le rond jaune
		sprite.texture = _create_yellow_circle_texture()
	
	# Scale
	var scale_value = location_data.get("scale", 1.5)  # ✅ Un peu plus grand par défaut
	sprite.scale = Vector2(scale_value, scale_value)
	
	# Couleur (si spécifiée dans les données)
	if location_data.has("color"):
		var c = location_data.color
		sprite.modulate = Color(c.get("r", 1), c.get("g", 1), c.get("b", 1), c.get("a", 1))
	else:
		# ✅ Jaune par défaut
		sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)
	
	# Nom
	label.text = location_name
	
	# Visibilité selon déverrouillage
	visible = is_unlocked
	
	# Effet hover
	if is_hovered:
		sprite.scale *= 1.2  # ✅ Plus gros au survol
		label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

func set_unlocked(unlocked: bool) -> void:
	"""Définit si la location est déverrouillée"""
	is_unlocked = unlocked
	_update_visuals()

# ============================================================================
# EVENTS
# ============================================================================

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	print("[WorldMapLocation] 🖱️ Input event reçu sur : ", location_name)
	print("  - Type event: ", event.get_class())
	print("  - is_unlocked: ", is_unlocked)
	
	if event is InputEventMouseButton:
		print("  - MouseButton: ", event.button_index, " pressed: ", event.pressed)
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("  - Clic gauche détecté!")
			if is_unlocked:
				print("  - Location déverrouillée, émission signal clicked")
				clicked.emit(self)
			else:
				print("  - ❌ Location verrouillée, pas de signal")

func _on_mouse_entered() -> void:
	if is_unlocked:
		is_hovered = true
		_update_visuals()
		hovered.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	_update_visuals()
	unhovered.emit(self)

# ============================================================================
# GETTERS
# ============================================================================

func get_location_id() -> String:
	return location_id

func get_location_name() -> String:
	return location_name

func get_connections() -> Array:
	return location_data.get("connections", [])
