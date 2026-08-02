# =============================================================================
# ses_uret.gd  —  YER TUTUCU SES EFEKTLERINI URETIR
#
# NE ISE YARAR: assets/sfx/ altina 9 adet WAV yazar. Hicbir dis dosya, hicbir
# indirme gerekmez - dalgalar burada matematikle uretilir. Gercek seslerini
# bulunca ayni ada .wav birak, kod degistirmene gerek yok.
#
# NASIL CALISTIRILIR (komut satirindan, proje klasorunde):
#   Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/ses_uret.gd
#
# TEKRAR URETILEBILIR: her dosyanin gurultusu SABIT tohumla uretilir, yani
# ayni komut her zaman ayni baytlari verir.
# =============================================================================
extends SceneTree

const CIKIS := "res://assets/sfx/"
const HZ: int = 32000
const TEPE: float = 0.8
const FADE_SN: float = 0.005  # bas/son klik onleme

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	print("\n=========== SES URETICI ===========")
	print("Cikis: %s" % CIKIS)
	print("Bicim: mono, %d Hz, 16-bit, tepe %.2f, %d ms fade" % [
		HZ, TEPE, int(FADE_SN * 1000.0)])
	var hata := DirAccess.make_dir_recursive_absolute(CIKIS)
	if hata != OK and hata != ERR_ALREADY_EXISTS:
		push_error("assets/sfx klasoru olusturulamadi: %d" % hata)
		quit(1)
		return
	print("")

	_savurma()
	_vurus_hafif()
	_vurus_orta()
	_vurus_agir()
	_vurus_hava()
	_blok()
	_zipla()
	_yere_dusme()
	_nakavt()

	print("\n=========== BITTI ===========\n")
	quit()


# =============================================================================
# TARIFLER
# =============================================================================

## Savurma: bant supurmeli gurultu 500 -> 1800 Hz. Havayi yaran his.
func _savurma() -> void:
	_rng.seed = 1001
	var a := _bos(0.14)
	_bant_gurultu(a, 500.0, 1800.0, 0.55, 1.0)
	_zarf(a, 0.035, 11.0)
	_yaz("savurma.wav", a)


## Hafif vurus: alcalan sinus + kisa gurultu patlamasi.
func _vurus_hafif() -> void:
	_rng.seed = 1002
	var a := _bos(0.09)
	_sinus_supurme(a, 180.0, 90.0, 45.0, 1.0)
	_gurultu(a, 0.020, 120.0, 0.35)
	_yaz("vurus_hafif.wav", a)


## Orta vurus: daha alcak sinus, daha gur patlama.
func _vurus_orta() -> void:
	_rng.seed = 1003
	var a := _bos(0.12)
	_sinus_supurme(a, 140.0, 70.0, 35.0, 1.0)
	_gurultu(a, 0.025, 100.0, 0.55)
	_yaz("vurus_orta.wav", a)


## Agir vurus: derin bom + catirti + uzun kuyruk.
func _vurus_agir() -> void:
	_rng.seed = 1004
	var a := _bos(0.22)
	_sinus_supurme(a, 100.0, 45.0, 16.0, 1.0)
	_gurultu(a, 0.050, 60.0, 0.50)
	_bant_gurultu(a, 2200.0, 700.0, 0.7, 0.22)  # catirti
	_zarf(a, 0.002, 9.0)
	_yaz("vurus_agir.wav", a)


## Hava tekmesi: vurus_hafif'in %20 tiz hali (butun frekanslar x1.2).
func _vurus_hava() -> void:
	_rng.seed = 1005
	var a := _bos(0.09)
	_sinus_supurme(a, 180.0 * 1.2, 90.0 * 1.2, 45.0, 1.0)
	_gurultu(a, 0.020, 120.0, 0.35)
	_yaz("vurus_hava.wav", a)


## Blok: metalik tik - iki cinlama + azicik gurultu.
func _blok() -> void:
	_rng.seed = 1006
	var a := _bos(0.08)
	_cinlama(a, 900.0, 60.0, 1.0)
	_cinlama(a, 1400.0, 75.0, 0.7)
	_gurultu(a, 0.006, 400.0, 0.25)
	_yaz("blok.wav", a)


## Ziplama: hizli yukari civilti.
func _zipla() -> void:
	_rng.seed = 1007
	var a := _bos(0.09)
	_sinus_supurme(a, 300.0, 520.0, 25.0, 1.0)
	_yaz("zipla.wav", a)


## Yere dusme: gum + kisa gurultu.
func _yere_dusme() -> void:
	_rng.seed = 1008
	var a := _bos(0.16)
	_sinus_supurme(a, 90.0, 50.0, 22.0, 1.0)
	_gurultu(a, 0.030, 90.0, 0.40)
	_yaz("yere_dusme.wav", a)


