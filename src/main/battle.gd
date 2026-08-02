# =============================================================================
# Battle  —  Ana sahne
# NEREYE BAGLI: battle.tscn dosyasinin kok Node2D node'una.
# Bu, oyun calistiginda acilan sahnedir (Proje Ayarlari > run/main_scene).
# =============================================================================
extends Node2D

@onready var stage: Stage = $NeoDojo
@onready var player: Fighter = $Fighters/Lyra
@onready var enemy: Fighter = $Fighters/Grunt
@onready var cam: BattleCamera = $BattleCamera
@onready var hud: BattleHud = $HUD

var _ko_label: Label
## Nakavt bir kere olur. Iki taraf da ayni karede olse bile etiket ve
## dondurma tek sefer calissin.
var _match_over: bool = false


func _ready() -> void:
	player.opponent = enemy
	enemy.opponent = player
	player.global_position = stage.spawn_p1
	enemy.global_position = stage.spawn_p2
	player.set_facing(1)
	enemy.set_facing(-1)

	cam.targets = [player, enemy]
	cam.global_position = (stage.spawn_p1 + stage.spawn_p2) * 0.5 + Vector2(0, -160)
	stage.apply_camera_limits(cam)

	hud.setup(player, enemy)
	# TEKRAR dugmesi: TouchScreenButton'in "action" alani Input.action_press
	# yoluyla calisir ve _unhandled_input'a olay DUSURMEZ. O yuzden action'a
	# guvenmeyip dogrudan sinyale baglaniyoruz.
	hud.restart_button().pressed.connect(_restart)
	CombatEvents.fighter_died.connect(_on_died)

	_ko_label = Label.new()
	_ko_label.set_anchors_preset(Control.PRESET_CENTER)
	# Genis: son satir ("TEKRAR ya da R = yeniden basla") 52 punto ile
	# yaklasik 780 px tutuyor.
	_ko_label.offset_left = -470.0
	_ko_label.offset_right = 470.0
	# Uc satir siger: "NAKAVT!" + kazanan + yeniden baslatma satiri.
	_ko_label.offset_top = -110.0
	_ko_label.offset_bottom = 110.0
	_ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ko_label.add_theme_font_size_override("font_size", 52)
	_ko_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_ko_label.visible = false
	hud.add_child(_ko_label)


func _on_died(who: Node) -> void:
	if _match_over:
		return
	_match_over = true

	var player_won: bool = who != player
	# KAZANANI DONDUR: girdi kaynagi kapanir, suren saldirisi dogal olarak
	# biter ama yeni bir eylem baslatamaz. Hem oyuncu hem YZ icin ayni yol.
	var winner: Fighter = player if player_won else enemy
	winner.input.disable()

	# Telefonda R tusu yok: ekrandaki TEKRAR dugmesi de ayni isi yapar.
	_ko_label.text = "NAKAVT!\n%s KAZANDI\nTEKRAR ya da R = yeniden basla" % (
		"LYRA" if player_won else "DUSMAN")
	_ko_label.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if player_won else Color(1.0, 0.35, 0.35))
	_ko_label.visible = true


## Dead durumundan TEK cikis. Iki yol da buraya gelir: klavyeden R ve
## ekrandaki TEKRAR dugmesi.
func _restart() -> void:
	get_tree().reload_current_scene()


## R dovusculerin girdi kaynagindan BAGIMSIZ: sahnenin kendi girdisi oldugu
## icin nakavttan sonra da calisir.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		_restart()
