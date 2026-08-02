# =============================================================================
# ImpactLight  —  Carpma isigi
# NEREYE BAGLI: Sahnenin LightRig'i icindeki bir PointLight2D'ye.
#
# Temas noktasinda parlar. HitStop Engine.time_scale'i 0 yaptigi icin delta
# sifir olur ve parlama donma boyunca TAM PARLAKLIKTA ASILI KALIR - istedigin
# tokat hissi tam olarak budur.
# =============================================================================
class_name ImpactLight
extends PointLight2D

@export var flash_energy: float = 2.6
@export var decay: float = 9.0
@export var offset_from_victim: Vector2 = Vector2(0.0, -60.0)


func _ready() -> void:
	enabled = false
	energy = 0.0
	blend_mode = Light2D.BLEND_MODE_ADD
	shadow_enabled = false  # bir parlama isigi ASLA golge dusurmemeli
	CombatEvents.hit_confirmed.connect(_on_hit_confirmed)


func _on_hit_confirmed(_attacker: Node, victim: Node, info: HitInfo) -> void:
	var v := victim as Node2D
	if v == null:
		return
	global_position = v.global_position + offset_from_victim
	energy = flash_energy * clampf(info.data.damage / 12.0, 0.5, 2.0)
	enabled = true


func _process(delta: float) -> void:
	if not enabled:
		return
	energy = move_toward(energy, 0.0, decay * delta)
	if energy <= 0.01:
		enabled = false
