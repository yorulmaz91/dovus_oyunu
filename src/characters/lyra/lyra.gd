# NEREYE BAGLI: lyra.tscn dosyasinin kok CharacterBody2D node'una.
class_name Lyra
extends Fighter


func _ready() -> void:
	super._ready()
	display_name = "Lyra"


func on_hit_landed(victim: Fighter, info: HitInfo) -> void:
	super.on_hit_landed(victim, info)
	# Lyra'nin Taekwondo kimligi: havadaki bir rakibe degen her tekme onu
	# birazcik yukari iter. Kendi juggle'ini yukari dogru KOVALAYABILIR.
	if not victim.is_on_floor() and not is_on_floor():
		velocity.y = minf(velocity.y, -300.0)
		air_actions = 1
