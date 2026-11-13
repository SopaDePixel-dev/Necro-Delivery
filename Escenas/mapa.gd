extends Control

# ============================================================
#  MAPA VERTICAL ESTILO SLAY THE SPIRE, EN CUADRÍCULA
#  - Se avanza de ABAJO hacia ARRIBA (inicio abajo, entrega arriba).
#  - El mapa es más alto que la pantalla: se mueve con la rueda del
#    mouse, arrastrando, o con las flechas arriba/abajo. También se
#    desplaza solo para seguir al jugador.
#  - Todo está hecho de cuadros (celdas). Los caminos se arman con tus
#    piezas: rectas (der), esquinas (esq_...), cruces (inter_...).
#  - Los nodos se copian de los que ya tienes en la escena.
# ============================================================

signal nodo_alcanzado(tipo: String)
signal entrega_completada
@onready var Menu_pausa: Panel = $Menu_pausa
@onready var contenedor_mapa: Control = $Contenedor_Mapa
# Sin tipo a propósito: funcionan igual si son AudioStreamPlayer o AudioStreamPlayer2D
@onready var musica_mapa = get_node_or_null("Musica_mapa")
@onready var fx_barrera = get_node_or_null("Fx_barrera")

# ---------- AJUSTES DEL MAPA (cámbialos con confianza) ----------
const PISOS := 10                 # niveles del mapa, contando el inicio y la entrega
const CARRILES := 6               # cuántas "columnas" posibles de nodos hay
const NUM_CAMINOS := 4            # cuántos caminos distintos salen del inicio
const ANCHO_CELDAS := 20          # ancho del mapa en cuadros
const FILAS_POR_PISO := 4         # cuadros de distancia entre un nivel y otro (mínimo 3)
const MARGEN_FILAS := 2           # cuadros libres arriba y abajo del mapa
const CELDA := 48.0               # tamaño de cada cuadro en pantalla (píxeles)
const TAM_NODO := 80.0            # tamaño de los nodos en pantalla
const TAM_NODO_FINAL := 104.0     # tamaño del nodo de la entrega
const RELLENAR_SUELO := false     # true = todo el mapa es suelo de piedra (sinC). false = solo bajo los caminos

const TIPO_INICIO := "Nodo_inicial"  # nodo donde empieza el jugador
# Nodos que pueden salir en medio (repetir uno = sale más seguido)
const TIPOS_POSIBLES := [
	"Nodo_batalla", "Nodo_batalla", "Nodo_batalla",
	"Nodo_Aleatorio", "Nodo_Aleatorio",
	"Nodo_Tienda", "Nodo_vida"
]

# ---------- TUS IMÁGENES (carpeta Caminos) ----------
const RUTA_CAMINOS := "res://Caminos/"
const GRUPOS := {
	"recto": ["der1", "der2", "der3", "der4", "der5", "der6"],
	"esq_sup_der": ["esq_sup_der1", "esq_sup_der2", "esq_sup_der3", "esq_sup_der4"],
	"esq_sup_izq": ["esq_sup_izq1", "esq_sup_izq2", "esq_sup_izq3"],
	"esq_inf_der": ["esq_inf_der1"],
	"esq_inf_izq": ["esq_inf_izq1"],
	"t": ["inter_3C", "inter_3C2"],
	"cruz": ["inter_4C", "inter_4C2"],
	"suelo": ["sinC1", "sinC2", "sinC3", "sinC4", "sinC5", "sinC6", "sinC7"],
}

# Qué esquina va en cada giro. Si alguna esquina se ve volteada al revés,
# aquí es donde se arregla: intercambia los nombres entre sí.
#   12 = el camino viene de la izquierda y baja     6 = viene de la derecha y baja
#    9 = viene de la izquierda y sube               3 = viene de la derecha y sube
const ESQUINA_POR_MASCARA := {
	12: "esq_sup_der",
	6: "esq_sup_izq",
	9: "esq_inf_der",
	3: "esq_inf_izq",
}

