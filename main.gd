extends Node2D

@export var mobScene: PackedScene = preload("enemy/mob.tscn")
@export var shadowScene: PackedScene = preload("enemy/shadow.tscn")

var screenSize

func _ready():
	screenSize = get_viewport_rect().size
	$HUD.player = $Player
	$Player.connect("playerHPChanged", player_HP_change)
	$HUD.change_player_health_bar(100)

func _process(delta):
	pass

func _on_mob_spawn_timer_timeout():
	var shadow = mobScene.instantiate().spawn_mob("shadow")
	shadow.position.x = screenSize.x * 3 / 4
	shadow.position.y = screenSize.y / 2
	shadow.player = $Player
	add_child(shadow)

func player_HP_change(amount):
	$HUD.change_player_health_bar(amount)
