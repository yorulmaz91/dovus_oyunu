# NEREYE BAGLI: grunt.tscn dosyasinin kok CharacterBody2D node'una.
# Lyra ile ayni sistemi kullanir; tek fark InputSource node'unda AIInput olmasi.
class_name Grunt
extends Fighter


func _ready() -> void:
	super._ready()
	display_name = "Dusman"
