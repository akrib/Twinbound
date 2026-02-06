extends Node3D
## BattleUnit3D - Unité de combat avec sprite billboard
## ✅ VERSION FINALE : Mana sans regen + Repos géré globalement

class_name BattleUnit3D

# ============================================================================
# ENUMS
# ============================================================================

enum TorusState {
	CAN_ACT_AND_MOVE,
	CAN_ACT_ONLY,
	CAN_MOVE_ONLY,
	CANNOT_ACT,
	SELECTED,
	ENEMY_TURN
}

# ============================================================================
# SIGNAUX
# ============================================================================

signal died()
signal health_changed(new_hp: int, max_hp: int)
signal mana_changed(new_mana: int, max_mana: int)
signal selected_changed(is_selected: bool)
signal status_effect_applied(effect_name: String)
signal status_effect_removed(effect_name: String)

# ============================================================================
# CONFIGURATION VISUELLE
# ============================================================================

const TILE_SIZE_DEFAULT: float = 1.0
const SPRITE_HEIGHT_DEFAULT: float = 0.2
const SHADOW_OPACITY: float = 0.3
const HP_BAR_WIDTH_RATIO: float = 0.8
const HP_BAR_HEIGHT_OFFSET: float = 0.6

const AURA_PETAL_COUNT := 6
const AURA_HEIGHT := 2.5
const AURA_BASE_RADIUS := 0.4
const AURA_RADIUS_STEP := 0.15
const AURA_ALPHA_MIN := 0.15
const AURA_ALPHA_MAX := 0.45
const DUO_AURA_LIFETIME := 2.0

# Couleurs du torus
const TORUS_COLORS: Dictionary = {
	TorusState.CAN_ACT_AND_MOVE: Color.GREEN,
	TorusState.CAN_ACT_ONLY: Color.YELLOW,
	TorusState.CAN_MOVE_ONLY: Color.CYAN,
	TorusState.CANNOT_ACT: Color.GRAY,
	TorusState.SELECTED: Color.RED,
	TorusState.ENEMY_TURN: Color.GRAY
}

# Respiration
const BREATH_INTENSITY: float = 0.05
const BREATH_DURATION_MIN: float = 2.5
const BREATH_DURATION_MAX: float = 3.5
const BREATH_DELAY_MAX: float = 2.0

const BREATH_SPEED_HEALTHY: float = 1.0
const BREATH_SPEED_WOUNDED: float = 1.5
const BREATH_SPEED_CRITICAL: float = 2.5

# ✅ Couleurs de mana par type
const MANA_COLORS: Dictionary = {
	"neutral": Color(0.8, 0.8, 1.0),
	"fire": Color(1.0, 0.3, 0.1),
	"ice": Color(0.2, 0.7, 1.0),
	"lightning": Color(1.0, 1.0, 0.3),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.7, 1.0, 0.8),
	"light": Color(1.0, 1.0, 0.9),
	"dark": Color(0.3, 0.1, 0.4),
}

# ============================================================================
# PROPRIÉTÉS
# ============================================================================

var tile_size: float = TILE_SIZE_DEFAULT
var sprite_height: float = SPRITE_HEIGHT_DEFAULT

# Identité
var unit_name: String = "Unit"
var is_player_unit: bool = false
var unit_id: String = ""

# Stats
var max_hp: int = 100
var current_hp: int = 100
var attack_power: int = 20
var defense_power: int = 10
var movement_range: int = 5
var attack_range: int = 1

# ✅ Stats de Mana (SANS régénération automatique)
var max_mana: int = 100
var current_mana: int = 100
var mana_type: String = "neutral"

# État
var movement_used: bool = false
var action_used: bool = false
var has_acted_this_turn: bool = false
var grid_position: Vector2i = Vector2i(0, 0)

# Capacités & Effets
var abilities: Array[String] = []
var status_effects: Dictionary = {}

# Apparence
var unit_color: Color = Color.BLUE
var is_selected: bool = false
var current_torus_state: TorusState = TorusState.CAN_ACT_AND_MOVE

# Sprite externe
var sprite_path: String = "res://asset/unit/unit.png"
var sprite_frame: int = 20
var sprite_hframes: int = 7
var sprite_vframes: int = 3

# Anneaux équipés
var equipped_materialization_ring: String = "mat_basic_line"
var equipped_channeling_ring: String = "chan_neutral"

# Progression
var level: int = 1
var xp: int = 0

