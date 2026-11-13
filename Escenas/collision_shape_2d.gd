extends CharacterBody2D


const TAMANO_CASILLA : int = 64
var en_movimiento : bool = false

func _unhandled_input(event):
	if en_movimiento:
		return
		
	var direccion = Vector2.ZERO
	
	if event.is_action_pressed("ui_right"):
		direccion.x += 1
	elif event.is_action_pressed("ui_left"):
		direccion.x -= 1
	elif event.is_action_pressed("ui_down"):
		direccion.y += 1
	elif event.is_action_pressed("ui_up"):
		direccion.y -= 1
		
	if direccion != Vector2.ZERO:
		mover_a_casilla(direccion)

func mover_a_casilla(dir: Vector2):
	en_movimiento = true
	var destino = position + (dir * TAMANO_CASILLA)
	
	# Transición suave usando un Tween
	var tween = create_tween()
	tween.tween_property(self, "position", destino, 0.15)
	await tween.finished
	
	en_movimiento = false
