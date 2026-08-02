# =============================================================================
# Fighter  —  HER karakterin ortak omurgasi
# NEREYE BAGLI: Bir dovuscu sahnesinin kok CharacterBody2D node'una.
# Lyra ve butun dusmanlar bunu genisletir, boylece TEK bir dovus sistemini
# paylasirlar.
# =============================================================================
class_name Fighter
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died
signal combo_changed(hits: int)

@export_group("Kimlik")
## Ayni takimdakiler birbirine vuramaz. Oyuncu = 0, dusmanlar = 1.
@export var team: int = 0
@export var display_name: String = "Fighter"

@export_group("Hareket")
@export var walk_speed: float = 210.0
@export var run_speed: float = 380.0
@export var ground_accel: float = 2600.0
@export var ground_friction: float = 2800.0
## Ziplama gucu. Havalandiricinin firlattigi yuksekligi YAKALAYABILMELI,
## yoksa juggle'i havada kovalayamazsin. (Su an: zipla ~177px, firlat ~196px)
@export var jump_velocity: float = -820.0
@export var gravity: float = 1900.0
@export var max_fall_speed: float = 1500.0
@export_range(0.0, 1.0) var air_control: float = 0.35

@export_group("Dovus")
@export var max_health: float = 100.0
## data/rules/default_juggle.tres dosyasini buraya surukle.
@export var juggle_rules: JuggleRules
## Bu karakterin tum hamleleri. data/moves/ icinden .tres surukle.
@export var moves: Array[MoveDef] = []

@export_group("Gorunum")
@export var flash_color: Color = Color(1.0, 0.45, 0.45)
@export var shadow_fade_height: float = 420.0

@onready var rig: Node2D = $Rig
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var fsm: StateMachine = $StateMachine
@onready var input: InputSource = $InputSource
@onready var blob_shadow: Sprite2D = $BlobShadow

# --- calisma anindaki degerler (durumlar bunlari okur) ---
var health: float = 0.0
var facing: int = 1
var lock_facing: bool = false
var opponent: Fighter
var juggle_hits: int = 0  ## yerden ayrildigindan beri harcanan juggle puani
var combo_hits: int = 0  ## toparlanmadan yenen vurus sayisi (hasar olceklemesi)
var invuln_timer: float = 0.0
var can_cancel: bool = false  ## iptal penceresinde VEYA vurus degdikten sonra
var current_move: MoveDef
var air_actions: int = 1
var anim_name: StringName = &""
var ground_y: float = 0.0

var _hitboxes: Array[Hitbox] = []
var _move_by_id: Dictionary = {}
var _last_hit_id: int = 0
var _flash_t: float = 0.0


func _ready() -> void:
	health = max_health
	if juggle_rules == null:
		juggle_rules = JuggleRules.new()  # hicbir sey cokmesin diye makul varsayilan

	# Kare hassasiyetli dovus: animasyon geri cagrilari FIZIK adiminda olmali.
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	RigAnimator.build(anim)

	for node in find_children("*", "Hitbox", true, false):
		_hitboxes.append(node as Hitbox)
	for m in moves:
		if m != null:
			_move_by_id[m.id] = m

	ground_y = global_position.y
	# Durum makinesi BURADA baslatilir, kendi _ready()'sinde degil: Godot'ta
	# cocugun _ready()'si ebeveynden once calisir, o an yukaridaki @onready
	# degiskenler henuz olusmamis olurdu.
	fsm.setup(self)
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	invuln_timer = maxf(0.0, invuln_timer - delta)
	_update_facing()
	fsm.physics_tick(delta)  # aktif durum `velocity` degerini yazar
	move_and_slide()  # tum karakter icin TEK hareket cagrisi
	_separate_from_opponent(delta)
	if is_on_floor():
		ground_y = global_position.y
	_update_shadow()
	_update_flash(delta)


# -----------------------------------------------------------------------------
# Durumlarin kullandigi hareket yardimcilari
# -----------------------------------------------------------------------------
func apply_gravity(delta: float, scale: float = 1.0) -> void:
	velocity.y = minf(velocity.y + gravity * scale * delta, max_fall_speed)


func set_facing(value: int) -> void:
	if value == facing:
		return
	facing = value
	rig.scale.x = float(facing)  # gorsel + hitbox + hurtbox hepsi birlikte doner


