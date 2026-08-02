# =============================================================================
# Hitbox  —  Saldiri hacmi (rakibe zarar veren kutu)
# NEREYE BAGLI: Onu savuran Bone2D'nin altindaki bir Area2D'ye.
#               (ornek: FootF > Hitbox_KickF). Altinda CollisionShape2D olmali.
# Animasyondaki "Call Method" izleriyle acilir/kapanir:
#   hitbox_on("Hitbox_KickF")  /  hitbox_off("Hitbox_KickF")
# =============================================================================
class_name Hitbox
extends Area2D

signal hit_landed(victim: Fighter, info: HitInfo)

## Buraya bir HitData .tres surukle.
@export var data: HitData
@export var debug_draw: bool = false

var fighter: Fighter

var _active: bool = false
var _already_hit: Array[int] = []


func _ready() -> void:
	fighter = _find_fighter()
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 1 << 2  # 3. katmani (hurtbox) algilar
	area_entered.connect(_on_area_entered)
	visible = debug_draw
	set_physics_process(false)


func _find_fighter() -> Fighter:
	var n: Node = self
	while n != null:
		if n is Fighter:
			return n as Fighter
		n = n.get_parent()
	return null


## Animasyon izinden, ilk AKTIF karede cagrilir.
func activate() -> void:
	_already_hit.clear()  # yeni savurus ayni hedefe tekrar vurabilir
	_active = true
	monitoring = true
	set_physics_process(true)


## Animasyon izinden, son aktif karede cagrilir.
func deactivate() -> void:
	_active = false
	monitoring = false
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	# area_entered sadece YENI temaslarda tetiklenir. Kutu acildiginda rakip
	# zaten icerideyse bu satir onu yakalar. Bu olmadan yapisik mesafede
	# yapilan hamleler bosa gider - klasik ve sinir bozucu bir hata.
	for a in get_overlapping_areas():
		_try_hit(a)


func _on_area_entered(a: Area2D) -> void:
	_try_hit(a)


func _try_hit(a: Area2D) -> void:
	if not _active or data == null or fighter == null:
		return
	var hurt := a as Hurtbox
	if hurt == null or hurt.fighter == null:
		return
	var victim: Fighter = hurt.fighter
	if victim == fighter or victim.team == fighter.team:
		return

	# Her aktiflik icin hedef basina TEK vurus. Bir dovusçunun birkac hurtbox'i
	# vardir; bu olmadan tek bir tekme uc kere sayilirdi.
	var vid: int = victim.get_instance_id()
	if _already_hit.has(vid):
		return
	_already_hit.append(vid)

	var info := HitInfo.make(data, fighter, self, fighter.facing)
	if victim.take_hit(info):
		hit_landed.emit(victim, info)
		fighter.on_hit_landed(victim, info)