# ---------- MOVIMIENTO ----------
const VELOCIDAD_JUGADOR := 220.0  # píxeles por segundo
const RADIO_CLIC := 45.0          # qué tan cerca del nodo cuenta el clic
const PASO_RUEDA := 90.0          # cuánto se mueve el mapa con cada giro de rueda
const PASO_TECLADO := 60.0
const TAM_JUGADOR := 40.0         # tamaño del nigromante en pantalla (un cuadro mide 48)
const ANIMAR_SOLO_AL_CAMINAR := true   # true = su animación solo corre mientras se mueve
const ESCENA_JUGADOR := ""        # (opcional) otra escena de personaje; se usa si no existe el nodo "Jugador"

# ---------- BARRERAS (caminos que se cierran) ----------
# Se cierran DESPUÉS de llegar al nodo, no al hacer clic.
const CERRAR_CAMINO_RECORRIDO := true   # el camino por el que acabas de venir queda cerrado
const BARRERA_EN_ENTRADA := true        # true = en el cuadro justo antes del nodo al que llegaste
										# false = pegada al nodo que dejaste
const CERRAR_ALTERNATIVAS := false      # true = los caminos que NO escogiste también se cierran
const RUTA_BARRERA := "res://Nodos/Barrera.png"   # si se deja vacío, se dibuja una X roja temporal

# ---------- ESCENAS A LAS QUE LLEVA CADA NODO ----------
# Pon aquí las rutas reales de tus escenas. Si una no existe todavía, el mapa
# simplemente sigue funcionando sin cambiar de escena.
const ESCENAS := {
	"Nodo_batalla": "res://Escenas/batalla.tscn",
	"Nodo_Tienda": "res://Escenas/tienda.tscn",
	"Nodo_vida": "res://Escenas/curacion.tscn",
	"Nodo_Final": "",   # pantalla de "entrega completada", si quieres una
}
# El nodo Aleatorio escoge uno de estos al llegar
const TIPOS_ALEATORIO := ["Nodo_batalla", "Nodo_Tienda", "Nodo_vida"]

# Nombre con el que se guarda el avance mientras estás en otra escena
const CLAVE_PARTIDA := "necro_partida"

# ---------- VARIABLES INTERNAS ----------
var _mundo: Node2D
var _capa_suelo: Node2D
var _capa_caminos: Node2D
var _capa_barreras: Node2D
var _capa_nodos: Node2D
var _capa_jugador: Node2D
var _jugador: Node2D

var _tex: Dictionary = {}             # grupo -> lista de texturas
var _nodos: Array = []                # {sprite, tipo, escala, siguientes, celda, pulso}
var _indice_por_clave: Dictionary = {}  # Vector2i(piso, carril) -> indice de nodo
var _celdas_nodo: Dictionary = {}     # celdas ocupadas por nodos
var _mascaras: Dictionary = {}        # celda -> lados abiertos del camino
var _duenos: Dictionary = {}          # celda -> aristas que pasan por ahí
var _rutas: Dictionary = {}           # Vector2i(desde, hasta) -> lista de celdas
var _barreras: Dictionary = {}        # celda -> barrera dibujada
var _estado: Dictionary = {}          # avance guardado: semilla, nodo actual, visitados, barreras

var _filas_total := 0
var _alto_px := 0.0
var _actual := -1
var _opciones: Array = []
var _moviendo := false
var _tween_scroll: Tween
var _presionando := false
var _distancia_arrastre := 0.0


func _ready() -> void:
	randomize()
	_cargar_texturas()

	if musica_mapa and not musica_mapa.playing:
		musica_mapa.play()

	# El avance se guarda en "Engine" para que sobreviva al cambiar de escena.
	# Si no hay nada guardado, es una partida nueva.
	_estado = Engine.get_meta(CLAVE_PARTIDA, {})
	if _estado.is_empty():
		_estado = {"semilla": randi(), "actual": 0, "visitados": [0], "barreras": []}
		Engine.set_meta(CLAVE_PARTIDA, _estado)

	generar_mapa()


