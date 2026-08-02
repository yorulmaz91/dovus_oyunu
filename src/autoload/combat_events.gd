# =============================================================================
# CombatEvents  —  Ortak ilan tahtasi
# NEREYE BAGLI: Hicbir node'a. Bu bir AUTOLOAD (Proje Ayarlari > Globals).
#
# Kamera, arayuz, isiklar ve sesler dovusculeri hic tanimadan olan bitene
# tepki verebilsin diye burasi var.
# =============================================================================
extends Node

signal hit_confirmed(attacker: Node, victim: Node, info: HitInfo)
## Vurus BLOKLANDI. DIKKAT: bloklu vurusta hit_confirmed DE yayilir
## (take_hit blok dalinda da true doner). Ikisini ayirt etmesi gereken
## dinleyiciler info.id ile eslestirmeli - SesCalar boyle yapiyor.
signal hit_blocked(victim: Node, info: HitInfo)
signal camera_shake_requested(strength: float)
signal combo_updated(victim: Node, hits: int)
signal fighter_died(fighter: Node)
