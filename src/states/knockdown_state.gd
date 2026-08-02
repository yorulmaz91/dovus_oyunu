# NEREYE BAGLI: StateMachine altindaki "Knockdown" adli Node.
class_name KnockdownState
extends FighterState

var _timer: float = 0.0
var _landed: bool = false


func can_turn() -> bool:
	return false


func enter(_msg: Dictionary = {}) -> void:
	_timer = fighter.juggle_rules.knockdown_time
	_landed = false
	fighter.deactivate_all_hitboxes()
	fighter.velocity.y = -190.0  # kucuk bir carpma sekmesi darbeyi hissettirir
	fighter.velocity.x *= 0.35
	fighter.play(&"knockdown", true)
	HitStop.freeze(0.05)
	CombatEvents.camera_shake_requested.emit(4.0)


## OTG korumasi - yerdeki rakibe vurulamaz. Ileride yer sekmesi / yerden
## tekrar havalandirma istersen bu satiri sil.
func on_hit_received(_info: HitInfo) -> int:
	return HitResponse.IGNORE


func update(delta: float) -> void:
	fighter.apply_gravity(delta)
	fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, fighter.ground_friction * 2.0 * delta)

	if fighter.is_on_floor():
		if not _landed:
			_landed = true
			fighter.play(&"downed", true)
		_timer -= delta

	if _timer <= 0.0:
		fighter.reset_juggle()
		fighter.end_combo()
		fighter.set_invulnerable(fighter.juggle_rules.wakeup_invuln)
		fighter.input.clear()  # bayat tus tamponu kalkis hamlesi yapmasin
		fighter.play(&"wakeup", true)
		fsm.change_to(&"Idle")
