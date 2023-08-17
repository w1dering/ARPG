extends Area2D

signal playerHPChanged
signal hitStop
signal shakeScreen
signal cameraPosition

@export var maxSpeed: int = 500
@export var acceleration: int = 2000
var currentSpeed: int = 0
var maxSpeedMulti: float = 1
var directionFacing: Vector2 = Vector2.RIGHT
@export var dashSpeed: int = 5000
@export var maxHP: int = 100
var HP: int = 100

@export var spriteFrameRate: int = 60
@onready var timerDash = $TimersBasic/TimerDash
@onready var timerDashPerfect = $TimersBasic/TimerDashPerfect
@onready var timerDashCD = $TimersBasic/TimerDashCD
@onready var timerGuardPerfect = $TimersBasic/TimerGuardPerfect
@onready var timerGuardCD = $TimersBasic/TimerGuardCD
@export var timerGuardCDBaseTime = 0.5
@onready var timerInvulnerability = $TimersBasic/TimerInvulnerability
@onready var timerSlowMo = $TimersBasic/TimerSlowMo

@onready var timerAttackHitscan = $TimersAttack/TimerAttackHitscan
@onready var timerAttackLinger = $TimersAttack/TimerAttackLinger
@onready var timerAttackCD = $TimersAttack/TimerAttackCD

@onready var timerSkill0Charge = $TimersSkill0/TimerSkill0Charge
@onready var timerSkill0BuildUp = $TimersSkill0/TimerSkill0BuildUp
@onready var timerSkill0Hitscan = $TimersSkill0/TimerSkill0Hitscan
@onready var timerSkill0Linger = $TimersSkill0/TimerSkill0Linger
@onready var timerSkill0CD = $TimersSkill0/TimerSkill0CD
@export var timerCameraOffset = 0.05

var attackHitscanInstance: Node2D
var attackLingerInstance: Node2D

var size: Vector2

var boundsTopLeft: Vector2
var boundsSize: Vector2

# skills
@export var attackDamage: int = 20
@export var attackKnockback: int = 10
@export var attackHitStop: float = 0.1
@export var attackScreenShakeAmount: int = 3 # duration of screen shake is equal to duration of hit stop
var isAttacking: bool = false
var canAttack: bool = true
var keyAttack = "LMB"

@export var skill0Damage: int = 40
@export var skill0Knockback: int = 20
@export var skill0HitStop: float = 0.25
@export var skill0ScreenShakeAmount: int = 8
var canChargeSkill0: bool = true
var isChargingSkill0: bool = false
var canUseSkill0: bool = false
var isUsingSkill0: bool = false
var keySkill0 = "key_1"

var skill0HitscanInstance: Node2D
var skill0LingerInstance: Node2D

var isInvulnerable: bool = false

var canMove: bool = true
var keyW = "key_w"
var keyA = "key_a"
var keyS = "key_s"
var keyD = "key_d"

var isDashing: bool = false
var canDash: bool = true
var canDashPerfect: bool = false
var currentDashDir: Vector2 = Vector2.ZERO
var keyDash = "RMB"

var isGuarding: bool = false
var canGuard: bool = true
var canGuardPerfect: bool = false
var keyGuard = "key_space"

var isInSlowMo: bool = false
@export var slowMoMultiplier: float = 0.25

