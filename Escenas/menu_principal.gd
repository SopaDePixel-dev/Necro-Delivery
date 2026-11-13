extends Control

@onready var fuego: AnimatedSprite2D = $FuegoSeleccion
@onready var panel_opciones: Panel = $PanelOpciones
@onready var fondo_principal: VideoStreamPlayer = $Fondo
@onready var fondo_opciones: VideoStreamPlayer = $FondoOpciones
@onready var musica_principal: AudioStreamPlayer = $MusicaPrincipal
@onready var musica_opciones: AudioStreamPlayer = $MusicaOpciones

@onready var sl_general: HSlider = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Audio/SL_general
@onready var sl_fx: HSlider = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Audio/SL_Fx
@onready var sl_musica: HSlider = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Audio/SL_Musica

@onready var ch_pantalla: CheckButton = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Video/ch_Pantalla
@onready var ch_vsync: CheckButton = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Video/ch_V
@onready var op_fps: OptionButton = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Video/cont_FPS/op_FPS
@onready var op_resolucion: OptionButton = $PanelOpciones/Marco_textura/MarginContainer/contenedor_principal/TabContainer/Video/cont_Resolucion/op_Resolucion
@onready var sfx_reproductor: AudioStreamPlayer = $Fx_btn

func reproducir_sonido_boton() -> void:
	if sfx_reproductor:
		sfx_reproductor.play()
		
func _ready() -> void:
	fuego.visible = false
	panel_opciones.visible = false
	
	if fondo_principal:
		fondo_principal.expand = true
		fondo_principal.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo_principal.play()
		
	if fondo_opciones:
		fondo_opciones.visible = false
		fondo_opciones.expand = true
		fondo_opciones.set_anchors_preset(Control.PRESET_FULL_RECT)

	if sl_general:
		sl_general.value_changed.connect(func(v): _cambiar_volumen("Master", v))
	if sl_fx:
		sl_fx.value_changed.connect(func(v): _cambiar_volumen("Fx", v))
	if sl_musica:
		sl_musica.value_changed.connect(func(v): _cambiar_volumen("Musica", v))

	if ch_pantalla:
		ch_pantalla.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		ch_pantalla.toggled.connect(_on_pantalla_completa_toggled)
		
	if ch_vsync:
		ch_vsync.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		ch_vsync.toggled.connect(_on_vsync_toggled)
		
	if op_fps:
		op_fps.item_selected.connect(_on_fps_seleccionado)
		
	if op_resolucion:
		op_resolucion.item_selected.connect(_on_resolucion_seleccionada)

func _cambiar_volumen(bus_nombre: String, valor: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_nombre)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(valor))

func _on_pantalla_completa_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_fps_seleccionado(index: int) -> void:
	match index:
		0: Engine.max_fps = 30
		1: Engine.max_fps = 60
		2: Engine.max_fps = 120
		3: Engine.max_fps = 144
		4: Engine.max_fps = 0 # Sin límite

func _on_resolucion_seleccionada(index: int) -> void:
	var nueva_resolucion = Vector2i(1152, 648)
	match index:
		0: nueva_resolucion = Vector2i(850, 315)
		1: nueva_resolucion = Vector2i(1280, 720)
		2: nueva_resolucion = Vector2i(1920, 1080)
		3: nueva_resolucion = Vector2i(2560, 1440)
			
	get_window().size = nueva_resolucion

func _on_btn_jugar_mouse_entered() -> void:
	posicionar_fuego($VBoxContainer/btn_jugar)

func _on_btn_jugar_mouse_exited() -> void:
	fuego.visible = false

func _on_btn_jugar_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/mapa.tscn")
	reproducir_sonido_boton()

func _on_btn_continuar_mouse_entered() -> void:
	posicionar_fuego($VBoxContainer/btn_continuar)

func _on_btn_continuar_mouse_exited() -> void:
	fuego.visible = false

func _on_btn_opciones_mouse_entered() -> void:
	posicionar_fuego($VBoxContainer/btn_opciones)

func _on_btn_opciones_mouse_exited() -> void:
	fuego.visible = false

func _on_btn_opciones_pressed() -> void:
	panel_opciones.visible = true
	$VBoxContainer.visible = false
	fuego.visible = false
	reproducir_sonido_boton()
	
	if fondo_principal: 
		fondo_principal.visible = false
		fondo_principal.stop()
		
	if fondo_opciones:
		fondo_opciones.visible = true
		fondo_opciones.expand = true
		fondo_opciones.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo_opciones.play()
	
	if musica_principal: musica_principal.stop()
	if musica_opciones: musica_opciones.play()

func _on_btn_salir_mouse_entered() -> void:
	posicionar_fuego($VBoxContainer/btn_Salir)

func _on_btn_salir_mouse_exited() -> void:
	fuego.visible = false

func _on_btn_salir_pressed() -> void:
	reproducir_sonido_boton()
	get_tree().quit()



func _on_btn_cerrar_opciones_pressed() -> void:
	cerrar_panel_opciones()
	reproducir_sonido_boton()

func cerrar_panel_opciones() -> void:
	panel_opciones.visible = false
	$VBoxContainer.visible = true
	
	if fondo_opciones:
		fondo_opciones.stop()
		fondo_opciones.visible = false
		
	if fondo_principal: 
		fondo_principal.visible = true
		fondo_principal.play()
		
	if musica_opciones: musica_opciones.stop()
	if musica_principal: musica_principal.play()

func posicionar_fuego(boton: Button) -> void:
	fuego.play()
	
	var fuente = boton.get_theme_font("font")
	var tamano_fuente = boton.get_theme_font_size("font_size")
	var ancho_texto = fuente.get_string_size(boton.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente).x
	
	var centro_x = boton.global_position.x + (boton.size.x / 2.0)
	var inicio_texto_x = centro_x - (ancho_texto / 2.0)
	
	var margen_fijo : float = 30.0
	var offset_y : float = -8.0
	
	var pos_x = inicio_texto_x - margen_fijo
	var pos_y = boton.global_position.y + (boton.size.y / 2.0) + offset_y
	
	fuego.global_position = Vector2(pos_x, pos_y)
	fuego.visible = true


func _on_ch_pantalla_pressed() -> void:
	reproducir_sonido_boton()


func _on_ch_v_pressed() -> void:
	reproducir_sonido_boton()
