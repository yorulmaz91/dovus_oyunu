# =============================================================================
# FighterState  —  Butun durumlarin atasi
# NEREYE BAGLI: Hicbir node'a. Her durum scripti bunu genisletir.
# =============================================================================
class_name FighterState
extends Node

## Bir durumun gelen vurusa verdigi cevap.
enum HitResponse {
	PASS,     ## benim isim degil - tepkiyi Fighter secsin (normal durum)
	HANDLED,  ## ben hallettim; hasari uygula ama durumu DEGISTIRME
	IGNORE    ## vurus hic sayilmaz (dokunulmaz / yerde yatiyor)
}

var fsm: StateMachine
var fighter: Fighter


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


## Her fizik karesinde calisir. Buraya fighter.velocity yaz - move_and_slide()
## cagrisini Fighter senin yerine yapar.
func update(_delta: float) -> void:
	pass


func on_hit_received(_info: HitInfo) -> int:
	return HitResponse.PASS


## Bu durumda dovuscu otomatik olarak rakibe donsun mu?
func can_turn() -> bool:
	return true
