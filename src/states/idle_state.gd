# NEREYE BAGLI: StateMachine altindaki "Idle" adli Node.
class_name IdleState
extends FighterState


func enter(_msg: Dictionary = {}) -> void:
	fighter.play(&"idle")


func update(delta: float) -> void:
	fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, fighter.ground_friction * delta)
	fighter.apply_gravity(delta)

	if not fighter.is_on_floor():
		fsm.change_to(&"Airborne")
		return
	if fighter.try_start_attack(false):
		return
	if fighter.input.consume(&"jump"):
		fighter.basla_ziplama()
		fsm.change_to(&"Airborne", {"jumped": true})
		return
	if absf(fighter.input.move_x) > 0.2:
		fsm.change_to(&"Run")
