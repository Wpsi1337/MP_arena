extends Label

func _ready():
	var shader_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float ripple_speed = 2.0;
	uniform float ripple_amplitude = 0.03;
	uniform float ripple_frequency = 2.0;
	uniform vec2 label_size = vec2(100.0, 50.0);
	
	void fragment() {
		vec2 uv = UV * label_size;
		float ripple = sin(uv.x * ripple_frequency + TIME * ripple_speed) * ripple_amplitude;
		uv.y += ripple / label_size.y;
		vec4 color = texture(TEXTURE, uv / label_size);
		COLOR.rgb = color.rgb * vec3(1.0, 0.0, 0.0);
		COLOR.a = color.a;
	}
	"""
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("label_size", size)
	material = shader_mat
	print("Label size at runtime: ", size)

func _process(_delta):
	if material is ShaderMaterial:
		material.set_shader_parameter("label_size", size)
