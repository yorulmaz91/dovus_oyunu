# =============================================================================
# HitData  —  Bir saldirinin "kimlik karti"
# NEREYE BAGLI: Hicbir node'a. Bu bir Resource (veri dosyasi).
# Hazir olanlar: data/moves/lyra/ klasorunde.
# =============================================================================
class_name HitData
extends Resource

enum Height { HIGH, MID, LOW, OVERHEAD }
enum Reaction { LIGHT, HEAVY, CRUMPLE, LAUNCH, KNOCKDOWN, SWEEP }

@export_group("Hasar")
@export var damage: float = 8.0
@export var chip_damage: float = 1.0

@export_group("Zamanlama (saniye)")
@export var hitstun: float = 0.22
@export var blockstun: float = 0.14
## Temas aninda donma suresi. Darbenin "tokat gibi" hissettirmesi buradan gelir.
@export var hitstop: float = 0.06

@export_group("Fizik")
@export var knockback: Vector2 = Vector2(180.0, 0.0)
## Havalandirma / havada tutma kuvveti.
@export var launch_power: float = 720.0

@export_group("Kurallar")
@export var height: Height = Height.MID
@export var reaction: Reaction = Reaction.LIGHT
@export var unblockable: bool = false
## Kapali ise bu hamle havadaki rakibi yukarida TUTAMAZ, dusurur.
@export var can_juggle: bool = true
## Bu vurusun harcadigi juggle puani. Agir hamleler 2-3 olmali.
@export var juggle_cost: int = 1

@export_group("Geri bildirim")
@export var hit_vfx: PackedScene
@export var hit_sfx: AudioStream
@export var camera_shake: float = 2.0
