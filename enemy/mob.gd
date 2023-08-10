# MAKE SEPARATE BASE CLASS FOR BOSS
extends Area2D

# area entered signals
#signal playerIsInHitbox
#signal playerIsInAttack

var player

# contains a node of the enemy type
@export var enemyType: PackedScene
var attackHitscanInstance
var attackPostAnimationInstance

var width
var height

# stats
var damage # on contact
var damageOnAttack
var hp
var speed
var knockbackResistance

# conditions
var canMove = true
var isGettingKnockedBack = false
var knockbackVector = Vector2.ZERO
var isAttacking = false
var canAttack = true
var isInvulnerable = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# PUT ALL FUNCTIONS INTO THE ONE SPECIFIC TO THE MOB, NOT THIS ONE; ELSE IT WILL GET OVERRIDDEN
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
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

func knockback(direction, magnitude):
	if !isGettingKnockedBack:
		canMove = false
		isGettingKnockedBack = true
		knockbackVector = direction.normalized() * 2000 * magnitude / knockbackResistance
		$TimerKnockback.start()

func _on_area_entered(area):
	if player.attackHitscanInstance != null and area == player.attackHitscanInstance and !isInvulnerable:
		# will only check damage ONCE
		# if it's a lingering attack, use bool variables (isInPlayerSkill), set it to true on area
		# enter and false on area exit, and deal damage via _process function
		reduce_hp(player.damageOnAttack)
		knockback(position - player.position, player.knockbackStrength)

func _on_area_exited(area):
	pass
		
	#elif player.attackHitscanInstance != null and area == player.attackHitscanInstance:
	#	isInPlayerAttack = false


func _on_timer_knockback_timeout():
	isGettingKnockedBack = false
	canMove = true
	knockbackVector = Vector2.ZERO

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
	canMove = true

func _on_timer_attack_cd_timeout():
	canAttack = true

func attack(direction):
	$TimerAttackHitscan.start()
	isAttacking = true
	canAttack = false
	attackHitscanInstance.position = direction.normalized() * 50
	attackHitscanInstance.rotation = direction.angle() + PI / 2
	attackHitscanInstance.show()
	add_child(attackHitscanInstance)
	
func make_invulnerable(time):
	$TimerInvulnerability.wait_time = time
	$TimerInvulnerability.start()
	isInvulnerable = true

func _on_timer_invulnerability_timeout():
	isInvulnerable = false

func move(direction, delta):
	position += direction.normalized() * speed * delta
