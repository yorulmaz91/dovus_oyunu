# =============================================================================
# MoveDef  —  Bir tusu bir animasyona baglar ve zincirleri tanimlar.
# NEREYE BAGLI: Hicbir node'a. Hazir olanlar: data/moves/lyra/
# =============================================================================
class_name MoveDef
extends Resource

## Benzersiz isim. Diger hamleler "chain_to" listesinde buna referans verir.
@export var id: StringName = &"light_1"
## AnimationPlayer icindeki bir animasyon adiyla AYNI olmali.
@export var animation: StringName = &"atk_light_1"
## Input Map icindeki bir eylem adiyla AYNI olmali.
@export var input_action: StringName = &"attack_light"
## Bu hamlenin hasar karti. Ayni tekme kutusu farkli hamlelerde farkli hasar
## versin diye HitData hamleye baglidir, kutuya degil.
@export var hit: HitData
## SAVURMA sesi - vurus kutusu ACILIRKEN calar, yani ISKALASA DA duyulur.
## Degdiginde calan ses ise yukaridaki hasar kartinda (hit.hit_sfx).
@export var swing_sfx: AudioStream

@export_group("Kurallar")
## Bostan baslatilabilir mi? Devam hamlelerinde kapali olmali.
@export var is_opener: bool = true
## Acik ise sadece havada kullanilir.
@export var airborne: bool = false
## Iptal penceresinde gecilebilecek hamle id'leri.
@export var chain_to: Array[StringName] = []
## Acik ise iptal penceresinde ZIPLA tusuna basarak toparlanma kesilir ve
## dovuscu havalanir. Havalandiriciya ac: kendi juggle'ini kovalayabilmenin
## tek yolu budur. Iptal penceresi vurus ONAYIYLA acildigi icin, bosa sallanan
## bir hamle ziplamayla iptal EDILEMEZ.
@export var jump_cancel: bool = false
## Hamle baslarken one atilma hizi (piksel/saniye).
@export var forward_momentum: float = 0.0
## Hamle oynarken rakibe donmeyi durdur. Neredeyse her zaman acik olmali.
@export var lock_facing: bool = true
