extends Area2D

signal playerHPChanged

@export var maxSpeed = 500
@export var acceleration = 4000
var currentSpeed = 0
var directionFacing = Vector2.RIGHT
@export var dashingSpeed = 5000
@export var maxHP = 100
var HP = 100
@export var damageOnAttack = 20
@export var knockbackStrength = 10

var bufferedInputs: Array # will have 5 (or 10) slots of inputs that are buffered

var attackHitscanInstance
var attackPostAnimationInstance

var width
var height

var keepCentered = false

var isInvulnerable = false
var canMove = true

var isDashing = false
var canDash = true
var canDashPerfect = false
var dashingDir = Vector2.ZERO

var isGuarding = false
var canGuard = true
var canGuardPerfect = false

var isAttacking = false
var canAttack = true

# Called when the node enters the scene tree for the first time.
func _ready():
	position = get_viewport_rect().size / 2
	attackHitscanInstance = load("res://player/player_attack_hitscan.tscn").instantiate()
	attackPostAnimationInstance = load("res://player/player_attack_post_animation.tscn").instantiate()
	width = $"Hitbox".get_shape().get_rect().size.x
	height = $"Hitbox".get_shape().get_rect().size.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
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
		
		var mousePosition = get_viewport().get_mouse_position()
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
		dashingDir = -directionFacing if inputDir == Vector2.ZERO else inputDir
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
		if inputDir != Vector2.ZERO and dashingDir != inputDir:
			dashingDir = inputDir
		# base maxSpeed of walking
		position += dashingDir * maxSpeed * delta
		# added boost due to dash
		position += dashingDir * $TimerDash.get_time_left() * dashingSpeed * delta
		currentSpeed = maxSpeed
	elif canMove and !isGuarding:
		if currentSpeed < maxSpeed and inputDir.length() != 0:
			currentSpeed += acceleration * delta
			if currentSpeed > maxSpeed:
				currentSpeed = maxSpeed
			
		position += inputDir * currentSpeed * delta
	
	position.x = clamp(position.x, 0, get_viewport_rect().size.x)
	position.y = clamp(position.y, 0, get_viewport_rect().size.y)

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

func reduce_HP(amount):
	if !isInvulnerable:
		if canDashPerfect:
			print("perfect dash")
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
