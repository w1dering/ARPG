extends CanvasLayer

var player
var playerHPBarGoal
var playerMPBarGoal
var playerBarChangeSpeed = 50

# Called when the node enters the scene tree for the first time.
func _ready():
	$PlayerHPBar.position = Vector2(20, 20)
	$PlayerMPBar.position = Vector2(20, 67)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if $PlayerHPBar.value > playerHPBarGoal:
		$PlayerHPBar.value -= playerBarChangeSpeed * delta
		if $PlayerHPBar.value < playerHPBarGoal:
			$PlayerHPBar.value = playerHPBarGoal
	
	if $PlayerHPBar.value < playerHPBarGoal:
		$PlayerHPBar.value += playerBarChangeSpeed * delta
		if $PlayerHPBar.value > playerHPBarGoal:
			$PlayerHPBar.value = playerHPBarGoal
	
	if $PlayerMPBar.value > playerMPBarGoal:
		$PlayerMPBar.value -= playerBarChangeSpeed * delta
		if $PlayerMPBar.value < playerMPBarGoal:
			$PlayerMPBar.value = playerMPBarGoal
	
	if $PlayerMPBar.value < playerMPBarGoal:
		$PlayerMPBar.value += playerBarChangeSpeed * delta
		if $PlayerMPBar.value > playerMPBarGoal:
			$PlayerMPBar.value = playerMPBarGoal


func change_player_HP_bar(amount):
	playerHPBarGoal = amount

func change_player_MP_bar(amount):
	playerMPBarGoal = amount
