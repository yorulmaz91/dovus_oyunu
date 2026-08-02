# =============================================================================
# yz_test.gd  —  Yapay zekanin otomatik dogrulamasi
#
# NE ISE YARAR: Iki bilinen YZ hatasini olcer.
#   FAZ A - BLOK: block_held eskiden tek kare suruyordu (savunma karari
#     ~0.25 sn'de bir verilirken block_held her karede sifirlaniyordu), yani
#     dusman pratikte hic blok yapamiyordu.
#   FAZ B - JUGGLE KOVALAMA: YZ hic ziplamiyordu, kendi havalandirdigi
#     rakibi kovalayamiyordu.
#
# YZ tekrar uretilebilir olsun diye tohum koddan veriliyor (rng_seed).
#
# NASIL CALISTIRILIR (komut satirindan, proje klasorunde):
#   Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/yz_test.tscn
# =============================================================================
extends Node

const TOHUM: int = 12345
## FAZ A butcesi. 10 jab bu sureden cok once biter; bu sadece tavan.
const A_LIMIT: int = 1200
## FAZ B butcesi (gorev tanimi: 3000 kare).
const B_LIMIT: int = 3000
const HEDEF_JAB: int = 10

var battle: Node
var player: Fighter
var enemy: Fighter
var hud: BattleHud

var frames: int = 0
var phase: String = "boot"
var _t: int = 0
var _b_bas: int = 0
var problems: Array[String] = []
var _reported: bool = false
var _last_tag: String = ""

# --- FAZ A olcumleri ---
var jab_atildi: int = 0
var jab_isabet: int = 0
var jab_bloklandi: int = 0
var blok_en_uzun: int = 0
var _blok_ardisik: int = 0
var blok_hit_anim_gorundu: bool = false
var _prev_enemy_health: float = 0.0
var can_takviyesi: int = 0

# --- FAZ B olcumleri ---
var oyuncu_juggle_oldu: bool = false
var yz_juggle_sirasinda_havada: bool = false
var yz_hava_tekme_isabet: int = 0
var yz_ziplama_karesi: int = -1

# --- olum akisi ---
var died_sinyali: int = 0
var olum_karesi: int = -1
var oyuncu_dead_sabit: bool = true
var ko_yazisi: String = "(yok)"
var tekrar_gorunur: bool = false


func _ready() -> void:
	print("\n=========== YZ TEST BASLIYOR ===========")
	battle = load("res://src/main/battle.tscn").instantiate()
	add_child(battle)
	CombatEvents.hit_confirmed.connect(_on_hit)
	CombatEvents.fighter_died.connect(_on_died)


func _on_died(who: Node) -> void:
	died_sinyali += 1
	print("   >>> OLUM SINYALI #%d (kare %d, %s)" % [
		died_sinyali, frames, (who as Fighter).display_name])


func _on_hit(attacker: Node, victim: Node, info: HitInfo) -> void:
	# --- FAZ A: oyuncunun jab'i dusmana degdi mi, bloklandi mi? ---
	if attacker == player and victim == enemy:
		jab_isabet += 1
		# BLOK KANITI: Fighter.take_hit blokta SADECE chip_damage uygular ve
		# durumu blocked bayragiyla Hit'e cevirir; HitState de "block_hit"
		# animasyonunu oynatir. Yani dusen can == chip_damage VE animasyon
		# block_hit ise vurus bloklanmistir. Tam hasar 5.0, chip 1.0 - hasar
		# olceklemesinin en dusuk carpani bile 5*0.3=1.5, yani 1.0 degeri
		# yalnizca bloktan gelebilir.
		var dusen: float = _prev_enemy_health - enemy.health
		var chip: float = info.data.chip_damage
		var anim_blok: bool = enemy.anim_name == &"block_hit"
		if anim_blok:
			blok_hit_anim_gorundu = true
		if is_equal_approx(dusen, chip) and anim_blok:
			jab_bloklandi += 1
			print("   >>> JAB BLOKLANDI #%d (kare %d): can %.1f -> %.1f, dusus %.1f = chip %.1f, anim %s, durum %s" % [
				jab_bloklandi, frames, _prev_enemy_health, enemy.health, dusen, chip,
				String(enemy.anim_name), String(enemy.fsm.current_name)])
		else:
			print("   >>> JAB DEGDI (kare %d): dusus %.1f (chip %.1f), anim %s" % [
				frames, dusen, chip, String(enemy.anim_name)])

	# --- FAZ B: YZ'nin havada attigi tekme oyuncuya degdi mi? ---
	if attacker == enemy and victim == player:
		if enemy.current_move != null and enemy.current_move.id == &"air_kick" \
				and not enemy.is_on_floor():
			yz_hava_tekme_isabet += 1
			print("   >>> YZ HAVA TEKMESI ISABET #%d (kare %d): yz_y %.0f, oyuncu_y %.0f, oyuncu durum %s" % [
				yz_hava_tekme_isabet, frames, enemy.global_position.y,
				player.global_position.y, String(player.fsm.current_name)])


