# =============================================================================
# oto_test.gd  —  Otomatik dogrulama testi (Godot'u acmadan calisir)
#
# NE ISE YARAR: Oyunu ekransiz baslatir, sanal bir oyuncu gibi oynar
# (yaklas > havalandir > zipla > tekme tekme tekme) ve juggle sisteminin
# gercekten calisip calismadigini rapor eder.
#
# NASIL CALISTIRILIR (komut satirindan, proje klasorunde):
#   Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/oto_test.tscn
#
# Oyunu oynamak icin buna GEREK YOK. Bu sadece bir guvenlik agi.
# =============================================================================
extends Node

const ANIMS := [
	"RESET", "idle", "run", "walk_back", "jump", "fall", "hit_light", "hit_heavy",
	"block_hit", "juggle", "juggle_fall", "knockdown", "downed", "wakeup",
	"atk_light_1", "atk_kick_1", "atk_launcher", "atk_air_kick",
]

var battle: Node
var player: Fighter
var enemy: Fighter

var frames: int = 0
var phase: String = "boot"
var kick_cooldown: int = 0
var max_juggle_seen: int = 0
var max_height_seen: float = 0.0
var reached_juggle: bool = false
var reached_knockdown: bool = false
var problems: Array[String] = []


var aerial_hits: int = 0
var total_hits: int = 0


func _ready() -> void:
	print("\n=========== OTO TEST BASLIYOR ===========")
	battle = load("res://src/main/battle.tscn").instantiate()
	add_child(battle)
	CombatEvents.hit_confirmed.connect(_on_hit)


func _on_hit(attacker: Node, victim: Node, _info: HitInfo) -> void:
	if attacker != player:
		return
	total_hits += 1
	# ASIL MEKANIK: ikisi de havadayken degen vurus.
	if not (attacker as Fighter).is_on_floor() and not (victim as Fighter).is_on_floor():
		aerial_hits += 1
		print("   >>> HAVA VURUSU! oyuncu_y %.0f  dusman_y %.0f  juggle %d" % [
			(attacker as Fighter).global_position.y,
			(victim as Fighter).global_position.y,
			(victim as Fighter).juggle_hits])


func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 2:
		player = battle.get_node("Fighters/Lyra")
		enemy = battle.get_node("Fighters/Grunt")
		enemy.get_node("InputSource").passive = true  # dusman karismasin
		_check_setup()
		phase = "approach"
		return

	if player == null:
		return

	_drive()

	max_juggle_seen = maxi(max_juggle_seen, enemy.juggle_hits)
	max_height_seen = maxf(max_height_seen, -enemy.global_position.y)
	if enemy.fsm.current_name == &"Juggle":
		reached_juggle = true
	if enemy.fsm.current_name == &"Knockdown":
		reached_knockdown = true

	if frames > 700:
		_report()
		get_tree().quit()


func _check_setup() -> void:
	for a in ANIMS:
		if not player.anim.has_animation(a):
			problems.append("Animasyon eksik: " + a)
	if player.moves.size() != 4:
		problems.append("Lyra'nin hamle sayisi 4 degil: %d" % player.moves.size())
	for m in player.moves:
		if m == null:
			problems.append("Hamle listesinde BOS kayit var")
		elif m.hit == null:
			problems.append("Hamlenin hasar karti yok: " + String(m.id))
	if player.juggle_rules == null:
		problems.append("juggle_rules bagli degil")
	var boxes := player.find_children("*", "Hitbox", true, false)
	if boxes.size() != 3:
		problems.append("Hitbox sayisi 3 degil: %d" % boxes.size())
	var hurts := player.find_children("*", "Hurtbox", true, false)
	if hurts.size() != 3:
		problems.append("Hurtbox sayisi 3 degil: %d" % hurts.size())


## Tusa 3 kare basili tut, sonra birak. Ayni karede basip birakmak
## is_action_just_pressed'i kacirir.
var _tap_left: int = 0
var _tap_action: StringName = &""
var _last_tag: String = ""


