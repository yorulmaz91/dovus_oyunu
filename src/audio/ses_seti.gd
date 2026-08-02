# =============================================================================
# SesSeti  —  Hamleye bagli OLMAYAN genel seslerin karti
# NEREYE BAGLI: Hicbir node'a. Bu bir Resource (veri dosyasi).
# Hazir olan: data/audio/varsayilan_sesler.tres
#
# NEDEN VAR: "blok sesi hangi dosya" sorusunun cevabi KODDA degil VERIDE
# dursun. Inspector'dan baska bir .wav surukleyip degistirebilirsin,
# tek satir kod yazmadan.
#
# Hamlelerin kendi sesleri BURADA DEGIL: onlar hamle kartlarinda
# (data/moves/... icinde swing_sfx ve hit_sfx alanlari).
# =============================================================================
class_name SesSeti
extends Resource

@export_group("Genel dovus sesleri")
## Vurus bloklandiginda.
@export var blok: AudioStream
## Bir dovuscu oldugunde.
@export var nakavt: AudioStream
## Her ziplamada (yerden ve saldiri iptalinden).
@export var zipla: AudioStream
## Yere serilme aninda (Knockdown ve Dead).
@export var yere_dusme: AudioStream
