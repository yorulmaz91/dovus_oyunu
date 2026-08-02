# =============================================================================
# dokunmatik_test.gd  —  Ekran dugmelerinin otomatik dogrulamasi
#
# NE ISE YARAR: Oyunu ekransiz baslatir ve GERCEK dokunus olaylari uretir
# (InputEventScreenTouch / InputEventScreenDrag). Asil kanit T2: iki parmak
# AYNI ANDA basiliyken kosarak ziplama calisiyor mu? Control tabanli Button
# ile bu yapilamiyordu, juggle mekanigi de tam olarak bunu istiyor.
#
# NASIL CALISTIRILIR (komut satirindan, proje klasorunde):
#   Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/dokunmatik_test.tscn
# =============================================================================
extends Node

## Hicbir dugmenin uzerine denk gelmeyen guvenli nokta (surukleme hedefi).
const DISARI := Vector2(640.0, 300.0)
const FRAME_LIMIT: int = 900

var battle: Node
var player: Fighter
var enemy: Fighter
var hud: BattleHud

var frames: int = 0
var phase: String = "boot"
var _t: int = 0
var problems: Array[String] = []
var _reported: bool = false
var _last_tag: String = ""

## ad -> TouchScreenButton
var btn: Dictionary = {}

# --- faz sonuclari ---
var t1_ok: bool = false
var t2_ok: bool = false
var t3_ok: bool = false
var t4_ok: bool = false
var t5_ok: bool = false
var t6_ok: bool = false

# --- ara olcumler ---
var t1_bas_x: float = 0.0
var t1_bit_x: float = 0.0
var t2_hiz_x: float = 0.0
var t3_move_id: StringName = &"-"
var t4_basladi: bool = false
var t4_surukleyince_birakti: bool = false
var t5_basiliyken: bool = false
var t5_biraktiktan_sonra: bool = true
var t6_gorunurluk: bool = false
var t6_baglanti_restart: bool = false
var t6_sayac: int = 0
var t6_gizli_sayisi: int = 0


func _ready() -> void:
	print("\n=========== DOKUNMATIK TEST BASLIYOR ===========")
	# Headless pencere 64x64 acilir ve "expand" esnetmesi viewport'u 1280x1280
	# yapar - yerlesimi telefonun gercek en-boy oraninda sinamak icin pencereyi
	# projenin taban cozunurlugune zorluyoruz. size_changed HUD'i yeniden dizer.
	get_window().size = Vector2i(1280, 720)
	battle = load("res://src/main/battle.tscn").instantiate()
	add_child(battle)