func generar_mapa() -> void:
	# Misma semilla = mismo mapa al volver de una batalla o de la tienda
	seed(_estado["semilla"])
	_limpiar()
	_crear_grafo()
	_trazar_rutas()
	_dibujar_suelo()
	_dibujar_caminos()
	_colocar_jugador()
	randomize()   # de aquí en adelante el azar vuelve a ser normal
	print("--- MAPA GENERADO: %d nodos ---" % _nodos.size())


# ------------------------------------------------------------
#  PREPARACIÓN
# ------------------------------------------------------------
func _cargar_texturas() -> void:
	_tex.clear()
	for grupo in GRUPOS:
		var lista: Array = []
		for nombre in GRUPOS[grupo]:
			var ruta: String = RUTA_CAMINOS + nombre + ".png"
			if ResourceLoader.exists(ruta):
				lista.append(load(ruta))
			else:
				push_warning("No encontré la imagen: " + ruta)
		_tex[grupo] = lista


func _limpiar() -> void:
	if is_instance_valid(_mundo):
		_mundo.queue_free()
	_nodos.clear()
	_indice_por_clave.clear()
	_celdas_nodo.clear()
	_mascaras.clear()
	_duenos.clear()
	_rutas.clear()
	_barreras.clear()
	_opciones = []
	_moviendo = false
	_actual = -1

	# Tus nodos originales se quedan escondidos: solo sirven de molde
	for hijo in contenedor_mapa.get_children():
		if hijo.name.begins_with("Nodo_"):
			hijo.visible = false

	# El contenedor recorta lo que se sale de su recuadro (así funciona el scroll)
	contenedor_mapa.clip_contents = true

	_filas_total = (PISOS - 1) * FILAS_POR_PISO + 1 + MARGEN_FILAS * 2
	_alto_px = _filas_total * CELDA

	_mundo = Node2D.new()
	_mundo.name = "Mundo"
	_mundo.position.x = floorf((contenedor_mapa.size.x - ANCHO_CELDAS * CELDA) / 2.0)
	contenedor_mapa.add_child(_mundo)

	_capa_suelo = _nueva_capa("CapaSuelo")
	_capa_caminos = _nueva_capa("CapaCaminos")
	_capa_nodos = _nueva_capa("CapaNodos")
	_capa_barreras = _nueva_capa("CapaBarreras")
	_capa_jugador = _nueva_capa("CapaJugador")


func _nueva_capa(nombre: String) -> Node2D:
	var capa := Node2D.new()
	capa.name = nombre
	_mundo.add_child(capa)
	return capa


func _centro(celda: Vector2i) -> Vector2:
	return Vector2((celda.x + 0.5) * CELDA, (celda.y + 0.5) * CELDA)


func _fila_de_piso(piso: int) -> int:
	return _filas_total - 1 - MARGEN_FILAS - piso * FILAS_POR_PISO


func _col_carril(carril: int) -> int:
	return int(round((carril + 0.5) * ANCHO_CELDAS / float(CARRILES) - 0.5))


# ------------------------------------------------------------
#  GENERACIÓN DE NODOS Y CONEXIONES (estilo Slay the Spire)
#  Varios "caminantes" suben desde el inicio; cada paso puede ir
#  recto o un carril a los lados, sin cruzarse con los demás.
# ------------------------------------------------------------
func _crear_grafo() -> void:
	var pisos_medios := PISOS - 2
	var col_centro := int(ANCHO_CELDAS * 0.5)

	var inicio := _crear_nodo(TIPO_INICIO, 0, col_centro)

	var carriles: Array = range(CARRILES)
	carriles.shuffle()
	var caminantes: Array = carriles.slice(0, mini(NUM_CAMINOS, CARRILES))
	for carril in caminantes:
		_unir(inicio, _nodo_en(1, carril))

	for piso in range(1, pisos_medios):
		var usadas: Array = []
		for k in range(caminantes.size()):
			var origen: int = caminantes[k]
			var destino := _elegir_destino(origen, usadas)
			usadas.append([origen, destino])
			caminantes[k] = destino
			_unir(_nodo_en(piso, origen), _nodo_en(piso + 1, destino))

	var entrega := _crear_nodo("Nodo_Final", PISOS - 1, col_centro)
	for carril in caminantes:
		_unir(_nodo_en(pisos_medios, carril), entrega)