# ============================================================================
# RÉFÉRENCES VISUELLES 3D
# ============================================================================

var sprite_3d: Sprite3D
var hp_bar_container: Node3D
var hp_bar_3d: MeshInstance3D
var hp_bar_bg: MeshInstance3D
var mana_bar_3d: MeshInstance3D
var mana_bar_bg: MeshInstance3D
var team_indicator: MeshInstance3D
var selection_indicator: MeshInstance3D
var shadow_sprite: Sprite3D

# Cache de materials
var torus_material: StandardMaterial3D
var hp_bar_material: StandardMaterial3D
var mana_bar_material: StandardMaterial3D

var defend_indicator: Sprite3D = null  # Diamant bleu (défense)
var prepared_indicator: Sprite3D = null  # Diamant rouge (préparé)
# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	if unit_id == "":
		unit_id = unit_name + "_" + str(Time.get_ticks_msec())
	
	_create_visuals_3d()
	_update_hp_bar()
	_update_mana_bar()
	
	GameRoot.global_logger.debug("BATTLE_UNIT", "Unité %s initialisée (ID: %s, Mana: %s)" % [unit_name, unit_id, mana_type])

# ============================================================================
# CRÉATION DES VISUELS 3D (IDENTIQUE)
# ============================================================================

func _create_visuals_3d() -> void:
	shadow_sprite = Sprite3D.new()
	shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	shadow_sprite.texture = _create_circle_texture(64, Color(0, 0, 0, SHADOW_OPACITY))
	shadow_sprite.pixel_size = 0.02
	shadow_sprite.rotation.x = -PI / 2
	shadow_sprite.position.y = 0.05
	shadow_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow_sprite)
	
	sprite_3d = Sprite3D.new()
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.pixel_size = 0.04
	sprite_3d.position.y = sprite_height
	sprite_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_load_sprite_texture()
	add_child(sprite_3d)
	
	selection_indicator = _create_selection_ring()
	selection_indicator.visible = true
	add_child(selection_indicator)
	
	_create_status_bars()
	_create_collision()
	
	visible = true
	show()
	
	_start_breathing_animation()
	_create_state_indicators()
	GameRoot.global_logger.debug("BATTLE_UNIT", "Visuels créés pour %s" % unit_name)

func _load_sprite_texture() -> void:
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var external_texture = load(sprite_path) as Texture2D
		
		if external_texture:
			sprite_3d.texture = external_texture
			sprite_3d.hframes = sprite_hframes
			sprite_3d.vframes = sprite_vframes
			sprite_3d.frame = sprite_frame
			GameRoot.global_logger.info("BATTLE_UNIT", "Sprite externe chargé : %s (frame %d)" % [sprite_path, sprite_frame])
			return
	
	sprite_3d.texture = _create_unit_texture()
	sprite_3d.hframes = 1
	sprite_3d.vframes = 1
	sprite_3d.frame = 0
	GameRoot.global_logger.warning("BATTLE_UNIT", "Sprite fallback utilisé pour %s" % unit_name)

func _create_unit_texture() -> ImageTexture:
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for y in range(128):
		for x in range(128):
			var dx = x - 64
			var dy = y - 64
			var dist = sqrt(dx*dx + dy*dy)
			
			if dist < 50:
				var alpha = 1.0 - (dist / 50.0) * 0.3
				image.set_pixel(x, y, Color(unit_color.r, unit_color.g, unit_color.b, alpha))
			
			if dist > 45 and dist < 50:
				image.set_pixel(x, y, unit_color.darkened(0.5))
	
	return ImageTexture.create_from_image(image)

