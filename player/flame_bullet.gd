
class_name Flamer
extends RigidBody2D

const SPEED = 200.0
const DAMAGE = 0.5
const LIFETIME = 1.5


@onready var timer = $DespawnTimer
@onready var collision_shape = $CollisionShape2D

func _ready():
	# Enable contact monitoring
	contact_monitor = true
	max_contacts_reported = 10
	
	# Set up timer
	timer.wait_time = LIFETIME
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	
	# Set initial velocity
	linear_velocity = Vector2(SPEED, 0).rotated(rotation)
	
	# Connect collision detection
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Prevent self-damage and ensure it's a player
	if body.has_method("take_damage") and body.name != str(get_multiplayer_authority()):
		if is_multiplayer_authority():  # Only authority deals damage
			body.take_damage.rpc(DAMAGE)
		queue_free()  # Remove bullet immediately

func _on_timer_timeout():
	queue_free()
