# =============================================================================
# ses_test.gd  —  Ses sisteminin otomatik dogrulamasi
#
# KANIT KAYNAGI: SesCalar.son_calinanlar halka kaydi.
# player.playing bayragina GUVENMIYORUZ - headless'ta ses surucusu sahtedir
# ve bayrak yaniltici olabilir. "Hangi ses, hangi karede calindi" bilgisi
# ise gercek koddan gelir.
#
# NASIL CALISTIRILIR (komut satirindan, proje klasorunde):
#   Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/ses_test.tscn
# =============================================================================
extends Node

const FRAME_LIMIT: int = 1800
const SFX := "res://assets/sfx/"
const BEKLENEN_WAV := [
	"savurma.wav", "vurus_hafif.wav", "vurus_orta.wav", "vurus_agir.wav",
	"vurus_hava.wav", "blok.wav", "zipla.wav", "yere_dusme.wav", "nakavt.wav",
]

var battle: Node
var player: Fighter
var enemy: Fighter

var frames: int = 0
var phase: String = "boot"
var _t: int = 0
var _faz_kare: int = 0
var problems: Array[String] = []
var _reported: bool = false
var _last_tag: String = ""

# --- faz sonuclari ---
var a_ok: bool = false      # iskalayan launcher: savurma var, vurus_agir yok
var b_ok: bool = false      # jab: savurma -> vurus_hafif sirasiyla
var c_ok: bool = false      # blok: blok var, vurus_hafif yok
var d_ok: bool = false      # normal ziplama
var e_ok: bool = false      # ziplama iptali
var f_ok: bool = false      # yere serilme
var g_ok: bool = false      # nakavt tam 1 + ceset sessiz
var h_ok: bool = false      # tasma

# --- ara olcumler ---
var a_sesler: Array = []
var b_sesler: Array = []
var c_sesler: Array = []
var d_sesler: Array = []
var e_sesler: Array = []
var f_sesler: Array = []
var nakavt_sayisi: int = 0
var olum_sonrasi_donuk_kayit: int = -1
var olum_sonrasi_cesede_vurus: Array = []
var h_kayit: int = -1
var yapisal_satirlar: Array = []

var _launch_tapped: bool = false
var _zipla_denendi: bool = false


func _ready() -> void:
	print("\n=========== SES TESTI BASLIYOR ===========")
	battle = load("res://src/main/battle.tscn").instantiate()
	add_child(battle)
	CombatEvents.hit_confirmed.connect(_on_hit)
	CombatEvents.fighter_died.connect(func(_w): nakavt_sayisi += 1)


func _on_hit(attacker: Node, _victim: Node, info: HitInfo) -> void:
	# Ziplama iptali fazinda: havalandirici degdigi ANDA W'ye bas.
	if phase == "e_iptal" and attacker == player \
			and info.data.reaction == HitData.Reaction.LAUNCH and not _launch_tapped:
		_launch_tapped = true
		_tap(&"jump")


