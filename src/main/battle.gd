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
	CombatEvents.fighter_died.connect(_on_died)

	_ko_label = Label.new()
	_ko_label.set_anchors_preset(Control.PRESET_CENTER)
	_ko_label.offset_left = -300.0
	_ko_label.offset_right = 300.0
	_ko_label.offset_top = -60.0
	_ko_label.offset_bottom = 60.0
	_ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_label.add_theme_font_size_override("font_size", 64)
	_ko_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_ko_label.visible = false
	hud.add_child(_ko_label)


func _on_died(who: Node) -> void:
	_ko_label.text = "NAKAVT!\nR = yeniden basla"
	_ko_label.add_theme_font_size_override("font_size", 52)
	_ko_label.visible = true
	if who == player:
		_ko_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		_ko_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
