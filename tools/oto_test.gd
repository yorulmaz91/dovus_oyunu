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

# --- Ziplama iptali olcumu ---
## Havalandiricinin degdigi kare.
var launch_hit_frame: int = -1
## Oyuncunun Airborne'a gectigi kare. Aradaki fark = iptalin gecikmesi.
var jump_cancel_frame: int = -1
## Iptalden sonra acik kalan hitbox var mi? (olmamali)
var hitbox_open_after_cancel: bool = false
var _box_watch: int = 0

## Bosa sallanan (whiff) launcher ziplamayla iptal EDILEMEDI mi? (edilememeli)
var whiff_immune: bool = false
var _whiff_t: int = 0
var _whiff_saw_attack: bool = false

# --- NAKAVT (KO) olcumleri ---
## Kac karede sonra pes edilir. Nakavt fazi yerden dovusmek zorunda oldugu
## icin ilk fazlardan cok daha uzun surer.
const FRAME_LIMIT: int = 3000

## CombatEvents.fighter_died KAC KEZ yayildi? Tam 1 olmali.
var died_signal_count: int = 0
## Dusmanin oldugu kare (-1 = daha olmedi).
var death_frame: int = -1
# --- olum anindaki fotograf; sonrasinda hicbiri degismemeli ---
var health_at_death: float = -1.0
var combo_at_death: int = -1
var hits_at_death: int = 0
var died_count_at_death: int = 0
## Olumden sonra dusman HER karede Dead durumunda kaldi mi?
var stayed_dead: bool = true
## Olumden sonra cesetin bir hitbox'i acildi mi? (acilmamali)
var corpse_hitbox_open: bool = false
## battle.gd kazananin girdisini gercekten dondurdu mu?
var winner_frozen: bool = false
## Cesede DOGRUDAN yapilan take_hit denemesi reddedildi mi?
var corpse_take_hit_rejected: bool = false
## Olumden sonra oyuncunun yaptigi saldiri sayisi (2 olmali).
var post_death_attacks: int = 0

## Nakavt fazinda sirayla basilan tuslar: J -> L -> K.
var _ko_order: Array[StringName] = [&"attack_light", &"attack_kick", &"attack_heavy"]
var _ko_index: int = 0
var _ko_cooldown: int = 0
var _probe_done: bool = false
var _reported: bool = false


func _ready() -> void:
	print("\n=========== OTO TEST BASLIYOR ===========")
	battle = load("res://src/main/battle.tscn").instantiate()
	add_child(battle)
	CombatEvents.hit_confirmed.connect(_on_hit)
	CombatEvents.fighter_died.connect(_on_fighter_died)


## Olum sinyalinin KAC KEZ yayildigini sayar. Duzeltmeden once olumden
# sonraki her isabet bunu tekrar tetikliyordu.
func _on_fighter_died(who: Node) -> void:
	died_signal_count += 1
	print("   >>> OLUM SINYALI #%d  (kare %d, %s)" % [
		died_signal_count, frames, (who as Fighter).display_name])


func _on_hit(attacker: Node, victim: Node, info: HitInfo) -> void:
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

	# ZIPLAMA IPTALI: havalandirici degdigi ANDA W'ye bas. Girdi tamponu
	# (0.15 sn) basisi vurus donmasi boyunca tasir, iptal bir sonraki
	# fizik karesinde gerceklesir.
	if info.data.reaction == HitData.Reaction.LAUNCH and launch_hit_frame < 0:
		launch_hit_frame = frames
		print("   >>> HAVALANDIRICI DEGDI (kare %d) - W basiliyor (ziplama iptali)" % frames)
		_tap(&"jump")


func _physics_process(_delta: float) -> void:
	frames += 1

	if frames == 2:
		player = battle.get_node("Fighters/Lyra")
		enemy = battle.get_node("Fighters/Grunt")
		enemy.get_node("InputSource").passive = true  # dusman karismasin
		_check_setup()
		phase = "whiff"
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

	_watch_corpse()

	if phase == "done" or frames > FRAME_LIMIT:
		if not _reported:
			_reported = true
			_report()
			get_tree().quit()


