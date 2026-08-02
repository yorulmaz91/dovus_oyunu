# =============================================================================
# RigAnimator  —  Animasyonlari KODLA uretir
# NEREYE BAGLI: Hicbir node'a. Fighter._ready() icinden cagrilir.
#
# NEDEN BOYLE: 18 animasyonu elle Godot'un animasyon editorunde yapmak
# gunlerini alirdi. Burasi hepsini acilista uretir, boylece oyun ILK
# CALISTIRMADA calisir. Iskelet kemiklerinin acilarini derece cinsinden
# ayarliyoruz - istersen sadece asagidaki sayilari degistir.
#
# ONEMLI: Sadece AnimationPlayer'da HENUZ OLMAYAN animasyonlar uretilir.
# Ileride editorde kendi "idle" animasyonunu yaparsan seninki kazanir.
#
# ACI KURALI: Bir kemigin acisi 0 iken uzuv DUZ ASAGI bakar.
#   -90  = tam ileri (saga)     -150 = ileri ve yukari
#   +30  = geriye dogru asagi     0  = asagi
# =============================================================================
class_name RigAnimator
extends RefCounted

const RIG := "Rig"
const HIPS := "Rig/Skeleton2D/Hips"
const TORSO := HIPS + "/Torso"
const HEAD := TORSO + "/Head"
const AFU := TORSO + "/ArmF_Upper"
const AFL := AFU + "/ArmF_Lower"
const ABU := TORSO + "/ArmB_Upper"
const ABL := ABU + "/ArmB_Lower"
const LFU := HIPS + "/LegF_Upper"
const LFL := LFU + "/LegF_Lower"
const LBU := HIPS + "/LegB_Upper"
const LBL := LBU + "/LegB_Lower"

# --- Notr gard durusu (butun animasyonlarin baslangic noktasi) ---
const B := {
	HIPS: 0.0,
	TORSO: -4.0,
	HEAD: 2.0,
	AFU: -50.0,
	AFL: -70.0,
	ABU: -30.0,
	ABL: -85.0,
	LFU: -8.0,
	LFL: 10.0,
	LBU: 12.0,
	LBL: -8.0,
}


static func build(player: AnimationPlayer) -> void:
	var lib: AnimationLibrary
	if player.has_animation_library(&""):
		lib = player.get_animation_library(&"")
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library(&"", lib)

	for entry in _all():
		var anim_name: StringName = entry[0]
		if lib.has_animation(anim_name):
			continue  # kullanici kendi animasyonunu yapmis - ona dokunma
		var a: Animation = entry[1]
		a.resource_name = String(anim_name)
		lib.add_animation(anim_name, a)


