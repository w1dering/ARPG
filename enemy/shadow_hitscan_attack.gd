extends Area2D

signal wasParried

var width
var height
var damage

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func _init():
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func was_parried():
	wasParried.emit()
