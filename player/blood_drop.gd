extends RigidBody2D

const LIFETIME = 3.0  # Blood drops last a bit longer than bullets

@onready var timer = $DespawnTimer
@onready var collision_shape = $CollisionShape2D

var initial_velocity: Vector2

func _ready():
	# Set up timer
	timer.wait_time = LIFETIME
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	
	# Set physics properties for blood splatter
	gravity_scale = 1.0  # Affected by gravity
	linear_damp = 0.5    # Some air resistance
	angular_damp = 2.0   # Dampens rotation
	
	# Enable contact monitoring for ground collision
	contact_monitor = true
	max_contacts_reported = 5
	
	# Connect to collision for ground splatter effect
	body_entered.connect(_on_body_entered)

func set_velocity(velocity: Vector2):
	initial_velocity = velocity
	linear_velocity = velocity

func _on_body_entered(body):
	# When blood hits ground or walls, reduce bounce and add some randomness
	if body != self:
		linear_velocity *= 0.3  # Reduce velocity on impact
		angular_velocity *= 0.5
		
		# Add slight random bounce for more realistic splatter
		linear_velocity += Vector2(randf_range(-20, 20), randf_range(-10, 0))

func _on_timer_timeout():
	# Fade out effect before despawning (optional)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