## Olumden sonraki HER karede ceseti denetler: durumdan cikmamali ve hicbir
## hitbox'i acilmamali.
func _watch_corpse() -> void:
	if death_frame < 0:
		return
	if enemy.fsm.current_name != &"Dead":
		stayed_dead = false
	for b in enemy.find_children("*", "Hitbox", true, false):
		if (b as Area2D).monitoring:
			corpse_hitbox_open = true


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
	# Lyra'nin rig parcalari artik GERCEK CIZIM: hicbiri kodla uretilen
	# gradyan doku olmamali. (BlobShadow rig'in parcasi degil, o haric.)
	var rig_sprite := 0
	var gradyan := 0
	for s: Sprite2D in player.get_node("Rig").find_children("*", "Sprite2D", true, false):
		rig_sprite += 1
		if s.texture is GradientTexture2D:
			gradyan += 1
	if rig_sprite != 15 or gradyan > 0:
		problems.append("Lyra rig dokulari: %d sprite, %d tanesi hala gradyan (15 sprite / 0 gradyan olmali)" % [
			rig_sprite, gradyan])
	# Grunt de artik gercek cizim (Lyra parcalarinin renk varyanti).
	var g_sprite := 0
	var g_gradyan := 0
	for s: Sprite2D in enemy.get_node("Rig").find_children("*", "Sprite2D", true, false):
		g_sprite += 1
		if s.texture is GradientTexture2D:
			g_gradyan += 1
	if g_sprite != 15 or g_gradyan > 0:
		problems.append("Grunt rig dokulari: %d sprite, %d tanesi hala gradyan (15 sprite / 0 gradyan olmali)" % [
			g_sprite, g_gradyan])

	# Nakavt sistemi iki karakterde de "Dead" node'u olmadan calismaz.
	for f: Fighter in [player, enemy]:
		if not f.fsm.has(&"Dead"):
			problems.append("StateMachine'de 'Dead' durumu yok: " + f.name)


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
		# BOSA SALLAMA (whiff) TESTI - asil senaryodan once.
		# Rakip 300 px uzakta, launcher kesinlikle isabet etmeyecek.
		# atk_launcher animasyonunda open_cancel_window izi YOK; can_cancel
		# yalniz VURUS ONAYIYLA acilir. Yani W'ye basmak hicbir sey yapmamali.
		"whiff":
			_whiff_t += 1
			if player.fsm.current_name == &"Attack":
				_whiff_saw_attack = true
			if _whiff_t == 1:
				_tap(&"attack_heavy")
			elif _whiff_t == 8:
				_tap(&"jump")  # saldirinin ortasinda W - iptal ETMEMELI
			elif _whiff_t > 8 and _whiff_saw_attack:
				if player.fsm.current_name == &"Airborne":
					problems.append("Bosa sallanan launcher ziplamayla IPTAL EDILDI - olmamali")
					phase = "approach"
				elif player.fsm.current_name in [&"Idle", &"Run"]:
					whiff_immune = true
					print("   >>> WHIFF TESTI: launcher bosa gitti, W iptal etmedi (dogru)")
					phase = "approach"
			if phase != "whiff":
				# Bayat ziplama tamponu yaklasma fazina karismasin.
				player.input.clear()
			elif _whiff_t > 120:
				problems.append("Bosa sallama testi zaman asimina ugradi")
				phase = "approach"

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
				phase = "jump_cancel"
			elif frames > 400:
				problems.append("Havalandirici rakibi Juggle durumuna sokamadi")
				phase = "done"

		# W zaten _on_hit icinde basildi. Burada sadece iptalin GERCEKLESMESINI
		# bekliyoruz: toparlanmayi beklemeden Airborne'a gecmeli.
		"jump_cancel":
			if player.fsm.current_name == &"Airborne":
				jump_cancel_frame = frames
				_box_watch = 12
				phase = "chase"
				kick_cooldown = 4
			elif player.fsm.current_name in [&"Idle", &"Run"]:
				# Saldiri animasyonu sonuna kadar oynadi - iptal olmadi.
				problems.append("Ziplama iptali gerceklesmedi: oyuncu saldiri bitene kadar yerde kaldi")
				phase = "chase"
				kick_cooldown = 4
			elif frames > 400:
				problems.append("Ziplama iptali beklenirken zaman asimi")
				phase = "done"

		"chase":
			# Iptalden hemen sonra hicbir hitbox acik kalmamis olmali.
			# (AttackState.exit() -> deactivate_all_hitboxes() bunu garanti eder.)
			if _box_watch > 0:
				_box_watch -= 1
				if player.fsm.current_name != &"Attack":
					for b in player.find_children("*", "Hitbox", true, false):
						if (b as Area2D).monitoring:
							hitbox_open_after_cancel = true

			kick_cooldown -= 1
			# Attack sirasinda da basiyoruz: tampon sayesinde hava tekmesi
			# kendine zincirlenebilsin (air_kick -> air_kick).
			if kick_cooldown <= 0 and _tap_left == 0:
				_tap(&"attack_kick")
				kick_cooldown = 8
			if enemy.is_on_floor() and enemy.fsm.current_name != &"Juggle":
				phase = "ko"

		# NAKAVT FAZI - juggle bittikten sonra yerden J / L / K ile dusmanin
		# canini sifira indir. Dusman passive, karsilik vermez.
		"ko":
			if enemy.is_dead():
				_begin_post_death()
			else:
				_ground_mash(dist)

		# OLUMDEN SONRA - 2 saldiri daha. Hicbiri isabet sinyali, can
		# degisimi, kombo degisimi veya ikinci bir olum sinyali URETMEMELI;
		# dusman Dead durumunda kalmali.
		"post_death":
			_post_death_tick(dist)

		"done":
			pass


