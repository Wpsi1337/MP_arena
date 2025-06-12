extends TextureRect

@onready var shader_mat := material
@export var pixel_size := 16.0
@export var lens_radius := 0.2
@export var feather := 0.05
@export var warp_speed := 5.0  # how quickly it ramps up/down

var current_warp := 0.0
var target_warp := 0.0

func _ready():
	if texture:
		shader_mat.set_shader_parameter("resolution", texture.get_size())
		shader_mat.set_shader_parameter("pixel_size", pixel_size)
		shader_mat.set_shader_parameter("lens_radius", lens_radius)
		shader_mat.set_shader_parameter("feather", feather)

func _process(delta):
	# Update mouse position
	var local_pos = get_local_mouse_position()
	var uv = local_pos / size
	shader_mat.set_shader_parameter("mouse_uv", uv)

	# Update target warp value
	target_warp = 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.00

	# Animate warp smoothly
	current_warp = lerp(current_warp, target_warp, delta * warp_speed)
	shader_mat.set_shader_parameter("warp_strength", current_warp)
