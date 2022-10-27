extends KinematicBody2D
class_name PacMan

signal player_reset
export var speed := 175
export var current_dir = "none"
export var movement_direction := Vector2.ZERO
var movement_enabled = false

var velocity := Vector2()
var inputs = {"right": Vector2.RIGHT,
			"left": Vector2.LEFT,
			"up": Vector2.UP,
			"down": Vector2.DOWN}

func get_input():
	if movement_enabled:
		velocity = Vector2()
		for input in inputs:
			if Input.is_action_just_pressed(input):
				current_dir = input
				movement_direction = inputs[input]
				animate_movement()
		
		velocity = movement_direction * speed


func animate_movement():
	$Sprite.play("eating")
	match current_dir:
		"right":
			$Sprite.rotation_degrees = 0
			$Sprite.flip_h = false
		"left":
			$Sprite.rotation_degrees = 0
			$Sprite.flip_h = true
		"up":
			$Sprite.rotation_degrees = -90
			$Sprite.flip_h = false
		"down":
			$Sprite.rotation_degrees = 90
			$Sprite.flip_h = false


func die():
	movement_enabled = false
	$Sprite.play("die")
	$Dead.play()
	var _d = $Sprite.connect("animation_finished", self, "reset")


func _physics_process(_delta):
	if !movement_enabled:
		return
	
	get_input()
	velocity = move_and_slide(velocity)
	if velocity.length() < 1 and movement_direction != Vector2.ZERO:
		movement_direction = Vector2.ZERO
		current_dir = "none"
		$Sprite.playing = false


func warp_to(pos):
	global_position = pos


func reset():
	if $Sprite.is_connected("animation_finished", self, "reset"):
		$Sprite.disconnect("animation_finished", self, "reset")
	position = Vector2(264, 212)
	$Sprite.play("idle")
	current_dir = "none"
	movement_direction = Vector2.ZERO
	emit_signal("player_reset")