func _create_circle_texture(size: int, color: Color) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = size / 2
	for y in range(size):
		for x in range(size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(dx*dx + dy*dy)
			
			if dist < center:
				var alpha = color.a * (1.0 - dist / center)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	return ImageTexture.create_from_image(image)

func _create_selection_ring() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	
	var torus = TorusMesh.new()
	torus.inner_radius = tile_size * 0.35
	torus.outer_radius = tile_size * 0.45
	torus.rings = 24
	torus.ring_segments = 48
	
	mesh_instance.mesh = torus
	mesh_instance.rotation_degrees.y = -90
	mesh_instance.position.y = -0.4
	
	torus_material = StandardMaterial3D.new()
	torus_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus_material.emission_enabled = true
	torus_material.emission_energy_multiplier = 2.0
	
	mesh_instance.set_surface_override_material(0, torus_material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance

func _create_status_bars() -> void:
	hp_bar_container = Node3D.new()
	hp_bar_container.position = Vector3(0, sprite_height + HP_BAR_HEIGHT_OFFSET, 0)
	hp_bar_container.top_level = false
	add_child(hp_bar_container)
	
	# Fond HP
	hp_bar_bg = MeshInstance3D.new()
	var bg_box = BoxMesh.new()
	bg_box.size = Vector3(tile_size * HP_BAR_WIDTH_RATIO, 0.08, 0.02)
	hp_bar_bg.mesh = bg_box
	
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.2, 0.2, 0.2)
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	hp_bar_bg.set_surface_override_material(0, bg_material)
	hp_bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar_container.add_child(hp_bar_bg)
	
	# Barre HP
	hp_bar_3d = MeshInstance3D.new()
	var hp_box = BoxMesh.new()
	hp_box.size = Vector3(tile_size * HP_BAR_WIDTH_RATIO, 0.06, 0.04)
	hp_bar_3d.mesh = hp_box
	hp_bar_3d.position.z = 0.03
	
	hp_bar_material = StandardMaterial3D.new()
	hp_bar_material.albedo_color = Color.GREEN
	hp_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bar_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hp_bar_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	hp_bar_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	hp_bar_material.no_depth_test = false
	hp_bar_3d.set_surface_override_material(0, hp_bar_material)
	hp_bar_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar_3d.sorting_offset = 0.1
	hp_bar_container.add_child(hp_bar_3d)
	
	# Fond Mana
	mana_bar_bg = MeshInstance3D.new()
	var mana_bg_box = BoxMesh.new()
	mana_bg_box.size = Vector3(tile_size * HP_BAR_WIDTH_RATIO, 0.06, 0.02)
	mana_bar_bg.mesh = mana_bg_box
	mana_bar_bg.position.y = -0.12
	
	var mana_bg_material = StandardMaterial3D.new()
	mana_bg_material.albedo_color = Color(0.15, 0.15, 0.2)
	mana_bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mana_bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mana_bg_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mana_bar_bg.set_surface_override_material(0, mana_bg_material)
	mana_bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar_container.add_child(mana_bar_bg)
	
	# Barre Mana
	mana_bar_3d = MeshInstance3D.new()
	var mana_box = BoxMesh.new()
	mana_box.size = Vector3(tile_size * HP_BAR_WIDTH_RATIO, 0.05, 0.04)
	mana_bar_3d.mesh = mana_box
	mana_bar_3d.position = Vector3(0, -0.12, 0.03)
	
	mana_bar_material = StandardMaterial3D.new()
	mana_bar_material.albedo_color = MANA_COLORS.get(mana_type, Color.CYAN)
	mana_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mana_bar_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mana_bar_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mana_bar_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mana_bar_material.no_depth_test = false
	mana_bar_material.emission_enabled = true
	mana_bar_material.emission = mana_bar_material.albedo_color * 0.5
	mana_bar_3d.set_surface_override_material(0, mana_bar_material)
	mana_bar_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mana_bar_3d.sorting_offset = 0.1
	hp_bar_container.add_child(mana_bar_3d)
	
	# Team Indicator
	team_indicator = MeshInstance3D.new()
	var indicator_box = BoxMesh.new()
	indicator_box.size = Vector3(0.12, 0.12, 0.04)
	team_indicator.mesh = indicator_box
	
	var bar_width = tile_size * HP_BAR_WIDTH_RATIO
	team_indicator.position = Vector3(bar_width / 2 + 0.08, -0.06, 0.03)
	
	var team_material = StandardMaterial3D.new()
	team_material.albedo_color = Color.GREEN if is_player_unit else Color.RED
	team_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	team_material.emission_enabled = true
	team_material.emission = team_material.albedo_color * 0.5
	team_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	team_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	team_indicator.set_surface_override_material(0, team_material)
	team_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar_container.add_child(team_indicator)

func _create_collision() -> void:
	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	
	var shape = CylinderShape3D.new()
	shape.radius = tile_size * 0.4
	shape.height = sprite_height * 2
	collision_shape.shape = shape
	collision_shape.position.y = sprite_height
	
	area.add_child(collision_shape)
	add_child(area)
	
	area.set_meta("unit", self)
	area.collision_layer = 2
	area.collision_mask = 0

# ============================================================================
# RESPIRATION (IDENTIQUE)
# ============================================================================

func _start_breathing_animation() -> void:
	if not sprite_3d:
		return
	
	await get_tree().create_timer(randf_range(0.0, BREATH_DELAY_MAX)).timeout
	
	var hp_percent = get_hp_percentage()
	var breath_speed_multiplier: float
	
	if hp_percent > 0.6:
		breath_speed_multiplier = BREATH_SPEED_HEALTHY
	elif hp_percent > 0.3:
		breath_speed_multiplier = BREATH_SPEED_WOUNDED
	else:
		breath_speed_multiplier = BREATH_SPEED_CRITICAL
	
	var base_breath_duration = randf_range(BREATH_DURATION_MIN, BREATH_DURATION_MAX)
	var breath_duration = base_breath_duration / breath_speed_multiplier
	
	var is_height_breathing = randf() < 0.5
	
	var scale_min = 1.0 - BREATH_INTENSITY
	var scale_max = 1.0 + BREATH_INTENSITY
	
	var base_position_y = sprite_3d.position.y
	set_meta("breathing_base_y", base_position_y)
	
	var tween = sprite_3d.create_tween()
	tween.set_loops()
	
	if is_height_breathing:
		tween.tween_method(_set_height_scale_keep_bottom, 1.0, scale_max, breath_duration / 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_method(_set_height_scale_keep_bottom, scale_max, scale_min, breath_duration / 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_method(_set_height_scale_keep_bottom, scale_min, 1.0, breath_duration / 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_property(sprite_3d, "scale:x", scale_max, breath_duration / 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite_3d, "scale:x", scale_min, breath_duration / 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite_3d, "scale:x", 1.0, breath_duration / 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	set_meta("breathing_tween", tween)

func _set_height_scale_keep_bottom(new_scale_y: float) -> void:
	if not sprite_3d:
		return
	
	var base_y = get_meta("breathing_base_y", sprite_height)
	var sprite_visual_height = 1.0
	var delta_y = (new_scale_y - 1.0) * sprite_visual_height / 2.0
	
	sprite_3d.scale.y = new_scale_y
	sprite_3d.position.y = base_y + delta_y

# ============================================================================
# PROCESS
# ============================================================================

func _process(_delta: float) -> void:
	if not hp_bar_container:
		return
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		hp_bar_container.global_transform.basis = camera.global_transform.basis

# ============================================================================
# TORUS
# ============================================================================

func update_torus_state(is_current_turn: bool) -> void:
	if not selection_indicator:
		return
	
	if is_selected:
		current_torus_state = TorusState.SELECTED
	elif not is_current_turn:
		current_torus_state = TorusState.ENEMY_TURN
	elif not can_move() and not can_act():
		current_torus_state = TorusState.CANNOT_ACT
	elif can_act() and not can_move():
		current_torus_state = TorusState.CAN_ACT_ONLY
	elif can_move() and not can_act():
		current_torus_state = TorusState.CAN_MOVE_ONLY
	else:
		current_torus_state = TorusState.CAN_ACT_AND_MOVE
	
	_apply_torus_color()

func _apply_torus_color() -> void:
	if not torus_material:
		return
	
	var color = TORUS_COLORS.get(current_torus_state, Color.WHITE)
	torus_material.albedo_color = color
	torus_material.emission = color * 0.8

func set_selected(selected: bool) -> void:
	is_selected = selected
	update_torus_state(true)
	selected_changed.emit(selected)

# ============================================================================
# SANTÉ
# ============================================================================

func take_damage(damage: int) -> int:
	var actual_damage = max(1, damage - defense_power)
	current_hp = max(0, current_hp - actual_damage)
	_update_hp_bar()
	
	health_changed.emit(current_hp, max_hp)
	
	GameRoot.global_logger.info("BATTLE_UNIT", "%s prend %d dégâts (HP: %d/%d)" % [unit_name, actual_damage, current_hp, max_hp])
	
	_animate_damage()
	
	if current_hp <= 0:
		die()
	
	return actual_damage

func heal(amount: int) -> int:
	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)
	var actual_heal = current_hp - old_hp
	
	_update_hp_bar()
	health_changed.emit(current_hp, max_hp)
	
	GameRoot.global_logger.info("BATTLE_UNIT", "%s soigné de %d HP" % [unit_name, actual_heal])
	_animate_heal()
	
	return actual_heal

func die() -> void:
	GameRoot.global_logger.info("BATTLE_UNIT", "%s est mort" % unit_name)
	_animate_death()
	died.emit()

func is_alive() -> bool:
	return current_hp > 0

func get_hp_percentage() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

# ============================================================================
# ✅ SYSTÈME DE MANA (SANS RÉGÉNÉRATION)
# ============================================================================

func consume_mana(amount: int) -> bool:
	"""
	Consomme du mana
	@return true si succès, false si mana insuffisant
	"""
	if current_mana < amount:
		GameRoot.global_logger.warning("BATTLE_UNIT", "%s : mana insuffisant (%d/%d)" % [unit_name, current_mana, amount])
		return false
	
	current_mana -= amount
	current_mana = max(0, current_mana)
	
	_update_mana_bar()
	mana_changed.emit(current_mana, max_mana)
	
	GameRoot.global_logger.info("BATTLE_UNIT", "%s consomme %d mana (reste: %d/%d)" % [unit_name, amount, current_mana, max_mana])
	
	_animate_mana_consumption()
	
	return true

func restore_mana(amount: int) -> int:
	"""
	Restaure du mana (via action Puiser ou potion)
	@return Quantité réellement restaurée
	"""
	var old_mana = current_mana
	current_mana = min(max_mana, current_mana + amount)
	var actual_restore = current_mana - old_mana
	
	_update_mana_bar()
	mana_changed.emit(current_mana, max_mana)
	
	if actual_restore > 0:
		GameRoot.global_logger.info("BATTLE_UNIT", "%s restaure %d mana (%d/%d)" % [unit_name, actual_restore, current_mana, max_mana])
		_animate_mana_restore()
	
	return actual_restore

func get_mana_percentage() -> float:
	if max_mana <= 0:
		return 0.0
	return float(current_mana) / float(max_mana)

func has_enough_mana(amount: int) -> bool:
	return current_mana >= amount

func get_mana_color() -> Color:
	return MANA_COLORS.get(mana_type, Color.CYAN)

# ============================================================================
# BARRE DE HP
# ============================================================================

func _update_hp_bar() -> void:
	if not hp_bar_3d or not hp_bar_3d.mesh or not hp_bar_material:
		return
	
	if max_hp <= 0:
		return
	
	var hp_percent = get_hp_percentage()
	
	var bar_max_width = tile_size * HP_BAR_WIDTH_RATIO
	var box_mesh = hp_bar_3d.mesh as BoxMesh
	
	if box_mesh:
		var current_width = bar_max_width * hp_percent
		box_mesh.size.x = current_width
		
		var offset = (bar_max_width - current_width) / 2.0
		hp_bar_3d.position.x = -offset
	
	if hp_percent > 0.6:
		hp_bar_material.albedo_color = Color.GREEN
	elif hp_percent > 0.3:
		hp_bar_material.albedo_color = Color.YELLOW
	else:
		hp_bar_material.albedo_color = Color.RED

# ============================================================================
# BARRE DE MANA
# ============================================================================

func _update_mana_bar() -> void:
	if not mana_bar_3d or not mana_bar_3d.mesh or not mana_bar_material:
		return
	
	if max_mana <= 0:
		return
	
	var mana_percent = get_mana_percentage()
	
	var bar_max_width = tile_size * HP_BAR_WIDTH_RATIO
	var box_mesh = mana_bar_3d.mesh as BoxMesh
	
	if box_mesh:
		var current_width = bar_max_width * mana_percent
		box_mesh.size.x = current_width
		
		var offset = (bar_max_width - current_width) / 2.0
		mana_bar_3d.position.x = -offset
	
	var base_color = get_mana_color()
	
	if mana_percent < 0.3:
		base_color = base_color.darkened(0.3)
	
	mana_bar_material.albedo_color = base_color
	mana_bar_material.emission = base_color * 0.5

# ============================================================================
# ACTIONS & ÉTAT
# ============================================================================

func can_move() -> bool:
	return is_alive() and not movement_used

func can_act() -> bool:
	return is_alive() and not action_used

func can_do_anything() -> bool:
	return can_move() or can_act()

func reset_for_new_turn() -> void:
	"""Réinitialise l'unité pour un nouveau tour"""
	
	movement_used = false
	action_used = false
	has_acted_this_turn = false
	
	# Retirer la défense
	if has_meta("is_defending"):
		remove_meta("is_defending")
		remove_meta("defense_bonus")
	
	_process_status_effects()
	update_torus_state(true)
	update_state_indicators() 



func _process_status_effects() -> void:
	var effects_to_remove: Array[String] = []
	
	for effect_name in status_effects:
		status_effects[effect_name] -= 1
		if status_effects[effect_name] <= 0:
			effects_to_remove.append(effect_name)
	
	for effect_name in effects_to_remove:
		remove_status_effect(effect_name)

# ============================================================================
# EFFETS DE STATUT
# ============================================================================

func add_status_effect(effect_name: String, duration: int) -> void:
	status_effects[effect_name] = duration
	status_effect_applied.emit(effect_name)
	GameRoot.global_logger.info("BATTLE_UNIT", "%s : effet ajouté : %s" % [unit_name, effect_name])

func remove_status_effect(effect_name: String) -> void:
	if status_effects.has(effect_name):
		status_effects.erase(effect_name)
		status_effect_removed.emit(effect_name)
		GameRoot.global_logger.info("BATTLE_UNIT", "%s : effet retiré : %s" % [unit_name, effect_name])

func has_status_effect(effect_name: String) -> bool:
	return status_effects.has(effect_name)

# ============================================================================
# ANIMATIONS
# ============================================================================

func _animate_damage() -> void:
	var tween = create_tween()
	tween.tween_property(sprite_3d, "modulate", Color(1, 0.3, 0.3), 0.1)
	tween.tween_property(sprite_3d, "modulate", Color(1, 1, 1), 0.1)

func _animate_heal() -> void:
	var tween = create_tween()
	tween.tween_property(sprite_3d, "modulate", Color(0.3, 1, 0.3), 0.1)
	tween.tween_property(sprite_3d, "modulate", Color(1, 1, 1), 0.1)

func _animate_mana_consumption() -> void:
	if not mana_bar_3d:
		return
	
	var tween = create_tween()
	tween.tween_property(mana_bar_3d, "scale", Vector3(0.9, 0.9, 1.0), 0.1)
	tween.tween_property(mana_bar_3d, "scale", Vector3.ONE, 0.1)

func _animate_mana_restore() -> void:
	if not mana_bar_3d:
		return
	
	var tween = create_tween()
	tween.tween_property(mana_bar_3d, "modulate", Color(1.5, 1.5, 1.5), 0.15)
	tween.tween_property(mana_bar_3d, "modulate", Color.WHITE, 0.15)

func _animate_death() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	if sprite_3d:
		tween.tween_property(sprite_3d, "modulate:a", 0.0, 0.5)
	
	if hp_bar_container:
		tween.tween_property(hp_bar_container, "scale", Vector3.ZERO, 0.5)
	
	if selection_indicator:
		tween.tween_property(selection_indicator, "scale", Vector3.ZERO, 0.3)
	
	tween.tween_property(self, "scale", Vector3(0.5, 0.5, 0.5), 0.5)
	
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

# ============================================================================
# DONNÉES
# ============================================================================

func get_unit_data() -> Dictionary:
	return {
		"id": unit_id,
		"name": unit_name,
		"is_player": is_player_unit,
		"position": grid_position,
		"hp": current_hp,
		"max_hp": max_hp,
		"mana": current_mana,
		"max_mana": max_mana,
		"mana_type": mana_type,
		"attack": attack_power,
		"defense": defense_power,
		"movement": movement_range,
		"range": attack_range,
		"abilities": abilities.duplicate(),
		"status_effects": status_effects.duplicate(),
		"can_move": can_move(),
		"can_act": can_act()
	}

func initialize_unit(data: Dictionary) -> void:
	if data.has("name"):
		unit_name = data.name
	if data.has("id"):
		unit_id = data.id
	elif unit_id == "":
		unit_id = unit_name + "_" + str(Time.get_ticks_msec())
	
	if data.has("is_player"):
		is_player_unit = data.is_player
	
	if data.has("position"):
		grid_position = data.position
	
	var temp_max_hp = 100
	var temp_current_hp = -1
	var temp_max_mana = 100
	var temp_current_mana = -1
	
	if data.has("stats"):
		var stats = data.stats
		if stats.has("hp"):
			temp_max_hp = stats.hp
		if stats.has("attack"):
			attack_power = stats.attack
		if stats.has("defense"):
			defense_power = stats.defense
		if stats.has("movement"):
			movement_range = stats.movement
		if stats.has("range"):
			attack_range = stats.range
		if stats.has("mana"):
			temp_max_mana = stats.mana
	
	if data.has("max_hp"):
		temp_max_hp = data.max_hp
	if data.has("hp"):
		temp_current_hp = data.hp
	if data.has("max_mana"):
		temp_max_mana = data.max_mana
	if data.has("mana"):
		temp_current_mana = data.mana
	if data.has("mana_type"):
		mana_type = data.mana_type
	
	max_hp = temp_max_hp
	current_hp = temp_current_hp if temp_current_hp >= 0 else max_hp
	current_hp = min(current_hp, max_hp)
	
	max_mana = temp_max_mana
	current_mana = temp_current_mana if temp_current_mana >= 0 else max_mana
	current_mana = min(current_mana, max_mana)
	
	if data.has("attack"):
		attack_power = data.attack
	if data.has("defense"):
		defense_power = data.defense
	if data.has("movement"):
		movement_range = data.movement
	if data.has("range"):
		attack_range = data.range
	
	if data.has("abilities"):
		abilities.clear()
		var abilities_array = data.abilities
		if abilities_array is Array:
			for ability in abilities_array:
				if ability is String:
					abilities.append(ability)
	
	if data.has("status_effects"):
		status_effects.clear()
		var effects = data.status_effects
		if effects is Dictionary:
			for effect_name in effects:
				status_effects[effect_name] = effects[effect_name]
	
	if data.has("sprite_path"):
		sprite_path = data.sprite_path
	if data.has("sprite_frame"):
		sprite_frame = data.sprite_frame
	if data.has("sprite_hframes"):
		sprite_hframes = data.sprite_hframes
	if data.has("sprite_vframes"):
		sprite_vframes = data.sprite_vframes
	
	if data.has("materialization_ring"):
		equipped_materialization_ring = data.materialization_ring
	if data.has("channeling_ring"):
		equipped_channeling_ring = data.channeling_ring
	
	if data.has("color"):
		if typeof(data.color) == TYPE_DICTIONARY:
			unit_color = Color(
				data.color.get("r", 1.0),
				data.color.get("g", 1.0),
				data.color.get("b", 1.0),
				data.color.get("a", 1.0)
			)
		else:
			unit_color = data.color
	else:
		unit_color = Color(0.2, 0.2, 0.8) if is_player_unit else Color(0.8, 0.2, 0.2)
	
	level = data.get("level", 1)
	xp = data.get("xp", 0)
	
	GameRoot.global_logger.info("BATTLE_UNIT", "Unité initialisée : %s (ID: %s)" % [unit_name, unit_id])
	GameRoot.global_logger.debug("BATTLE_UNIT", "  → HP: %d/%d" % [current_hp, max_hp])
	GameRoot.global_logger.debug("BATTLE_UNIT", "  → Mana: %d/%d (%s)" % [current_mana, max_mana, mana_type])

func award_xp(amount: int) -> void:
	if not is_player_unit:
		return
	
	xp += amount
	GameRoot.global_logger.info("BATTLE_UNIT", "%s : +%d XP (Total: %d)" % [unit_name, amount, xp])
	GameRoot.team_manager.add_xp(unit_id, amount)

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	if has_meta("breathing_tween"):
		var tween = get_meta("breathing_tween") as Tween
		if tween and tween.is_valid():
			tween.kill()
	
	if has_meta("blink_tween"):
		var tween = get_meta("blink_tween") as Tween
		if tween and tween.is_valid():
			tween.kill()
	
	GameRoot.global_logger.debug("BATTLE_UNIT", "Unité %s nettoyée" % unit_name)

# ============================================================================
# DUO AURA (conservé)
# ============================================================================

func show_duo_aura(is_enemy_duo: bool = false) -> void:
	if not sprite_3d:
		return

	if has_meta("duo_aura"):
		var old_aura := get_meta("duo_aura") as Node3D
		if old_aura and is_instance_valid(old_aura):
			_fade_and_destroy_duo_aura(old_aura)
		remove_meta("duo_aura")

	var aura := Node3D.new()
	aura.name = "DuoAura"
	add_child(aura)
	set_meta("duo_aura", aura)

	var base_color := Color(1.0, 0.25, 0.25) if is_enemy_duo else Color(0.25, 0.6, 1.0)

	var beam_count := 14
	var radius := 0.65
	var height := 1.6

	for i in range(beam_count):
		var beam := MeshInstance3D.new()

		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.05
		mesh.height = height * randf_range(0.85, 1.1)
		mesh.radial_segments = 12
		beam.mesh = mesh
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var angle := TAU * float(i) / beam_count
		beam.position = Vector3(
			cos(angle) * radius,
			mesh.height * 0.5,
			sin(angle) * radius
		)

		beam.position.x += randf_range(-0.05, 0.05)
		beam.position.z += randf_range(-0.05, 0.05)

		beam.rotation.y = angle

		var tilt_strength := 0.25
		beam.rotate_object_local(Vector3.RIGHT, randf_range(-tilt_strength, tilt_strength))
		beam.rotate_object_local(Vector3.FORWARD, randf_range(-tilt_strength, tilt_strength))

		var mat := ShaderMaterial.new()
		mat.shader = preload("res://asset/shader/aura_ring.gdshader")
		mat.set_shader_parameter("base_color", base_color)
		mat.set_shader_parameter("time_offset", randf() * 6.0)
		mat.set_shader_parameter("alpha_multiplier", 0.0)
		beam.material_override = mat

		aura.add_child(beam)

		var fade := aura.create_tween()
		fade.tween_property(
			mat,
			"shader_parameter/alpha_multiplier",
			1.0,
			0.3
		).set_delay(i * 0.025).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		var sway := beam.create_tween()
		sway.set_loops()
		sway.tween_property(
			beam,
			"rotation:x",
			beam.rotation.x + randf_range(-0.05, 0.05),
			randf_range(1.8, 2.8)
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		sway.tween_property(
			beam,
			"rotation:z",
			beam.rotation.z + randf_range(-0.05, 0.05),
			randf_range(1.8, 2.8)
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pulse := aura.create_tween()
	pulse.set_loops()
	pulse.tween_property(aura, "scale", Vector3(1.05, 1.0, 1.05), 0.9)
	pulse.tween_property(aura, "scale", Vector3.ONE, 0.9)

	var rot := aura.create_tween()
	rot.set_loops()
	rot.tween_property(aura, "rotation:y", TAU, 5.0)

	await get_tree().create_timer(DUO_AURA_LIFETIME).timeout

	if is_instance_valid(aura):
		_fade_and_destroy_duo_aura(aura)

func _fade_and_destroy_duo_aura(aura: Node3D) -> void:
	if not aura or not is_instance_valid(aura):
		return

	var t := aura.create_tween()
	t.tween_property(aura, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	t.tween_callback(func():
		if is_instance_valid(aura):
			aura.queue_free()
	)

func hide_duo_aura() -> void:
	if not has_meta("duo_aura"):
		return

	var aura := get_meta("duo_aura") as Node3D
	if aura and is_instance_valid(aura):
		_fade_and_destroy_duo_aura(aura)

	remove_meta("duo_aura")

func _create_state_indicators() -> void:
	"""Crée les diamants d'état au-dessus de l'unité"""
	
	# Diamant bleu (défense)
	defend_indicator = Sprite3D.new()
	defend_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	defend_indicator.texture = _create_diamond_texture(Color(0.3, 0.6, 1.0))  # Bleu
	defend_indicator.pixel_size = 0.02
	defend_indicator.position = Vector3(0, sprite_height + 1.2, 0)
	defend_indicator.visible = false
	add_child(defend_indicator)
	
	# Diamant rouge (préparé)
	prepared_indicator = Sprite3D.new()
	prepared_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prepared_indicator.texture = _create_diamond_texture(Color(1.0, 0.3, 0.3))  # Rouge
	prepared_indicator.pixel_size = 0.02
	prepared_indicator.position = Vector3(0, sprite_height + 1.2, 0)
	prepared_indicator.visible = false
	add_child(prepared_indicator)
	
func _create_diamond_texture(color: Color) -> ImageTexture:
	"""Crée une texture de diamant"""
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = size / 2
	
	# Dessiner un losange
	for y in range(size):
		for x in range(size):
			var dx = abs(x - center)
			var dy = abs(y - center)
			
			# Distance Manhattan pour former un losange
			if dx + dy < center:
				var edge_dist = center - (dx + dy)
				var alpha = 1.0
				
				# Bordure plus sombre
				if edge_dist < 3:
					image.set_pixel(x, y, color.darkened(0.5))
				else:
					image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

func update_state_indicators() -> void:
	"""Met à jour la visibilité des indicateurs d'état"""
	
	if defend_indicator:
		defend_indicator.visible = has_meta("is_defending")
	
	if prepared_indicator:
		prepared_indicator.visible = has_meta("is_prepared")

# Modifier reset_for_new_turn pour mettre à jour les indicateurs :
