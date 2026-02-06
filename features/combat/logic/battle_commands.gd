extends Command
class_name MoveUnitCommand

var unit: BattleUnit3D
var from_pos: Vector2i
var to_pos: Vector2i
var unit_manager: UnitManager3D

func _init(p_unit: BattleUnit3D, p_to: Vector2i, p_manager: UnitManager3D):
	unit = p_unit
	from_pos = p_unit.grid_position
	to_pos = p_to
	unit_manager = p_manager
	description = "%s se déplace de %s à %s" % [unit.unit_name, from_pos, to_pos]

func _do_execute() -> bool:
	unit_manager.move_unit(unit, to_pos)
	return true

func _do_undo() -> bool:
	unit_manager.move_unit(unit, from_pos)
	return true