## Yerden sirayla J -> L -> K basar. Dusman gercekten vurulabilir durumda
## degilse (yerde yatiyor, havada savruluyor, kalkis dokunulmazliginda)
## tusu bosa harcamaz.
func _ground_mash(dist: float) -> void:
	if dist > 85.0:
		_walk_toward()
		return
	_stop_walking()

	_ko_cooldown -= 1
	if _ko_cooldown > 0 or _tap_left > 0:
		return
	if not player.is_on_floor() or not player.fsm.current_name in [&"Idle", &"Run"]:
		return
	if enemy.fsm.current_name in [&"Knockdown", &"Juggle"] or enemy.invuln_timer > 0.0:
		return
	_tap(_ko_order[_ko_index])
	_ko_index = (_ko_index + 1) % _ko_order.size()
	_ko_cooldown = 4


## Olum anini fotograflar ve olum sonrasi fazini hazirlar.
func _begin_post_death() -> void:
	death_frame = frames
	health_at_death = enemy.health
	combo_at_death = enemy.combo_hits
	hits_at_death = total_hits
	died_count_at_death = died_signal_count

	# battle.gd._on_died() kazananin girdisini kapatmis olmali.
	winner_frozen = not player.input.is_physics_processing()
	print("   >>> DUSMAN OLDU (kare %d, can %.1f). Kazanan girdisi kapali mi: %s" % [
		frames, enemy.health, "EVET" if winner_frozen else "HAYIR"])

	# CESEDE VURMA SINAMASI icin girdiyi GECICI olarak geri aciyoruz. Aksi
	# halde oyuncu hic saldiramaz, "etkisiz mi" sorusu da bos yere EVET cikardi.
	player.input.set_physics_process(true)
	_stop_walking()
	phase = "post_death"


func _post_death_tick(dist: float) -> void:
	if post_death_attacks < 2:
		if dist > 80.0:
			_walk_toward()
			return
		_stop_walking()
		if _tap_left == 0 and player.fsm.current_name in [&"Idle", &"Run"]:
			post_death_attacks += 1
			print("   >>> OLUMDEN SONRAKI SALDIRI #%d (kare %d)" % [post_death_attacks, frames])
			_tap(&"attack_light")
		return

	if player.fsm.current_name == &"Attack":
		return  # son saldiri dogal olarak bitsin

	if not _probe_done:
		_probe_done = true
		# DOGRUDAN SINAMA: cesede vurmayi DENE. Ceset yatarken hurtbox'lari
		# dondugu icin gercek bir tekme geometrik olarak isabet etmeyebilir;
		# bu cagri "ceset vurulamaz" iddiasini kesin olarak olcer.
		# Dokunulmazlik sayaci sonucu gizlemesin diye sifirlaniyor: tek red
		# sebebi Dead durumu olmali.
		enemy.invuln_timer = 0.0
		var probe := HitInfo.make(player.moves[0].hit, player, player, player.facing)
		corpse_take_hit_rejected = not enemy.take_hit(probe)
		print("   >>> CESEDE DOGRUDAN VURUS DENEMESI: %s" % (
			"REDDEDILDI (dogru)" if corpse_take_hit_rejected else "KABUL EDILDI (HATA)"))
		return

	phase = "done"


func _walk_toward() -> void:
	if enemy.global_position.x > player.global_position.x:
		Input.action_release(&"move_left")
		Input.action_press(&"move_right")
	else:
		Input.action_release(&"move_right")
		Input.action_press(&"move_left")


