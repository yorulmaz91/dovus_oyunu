# NEREYE BAGLI: OYUNCU dovuscusunun "InputSource" adli cocuk node'una.
class_name PlayerInput
extends InputSource

const BUFFERED_ACTIONS: Array[StringName] = [
	&"attack_light", &"attack_heavy", &"attack_kick", &"jump", &"dash", &"block"
]


func _poll(_delta: float) -> void:
	move_x = Input.get_axis(&"move_left", &"move_right")
	block_held = Input.is_action_pressed(&"block")
	jump_held = Input.is_action_pressed(&"jump")
	for action in BUFFERED_ACTIONS:
		if Input.is_action_just_pressed(action):
			press(action)
