extends GPUParticles2D

func _ready():
	var material = process_material as ParticleProcessMaterial
	material.set_use_custom(true)  # Enable Use Custom
	material.set_initial_custom(Vector4(0.0, 0.0, 0.0, 0.0,))
