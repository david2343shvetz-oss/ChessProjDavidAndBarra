extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_lv1_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LV1.tscn")
	
func _on_lv2_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LV2.tscn")


func _on_lv3_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LV3.tscn")



func _on_lv4_button_pressed() -> void:
	pass # Replace with function body.


func _on_lv5_button_pressed() -> void:
	pass # Replace with function body.