func _tap(action: StringName) -> void:
	Input.action_press(action)
	_tap_action = action
	_tap_left = 3


func _drive() -> void:
	if _tap_left > 0:
		_tap_left -= 1
		if _tap_left == 0:
			Input.action_release(_tap_action)

	var dist: float = absf(enemy.global_position.x - player.global_position.x)

	var tag: String = "%s>%s" % [String(player.fsm.current_name), String(enemy.fsm.current_name)]
	if tag != _last_tag:
		_last_tag = tag
		print("kare %4d | %-8s | oyuncu %-10s | dusman %-10s | oyuncu_y %7.1f | dusman_y %7.1f | juggle %d | can %.0f" % [
			frames, phase, String(player.fsm.current_name), String(enemy.fsm.current_name),
			player.global_position.y, enemy.global_position.y, enemy.juggle_hits, enemy.health])

	match phase:
		"approach":
			Input.action_press(&"move_right")
			if dist < 95.0:
				Input.action_release(&"move_right")
				phase = "launch"

		"launch":
			_tap(&"attack_heavy")
			phase = "wait_launch"

		"wait_launch":
			if enemy.fsm.current_name == &"Juggle":
				phase = "recover"
			elif frames > 400:
				problems.append("Havalandirici rakibi Juggle durumuna sokamadi")
				phase = "done"

		# Gercek bir oyuncu gibi: once saldiri toparlanmasini BEKLE, sonra zipla.
		"recover":
			if player.fsm.current_name in [&"Idle", &"Run"]:
				_tap(&"jump")
				phase = "chase"
				kick_cooldown = 8
			elif enemy.is_on_floor():
				problems.append("Havalandiricinin toparlanmasi cok uzun - juggle kovalanamiyor")
				phase = "done"

		"chase":
			kick_cooldown -= 1
			if kick_cooldown <= 0 and _tap_left == 0 and player.fsm.current_name != &"Attack":
				_tap(&"attack_kick")
				kick_cooldown = 10
			if enemy.is_on_floor() and enemy.fsm.current_name != &"Juggle":
				phase = "done"

		"done":
			pass


func _report() -> void:
	print("\n--------- SONUC ---------")
	print("Havalandirma calisti mi (Juggle durumuna girdi mi)? : %s" % ("EVET" if reached_juggle else "HAYIR"))
	print("En yuksek juggle puani                             : %d / %d" % [max_juggle_seen, enemy.juggle_rules.max_juggle_hits])
	print("Rakibin ulastigi en yuksek nokta                   : %.0f piksel" % max_height_seen)
	print("Sonunda yere serildi mi (Knockdown)?               : %s" % ("EVET" if reached_knockdown else "HAYIR"))
	print("Toplam isabet                                      : %d" % total_hits)
	print("Bunlarin HAVADA olani (asil mekanik)               : %d" % aerial_hits)
	print("Dusmanin kalan cani                                : %.1f / %.0f" % [enemy.health, enemy.max_health])
	print("Oyuncunun kalan cani                               : %.1f / %.0f" % [player.health, player.max_health])

	if aerial_hits < 1:
		problems.append("Lyra havadaki rakibe HAVADAYKEN hic vuramadi (ana mekanik calismiyor)")
	if max_juggle_seen < 2:
		problems.append("Juggle zinciri kurulamadi (puan 2'nin altinda kaldi)")
	if not reached_knockdown:
		problems.append("Juggle sonunda Knockdown'a gecilmedi")
	if enemy.health >= enemy.max_health:
		problems.append("Dusmana hic hasar verilmedi")

	print("\n--------- HATALAR ---------")
	if problems.is_empty():
		print("HIC HATA YOK. Sistem calisiyor.")
	else:
		for p in problems:
			print("  HATA: " + p)
	print("===========================================\n")