# =============================================================================
func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 2:
		player = battle.get_node("Fighters/Lyra")
		enemy = battle.get_node("Fighters/Grunt")
		enemy.get_node("InputSource").passive = true
		_yapisal_kontrol()
		_advance("a_whiff")
		return

	if player == null:
		return

	_t += 1
	_process_tap()
	_trace()

	match phase:
		# --- A: ISKALAYAN LAUNCHER -> savurma VAR, vurus_agir YOK -----------
		# Rakip 300 px uzakta; kutu acilir ama kimseye degmez.
		"a_whiff":
			if _t == 2:
				_tap(&"attack_heavy")
			elif _t == 45:
				a_sesler = _sesler(_faz_kare)
				a_ok = a_sesler.has("savurma.wav") and not a_sesler.has("vurus_agir.wav")
				_advance("b_jab")

		# --- B: ISABET EDEN JAB -> savurma SONRA vurus_hafif ----------------
		"b_jab":
			var d1: float = absf(enemy.global_position.x - player.global_position.x)
			if d1 > 90.0:
				_yuru_dogru()
				return
			_dur()
			if _t < 4:
				return
			if not _vurdu_mu("b"):
				if player.fsm.current_name in [&"Idle", &"Run"] and _tap_left == 0:
					_tap(&"attack_light")
				return
			b_sesler = _sesler(_faz_kare)
			b_ok = _sirali(b_sesler, "savurma.wav", "vurus_hafif.wav")
			_advance("c_blok")

		# --- C: BLOKLANAN JAB -> blok VAR, vurus_hafif YOK ------------------
		"c_blok":
			if _t == 1:
				# YZ'yi tamamen durdurup blogu ELLE aciyoruz: _poll her karede
				# block_held'i yeniden yazdigi icin tek yol bu.
				enemy.input.set_physics_process(false)
				enemy.input.block_held = true
				enemy.input.move_x = 0.0
				player.input.clear()
				return
			var d2: float = absf(enemy.global_position.x - player.global_position.x)
			if d2 > 90.0:
				_yuru_dogru()
				return
			_dur()
			if not _vurdu_mu("c"):
				if player.fsm.current_name in [&"Idle", &"Run"] and _tap_left == 0:
					_tap(&"attack_light")
				return
			c_sesler = _sesler(_faz_kare)
			c_ok = c_sesler.has("blok.wav") and not c_sesler.has("vurus_hafif.wav")
			enemy.input.block_held = false  # bundan sonraki vuruslar gecsin
			_advance("d_zipla")

		# --- D: NORMAL ZIPLAMA (Idle) -> zipla ------------------------------
		"d_zipla":
			# Oyuncu jab'in ORTASINDA olabilir; jab jump_cancel'siz oldugu icin
			# erken basilan W tamponda soner. Once Idle'a donmesini bekle.
			if not _zipla_denendi:
				if player.fsm.current_name == &"Idle" and player.is_on_floor() and _tap_left == 0:
					_zipla_denendi = true
					_faz_kare = Engine.get_physics_frames() + 1
					_tap(&"jump")
				elif _t > 200:
					_advance("e_iptal")
				return
			if player.fsm.current_name == &"Airborne" and not d_ok:
				d_sesler = _sesler(_faz_kare)
				d_ok = d_sesler.has("zipla.wav")
			if d_ok and player.is_on_floor():
				_advance("e_iptal")
			elif _t > 200:
				_advance("e_iptal")

		# --- E: ZIPLAMA IPTALI (AttackState) -> zipla -----------------------
		"e_iptal":
			var d3: float = absf(enemy.global_position.x - player.global_position.x)
			if not _launch_tapped:
				if d3 > 90.0:
					_yuru_dogru()
					return
				_dur()
				if player.fsm.current_name in [&"Idle", &"Run"] and _tap_left == 0:
					_tap(&"attack_heavy")
				return
			if player.fsm.current_name == &"Airborne":
				e_sesler = _sesler(_faz_kare)
				e_ok = e_sesler.has("zipla.wav")
				_advance("f_dusme")
			elif _t > 260:
				_advance("f_dusme")

		# --- F: YERE SERILME -> yere_dusme ----------------------------------
		"f_dusme":
			if enemy.fsm.current_name == &"Knockdown":
				f_sesler = _sesler(_faz_kare)
				f_ok = f_sesler.has("yere_dusme.wav")
				_advance("g_ko")
			elif _t > 260:
				f_sesler = _sesler(_faz_kare)
				_advance("g_ko")

		# --- G: NAKAVT -> nakavt TAM 1, sonrasinda ceset sessiz -------------
		"g_ko":
			_ko_fazi()

		# --- H: TASMA -> ayni karede 12 cal(), hata yok, kayit 12 -----------
		"h_tasma":
			if _t == 2:
				var s: AudioStream = load(SFX + "blok.wav")
				var oncesi: int = SesCalar.son_calinanlar.size()
				for i in 12:
					SesCalar.cal(s, -40.0)
				h_kayit = _sesler(Engine.get_physics_frames()).size()
				h_ok = h_kayit == 12 and SesCalar.son_calinanlar.size() >= oncesi
				print("   >>> TASMA: 12 cal() cagrisi, ayni karede kayit = %d (havuz %d oyuncu)" % [
					h_kayit, SesCalar.HAVUZ])
				_advance("done")

		"done":
			pass

	if phase == "done" or frames > FRAME_LIMIT:
		if not _reported:
			_reported = true
			_report()
			get_tree().quit()


