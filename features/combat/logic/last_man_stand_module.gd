extends Node
## LastManStandModule - Gère l'attaque solo ultime (Déchaînement Profane)
## ⚠️ Condition stricte : UNE SEULE unité vivante + 50% mana minimum

class_name LastManStandModule

# ============================================================================
# SIGNAUX
# ============================================================================

signal last_man_stand_triggered(unit: BattleUnit3D)
signal last_man_stand_completed(unit: BattleUnit3D, total_damage: int)
signal last_man_stand_failed(unit: BattleUnit3D, reason: String)

# ============================================================================
# CONFIGURATION
# ============================================================================

const MIN_MANA_PERCENT: float = 0.5  # 50% minimum requis
const AREA_SIZE: int = 8  # 8 cases adjacentes
const LORE_NAME: String = "Déchaînement Profane"

# ============================================================================
# RÉFÉRENCES
# ============================================================================

var terrain: TerrainModule3D
var unit_manager: UnitManager3D

# ============================================================================
# VALIDATION
# ============================================================================

func can_use_last_man_stand(unit: BattleUnit3D) -> Dictionary:
	"""
	Vérifie si une unité peut utiliser Last Man Stand
	@return Dictionary avec {can_use: bool, reason: String}
	"""
	
	if not unit or not unit.is_alive():
		return {"can_use": false, "reason": "Unité morte ou invalide"}
	
	# ✅ RÈGLE 1 : Une seule unité vivante dans l'équipe
	var allies = unit_manager.get_alive_player_units() if unit.is_player_unit else unit_manager.get_alive_enemy_units()
	
	if allies.size() != 1:
		return {
			"can_use": false, 
			"reason": "Last Man Stand impossible : %d unité(s) vivante(s) (requis: 1)" % allies.size()
		}
	
	# ✅ RÈGLE 2 : Au moins 50% de mana
	var mana_percent = unit.get_mana_percentage()
	
	if mana_percent < MIN_MANA_PERCENT:
		return {
			"can_use": false,
			"reason": "Mana insuffisant : %.0f%% (requis: 50%%)" % (mana_percent * 100)
		}
	
	# ✅ RÈGLE 3 : Doit pouvoir agir
	if not unit.can_act():
		return {
			"can_use": false,
			"reason": "L'unité a déjà agi ce tour"
		}
	
	return {"can_use": true, "reason": ""}

# ============================================================================
# EXÉCUTION
# ============================================================================

func execute_last_man_stand(unit: BattleUnit3D) -> void:
	"""
	Exécute le Last Man Stand
	Consomme 100% du mana et inflige des dégâts en AOE 3x3
	"""
	
	# Vérification finale
	var check = can_use_last_man_stand(unit)
	if not check.can_use:
		last_man_stand_failed.emit(unit, check.reason)
		GameRoot.global_logger.warning("LAST_MAN_STAND", check.reason)
		return
	
	GameRoot.global_logger.info("LAST_MAN_STAND", "🔥 %s déclenche le %s !" % [unit.unit_name, LORE_NAME])
	last_man_stand_triggered.emit(unit)
	
	# ✅ Animation préparatoire
	await _play_charge_animation(unit)
	
	# ✅ Calculer le multiplicateur basé sur le mana actuel
	var mana_percent = unit.get_mana_percentage()
	var damage_multiplier = 1.0 + mana_percent
	
	# ✅ Dégâts de base
	var base_damage = unit.attack_power
	var total_damage = int(base_damage * damage_multiplier)
	
	# ✅ Diviser en 8 portions pour les 8 cases adjacentes
	var damage_per_cell = total_damage / 8.0
	
	GameRoot.global_logger.info("LAST_MAN_STAND", "Multiplicateur: %.2fx | Dégâts totaux: %d | Par case: %.1f" % [
		damage_multiplier,
		total_damage,
		damage_per_cell
	])
	
	# ✅ Obtenir les 8 positions adjacentes
	var affected_positions = _get_adjacent_positions(unit.grid_position)
	
	# ✅ Infliger les dégâts
	var enemies_hit = 0
	var total_damage_dealt = 0
	
	for pos in affected_positions:
		var target = unit_manager.get_unit_at(pos)
		
		if target and target.is_alive() and target.is_player_unit != unit.is_player_unit:
			var damage = int(damage_per_cell)
			target.take_damage(damage)
			
			_spawn_damage_number(target, damage)
			await get_tree().create_timer(0.1).timeout
			
			enemies_hit += 1
			total_damage_dealt += damage
			
			GameRoot.global_logger.debug("LAST_MAN_STAND", "→ %s touché : %d dégâts" % [target.unit_name, damage])
	
	# ✅ Consommer 100% du mana
	unit.current_mana = 0
	unit._update_mana_bar()
	unit.mana_changed.emit(0, unit.max_mana)
	
	# ✅ Marquer l'action comme utilisée
	unit.action_used = true
	unit.movement_used = true
	
	GameRoot.global_logger.info("LAST_MAN_STAND", "✅ %d ennemi(s) touché(s) | Total: %d dégâts" % [
		enemies_hit,
		total_damage_dealt
	])
	
	last_man_stand_completed.emit(unit, total_damage_dealt)
	
	# ✅ Message au joueur
	GameRoot.event_bus.notify("💀 %s : %s ! (%d dégâts)" % [unit.unit_name, LORE_NAME, total_damage_dealt], "critical")

