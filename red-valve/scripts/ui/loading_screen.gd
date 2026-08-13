extends CanvasLayer

@onready var bg: ColorRect = $ColorRect
@onready var texture_rect: TextureRect = $TextureRect
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var timer: Timer = $Timer
@onready var title_label: Label = $TitleLabel
@onready var desc_label: Label = $DescLabel

var loading_images: Array = [
	preload("res://assets/images/loadings/anti-lopes.png"),
	preload("res://assets/images/loadings/red_valve_sprite.png"),
	preload("res://assets/images/loadings/the_negotiator_V1_bullet.png"),
	preload("res://assets/images/loadings/the_negotiator_V1.png"),
	preload("res://assets/images/loadings/the_negotiator_V2.png")
]

var image_descriptions: Array = [
	"LOADING_TEXT_1",
	"LOADING_TEXT_2",
	"LOADING_TEXT_3",
	"LOADING_TEXT_4",
	"LOADING_TEXT_5"
]

var current_image_index: int = 0
var next_scene_path: String = ""
var is_loading: bool = false
var progress_array: Array = []
var elapsed_load_time: float = 0.0
var min_load_time: float = 1.5 # Tempo mínimo garantido que a tela de loading vai ficar visível

var original_master_volume: float = 0.0
var master_bus_index: int = 0

func _ready() -> void:
	layer = 128
	master_bus_index = AudioServer.get_bus_index("Master")
	visible = false
	progress_bar.value = 0
	
	timer.wait_time = 2.5
	timer.timeout.connect(_on_timer_timeout)

func load_scene(path: String) -> void:
	next_scene_path = path
	current_image_index = randi() % loading_images.size()
	texture_rect.texture = loading_images[current_image_index]
	desc_label.text = tr(image_descriptions[current_image_index])
	
	progress_bar.value = 0
	progress_array.clear()
	progress_array.append(0.0)
	
	# Fade in loading screen
	visible = true
	bg.modulate.a = 1.0
	progress_bar.modulate.a = 1.0
	title_label.modulate.a = 1.0
	texture_rect.modulate.a = 0.0
	desc_label.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(texture_rect, "modulate:a", 1.0, 0.5)
	tween.tween_property(desc_label, "modulate:a", 1.0, 0.5)
	
	original_master_volume = AudioServer.get_bus_volume_db(master_bus_index)
	tween.tween_method(func(v): AudioServer.set_bus_volume_db(master_bus_index, v), original_master_volume, -60.0, 0.3)
	
	tween.chain().tween_callback(func(): _start_threaded_load())

func _start_threaded_load() -> void:
	elapsed_load_time = 0.0
	ResourceLoader.load_threaded_request(next_scene_path)
	is_loading = true
	timer.start()

func _process(_delta: float) -> void:
	if not is_loading:
		return
		
	elapsed_load_time += _delta
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress_array)
	
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_bar.value = progress_array[0] * 100.0
		
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		# Se já carregou mas ainda não deu o tempo mínimo, não troca de cena ainda
		if elapsed_load_time < min_load_time:
			progress_bar.value = 99.0
			return
			
		is_loading = false
		progress_bar.value = 100.0
		timer.stop()
		
		var new_scene = ResourceLoader.load_threaded_get(next_scene_path)
		get_tree().change_scene_to_packed(new_scene)
		
		# Fade out loading screen
		var tween = create_tween().set_parallel(true)
		# Apenas as imagens e textos
		tween.tween_property(texture_rect, "modulate:a", 0.0, 0.4)
		tween.tween_property(desc_label, "modulate:a", 0.0, 0.4)
		tween.tween_method(func(v): AudioServer.set_bus_volume_db(master_bus_index, v), -60.0, original_master_volume, 0.5)
		
		tween.chain().tween_callback(func(): 
			visible = false
			bg.modulate.a = 1.0
			progress_bar.modulate.a = 1.0
			title_label.modulate.a = 1.0
		)
		
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		is_loading = false
		print("Error loading scene: ", next_scene_path)
		timer.stop()
		visible = false

func _on_timer_timeout() -> void:
	current_image_index = (current_image_index + 1) % loading_images.size()
	
	# Crossfade effect
	var tween = create_tween().set_parallel(true)
	tween.tween_property(texture_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(desc_label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(func(): 
		texture_rect.texture = loading_images[current_image_index]
		desc_label.text = tr(image_descriptions[current_image_index])
	)
	tween.tween_property(texture_rect, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(desc_label, "modulate:a", 1.0, 0.5)