# --- G fazi ayrintili ---------------------------------------------------------
var _g_adim: int = 0
var _olum_kare: int = 0


func _ko_fazi() -> void:
	match _g_adim:
		0:
			# Dusman ayaga kalksin, sonra tek vurusla olsun.
			if enemy.fsm.current_name in [&"Idle", &"Run"] and enemy.invuln_timer <= 0.0:
				enemy.health = 3.0
				enemy.health_changed.emit(enemy.health, enemy.max_health)
				_g_adim = 1
			elif _t > 300:
				problems.append("G: dusman ayaga kalkmadi, nakavt denenemedi")
				_advance("h_tasma")
		1:
			var d: float = absf(enemy.global_position.x - player.global_position.x)
			if d > 90.0:
				_yuru_dogru()
				return
			_dur()
			if enemy.is_dead():
				_olum_kare = Engine.get_physics_frames()
				print("   >>> DUSMAN OLDU (kare %d). Kazanan girdisi kapali mi: %s" % [
					frames, not player.input.is_physics_processing()])
				_g_adim = 2
				_t = 0
				return
			if player.fsm.current_name in [&"Idle", &"Run"] and _tap_left == 0:
				_tap(&"attack_light")
		2:
			# G1: gercek oyun davranisi - kazanan donuk, hicbir yeni ses YOK.
			if _t == 60:
				olum_sonrasi_donuk_kayit = _sesler(_olum_kare + 1).size()
				print("   >>> Olumden sonra (kazanan donuk) 60 karede yeni kayit: %d" % olum_sonrasi_donuk_kayit)
				# G2: girdiyi GECICI acip cesede vuruyoruz - darbe sesi
				# CIKMAMALI (savurma cikar, o saldirana ait).
				player.input.set_physics_process(true)
				_faz_kare = Engine.get_physics_frames()
				_g_adim = 3
				_t = 0
		3:
			if _t < 90:
				if player.fsm.current_name in [&"Idle", &"Run"] and _tap_left == 0:
					_tap(&"attack_light")
				return
			olum_sonrasi_cesede_vurus = _sesler(_faz_kare)
			var darbe_var: bool = false
			for s in olum_sonrasi_cesede_vurus:
				if String(s).begins_with("vurus_") or s == "nakavt.wav":
					darbe_var = true
			g_ok = nakavt_sayisi == 1 and olum_sonrasi_donuk_kayit == 0 and not darbe_var
			print("   >>> Cesede vurus denemesi sesleri: %s" % [olum_sonrasi_cesede_vurus])
			_advance("h_tasma")