func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 2:
		player = battle.get_node("Fighters/Lyra")
		enemy = battle.get_node("Fighters/Grunt")
		hud = battle.get_node("HUD")
		enemy.get_node("InputSource").passive = true  # dusman karismasin
		_collect_buttons()
		_check_setup()
		_advance("t1")
		return

	if player == null:
		return

	_t += 1
	_trace()

	match phase:
		# --- T1: TEK DOKUNUS -------------------------------------------------
		# index 0 ile ">" tusuna bas ve TUT. Oyuncu kosmali ve saga gitmeli.
		"t1":
			if _t == 1:
				t1_bas_x = player.global_position.x
				_touch(0, _center("BtnSag"), true)
			elif _t == 24:
				t1_bit_x = player.global_position.x
				t1_ok = player.fsm.current_name == &"Run" and t1_bit_x > t1_bas_x + 20.0
				_advance("t2")

		# --- T2: COKLU DOKUNUS (ASIL KANIT) ----------------------------------
		# index 0 hala ">" uzerinde BASILIYKEN index 1 ile ZIPLA'ya bas.
		# Havada yatay hiz korunuyorsa iki parmak da ayni anda okunuyor demektir.
		"t2":
			if _t == 1:
				_touch(1, _center("BtnZipla"), true)
			elif _t > 1:
				if player.fsm.current_name == &"Airborne":
					t2_hiz_x = maxf(t2_hiz_x, player.velocity.x)
					if player.velocity.x > 60.0:
						t2_ok = true
				if _t == 22:
					_advance("t3")

		# --- T3: UCUNCU GIRDI ------------------------------------------------
		# index 1'i birak, ayni parmakla TEKME'ye bas. index 0 hala ">"da.
		"t3":
			if _t == 1:
				_touch(1, _center("BtnZipla"), false)
			elif _t == 3:
				_touch(1, _center("BtnTekme"), true)
			elif _t > 3:
				if player.fsm.current_name == &"Attack" and player.current_move != null:
					t3_move_id = player.current_move.id
					if t3_move_id == &"air_kick":
						t3_ok = true
				if _t == 26:
					_touch(1, _center("BtnTekme"), false)
					_advance("t4")

		# --- T4: SURUKLEME GUVENLIGI -----------------------------------------
		# index 0'i dugmenin DISINA surukle, sonra parmagi kaldir.
		"t4":
			if not t4_basladi:
				if player.is_on_floor():
					t4_basladi = true
					_t = 0
				return
			if _t == 4:
				_drag(0, DISARI)
			elif _t == 8:
				t4_surukleyince_birakti = not Input.is_action_pressed(&"move_right")
				_touch(0, DISARI, false)
			elif _t == 16:
				t4_ok = t4_surukleyince_birakti \
					and not Input.is_action_pressed(&"move_right") \
					and is_zero_approx(player.input.move_x) \
					and player.fsm.current_name == &"Idle"
				_advance("t5")

		# --- T5: BLOK --------------------------------------------------------
		"t5":
			if _t == 1:
				_touch(0, _center("BtnBlok"), true)
			elif _t == 6:
				t5_basiliyken = player.input.block_held
			elif _t == 8:
				_touch(0, _center("BtnBlok"), false)
			elif _t == 14:
				t5_biraktiktan_sonra = player.input.block_held
				t5_ok = t5_basiliyken and not t5_biraktiktan_sonra
				_advance("t6")

		# --- T6: NAKAVT AKISI ------------------------------------------------
		"t6":
			if _t == 1:
				# Ayirmadan ONCE: sinyal gercekten battle._restart'a mi gidiyor?
				for c in btn["BtnTekrar"].pressed.get_connections():
					var cb: Callable = c["callable"]
					if cb.get_object() == battle and cb.get_method() == &"_restart":
						t6_baglanti_restart = true
				print("   >>> BtnTekrar.pressed -> battle._restart bagli mi: %s" % (
					"EVET" if t6_baglanti_restart else "HAYIR"))
			elif _t == 2:
				enemy.invuln_timer = 0.0
				enemy.health = 1.0
				var probe := HitInfo.make(player.moves[0].hit, player, player, player.facing)
				enemy.take_hit(probe)
				print("   >>> DUSMAN OLDURULDU (kare %d) - durum %s" % [
					frames, String(enemy.fsm.current_name)])
			elif _t == 8:
				t6_gizli_sayisi = 0
				for ad in btn.keys():
					if ad != "BtnTekrar" and not (btn[ad] as TouchScreenButton).visible:
						t6_gizli_sayisi += 1
				t6_gorunurluk = t6_gizli_sayisi == 7 and btn["BtnTekrar"].visible
				print("   >>> Gizlenen oyun dugmesi: %d/7   TEKRAR gorunur mu: %s" % [
					t6_gizli_sayisi, btn["BtnTekrar"].visible])
				# Gercek reload olmasin diye sinyali kendi sayacimiza aliyoruz;
				# aksi halde test sahnesi sonsuz doner.
				if t6_baglanti_restart:
					btn["BtnTekrar"].pressed.disconnect(Callable(battle, "_restart"))
				btn["BtnTekrar"].pressed.connect(_on_tekrar)
			elif _t == 12:
				_touch(0, _center("BtnTekrar"), true)
			elif _t == 16:
				_touch(0, _center("BtnTekrar"), false)
			elif _t == 20:
				t6_ok = t6_baglanti_restart and t6_gorunurluk and t6_sayac == 1
				_advance("done")

		"done":
			pass

	if phase == "done" or frames > FRAME_LIMIT:
		if not _reported:
			_reported = true
			_report()
			get_tree().quit()


