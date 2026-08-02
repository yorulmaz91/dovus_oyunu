# =============================================================================
# JuggleRules  —  Hava dovusunun BUTUN ayar dugmeleri tek panelde.
# NEREYE BAGLI: Hicbir node'a. Hazir dosya: data/rules/default_juggle.tres
#
# BIR JUGGLE NASIL BITER (sade anlatim):
#   Her vurus rakibi bir oncekinden BIRAZ DAHA AZ kaldirir (lift_decay),
#   ve yer cekimi her vurusta BIRAZ DAHA AGIRLASIR (gravity_ramp).
#   Yeterince vurustan sonra kaldirma kuvveti yer cekimini yenemez ve rakip
#   duser. Sert bir kesme yok, cirkin bir kopma yok. Kombo kendiliginden biter.
# =============================================================================
class_name JuggleRules
extends Resource

@export_group("Juggle siniri")
## Kesin tavan. Bu kadar puandan sonra vuruslar deger ama artik kaldirmaz.
@export var max_juggle_hits: int = 8

@export_group("Yukseklik sonumu")
## Her juggle vurusu bir oncekinin bu kadarini kaldirir. 0.72 profesyonel his.
@export_range(0.3, 1.0, 0.01) var lift_decay: float = 0.72
## Sonumun alt siniri; gec vuruslar yine de biraz yukari tiklasin.
@export_range(0.0, 0.6, 0.01) var min_lift_ratio: float = 0.18
## Her juggle vurusunda yer cekimi bu kadar agirlasir. 0.18 = her seferinde +%18.
@export_range(0.0, 0.6, 0.01) var gravity_ramp: float = 0.18
## YUKARI CIKARKEN yer cekimi carpani. 1'in altinda olmasi tepe noktasinda
## asili kalmayi saglar; bir sonraki tekmeyi yetistirme firsatini bu verir.
@export_range(0.1, 1.0, 0.01) var rise_gravity_scale: float = 0.50
## ASAGI INERKEN yer cekimi carpani. Juggle'daki rakip normal bir karakterden
## daha yavas duser - kovalayip yakalayabilmen icin. Kucult = daha uzun kombo.
@export_range(0.1, 1.5, 0.01) var fall_gravity_scale: float = 0.70

@export_group("Hava sersemlemesi")
@export var air_hitstun: float = 0.30
@export_range(0.5, 1.0, 0.01) var air_hitstun_decay: float = 0.90
## Sersemleme bitince BLOK tusuna basip havada toparlanma. Varsayilan kapali.
@export var allow_air_tech: bool = false

@export_group("Hasar olceklemesi")
## Kombo sirasina gore hasar carpani. Sonsuz kombolarin oldurmesini engeller.
@export var damage_scaling: PackedFloat32Array = PackedFloat32Array([1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.45, 0.4, 0.35, 0.3])

@export_group("Yere inis")
@export var knockdown_time: float = 0.55
@export var wakeup_invuln: float = 0.40
@export var air_drag: float = 320.0


func lift_scale(hits: int) -> float:
	return maxf(pow(lift_decay, float(hits)), min_lift_ratio)


func gravity_scale_for(hits: int) -> float:
	return 1.0 + float(hits) * gravity_ramp


func stun_for(hits: int) -> float:
	return air_hitstun * pow(air_hitstun_decay, float(hits))


func damage_scale(combo_index: int) -> float:
	if damage_scaling.is_empty():
		return 1.0
	return damage_scaling[clampi(combo_index, 0, damage_scaling.size() - 1)]