# =============================================================================
# YAPISAL KONTROLLER
# =============================================================================
func _yapisal_kontrol() -> void:
	# --- 9 WAV var ve gecerli mi? ---
	for ad in BEKLENEN_WAV:
		var yol: String = SFX + ad
		var ham := FileAccess.get_file_as_bytes(yol)
		if ham.size() < 44:
			problems.append("Ses dosyasi yok/bozuk: " + ad)
			continue
		var riff: String = ham.slice(0, 4).get_string_from_ascii()
		var wave: String = ham.slice(8, 12).get_string_from_ascii()
		var akis := load(yol) as AudioStream
		if riff != "RIFF" or wave != "WAVE":
			problems.append("%s RIFF/WAVE basligi yok (%s/%s)" % [ad, riff, wave])
		if akis == null:
			problems.append("%s yuklenemedi" % ad)
			continue
		var sure: float = akis.get_length()
		if sure < 0.02 or sure > 1.0:
			problems.append("%s suresi araligin disinda: %.3f sn" % [ad, sure])
		var veri: int = (akis as AudioStreamWAV).data.size() if akis is AudioStreamWAV else 0
		if veri <= 0:
			problems.append("%s ses verisi bos" % ad)
		yapisal_satirlar.append("  %-18s %s/%s  %6.3f sn  %7d bayt veri  %8d bayt dosya" % [
			ad, riff, wave, sure, veri, ham.size()])

	# --- varsayilan_sesler.tres dolu mu? ---
	var set_res := load("res://data/audio/varsayilan_sesler.tres") as SesSeti
	if set_res == null:
		problems.append("varsayilan_sesler.tres yuklenemedi")
	else:
		for alan in ["blok", "nakavt", "zipla", "yere_dusme"]:
			if set_res.get(alan) == null:
				problems.append("varsayilan_sesler.tres '%s' alani bos" % alan)

	# --- dort hamlede swing_sfx + hit_sfx dolu mu? ---
	for m: MoveDef in player.moves:
		if m == null:
			continue
		if m.swing_sfx == null:
			problems.append("%s hamlesinde swing_sfx bos" % m.id)
		if m.hit == null or m.hit.hit_sfx == null:
			problems.append("%s hamlesinde hit_sfx bos" % m.id)

	# --- SesCalar autoload ve havuz ---
	var sc := get_node_or_null("/root/SesCalar")
	if sc == null:
		problems.append("SesCalar autoload'da yok")
	else:
		var oyuncular := 0
		var yanlis_bus := 0
		for c in sc.get_children():
			if c is AudioStreamPlayer:
				oyuncular += 1
				if (c as AudioStreamPlayer).bus != &"SFX":
					yanlis_bus += 1
		if oyuncular != 8:
			problems.append("SesCalar havuzu 8 degil: %d" % oyuncular)
		if yanlis_bus > 0:
			problems.append("%d oyuncu 'SFX' bus'inda degil" % yanlis_bus)
		yapisal_satirlar.append("  SesCalar havuzu: %d oyuncu, hepsi SFX bus'inda: %s" % [
			oyuncular, yanlis_bus == 0])
	# --- bus duzeni ---
	yapisal_satirlar.append("  Ses katmanlari: %s" % [
		range(AudioServer.bus_count).map(func(i): return String(AudioServer.get_bus_name(i)))])


# =============================================================================
# Yardimcilar
# =============================================================================
## Faz basindan bu yana calinan seslerin adlari, SIRAYLA.
func _sesler(baslangic_kare: int) -> Array:
	var r := []
	for k in SesCalar.son_calinanlar:
		if int(k["kare"]) >= baslangic_kare:
			r.append(String(k["ses"]))
	return r


## a sesi, b sesinden ONCE calindi mi? (ikisi de olmali)
func _sirali(liste: Array, a: String, b: String) -> bool:
	var ia: int = liste.find(a)
	var ib: int = liste.find(b)
	return ia >= 0 and ib >= 0 and ia < ib


var _vurus_izi: Dictionary = {}


## Bu fazda dusmana vurus degdi mi? (hit_confirmed yerine can dususu izlenir)
func _vurdu_mu(faz: String) -> bool:
	if not _vurus_izi.has(faz):
		_vurus_izi[faz] = enemy.health
		return false
	return enemy.health < float(_vurus_izi[faz]) - 0.001


var _tap_left: int = 0
var _tap_action: StringName = &""


func _tap(action: StringName) -> void:
	Input.action_press(action)
	_tap_action = action
	_tap_left = 3


func _process_tap() -> void:
	if _tap_left > 0:
		_tap_left -= 1
		if _tap_left == 0:
			Input.action_release(_tap_action)


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


func _advance(next_phase: String) -> void:
	phase = next_phase
	_t = 0
	_faz_kare = Engine.get_physics_frames() + 1


