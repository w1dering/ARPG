extends "res://enemy/mob.gd"

# Called when the node enters the scene tree for the first time.
func _ready():
	hp = 100
	speed = 200
	damage = 10
	damageOnAttack = 20
	knockbackResistance = 10
	
	attackHitscanInstance = load("res://enemy/shadow_hitscan_attack.tscn").instantiate()
	attackPostAnimationInstance = load("res://enemy/shadow_attack_post_animation.tscn").instantiate()
	attackHitscanInstance.damage = damageOnAttack
	
	var arr = attackHitscanInstance.get_node("Hitbox").get_polygon()
	var maxes = Vector2(-1, -1)
	var mins = Vector2(9223372036854775807, 9223372036854775807)
	
	for i in arr:
		if i.x < mins.x:
			mins.x = i.x
		if i.x > maxes.x:
			maxes.x = i.x
		if i.y < mins.y:
			mins.y = i.y
		if i.y > maxes.y:
			maxes.y = i.y
	
	attackHitscanInstance.width = abs(maxes.x - mins.x)
	attackHitscanInstance.height = abs(maxes.y - mins.y)
	
	width = $Hitbox.get_shape().get_rect().size.x
	height = $Hitbox.get_shape().get_rect().size.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if isGettingKnockedBack or isAttacking:
		canMove = false
	
	if isGettingKnockedBack:
		position += knockbackVector * delta
	elif canMove:
		var pathToPlayer = player.position - position
		if !canAttack:
			move(-pathToPlayer, delta)
		else:
			if pathToPlayer.length() <= 170:
				attack(pathToPlayer)
			else:
				move(pathToPlayer, delta)

func dash(direction, delta):
	pass