func _stop_walking() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")


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

	var cancel_ok: bool = launch_hit_frame >= 0 and jump_cancel_frame >= 0
	if cancel_ok:
		var gap: int = jump_cancel_frame - launch_hit_frame
		print("Ziplama iptali calisti mi                          : EVET - isabet kare %d -> Airborne kare %d = %d kare (%.3f sn)" % [
			launch_hit_frame, jump_cancel_frame, gap, float(gap) / 60.0])
	else:
		print("Ziplama iptali calisti mi                          : HAYIR")

	print("Bosa sallanan launcher iptal edilemedi mi?        : %s" % ("EVET (dogru)" if whiff_immune else "HAYIR"))

	# --- NAKAVT ---
	var post_death_clean: bool = death_frame >= 0 \
		and post_death_attacks >= 2 \
		and total_hits == hits_at_death \
		and is_equal_approx(enemy.health, health_at_death) \
		and enemy.combo_hits == combo_at_death \
		and died_signal_count == died_count_at_death \
		and stayed_dead \
		and not corpse_hitbox_open \
		and corpse_take_hit_rejected

	print("Olum sinyali kac kez yayinlandi                    : %d" % died_signal_count)
	print("Olumden sonra dusmanin durumu                      : %s" % String(enemy.fsm.current_name))
	print("Olumden sonraki saldirilar etkisiz mi              : %s" % ("EVET" if post_death_clean else "HAYIR"))
	print("Olumden sonra yapilan saldiri sayisi               : %d" % post_death_attacks)
	print("Cesede dogrudan vurus denemesi reddedildi mi       : %s" % ("EVET" if corpse_take_hit_rejected else "HAYIR"))
	print("Kazananin girdisi donduruldu mu                    : %s" % ("EVET" if winner_frozen else "HAYIR"))
	print("Olum ani / bitis                                   : kare %d / %d" % [death_frame, frames])

	var olcut: bool = aerial_hits >= 3 and max_juggle_seen >= 4
	print("Basari olcutu (hava isabeti >=3 VE juggle >=4)      : %s  (hava %d, juggle %d)" % [
		"GECTI" if olcut else "KALDI", aerial_hits, max_juggle_seen])

	if aerial_hits < 1:
		problems.append("Lyra havadaki rakibe HAVADAYKEN hic vuramadi (ana mekanik calismiyor)")
	if max_juggle_seen < 2:
		problems.append("Juggle zinciri kurulamadi (puan 2'nin altinda kaldi)")
	if not reached_knockdown:
		problems.append("Juggle sonunda Knockdown'a gecilmedi")
	if enemy.health >= enemy.max_health:
		problems.append("Dusmana hic hasar verilmedi")
	if not cancel_ok:
		problems.append("Ziplama iptali calismadi (havalandirici isabetinden sonra Airborne'a gecilemedi)")
	if hitbox_open_after_cancel:
		problems.append("Ziplama iptalinden sonra bir hitbox ACIK kaldi")
	if not whiff_immune:
		problems.append("Bosa sallanan launcher'in iptal edilemedigi dogrulanamadi")
	if not olcut:
		problems.append("OLCUT SAGLANAMADI: havada isabet %d (>=3 gerekli), juggle puani %d (>=4 gerekli)" % [
			aerial_hits, max_juggle_seen])

	# --- NAKAVT hatalari ---
	if died_signal_count != 1:
		problems.append("Olum sinyali %d kez yayinlandi (tam 1 olmali)" % died_signal_count)
	if death_frame < 0:
		problems.append("Dusman hic olmedi - nakavt fazi tamamlanamadi (can %.1f)" % enemy.health)
	else:
		if not stayed_dead or enemy.fsm.current_name != &"Dead":
			problems.append("Dusman olumden sonra Dead durumunda kalmadi (su an: %s)" % String(enemy.fsm.current_name))
		if not is_equal_approx(enemy.health, health_at_death):
			problems.append("Olumden sonra can degisti: %.2f -> %.2f" % [health_at_death, enemy.health])
		if enemy.combo_hits != combo_at_death:
			problems.append("Olumden sonra kombo degisti: %d -> %d" % [combo_at_death, enemy.combo_hits])
		if total_hits != hits_at_death:
			problems.append("Olumden sonra yeni isabet sinyali geldi: %d -> %d" % [hits_at_death, total_hits])
		if corpse_hitbox_open:
			problems.append("Olen dovuscunun bir hitbox'i ACIK kaldi")
		if not corpse_take_hit_rejected:
			problems.append("Ceset hala vurulabiliyor: take_hit true dondu")
		if post_death_attacks < 2:
			problems.append("Olumden sonra 2 saldiri yapilamadi (%d)" % post_death_attacks)
		if not winner_frozen:
			problems.append("Kazananin girdisi dondurulmadi (battle.gd._on_died)")

	print("\n--------- HATALAR ---------")
	if problems.is_empty():
		print("HIC HATA YOK. Sistem calisiyor.")
	else:
		for p in problems:
			print("  HATA: " + p)
	print("===========================================\n")