# =============================================================================
# Animasyon listesi
# =============================================================================
static func _all() -> Array:
	return [
		[&"RESET", _make(0.1, false, {})],

		# --- Bekleme: nefes alip verme ---
		[&"idle", _make(2.0, true, {
			TORSO: [[0.0, -4.0], [1.0, -6.5], [2.0, -4.0]],
			HEAD: [[0.0, 2.0], [1.0, 4.0], [2.0, 2.0]],
			AFU: [[0.0, -50.0], [1.0, -46.0], [2.0, -50.0]],
			AFL: [[0.0, -70.0], [1.0, -74.0], [2.0, -70.0]],
			ABU: [[0.0, -30.0], [1.0, -27.0], [2.0, -30.0]],
		}, {RIG + ":position": [[0.0, Vector2.ZERO], [1.0, Vector2(0, -2)], [2.0, Vector2.ZERO]]})],

		# --- Ileri kosu ---
		[&"run", _make(0.5, true, {
			TORSO: [[0.0, -12.0]],
			LFU: [[0.0, -40.0], [0.25, 30.0], [0.5, -40.0]],
			LFL: [[0.0, 38.0], [0.25, 6.0], [0.5, 38.0]],
			LBU: [[0.0, 30.0], [0.25, -40.0], [0.5, 30.0]],
			LBL: [[0.0, 6.0], [0.25, 38.0], [0.5, 6.0]],
			AFU: [[0.0, -18.0], [0.25, -72.0], [0.5, -18.0]],
			AFL: [[0.0, -80.0], [0.25, -55.0], [0.5, -80.0]],
			ABU: [[0.0, -62.0], [0.25, -14.0], [0.5, -62.0]],
			ABL: [[0.0, -60.0], [0.25, -90.0], [0.5, -60.0]],
		}, {RIG + ":position": [[0.0, Vector2.ZERO], [0.125, Vector2(0, -6)], [0.25, Vector2.ZERO], [0.375, Vector2(0, -6)], [0.5, Vector2.ZERO]]})],

		# --- Geri yuruyus ---
		[&"walk_back", _make(0.7, true, {
			TORSO: [[0.0, 2.0]],
			LFU: [[0.0, 22.0], [0.35, -26.0], [0.7, 22.0]],
			LFL: [[0.0, 4.0], [0.35, 24.0], [0.7, 4.0]],
			LBU: [[0.0, -26.0], [0.35, 22.0], [0.7, -26.0]],
			LBL: [[0.0, 24.0], [0.35, 4.0], [0.7, 24.0]],
		}, {RIG + ":position": [[0.0, Vector2.ZERO], [0.175, Vector2(0, -3)], [0.35, Vector2.ZERO], [0.525, Vector2(0, -3)], [0.7, Vector2.ZERO]]})],

		# --- Zipla / dus ---
		[&"jump", _make(0.4, false, {
			TORSO: [[0.0, -8.0], [0.4, -4.0]],
			LFU: [[0.0, -55.0], [0.4, -38.0]],
			LFL: [[0.0, 70.0], [0.4, 50.0]],
			LBU: [[0.0, -20.0], [0.4, 10.0]],
			LBL: [[0.0, 45.0], [0.4, 20.0]],
			AFU: [[0.0, -95.0], [0.4, -70.0]],
			ABU: [[0.0, -80.0], [0.4, -60.0]],
		})],
		[&"fall", _make(0.6, true, {
			TORSO: [[0.0, 4.0], [0.3, 7.0], [0.6, 4.0]],
			LFU: [[0.0, -30.0], [0.3, -22.0], [0.6, -30.0]],
			LFL: [[0.0, 25.0], [0.3, 34.0], [0.6, 25.0]],
			LBU: [[0.0, 18.0], [0.3, 26.0], [0.6, 18.0]],
			AFU: [[0.0, -78.0], [0.3, -88.0], [0.6, -78.0]],
			ABU: [[0.0, -66.0], [0.3, -76.0], [0.6, -66.0]],
		})],

		# --- Darbe tepkileri ---
		[&"hit_light", _make(0.28, false, {
			TORSO: [[0.0, 14.0], [0.28, -4.0]],
			HEAD: [[0.0, 26.0], [0.28, 2.0]],
			AFU: [[0.0, -18.0], [0.28, -50.0]],
			AFL: [[0.0, -40.0], [0.28, -70.0]],
			ABU: [[0.0, -6.0], [0.28, -30.0]],
			LFU: [[0.0, 14.0], [0.28, -8.0]],
		})],
		[&"hit_heavy", _make(0.42, false, {
			TORSO: [[0.0, 30.0], [0.15, 26.0], [0.42, -4.0]],
			HEAD: [[0.0, 44.0], [0.15, 38.0], [0.42, 2.0]],
			AFU: [[0.0, 24.0], [0.42, -50.0]],
			AFL: [[0.0, -12.0], [0.42, -70.0]],
			ABU: [[0.0, 34.0], [0.42, -30.0]],
			ABL: [[0.0, -20.0], [0.42, -85.0]],
			LFU: [[0.0, 28.0], [0.42, -8.0]],
			LBU: [[0.0, -14.0], [0.42, 12.0]],
		}, {RIG + ":rotation": [[0.0, 9.0], [0.42, 0.0]]})],
		[&"block_hit", _make(0.22, false, {
			TORSO: [[0.0, 6.0], [0.22, -4.0]],
			AFU: [[0.0, -62.0], [0.22, -50.0]],
			AFL: [[0.0, -82.0], [0.22, -70.0]],
			ABU: [[0.0, -44.0], [0.22, -30.0]],
			ABL: [[0.0, -95.0], [0.22, -85.0]],
		})],

		# --- JUGGLE: havada caresiz savrulma ---
		[&"juggle", _make(0.6, true, {
			TORSO: [[0.0, 22.0], [0.3, 30.0], [0.6, 22.0]],
			HEAD: [[0.0, 30.0], [0.3, 22.0], [0.6, 30.0]],
			AFU: [[0.0, 30.0], [0.3, 55.0], [0.6, 30.0]],
			AFL: [[0.0, -25.0], [0.3, -8.0], [0.6, -25.0]],
			ABU: [[0.0, 48.0], [0.3, 24.0], [0.6, 48.0]],
			ABL: [[0.0, -14.0], [0.3, -30.0], [0.6, -14.0]],
			LFU: [[0.0, 26.0], [0.3, 42.0], [0.6, 26.0]],
			LFL: [[0.0, 30.0], [0.3, 12.0], [0.6, 30.0]],
			LBU: [[0.0, 44.0], [0.3, 20.0], [0.6, 44.0]],
			LBL: [[0.0, 10.0], [0.3, 34.0], [0.6, 10.0]],
		}, {RIG + ":rotation": [[0.0, 16.0], [0.3, 26.0], [0.6, 16.0]]})],
		[&"juggle_fall", _make(0.6, true, {
			TORSO: [[0.0, 30.0], [0.3, 24.0], [0.6, 30.0]],
			HEAD: [[0.0, 20.0], [0.6, 20.0]],
			AFU: [[0.0, 58.0], [0.3, 44.0], [0.6, 58.0]],
			ABU: [[0.0, 40.0], [0.3, 56.0], [0.6, 40.0]],
			LFU: [[0.0, 14.0], [0.3, 30.0], [0.6, 14.0]],
			LBU: [[0.0, 32.0], [0.3, 16.0], [0.6, 32.0]],
		}, {RIG + ":rotation": [[0.0, 30.0], [0.3, 36.0], [0.6, 30.0]]})],

		# --- Yere serilme ve kalkis ---
		[&"knockdown", _make(0.3, false, {
			TORSO: [[0.0, 26.0], [0.3, 8.0]],
			LFU: [[0.0, 30.0], [0.3, -46.0]],
			LFL: [[0.0, 20.0], [0.3, 40.0]],
			LBU: [[0.0, 40.0], [0.3, -30.0]],
			AFU: [[0.0, 50.0], [0.3, 16.0]],
			ABU: [[0.0, 36.0], [0.3, 10.0]],
		}, {
			RIG + ":rotation": [[0.0, 34.0], [0.3, 78.0]],
			RIG + ":position": [[0.0, Vector2(0, -10)], [0.3, Vector2(0, 30)]],
		})],
		[&"downed", _make(0.8, true, {
			TORSO: [[0.0, 8.0], [0.4, 11.0], [0.8, 8.0]],
			LFU: [[0.0, -46.0], [0.8, -46.0]],
			LFL: [[0.0, 40.0], [0.8, 40.0]],
			LBU: [[0.0, -30.0], [0.8, -30.0]],
			AFU: [[0.0, 16.0], [0.4, 20.0], [0.8, 16.0]],
			ABU: [[0.0, 10.0], [0.8, 10.0]],
		}, {
			RIG + ":rotation": [[0.0, 78.0]],
			RIG + ":position": [[0.0, Vector2(0, 30)]],
		})],
		[&"wakeup", _make(0.34, false, {
			TORSO: [[0.0, 8.0], [0.34, -4.0]],
			LFU: [[0.0, -46.0], [0.34, -8.0]],
			LFL: [[0.0, 40.0], [0.34, 10.0]],
			LBU: [[0.0, -30.0], [0.34, 12.0]],
			AFU: [[0.0, 16.0], [0.34, -50.0]],
			ABU: [[0.0, 10.0], [0.34, -30.0]],
		}, {
			RIG + ":rotation": [[0.0, 78.0], [0.34, 0.0]],
			RIG + ":position": [[0.0, Vector2(0, 30)], [0.34, Vector2.ZERO]],
		})],

		# =====================================================================
		# SALDIRILAR — hitbox_on / hitbox_off metot izleri burada
		# =====================================================================

		# Jab (on el yumruk) — hizli ve guvenli acilis
		[&"atk_light_1", _make(0.40, false, {
			TORSO: [[0.0, -4.0], [0.06, 5.0], [0.13, -13.0], [0.22, -13.0], [0.40, -4.0]],
			HEAD: [[0.0, 2.0], [0.13, -3.0], [0.40, 2.0]],
			AFU: [[0.0, -50.0], [0.06, -34.0], [0.13, -88.0], [0.22, -86.0], [0.40, -50.0]],
			AFL: [[0.0, -70.0], [0.06, -98.0], [0.13, -5.0], [0.22, -8.0], [0.40, -70.0]],
			ABU: [[0.0, -30.0], [0.06, -38.0], [0.13, -18.0], [0.40, -30.0]],
			LFU: [[0.0, -8.0], [0.13, -16.0], [0.40, -8.0]],
			LBU: [[0.0, 12.0], [0.13, 20.0], [0.40, 12.0]],
		}, {}, [
			[0.13, &"hitbox_on", [&"Hitbox_Punch"]],
			[0.16, &"open_cancel_window", []],
			[0.21, &"hitbox_off", [&"Hitbox_Punch"]],
			[0.34, &"close_cancel_window", []],
		])],

		# Yerden on tekme — jab'den zincirlenir, havalandiriciyi hazirlar
		[&"atk_kick_1", _make(0.46, false, {
			TORSO: [[0.0, -4.0], [0.08, 10.0], [0.17, 16.0], [0.26, 16.0], [0.46, -4.0]],
			AFU: [[0.0, -50.0], [0.17, -30.0], [0.46, -50.0]],
			ABU: [[0.0, -30.0], [0.17, -56.0], [0.46, -30.0]],
			LFU: [[0.0, -8.0], [0.08, -68.0], [0.17, -82.0], [0.26, -80.0], [0.46, -8.0]],
			LFL: [[0.0, 10.0], [0.08, 86.0], [0.17, 2.0], [0.26, 4.0], [0.46, 10.0]],
			LBU: [[0.0, 12.0], [0.17, 20.0], [0.46, 12.0]],
		}, {}, [
			[0.17, &"hitbox_on", [&"Hitbox_KickF"]],
			[0.20, &"open_cancel_window", []],
			[0.26, &"hitbox_off", [&"Hitbox_KickF"]],
			[0.40, &"close_cancel_window", []],
		])],

		# HAVALANDIRICI — yukselen tekme. Juggle'i baslatan hamle.
		[&"atk_launcher", _make(0.48, false, {
			TORSO: [[0.0, -4.0], [0.11, 16.0], [0.24, -28.0], [0.34, -32.0], [0.48,-4.0]],
			HEAD: [[0.0, 2.0], [0.24, 14.0], [0.48,2.0]],
			AFU: [[0.0, -50.0], [0.11, -20.0], [0.24, -120.0], [0.48,-50.0]],
			AFL: [[0.0, -70.0], [0.24, -30.0], [0.48,-70.0]],
			ABU: [[0.0, -30.0], [0.11, -10.0], [0.24, 40.0], [0.48,-30.0]],
			ABL: [[0.0, -85.0], [0.24, -20.0], [0.48,-85.0]],
			LFU: [[0.0, -8.0], [0.11, -20.0], [0.24, -118.0], [0.34, -140.0], [0.48,-8.0]],
			LFL: [[0.0, 10.0], [0.11, 36.0], [0.24, -14.0], [0.34, -8.0], [0.48,10.0]],
			LBU: [[0.0, 12.0], [0.11, 26.0], [0.24, 6.0], [0.48,12.0]],
			LBL: [[0.0, -8.0], [0.11, 20.0], [0.48,-8.0]],
		}, {
			RIG + ":position": [[0.0, Vector2.ZERO], [0.11, Vector2(0, 12)], [0.24, Vector2(0, -14)], [0.34, Vector2(0, -10)], [0.48,Vector2.ZERO]],
		}, [
			[0.24, &"hitbox_on", [&"Hitbox_KickF"]],
			[0.35, &"hitbox_off", [&"Hitbox_KickF"]],
		])],

		# HAVA TEKMESI — juggle'i surduren hizli tekme. Kendine zincirlenir.
		[&"atk_air_kick", _make(0.34, false, {
			TORSO: [[0.0, -4.0], [0.07, 8.0], [0.14, -18.0], [0.21, -18.0], [0.34, -4.0]],
			AFU: [[0.0, -60.0], [0.14, -104.0], [0.34, -60.0]],
			AFL: [[0.0, -60.0], [0.14, -22.0], [0.34, -60.0]],
			ABU: [[0.0, -40.0], [0.14, 16.0], [0.34, -40.0]],
			LFU: [[0.0, -30.0], [0.07, -58.0], [0.14, -106.0], [0.21, -104.0], [0.34, -30.0]],
			LFL: [[0.0, 25.0], [0.07, 74.0], [0.14, -6.0], [0.21, -4.0], [0.34, 25.0]],
			LBU: [[0.0, 18.0], [0.14, 34.0], [0.34, 18.0]],
			LBL: [[0.0, 0.0], [0.14, 22.0], [0.34, 0.0]],
		}, {}, [
			[0.14, &"hitbox_on", [&"Hitbox_KickF"]],
			[0.16, &"open_cancel_window", []],
			[0.22, &"hitbox_off", [&"Hitbox_KickF"]],
			[0.30, &"close_cancel_window", []],
		])],
	]