func _on_tekrar() -> void:
	t6_sayac += 1
	print("   >>> TEKRAR dugmesine basildi (sayac %d)" % t6_sayac)


# -----------------------------------------------------------------------------
# Dokunus uretimi
# -----------------------------------------------------------------------------
func _touch(index: int, canvas_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _ekran(canvas_pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, canvas_pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _ekran(canvas_pos)
	Input.parse_input_event(ev)


## Olay konumu EKRAN (pencere) uzayinda beklenir: Viewport.push_input onu
## get_final_transform().affine_inverse() ile canvas uzayina cevirir. Bu adim
## atlanirsa esnetme uygulanan her cozunurlukte dokunuslar isabetsiz olur.
func _ekran(canvas_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_pos


## TouchScreenButton'da dokunun SOL UST kosesi node konumundadir; dokunma
## alani da doku dikdortgenidir. Merkez bu yuzden konum + yariçap.
func _center(ad: String) -> Vector2:
	var b: TouchScreenButton = btn[ad]
	return b.get_global_transform_with_canvas() * (b.texture_normal.get_size() * 0.5)


func _rect(ad: String) -> Rect2:
	var b: TouchScreenButton = btn[ad]
	var sz: Vector2 = b.texture_normal.get_size()
	return Rect2(b.get_global_transform_with_canvas() * Vector2.ZERO, sz)


# -----------------------------------------------------------------------------
func _collect_buttons() -> void:
	for n in get_tree().get_nodes_in_group(&"dokunmatik_dugme"):
		btn[String(n.name)] = n


func _check_setup() -> void:
	var beklenen := ["BtnSol", "BtnSag", "BtnBlok", "BtnYumruk", "BtnTekme",
		"BtnHavalandir", "BtnZipla", "BtnTekrar"]
	if btn.size() != 8:
		problems.append("'dokunmatik_dugme' grubunda 8 dugme yok: %d" % btn.size())
	for ad in beklenen:
		if not btn.has(ad):
			problems.append("Dugme eksik: " + ad)
			return
		var b = btn[ad]
		if not (b is TouchScreenButton):
			problems.append("%s TouchScreenButton degil: %s" % [ad, b.get_class()])
		elif b.texture_normal == null or b.texture_pressed == null:
			problems.append("%s dokusu eksik (normal/pressed)" % ad)
		# passby_press SADECE yon tuslarinda acik olmali: parmak kayinca
		# yuruyus birakilsin ama kayarak HAVALANDIR'a girilemesin.
		elif b.passby_press != (ad in ["BtnSol", "BtnSag"]):
			problems.append("%s passby_press yanlis: %s" % [ad, b.passby_press])

	if btn["BtnTekrar"].action != &"":
		problems.append("BtnTekrar'in action'i olmamali: %s" % btn["BtnTekrar"].action)
	if btn["BtnTekrar"].visible:
		problems.append("BtnTekrar baslangicta gorunur olmamali")
	for ad in beklenen:
		if ad != "BtnTekrar" and btn[ad].action == &"":
			problems.append("%s icin action tanimli degil" % ad)

	# --- yerlesim ---
	var vs: Vector2 = get_viewport().get_visible_rect().size
	print("Viewport: %s" % vs)
	for ad in beklenen:
		var r: Rect2 = _rect(ad)
		print("  %-14s merkez %s  cap %.0f" % [ad, _center(ad), r.size.x])
		# 0.5 px tolerans: kenara TAM oturan dugmeler kayan nokta yuzunden
		# yanlislikla hata saymasin.
		if r.position.x < 23.5 or r.position.y < 23.5 \
				or r.end.x > vs.x - 23.5 or r.end.y > vs.y - 23.5:
			problems.append("%s ekran kenarina 24 px'den yakin: %s" % [ad, r])
		# Can barlari ust 74 px'i kullanir.
		if r.position.y < 90.0:
			problems.append("%s can barlariyla cakisiyor (ust kenar %.0f)" % [ad, r.position.y])

	for i in beklenen.size():
		for j in range(i + 1, beklenen.size()):
			var a: String = beklenen[i]
			var b2: String = beklenen[j]
			var cap: float = maxf(_rect(a).size.x, _rect(b2).size.x)
			var d: float = _center(a).distance_to(_center(b2))
			if d < cap * 1.2:
				problems.append("%s ile %s cok yakin: %.1f px (en az %.1f gerekli)" % [
					a, b2, d, cap * 1.2])


func _trace() -> void:
	var tag: String = "%s|%s|%s" % [phase, String(player.fsm.current_name),
		String(enemy.fsm.current_name)]
	if tag == _last_tag:
		return
	_last_tag = tag
	print("kare %4d | %-5s | oyuncu %-9s | x %7.1f | vx %7.1f | move_x %4.1f | blok %s | dusman %s" % [
		frames, phase, String(player.fsm.current_name), player.global_position.x,
		player.velocity.x, player.input.move_x, player.input.block_held,
		String(enemy.fsm.current_name)])


func _advance(next_phase: String) -> void:
	phase = next_phase
	_t = 0


func _report() -> void:
	print("\n--------- SONUC ---------")
	print("T1 TEK DOKUNUS      (BtnSag basili -> Run + saga hareket)   : %s  (durum %s, x %.1f -> %.1f)" % [
		"GECTI" if t1_ok else "KALDI", String(player.fsm.current_name), t1_bas_x, t1_bit_x])
	print("T2 COKLU DOKUNUS    (BtnSag + BtnZipla -> Airborne, vx>60)  : %s  (havada en yuksek vx %.1f)" % [
		"GECTI" if t2_ok else "KALDI", t2_hiz_x])
	print("T3 UCUNCU GIRDI     (havada BtnTekme -> air_kick)           : %s  (hamle %s)" % [
		"GECTI" if t3_ok else "KALDI", String(t3_move_id)])
	print("T4 SURUKLEME        (disari surukle + birak -> Idle, 0)     : %s  (surukleyince birakti mi: %s)" % [
		"GECTI" if t4_ok else "KALDI", "EVET" if t4_surukleyince_birakti else "HAYIR"])
	print("T5 BLOK             (BtnBlok -> block_held true/false)      : %s  (basiliyken %s, biraktiktan sonra %s)" % [
		"GECTI" if t5_ok else "KALDI", t5_basiliyken, t5_biraktiktan_sonra])
	print("T6 NAKAVT AKISI     (7 dugme gizli, TEKRAR gorunur+calisir) : %s" % (
		"GECTI" if t6_ok else "KALDI"))
	print("     - BtnTekrar.pressed baslangicta battle._restart'a bagli : %s" % (
		"EVET" if t6_baglanti_restart else "HAYIR"))
	print("     - Nakavtta gizlenen oyun dugmesi                        : %d / 7" % t6_gizli_sayisi)
	print("     - TEKRAR gorunur                                        : %s" % btn["BtnTekrar"].visible)
	print("     - TEKRAR'a dokununca sinyal sayaci                      : %d  (1 olmali)" % t6_sayac)
	print("Bitis karesi                                                : %d" % frames)

	if not t1_ok:
		problems.append("T1: tek dokunusla yuruyus calismadi")
	if not t2_ok:
		problems.append("T2: COKLU DOKUNUS calismadi - kosarak ziplama yapilamadi (havada vx %.1f)" % t2_hiz_x)
	if not t3_ok:
		problems.append("T3: havada ucuncu girdi ile hava tekmesi yapilamadi (hamle %s)" % String(t3_move_id))
	if not t4_surukleyince_birakti:
		problems.append("T4: parmak dugmenin DISINA suruklendiginde move_right birakilmadi")
	if not t4_ok:
		problems.append("T4: surukleme guvenligi saglanmadi (birakma / move_x 0 / Idle)")
	if not t5_ok:
		problems.append("T5: BLOK dugmesi block_held'i dogru surmedi")
	if not t6_ok:
		problems.append("T6: nakavt akisi (dugme gizleme / TEKRAR) calismadi")

	print("\n--------- HATALAR ---------")
	if problems.is_empty():
		print("HIC HATA YOK. Dokunmatik kume calisiyor.")
	else:
		for p in problems:
			print("  HATA: " + p)
	print("===============================================\n")
