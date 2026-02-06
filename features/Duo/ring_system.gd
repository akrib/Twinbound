# scripts/systems/ring/ring_system.gd
extends Node
class_name RingSystem

## ⭐ MODULE CRITIQUE : Système des Anneaux
## Gère les anneaux de matérialisation et canalisation

# ============================================================================
# SIGNAUX
# ============================================================================

signal rings_loaded(count: int)
signal ring_equipped(unit_id: String, ring_id: String, slot: String)
signal attack_profile_generated(profile: AttackProfile)

# ============================================================================
# STRUCTURES DE DONNÉES
# ============================================================================

## Anneau de Matérialisation (forme d'attaque)
class MaterializationRing:
	var ring_id: String
	var ring_name: String
	var attack_shape: String  # "line", "cone", "circle", "cross"
	var base_range: int
	var area_size: int
	var description: String
	
	func _init(data: Dictionary):
		ring_id = data.get("ring_id", "")
		ring_name = data.get("ring_name", "Unknown Ring")
		attack_shape = data.get("attack_shape", "line")
		base_range = data.get("base_range", 1)
		area_size = data.get("area_size", 1)
		description = data.get("description", "")

## Anneau de Canalisation (effet mana)
class ChannelingRing:
	var ring_id: String
	var ring_name: String
	var mana_effect_id: String
	var mana_potency: float
	var effect_duration: float
	var description: String
	
	func _init(data: Dictionary):
		ring_id = data.get("ring_id", "")
		ring_name = data.get("ring_name", "Unknown Ring")
		mana_effect_id = data.get("mana_effect_id", "")
		mana_potency = data.get("mana_potency", 1.0)
		effect_duration = data.get("effect_duration", 3.0)
		description = data.get("description", "")

## Profil d'Attaque Combiné
class AttackProfile:
	var shape: String
	var range: int
	var area: int
	var mana_effect: String
	var potency: float
	var duration: float
	
	func _init():
		shape = "line"
		range = 1
		area = 1
		mana_effect = ""
		potency = 1.0
		duration = 3.0

# ============================================================================
# DONNÉES
# ============================================================================

var materialization_rings: Dictionary = {}  # ring_id -> MaterializationRing
var channeling_rings: Dictionary = {}  # ring_id -> ChannelingRing

var json_loader: JSONDataLoader = null

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	json_loader = JSONDataLoader.new()
	print("[RingSystem] ✅ Initialisé")

# ============================================================================
# CHARGEMENT
# ============================================================================

func load_rings_from_json(json_path: String) -> bool:
	"""
	Charge tous les anneaux depuis un fichier JSON
	
	Format attendu:
	{
		"materialization_rings": [...],
		"channeling_rings": [...]
	}
	"""
	
	var data = json_loader.load_json_file(json_path, true)
	
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		push_error("[RingSystem] ❌ Impossible de charger : ", json_path)
		return false
	
	# Charger anneaux de matérialisation
	if data.has("materialization_rings"):
		for ring_data in data.materialization_rings:
			var ring = MaterializationRing.new(ring_data)
			materialization_rings[ring.ring_id] = ring
	
	# Charger anneaux de canalisation
	if data.has("channeling_rings"):
		for ring_data in data.channeling_rings:
			var ring = ChannelingRing.new(ring_data)
			channeling_rings[ring.ring_id] = ring
	
	var total_count = materialization_rings.size() + channeling_rings.size()
	rings_loaded.emit(total_count)
	
	print("[RingSystem] ✅ Chargé : ", materialization_rings.size(), " matérialisation + ", channeling_rings.size(), " canalisation")
	
	return true

# ============================================================================
# GETTERS
# ============================================================================

func get_materialization_ring(ring_id: String) -> MaterializationRing:
	"""Retourne un anneau de matérialisation"""
	
	if materialization_rings.has(ring_id):
		return materialization_rings[ring_id]
	
	push_warning("[RingSystem] Anneau de matérialisation introuvable : ", ring_id)
	return null

func get_channeling_ring(ring_id: String) -> ChannelingRing:
	"""Retourne un anneau de canalisation"""
	
	if channeling_rings.has(ring_id):
		return channeling_rings[ring_id]
	
	push_warning("[RingSystem] Anneau de canalisation introuvable : ", ring_id)
	return null

func get_all_materialization_rings() -> Array:
	"""Retourne tous les anneaux de matérialisation"""
	return materialization_rings.values()

func get_all_channeling_rings() -> Array:
	"""Retourne tous les anneaux de canalisation"""
	return channeling_rings.values()

# ============================================================================
# GÉNÉRATION DE PROFIL D'ATTAQUE
# ============================================================================

func generate_attack_profile(mat_ring_id: String, chan_ring_id: String) -> AttackProfile:
	"""
	Combine deux anneaux pour générer un profil d'attaque
	
	@param mat_ring_id : ID de l'anneau de matérialisation
	@param chan_ring_id : ID de l'anneau de canalisation
	@return AttackProfile combiné
	"""
	
	var mat_ring = get_materialization_ring(mat_ring_id)
	var chan_ring = get_channeling_ring(chan_ring_id)
	
	var profile = AttackProfile.new()
	
	# Données de matérialisation
	if mat_ring:
		profile.shape = mat_ring.attack_shape
		profile.range = mat_ring.base_range
		profile.area = mat_ring.area_size
	
	# Données de canalisation
	if chan_ring:
		profile.mana_effect = chan_ring.mana_effect_id
		profile.potency = chan_ring.mana_potency
		profile.duration = chan_ring.effect_duration
	
	attack_profile_generated.emit(profile)
	
	return profile

# ============================================================================
# ÉQUIPEMENT (pour plus tard)
# ============================================================================

## Stockage temporaire des équipements
var unit_equipment: Dictionary = {}  # unit_id -> {"mat": ring_id, "chan": ring_id}

func equip_materialization_ring(unit_id: String, ring_id: String) -> bool:
	"""Équipe un anneau de matérialisation à une unité"""
	
	if not materialization_rings.has(ring_id):
		return false
	
	if not unit_equipment.has(unit_id):
		unit_equipment[unit_id] = {}
	
	unit_equipment[unit_id]["mat"] = ring_id
	ring_equipped.emit(unit_id, ring_id, "materialization")
	
	return true

func equip_channeling_ring(unit_id: String, ring_id: String) -> bool:
	"""Équipe un anneau de canalisation à une unité"""
	
	if not channeling_rings.has(ring_id):
		return false
	
	if not unit_equipment.has(unit_id):
		unit_equipment[unit_id] = {}
	
	unit_equipment[unit_id]["chan"] = ring_id
	ring_equipped.emit(unit_id, ring_id, "channeling")
	
	return true

func get_unit_rings(unit_id: String) -> Dictionary:
	"""Retourne les anneaux équipés par une unité"""
	return unit_equipment.get(unit_id, {})

# ============================================================================
# DEBUG
# ============================================================================

func debug_print_rings() -> void:
	"""Affiche tous les anneaux (debug)"""
	
	print("\n=== RingSystem - Anneaux ===")
	print("Matérialisation (", materialization_rings.size(), "):")
	for ring_id in materialization_rings:
		var ring = materialization_rings[ring_id]
		print("  - ", ring.ring_name, " (", ring.attack_shape, ", range:", ring.base_range, ")")
	
	print("\nCanalisation (", channeling_rings.size(), "):")
	for ring_id in channeling_rings:
		var ring = channeling_rings[ring_id]
		print("  - ", ring.ring_name, " (", ring.mana_effect_id, ", potency:", ring.mana_potency, ")")
	
	print("=============================\n")
