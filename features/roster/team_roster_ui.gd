extends Control
class_name TeamRosterUI

signal team_updated()

@onready var roster_list: VBoxContainer = $Panel/MarginContainer/HBoxContainer/RosterPanel/ScrollContainer/RosterList
@onready var team_list: VBoxContainer = $Panel/MarginContainer/HBoxContainer/TeamPanel/ScrollContainer/TeamList
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_refresh_ui()

func _refresh_ui() -> void:
	_clear_lists()
	_populate_roster()
	_populate_team()

func _clear_lists() -> void:
	for child in roster_list.get_children():
		child.queue_free()
	
	for child in team_list.get_children():
		child.queue_free()

func _populate_roster() -> void:
	var roster = GameRoot.team_manager.get_roster()
	
	for unit in roster:
		var button = Button.new()
		button.text = "%s (Lv.%d)" % [unit.get("name"), unit.get("level", 1)]
		button.custom_minimum_size = Vector2(200, 40)
		
		button.pressed.connect(func(): _on_roster_unit_clicked(unit))
		
		roster_list.add_child(button)

func _populate_team() -> void:
	var team = GameRoot.team_manager.get_current_team()
	
	for unit in team:
		var button = Button.new()
		button.text = "%s (Lv.%d)" % [unit.get("name"), unit.get("level", 1)]
		button.custom_minimum_size = Vector2(200, 40)
		
		button.pressed.connect(func(): _on_team_unit_clicked(unit))
		
		team_list.add_child(button)

func _on_roster_unit_clicked(unit: Dictionary) -> void:
	if GameRoot.team_manager.add_to_team(unit):
		_refresh_ui()

func _on_team_unit_clicked(unit: Dictionary) -> void:
	GameRoot.team_manager.remove_from_team(unit.get("id"))
	_refresh_ui()

func _on_close_pressed() -> void:
	queue_free()
