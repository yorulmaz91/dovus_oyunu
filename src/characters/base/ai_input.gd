# =============================================================================
# AIInput  —  Yapay zeka girdisi
# NEREYE BAGLI: DUSMAN dovuscusunun "InputSource" adli cocuk node'una.
#
# Oyuncunun scripti hangi alanlari dolduruyorsa bu da aynilarini doldurur.
# Bu yuzden her durum ve her juggle kurali dusmanlar icin de birebir calisir.
# Ayri bir "AI durum makinesi" YOK.
# =============================================================================
class_name AIInput
extends InputSource

var _rng := RandomNumberGenerator.new()

@export_range(0.0, 1.0, 0.05) var difficulty: float = 0.5
@export var preferred_range: float = 130.0
@export var attack_range: float = 100.0
## Kendi juggle'ini surdurme istegi. 0 = hic, 1 = her zaman.
@export_range(0.0, 1.0, 0.05) var juggle_greed: float = 0.85
## Acik ise dusman hic saldirmaz - sistemi rahat rahat denemen icin.
@export var passive: bool = false
## 0 = her calistirmada rastgele (oyunda boyle kalmali). Sifirdan farkli bir
## deger verilirse YZ tekrar uretilebilir olur - testler bunu koddan verir.
@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		if value != 0 and _rng != null:
			_rng.seed = value

var fighter: Fighter

var _think_timer: float = 0.0
var _held_move: float = 0.0
## Blok GERI SAYIMI. Blok bir SURE'dir, tek kare degil: savunma karari
## ~0.25 sn'de bir verilir, ama block_held her karede yazilir. Eskiden
## kosulsuz "block_held = false" satiri vardi ve dusman pratikte hic blok
## yapamiyordu - karar verdigi kare disinda blok hep kapaliydi.
var _block_hold: float = 0.0


func _ready() -> void:
	fighter = get_parent() as Fighter
	if rng_seed == 0:
		_rng.randomize()


func _poll(delta: float) -> void:
	# Bu iki satir HER karede calisir; asagidaki karar dali ise sadece
	# dusunme karelerinde.
	_block_hold = maxf(0.0, _block_hold - delta)
	block_held = _block_hold > 0.0
	move_x = _held_move

	if fighter == null or fighter.opponent == null:
		return

	# Vurulurken (ve oldukten sonra) hareket edemez - oyuncuyla ayni kural.
	if fighter.fsm.current_name in [&"Hit", &"Juggle", &"Knockdown", &"Dead"]:
		_block_hold = 0.0
		block_held = false
		_held_move = 0.0
		move_x = 0.0
		return

	_think_timer -= delta
	if _think_timer > 0.0:
		return
	# Tepki gecikmesi: dusuk zorluk yavas dusunur. Zorluk ayari ISTE BUDUR.
	_think_timer = lerpf(0.34, 0.07, difficulty)

	var foe: Fighter = fighter.opponent
	var dx: float = foe.global_position.x - fighter.global_position.x
	var dist: float = absf(dx)
	var toward: float = signf(dx)

	if passive:
		_held_move = 0.0
		move_x = 0.0
		return

	# --- 1. Juggle surdurme: rakip havada ve caresiz. ---
	if foe.fsm.current_name == &"Juggle":
		_chase_juggle(dist, toward)
		move_x = _held_move
		return

	# --- 2. Savunma: rakip saldiriyor ve yakiniz. ---
	if foe.fsm.current_name == &"Attack" and dist < attack_range * 1.3:
		if _rng.randf() < difficulty * 0.6:
			# Karari bir SURE tut, yoksa blok bir sonraki dusunmeye kadar
			# kapali kalirdi.
			_block_hold = _rng.randf_range(0.25, 0.45)
			block_held = true
			_held_move = -toward  # blok ederken geri cekil
			move_x = _held_move
			return

	# --- 3. Mesafe ve hucum. ---
	if dist > preferred_range:
		_held_move = toward
	elif dist < preferred_range * 0.55:
		_held_move = -toward
	else:
		_held_move = 0.0
		if _rng.randf() < 0.25 + difficulty * 0.45:
			# Usta yapay zeka kendi juggle'ini baslatmak icin havalandiriciyla acar.
			if _rng.randf() < difficulty * 0.5:
				press(&"attack_heavy")
			else:
				press(&"attack_light")

	move_x = _held_move


## Kendi juggle'ini kovalama. ZIPLAMA SADECE BURADA VAR - notr ziplama yok,
## boylece dusmanin davranisi ongorulebilir kalir.
func _chase_juggle(dist: float, toward: float) -> void:
	if fighter.is_on_floor():
		if dist > attack_range:
			_held_move = toward  # once mesafeyi kapat
			return
		_held_move = 0.0
		if _rng.randf() < juggle_greed:
			# Ikisi de girdi tamponuna girer (0.15 sn) ve ikisi de tasinir.
			# Havalandiriciyi kendisi vurduysa can_cancel acik oldugu icin
			# AttackState'in jump_cancel yolu devreye girer; Idle'daysa
			# normal ziplama olur. Ikisi de istenen davranis.
			press(&"jump")
			press(&"attack_kick")
		return

	# Havada: rakibe dogru suzul ve tekmele. Yatay yaklasma AirborneState'in
	# hava kontrolunden gelir (air_control zaten var). air_kick kendine
	# zincirlendigi icin pes pese tekme olur.
	_held_move = toward if dist > 20.0 else 0.0
	if _rng.randf() < juggle_greed:
		press(&"attack_kick")
