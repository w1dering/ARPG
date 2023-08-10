extends Area2D

signal playerHPChanged

@export var maxSpeed = 500
@export var acceleration = 4000
var currentSpeed = 0
var directionFacing = Vector2.RIGHT
@export var dashSpeed = 5000
@export var maxHP = 100
var HP = 100
@export var damageOnAttack = 20
@export var knockbackStrength = 10

@export var spriteFrameRate = 60
@export var timerDashBaseTime = 0.25
@export var timerDashPerfectBaseTime = 0.1
@export var timerDashCDBaseTime = 0.2
@export var timerGuardPerfectBaseTime = 0.1
@export var timerAttackHitscanBaseTime = 0.05
@export var timerAttackPostAnimationBaseTime = 0.15
@export var timerAttackCDBaseTime = 0.133

var attackHitscanInstance
var attackPostAnimationInstance

var size

var boundsTopLeft
var boundsSize

var keepCentered = false

var isInvulnerable = false
var canMove = true

var isDashing = false
var canDash = true
var canDashPerfect = false
var dashDir = Vector2.ZERO
var isInSlowMo = false
var slowMoTimer: float

var isGuarding = false
var canGuard = true
var canGuardPerfect = false

var isAttacking = false
var canAttack = true

# Called when the node enters the scene tree for the first time.
func _ready():
	$TimerDash.wait_time = timerDashBaseTime
	$TimerDashPerfect.wait_time = timerDashPerfectBaseTime
	$TimerDashCD.wait_time = timerDashCDBaseTime
	$TimerGuardPerfect.wait_time = timerGuardPerfectBaseTime
	$TimerAttackHitscan.wait_time = timerAttackHitscanBaseTime
	$TimerAttackPostAnimation.wait_time = timerAttackPostAnimationBaseTime
	$TimerAttackCD.wait_time = timerAttackCDBaseTime
	
	position = get_viewport_rect().size / 2
	attackHitscanInstance = load("res://player/player_attack_hitscan.tscn").instantiate()
	attackPostAnimationInstance = load("res://player/player_attack_post_animation.tscn").instantiate()
	size = $Hitbox.get_shape().get_rect().size
	print("player size")
	print(size)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if isInSlowMo:
		# ensures player movement will always be constant during slow mo
		$TimerDash.wait_time = timerDashBaseTime * Engine.time_scale
		$TimerDashPerfect.wait_time = timerDashPerfectBaseTime * Engine.time_scale
		$TimerDashCD.wait_time = timerDashCDBaseTime * Engine.time_scale
		$TimerGuardPerfect.wait_time = timerGuardPerfectBaseTime * Engine.time_scale
		$TimerAttackHitscan.wait_time = timerAttackHitscanBaseTime * Engine.time_scale
		$TimerAttackPostAnimation.wait_time = timerAttackPostAnimationBaseTime * Engine.time_scale
		$TimerAttackCD.wait_time = timerAttackCDBaseTime * Engine.time_scale
		print($TimerAttackHitscan.wait_time)
		delta /= Engine.time_scale
		slowMoTimer += delta
		if slowMoTimer >= 1:
			Engine.time_scale = (slowMoTimer - 1) / 2 + 0.5
		if slowMoTimer >= 2:
			isInSlowMo = false
			slowMoTimer = 0
			Engine.time_scale = 1
		
	
	var inputDir = Vector2.ZERO
	
	# WASD movement
	if Input.is_action_pressed("key_w"):
		inputDir += Vector2.UP
	if Input.is_action_pressed("key_a"):
		inputDir += Vector2.LEFT
	if Input.is_action_pressed("key_s"):
		inputDir += Vector2.DOWN
	if Input.is_action_pressed("key_d"):
		inputDir += Vector2.RIGHT
	
	if inputDir.length() > 1:
		inputDir = inputDir.normalized()
	
	if inputDir.length() > 0:
		directionFacing = inputDir
	
	if inputDir.length() == 0 and currentSpeed > 0:
		currentSpeed = 0
	# stops WASD movement if dashing, blocking
	# attacking - can hold for continuous attacks
	if Input.is_action_pressed("LMB") and canAttack and !isDashing:
		$TimerAttackHitscan.start()
		isAttacking = true
		canAttack = false
		
		var mousePosition = get_global_mouse_position()
		var attackVector = mousePosition - position
		attackHitscanInstance.position = attackVector.normalized() * 50
		attackHitscanInstance.rotation = attackVector.angle() + PI / 2
		attackHitscanInstance.show()
		add_child(attackHitscanInstance)
		# play swing animation when done
		
		if isGuarding:
			isGuarding = false
			canGuardPerfect = false
			$TimerGuardPerfect.stop()
			canMove = true
	# second statement allows basically buffering a guard
	elif (Input.is_action_just_pressed("key_space") and canGuard) or (Input.is_action_pressed("key_space") and canGuard and !isGuarding):
		isGuarding = true
		canGuardPerfect = true
		$TimerGuardPerfect.start()
		canMove = false
		currentSpeed = 0
		
		if isAttacking:
			isAttacking = false
			
			if $TimerAttackHitscan.time_left > 0:
				remove_child(attackHitscanInstance)
			if $TimerAttackPostAnimation.time_left > 0:
				remove_child(attackPostAnimationInstance)
			
			$TimerAttackHitscan.stop()
			$TimerAttackCD.stop()
			$TimerAttackPostAnimation.stop()
	elif Input.is_action_just_released("key_space"):
		isGuarding = false
		canMove = true
		canAttack = true
	elif Input.is_action_just_pressed("RMB") and canDash:
		currentSpeed = maxSpeed
		$TimerDash.start()
		isDashing = true
		canDash = false
		canDashPerfect = true
		dashDir = -directionFacing if inputDir == Vector2.ZERO else inputDir
		$TimerDashPerfect.start()
		
		# dash-cancelling an attack
		if isAttacking:
			isAttacking = false
			
			if $TimerAttackHitscan.time_left > 0:
				remove_child(attackHitscanInstance)
			if $TimerAttackPostAnimation.time_left > 0:
				remove_child(attackPostAnimationInstance)
			
			$TimerAttackHitscan.stop()
			$TimerAttackCD.stop()
			$TimerAttackPostAnimation.stop()
		
		# dash-cancelling a guard
		if isGuarding:
			isGuarding = false
			canMove = true
			canGuardPerfect = false
			$TimerGuardPerfect.stop()
	elif $TimerDash.get_time_left() > 0 and isDashing:
		if inputDir != Vector2.ZERO and dashDir != inputDir:
			dashDir = inputDir
		# base maxSpeed of walking
		move(dashDir, maxSpeed, delta)
		# added boost due to dash
		move(dashDir, dashSpeed * $TimerDash.time_left / timerDashBaseTime, delta if !isInSlowMo else delta * 2)
		currentSpeed = maxSpeed
	elif canMove and !isGuarding:
		if currentSpeed < maxSpeed and inputDir.length() != 0:
			currentSpeed += acceleration * delta
			if currentSpeed > maxSpeed:
				currentSpeed = maxSpeed
			
		move(inputDir, currentSpeed, delta)
	
	position.x = clamp(position.x, boundsTopLeft.x + size.x / 2, boundsTopLeft.x + boundsSize.x - size.x / 2)
	position.y = clamp(position.y, boundsTopLeft.y + size.y / 2, boundsTopLeft.y + boundsSize.y - size.y / 2)

