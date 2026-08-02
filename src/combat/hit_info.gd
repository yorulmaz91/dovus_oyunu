# =============================================================================
# HitInfo  —  TEK bir canli vurus: hamle karti + kimin attigi + hangi yon.
# NEREYE BAGLI: Hicbir node'a.
#
# NEDEN VAR: Bir HitData .tres dosyasini o hamleyi kullanan HERKES paylasir.
# "saldiran" ve "yon" bilgisini .tres icine yazsaydik, ayni anda saldiran iki
# dusman birbirinin verisini ezerdi. Bu sarmalayici o veriyi ayri tutar.
# =============================================================================
class_name HitInfo
extends RefCounted

var data: HitData
var attacker: Node2D
var source: Node2D
var dir: int = 1
var id: int = 0

static var _next_id: int = 0


static func make(p_data: HitData, p_attacker: Node2D, p_source: Node2D, p_dir: int) -> HitInfo:
	var info := HitInfo.new()
	info.data = p_data
	info.attacker = p_attacker
	info.source = p_source
	info.dir = p_dir
	_next_id += 1
	info.id = _next_id
	return info
