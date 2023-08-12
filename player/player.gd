extends Area2D

signal playerHPChanged
signal hitStop
signal shakeScreen

@export var maxSpeed: int = 500
@export var acceleration: int = 4000
var currentSpeed: int = 0
var directionFacing: Vector2 = Vector2.RIGHT
@export var dashSpeed: int = 5000
@export var maxHP: int = 100
var HP: int = 100

# skills
@export var damageOnAttack: int = 20
@export var knockbackAmountOnAttack: int = 10
@export var hitStopTimeOnAttack: float = 0.1
@export var screenShakeAmountOnAttack: int = 3 # duration of screen shake is equal to duration of hit stop

var isAttacking: bool = false
var canAttack: bool = true

@export var damageOnCleave: int = 40
@export var knockbackAmountOnCleave: int = 20

var isCleaving: bool = false
var canCleave: bool = true

@export var spriteFrameRate: int = 60

@onready var timerDash = $TimerHolder/TimerDash
@export var timerDashBaseTime: float = 0.25

@onready var timerDashPerfect = $TimerHolder/TimerDashPerfect
@export var timerDashPerfectBaseTime: float = 0.1

@onready var timerDashCD = $TimerHolder/TimerDashCD
@export var timerDashCDBaseTime: float = 0.2

@onready var timerGuardPerfect = $TimerHolder/TimerGuardPerfect
@export var timerGuardPerfectBaseTime: float = 0.1

@onready var timerGuardCD = $TimerHolder/TimerGuardCD
@export var timerGuardCDBaseTime: float = 0.5

@onready var timerAttackHitscan = $TimerHolder/TimerAttackHitscan
@export var timerAttackHitscanBaseTime: float = 0.05

@onready var timerAttackPostAnimation = $TimerHolder/TimerAttackPostAnimation
@export var timerAttackPostAnimationBaseTime: float = 0.15

@onready var timerAttackCD = $TimerHolder/TimerAttackCD
@export var timerAttackCDBaseTime: float = 0.133

@onready var timerInvulnerability = $TimerHolder/TimerInvulnerability

var attackHitscanInstance: Node2D
var attackPostAnimationInstance: Node2D

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
var slowMoTimer: float

var isGuarding: bool = false
var canGuard: bool = true
var canGuardPerfect: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	timerDash.wait_time = timerDashBaseTime
	timerDashPerfect.wait_time = timerDashPerfectBaseTime
	timerDashCD.wait_time = timerDashCDBaseTime
	timerGuardPerfect.wait_time = timerGuardPerfectBaseTime
	timerGuardCD.wait_time = timerGuardCDBaseTime
	timerAttackHitscan.wait_time = timerAttackHitscanBaseTime
	timerAttackPostAnimation.wait_time = timerAttackPostAnimationBaseTime
	timerAttackCD.wait_time = timerAttackCDBaseTime
	
	position = Vector2(800, 800)
	
	attackHitscanInstance = load("res://player/player_attack_hitscan.tscn").instantiate()
	attackHitscanInstance.z_index = 100
	attackHitscanInstance.damage = damageOnAttack
	attackHitscanInstance.knockbackAmount = knockbackAmountOnAttack
	attackHitscanInstance.hitStopTime = hitStopTimeOnAttack
	attackHitscanInstance.screenShakeAmount = screenShakeAmountOnAttack
	
	attackPostAnimationInstance = load("res://player/player_attack_post_animation.tscn").instantiate()
	attackPostAnimationInstance.z_index = 100
	size = $Hitbox.get_shape().get_rect().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if isInSlowMo:
		isInvulnerable = true
		# ensures player movement will always be constant during slow mo
		timerDash.wait_time = timerDashBaseTime * Engine.time_scale
		timerDashPerfect.wait_time = timerDashPerfectBaseTime * Engine.time_scale
		timerDashCD.wait_time = timerDashCDBaseTime * Engine.time_scale
		timerGuardPerfect.wait_time = timerGuardPerfectBaseTime * Engine.time_scale
		timerGuardCD.wait_time = timerGuardCDBaseTime * Engine.time_scale
		timerAttackHitscan.wait_time = timerAttackHitscanBaseTime * Engine.time_scale
		timerAttackPostAnimation.wait_time = timerAttackPostAnimationBaseTime * Engine.time_scale
		timerAttackCD.wait_time = timerAttackCDBaseTime * Engine.time_scale
		delta /= Engine.time_scale
		slowMoTimer += delta
		if slowMoTimer >= 1:
			Engine.time_scale = (slowMoTimer - 1) * 3 / 4 + 0.25
		if slowMoTimer >= 2:
			isInSlowMo = false
			isInvulnerable = false
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
	
	if inputDir.length() > 0 and !isDashing:
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
				timerGuardCD.wait_time = timerAttackHitscan.wait_time + timerAttackPostAnimation.wait_time
				cancel_guard()
	# second statement allows basically buffering a guard
	if (Input.is_action_pressed("key_space") and canGuard) or (Input.is_action_pressed("key_space") and canGuard and !isGuarding and !isAttacking):
		start_guard()
		cancel_attack()
	if !Input.is_action_pressed("key_space") and isGuarding:
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
		if timerAttackPostAnimation.time_left > 0:
			remove_child(attackPostAnimationInstance)
			timerAttackPostAnimation.stop()
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
	timerAttackPostAnimation.start()
	attackPostAnimationInstance.position = attackHitscanInstance.position
	attackPostAnimationInstance.rotation = attackHitscanInstance.rotation
	attackPostAnimationInstance.show()
	add_child(attackPostAnimationInstance)
	
	remove_child(attackHitscanInstance)
	
func _on_timer_attack_post_animation_timeout():
	timerAttackCD.start()
	remove_child(attackPostAnimationInstance)
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
				Engine.time_scale = 0.25
				isInSlowMo = true
				isInvulnerable = true
				var temp = timerDash.time_left
				timerDash.stop()
				timerDash.wait_time = temp / 4
				timerDash.start()
				timerDash.wait_time = timerDashBaseTime / 4
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
	if timerGuardCD.wait_time != timerGuardCDBaseTime * Engine.time_scale:
		timerGuardCD.wait_time = timerGuardCDBaseTime * Engine.time_scale
