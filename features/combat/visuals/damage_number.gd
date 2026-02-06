extends Node3D
## DamageNumber - Affiche un nombre de dégâts avec animation parabolique

class_name DamageNumber

var damage_value: int = 0
var label_3d: Label3D
var lifetime: float = 1.5  # Durée totale de l'animation
var elapsed: float = 0.0

# Paramètres de la parabole
var start_position: Vector3
var peak_height: float = 2.0
var horizontal_offset: Vector3 = Vector3(0, 0, 0)

func _ready() -> void:
	label_3d = Label3D.new()
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.render_priority = 10
	label_3d.outline_size = 4
	label_3d.outline_modulate = Color.BLACK
	add_child(label_3d)

	label_3d.font_size = 48
	label_3d.modulate = Color.YELLOW
	label_3d.text = str(damage_value)

	# ✅ Maintenant le node est dans l’arbre
	global_position = start_position


func _process(delta: float) -> void:
	elapsed += delta
	
	if elapsed >= lifetime:
		queue_free()
		return
	
	# Progression normalisée (0.0 -> 1.0)
	var t = elapsed / lifetime
	
	# Calcul de la parabole (y = -4h * t * (t - 1))
	var parabola = -4.0 * peak_height * t * (t - 1.0)
	
	# Position finale
	var final_pos = start_position + horizontal_offset * t
	final_pos.y += parabola
	
	global_position = final_pos
	
	# Fade out sur la phase descendante (après t = 0.5)
	if t > 0.5:
		var fade = 1.0 - (t - 0.5) * 2.0  # 1.0 -> 0.0
		label_3d.modulate.a = fade

func setup(damage: int, spawn_pos: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	"""Configure le nombre de dégâts"""
	damage_value = damage
	#global_position = spawn_pos
	start_position = spawn_pos
	horizontal_offset = offset
