# scenes/battle/json_scenario_module.gd
extends Node
class_name JSONScenarioModule

## 🎬 MODULE DE SCÉNARIO 100% JSON
## Remplace LuaScenarioModule pour utiliser uniquement du JSON

# ============================================================================
# SIGNAUX
# ============================================================================

signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)
signal event_triggered(event_id: String)

# ============================================================================
# DONNÉES
# ============================================================================

var scenario_data: Dictionary = {}
var triggered_events: Array[String] = []

# ✅ Référence à la DialogueBox
var dialogue_box: DialogueBoxClass = null

# ============================================================================
# SETUP
# ============================================================================

func setup_scenario(scenario_path: String) -> void:
	"""Configure un scénario depuis JSON"""
	
	scenario_data = GameRoot.json_data_loader.load_json_file(scenario_path)
	
	if scenario_data.is_empty():
		push_error("[JSONScenarioModule] Erreur : impossible de charger ", scenario_path)
		return
	
	print("[JSONScenarioModule] ✅ Scénario chargé : ", scenario_path)

# ============================================================================
# INTRO / OUTRO
# ============================================================================

func has_intro() -> bool:
	return scenario_data.has("intro_dialogue")

func play_intro() -> void:
	if not scenario_data.has("intro_dialogue"):
		return
	
	var dialogue_lines = scenario_data.intro_dialogue
	await _play_json_dialogue(dialogue_lines)

func has_outro() -> bool:
	return scenario_data.has("outro_victory") or scenario_data.has("outro_defeat")

func play_outro(victory: bool) -> void:
	var dialogue_key = "outro_victory" if victory else "outro_defeat"
	
	if not scenario_data.has(dialogue_key):
		return
	
	var dialogue_lines = scenario_data[dialogue_key]
	await _play_json_dialogue(dialogue_lines)

# ============================================================================
# TRIGGERS
# ============================================================================

func trigger_turn_event(turn: int, is_player: bool) -> void:
	if not scenario_data.has("turn_events"):
		return
	
	var turn_events = scenario_data.turn_events
	var turn_key = "turn_" + str(turn)
	
	if turn_events.has(turn_key):
		var event_data = turn_events[turn_key]
		await _execute_json_event(event_data)

func trigger_position_event(unit: BattleUnit3D, pos: Vector2i) -> void:
	if not scenario_data.has("position_events"):
		return
	
	var position_events = scenario_data.position_events
	var pos_key = str(pos.x) + "," + str(pos.y)
	
	if position_events.has(pos_key):
		var event_data = position_events[pos_key]
		await _execute_json_event(event_data)

# ============================================================================
# EXÉCUTION D'ÉVÉNEMENTS JSON
# ============================================================================

func _execute_json_event(event_data: Dictionary) -> void:
	match event_data.get("type", ""):
		"dialogue":
			await _play_json_dialogue(event_data.get("dialogue", []))
		
		"spawn_units":
			GameRoot.event_bus.emit_signal("units_spawn_requested", event_data.get("units", []))
		
		"trigger_cutscene":
			GameRoot.event_bus.emit_signal("cutscene_requested", event_data.get("cutscene_id", ""))
		
		_:
			push_warning("[JSONScenarioModule] Type d'événement inconnu : ", event_data.type)

# ============================================================================
# SYSTÈME DE DIALOGUE
# ============================================================================

func _play_json_dialogue(dialogue_lines: Array) -> void:
	if not dialogue_box:
		push_warning("[JSONScenarioModule] DialogueBox non configurée")
		return
	
	# Créer un DialogueData
	var dialogue_data = DialogueData.new("scenario_dialogue_" + str(Time.get_ticks_msec()))
	
	for line in dialogue_lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		
		dialogue_data.add_line({
			"speaker": speaker,
			"text": text
			})
	
	# Démarrer le dialogue
	GameRoot.dialogue_manager.start_dialogue(dialogue_data, dialogue_box)
	
	# Attendre la fin
	await GameRoot.dialogue_manager.dialogue_ended
