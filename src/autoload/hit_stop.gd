# =============================================================================
# HitStop  —  "Vurus donmasi" (freeze frames)
# NEREYE BAGLI: Hicbir node'a. Bu bir AUTOLOAD (Proje Ayarlari > Globals).
#
# Bir vurus degdiginde tum oyunu birkac milisaniye dondurur. Dovus oyunlarinda
# darbenin "agir" hissettirmesinin %80'i budur.
# =============================================================================
extends Node

var _pending: int = 0


func freeze(duration: float) -> void:
	if duration <= 0.0:
		return
	_pending += 1
	Engine.time_scale = 0.0
	# 4. parametre (ignore_time_scale = true) sayesinde bu sayac oyun donmusken
	# bile isler. O olmadan oyun sonsuza kadar donar kalirdi.
	await get_tree().create_timer(duration, true, false, true).timeout
	_pending -= 1
	if _pending <= 0:
		_pending = 0
		Engine.time_scale = 1.0
