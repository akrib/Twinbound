extends Node
## ActionModule3D - Gère toutes les actions de combat en 3D

class_name ActionModule3D

signal action_executed(attacker: BattleUnit3D, target: BattleUnit3D, action_type: String)
signal damage_dealt(target: BattleUnit3D, damage: int)

var unit_manager: UnitManager3D
var terrain: TerrainModule3D
var ring_system: RingSystem

const ATTACK_COLOR: Color = Color(1.0, 0.3, 0.3, 0.5)

# ============================================================================
# VALIDATION
# ============================================================================

func can_attack(attacker: BattleUnit3D, target: BattleUnit3D) -> bool:
	if not attacker.can_act():
		return false
	if not target.is_alive():
		return false
	if attacker.is_player_unit == target.is_player_unit:
		return false
	
	var distance = terrain.get_distance(attacker.grid_position, target.grid_position)
	return distance <= attacker.attack_range

func get_attack_positions(unit: BattleUnit3D) -> Array[Vector2i]:
	"""Retourne toutes les positions attaquables"""
	var positions: Array[Vector2i] = []
	var range = unit.attack_range
	
	for dy in range(-range, range + 1):
		for dx in range(-range, range + 1):
			if dx == 0 and dy == 0:
				continue
			
			var manhattan = abs(dx) + abs(dy)
			if manhattan > range:
				continue
			
			var pos = unit.grid_position + Vector2i(dx, dy)
			if terrain.is_in_bounds(pos):
				positions.append(pos)
	
	return positions

# ============================================================================
# ACTIONS DE COMBAT
# ============================================================================

func execute_attack(attacker: BattleUnit3D, target: BattleUnit3D, duo_partner: BattleUnit3D = null) -> void:
	if not can_attack(attacker, target):
		return
	
	var is_duo_attack = duo_partner != null
	
	if is_duo_attack:
		print("[ActionModule3D] ⚔️ ATTAQUE EN DUO")
		
		# ✅ NOUVEAU : Afficher l'aura sur les deux unités
		var is_enemy_duo = not attacker.is_player_unit
		attacker.show_duo_aura(is_enemy_duo)
		duo_partner.show_duo_aura(is_enemy_duo)
		
		# Attendre un peu pour que l'aura soit visible
		await attacker.get_tree().create_timer(0.5).timeout
	
	await _animate_attack_3d(attacker, target)

	if is_duo_attack and duo_partner:
		var mana_cost = 20  # TODO: Ajuster selon le ring de canalisation
		
		if not duo_partner.consume_mana(mana_cost):
			GameRoot.event_bus.notify("❌ Mana insuffisant pour le duo", "error")
			GameRoot.global_logger.warning("ACTION", "%s : mana insuffisant" % duo_partner.unit_name)
			return
		
		GameRoot.global_logger.info("ACTION", "%s (support) consomme %d mana" % [
			duo_partner.unit_name,
			mana_cost
		])

	var damage = calculate_damage(attacker, target)
	
	# Bonus de duo
	if is_duo_attack:
		damage = int(damage * 1.5)
	
	target.take_damage(damage)
	_spawn_damage_number(target, damage)
	
	damage_dealt.emit(target, damage)
	action_executed.emit(attacker, target, "attack")
	GameRoot.event_bus.attack(attacker, target, damage)
	
	# ✅ NOUVEAU : Retirer les auras après l'attaque
	if is_duo_attack:
		await attacker.get_tree().create_timer(0.5).timeout
		
		# Vérifier que les unités existent encore
		if is_instance_valid(attacker) and attacker.is_alive():
			attacker.hide_duo_aura()
		
		if is_instance_valid(duo_partner) and duo_partner.is_alive():
			duo_partner.hide_duo_aura()

# ✅ NOUVELLE FONCTION
func _spawn_damage_number(target: BattleUnit3D, damage: int) -> void:
	"""Crée un nombre de dégâts animé au-dessus de la cible"""
	var damage_number = preload("res://features/combat/visuals/damage_number.gd").new()
	
	# Position de spawn : au-dessus de l'unité
	var spawn_pos = target.global_position + Vector3(0, 2.0, 0)
	
	# Offset aléatoire pour éviter superposition
	var random_offset = Vector3(
		randf_range(-0.5, 0.5),
		0,
		randf_range(-0.5, 0.5)
	)
	
	damage_number.setup(damage, spawn_pos, random_offset)
	
	# Ajouter à la scène
	target.get_parent().add_child(damage_number)

func calculate_damage(attacker: BattleUnit3D, target: BattleUnit3D) -> int:
	var base_damage = attacker.attack_power
	if attacker.has_meta("is_prepared"):
		var bonus = attacker.get_meta("prepared_bonus", {})
		if bonus.has("attack"):
			base_damage = int(base_damage * bonus.attack)
			GameRoot.global_logger.debug("ACTION", "%s (préparé) : attaque boostée x%.2f" % [attacker.unit_name, bonus.attack])
		
		# Décrémenter le compteur
		bonus.turns_remaining -= 1
		if bonus.turns_remaining <= 0:
			attacker.remove_meta("is_prepared")
			attacker.remove_meta("prepared_bonus")
			GameRoot.global_logger.debug("ACTION", "%s : bonus de préparation expiré" % attacker.unit_name)
		else:
			attacker.set_meta("prepared_bonus", bonus)
	
	var terrain_defense = terrain.get_defense_bonus(target.grid_position)
	var total_defense = target.defense_power + (terrain_defense * 0.1)
	# ✅ Appliquer le bonus défensif de préparation
	if target.has_meta("is_prepared"):
		var bonus = target.get_meta("prepared_bonus", {})
		if bonus.has("defense"):
			total_defense = int(total_defense * bonus.defense)
			GameRoot.global_logger.debug("ACTION", "%s (préparé) : défense boostée x%.2f" % [target.unit_name, bonus.defense])
	# ✅ Appliquer la réduction de défense si l'unité défend
	if target.has_meta("is_defending"):
		var defense_reduction = target.get_meta("defense_bonus", 0.0)
		base_damage = int(base_damage * (1.0 - defense_reduction))
		GameRoot.global_logger.debug("ACTION", "%s défend : -%d%% dégâts" % [target.unit_name, int(defense_reduction * 100)])
	
	var damage = max(1, int(base_damage - total_defense))
	damage = int(damage * randf_range(0.9, 1.1))
	
	return damage

# ============================================================================
# ANIMATIONS 3D
# ============================================================================

func _animate_attack_3d(attacker: BattleUnit3D, target: BattleUnit3D) -> void:
	"""Anime une attaque en 3D"""
	var original_pos = attacker.position
	var target_pos = target.position
	var direction = (target_pos - original_pos).normalized()
	var attack_distance = 0.5
	
	var tween = attacker.create_tween()
	tween.tween_property(attacker, "position", original_pos + direction * attack_distance, 0.1)
	tween.tween_property(attacker, "position", original_pos, 0.1)
	await tween.finished
