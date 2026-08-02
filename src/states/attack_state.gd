# NEREYE BAGLI: StateMachine altindaki "Attack" adli Node.
class_name AttackState
extends FighterState

var move: MoveDef

var _finished: bool = false


func can_turn() -> bool:
	return not (move != null and move.lock_facing)


func enter(msg: Dictionary = {}) -> void:
	move = msg.get("move")
	_finished = false
	if move == null:
		fsm.change_to(&"Idle")
		return

	fighter.deactivate_all_hitboxes()
	fighter.current_move = move
	fighter.lock_facing = move.lock_facing
	if not move.airborne:
		fighter.velocity.x = move.forward_momentum * float(fighter.facing)
	fighter.play(move.animation, true)
	fighter.anim.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)


func exit() -> void:
	fighter.deactivate_all_hitboxes()
	fighter.lock_facing = false
	fighter.current_move = null
	if fighter.anim.animation_finished.is_connected(_on_animation_finished):
		fighter.anim.animation_finished.disconnect(_on_animation_finished)


func update(delta: float) -> void:
	if move.airborne:
		fighter.apply_gravity(delta)
		if fighter.is_on_floor() and fighter.velocity.y >= 0.0:
			fighter.land()
			fsm.change_to(&"Idle")
			return
	else:
		fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, fighter.ground_friction * delta)
		fighter.apply_gravity(delta)

	# Iptal penceresi: ya animasyon izi acar (open_cancel_window) ya da
	# saldiri rakibe degdigi an kendiliginden acilir.
	if fighter.can_cancel:
		# ZIPLAMA IPTALI - zincirden ONCE denenir.
		# Havalandirici degdikten sonra toparlanmayi kesip havalanmani saglar;
		# kendi juggle'ini kovalayabilmenin tek yolu budur. Iptal penceresi
		# vurus onayiyla acildigi icin bosa sallanan hamle iptal EDILEMEZ.
		# Ziplama hizi Idle/Run ile AYNI yoldan verilir - tek bir dogru vardir.
		if move.jump_cancel and fighter.is_on_floor() and fighter.input.consume(&"jump"):
			fighter.velocity.y = fighter.jump_velocity
			fsm.change_to(&"Airborne", {"jumped": true})
			return

		var next_move: MoveDef = fighter.pick_chain_move(move)
		if next_move != null:
			fsm.change_to(&"Attack", {"move": next_move})
			return

	if _finished:
		fsm.change_to(&"Idle" if fighter.is_on_floor() else &"Airborne")


func _on_animation_finished(_name: StringName) -> void:
	_finished = true
