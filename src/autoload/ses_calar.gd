# =============================================================================
# SesCalar  —  Ses efekti calici
# NEREYE BAGLI: Hicbir node'a. Bu bir AUTOLOAD (Proje Ayarlari > Globals).
# Sira ONEMLI: HitStop -> CombatEvents -> SesCalar. (CombatEvents'in
# sinyallerine _ready icinde abone oluyoruz, o yuzden ondan SONRA gelmeli.)
#
# NASIL CALISIR: 8 AudioStreamPlayer'lik sabit bir havuz. Hepsi bos degilse
# EN ESKI baslayan devralinir (voice steal) - hata uretmez, ses kesilir.
# Her calista pitch hafifce rastgele: ayni tekme ust uste calindiginda
# "makineli tufek" gibi tekduze duyulmasin.
#
# HITSTOP NOTU (bilincli davranis): HitStop, Engine.time_scale'i 0 yapar ama
# AudioStreamPlayer'lar time_scale'den ETKILENMEZ. Yani vurus sesi donma
# boyunca calmaya devam eder. Istenen his tam olarak budur.
#
# TARAYICI NOTU: tarayicilar ilk kullanici etkilesimine kadar sesi kilitler.
# Web surumunde ses, ilk dokunus/tiklamayla baslar. Bu bir hata degil,
# tarayici kuralidir.
# =============================================================================
extends Node

## Ayni anda calabilecek ses sayisi.
const HAVUZ: int = 8
## son_calinanlar halka kaydinin boyu.
const KAYIT_BOYU: int = 32
const VARSAYILAN_SET := "res://data/audio/varsayilan_sesler.tres"

# --- Baslangic ses seviyeleri (dB). Hepsi TEK YERDE dursun. ---
const DB_SAVURMA: float = -12.0
const DB_BLOK: float = -8.0
const DB_ZIPLA: float = -14.0
const DB_YERE_DUSME: float = -6.0
const DB_NAKAVT: float = 0.0

## Hamleye bagli olmayan sesler. Inspector'dan degistirilebilir.
var setler: SesSeti

## SON calinan sesler: [{ses, yol, kare}, ...]. Testlerin KANIT kaynagi budur -
## headless'ta ses surucusu sahte olabildigi icin player.playing bayragina
## guvenilmez.
var son_calinanlar: Array = []

var _oyuncular: Array[AudioStreamPlayer] = []
## Kullanim sirasi: bas = en eski, son = en yeni.
var _sira: Array[int] = []
## Bloklanan son vurusun kimligi - asagida neden gerektigi anlatiliyor.
var _son_bloklanan_id: int = 0


func _ready() -> void:
	for i in HAVUZ:
		var p := AudioStreamPlayer.new()
		p.name = "Oyuncu%d" % i
		p.bus = &"SFX"
		add_child(p)
		_oyuncular.append(p)
		_sira.append(i)

	setler = load(VARSAYILAN_SET) as SesSeti
	if setler == null:
		push_warning("SesCalar: %s yuklenemedi, genel sesler calmayacak." % VARSAYILAN_SET)

	CombatEvents.hit_confirmed.connect(_on_hit_confirmed)
	CombatEvents.hit_blocked.connect(_on_hit_blocked)
	CombatEvents.fighter_died.connect(_on_fighter_died)


## Butun sesleri keser. Simdilik oyun icinde cagiran yok; duraklat/yeniden
## basla gibi bir ihtiyac cikarsa hazir.
func sustur() -> void:
	for p in _oyuncular:
		p.stop()


# -----------------------------------------------------------------------------
# TEK GIRIS NOKTASI
# -----------------------------------------------------------------------------
func cal(stream: AudioStream, volume_db: float = 0.0,
		pitch_min: float = 0.94, pitch_max: float = 1.06) -> void:
	if stream == null:
		return
	var p := _oyuncu_bul()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()
	_kaydet(stream)


# --- Genel sesler icin kisayollar (hepsi cal() uzerinden gider) ---
func cal_blok() -> void:
	if setler != null:
		cal(setler.blok, DB_BLOK)


func cal_nakavt() -> void:
	if setler != null:
		cal(setler.nakavt, DB_NAKAVT)


func cal_zipla() -> void:
	if setler != null:
		cal(setler.zipla, DB_ZIPLA)


func cal_yere_dusme() -> void:
	if setler != null:
		cal(setler.yere_dusme, DB_YERE_DUSME)


# -----------------------------------------------------------------------------
# Havuz
# -----------------------------------------------------------------------------
func _oyuncu_bul() -> AudioStreamPlayer:
	for i in _oyuncular.size():
		if not _oyuncular[i].playing:
			_sirala(i)
			return _oyuncular[i]
	# Hepsi dolu: en eski baslayani devral. Hata YOK, ses kesilir.
	var en_eski: int = _sira[0]
	_sirala(en_eski)
	return _oyuncular[en_eski]


func _sirala(i: int) -> void:
	_sira.erase(i)
	_sira.append(i)


func _kaydet(stream: AudioStream) -> void:
	var yol: String = stream.resource_path
	son_calinanlar.append({
		"ses": yol.get_file() if yol != "" else "(gomulu)",
		"yol": yol,
		"kare": Engine.get_physics_frames(),
	})
	while son_calinanlar.size() > KAYIT_BOYU:
		son_calinanlar.remove_at(0)


# -----------------------------------------------------------------------------
# Olaylar
# -----------------------------------------------------------------------------
## DIKKAT - BLOK/DARBE AYRIMI:
## Bloklanan bir vurusta Fighter.take_hit YINE true doner (bkz. fighter.gd
## blok dali), bu yuzden Hitbox on_hit_landed'i cagirir ve hit_confirmed DE
## yayilir. Yani tek bir bloklu vurus icin once hit_blocked, hemen ardindan
## ayni info.id ile hit_confirmed gelir. Ikisi de ayni cagri yiginindadir,
## araya baska vurus giremez - o yuzden tek bir "son bloklanan kimlik"
## degiskeni yeterlidir. Ayni kimligi gorunce darbe sesini ATLIYORUZ,
## yoksa blok sesiyle darbe sesi ust uste binerdi.
func _on_hit_blocked(_victim: Node, info: HitInfo) -> void:
	_son_bloklanan_id = info.id
	cal_blok()


func _on_hit_confirmed(_attacker: Node, _victim: Node, info: HitInfo) -> void:
	if info.id == _son_bloklanan_id:
		return
	cal(info.data.hit_sfx, info.data.hit_sfx_db)


func _on_fighter_died(_who: Node) -> void:
	cal_nakavt()