## Nakavt: buyuk bom + gurultu + yumusak kirpma (doygun, agir).
func _nakavt() -> void:
	_rng.seed = 1009
	var a := _bos(0.50)
	_sinus_supurme(a, 70.0, 35.0, 7.0, 1.0)
	_gurultu(a, 0.120, 30.0, 0.35)
	_yumusak_kirp(a, 2.5)
	_yaz("nakavt.wav", a)


# =============================================================================
# DALGA YAPI TASLARI
# =============================================================================
func _bos(sure: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(maxi(1, int(sure * float(HZ))))
	a.fill(0.0)
	return a


## Ussel sonumlu sinus supurmesi (f0 -> f1). Faz birikimli, yani supurme
## sirasinda tiklama olmaz.
func _sinus_supurme(a: PackedFloat32Array, f0: float, f1: float, sonum: float, kazanc: float) -> void:
	var n: int = a.size()
	var faz: float = 0.0
	for i in n:
		var t: float = float(i) / float(maxi(1, n - 1))
		faz += TAU * lerpf(f0, f1, t) / float(HZ)
		a[i] += sin(faz) * exp(-sonum * float(i) / float(HZ)) * kazanc


## Ussel sonumlu gurultu patlamasi (ilk sure_sn saniye).
func _gurultu(a: PackedFloat32Array, sure_sn: float, sonum: float, kazanc: float) -> void:
	var n: int = mini(a.size(), int(sure_sn * float(HZ)))
	for i in n:
		a[i] += _rng.randf_range(-1.0, 1.0) * exp(-sonum * float(i) / float(HZ)) * kazanc


## Bant supurmeli gurultu. Chamberlin durum degiskenli suzgeci (SVF) ile
## rezonansli bant gecirgen; merkez frekans f0'dan f1'e suzulur.
func _bant_gurultu(a: PackedFloat32Array, f0: float, f1: float, rezonans: float, kazanc: float) -> void:
	var n: int = a.size()
	var alcak: float = 0.0
	var bant: float = 0.0
	for i in n:
		var t: float = float(i) / float(maxi(1, n - 1))
		var f: float = 2.0 * sin(PI * lerpf(f0, f1, t) / float(HZ))
		var giris: float = _rng.randf_range(-1.0, 1.0)
		alcak += f * bant
		var yuksek: float = giris - alcak - rezonans * bant
		bant += f * yuksek
		a[i] += bant * kazanc


## Sonumlu saf ton - metalik cinlama icin.
func _cinlama(a: PackedFloat32Array, f: float, sonum: float, kazanc: float) -> void:
	for i in a.size():
		var t: float = float(i) / float(HZ)
		a[i] += sin(TAU * f * t) * exp(-sonum * t) * kazanc


## Zarf: kisa yukselis + ussel dusus.
func _zarf(a: PackedFloat32Array, yukselis_sn: float, sonum: float) -> void:
	var y: int = maxi(1, int(yukselis_sn * float(HZ)))
	for i in a.size():
		var t: float = float(i) / float(HZ)
		a[i] *= minf(1.0, float(i) / float(y)) * exp(-sonum * t)


## Yumusak kirpma: tepeler kesilmez, ezilir. Doygun ve agir duyulur.
func _yumusak_kirp(a: PackedFloat32Array, miktar: float) -> void:
	var bolen: float = tanh(miktar)
	for i in a.size():
		a[i] = tanh(a[i] * miktar) / bolen


# =============================================================================
# NORMALIZE + FADE + WAV YAZIMI
# =============================================================================
func _bitir(a: PackedFloat32Array) -> void:
	var enb: float = 0.0
	for v in a:
		enb = maxf(enb, absf(v))
	if enb > 0.0:
		var k: float = TEPE / enb
		for i in a.size():
			a[i] *= k
	# Bas ve son 5 ms yumusatilir - aksi halde her calista "tik" duyulur.
	var f: int = mini(int(FADE_SN * float(HZ)), a.size() / 2)
	for i in f:
		var g: float = float(i) / float(f)
		a[i] *= g
		a[a.size() - 1 - i] *= g


## WAV'i AudioStreamWAV.save_to_wav ile yaziyoruz - RIFF basligini motorun
## kendisi kuruyor, elle bayt dizmekten daha az hata riski var.
func _yaz(ad: String, a: PackedFloat32Array) -> void:
	_bitir(a)

	var bayt := PackedByteArray()
	bayt.resize(a.size() * 2)
	for i in a.size():
		bayt.encode_s16(i * 2, int(round(clampf(a[i], -1.0, 1.0) * 32767.0)))

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = HZ
	w.stereo = false
	w.data = bayt

	var yol: String = CIKIS + ad
	var hata := w.save_to_wav(yol)
	if hata != OK:
		push_error("%s yazilamadi: %d" % [yol, hata])
		return
	print("  %-18s %6.3f sn  %7d ornek  %8d bayt" % [
		ad, float(a.size()) / float(HZ), a.size(),
		FileAccess.get_file_as_bytes(yol).size()])
