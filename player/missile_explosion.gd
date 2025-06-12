extends Node2D

@onready var audio_player = $Explosion
@onready var particles = $ExplosionParticle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if particles:
		particles.emitting = true
		particles.finished.connect(_on_particles_finished)
		
	if audio_player:
		audio_player.play()
		
	var cleanup_time = 2.0
	if particles:
		var lifetime = particles.lifetime
		var preprocess = particles.preprocess
		cleanup_time = lifetime + preprocess + 0.5
		
	get_tree().create_timer(cleanup_time).timeout.connect(queue_free)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_particles_finished():
	queue_free()
