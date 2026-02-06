extends Node
## ItemModule - Gère les objets de combat
## Les objets servent à corriger une erreur, sauver une unité, créer une ouverture ponctuelle
## ⚠️ NE DOIVENT JAMAIS remplacer une attaque en duo, une préparation ou un bon placement

class_name ItemModule

# ============================================================================
# SIGNAUX
# ============================================================================

signal item_used(unit: BattleUnit3D, item_id: String, target: Variant)
signal item_failed(unit: BattleUnit3D, item_id: String, reason: String)

# ============================================================================
# ENUMS
# ============================================================================

enum ItemRarity {
	COMMON,      # Objets de base (soins, antidotes)
	RARE,        # Objets puissants (repositionnement, suppression état)
	VERY_RARE    # Objets exceptionnels (rupture de duo adverse)
}

enum ItemCategory {
	HEALING,          # Soins
	STATUS_CURE,      # Guérison d'états
	MOVEMENT,         # Repositionnement
	TACTICAL,         # Rupture de duo, etc.
	BUFF,            # Bonus temporaires
}

# ============================================================================
# DONNÉES DES OBJETS
# ============================================================================

const ITEM_DATABASE: Dictionary = {
	# === OBJETS COMMUNS ===
	"potion_hp_small": {
		"name": "Potion de Soin Mineure",
		"description": "Restaure 30 HP",
		"category": ItemCategory.HEALING,
		"rarity": ItemRarity.COMMON,
		"target_type": "ally_single",
		"effect": {
			"type": "heal",
			"value": 30
		},
		"icon": "res://asset/items/potion_small.png"
	},
	
	"potion_hp_medium": {
		"name": "Potion de Soin",
		"description": "Restaure 60 HP",
		"category": ItemCategory.HEALING,
		"rarity": ItemRarity.COMMON,
		"target_type": "ally_single",
		"effect": {
			"type": "heal",
			"value": 60
		},
		"icon": "res://asset/items/potion_medium.png"
	},
	
	"antidote": {
		"name": "Antidote",
		"description": "Soigne l'empoisonnement",
		"category": ItemCategory.STATUS_CURE,
		"rarity": ItemRarity.COMMON,
		"target_type": "ally_single",
		"effect": {
			"type": "cure_status",
			"status": "poison"
		},
		"icon": "res://asset/items/antidote.png"
	},
	
	"remedy": {
		"name": "Remède",
		"description": "Soigne tous les états négatifs",
		"category": ItemCategory.STATUS_CURE,
		"rarity": ItemRarity.COMMON,
		"target_type": "ally_single",
		"effect": {
			"type": "cure_all_status"
		},
		"icon": "res://asset/items/remedy.png"
	},
	
	# === OBJETS RARES ===
	"blink_stone": {
		"name": "Pierre de Téléportation",
		"description": "Repositionnement instantané (portée 5)",
		"category": ItemCategory.MOVEMENT,
		"rarity": ItemRarity.RARE,
		"target_type": "ally_single_position",
		"effect": {
			"type": "teleport",
			"range": 5
		},
		"icon": "res://asset/items/blink_stone.png"
	},
	
	"cleansing_crystal": {
		"name": "Cristal Purificateur",
		"description": "Supprime un état majeur (paralysie, pétrification)",
		"category": ItemCategory.STATUS_CURE,
		"rarity": ItemRarity.RARE,
		"target_type": "ally_single",
		"effect": {
			"type": "cure_major_status"
		},
		"icon": "res://asset/items/crystal_cleanse.png"
	},
	
	"duo_breaker": {
		"name": "Orbe de Discorde",
		"description": "Rompt un duo adverse (portée 3)",
		"category": ItemCategory.TACTICAL,
		"rarity": ItemRarity.VERY_RARE,
		"target_type": "enemy_duo",
		"effect": {
			"type": "break_duo",
			"range": 3
		},
		"icon": "res://asset/items/orb_discord.png"
	},
	
	"iron_will_potion": {
		"name": "Potion de Volonté de Fer",
		"description": "Immunité aux contrôles pendant 2 tours",
		"category": ItemCategory.BUFF,
		"rarity": ItemRarity.RARE,
		"target_type": "ally_single",
		"effect": {
			"type": "buff",
			"buff_type": "cc_immunity",
			"duration": 2
		},
		"icon": "res://asset/items/iron_will.png"
	},
	
	"mana_elixir": {
		"name": "Élixir de Mana",
		"description": "Restaure 50 points de mana",
		"category": ItemCategory.HEALING,
		"rarity": ItemRarity.COMMON,
		"target_type": "ally_single",
		"effect": {
			"type": "restore_mana",
			"value": 50
		},
		"icon": "res://asset/items/mana_elixir.png"
	}
}

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var terrain: TerrainModule3D
var unit_manager: UnitManager3D
var duo_system: DuoSystem