func _update_facing() -> void:
	if lock_facing or opponent == null or fsm.current == null:
		return
	if not fsm.current.can_turn():
		return
	set_facing(1 if opponent.global_position.x >= global_position.x else -1)


func land() -> void:
	air_actions = 1


## Yumusak itme kutusu: dovuscular ic ice gecmesin diye birbirlerini nazikce
## iterler. Iki taraf da bunu calistirdigi icin ayrilma simetriktir.
func _separate_from_opponent(delta: float) -> void:
	if opponent == null:
		return
	# Olen taraf itilmez ve itmez: kazanan cesedi sahnede kaydiramaz.
	if is_dead() or opponent.is_dead():
		return
	const MIN_GAP := 46.0
	var dx: float = global_position.x - opponent.global_position.x
	if absf(global_position.y - opponent.global_position.y) > 120.0:
		return
	if absf(dx) >= MIN_GAP:
		return
	var dir: float = signf(dx) if absf(dx) > 0.5 else 1.0
	global_position.x += dir * (MIN_GAP - absf(dx)) * 0.5 * minf(1.0, delta * 14.0)


# -----------------------------------------------------------------------------
# Animasyon
# -----------------------------------------------------------------------------
func play(name: StringName, restart: bool = false) -> void:
	if not anim.has_animation(name):
		return
	if not restart and anim_name == name:
		return
	anim_name = name
	anim.play(name)


# -----------------------------------------------------------------------------
# Saldirilar
# -----------------------------------------------------------------------------
## Idle/Run/Airborne tarafindan cagrilir. Saldiri basladiysa true doner.
func try_start_attack(in_air: bool = false) -> bool:
	for m in moves:
		if m == null or not m.is_opener or m.airborne != in_air:
			continue
		if input.consume(m.input_action):
			fsm.change_to(&"Attack", {"move": m})
			return true
	return false


## AttackState iptal penceresinde devam hamlesi aramak icin cagirir.
func pick_chain_move(from: MoveDef) -> MoveDef:
	if from == null:
		return null
	for id in from.chain_to:
		var m: MoveDef = _move_by_id.get(id)
		if m != null and input.peek(m.input_action):
			input.consume(m.input_action)
			return m
	return null


# --- asagidaki dortu AnimationPlayer "Call Method" izlerinden cagrilir ---
func hitbox_on(box_name: StringName) -> void:
	var b := _find_hitbox(box_name)
	if b == null:
		return
	# Hasar karti O ANKI HAMLEDEN gelir. Boylece tek bir "tekme kutusu"
	# hafif tekmede az, havalandiricida cok hasar verebilir.
	if current_move != null and current_move.hit != null:
		b.data = current_move.hit
	b.activate()


func hitbox_off(box_name: StringName) -> void:
	var b := _find_hitbox(box_name)
	if b != null:
		b.deactivate()


func open_cancel_window() -> void:
	can_cancel = true


func close_cancel_window() -> void:
	can_cancel = false


func deactivate_all_hitboxes() -> void:
	for b in _hitboxes:
		b.deactivate()
	can_cancel = false


func _find_hitbox(box_name: StringName) -> Hitbox:
	for b in _hitboxes:
		if b.name == box_name:
			return b
	return null


## Kendi Hitbox'imiz rakibe degdiginde cagirir.
func on_hit_landed(victim: Fighter, info: HitInfo) -> void:
	can_cancel = true  # vurus onayi: degen her darbe zincir penceresini acar
	CombatEvents.hit_confirmed.emit(self, victim, info)
	CombatEvents.camera_shake_requested.emit(info.data.camera_shake)


