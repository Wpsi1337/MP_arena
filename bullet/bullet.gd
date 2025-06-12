extends Area2D

var dmg = 10
var speed = 250
var velocity = Vector2()
var gravity_force = 200

func _ready():
	velocity = transform.x * speed
	set_multiplayer_authority(get_multiplayer_authority())
	if is_multiplayer_authority():
		sync_position.rpc(global_position, velocity)

func _physics_process(delta):
	if !is_multiplayer_authority():
		return
	velocity.y += gravity_force * delta
	position += velocity * delta
	sync_position.rpc(global_position, velocity)

@rpc("any_peer", "call_local", "reliable")
func sync_position(pos: Vector2, vel: Vector2):
	global_position = pos
	velocity = vel

@rpc("any_peer", "call_local", "reliable")
func _on_body_entered(body):
	if !is_multiplayer_authority():
		return
	
	if body is Player:
		var target_authority = body.get_multiplayer_authority()
		if target_authority == multiplayer.get_unique_id():
			body.take_damage(dmg)
		else:
			body.take_damage.rpc_id(body.get_multiplayer_authority(), dmg)
	
	remove_bullet.rpc()

@rpc("call_local")
func remove_bullet():
	queue_free()