# ============================================================================
# INVENTAIRE
# ============================================================================

var battle_inventory: Dictionary = {}  # item_id -> quantity

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	GameRoot.global_logger.info("ITEM_MODULE", "Module d'objets initialisé (%d objets)" % ITEM_DATABASE.size())

func setup_inventory(items: Dictionary) -> void:
	"""Configure l'inventaire pour le combat"""
	battle_inventory = items.duplicate()
	GameRoot.global_logger.debug("ITEM_MODULE", "Inventaire: %s" % battle_inventory)

# ============================================================================
# VALIDATION
# ============================================================================

func can_use_item(unit: BattleUnit3D, item_id: String) -> Dictionary:
	"""Vérifie si un objet peut être utilisé"""
	
	if not unit or not unit.is_alive():
		return {"can_use": false, "reason": "Unité invalide"}
	
	if not unit.can_act():
		return {"can_use": false, "reason": "L'unité a déjà agi ce tour"}
	
	if not battle_inventory.has(item_id) or battle_inventory[item_id] <= 0:
		return {"can_use": false, "reason": "Objet non disponible"}
	
	if not ITEM_DATABASE.has(item_id):
		return {"can_use": false, "reason": "Objet inconnu"}
	
	return {"can_use": true, "reason": ""}

# ============================================================================
# UTILISATION
# ============================================================================

func use_item(user: BattleUnit3D, item_id: String, target: Variant = null) -> bool:
	"""
	Utilise un objet
	@param user : Unité qui utilise l'objet
	@param item_id : ID de l'objet
	@param target : Cible (BattleUnit3D ou Vector2i selon l'objet)
	@return true si succès
	"""
	
	# Validation
	var check = can_use_item(user, item_id)
	if not check.can_use:
		item_failed.emit(user, item_id, check.reason)
		return false
	
	var item_data = ITEM_DATABASE[item_id]
	
	# Vérifier la cible
	if not _validate_target(item_data, target):
		item_failed.emit(user, item_id, "Cible invalide")
		return false
	
	# Appliquer l'effet
	var success = _apply_effect(user, item_data, target)
	
	if success:
		# Consommer l'objet
		battle_inventory[item_id] -= 1
		
		# Marquer l'action
		user.action_used = true
		
		item_used.emit(user, item_id, target)
		
		GameRoot.global_logger.info("ITEM_MODULE", "%s utilise %s" % [user.unit_name, item_data.name])
		GameRoot.event_bus.notify("📦 %s utilise : %s" % [user.unit_name, item_data.name], "info")
		
		return true
	
	return false

# ============================================================================
# VALIDATION DE CIBLE
# ============================================================================

func _validate_target(item_data: Dictionary, target: Variant) -> bool:
	"""Valide que la cible est correcte pour l'objet"""
	
	var target_type = item_data.get("target_type", "self")
	
	match target_type:
		"self":
			return target == null
		
		"ally_single":
			return target is BattleUnit3D and target.is_alive()
		
		"ally_single_position":
			return target is Vector2i and terrain.is_in_bounds(target)
		
		"enemy_single":
			return target is BattleUnit3D and target.is_alive()
		
		"enemy_duo":
			# Vérifier que c'est une unité ennemie en duo
			if not target is BattleUnit3D or not target.is_alive():
				return false
			return duo_system.is_in_duo(target) if duo_system else false
	
	return false

# ============================================================================
# APPLICATION DES EFFETS
# ============================================================================

