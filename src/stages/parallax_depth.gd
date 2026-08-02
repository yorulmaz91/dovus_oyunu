# =============================================================================
# ParallaxDepth  —  Derinlik katmani
# NEREYE BAGLI: Sahnedeki HER Parallax2D node'una.
#
# Sadece TEK bir sayiya dokunursun: "Depth" (derinlik).
#   0.0 = sonsuz uzakta (hic kimildamaz)
#   1.0 = dovus duzlemi
#   1.0 uzeri = dovusculerin ONUNDE (on plan sutunlari)
#
# Ayrica sahte atmosfer sisi yapar: uzak katmanlar sis rengine dogru solar.
# "2.5D" hissini en cok veren numara budur ve maliyeti sifirdir.
# =============================================================================
@tool
class_name ParallaxDepth
extends Parallax2D

@export_range(0.0, 2.0, 0.01) var depth: float = 0.5:
	set(value):
		depth = value
		_apply()

@export_group("Atmosfer")
## Uzak katmanlar bu renge dogru solar. CanvasModulate rengiyle uyumlu olsun.
@export var fog_color: Color = Color(0.30, 0.34, 0.46):
	set(value):
		fog_color = value
		_apply()
## 0 = sis yok, 1 = en uzak katman tamamen sis rengi olur.
@export_range(0.0, 1.0, 0.01) var fog_strength: float = 0.8:
	set(value):
		fog_strength = value
		_apply()

@export_group("Hareket")
## Dikeyde de kaymasi gereken katmanlar icin acilir (bulutlar, tavan).
@export var vertical_parallax: bool = false:
	set(value):
		vertical_parallax = value
		_apply()
## Sabit surukleme (piksel/saniye) - bulut, yagmur, neon akisi. Ucuz ve etkili.
@export var drift: Vector2 = Vector2.ZERO:
	set(value):
		drift = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return

	# scroll_scale = bu katmanin kamerayi ne kadar takip ettigi.
	# 1.0 = dunyaya kilitli. Daha dusuk = daha uzak.
	scroll_scale = Vector2(depth, depth if vertical_parallax else 1.0)
	autoscroll = drift

	# Atmosferik perspektif: uzak katmanlari sis rengine dogru soldur.
	var nearness: float = clampf(depth, 0.0, 1.0)
	var t: float = 1.0 - (1.0 - nearness) * fog_strength
	modulate = Color(
		lerpf(fog_color.r, 1.0, t),
		lerpf(fog_color.g, 1.0, t),
		lerpf(fog_color.b, 1.0, t),
		1.0
	)

	# Cizim sirasi derinlikten kendiliginden cikar - elle siralama yok.
	z_index = clampi(int(lerpf(-200.0, 200.0, depth * 0.5)), -4096, 4096)
