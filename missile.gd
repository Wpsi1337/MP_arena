extends Area2D


var speed = 320
var velocity = Vector2()
var gravity_force = 250
var has_collided = false
#syncing physics every 50 frame
var sync_timer = 0.0
var sync_interval = 0.05

@export var explosion_radius: float = 80.0
@export var max_damage: int = 25

func _ready():
	velocity = transform.x * speed
	$TrailParticles.emitting = true
	$CollisionShape2D.disabled = false
	monitoring = true
	monitorable = true
	print("Body entered on peer ", multiplayer.get_unique_id(), " authority: ", is_multiplayer_authority())
	set_multiplayer_authority(multiplayer.get_unique_id())
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	print("Missile %s: Spawned on peer %d" % [name, multiplayer.get_unique_id()])
	
func _physics_process(delta):
	velocity.y += gravity_force * delta
	if not has_collided and is_instance_valid(self):
		position += velocity * delta
		rotation = velocity.angle()
		var trail_particles = $TrailParticles
		if trail_particles and is_instance_valid(trail_particles):
			trail_particles.emitting = true
	
			
@rpc("any_peer")
func sync_rotation(rot: float):
	if is_instance_valid(self) and not has_collided:
		rotation = rot
@rpc("any_peer")
func sync_position(pos: Vector2):
	if is_instance_valid(self) and not has_collided:
		global_position = pos


@rpc("any_peer", "call_local")
func _on_body_entered(body):
	if not is_instance_valid(self):
		return
	has_collided = true
	# Debug collision
	print("Missile %s: Collided with %s on peer %d" % [name, body.name, multiplayer.get_unique_id()])
	rpc("set_collided")  # Synchronize has_collided across peers
	rpc("trigger_explosion")
	
	if is_multiplayer_authority():
		apply_area_damage()
		rpc("remove_missile_rpc")


@rpc("any_peer", "call_local")
func set_collided():
	has_collided = true

func apply_area_damage():
	print("applying area damage at position: ", global_position)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	query.set_shape(shape)
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 1
	var results = space_state.intersect_shape(query)
	print("Found ", results.size(), " colliders")
	for result in results:
		var collider = result.collider
		print("found ", results.size(), " colliders")
		if collider is Player:
			var distance = global_position.distance_to(collider.global_position)
			print("Player ", collider.name, " at distance: ", distance)
			if distance <= explosion_radius:
				var damage = calculate_damage(distance)
				print("Calculated damage: ", damage, " for player ", collider.name)
				var target_authority = collider.get_multiplayer_authority()
				if target_authority == collider.multiplayer.get_unique_id():
					collider.take_damage(damage)
				else:
					collider.take_damage.rpc_id(target_authority, damage)
 
		
func calculate_damage(distance: float) -> int:
	var damage = max_damage * (1 - distance / explosion_radius)
	return int(max(damage, 0))
			
@rpc("any_peer", "call_local")
func trigger_explosion():
	print("Explosion at position: ", global_position)
	var trail_particles = $TrailParticles
	if trail_particles:
		print("Missile %s: Detaching TrailParticles on peer %d" % [name, multiplayer.get_unique_id()])
		remove_child(trail_particles)
		get_tree().root.add_child(trail_particles)
		trail_particles.global_position = global_position
		trail_particles.emitting = false
		trail_particles.one_shot = true
		get_tree().create_timer(trail_particles.lifetime).timeout.connect(func():
			if is_instance_valid(trail_particles):
				trail_particles.queue_free()
		)
	
# Trigger audio playback only on the authority
	if is_multiplayer_authority():
		var explosion_pos = global_position
		var server_time = Time.get_ticks_msec() / 1000.0  # Server timestamp in seconds
		rpc("play_explosion_audio", explosion_pos, server_time)
	
	if is_instance_valid($ExplosionParticle):
		$ExplosionParticle.emitting = true
		print("explosionparticle happens here")
	else:
		print("Missile %s: ExplosionParticle invalid" % name)
	if is_instance_valid($Sprite2D):
		$Sprite2D.hide()
	else:
		print("Missile %s: Sprite2D invalid" % name)
	$CollisionShape2D.set_deferred("disabled", true)

@rpc("any_peer", "call_local")
func play_explosion_audio(pos: Vector2, server_time: float):
	print("Missile %s: Playing explosion audio on peer %d at position %s" % [name, multiplayer.get_unique_id(), pos])
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_diff = current_time - server_time
	print("Missile %s: Audio time_diff on peer %d: %f seconds" % [name, multiplayer.get_unique_id(), time_diff])
	
	var explosion_audio = AudioStreamPlayer2D.new()
	explosion_audio.stream = load("res://player/explosion-fx-343683.mp3")  # Replace with your audio file path
	if not explosion_audio.stream:
		print("Missile %s: Failed to load explosion audio on peer %d" % [name, multiplayer.get_unique_id()])
		return
	
	explosion_audio.global_position = pos
	explosion_audio.volume_db = -10.0
	explosion_audio.max_distance = 1000.0
	get_tree().root.add_child(explosion_audio)
	
	var audio_length = explosion_audio.stream.get_length()
	if time_diff < audio_length and time_diff >= 0:
		print("Missile %s: Playing audio with offset %f on peer %d" % [name, time_diff, multiplayer.get_unique_id()])
		explosion_audio.play(time_diff)
	else:
		print("Missile %s: Playing audio immediately on peer %d (time_diff: %f)" % [name, multiplayer.get_unique_id(), time_diff])
		explosion_audio.play()
	
	get_tree().create_timer(max(audio_length - time_diff, 0.1)).timeout.connect(func():
		if is_instance_valid(explosion_audio):
			explosion_audio.queue_free()
			print("Missile %s: Explosion audio freed on peer %d" % [name, multiplayer.get_unique_id()])
	)


func remove_missile():
	rpc("remove_missile_rpc")

@rpc("any_peer", "call_local")
func remove_missile_rpc():
	if is_instance_valid(self):
		# Stop physics and interactions
		set_physics_process(false)

		$CollisionShape2D.set_deferred("disabled", true)
		# Notify peers to stop processing
		has_collided = true
		# Minimal delay to ensure RPCs are processed
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self):
			print("Missile %s: Removed on peer %d" % [name, multiplayer.get_unique_id()])
			call_deferred("queue_free")