func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 2:
		player = battle.get_node("Fighters/Lyra")
		enemy = battle.get_node("Fighters/Grunt")
		hud = battle.get_node("HUD")
		var ai: AIInput = enemy.get_node("InputSource")
		# Tekrar uretilebilirlik + en sert YZ: her iki hatayi da en net
		# gosterecek ayar.
		ai.rng_seed = TOHUM
		ai.difficulty = 1.0
		ai.passive = false
		print("YZ ayari: rng_seed=%d  difficulty=%.2f  juggle_greed=%.2f  attack_range=%.0f" % [
			ai.rng_seed, ai.difficulty, ai.juggle_greed, ai.attack_range])
		_check_setup()
		_prev_enemy_health = enemy.health
		_advance("a_blok")
		return

	if player == null:
		return

	_t += 1
	_process_tap()
	_olc()
	_trace()

	match phase:
		"a_blok":
			_faz_a()
		"b_juggle":
			_faz_b()
		"done":
			pass

	# Sonraki karede "vurustan onceki can" olarak kullanilir. Bu node
	# agacta EN USTTE oldugu icin dovusculerden ONCE calisir - yani bu deger
	# gercekten bu karedeki vuruslardan oncekidir.
	_prev_enemy_health = enemy.health

	if phase == "done" or frames > A_LIMIT + B_LIMIT:
		if not _reported:
			_reported = true
			_report()
			get_tree().quit()


## Her karede yurutulen olcumler.
func _olc() -> void:
	if enemy.input.block_held:
		_blok_ardisik += 1
		blok_en_uzun = maxi(blok_en_uzun, _blok_ardisik)
	else:
		_blok_ardisik = 0

	if player.fsm.current_name == &"Juggle":
		oyuncu_juggle_oldu = true
		# YZ ayni anda havadaysa = kendi juggle'ini kovaliyor.
		if not enemy.is_on_floor():
			if not yz_juggle_sirasinda_havada:
				yz_juggle_sirasinda_havada = true
				yz_ziplama_karesi = frames
				print("   >>> YZ ZIPLADI, JUGGLE KOVALIYOR (kare %d): yz durum %s, yz_y %.0f, oyuncu_y %.0f" % [
					frames, String(enemy.fsm.current_name), enemy.global_position.y,
					player.global_position.y])

	if olum_karesi >= 0 and player.fsm.current_name != &"Dead":
		oyuncu_dead_sabit = false


# -----------------------------------------------------------------------------
# FAZ A - BLOK SINAMASI
# -----------------------------------------------------------------------------
var _jab_cooldown: int = 0
## Son jab atildiktan sonra faz kapanmadan once beklenen kare sayisi.
var _a_bitis: int = 40


func _faz_a() -> void:
	# Blok olcumu icin oyuncunun ayakta kalmasi sart; zorluk 1.0 YZ aksi
	# halde 10 jab dolmadan nakavt edebilir. FAZ B'de takviye YOK.
	if player.health < 45.0:
		player.health = player.max_health
		player.health_changed.emit(player.health, player.max_health)
		can_takviyesi += 1

	var dist: float = absf(enemy.global_position.x - player.global_position.x)
	if dist > 95.0:
		_yuru_dogru()
	else:
		_dur()

	if jab_atildi >= HEDEF_JAB or _t > A_LIMIT:
		# Son jab'in vurusu havada kalmasin: girdi tamponu (9 kare) + jab
		# animasyonu (24 kare) bitene kadar bekle, yoksa 10. jab'in isabeti
		# FAZ B'ye tasinir ve sayaclar tutarsiz gorunur.
		_a_bitis -= 1
		if _a_bitis <= 0:
			_faz_a_bitir()
		return

	_jab_cooldown -= 1
	if _jab_cooldown > 0 or _tap_left > 0:
		return
	if not player.is_on_floor() or not player.fsm.current_name in [&"Idle", &"Run"]:
		return
	if dist > 110.0:
		return
	jab_atildi += 1
	_tap(&"attack_light")
	_jab_cooldown = 14  # araliklı: YZ'ye blok karari verecek zaman birak


func _faz_a_bitir() -> void:
	_dur()
	player.input.clear()
	print("   >>> FAZ A BITTI (kare %d): %d jab atildi, %d isabet, %d bloklandi, en uzun blok %d kare, can takviyesi %d" % [
		frames, jab_atildi, jab_isabet, jab_bloklandi, blok_en_uzun, can_takviyesi])
	# FAZ B temiz baslasin: iki taraf da tam canla, oyuncu PASIF hedef.
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	enemy.health = enemy.max_health
	enemy.health_changed.emit(enemy.health, enemy.max_health)
	_b_bas = frames
	_advance("b_juggle")


