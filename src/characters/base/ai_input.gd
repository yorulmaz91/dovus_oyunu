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

@export_range(0.0, 1.0, 0.05) var difficulty: float = 0.5
@export var preferred_range: float = 130.0
@export var attack_range: float = 100.0
## Kendi juggle'ini surdurme istegi. 0 = hic, 1 = her zaman.
@export_range(0.0, 1.0, 0.05) var juggle_greed: float = 0.85
## Acik ise dusman hic saldirmaz - sistemi rahat rahat denemen icin.
@export var passive: bool = false

var fighter: Fighter

var _think_timer: float = 0.0
var _held_move: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fighter = get_parent() as Fighter
	_rng.randomize()


func _poll(delta: float) -> void:
	move_x = _held_move
	block_held = false
	if fighter == null or fighter.opponent == null:
		return

	# Vurulurken (ve oldukten sonra) hareket edemez - oyuncuyla ayni kural.
	if fighter.fsm.current_name in [&"Hit", &"Juggle", &"Knockdown", &"Dead"]:
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
		if dist > attack_range * 0.85:
			_held_move = toward
		else:
			_held_move = 0.0
			if _rng.randf() < juggle_greed:
				press(&"attack_kick")  # hizli tekmeler onu yukarida tutar
		move_x = _held_move
		return

	# --- 2. Savunma: rakip saldiriyor ve yakiniz. ---
	if foe.fsm.current_name == &"Attack" and dist < attack_range * 1.3:
		if _rng.randf() < difficulty * 0.6:
			block_held = true
			_held_move = -toward
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
