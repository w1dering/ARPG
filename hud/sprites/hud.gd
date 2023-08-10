extends CanvasLayer

var player

# Called when the node enters the scene tree for the first time.
func _ready():
	$PlayerHealthBar.position = Vector2(20, 20)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func change_player_health_bar(amount):
	print("health changed")
	$PlayerHealthBar.value = amount