func _trace() -> void:
	var tag: String = "%s|%s|%s" % [phase, String(player.fsm.current_name),
		String(enemy.fsm.current_name)]
	if tag == _last_tag:
		return
	_last_tag = tag
	print("kare %4d | %-8s | oyuncu %-9s | dusman %-9s can %5.1f | mesafe %5.1f" % [
		frames, phase, String(player.fsm.current_name), String(enemy.fsm.current_name),
		enemy.health, absf(enemy.global_position.x - player.global_position.x)])


# =============================================================================
func _report() -> void:
	print("\n--------- YAPISAL ---------")
	for s in yapisal_satirlar:
		print(s)

	print("\n--------- SONUC ---------")
	print("a) Iskalayan launcher (savurma VAR, vurus_agir YOK) : %s  %s" % [
		"GECTI" if a_ok else "KALDI", a_sesler])
	print("b) Isabet eden jab (savurma -> vurus_hafif sirali)  : %s  %s" % [
		"GECTI" if b_ok else "KALDI", b_sesler])
	print("c) Bloklanan jab (blok VAR, vurus_hafif YOK)        : %s  %s" % [
		"GECTI" if c_ok else "KALDI", c_sesler])
	print("d) Normal ziplama (Idle) -> zipla                   : %s  %s" % [
		"GECTI" if d_ok else "KALDI", d_sesler])
	print("e) Ziplama iptali (AttackState) -> zipla            : %s  %s" % [
		"GECTI" if e_ok else "KALDI", e_sesler])
	print("f) Yere serilme (Knockdown) -> yere_dusme           : %s  %s" % [
		"GECTI" if f_ok else "KALDI", f_sesler])
	print("g) Nakavt + ceset sessizligi                        : %s" % ("GECTI" if g_ok else "KALDI"))
	print("     - nakavt sinyali sayisi (1 olmali)              : %d" % nakavt_sayisi)
	print("     - olumden sonra 60 kare yeni kayit (kazanan donuk): %d  (0 olmali)" % olum_sonrasi_donuk_kayit)
	print("     - girdi acilip cesede vurulunca cikan sesler    : %s" % [olum_sonrasi_cesede_vurus])
	print("       (savurma BEKLENIR - o saldirana ait; vurus_* ve nakavt BEKLENMEZ)")
	print("h) Tasma: ayni karede 12 cal()                      : %s  (kayit %d, hata yok)" % [
		"GECTI" if h_ok else "KALDI", h_kayit])
	print("Bitis karesi                                        : %d" % frames)

	if not a_ok:
		problems.append("a: iskalayan launcher'da savurma yok ya da vurus_agir sizdi")
	if not b_ok:
		problems.append("b: jab isabetinde savurma -> vurus_hafif sirasi olusmadi")
	if not c_ok:
		problems.append("c: bloklu vurusta blok sesi yok ya da darbe sesi de caldi")
	if not d_ok:
		problems.append("d: normal ziplamada zipla sesi calmadi")
	if not e_ok:
		problems.append("e: ziplama iptalinde zipla sesi calmadi")
	if not f_ok:
		problems.append("f: yere serilmede yere_dusme sesi calmadi")
	if nakavt_sayisi != 1:
		problems.append("g: nakavt sesi %d kez caldi (1 olmali)" % nakavt_sayisi)
	if olum_sonrasi_donuk_kayit != 0:
		problems.append("g: olumden sonra (kazanan donukken) %d yeni ses caldi" % olum_sonrasi_donuk_kayit)
	if not g_ok:
		problems.append("g: nakavt / ceset sessizligi olcutu saglanmadi")
	if not h_ok:
		problems.append("h: tasma sinamasi basarisiz (kayit %d, 12 bekleniyordu)" % h_kayit)

	print("\n--------- HATALAR ---------")
	if problems.is_empty():
		print("HIC HATA YOK. Ses sistemi calisiyor.")
	else:
		for p in problems:
			print("  HATA: " + p)
	print("==========================================\n")
