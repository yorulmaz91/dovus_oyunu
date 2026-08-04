# =============================================================================
# ekran_dogrula.gd  —  Rig'i GOZLE denetlemek icin ekran goruntusu alir
#
# NE ISE YARAR: battle sahnesini kurar, Lyra'yi yakin plana alan kendi
# kamerasini takar ve secili anlarda viewport'u PNG olarak kaydeder.
# Amac: eklem bosluklari, oranlar, kafa-govde baglantisi, cift paca gibi
# sorunlari koda bakarak degil GOREREK yakalamak.
#
# NASIL CALISTIRILIR - headless DEGIL, normal exe ile (pencere kisa sure
# acilip kapanir, normaldir):
#   Godot_v4.7.1-stable_win64.exe --path . res://tools/ekran_dogrula.tscn
#
# Cikti: build/dogrulama/{idle,yumruk,tekme,havalandirici,zipla,juggle,
#        grunt_idle,karsilasma}.png
# =============================================================================
extends Node

const CIKIS := "res://build/dogrulama/"
## Yakin plan: 170 px'lik karakter 720 px'lik ekranda ayrinti versin.
const YAKINLIK := 3.2
const FRAME_LIMIT: int = 900

var battle: Node
var player: Fighter
var enemy: Fighter
var kam: Camera2D

var frames: int = 0
var phase: String = "boot"
var _t: int = 0
var alinan: Dictionary = {}
var _tap_left: int = 0
var _tap_action: StringName = &""


func _ready() -> void:
	print("\n=========== EKRAN DOGRULAMA ===========")
	DirAccess.make_dir_recursive_absolute(CIKIS)
	battle = load("res://src/main/battle.tscn").instantiate()
	add_child(battle)


func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 2:
		player = battle.get_node("Fighters/Lyra")
		enemy = battle.get_node("Fighters/Grunt")
		enemy.get_node("InputSource").passive = true
		# Kendi kameramiz BattleCamera'yi devralir - yalniz bu arac icin.
		kam = Camera2D.new()
		kam.zoom = Vector2(YAKINLIK, YAKINLIK)
		battle.add_child(kam)
		kam.make_current()
		return

	if player == null:
		return

	# Kamera hep Lyra'nin govdesinde dursun (son iki faz kendi kamerasini kurar).
	if phase not in ["grunt_idle", "karsilasma"]:
		kam.global_position = player.global_position + Vector2(14.0, -88.0)

	if _tap_left > 0:
		_tap_left -= 1
		if _tap_left == 0:
			Input.action_release(_tap_action)

	_t += 1
	var dist: float = absf(enemy.global_position.x - player.global_position.x)

	match phase:
		"boot":
			if _t > 3:
				_gec("yaklas")

		# Havalandirici ve juggle karesi icin rakip menzilde olmali.
		"yaklas":
			if dist > 88.0:
				Input.action_press(&"move_right")
			else:
				Input.action_release(&"move_right")
				if player.fsm.current_name == &"Idle":
					_gec("idle")

		"idle":
			if _t == 40:
				_cek("idle")
			elif _t == 46:
				_gec("yumruk")

		"yumruk":
			_saldiri_cek(&"attack_light", "yumruk", "tekme")

		"tekme":
			_saldiri_cek(&"attack_kick", "tekme", "zipla")

		"zipla":
			if _t == 2:
				_tap(&"jump")
			elif player.fsm.current_name == &"Airborne" and not alinan.has("zipla"):
				if player.velocity.y > -260.0:  # tepeye yakin, poz otursun
					_cek("zipla")
			elif alinan.has("zipla") and player.is_on_floor() and _t > 30:
				_gec("havalandirici")

		"havalandirici":
			_saldiri_cek(&"attack_heavy", "havalandirici", "juggle")

		"juggle":
			if enemy.fsm.current_name == &"Juggle" and not alinan.has("juggle"):
				if enemy.global_position.y < -60.0:
					_cek("juggle")
			elif alinan.has("juggle") and _t > 20:
				_gec("toparlan")
			elif _t > 200:
				_gec("toparlan")

		# Rakip ayaga kalksin, sonra Grunt yakin plani ve karsilasma karesi.
		"toparlan":
			if enemy.fsm.current_name in [&"Idle", &"Run"] and _t > 20:
				_gec("grunt_idle")
			elif _t > 260:
				_gec("grunt_idle")

		"grunt_idle":
			# Kamera Grunt'a kayar - renk varyanti yakindan gorunsun.
			kam.global_position = enemy.global_position + Vector2(-14.0, -88.0)
			if _t == 30:
				_cek("grunt_idle")
			elif _t > 36:
				_gec("karsilasma")

		"karsilasma":
			# Ikisi birden: uzaklas, ortaya bak, palet ayrimi okunuyor mu?
			kam.zoom = Vector2(YAKINLIK * 0.55, YAKINLIK * 0.55)
			kam.global_position = (player.global_position + enemy.global_position) * 0.5 + Vector2(0.0, -88.0)
			if _t == 30:
				_cek("karsilasma")
			elif _t > 36:
				_gec("bitti")

		"bitti":
			if _t > 4:
				_rapor()
				get_tree().quit()

	if frames > FRAME_LIMIT:
		_rapor()
		get_tree().quit()


## Saldiriyi baslat, vurus kutusunun ACIK oldugu karede goruntu al.
func _saldiri_cek(eylem: StringName, ad: String, sonraki: String) -> void:
	if _t == 2:
		_tap(eylem)
		return
	if not alinan.has(ad) and player.fsm.current_name == &"Attack" and _kutu_acik():
		_cek(ad)
		return
	if alinan.has(ad) and player.fsm.current_name in [&"Idle", &"Run"]:
		_gec(sonraki)
	elif _t > 120:
		_gec(sonraki)


func _kutu_acik() -> bool:
	for b in player.find_children("*", "Hitbox", true, false):
		if (b as Area2D).monitoring:
			return true
	return false


func _cek(ad: String) -> void:
	if alinan.has(ad):
		return
	alinan[ad] = frames
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var hata := img.save_png(CIKIS + ad + ".png")
	print("  %-14s kare %4d  %s" % [ad + ".png", frames, "TAMAM" if hata == OK else "HATA %d" % hata])


func _tap(eylem: StringName) -> void:
	Input.action_press(eylem)
	_tap_action = eylem
	_tap_left = 3


func _gec(yeni: String) -> void:
	phase = yeni
	_t = 0


func _rapor() -> void:
	print("\n--------- ALINAN GORUNTULER ---------")
	for ad in ["idle", "yumruk", "tekme", "havalandirici", "zipla", "juggle"]:
		print("  %-14s %s" % [ad + ".png", "kare %d" % alinan[ad] if alinan.has(ad) else "ALINAMADI"])
	print("  Klasor: %s" % ProjectSettings.globalize_path(CIKIS))
	print("=======================================\n")
