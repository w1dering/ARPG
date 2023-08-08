extends Area2D

@export var maxSpeed = 500
@export var acceleration = 4000
var currentSpeed = 0
var previousInputDir
@export var dashingSpeed = 5000
@export var hp = 100
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
var canPerfectDash = false
var dashingDir = Vector2.ZERO

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
	var isMidAction = Input.is_action_just_pressed("RMB") or Input.is_action_pressed("key_space") or isDashing
	
	# WASD movement
	if Input.is_action_pressed("key_w"):
		inputDir += Vector2.UP
	if Input.is_action_pressed("key_a"):
		inputDir += Vector2.LEFT
	if Input.is_action_pressed("key_s"):
		inputDir += Vector2.DOWN
	if Input.is_action_pressed("key_d"):
		inputDir += Vector2.RIGHT
	
	if inputDir.length() > 0:
		inputDir = inputDir.normalized()
		previousInputDir = inputDir
	
	if inputDir.length() == 0 and currentSpeed > 0:
		currentSpeed = 0
	# stops WASD movement if dashing, blocking
	if !isMidAction:
		# WASD movement
		if currentSpeed < maxSpeed and inputDir.length() != 0:
			currentSpeed += acceleration * delta
		if currentSpeed > maxSpeed:
			currentSpeed = maxSpeed
		position += inputDir * currentSpeed * delta
		
		# attacking - can hold for continuous attacks
		if Input.is_action_pressed("LMB") and canAttack:
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
	else:
		# dash
		if Input.is_action_just_pressed("RMB") and canDash:
			currentSpeed = maxSpeed
			$TimerDash.start()
			isDashing = true
			canDash = false
			isInvulnerable = true
			canPerfectDash = true
			dashingDir = Vector2.LEFT if inputDir == Vector2.ZERO else inputDir
			$TimerDashPerfect.start()
			
			if isAttacking:
				isAttacking = false
				remove_child(attackHitscanInstance)
				remove_child(attackPostAnimationInstance)
				$TimerAttackHitscan.stop()
				$TimerAttackCD.stop()
				$TimerAttackPostAnimation.stop()
		
		# block
	
	if $TimerDash.get_time_left() > 0 and isDashing:
		if inputDir != Vector2.ZERO and dashingDir != inputDir:
			dashingDir = inputDir
		# base maxSpeed of walking
		position += dashingDir * maxSpeed * delta
		# added boost due to dash
		position += dashingDir * $TimerDash.get_time_left() * dashingSpeed * delta
		currentSpeed = maxSpeed
		
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

func _on_timer_invulnerability_timeout():
	isInvulnerable = false

func reduce_hp(amount):
	if canPerfectDash:
		print("perfect dash")
		# effects of perfect dash here
	if !isInvulnerable:
		hp -= amount
		# if hp <= 0 game_over()
		
		isInvulnerable = true
		$TimerInvulnerability.start()
		# play hit and invulnerable animation

func _on_area_entered(area):
	# prevents player from taking damage from their own attack
	if area != attackHitscanInstance:
		reduce_hp(area.damage)
	# elif area == get_node() enemy attack
	#	reduce_hp(mob.damageOnAttack)


func _on_timer_dash_perfect_timeout():
	canPerfectDash = false