func _elegir_destino(origen: int, usadas: Array) -> int:
	var opciones: Array = [-1, 0, 1]
	opciones.shuffle()
	for d in opciones:
		var destino: int = origen + d
		if destino < 0 or destino >= CARRILES:
			continue
		if not _cruza(usadas, origen, destino):
			return destino
	return origen


func _cruza(usadas: Array, origen: int, destino: int) -> bool:
	for e in usadas:
		if (origen < e[0] and destino > e[1]) or (origen > e[0] and destino < e[1]):
			return true
	return false


func _nodo_en(piso: int, carril: int) -> int:
	var clave := Vector2i(piso, carril)
	if _indice_por_clave.has(clave):
		return _indice_por_clave[clave]

	var tipo: String
	if piso == 1:
		tipo = "Nodo_batalla"
	elif piso == PISOS - 2:
		tipo = "Nodo_vida"
	else:
		tipo = TIPOS_POSIBLES.pick_random()

	var indice := _crear_nodo(tipo, piso, _col_carril(carril))
	_indice_por_clave[clave] = indice
	return indice


func _crear_nodo(tipo: String, piso: int, columna: int) -> int:
	var molde: AnimatedSprite2D = contenedor_mapa.get_node(tipo)
	var celda := Vector2i(columna, _fila_de_piso(piso))

	var copia: AnimatedSprite2D = molde.duplicate()
	copia.name = "Casilla_%d" % _nodos.size()
	copia.visible = true
	copia.position = _centro(celda)

	# Todos los nodos quedan del mismo tamaño, sin importar el de su imagen
	var tam_frame: Vector2 = molde.sprite_frames.get_frame_texture(molde.animation, 0).get_size()
	var objetivo := TAM_NODO_FINAL if tipo == "Nodo_Final" else TAM_NODO
	copia.scale = Vector2.ONE * (objetivo / maxf(tam_frame.x, tam_frame.y))
	_capa_nodos.add_child(copia)

	# Que no todos animen sincronizados
	copia.play(copia.animation)
	copia.frame = randi() % copia.sprite_frames.get_frame_count(copia.animation)

	_celdas_nodo[celda] = true
	_nodos.append({
		"sprite": copia,
		"tipo": tipo,
		"escala": copia.scale,
		"siguientes": [],
		"celda": celda,
		"pulso": null,
	})
	return _nodos.size() - 1


func _unir(desde: int, hasta: int) -> void:
	var lista: Array = _nodos[desde]["siguientes"]
	if not lista.has(hasta):
		lista.append(hasta)


# ------------------------------------------------------------
#  RUTAS EN LA CUADRÍCULA
#  Cada conexión sube recto, gira en una fila "intermedia", y vuelve a subir.
#  Si dos caminos coinciden en un cuadro, ese cuadro se vuelve T o cruce.
# ------------------------------------------------------------
func _trazar_rutas() -> void:
	for a in range(_nodos.size()):
		for b in _nodos[a]["siguientes"]:
			var ruta := _mejor_ruta(a, b)
			var id := Vector2i(a, b)
			_rutas[id] = ruta
			_registrar_ruta(ruta, id)


