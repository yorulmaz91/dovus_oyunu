# =============================================================================
# BattleCamera  —  Dovus kamerasi
# NEREYE BAGLI: battle.tscn icindeki Camera2D node'una.
#
# Iki dovuscuyu birden cerceveler, ayrilinca uzaklasir, yakinlasinca daralir.
# Juggle sirasinda havadaki dovuscu cerceve kutusunun icinde oldugu icin
# kamera yukariyi kendiliginden takip eder.
# =============================================================================
class_name BattleCamera
extends Camera2D

@export var targets: Array[Node2D] = []
## Dovusculerin etrafinda birakilan bosluk (piksel).
@export var margin: Vector2 = Vector2(360.0, 300.0)
@export var min_zoom: float = 0.70
@export var max_zoom: float = 1.20
@export var follow_speed: float = 7.0
@export var zoom_speed: float = 4.5

var _shake: float = 0.0


func _ready() -> void:
	CombatEvents.camera_shake_requested.connect(add_shake)
	make_current()


func add_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _physics_process(delta: float) -> void:
	var points: Array[Vector2] = []
	for t in targets:
		if is_instance_valid(t):
			points.append(t.global_position)
	if points.is_empty():
		return

	# Butun dovusculeri iceren en kucuk kutu + nefes payi.
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	box = box.grow_individual(margin.x, margin.y, margin.x, margin.y)

	var view: Vector2 = get_viewport_rect().size
	var needed: float = maxf(box.size.x / view.x, box.size.y / view.y)
	var wanted_zoom: float = clampf(1.0 / maxf(needed, 0.001), min_zoom, max_zoom)

	# exp() yumusatmasi kare hizindan bagimsizdir; duz lerp degildir.
	zoom = zoom.lerp(Vector2.ONE * wanted_zoom, 1.0 - exp(-zoom_speed * delta))
	global_position = global_position.lerp(box.get_center(), 1.0 - exp(-follow_speed * delta))

	_shake = maxf(0.0, _shake - delta * 30.0)
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
