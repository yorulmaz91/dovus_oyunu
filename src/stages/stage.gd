# NEREYE BAGLI: Her sahne (stage) dosyasinin kok Node2D node'una.
class_name Stage
extends Node2D

@export_group("Sinirlar")
@export var wall_left: float = -1100.0
@export var wall_right: float = 1100.0
## Juggle'larin gorunmesi icin bol tavan bosluğu.
@export var ceiling: float = -1400.0
@export var floor_y: float = 0.0

@export_group("Baslangic noktalari")
@export var spawn_p1: Vector2 = Vector2(-150.0, 0.0)
@export var spawn_p2: Vector2 = Vector2(150.0, 0.0)


func apply_camera_limits(cam: Camera2D) -> void:
	cam.limit_left = int(wall_left - 260.0)
	cam.limit_right = int(wall_right + 260.0)
	cam.limit_top = int(ceiling)
	cam.limit_bottom = int(floor_y + 300.0)