func _apply_effect(user: BattleUnit3D, item_data: Dictionary, target: Variant) -> bool:
	"""Applique l'effet de l'objet"""
	
	var effect = item_data.get("effect", {})
	var effect_type = effect.get("type", "")
	
	match effect_type:
		"heal":
			return _apply_heal(target as BattleUnit3D, effect.get("value", 0))
		
		"restore_mana":
			return _apply_mana_restore(target as BattleUnit3D, effect.get("value", 0))
		
		"cure_status":
			return _apply_cure_status(target as BattleUnit3D, effect.get("status", ""))
		
		"cure_all_status":
			return _apply_cure_all_status(target as BattleUnit3D)
		
		"cure_major_status":
			return _apply_cure_major_status(target as BattleUnit3D)
		
		"teleport":
			return _apply_teleport(target as BattleUnit3D, user, effect.get("range", 5))
		
		"break_duo":
			return _apply_break_duo(target as BattleUnit3D)
		
		"buff":
			return _apply_buff(target as BattleUnit3D, effect)
	
	return false

func _apply_heal(target: BattleUnit3D, amount: int) -> bool:
	"""Soigne une unité"""
	if not target:
		return false
	
	target.heal(amount)
	return true

func _apply_mana_restore(target: BattleUnit3D, amount: int) -> bool:
	"""Restaure du mana"""
	if not target:
		return false
	
	target.restore_mana(amount)
	return true

func _apply_cure_status(target: BattleUnit3D, status: String) -> bool:
	"""Soigne un état spécifique"""
	if not target or not target.has_status_effect(status):
		return false
	
	target.remove_status_effect(status)
	return true

func _apply_cure_all_status(target: BattleUnit3D) -> bool:
	"""Soigne tous les états"""
	if not target:
		return false
	
	for status in target.status_effects.keys():
		target.remove_status_effect(status)
	
	return true

func _apply_cure_major_status(target: BattleUnit3D) -> bool:
	"""Soigne les états majeurs (paralysie, pétrification, etc.)"""
	if not target:
		return false
	
	var major_statuses = ["paralysis", "petrification", "stun", "freeze"]
	var cured = false
	
	for status in major_statuses:
		if target.has_status_effect(status):
			target.remove_status_effect(status)
			cured = true
	
	return cured

func _apply_teleport(target: BattleUnit3D, user: BattleUnit3D, range: int) -> bool:
	"""Téléporte une unité (nécessite MovementModule)"""
	# TODO: Implémenter avec MovementModule
	GameRoot.global_logger.warning("ITEM_MODULE", "Téléportation non implémentée")
	return false

func _apply_break_duo(target: BattleUnit3D) -> bool:
	"""Rompt un duo adverse"""
	if not duo_system or not target:
		return false
	
	if duo_system.is_in_duo(target):
		# Récupérer l'ID du duo
		for duo_id in duo_system.active_duos:
			var duo = duo_system.active_duos[duo_id]
			if duo.leader == target or duo.support == target:
				duo_system.break_duo(duo_id)
				return true
	
	return false

func _apply_buff(target: BattleUnit3D, effect: Dictionary) -> bool:
	"""Applique un buff temporaire"""
	if not target:
		return false
	
	var buff_type = effect.get("buff_type", "")
	var duration = effect.get("duration", 1)
	
	# Utiliser le système de status_effects existant
	target.add_status_effect("buff_" + buff_type, duration)
	
	return true

# ============================================================================
# GETTERS
# ============================================================================

func get_available_items(unit: BattleUnit3D) -> Array[Dictionary]:
	"""Retourne les objets utilisables par l'unité"""
	
	var items: Array[Dictionary] = []
	
	for item_id in battle_inventory:
		if battle_inventory[item_id] > 0:
			var check = can_use_item(unit, item_id)
			if check.can_use:
				var item_info = ITEM_DATABASE[item_id].duplicate()
				item_info["id"] = item_id
				item_info["quantity"] = battle_inventory[item_id]
				items.append(item_info)
	
	return items

func get_item_data(item_id: String) -> Dictionary:
	"""Retourne les données d'un objet"""
	return ITEM_DATABASE.get(item_id, {})
