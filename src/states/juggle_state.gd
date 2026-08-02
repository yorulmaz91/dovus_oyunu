# =============================================================================
# NEREYE BAGLI: StateMachine altindaki "Juggle" adli Node.
#
# BU OYUNUN KALBI.
#
# Kurban tum juggle boyunca BU TEK DURUMDA kalir. Her ek vurus durumu bastan
# baslatmaz, sadece _apply_launch()'i TEKRAR cagirir. Lyra'nin hizli
# tekmelerinin rakibi havada asili tutabilmesinin sebebi budur.
#
# Birbiriyle savasan iki ayar:
#   KALDIRMA — her vurus oncekinden az kaldirir   (lift_decay)
#   AGIRLIK  — her vurusta yer cekimi artar       (gravity_ramp)
# Agirlik kaldirmayi yendiginde rakip duser. Kombo kendiliginden biter.
# =============================================================================
class_name JuggleState
extends FighterState

## Kucuk bir tolerans: havalandirma karesinde is_on_floor() hala true oldugu
## icin aninda Knockdown'a dusmeyi engeller.
const GROUND_LOCK: float = 0.06

var _stun: float = 0.0
var _ground_lock: float = 0.0
var _gravity_scale: float = 1.0


func can_turn() -> bool:
	return false


func enter(msg: Dictionary = {}) -> void:
	var info: HitInfo = msg.get("hit")
	if info == null:
		fsm.change_to(&"Airborne")
		return
	fighter.deactivate_all_hitboxes()
	if msg.get("fresh", true):
		fighter.juggle_hits = 0  # yeni havalandirma juggle butcesini sifirlar
	_apply_launch(info)


## Ek vuruslar buraya gelir - durumdan CIKMADAN.
func on_hit_received(info: HitInfo) -> int:
	var rules: JuggleRules = fighter.juggle_rules
	if info.data.can_juggle and fighter.juggle_hits < rules.max_juggle_hits:
		_apply_launch(info)  # havada TUT
	else:
		# Juggle butcesi bitti: vurus hala aci verir ama artik asagi inerler.
		_stun = maxf(_stun, rules.stun_for(rules.max_juggle_hits))
		fighter.velocity.x = float(info.dir) * info.data.knockback.x * 0.4
		_gravity_scale = rules.gravity_scale_for(rules.max_juggle_hits) * 1.4
	return HitResponse.HANDLED


func _apply_launch(info: HitInfo) -> void:
	var rules: JuggleRules = fighter.juggle_rules
	var hits: int = fighter.juggle_hits

	# Azalan kaldirma - 1. vurus %100, 2. vurus %72, 3. vurus %52...
	var scale: float = rules.lift_scale(hits)
	fighter.velocity.y = -info.data.launch_power * scale
	fighter.velocity.x = float(info.dir) * info.data.knockback.x * scale

	# Artan agirlik - ters yondeki basinc.
	_gravity_scale = rules.gravity_scale_for(hits)
	_stun = rules.stun_for(hits)
	_ground_lock = GROUND_LOCK

	fighter.juggle_hits += maxi(info.data.juggle_cost, 1)
	fighter.play(&"juggle", true)


func update(delta: float) -> void:
	var rules: JuggleRules = fighter.juggle_rules
	_ground_lock = maxf(0.0, _ground_lock - delta)
	_stun = maxf(0.0, _stun - delta)

	# Cikarken suzul, inerken hizli dus. Bu "tepe noktasinda asili kalma"
	# bir sonraki tekmeyi yetistirmen icin gereken pencereyi acar.
	var g: float = fighter.gravity * _gravity_scale
	if fighter.velocity.y < 0.0:
		g *= rules.rise_gravity_scale
	else:
		g *= rules.fall_gravity_scale
	fighter.velocity.y = minf(fighter.velocity.y + g * delta, fighter.max_fall_speed)
	fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, rules.air_drag * delta)

	if fighter.velocity.y > 0.0:
		fighter.play(&"juggle_fall")

	# Istege bagli kacis: hava sersemlemesi bitince BLOK'a basip toparlanma.
	if rules.allow_air_tech and _stun <= 0.0 and fighter.input.consume(&"block"):
		fighter.reset_juggle()
		fighter.set_invulnerable(0.25)
		fsm.change_to(&"Airborne")
		return

	if _ground_lock <= 0.0 and fighter.is_on_floor() and fighter.velocity.y >= 0.0:
		fsm.change_to(&"Knockdown")