func _mejor_ruta(a: int, b: int) -> Array:
	var ca: Vector2i = _nodos[a]["celda"]
	var cb: Vector2i = _nodos[b]["celda"]
	var candidatas: Array = []

	if ca.x == cb.x:
		candidatas.append(_ruta_vhv(ca, cb, ca.y))
	else:
		var libres: Array = []
		for fila in range(cb.y + 1, ca.y):
			libres.append(fila)
		libres.shuffle()
		var medio: float = (ca.y + cb.y) / 2.0
		libres.sort_custom(func(x, y): return absf(x - medio) < absf(y - medio))
		for fila in libres:
			candidatas.append(_ruta_vhv(ca, cb, fila))

	# Nos quedamos con la que menos se encime con otros caminos o nodos
	var mejor: Array = candidatas[0]
	var menor := 999999
	for ruta in candidatas:
		var choques := _conflictos(ruta, a, b)
		if choques < menor:
			menor = choques
			mejor = ruta
		if choques == 0:
			break
	return mejor


func _ruta_vhv(ca: Vector2i, cb: Vector2i, fila_giro: int) -> Array:
	var celdas: Array = []
	var p := ca
	celdas.append(p)
	while p.y != fila_giro:
		p.y += signi(fila_giro - p.y)
		celdas.append(p)
	while p.x != cb.x:
		p.x += signi(cb.x - p.x)
		celdas.append(p)
	while p.y != cb.y:
		p.y += signi(cb.y - p.y)
		celdas.append(p)
	return celdas


func _conflictos(ruta: Array, a: int, b: int) -> int:
	var total := 0
	for i in range(1, ruta.size() - 1):
		var c: Vector2i = ruta[i]
		if _duenos.has(c):
			for e in _duenos[c]:
				# Compartir inicio o final con otro camino está bien (bifurcación o unión)
				if e.x != a and e.y != b:
					total += 1
					break
		for n in range(_nodos.size()):
			if n == a or n == b:
				continue
			var cn: Vector2i = _nodos[n]["celda"]
			if maxi(absi(cn.x - c.x), absi(cn.y - c.y)) <= 1:
				total += 1
				break
	return total


func _registrar_ruta(ruta: Array, id: Vector2i) -> void:
	for i in range(ruta.size()):
		var c: Vector2i = ruta[i]
		if not _duenos.has(c):
			_duenos[c] = []
		_duenos[c].append(id)
		if i < ruta.size() - 1:
			var siguiente: Vector2i = ruta[i + 1]
			var d: Vector2i = siguiente - c
			_mascaras[c] = int(_mascaras.get(c, 0)) | _bit(d)
			_mascaras[siguiente] = int(_mascaras.get(siguiente, 0)) | _bit(-d)


# Cada lado abierto de un cuadro vale: arriba 1, derecha 2, abajo 4, izquierda 8
func _bit(d: Vector2i) -> int:
	if d == Vector2i.UP:
		return 1
	if d == Vector2i.RIGHT:
		return 2
	if d == Vector2i.DOWN:
		return 4
	return 8


# ------------------------------------------------------------
#  DIBUJO DEL SUELO Y LOS CAMINOS
# ------------------------------------------------------------
func _dibujar_suelo() -> void:
	if _tex["suelo"].is_empty():
		return
	if RELLENAR_SUELO:
		for fila in range(_filas_total):
			for col in range(ANCHO_CELDAS):
				_poner_pieza(_capa_suelo, _tex["suelo"].pick_random(), Vector2i(col, fila), 0.0)
	else:
		for celda in _mascaras:
			_poner_pieza(_capa_suelo, _tex["suelo"].pick_random(), celda, 0.0)


func _dibujar_caminos() -> void:
	for celda in _mascaras:
		if _celdas_nodo.has(celda):
			continue   # debajo de un nodo no hace falta pieza
		var info := _pieza_para(_mascaras[celda])
		var lista: Array = _tex.get(info["grupo"], [])
		if lista.is_empty():
			continue
		_poner_pieza(_capa_caminos, lista.pick_random(), celda, info["rot"])


