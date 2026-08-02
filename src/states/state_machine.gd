# =============================================================================
# StateMachine  —  Durum makinesi
# NEREYE BAGLI: Dovuscunun altindaki "StateMachine" adli duz bir Node'a.
# Onun cocuklari durumlardir. NODE ADI = DURUM ADI:
#   "Idle", "Run", "Airborne", "Attack", "Hit", "Juggle", "Knockdown"
# Yazim birebir ayni olmali.
# =============================================================================
class_name StateMachine
extends Node

signal transitioned(from_state: StringName, to_state: StringName)

@export var initial_state: StringName = &"Idle"

var fighter: Fighter
var current: FighterState
var current_name: StringName = &""
var previous_name: StringName = &""
var time_in_state: float = 0.0

var _states: Dictionary = {}


## Fighter._ready() tarafindan cagrilir, BURADAKI _ready() tarafindan DEGIL.
## Cunku Godot'ta cocugun _ready()'si ebeveynden ONCE calisir; o an
## dovuscunun @onready degiskenleri henuz bos olurdu.
func setup(owner_fighter: Fighter) -> void:
	fighter = owner_fighter
	for child in get_children():
		var st := child as FighterState
		if st == null:
			continue
		st.fsm = self
		st.fighter = owner_fighter
		_states[StringName(child.name)] = st
	change_to(initial_state)


func change_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: '%s' adli durum node'u yok (%s)" % [state_name, fighter.name])
		return
	if current != null:
		current.exit()
		previous_name = current_name
	current = _states[state_name]
	current_name = state_name
	time_in_state = 0.0
	current.enter(msg)
	transitioned.emit(previous_name, state_name)


func physics_tick(delta: float) -> void:
	time_in_state += delta
	if current != null:
		current.update(delta)


func has(state_name: StringName) -> bool:
	return _states.has(state_name)