# -----------------------------------------------------------------------------
# FAZ B - JUGGLE KOVALAMA (oyuncu hicbir tusa basmaz)
# -----------------------------------------------------------------------------
func _faz_b() -> void:
	# Oyuncu tamamen pasif: hicbir tus basilmiyor, sadece izliyoruz.
	if frames - _b_bas > B_LIMIT:
		_advance("done")
		return

	if olum_karesi < 0 and player.is_dead():
		olum_karesi = frames
		ko_yazisi = _ko_yazisini_bul()
		tekrar_gorunur = hud.restart_button().visible
		print("   >>> OYUNCU OLDU (kare %d). KO yazisi: %s" % [
			frames, ko_yazisi.replace("\n", " / ")])
		print("   >>> TEKRAR dugmesi gorunur mu: %s" % tekrar_gorunur)
		return

	# Olumden sonra 90 kare daha izle (Dead'de sabit mi?), sonra bitir.
	if olum_karesi >= 0 and frames > olum_karesi + 90:
		_advance("done")


## KO etiketi battle.gd tarafindan HUD'a dogrudan cocuk olarak ekleniyor.
func _ko_yazisini_bul() -> String:
	for c in hud.get_children():
		var l := c as Label
		if l != null and l.visible and String(l.text).begins_with("NAKAVT"):
			return String(l.text)
	return "(yok)"


# -----------------------------------------------------------------------------
# Oyuncu surusu (oto_test ile ayni kalip)
# -----------------------------------------------------------------------------
var _tap_left: int = 0
var _tap_action: StringName = &""


func _tap(action: StringName) -> void:
	Input.action_press(action)
	_tap_action = action
	_tap_left = 3


func _yuru_dogru() -> void:
	if enemy.global_position.x > player.global_position.x:
		Input.action_release(&"move_left")
		Input.action_press(&"move_right")
	else:
		Input.action_release(&"move_right")
		Input.action_press(&"move_left")


func _dur() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")


func _process_tap() -> void:
	if _tap_left > 0:
		_tap_left -= 1
		if _tap_left == 0:
			Input.action_release(_tap_action)


# -----------------------------------------------------------------------------
func _check_setup() -> void:
	var ai: AIInput = enemy.get_node("InputSource")
	if not ai.has_method("_chase_juggle"):
		problems.append("AIInput'ta _chase_juggle yok - juggle kovalama eklenmemis")
	if not "rng_seed" in ai:
		problems.append("AIInput'ta rng_seed alani yok")
	# grunt.tscn'de tohum YAZILI OLMAMALI (oyunda rastgele kalsin).
	var sahne := load("res://src/characters/enemies/grunt/grunt.tscn") as PackedScene
	var taze := sahne.instantiate()
	var taze_ai = taze.get_node("InputSource")
	if taze_ai.rng_seed != 0:
		problems.append("grunt.tscn'e rng_seed yazilmis (%d) - 0 kalmaliydi" % taze_ai.rng_seed)
	taze.queue_free()


func _trace() -> void:
	var tag: String = "%s|%s|%s|%s" % [phase, String(player.fsm.current_name),
		String(enemy.fsm.current_name), enemy.input.block_held]
	if tag == _last_tag:
		return
	_last_tag = tag
	print("kare %4d | %-8s | oyuncu %-9s can %5.1f | yz %-9s can %5.1f | yz_blok %-5s | yz_y %6.1f | mesafe %5.1f" % [
		frames, phase, String(player.fsm.current_name), player.health,
		String(enemy.fsm.current_name), enemy.health, enemy.input.block_held,
		enemy.global_position.y, absf(enemy.global_position.x - player.global_position.x)])


func _advance(next_phase: String) -> void:
	phase = next_phase
	_t = 0


