extends Area2D

signal playerHPChanged
signal hitStop
signal shakeScreen
signal cameraPosition

@export var maxSpeed: int = 500
@export var acceleration: int = 4000
var currentSpeed: int = 0
var directionFacing: Vector2 = Vector2.RIGHT
@export var dashSpeed: int = 5000
@export var maxHP: int = 100
var HP: int = 100

@export var timerCameraOffset = 0.05

# skills
@export var damageOnAttack: int = 20
@export var knockbackAmountOnAttack: int = 10
@export var hitStopTimeOnAttack: float = 0.1
@export var screenShakeAmountOnAttack: int = 3 # duration of screen shake is equal to duration of hit stop

var isAttacking: bool = false
var canAttack: bool = true

@export var damageOnCleave: int = 40
@export var knockbackAmountOnCleave: int = 20

var isUsingCleave: bool = false
var canCleave: bool = true

@export var spriteFrameRate: int = 60
@onready var timerDash = $TimerHolder/TimerDash
@onready var timerDashPerfect = $TimerHolder/TimerDashPerfect
@onready var timerDashCD = $TimerHolder/TimerDashCD
@onready var timerGuardPerfect = $TimerHolder/TimerGuardPerfect
@onready var timerGuardCD = $TimerHolder/TimerGuardCD
@export var timerGuardCDBaseTime = 0.5
@onready var timerAttackHitscan = $TimerHolder/TimerAttackHitscan
@onready var timerAttackLinger = $TimerHolder/TimerAttackLinger
@onready var timerAttackCD = $TimerHolder/TimerAttackCD
@onready var timerInvulnerability = $TimerHolder/TimerInvulnerability
@onready var timerSlowMo = $TimerHolder/TimerSlowMo

var attackHitscanInstance: Node2D
var attackLingerInstance: Node2D

var size: Vector2

var boundsTopLeft: Vector2
var boundsSize: Vector2

var keepCentered: bool = false

var isInvulnerable: bool = false
var canMove: bool = true

var isDashing: bool = false
var canDash: bool = true
var canDashPerfect: bool = false
var currentDashDir: Vector2 = Vector2.ZERO

var isInSlowMo: bool = false
@export var slowMoMultiplier: float = 0.25

var isGuarding: bool = false
var canGuard: bool = true
var canGuardPerfect: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	
	position = Vector2(800, 800)
	
	attackHitscanInstance = load("res://player/player_attack_hitscan.tscn").instantiate()
	attackHitscanInstance.z_index = 100
	attackHitscanInstance.damage = damageOnAttack
	attackHitscanInstance.knockbackAmount = knockbackAmountOnAttack
	attackHitscanInstance.hitStopTime = hitStopTimeOnAttack
	attackHitscanInstance.screenShakeAmount = screenShakeAmountOnAttack
	
	attackLingerInstance = load("res://player/player_attack_linger.tscn").instantiate()
	attackLingerInstance.z_index = 100
	size = $Hitbox.get_shape().get_rect().size

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
		if !isDashing and abs(directionFacing.angle_to(inputDir)) > PI / 2 + 0.1:
			currentSpeed = 0
		directionFacing = inputDir
	
	if inputDir.length() == 0 and currentSpeed > 0:
		currentSpeed = 0
	# stops WASD movement if dashing, blocking
	# attacking - can hold for continuous attacks
	if Input.is_action_pressed("LMB"):
		if canAttack and !isDashing:
			start_attack()
			# play swing animation when done
			
			# if a guard is attack-cancelled, the cooldown of the guard will shorten afterwards
			if isGuarding:
				timerGuardCD.wait_time = timerAttackHitscan.wait_time + timerAttackLinger.wait_time
				cancel_guard()
	# second statement allows basically buffering a guard
	if (Input.is_action_pressed("key_space") and canGuard) or (Input.is_action_pressed("key_space") and canGuard and !isGuarding and !isAttacking):
		start_guard()
		cancel_attack()
	if isGuarding and !Input.is_action_pressed("key_space"):
		cancel_guard()
	if Input.is_action_just_pressed("RMB") and canDash:
		start_dash(inputDir)
		
		# dash-cancelling an attack
		cancel_attack()
		
		# dash-cancelling a guard
		if isGuarding:
			timerGuardCD.wait_time = timerDash.wait_time
			cancel_guard()
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
	
	if canMove and !isGuarding and !isDashing:
		if currentSpeed < maxSpeed and inputDir.length() != 0:
			currentSpeed += acceleration * delta
			if currentSpeed > maxSpeed:
				currentSpeed = maxSpeed
			
		move(inputDir, currentSpeed, delta)
	
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
		canGuard = false
		isGuarding = true
		canGuardPerfect = true
		timerGuardPerfect.start()
		canMove = false
		currentSpeed = 0

func cancel_guard():
	if isGuarding:
		canGuard = false
		isGuarding = false
		canGuardPerfect = false
		timerGuardPerfect.stop()
		timerGuardCD.start()
		canMove = true

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
	timerAttackCD.start()
	remove_child(attackLingerInstance)
	isAttacking = false

func _on_timer_attack_cd_timeout():
	canAttack = true

func _on_area_entered(area):
	# prevents player from taking damage from their own attack or when invulnerable
	if area != attackHitscanInstance and !isInvulnerable:
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



