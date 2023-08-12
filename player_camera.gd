extends Camera2D

var shakeAmount: int
var defaultOffset = offset

# Called when the node enters the scene tree for the first time.
func _ready():
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var tempShakeAmount = shakeAmount
	if $TimerShake.time_left <= $TimerShake.wait_time / 2:
		tempShakeAmount = shakeAmount * 2 * $TimerShake.time_left / $TimerShake.wait_time
	offset = Vector2(randf_range(-1, 1) * tempShakeAmount, randf_range(-1, 1) * tempShakeAmount)

func shake(time, amount):
	randomize()
	$TimerShake.wait_time = time
	shakeAmount = amount
	set_process(true)
	$TimerShake.start()

func _on_timer_shake_timeout():
	offset = defaultOffset
	set_process(false)
