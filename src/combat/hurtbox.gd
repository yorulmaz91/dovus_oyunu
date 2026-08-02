# =============================================================================
# Hurtbox  —  Hasar alan hacim (vurulabilir bolge)
# NEREYE BAGLI: Rig/Hurtboxes altindaki her Area2D'ye.
#               Her birinin altinda bir CollisionShape2D olmali.
# =============================================================================
class_name Hurtbox
extends Area2D

var fighter: Fighter


func _ready() -> void:
	var n: Node = self
	while n != null:
		if n is Fighter:
			fighter = n as Fighter
			break
		n = n.get_parent()
	monitoring = false  # hurtbox asla aramaz; o BULUNUR
	monitorable = true
	collision_layer = 1 << 2  # 3. katman = hurtbox
	collision_mask = 0
