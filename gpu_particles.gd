extends GPUParticles2D

func _ready():
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type particles;
	void vertex() {
		VELOCITY.x += sin(TIME) * 10.0;
		COLOR.a = 1.0 - (LIFETIME / LIFETIME_MAX);
	}
	"""
	material.shader = shader
	process_material = material
	emitting = true # Ensure partic