# Called when the node enters the scene tree for the first time.
func _ready():
	
	position = Vector2(800, 800)
	
	attackHitscanInstance = load("res://player/player_attack_hitscan.tscn").instantiate()
	attackHitscanInstance.z_index = 100
	attackHitscanInstance.damage = attackDamage
	attackHitscanInstance.knockbackAmount = attackKnockback
	attackHitscanInstance.hitStopTime = attackHitStop
	attackHitscanInstance.screenShakeAmount = attackScreenShakeAmount
	
	attackLingerInstance = load("res://player/player_attack_linger.tscn").instantiate()
	attackLingerInstance.z_index = 100
	
	skill0HitscanInstance = load("res://player/player_skill_0_hitscan.tscn").instantiate()
	skill0HitscanInstance.z_index = 100
	skill0HitscanInstance.damage = skill0Damage
	skill0HitscanInstance.knockbackAmount = skill0Knockback
	skill0HitscanInstance.hitStopTime = skill0HitStop
	skill0HitscanInstance.screenShakeAmount = skill0ScreenShakeAmount
	
	skill0LingerInstance = load("res://player/player_skill_0_linger.tscn").instantiate()
	skill0LingerInstance.z_index = 100
	
	size = $Hitbox.get_shape().get_rect().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var inputDir = Vector2.ZERO
	
	# WASD movement
	if Input.is_action_pressed(keyW):
		inputDir += Vector2.UP
	if Input.is_action_pressed(keyA):
		inputDir += Vector2.LEFT
	if Input.is_action_pressed(keyS):
		inputDir += Vector2.DOWN
	if Input.is_action_pressed(keyD):
		inputDir += Vector2.RIGHT
	
	if inputDir.length() > 1:
		inputDir = inputDir.normalized()
	
	if inputDir.length() > 0 and !isDashing:
		if abs(directionFacing.angle_to(inputDir)) > PI / 2 + 0.1:
			currentSpeed = 0
		directionFacing = inputDir
	
	if inputDir.length() == 0 and currentSpeed > 0:
		currentSpeed = 0
	# stops WASD movement if dashing, blocking
	# attacking - can hold for continuous attacks
	if Input.is_action_pressed(keyAttack):
		if canAttack and !isDashing:
			start_attack()
			# play swing animation when done
			
			# if a guard is attack-cancelled, the cooldown of the guard will shorten afterwards
			if isGuarding:
				timerGuardCD.wait_time = timerAttackHitscan.wait_time + timerAttackLinger.wait_time
				cancel_guard()
				maxSpeedMulti = 0.5
		if isChargingSkill0:
			cancel_skill_0()
	# second statement allows basically buffering a guard
	if (Input.is_action_pressed(keyGuard) and canGuard) or (Input.is_action_pressed(keyGuard) and canGuard and !isGuarding and !isAttacking):
		start_guard()
		if isAttacking:
			cancel_attack()
		if isChargingSkill0 or isUsingSkill0:
			cancel_skill_0()
	if isGuarding and !Input.is_action_pressed(keyGuard):
		cancel_guard()
	if Input.is_action_just_pressed(keyDash) and canDash:
		start_dash(inputDir)
		
		# dash-cancelling an attack
		cancel_attack()
		
		# dash-cancelling a guard
		if isGuarding:
			timerGuardCD.wait_time = timerDash.wait_time
			cancel_guard()
		if isChargingSkill0 or isUsingSkill0:
			cancel_skill_0()
	if timerDash.get_time_left() > 0 and isDashing:
		if inputDir != Vector2.ZERO and abs(currentDashDir.angle_to(inputDir)) <= PI / 2 + 0.2:
			# +0.2 is there for insurance bc angles that are exactly PI/2 might get rounded down 
			currentDashDir = inputDir
			directionFacing = inputDir
		# base maxSpeed of walking
		move(currentDashDir, maxSpeed, delta)
		# added boost due to dash
		move(currentDashDir, dashSpeed * timerDash.time_left / timerDash.wait_time, delta)
		currentSpeed = maxSpeed
	
	if canMove and !isDashing:
		if currentSpeed < maxSpeed * maxSpeedMulti and inputDir.length() != 0:
			currentSpeed += acceleration * delta
		if currentSpeed > maxSpeed * maxSpeedMulti:
			currentSpeed = maxSpeed * maxSpeedMulti
			
		move(inputDir, currentSpeed, delta)
	
	if Input.is_action_just_pressed(keySkill0) and canMove and !isDashing:
		if canChargeSkill0:
			charge_skill_0()
		elif isChargingSkill0:
			cancel_skill_0()
		elif canUseSkill0:
			start_skill_0()
	
	position.x = clamp(position.x, boundsTopLeft.x + size.x / 2, boundsTopLeft.x + boundsSize.x - size.x / 2)
	position.y = clamp(position.y, boundsTopLeft.y + size.y / 2, boundsTopLeft.y + boundsSize.y - size.y / 2)
	
	send_camera_position(position)
	if isInSlowMo:
		isInvulnerable = true

