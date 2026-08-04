# =============================================================================
# poz_levha.gd  —  MONTAJ TESHISI
#
# NE ISE YARAR: Lyra'yi sahnesiz, isiksiz, flash'siz ve DUZ GRI fon uzerinde
# tek basina kurar; rig'i belirli pozlarda DONDURUP tek tek PNG basar.
# Montaj kusurlari (omuz yumrusu, dirsek/diz kopmasi, kola sarilma) sahne
# isiginda kayboluyor; burada ciplak gorunurler.
#
# NASIL CALISTIRILIR (NORMAL exe, headless DEGIL - goruntu almasi gerek):
#   Godot_v4.7.1-stable_win64.exe --path . res://tools/poz_levha.tscn
#
# Cikti: build/dogrulama/poz/*.png
# =============================================================================
extends Node2D

const CIKIS := "res://build/dogrulama/poz/"
const YAKINLIK := 2.4
## Kaydedilecek pozlar: [dosya adi, animasyon, saniye]
## Saldirilarda secilen an, vurus kutusunun ACIK oldugu an.
const POZLAR := [
	["01_dinlenme", &"RESET", 0.0],
	["02_idle", &"idle", 0.0],
	["03_gard", &"idle", 1.0],
	["04_kosu_orta", &"run", 0.25],
	["05_yumruk_aktif", &"atk_light_1", 0.17],
	["06_tekme_aktif", &"atk_kick_1", 0.21],
	["07_havalandirici_aktif", &"atk_launcher", 0.29],
	["08_ziplama", &"jump", 0.20],
	["09_juggle_dusus", &"juggle_fall", 0.30],
	["10_knockdown", &"knockdown", 0.30],
]

var lyra: Fighter
var kam: Camera2D
var frames: int = 0
var sira: int = 0
var alinan: Array[String] = []


func _ready() -> void:
	print("\n=========== POZ LEVHASI ===========")
	DirAccess.make_dir_recursive_absolute(CIKIS)

	# Duz acik gri fon - sahne, isik ve parallax YOK.
	var fon := ColorRect.new()
	fon.color = Color(0.72, 0.72, 0.74)
	fon.anchor_right = 1.0
	fon.anchor_bottom = 1.0
	var kat := CanvasLayer.new()
	kat.layer = -10
	kat.add_child(fon)
	add_child(kat)

	lyra = load("res://src/characters/lyra/lyra.tscn").instantiate()
	add_child(lyra)

	kam = Camera2D.new()
	kam.zoom = Vector2(YAKINLIK, YAKINLIK)
	add_child(kam)
	kam.make_current()


func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 3:
		# Dovuscuyu DONDUR: durum makinesi, yer cekimi ve flash calismasin.
		lyra.set_physics_process(false)
		lyra.fsm.set_physics_process(false)
		lyra.input.set_physics_process(false)
		# Flash rig.modulate'i eziyor; teshiste temiz renk istiyoruz.
		lyra.rig.modulate = Color.WHITE
		kam.global_position = lyra.global_position + Vector2(10.0, -86.0)
		return
	if lyra == null or frames < 5:
		return

	# Her poz icin: animasyonu ac, istenen ana sar, DURDUR, bir kare bekle,
	# sonra goruntuyu al. Bekleme sarti - AnimationPlayer pozu bir sonraki
	# karede uyguluyor.
	var adim: int = frames - 5
	var poz_index: int = adim / 3
	if poz_index >= POZLAR.size():
		_rapor()
		get_tree().quit()
		return

	var faz: int = adim % 3
	var poz: Array = POZLAR[poz_index]
	if faz == 0:
		var anim_ad: StringName = poz[1]
		if not lyra.anim.has_animation(anim_ad):
			print("  ATLANDI (animasyon yok): %s" % anim_ad)
			return
		lyra.anim.play(anim_ad)
		lyra.anim.seek(float(poz[2]), true)
		lyra.anim.pause()
	elif faz == 2:
		_cek(String(poz[0]))


func _cek(ad: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var hata := img.save_png(CIKIS + ad + ".png")
	if hata == OK:
		alinan.append(ad)
	print("  %-26s %s" % [ad + ".png", "TAMAM" if hata == OK else "HATA %d" % hata])


func _rapor() -> void:
	print("\n--------- LEVHA ---------")
	print("  %d / %d poz alindi" % [alinan.size(), POZLAR.size()])
	print("  Klasor: %s" % ProjectSettings.globalize_path(CIKIS))
	print("===================================\n")
