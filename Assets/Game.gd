extends Node2D

const tile_size = 8

export(Resource) var pellet_prefab
export var vulnerable_time := 7.0

var pellets_left = 244
var starting_pellets = pellets_left
var current_ghost := 0
var ghost_names = ["Red", "Pink", "Blue", "Orange"]
var lives := 5
var vulnearable_ghosts := 0
var eaten_ghosts := 0
var ghost_bonus = 200
var mortal = true

onready var ghosts = [$Enemies/Red, $Enemies/Pink, $Enemies/Blue, $Enemies/Orange]
onready var draw_lines = [$Enemies/Red_Line, $Enemies/Pink_Line, $Enemies/Blue_Line, $Enemies/Orange_Line]
onready var player : PacMan = $"Pac-Man"
onready var nav_2D : Navigation2D = $Arena/Arena_Navigator

var scattering := false


func _init():
	Console.add_command("toggle_navigation_draw", self, "toggle_debug_draw").register()
	Console.add_command("skip_level", self, "level_won").register()
	Console.add_command("invulnerability", self, "toggle_invulnerability").register()


func level_won():
	$UI.level_won()
	reset()


func reset():
	stop_ghost_audio()
	for ghost in ghosts:
		ghost.reset()
	vulnearable_ghosts = 0
	eaten_ghosts = 0
	$Pellets.queue_free()
	yield(get_tree().create_timer(1.0), "timeout")
	player.reset()
	yield(get_tree().create_timer(0.10), "timeout")
	var pellets = pellet_prefab.instance()
	add_child(pellets)
	pellets.connect("pellet_eaten", self, "_on_Pellet_eaten")
	pellets.connect("power_pellet_eaten", self, "_on_Power_Pellet_eaten")
	pellets_left = 244
	starting_pellets = pellets_left


func ghost_repath():
	# Select the next ghost.
	current_ghost += 1
	if current_ghost >= ghosts.size():
		current_ghost = 0
	
	
	# Re-process pathfinding for the next ghost
	var ghost: Ghost = ghosts[current_ghost]
	
	match ghost.state:
		Ghost.CHASE:
			var new_path
			match ghost_names[current_ghost]:
				"Red":
					new_path = nav_2D.get_simple_path(ghost.position, player.position)
				"Pink":
					var target_position = player.position + (player.velocity.normalized() * 4 * tile_size)
					new_path = nav_2D.get_simple_path(ghost.position, target_position)
				"Blue":
					var player_heading = player.position + (player.velocity.normalized() * 2 * tile_size)
					var blinky_vector = ($Enemies/Red.position - player_heading)
					var target_position = player_heading - blinky_vector
					new_path = nav_2D.get_simple_path(ghost.position, target_position)
				"Orange":
					var distance = ghost.position.distance_to(player.position)
					if distance > 8 * tile_size:
						new_path = nav_2D.get_simple_path(ghost.position, player.position)
					else:
						var target_position = player.position + (player.velocity.normalized() * -10 * tile_size)
						new_path = nav_2D.get_simple_path(ghost.position, target_position)
			# Apply the path.
			draw_lines[current_ghost].points = new_path
			ghost.path = new_path
		Ghost.CORNER:
			if ghost.path.size() < 3:
				var new_pos
				match ghost_names[current_ghost]:
					"Red":
						new_pos = Vector2(rand_range(264, 372), rand_range(24, 120))
					"Pink":
						new_pos = Vector2(rand_range(156, 264), rand_range(24, 120))
					"Blue":
						new_pos = Vector2(rand_range(264, 372), rand_range(156, 270))
					"Orange":
						new_pos = Vector2(rand_range(156, 264), rand_range(156, 270))
				
				# Apply the path.
				var new_path := nav_2D.get_simple_path(ghost.position, new_pos)
				draw_lines[current_ghost].points = new_path
				ghost.path = new_path
		Ghost.SCARED:
			var new_pos = Vector2(rand_range(156, 372), rand_range(24, 270))
			var new_path := nav_2D.get_simple_path(ghost.position, new_pos)
			draw_lines[current_ghost].points = new_path
			ghost.path = new_path
		Ghost.EATEN:
			pass
		Ghost.IN_PEN:
			pass