func _pieza_para(mascara: int) -> Dictionary:
	match mascara:
		10, 2, 8:
			return {"grupo": "recto", "rot": 0.0}
		5, 1, 4:
			return {"grupo": "recto", "rot": PI / 2.0}
		3, 6, 9, 12:
			return {"grupo": ESQUINA_POR_MASCARA[mascara], "rot": 0.0}
		14:
			return {"grupo": "t", "rot": 0.0}            # abierta: izquierda, derecha, abajo
		13:
			return {"grupo": "t", "rot": PI / 2.0}       # abierta: arriba, abajo, izquierda
		11:
			return {"grupo": "t", "rot": PI}             # abierta: izquierda, derecha, arriba
		7:
			return {"grupo": "t", "rot": 3.0 * PI / 2.0} # abierta: arriba, abajo, derecha
	return {"grupo": "cruz", "rot": 0.0}


func _poner_pieza(capa: Node2D, textura: Texture2D, celda: Vector2i, rotacion: float) -> void:
	var pieza := Sprite2D.new()
	pieza.texture = textura
	pieza.position = _centro(celda)
	# Cada pieza se ajusta al cuadro (+1 píxel para que no se vean rendijas)
	pieza.scale = Vector2((CELDA + 1.0) / textura.get_width(), (CELDA + 1.0) / textura.get_height())
	pieza.rotation = rotacion
	capa.add_child(pieza)


# ------------------------------------------------------------
#  JUGADOR
# ------------------------------------------------------------
func _colocar_jugador() -> void:
	var molde_jugador := contenedor_mapa.get_node_or_null("Jugador") as AnimatedSprite2D
	if molde_jugador != null:
		# Tu nigromante de la escena: el original se esconde y se usa una copia
		molde_jugador.visible = false
		var copia: AnimatedSprite2D = molde_jugador.duplicate()
		copia.visible = true
		var tam: Vector2 = molde_jugador.sprite_frames.get_frame_texture(molde_jugador.animation, 0).get_size()
		copia.scale = Vector2.ONE * (TAM_JUGADOR / maxf(tam.x, tam.y))
		_jugador = copia
	elif ESCENA_JUGADOR != "" and ResourceLoader.exists(ESCENA_JUGADOR):
		_jugador = load(ESCENA_JUGADOR).instantiate() as Node2D
	else:
		# Marcador temporal (un rombo rojo) hasta que tengas tu personaje
		var marcador := Polygon2D.new()
		marcador.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(12, 0), Vector2(0, 16), Vector2(-12, 0)
		])
		marcador.color = Color(0.8, 0.1, 0.1)
		_jugador = marcador

	_actual = int(_estado["actual"])
	if _actual < 0 or _actual >= _nodos.size():
		_actual = 0
	_jugador.position = _nodos[_actual]["sprite"].position
	_capa_jugador.add_child(_jugador)
	if _jugador is AnimatedSprite2D and ANIMAR_SOLO_AL_CAMINAR:
		_jugador.stop()

	# Recuperamos lo que ya pasó: nodos visitados y barreras
	for indice in _estado["visitados"]:
		if indice < _nodos.size():
			_nodos[indice]["sprite"].modulate = Color(0.7, 0.7, 0.7)
	for celda in _estado["barreras"]:
		_poner_barrera(celda, false)

	_opciones = _nodos[_actual]["siguientes"]
	_resaltar_opciones()

	_mundo.position.y = _min_y()
	_enfocar(_jugador.position.y, 0.0)


func _ir_a_nodo(indice: int) -> void:
	var origen := _actual
	_moviendo = true
	_opciones = []
	_resaltar_opciones()

	# El jugador sigue el camino por las esquinas, no en línea recta
	var ruta: Array = _rutas[Vector2i(_actual, indice)]
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	var pos := _jugador.position
	var duracion_total := 0.0
	for punto in _puntos_de_ruta(ruta):
		var tiempo := pos.distance_to(punto) / VELOCIDAD_JUGADOR
		tween.tween_property(_jugador, "position", punto, tiempo)
		duracion_total += tiempo
		pos = punto

	if _jugador is AnimatedSprite2D and ANIMAR_SOLO_AL_CAMINAR:
		_jugador.play()
	_enfocar(pos.y, duracion_total)
	await tween.finished
	if _jugador is AnimatedSprite2D and ANIMAR_SOLO_AL_CAMINAR:
		_jugador.stop()
		_jugador.frame = 0

	_actual = indice
	_nodos[indice]["sprite"].modulate = Color(0.7, 0.7, 0.7)   # nodo ya visitado
	_moviendo = false
	_al_llegar(origen, indice)