# =============================================================================
# Uretim yardimcilari
# =============================================================================
static func _make(length: float, loop: bool, rots: Dictionary, extra: Dictionary = {}, calls: Array = []) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	# Verilmeyen her kemik notr durusa sabitlenir. Bu sayede bir animasyondan
	# digerine gecerken hicbir uzuv "unutulmus" pozda takili kalmaz.
	var full: Dictionary = {}
	for bone in B.keys():
		full[bone] = [[0.0, B[bone]]]
	for bone in rots.keys():
		full[bone] = rots[bone]

	for path in full.keys():
		var ti: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(ti, NodePath(String(path) + ":rotation"))
		a.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		a.value_track_set_update_mode(ti, Animation.UPDATE_CONTINUOUS)
		for key in full[path]:
			a.track_insert_key(ti, float(key[0]), deg_to_rad(float(key[1])))

	# Rig'in kendi donusu/konumu her animasyonda sifirlanir (sizinti olmasin).
	var ex: Dictionary = {
		RIG + ":rotation": [[0.0, 0.0]],
		RIG + ":position": [[0.0, Vector2.ZERO]],
	}
	for path in extra.keys():
		ex[path] = extra[path]

	for path in ex.keys():
		var tj: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tj, NodePath(path))
		a.track_set_interpolation_type(tj, Animation.INTERPOLATION_LINEAR)
		a.value_track_set_update_mode(tj, Animation.UPDATE_CONTINUOUS)
		var is_rot: bool = String(path).ends_with(":rotation")
		for key in ex[path]:
			var v: Variant = key[1]
			if is_rot:
				v = deg_to_rad(float(v))
			a.track_insert_key(tj, float(key[0]), v)

	if not calls.is_empty():
		var tm: int = a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(tm, NodePath("."))
		for c in calls:
			a.track_insert_key(tm, float(c[0]), {"method": c[1], "args": c[2]})

	return a