func _on_timer_dash_timeout():
	$TimerDashCD.start()
	isDashing = false
	canAttack = true


func _on_timer_dash_cd_timeout():
	canDash = true


func _on_timer_attack_hitscan_timeout():
	$TimerAttackPostAnimation.start()
	attackPostAnimationInstance.position = attackHitscanInstance.position
	attackPostAnimationInstance.rotation = attackHitscanInstance.rotation
	attackPostAnimationInstance.show()
	add_child(attackPostAnimationInstance)
	
	remove_child(attackHitscanInstance)
	
func _on_timer_attack_post_animation_timeout():
	$TimerAttackCD.start()
	remove_child(attackPostAnimationInstance)
	isAttacking = false

func _on_timer_attack_cd_timeout():
	canAttack = true

func _on_area_entered(area):
	# prevents player from taking damage from their own attack
	if area != attackHitscanInstance:
		reduce_HP(area.damage)
	# elif area == get_node() enemy attack
	#	reduce_HP(mob.damageOnAttack)

func move(direction, speed, delta):
	position += direction.normalized() * speed * delta

func reduce_HP(amount):
	if !isInvulnerable:
		if canDashPerfect:
			print("perfect dash")
			Engine.time_scale = 0.5
			isInSlowMo = true
			# effects of perfect dash here
		elif canGuardPerfect:
			print("parried")
		elif isGuarding:
			print("guarded")
		else:
			print("hit")
			HP -= amount
			playerHPChanged.emit(HP)
			# if HP <= 0 game_over()
			make_invulnerable(2.0)
			# play hit and invulnerable animation

func _on_timer_dash_perfect_timeout():
	canDashPerfect = false

func _on_timer_guard_perfect_timeout():
	canGuardPerfect = false

func make_invulnerable(time):
	$TimerInvulnerability.wait_time = time
	$TimerInvulnerability.start()
	isInvulnerable = true

func _on_timer_invulnerability_timeout():
	isInvulnerable = false
