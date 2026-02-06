extends StateMachine
class_name BattleStateMachine
## State Machine pour le système de combat

signal battle_phase_changed(old_phase: String, new_phase: String)

enum State {
	INTRO,
	PLAYER_TURN,
	ENEMY_TURN,
	ANIMATION,
	VICTORY,
	DEFEAT
}

func _define_states() -> void:
	add_state("INTRO", _on_intro_enter, _on_intro_exit)
	add_state("PLAYER_TURN", _on_player_turn_enter, _on_player_turn_exit, _on_player_turn_process)
	add_state("ENEMY_TURN", _on_enemy_turn_enter, _on_enemy_turn_exit)
	add_state("ANIMATION", _on_animation_enter, _on_animation_exit)
	add_state("VICTORY", _on_victory_enter)
	add_state("DEFEAT", _on_defeat_enter)
	
	current_state = "INTRO"

func _define_transitions() -> void:
	add_transition("INTRO", "PLAYER_TURN")
	add_transition("PLAYER_TURN", "ANIMATION")
	add_transition("PLAYER_TURN", "ENEMY_TURN")
	add_transition("ENEMY_TURN", "ANIMATION")
	add_transition("ENEMY_TURN", "PLAYER_TURN")
	add_transition("ANIMATION", "PLAYER_TURN")
	add_transition("ANIMATION", "ENEMY_TURN")
	add_transition("ANIMATION", "VICTORY")
	add_transition("ANIMATION", "DEFEAT")
	add_transition("PLAYER_TURN", "VICTORY")
	add_transition("PLAYER_TURN", "DEFEAT")
	add_transition("ENEMY_TURN", "VICTORY")
	add_transition("ENEMY_TURN", "DEFEAT")

# Callbacks des états
func _on_intro_enter() -> void:
	print("[BattleStateMachine] 🎬 Intro")
	battle_phase_changed.emit("", "INTRO")  # ✅ AJOUTER

func _on_intro_exit() -> void:
	pass

func _on_player_turn_enter() -> void:
	print("[BattleStateMachine] ▶️ Tour du Joueur")
	battle_phase_changed.emit(get_previous_state(), "PLAYER_TURN")

func _on_player_turn_exit() -> void:
	pass

func _on_player_turn_process(delta: float) -> void:
	# Logique du tour joueur
	pass

func _on_enemy_turn_enter() -> void:
	print("[BattleStateMachine] 👾 Tour des Ennemis")
	battle_phase_changed.emit(get_previous_state(), "ENEMY_TURN") 

func _on_enemy_turn_exit() -> void:
	pass

func _on_animation_enter() -> void:
	print("[BattleStateMachine] 🎞️ Animation")
	battle_phase_changed.emit(get_previous_state(), "ANIMATION")

func _on_animation_exit() -> void:
	pass

func _on_victory_enter() -> void:
	print("[BattleStateMachine] 🎉 Victoire!")
	battle_phase_changed.emit(get_previous_state(), "VICTORY")

func _on_defeat_enter() -> void:
	print("[BattleStateMachine] 💀 Défaite")
	battle_phase_changed.emit(get_previous_state(), "DEFEAT")
