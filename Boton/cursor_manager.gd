extends Node

var cursor_normal = load("res://Boton/Cur_norm.png")
var cursor_clic = load("res://Boton/Cur_señ.png")

func _process(_delta):
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var hovered_control = viewport.gui_get_hovered_control()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if cursor_clic:
			Input.set_custom_mouse_cursor(cursor_clic, Input.CURSOR_ARROW, Vector2.ZERO)
	elif hovered_control is Button:
		if cursor_clic:
			Input.set_custom_mouse_cursor(cursor_clic, Input.CURSOR_ARROW, Vector2.ZERO)
	else:
		if cursor_normal:
			Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, Vector2.ZERO)