func start_attack():
	if canAttack:
		timerAttackHitscan.start()
		isAttacking = true
		canAttack = false
		
		var mousePosition = get_global_mouse_position()
		var attackVector = mousePosition - position
		attackHitscanInstance.position = attackVector.normalized() * 50
		attackHitscanInstance.rotation = attackVector.angle() + PI / 2
		attackHitscanInstance.show()
		add_child(attackHitscanInstance)

func cancel_attack():
	if isAttacking:
		isAttacking = false
		if timerAttackHitscan.time_left > 0:
			remove_child(attackHitscanInstance)
			timerAttackHitscan.stop()
		if timerAttackLinger.time_left > 0:
			remove_child(attackLingerInstance)
			timerAttackLinger.stop()
		timerAttackCD.stop()
		timerAttackCD.start()

func start_dash(inputDir):
	if canDash:
		currentSpeed = maxSpeed
		isDashing = true
		canDash = false
		canDashPerfect = true
		timerDash.start()
		timerDashPerfect.start()
		currentDashDir = -directionFacing if inputDir == Vector2.ZERO else inputDir

func cancel_dash():
	if isDashing:
		isDashing = false
		canDashPerfect = false
		canDash = false
		timerDash.stop()
		timerDashPerfect.stop()
		timerDashCD.start()
		currentDashDir = Vector2.ZERO

func start_guard():
	if canGuard:
		maxSpeedMulti = 0.5
		canGuard = false
		isGuarding = true
		canGuardPerfect = true
		timerGuardPerfect.start()

func cancel_guard():
	if isGuarding:
		maxSpeedMulti = 1
		canGuard = false
		isGuarding = false
		canGuardPerfect = false
		timerGuardPerfect.stop()
		timerGuardCD.start()

func charge_skill_0():
	if canChargeSkill0:
		timerSkill0Charge.start()
		isChargingSkill0 = true
		canChargeSkill0 = false
		maxSpeedMulti = 0.5

func _on_timer_skill_0_charge_timeout():
	maxSpeedMulti = 1
	canUseSkill0 = true
	canChargeSkill0 = false
	isChargingSkill0 = false

func start_skill_0():
	canMove = false
	canUseSkill0 = true
	isUsingSkill0 = true
	canChargeSkill0 = false
	isChargingSkill0 = false
	timerSkill0BuildUp.start()

func _on_timer_skill_0_build_up_timeout():
	if canUseSkill0:
		canMove = true
		timerSkill0Hitscan.start()
		var mousePosition = get_global_mouse_position()
		var attackVector = mousePosition - position
		skill0HitscanInstance.position = attackVector.normalized() * 150
		skill0HitscanInstance.rotation = attackVector.angle() + PI / 2
		skill0HitscanInstance.show()
		add_child(skill0HitscanInstance)

func _on_timer_skill_0_hitscan_timeout():
	timerSkill0Linger.start()
	skill0LingerInstance.position = skill0HitscanInstance.position
	skill0LingerInstance.rotation = skill0HitscanInstance.rotation
	skill0LingerInstance.show()
	add_child(skill0LingerInstance)
	
	remove_child(skill0HitscanInstance)

func _on_timer_skill_0_linger_timeout():
	remove_child(skill0LingerInstance)
	cancel_skill_0()