# Solo los puntos donde el camino cambia de dirección, y el final
func _puntos_de_ruta(ruta: Array) -> Array:
	var puntos: Array = []
	for i in range(1, ruta.size()):
		var es_ultimo := (i == ruta.size() - 1)
		if es_ultimo or (ruta[i] - ruta[i - 1]) != (ruta[i + 1] - ruta[i]):
			puntos.append(_centro(ruta[i]))
	return puntos


func _al_llegar(origen: int, indice: int) -> void:
	var tipo: String = _nodos[indice]["tipo"]
	print("Llegaste a: ", tipo)
	nodo_alcanzado.emit(tipo)

	# Guardamos el avance (así, al volver de otra escena, el mapa es el mismo)
	_estado["actual"] = indice
	if not _estado["visitados"].has(indice):
		_estado["visitados"].append(indice)

	# Ya pasamos por el nodo: ahora sí se cierran los caminos
	_cerrar_caminos(origen, indice)
	Engine.set_meta(CLAVE_PARTIDA, _estado)
	await get_tree().create_timer(0.6).timeout   # para que se alcance a ver la barrera

	var es_final := (tipo == "Nodo_Final")
	if es_final:
		print("¡ENTREGA COMPLETADA!")
		Engine.remove_meta(CLAVE_PARTIDA)   # la próxima vez se genera un mapa nuevo
		entrega_completada.emit()

	# Si el nodo tiene escena (batalla, tienda, curación...), nos vamos para allá.
	# Cuando termine, esa escena debe regresar a res://Escenas/mapa.tscn
	var escena := _escena_para(tipo)
	if escena != "" and ResourceLoader.exists(escena):
		get_tree().change_scene_to_file(escena)
		return
	if escena != "":
		push_warning("Todavía no existe la escena: " + escena)

	if es_final:
		return
	_opciones = _nodos[indice]["siguientes"]
	_resaltar_opciones()


func _escena_para(tipo: String) -> String:
	var clave: String = tipo
	if tipo == "Nodo_Aleatorio":
		clave = TIPOS_ALEATORIO.pick_random()
	print("Evento: ", clave)
	return ESCENAS.get(clave, "")


# ------------------------------------------------------------
#  BARRERAS
# ------------------------------------------------------------
func _cerrar_caminos(origen: int, elegido: int) -> void:
	var ruta_elegida: Array = _rutas[Vector2i(origen, elegido)]

	# El camino por el que acabamos de venir
	if CERRAR_CAMINO_RECORRIDO and ruta_elegida.size() > 2:
		if BARRERA_EN_ENTRADA:
			_poner_barrera(ruta_elegida[ruta_elegida.size() - 2], true)   # justo antes del nodo al que llegaste
		else:
			_poner_barrera(ruta_elegida[1], true)                          # pegada al nodo que dejaste

	# Los caminos que no escogimos: barrera en el primer cuadro que no comparten con el nuestro
	if CERRAR_ALTERNATIVAS:
		for otro in _nodos[origen]["siguientes"]:
			if otro == elegido:
				continue
			var ruta: Array = _rutas[Vector2i(origen, otro)]
			for i in range(1, ruta.size() - 1):
				if not ruta_elegida.has(ruta[i]):
					_poner_barrera(ruta[i], true)
					break


func _poner_barrera(celda: Vector2i, nueva: bool) -> void:
	if _barreras.has(celda):
		return
	var barrera := _crear_barrera()
	barrera.position = _centro(celda)
	_capa_barreras.add_child(barrera)
	_barreras[celda] = barrera

	if nueva:
		_estado["barreras"].append(celda)
		if fx_barrera:
			fx_barrera.play()
		# Aparece con un pequeño "pop"
		barrera.scale = Vector2.ZERO
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(barrera, "scale", Vector2.ONE, 0.35)