# -----------------------------------------------------------------------------
# Hasar alma - TUM gelen vuruslarin TEK giris noktasi
# -----------------------------------------------------------------------------
func take_hit(info: HitInfo) -> bool:
	if info.attacker == self:
		return false
	if info.attacker is Fighter and (info.attacker as Fighter).team == team:
		return false
	if invuln_timer > 0.0:
		return false
	if info.id == _last_hit_id:
		return false
	_last_hit_id = info.id

	# Once aktif durum karar verir. Juggle'in bastan baslamadan tekrar
	# kaldirmasi ve Knockdown'in kalkis dokunulmazligi bu sayede calisir.
	var response: int = fsm.current.on_hit_received(info)
	if response == FighterState.HitResponse.IGNORE:
		return false

	# Blok (sadece notr durumlardan - juggle sirasinda blok yapilamaz).
	if response == FighterState.HitResponse.PASS and _is_blocking(info):
		_damage(info.data.chip_damage)
		HitStop.freeze(info.data.hitstop * 0.6)
		# Siyrik hasari da oldurebilir; o zaman Hit'e degil Dead'e gidilir.
		fsm.change_to(&"Dead" if is_dead() else &"Hit", {"hit": info, "blocked": true})
		return true

	# Hasar olceklemesi: kombonun 8. vurusu 1.'si kadar aci vermemeli.
	var scaled: float = info.data.damage * juggle_rules.damage_scale(combo_hits)
	_damage(scaled)
	combo_hits += 1
	combo_changed.emit(combo_hits)
	CombatEvents.combo_updated.emit(self, combo_hits)

	HitStop.freeze(info.data.hitstop)  # olduren vurusun donmasi da normal
	flash()

	# SIRALAMA TUZAGI: olum kontrolu tepkiden ONCE gelmeli. _enter_reaction
	# calisirsa durumu Hit/Juggle'a cevirir ve olumu ezerdi. Olum HANGI
	# durumda gelirse gelsin (Hit, Juggle, Attack...) Dead'e gidilir - bu
	# yuzden asagidaki dal response'a bakmadan once is_dead()'e bakar.
	if is_dead():
		fsm.change_to(&"Dead")
	elif response == FighterState.HitResponse.PASS:
		_enter_reaction(info)
	return true


func _enter_reaction(info: HitInfo) -> void:
	match info.data.reaction:
		HitData.Reaction.LAUNCH:
			fsm.change_to(&"Juggle", {"hit": info, "fresh": true})
		HitData.Reaction.KNOCKDOWN, HitData.Reaction.SWEEP:
			fsm.change_to(&"Knockdown", {"hit": info})
		_:
			# ANA JUGGLE KURALI: kurban yerden ayrikken degen HER vurus, hamle
			# normalde ne yaparsa yapsin, juggle'a donusur.
			if not is_on_floor():
				fsm.change_to(&"Juggle", {"hit": info, "fresh": true})
			else:
				fsm.change_to(&"Hit", {"hit": info})


func _is_blocking(info: HitInfo) -> bool:
	if not is_on_floor() or info.data.unblockable:
		return false
	if not input.block_held:
		return false
	# Saldiriya donuk muyuz? Sadece geriye dogru blok yapilir.
	var attack_from_right: bool = info.attacker.global_position.x > global_position.x
	return (facing > 0) == attack_from_right


## Can 0'in altina inmez ve olum TEK SEFERLIKTIR: olduktan sonra gelen hicbir
## vurus ne hasar yazar ne de olum sinyalini tekrar yayar.
func _damage(amount: float) -> void:
	if is_dead():
		return
	if amount <= 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		# Buraya yalnizca can >0 iken girilebildigi icin (yukaridaki erken
		# cikis), bu iki sinyal olum basina TAM BIR KEZ yayilir.
		died.emit()
		CombatEvents.fighter_died.emit(self)


func is_dead() -> bool:
	return health <= 0.0


func set_invulnerable(duration: float) -> void:
	invuln_timer = maxf(invuln_timer, duration)


func reset_juggle() -> void:
	juggle_hits = 0


func end_combo() -> void:
	combo_hits = 0
	combo_changed.emit(0)
	CombatEvents.combo_updated.emit(self, 0)


# -----------------------------------------------------------------------------
# Gorsel geri bildirim
# -----------------------------------------------------------------------------
func flash() -> void:
	_flash_t = 0.12


func _update_flash(delta: float) -> void:
	if _flash_t <= 0.0:
		return
	_flash_t = maxf(0.0, _flash_t - delta)
	rig.modulate = Color.WHITE.lerp(flash_color, _flash_t / 0.12)


## Sahte temas golgesi: yukseklikle kuculur ve solar. Maliyeti bir sprite.
func _update_shadow() -> void:
	if blob_shadow == null:
		return
	var height: float = clampf((ground_y - global_position.y) / shadow_fade_height, 0.0, 1.0)
	blob_shadow.global_position = Vector2(global_position.x, ground_y)
	blob_shadow.global_rotation = 0.0
	blob_shadow.scale = Vector2.ONE * lerpf(1.0, 0.42, height)
	blob_shadow.modulate.a = lerpf(0.5, 0.08, height)