func _on_ExitL_body_entered(body):
	if body is PacMan or body is Ghost:
		body.warp_to($"Arena/Exit-R".global_position)


func _on_ExitR_body_entered(body):
	if body is PacMan or body is Ghost:
		body.warp_to($"Arena/Exit-L".global_position)


func _on_Power_Pellet_eaten():
	$Sounds/Ghost_Woo.stop()
	ghost_bonus = 200
	$UI.add_score(50)
	for ghost in ghosts:
		ghost.scared()
	for _i in 4:
		ghost_repath()
	scattering = true
	$Scatter_Timer.start(vulnerable_time)
	pellets_left -= 1
	if pellets_left == 0:
		level_won()


func _on_Pellet_eaten():
	$UI.add_score(10)
	pellets_left -= 1
	if pellets_left % 2 == 1:
		$Sounds/Dot_1.play()
	else:
		$Sounds/Dot_2.play()
	if pellets_left == starting_pellets - 1:
		play_appropriate_ghost_audio()
		ghosts[0].start()
		ghosts[1].start()
	if pellets_left == starting_pellets - 30:
		ghosts[2].start()
	if pellets_left == starting_pellets - 90:
		ghosts[3].start()
	if pellets_left == 0:
		level_won()


func _on_Ai_Timer_timeout():
	ghost_repath()


func _on_Scatter_Timer_timeout():
	scattering = !scattering
	if vulnearable_ghosts != 0:
		vulnearable_ghosts = 0
		play_appropriate_ghost_audio()
	if scattering:
		$Scatter_Timer.start(7)
		for ghost in ghosts:
			ghost.corner()
	else:
		$Scatter_Timer.start(20)
		for ghost in ghosts:
			ghost.chase()


func _on_ghost_ate_player(_ghost):
	if not mortal:
		return
	stop_ghost_audio()
	lives -= 1
	$UI.draw_lives(lives)
	player.die()
	for ghost in ghosts:
		ghost.reset()
	yield(get_tree().create_timer(0.10), "timeout")
	starting_pellets = pellets_left
	if lives < 0:
		$UI.game_over()
		yield(get_tree().create_timer(5.0), "timeout")
		lives = 5
		$UI.reset()
		$UI.draw_lives(lives)
		$Sounds/Intro.play()
		reset()


func toggle_debug_draw():
	for line in draw_lines:
		line.visible = !line.visible


func _on_player_ate_ghost(ghost):
	$UI.add_score(ghost_bonus)
	ghost_bonus *= 2
	var new_path := nav_2D.get_simple_path(ghost.position, Vector2(264, 140))
	draw_lines[current_ghost].points = new_path
	ghost.path = new_path
	vulnearable_ghosts -= 1
	eaten_ghosts += 1
	$Sounds/Bwahhh.play()
	play_appropriate_ghost_audio()


func _on_ghost_became_vulnerable():
	vulnearable_ghosts += 1
	play_appropriate_ghost_audio()


func _on_ghost_restored():
	eaten_ghosts -= 1
	play_appropriate_ghost_audio()


func play_appropriate_ghost_audio():
	if eaten_ghosts > 0:
		$Sounds/Ghost_wahwah.stop()
		$Sounds/Ghost_Woo.stop()
		$Sounds/Ghost_ewweww.play()
	elif vulnearable_ghosts > 0:
		$Sounds/Ghost_Woo.stop()
		$Sounds/Ghost_ewweww.stop()
		$Sounds/Ghost_wahwah.play()
	else:
		$Sounds/Ghost_ewweww.stop()
		$Sounds/Ghost_wahwah.stop()
		$Sounds/Ghost_Woo.play()


func stop_ghost_audio():
	$Sounds/Ghost_Woo.stop()
	$Sounds/Ghost_ewweww.stop()
	$Sounds/Ghost_wahwah.stop()


func _on_Intro_finished():
	player.movement_enabled = true


func _on_PacMan_player_reset():
	if lives >= 0:
		player.movement_enabled = true


func toggle_invulnerability():
	mortal = !mortal
