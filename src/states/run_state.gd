# NEREYE BAGLI: StateMachine altindaki "Run" adli Node.
class_name RunState
extends FighterState


func enter(_msg: Dictionary = {}) -> void:
	fighter.play(&"run")


func update(delta: float) -> void:
	var x: float = fighter.input.move_x
	if absf(x) < 0.2:
		fsm.change_to(&"Idle")
		return

	# Dovus oyunu gelenegi: ileri hizli, geri temkinli yuruyus.
	var forward: bool = x * float(fighter.facing) > 0.0
	var speed: float = fighter.run_speed if forward else fighter.walk_speed
	fighter.velocity.x = move_toward(fighter.velocity.x, x * speed, fighter.ground_accel * delta)
	fighter.apply_gravity(delta)
	fighter.play(&"run" if forward else &"walk_back")

	if not fighter.is_on_floor():
		fsm.change_to(&"Airborne")
		return
	if fighter.try_start_attack(false):
		return
	if fighter.input.consume(&"jump"):
		fighter.velocity.y = fighter.jump_velocity
		fsm.change_to(&"Airborne", {"jumped": true})
