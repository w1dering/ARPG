extends "res://enemy/mob.gd"

@onready var timerDash = $TimerHolder/TimerDash
@export var timerDashBaseTime = 0.25

var canDash = true
var isDashing = false
var dashingDir = Vector2.ZERO
var dashSpeed = 1000

# Called when the node enters the scene tree for the first time.
func extra_ready():
	hp = 100
	speed = 200
	damage = 10
	damageOnAttack = 20
	knockbackResistance = 10
	
	attackHitscanInstance = load("res://enemy/shadow_hitscan_attack.tscn").instantiate()
	attackLingerInstance = load("res://enemy/shadow_attack_linger.tscn").instantiate()
	
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
	
	attackHitscanInstance.damage = damageOnAttack
	
	attackHitscanInstance.z_index = 100
	attackLingerInstance.z_index = 100
	
	attackHitscanInstance.connect("wasParried", was_parried)
	
	attackHitscanInstance.size = Vector2(abs(maxes.x - mins.x), abs(maxes.y - mins.y))
	
	size = $Hitbox.get_shape().get_rect().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player.isInSlowMo:
		var time_scale = player.get_time_scale()
		timerAttackHitscan.wait_time = timerAttackHitscanBaseTime / time_scale
		timerAttackLinger.wait_time = timerAttackLingerBaseTime / time_scale
		timerAttackCD.wait_time = timerAttackCDBaseTime / time_scale
		# invulnerability timer stays the same, even tho technically they're always invulnerable
		timerParryStun.wait_time = timerParryStunBaseTime / time_scale
		timerDash.wait_time = timerDashBaseTime / time_scale
		delta *= time_scale
	
	if isGettingKnockedBack or isAttacking:
		canMove = false
	
	if isGettingKnockedBack:
		position += knockbackVector * delta
	elif isDashing:
		position += dashingDir * (timerDash.time_left / timerDash.wait_time) * dashSpeed * delta
	elif canMove:
		var pathToPlayer = player.position - position
		if pathToPlayer.length() <= 170:
			if canAttack:
				start_attack(pathToPlayer)
			else:
				if canDash:
					canDash = false
					isDashing = true
					dashingDir = -pathToPlayer.normalized()
					timerDash.start()
					make_invulnerable(timerDash.wait_time)
				else:
					move(-pathToPlayer, delta)
		else:
			if canAttack:
				move(pathToPlayer, delta)
			else:
				# incorporate side to side movement
				pass
		
		if player.isInSlowMo:
			isInvulnerable = false
			# overrides any other changes to isInvulnerable

func _on_timer_dash_timeout():
	isDashing = false
	dashingDir = Vector2.ZERO

func _on_timer_attack_cd_timeout():
	canAttack = true
	canDash = true