func _crear_barrera() -> Node2D:
	if RUTA_BARRERA != "" and ResourceLoader.exists(RUTA_BARRERA):
		var textura: Texture2D = load(RUTA_BARRERA)
		var imagen := Sprite2D.new()
		imagen.texture = textura
		imagen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		imagen.scale = Vector2((CELDA + 1.0) / textura.get_width(), (CELDA + 1.0) / textura.get_height())
		return imagen

	var raiz := Node2D.new()
	var m := CELDA * 0.4
	var fondo := Polygon2D.new()
	fondo.polygon = PackedVector2Array([Vector2(-m, -m), Vector2(m, -m), Vector2(m, m), Vector2(-m, m)])
	fondo.color = Color(0.35, 0.05, 0.05, 0.85)
	raiz.add_child(fondo)
	for puntos in [[Vector2(-m, -m), Vector2(m, m)], [Vector2(m, -m), Vector2(-m, m)]]:
		var linea := Line2D.new()
		linea.points = PackedVector2Array(puntos)
		linea.width = 5.0
		linea.default_color = Color(0.9, 0.8, 0.6)
		raiz.add_child(linea)
	return raiz


func _resaltar_opciones() -> void:
	for nodo in _nodos:
		if nodo["pulso"] != null:
			nodo["pulso"].kill()
			nodo["pulso"] = null
		nodo["sprite"].scale = nodo["escala"]

	for indice in _opciones:
		var nodo = _nodos[indice]
		var tween := create_tween().set_loops()
		tween.tween_property(nodo["sprite"], "scale", nodo["escala"] * 1.12, 0.5)
		tween.tween_property(nodo["sprite"], "scale", nodo["escala"], 0.5)
		nodo["pulso"] = tween


func _min_y() -> float:
	return minf(0.0, contenedor_mapa.size.y - _alto_px)


func _mouse_dentro() -> bool:
	return Rect2(Vector2.ZERO, contenedor_mapa.size).has_point(contenedor_mapa.get_local_mouse_position())


func _desplazar(delta: float) -> void:
	_detener_scroll()
	_mundo.position.y = clampf(_mundo.position.y + delta, _min_y(), 0.0)


func _detener_scroll() -> void:
	if _tween_scroll and _tween_scroll.is_valid():
		_tween_scroll.kill()


func _enfocar(y_mundo: float, duracion: float) -> void:
	_detener_scroll()
	var objetivo := clampf(contenedor_mapa.size.y * 0.65 - y_mundo, _min_y(), 0.0)
	if duracion <= 0.0:
		_mundo.position.y = objetivo
		return
	_tween_scroll = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_scroll.tween_property(_mundo, "position:y", objetivo, duracion)


func _input(event: InputEvent) -> void:
	if _moviendo:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _mouse_dentro():
			_desplazar(PASO_RUEDA)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _mouse_dentro():
			_desplazar(-PASO_RUEDA)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_presionando = _mouse_dentro()
				_distancia_arrastre = 0.0
			else:
				if _presionando and _distancia_arrastre < 8.0:
					_intentar_clic()
				_presionando = false
	elif event is InputEventMouseMotion and _presionando:
		_distancia_arrastre += event.relative.length()
		if _distancia_arrastre >= 8.0:
			_desplazar(event.relative.y)
	elif event.is_action_pressed("ui_up", true):
		_desplazar(PASO_TECLADO)
	elif event.is_action_pressed("ui_down", true):
		_desplazar(-PASO_TECLADO)


func _intentar_clic() -> void:
	var clic := _mundo.get_local_mouse_position()
	for indice in _opciones:
		if clic.distance_to(_nodos[indice]["sprite"].position) <= RADIO_CLIC:
			_ir_a_nodo(indice)
			return


func _on_btn_cerrar_opciones_pressed() -> void:
	Menu_pausa.visible = false
