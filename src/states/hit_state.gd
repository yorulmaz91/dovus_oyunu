# NEREYE BAGLI: StateMachine altindaki "Hit" adli Node.
class_name HitState
extends FighterState

var _stun: float = 0.0


func can_turn() -> bool:
	return false


func enter(msg: Dictionary = {}) -> void:
	var info: HitInfo = msg.get("hit")
	var blocked: bool = msg.get("blocked", false)
	if info == null:
		fsm.change_to(&"Idle")
		return

	fighter.deactivate_all_hitboxes()
	_stun = info.data.blockstun if blocked else info.data.hitstun
	var push: float = 0.4 if blocked else 1.0
	fighter.velocity.x = float(info.dir) * info.data.knockback.x * push
	fighter.velocity.y = minf(info.data.knockback.y, 0.0)

	if blocked:
		fighter.play(&"block_hit", true)
	elif info.data.reaction >= HitData.Reaction.HEAVY:
		fighter.play(&"hit_heavy", true)
	else:
		fighter.play(&"hit_light", true)


func on_hit_received(info: HitInfo) -> int:
	# Zaten sersemken tekrar vurulduk: durumu bastan baslatmak yerine
	# sersemlemeyi tazele. Ama havalandiran hamleyse Fighter karar versin.
	if info.data.reaction == HitData.Reaction.LAUNCH:
		return HitResponse.PASS
	enter({"hit": info})
	return HitResponse.HANDLED


func update(delta: float) -> void:
	fighter.apply_gravity(delta)
	fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, fighter.ground_friction * delta)
	_stun -= delta
	if _stun <= 0.0:
		fighter.end_combo()
		fsm.change_to(&"Idle" if fighter.is_on_floor() else &"Airborne")