func _on_timer_skill_0_cd_timeout():
	canChargeSkill0 = true

func cancel_skill_0():
	maxSpeedMulti = 1
	
	canChargeSkill0 = false
	canUseSkill0 = false
	isChargingSkill0 = false
	isUsingSkill0 = false
	
	if timerSkill0Hitscan.time_left > 0:
		remove_child(skill0HitscanInstance)
	if timerSkill0Linger.time_left > 0:
		remove_child(skill0LingerInstance)
	
	timerSkill0Charge.stop()
	timerSkill0BuildUp.stop()
	timerSkill0Hitscan.stop()
	timerSkill0Linger.stop()
	timerSkill0CD.stop()
	
	timerSkill0CD.start()

func _on_timer_dash_timeout():
	timerDashCD.start()
	isDashing = false
	canAttack = true


func _on_timer_dash_cd_timeout():
	canDash = true


func _on_timer_attack_hitscan_timeout():
	timerAttackLinger.start()
	attackLingerInstance.position = attackHitscanInstance.position
	attackLingerInstance.rotation = attackHitscanInstance.rotation
	attackLingerInstance.show()
	add_child(attackLingerInstance)
	
	remove_child(attackHitscanInstance)
	
func _on_timer_attack_linger_timeout():
	cancel_attack()
	remove_child(attackLingerInstance)

func _on_timer_attack_cd_timeout():
	canAttack = true

func _on_area_entered(area):
	var isOwnAttack = area == attackHitscanInstance or area == skill0HitscanInstance
	# prevents player from taking damage from their own attack or when invulnerable
	if !isOwnAttack and !isInvulnerable:
		# third condition checks if instance is a mob (which would have area entered) or an attack instance (which would
		# not have area entered method, as that is handled in the mob script)
		if canDashPerfect and !isInSlowMo:
			if !area.has_method("_on_area_entered"):
				print("perfect dash")
				isInSlowMo = true
				isInvulnerable = true
				timerSlowMo.start()
		elif canGuardPerfect:
			print("parried")
			area.was_parried()
		elif isGuarding:
			print("guarded")
			hitStop.emit(0.1)
			shakeScreen.emit(0.1, 3)
			HP -= area.damage / 2
			playerHPChanged.emit(HP)
			make_invulnerable(1.0)
		else:
			print("hit")
			hitStop.emit(0.3)
			shakeScreen.emit(0.3, 10)
			HP -= area.damage
			playerHPChanged.emit(HP)
			# if HP <= 0 game_over()
			make_invulnerable(2.0)
			# play hit and invulnerable animation

func move(direction, speed, delta):
	position += direction.normalized() * speed * delta

func _on_timer_dash_perfect_timeout():
	canDashPerfect = false
	if timerDash.time_left > 0:
		make_invulnerable(timerDash.time_left)

func _on_timer_guard_perfect_timeout():
	canGuardPerfect = false

func make_invulnerable(time):
	timerInvulnerability.wait_time = time
	timerInvulnerability.start()
	isInvulnerable = true

func _on_timer_invulnerability_timeout():
	isInvulnerable = false

func _on_timer_guard_cd_timeout():
	canGuard = true
	if timerGuardCD.wait_time != timerGuardCDBaseTime:
		timerGuardCD.wait_time = timerGuardCDBaseTime

func send_camera_position(pos):
	await get_tree().create_timer(timerCameraOffset).timeout
	cameraPosition.emit(pos)

func get_time_scale() -> float:
	var t = timerSlowMo.time_left
	if t == 0:
		return 1.0
	if timerSlowMo.wait_time - t <= 0.1:
		return 1.0 - (timerSlowMo.wait_time - t) * 7.5
	if t <= 1:
		return 0.25 + 0.75 * (1 - t)
	else:
		return slowMoMultiplier

func _on_timer_slow_mo_timeout():
	isInSlowMo = false
	isInvulnerable = false
