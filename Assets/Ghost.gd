extends KinematicBody2D
class_name Ghost

signal player_ate_ghost
signal ghost_ate_player
signal ghost_became_vulnerable
signal ghost_restored

export var speed := 176
export var state_speed := 1
export var color = "Red"
var state = IN_PEN
var start_pos

var path := PoolVector2Array() setget set_path
enum {
	IN_PEN,
	CHASE,
	CORNER,
	SCARED,
	EATEN
}


func _ready():
	start_pos = position


func _physics_process(delta):
	if path.size() == 0:
		if state == EATEN:
			state = CHASE
			emit_signal("ghost_restored")
		return
	
	var starting_point := position
	var distance = position.distance_to(path[0])
	if distance < speed * delta:
		path.remove(0)
		if path.size() == 0:
			return
		
	var speed_multiplier = 1
	match state:
		EATEN:
			speed_multiplier = 2
		SCARED:
			speed_multiplier = 0.6
	var velocity = (path[0] - starting_point).normalized() * speed * speed_multiplier
	animate(velocity)
	velocity = move_and_slide(velocity)


func start():
	state = CHASE


func chase():
	if state == CORNER or state == SCARED:
		state = CHASE


func corner():
	if state == CHASE or state == SCARED:
		state = CORNER


func scared():
	if state != IN_PEN and state != EATEN:
		state = SCARED
		emit_signal("ghost_became_vulnerable")


func animate(velocity: Vector2):
	match state:
		IN_PEN, CHASE, CORNER:
			if abs(velocity.x) > abs(velocity.y):
				# Horizontal
				if velocity.x > 0:
					$Animation.play("move_right")
				else:
					$Animation.play("move_left")
			else:
				# Vertical
				if velocity.y > 0:
					$Animation.play("move_down")
				else:
					$Animation.play("move_up")
		EATEN:
			if abs(velocity.x) > abs(velocity.y):
				# Horizontal
				if velocity.x > 0:
					$Animation.play("eye_right")
				else:
					$Animation.play("eye_left")
			else:
				# Vertical
				if velocity.y > 0:
					$Animation.play("eye_down")
				else:
					$Animation.play("eye_up")
		SCARED:
			$Animation.play("scared")


func reset():
	position = start_pos
	state = IN_PEN
	path = PoolVector2Array([])
	$Animation.play("idle")


func set_path(value : PoolVector2Array) -> void:
	path = value


func warp_to(pos):
	global_position = pos
	path.resize(0)


func _on_Area_body_entered(_body):
	if state == SCARED:
		emit_signal("player_ate_ghost", self)
		state = EATEN
	elif state == CHASE or state == CORNER:
		emit_signal("ghost_ate_player", self)
