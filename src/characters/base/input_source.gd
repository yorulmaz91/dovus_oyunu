# =============================================================================
# InputSource  —  Girdi kaynaginin atasi
# NEREYE BAGLI: Dogrudan hicbir seye; alt siniflari baglanir.
#
# Tampon (buffer) mobil bir dovus oyununun tepkili hissetmesini saglar:
# 100 ms erken basilan bir tus yenmez, sirasi gelince cikar.
# =============================================================================
class_name InputSource
extends Node

## Bir tus basimi ne kadar "hatirlanir". 0.15 sn = 60 fps'te ~9 kare.
@export var buffer_time: float = 0.15

var move_x: float = 0.0
var jump_held: bool = false
var block_held: bool = false

var _buffer: Dictionary = {}


func _physics_process(delta: float) -> void:
	_poll(delta)
	for key in _buffer.keys():
		_buffer[key] = maxf(0.0, _buffer[key] - delta)


## Alt siniflar bunu ezer.
func _poll(_delta: float) -> void:
	pass


func press(action: StringName) -> void:
	_buffer[action] = buffer_time


## Tamponu OKUR ve TEMIZLER.
func consume(action: StringName) -> bool:
	if _buffer.get(action, 0.0) > 0.0:
		_buffer[action] = 0.0
		return true
	return false


## Tamponu TEMIZLEMEDEN okur - zincir secenegini yoklamak icin.
func peek(action: StringName) -> bool:
	return _buffer.get(action, 0.0) > 0.0


func clear() -> void:
	_buffer.clear()


## Dovus bitti: bu kaynak artik hicbir girdi uretmesin.
## _physics_process kapandigi icin tampon bir daha DOLMAZ; tutulan yon ve blok
## degerleri de sifirlanir, yoksa kazanan basili kalan tusla kosmaya devam
## ederdi. Suren saldiri dogal sonuna kadar oynar, yeni eylem baslatilamaz.
func disable() -> void:
	set_physics_process(false)
	clear()
	move_x = 0.0
	jump_held = false
	block_held = false
