extends Button
## DuoAttackOption - Bouton unique pour sélectionner une combinaison Mana + Arme

class_name DuoAttackOption

signal option_selected(mana_ring_id: String, weapon_ring_id: String)
signal option_hovered(partner: BattleUnit3D)
signal option_unhovered(partner: BattleUnit3D)  # ✅ NOUVEAU

@onready var mana_name_label: Label = $HBoxContainer/ManaSection/ManaName
@onready var weapon_name_label: Label = $HBoxContainer/WeaponSection/WeaponName

var mana_ring_id: String = ""
var weapon_ring_id: String = ""
var partner_unit: BattleUnit3D = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)  # ✅ NOUVEAU

func setup(mana_data: Dictionary, weapon_data: Dictionary, partner: BattleUnit3D = null) -> void:
	"""Configure le bouton avec les données de mana et d'arme"""
	
	mana_ring_id = mana_data.get("ring_id", "")
	weapon_ring_id = weapon_data.get("ring_id", "")
	partner_unit = partner
	
	mana_name_label.text = mana_data.get("ring_name", "Inconnu")
	weapon_name_label.text = weapon_data.get("ring_name", "Inconnu")

func _on_pressed() -> void:
	option_selected.emit(mana_ring_id, weapon_ring_id)

func _on_mouse_entered() -> void:
	if partner_unit:
		option_hovered.emit(partner_unit)

# ✅ NOUVEAU
func _on_mouse_exited() -> void:
	if partner_unit:
		option_unhovered.emit(partner_unit)