func _report() -> void:
	var blok_ok: bool = blok_en_uzun >= 6
	var bloklandi_ok: bool = jab_bloklandi >= 1
	var faz_a_ok: bool = blok_ok and bloklandi_ok
	var faz_b_ok: bool = oyuncu_juggle_oldu and yz_juggle_sirasinda_havada \
		and yz_hava_tekme_isabet >= 1

	print("\n--------- SONUC ---------")
	print("FAZ A - BLOK")
	print("  Atilan jab / isabet eden                         : %d / %d" % [jab_atildi, jab_isabet])
	print("  YZ blok_held en uzun ardisik kare (>=6 gerekli)  : %d   %s" % [
		blok_en_uzun, "GECTI" if blok_ok else "KALDI"])
	print("  Bloklanan jab sayisi (>=1 gerekli)               : %d   %s" % [
		jab_bloklandi, "GECTI" if bloklandi_ok else "KALDI"])
	print("  'block_hit' animasyonu goruldu mu                : %s" % (
		"EVET" if blok_hit_anim_gorundu else "HAYIR"))
	print("  FAZ A                                            : %s" % (
		"GECTI" if faz_a_ok else "KALDI"))
	print("")
	print("FAZ B - JUGGLE KOVALAMA")
	print("  YZ oyuncuyu Juggle'a soktu mu                    : %s   %s" % [
		"EVET" if oyuncu_juggle_oldu else "HAYIR", "GECTI" if oyuncu_juggle_oldu else "KALDI"])
	print("  Oyuncu Juggle'dayken YZ havalandi mi (zipladi)   : %s   %s  (ilk kare %d)" % [
		"EVET" if yz_juggle_sirasinda_havada else "HAYIR",
		"GECTI" if yz_juggle_sirasinda_havada else "KALDI", yz_ziplama_karesi])
	print("  YZ'nin havadan isabet ettirdigi air_kick (>=1)   : %d   %s" % [
		yz_hava_tekme_isabet, "GECTI" if yz_hava_tekme_isabet >= 1 else "KALDI"])
	print("  FAZ B                                            : %s" % (
		"GECTI" if faz_b_ok else "KALDI"))
	print("")
	print("NAKAVT AKISI (FAZ B sonunda oyuncu olduyse)")
	if olum_karesi < 0:
		print("  Oyuncu FAZ B icinde OLMEDI (can %.1f) - nakavt olcumleri yapilamadi" % player.health)
	else:
		print("  Olum karesi                                      : %d" % olum_karesi)
		print("  Olum sinyali kac kez yayinlandi (1 olmali)       : %d   %s" % [
			died_sinyali, "GECTI" if died_sinyali == 1 else "KALDI"])
		print("  Oyuncu Dead'de sabit kaldi mi                    : %s   %s" % [
			"EVET" if oyuncu_dead_sabit else "HAYIR",
			"GECTI" if oyuncu_dead_sabit else "KALDI"])
		print("  Oyuncunun su anki durumu                         : %s" % String(player.fsm.current_name))
		print("  KO yazisi 'DUSMAN KAZANDI' iceriyor mu           : %s   %s" % [
			"EVET" if ko_yazisi.contains("DUSMAN KAZANDI") else "HAYIR",
			"GECTI" if ko_yazisi.contains("DUSMAN KAZANDI") else "KALDI"])
		print("  KO yazisi tam metin                              : %s" % ko_yazisi.replace("\n", " / "))
		print("  TEKRAR dugmesi gorunur mu                        : %s   %s" % [
			"EVET" if tekrar_gorunur else "HAYIR", "GECTI" if tekrar_gorunur else "KALDI"])
	print("")
	print("FAZ A can takviyesi (test kolayligi, FAZ B'de yok)  : %d kez" % can_takviyesi)
	print("Bitis karesi                                       : %d" % frames)

	if not blok_ok:
		problems.append("FAZ A: YZ blogu en fazla %d kare surdu (>=6 gerekli)" % blok_en_uzun)
	if not bloklandi_ok:
		problems.append("FAZ A: hicbir jab bloklanmadi (%d isabetin hicbiri chip hasari vermedi)" % jab_isabet)
	if not oyuncu_juggle_oldu:
		problems.append("FAZ B: YZ oyuncuyu hic Juggle'a sokamadi")
	if not yz_juggle_sirasinda_havada:
		problems.append("FAZ B: YZ kendi juggle'ini kovalamak icin hic ziplamadi")
	if yz_hava_tekme_isabet < 1:
		problems.append("FAZ B: YZ havadan hic air_kick isabet ettiremedi")
	if olum_karesi >= 0:
		if died_sinyali != 1:
			problems.append("Olum sinyali %d kez yayinlandi (1 olmali)" % died_sinyali)
		if not oyuncu_dead_sabit:
			problems.append("Oyuncu olumden sonra Dead durumunda kalmadi")
		if not ko_yazisi.contains("DUSMAN KAZANDI"):
			problems.append("KO yazisi 'DUSMAN KAZANDI' icermiyor: %s" % ko_yazisi)
		if not tekrar_gorunur:
			problems.append("Nakavtta TEKRAR dugmesi gorunur olmadi")

	print("\n--------- HATALAR ---------")
	if problems.is_empty():
		print("HIC HATA YOK. YZ calisiyor.")
	else:
		for p in problems:
			print("  HATA: " + p)
	print("========================================\n")
