extends Node2D

@export var mobScene: PackedScene = preload("enemy/mob.tscn")
@export var shadowScene: PackedScene = preload("enemy/shadow.tscn")

var levelTopLeft: Vector2
var levelSize: Vector2

@onready var player = $Player

func _ready():
	levelTopLeft = $TextureRect.position
	levelSize = $TextureRect.size
	$HUD.player = player
	
	player.connect("playerHPChanged", player_HP_change)
	player.connect("hitStop", hit_stop)
	player.connect("shakeScreen", shake_screen)
	player.connect("cameraPosition", update_camera_position)

	player.boundsTopLeft = levelTopLeft
	player.boundsSize = levelSize
	
	
	$HUD.change_player_health_bar(100)

func _process(delta):
	if player.isInSlowMo:
		if player.slowMoTimer < 0.10:
			$PlayerCamera.zoom = Vector2(1 + player.slowMoTimer * 2.5, 1 + player.slowMoTimer * 2.5)
		elif player.slowMoTimer < 1:
			$PlayerCamera.zoom = Vector2(1.25, 1.25)
		else:
			$PlayerCamera.zoom = Vector2(1.25 - (player.slowMoTimer - 1) / 4, 1.25 - (player.slowMoTimer - 1) / 4)

func _on_timer_mob_spawn_timeout():
	var shadow = mobScene.instantiate().spawn_mob("shadow")
	shadow.position.x = 1200
	shadow.position.y = 450
	shadow.player = player
	shadow.connect("hitStop", hit_stop)
	shadow.connect("shakeScreen", shake_screen)
	$ShadowSpawner.add_child(shadow)

func player_HP_change(amount):
	$HUD.change_player_health_bar(amount)

func hit_stop(time):
	$HitStop.wait_time = time * Engine.time_scale
	$HitStop.start()
	get_tree().paused = true

func _on_hit_stop_timeout():
	get_tree().paused = false

func shake_screen(time, amount):
	$PlayerCamera.shake(time, amount)

func update_camera_position(pos):
	$CameraTarget.position = pos
