# NEREYE BAGLI: StateMachine altindaki "Airborne" adli Node.
# Bu KENDI ziplayisin - juggle (havada savrulma) degil.
class_name AirborneState
extends FighterState


func enter(msg: Dictionary = {}) -> void:
	fighter.play(&"jump" if msg.get("jumped", false) else &"fall")


func update(delta: float) -> void:
	var x: float = fighter.input.move_x
	var accel: float = fighter.run_speed * fighter.air_control * 5.0
	fighter.velocity.x = move_toward(fighter.velocity.x, x * fighter.run_speed, accel * delta)
	fighter.apply_gravity(delta)

	if fighter.velocity.y > 0.0:
		fighter.play(&"fall")
	if fighter.try_start_attack(true):
		return
	if fighter.is_on_floor() and fighter.velocity.y >= 0.0:
		fighter.land()
		fsm.change_to(&"Idle")
