extends Node
class_name StateMachine
## Machine à états générique réutilisable
## Usage: Hériter et définir _define_states() et _define_transitions()

signal state_changed(from: String, to: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)

# ============================================================================
# ÉTAT
# ============================================================================

var current_state: String = ""
var previous_state: String = ""
var states: Dictionary = {}  # state_name -> { enter: Callable, exit: Callable, process: Callable }
var transitions: Dictionary = {}  # from_state -> [allowed_to_states]

var is_active: bool = true
var debug_mode: bool = false

var current_state_name: String:
	get:
		return current_state

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	_define_states()
	_define_transitions()
	
	if not current_state.is_empty():
		_enter_state(current_state)

## À surcharger : définir les états
func _define_states() -> void:
	pass  # Override in child class

## À surcharger : définir les transitions autorisées
func _define_transitions() -> void:
	pass  # Override in child class

# ============================================================================
# GESTION DES ÉTATS
# ============================================================================

func add_state(state_name: String, enter: Callable = Callable(), exit: Callable = Callable(), process: Callable = Callable()) -> void:
	"""Ajoute un état à la machine"""
	states[state_name] = {
		"enter": enter,
		"exit": exit,
		"process": process
	}
	
	if debug_mode:
		print("[StateMachine] État ajouté : ", state_name)

func add_transition(from: String, to: String) -> void:
	"""Autorise une transition from -> to"""
	if not transitions.has(from):
		transitions[from] = []
	
	if to not in transitions[from]:
		transitions[from].append(to)

func can_transition(from: String, to: String) -> bool:
	"""Vérifie si une transition est autorisée"""
	if not transitions.has(from):
		return false
	
	return to in transitions[from]

func change_state(new_state: String, force: bool = false) -> bool:
	"""Change l'état actuel"""
	if not states.has(new_state):
		push_error("[StateMachine] État inexistant : ", new_state)
		return false
	
	# Vérifier la transition
	if not force and not can_transition(current_state, new_state):
		if debug_mode:
			push_warning("[StateMachine] Transition interdite : ", current_state, " -> ", new_state)
		return false
	
	# Exit current state
	if not current_state.is_empty():
		_exit_state(current_state)
	
	# Change state
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
	_enter_state(new_state)
	
	state_changed.emit(previous_state, current_state)
	
	if debug_mode:
		print("[StateMachine] ", previous_state, " -> ", current_state)
	
	return true

func _enter_state(state_name: String) -> void:
	"""Appelle le callback d'entrée d'un état"""
	if states[state_name].enter.is_valid():
		states[state_name].enter.call()
	
	state_entered.emit(state_name)

func _exit_state(state_name: String) -> void:
	"""Appelle le callback de sortie d'un état"""
	if states[state_name].exit.is_valid():
		states[state_name].exit.call()
	
	state_exited.emit(state_name)

func _process(delta: float) -> void:
	if not is_active or current_state.is_empty():
		return
	
	if states[current_state].process.is_valid():
		states[current_state].process.call(delta)

# ============================================================================
# GETTERS
# ============================================================================

func get_current_state() -> String:
	return current_state

func get_previous_state() -> String:
	return previous_state

func is_in_state(state_name: String) -> bool:
	return current_state == state_name

func get_allowed_transitions() -> Array:
	return transitions.get(current_state, [])
