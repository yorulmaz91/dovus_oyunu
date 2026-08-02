# =============================================================================
# NEREYE BAGLI: StateMachine altindaki "Dead" adli Node.
#
# CIKISI OLMAYAN DURUM. Bir dovuscunun cani 0'a dustugunde buraya gelir ve
# BIR DAHA CIKMAZ. Tek cikis yolu R ile sahnenin yeniden yuklenmesidir.
#
# Ne yapar:
#   - butun hitbox'lari kapatir (ceset vuramaz)
#   - girdi tamponunu bosaltir (bayat tuslar bir sey baslatamaz)
#   - komboyu ve juggle butcesini kapatir
#   - dovuscuyu yere serer
#
# Havada olduyse once duser ("juggle_fall"), yere degince carpar ("knockdown"),
# sonra sonsuza kadar yatar ("downed"). Yerde olduyse dogrudan carpma ile
# baslar. Dusme icin YENI bir yer cekimi formulu YOK - Knockdown'in kullandigi
# fighter.apply_gravity() ve ayni yer surtunmesi kullanilir.
# =============================================================================
class_name DeadState
extends FighterState

var _landed: bool = false


func can_turn() -> bool:
	return false


func enter(_msg: Dictionary = {}) -> void:
	fighter.deactivate_all_hitboxes()
	fighter.input.clear()
	fighter.end_combo()
	fighter.reset_juggle()
	_landed = false

	if _on_ground():
		_hit_the_ground()
	else:
		fighter.play(&"juggle_fall", true)


## CESET VURULAMAZ. IGNORE donunce take_hit hasar uygulamadan, hicbir sinyal
## yaymadan geri doner - yani olumden sonraki vuruslar tamamen etkisizdir.
func on_hit_received(_info: HitInfo) -> int:
	return HitResponse.IGNORE


func update(delta: float) -> void:
	# Knockdown ile BIREBIR ayni dusus: ayni yer cekimi, ayni surtunme.
	fighter.apply_gravity(delta)
	fighter.velocity.x = move_toward(fighter.velocity.x, 0.0, fighter.ground_friction * 2.0 * delta)

	if not _landed and _on_ground():
		_hit_the_ground()


## Juggle'daki GROUND_LOCK ile ayni tuzagi kapatir: havalandirma karesinde
## is_on_floor() hala true'dur, o yuzden yukari giderken "yere degdi" sayilmaz.
func _on_ground() -> bool:
	return fighter.is_on_floor() and fighter.velocity.y >= 0.0


func _hit_the_ground() -> void:
	_landed = true
	fighter.play(&"knockdown", true)
	SesCalar.cal_yere_dusme()  # Knockdown ile AYNI ses - ayni olay cunku
	# "knockdown" dongusuz; bitince "downed" dongusune gecilir ve orada kalinir.
	if not fighter.anim.animation_finished.is_connected(_on_impact_finished):
		fighter.anim.animation_finished.connect(_on_impact_finished, CONNECT_ONE_SHOT)


func _on_impact_finished(_finished_name: StringName) -> void:
	fighter.play(&"downed", true)
