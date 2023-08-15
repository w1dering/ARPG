# MAKE SEPARATE BASE CLASS FOR BOSS
extends Area2D

# area entered signals
#signal playerIsInHitbox
#signal playerIsInAttack

signal hitStop
signal shakeScreen

var player

# contains a node of the enemy type
@export var enemyType: PackedScene
var attackHitscanInstance
var attackPostAnimationInstance

var size

# stats
var damage # on contact
var damageOnAttack
var hp
var speed
var knockbackResistance

@onready var timerAttackHitscan = $TimerHolder/TimerAttackHitscan
@export var timerAttackHitscanBaseTime = 0.05

@onready var timerAttackPostAnimation = $TimerHolder/TimerAttackPostAnimation
@export var timerAttackPostAnimationBaseTime = 0.15

@onready var timerAttackCD = $TimerHolder/TimerAttackCD
@export var timerAttackCDBaseTime = 1.0

@onready var timerInvulnerability = $TimerHolder/TimerInvulnerability
@export var timerInvulnerabilityBaseTime = 0.32

@onready var timerKnockback = $TimerHolder/TimerKnockback
@export var timerKnockbackBaseTime = 0.075

@onready var timerParryStun = $TimerHolder/TimerParryStun
@export var timerParryStunBaseTime = 2.0

# conditions
var canMove = true

var isGettingKnockedBack = false
var knockbackVector = Vector2.ZERO

var isAttacking = false
var canAttack = true

var isInvulnerable = false

# Called when the node enters the scene tree for the first time.
func _ready():
	timerAttackHitscan.wait_time = timerAttackHitscanBaseTime
	timerAttackPostAnimation.wait_time = timerAttackPostAnimationBaseTime
	timerAttackCD.wait_time = timerAttackCDBaseTime
	timerInvulnerability.wait_time = timerInvulnerabilityBaseTime
	timerKnockback.wait_time = timerKnockbackBaseTime
	timerParryStun.wait_time = timerParryStunBaseTime
	
	extra_ready()

func extra_ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# PUT ALL FUNCTIONS INTO THE ONE SPECIFIC TO THE MOB, NOT THIS ONE; ELSE IT WILL GET OVERRIDDEN
	pass

func spawn_mob(type):
	if type == "shadow":
		enemyType = load("res://enemy/shadow.tscn")
	return enemyType.instantiate()

func reduce_hp(amount):
	hp -= amount
	if hp <= 0:
		# play death animation
		# await death animation timer timeout
		queue_free()
	
	make_invulnerable(0.32)

func knockback(direction, amount):
	if !isGettingKnockedBack:
		canMove = false
		isGettingKnockedBack = true
		knockbackVector = direction.normalized() * 2000 * amount / knockbackResistance
		timerKnockback.start()

func _on_area_entered(area):
	if area != player and area != attackHitscanInstance and area != attackPostAnimationInstance and !isInvulnerable:
		hitStop.emit(area.hitStopTime)
		shakeScreen.emit(area.hitStopTime, area.screenShakeAmount)
		reduce_hp(area.damage)
		knockback(position - player.position, area.knockbackAmount)
		isAttacking = false
		canAttack = false
		canMove = false
		cancel_attack()

func _on_area_exited(area):
	pass
		
	#elif player.attackHitscanInstance != null and area == player.attackHitscanInstance:
	#	isInPlayerAttack = false

func cancel_attack():
	if isAttacking:
		isAttacking = false
		if timerAttackHitscan.time_left > 0:
			remove_child(attackHitscanInstance)
			timerAttackHitscan.stop()
		if timerAttackPostAnimation.time_left > 0:
			remove_child(attackPostAnimationInstance)
			timerAttackPostAnimation.stop()

func _on_timer_knockback_timeout():
	isGettingKnockedBack = false
	canMove = true
	timerAttackCD.start()
	knockbackVector = Vector2.ZERO

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
	canMove = true

func _on_timer_attack_cd_timeout():
	canAttack = true

func start_attack(direction):
	timerAttackHitscan.start()
	isAttacking = true
	canAttack = false
	attackHitscanInstance.position = direction.normalized() * 50
	attackHitscanInstance.rotation = direction.angle() + PI / 2
	attackHitscanInstance.show()
	add_child(attackHitscanInstance)
	
func make_invulnerable(time):
	timerInvulnerability.wait_time = time
	timerInvulnerability.start()
	isInvulnerable = true

func _on_timer_invulnerability_timeout():
	isInvulnerable = false

func move(direction, delta):
	position += direction.normalized() * speed * delta

func was_parried():
	# play parried animation
	timerParryStun.start()
	cancel_attack()
	canMove = false
	canAttack = false

func _on_timer_parry_stun_timeout():
	canMove = true
	canAttack = true
	isGettingKnockedBack = false
	timerAttackCD.start()
	knockbackVector = Vector2.ZERO