# ============================================================================
# UTILITAIRES
# ============================================================================

func _get_adjacent_positions(center: Vector2i) -> Array[Vector2i]:
	"""Retourne les 8 positions adjacentes (cardinales + diagonales)"""
	
	var positions: Array[Vector2i] = []
	
	var offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),  # Haut
		Vector2i(-1,  0),                  Vector2i(1,  0),  # Centre
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)   # Bas
	]
	
	for offset in offsets:
		var pos = center + offset
		if terrain.is_in_bounds(pos):
			positions.append(pos)
	
	return positions

func _spawn_damage_number(target: BattleUnit3D, damage: int) -> void:
	"""Crée un nombre de dégâts au-dessus de la cible"""
	
	var damage_number = preload("res://features/combat/visuals/damage_number.gd").new()
	var spawn_pos = target.global_position + Vector3(0, 2.5, 0)
	var random_offset = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	
	damage_number.setup(damage, spawn_pos, random_offset)
	target.get_parent().add_child(damage_number)

# ============================================================================
# ANIMATIONS
# ============================================================================

func _play_charge_animation(unit: BattleUnit3D) -> void:
	"""Animation de charge avant l'attaque"""
	
	if not unit.sprite_3d:
		return
	
	# Effet de charge (pulsation + élévation)
	var tween = unit.create_tween()
	tween.set_parallel(true)
	
	# Pulsation
	tween.tween_property(unit.sprite_3d, "scale", Vector3(1.3, 1.3, 1.3), 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# Élévation
	var original_y = unit.position.y
	tween.tween_property(unit, "position:y", original_y + 0.5, 0.5).set_ease(Tween.EASE_OUT)
	
	# Effet de couleur (rouge intense)
	tween.tween_property(unit.sprite_3d, "modulate", Color(1.5, 0.3, 0.3), 0.5)
	
	await tween.finished
	
	# Retour brutal
	var release = unit.create_tween()
	release.set_parallel(true)
	release.tween_property(unit.sprite_3d, "scale", Vector3.ONE, 0.2)
	release.tween_property(unit, "position:y", original_y, 0.2)
	release.tween_property(unit.sprite_3d, "modulate", Color.WHITE, 0.3)
	
	await release.finished

# ============================================================================
# DEBUG
# ============================================================================

func debug_check_status(unit: BattleUnit3D) -> void:
	"""Affiche l'état du Last Man Stand pour une unité"""
	
	var check = can_use_last_man_stand(unit)
	
	print("\n=== Last Man Stand - %s ===" % unit.unit_name)
	print("Peut utiliser : %s" % ("OUI" if check.can_use else "NON"))
	if not check.can_use:
		print("Raison : %s" % check.reason)
	print("Mana : %.0f%%" % (unit.get_mana_percentage() * 100))
	
	var allies = unit_manager.get_alive_player_units() if unit.is_player_unit else unit_manager.get_alive_enemy_units()
	print("Alliés vivants : %d" % allies.size())
	print("============================\n")
