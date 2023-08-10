extends Node2D

@export var mobScene: PackedScene = preload("enemy/mob.tscn")
@export var shadowScene: PackedScene = preload("enemy/shadow.tscn")

var levelTopLeft: Vector2
var levelSize: Vector2

func _ready():
	levelTopLeft = $TextureRect.position
	levelSize = $TextureRect.size
	$HUD.player = $Player
	$Player.connect("playerHPChanged", player_HP_change)
	$HUD.change_player_health_bar(100)
	$Player.boundsTopLeft = levelTopLeft
	$Player.boundsSize = levelSize
	$Player/CameraTarget.remote_path = "/root/Level1/LevelCamera"

func _process(delta):
	if $Player.isInSlowMo:
		if $Player.slowMoTimer < 0.10:
			$LevelCamera.zoom = Vector2(1 + $Player.slowMoTimer * 2.5, 1 + $Player.slowMoTimer * 2.5)
		elif $Player.slowMoTimer < 1:
			$LevelCamera.zoom = Vector2(1.25, 1.25)
		else:
			$LevelCamera.zoom = Vector2(1.25 - ($Player.slowMoTimer - 1) / 4, 1.25 - ($Player.slowMoTimer - 1) / 4)

func _on_mob_spawn_timer_timeout():
	var shadow = mobScene.instantiate().spawn_mob("shadow")
	shadow.position.x = 1200
	shadow.position.y = 450
	shadow.player = $Player
	add_child(shadow)

func player_HP_change(amount):
	$HUD.change_player_health_bar(amount)
