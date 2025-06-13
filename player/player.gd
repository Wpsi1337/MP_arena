class_name Player
extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -250.0
const MIN_JUMP_VELOCITY = -50
const JUMP_CUT_MULTIPLIER = 0.3
const MAX_HEALTH = 100

const BLOOD = preload("res://player/blood_drop.tscn")
const BULLET = preload("res://bullet/bullet.tscn")
const FLAME_BULLET = preload("res://player/flame_bullet.tscn")
const MISSILE = preload("res://player/missile.tscn")
const ROCKET_LAUNCHER = preload("res://player/rocket_launcher_container.tscn")
const FLAMETHROWER = preload("res://player/flamethrower_container.tscn")
const GUN = preload("res://player/gun_container.tscn")

var current_weapon_index = 0
var current_weapon_node = null
var can_shoot = true
@export var fire_rate = 1.0
var health = MAX_HEALTH
var is_jumping = false
var jump_count = 0
@export var max_jumps = 2

#missile stuff
var can_shoot_missile = true
var missile_cooldown_timer = 0.0
const MISSILE_COOLDOWN = 5.0

#footstep timer
@onready var step_timer = $Sounds/StepTimer
var current_footstep = 0
var footsteps_playing = false
var step_interval = 0.1
#respawn stuff
var respawn_timer: Timer
var is_dead = false
var is_invulnerable = false
var invulnerability_timer: Timer
var player_color: Color

	
@onready var game: Game = get_parent()
@onready var stains = $Blood
@onready var poof = $WindGust
@onready var shimmer = $Shimmer
@onready var out_of_bounds_area: Area2D
@onready var sprite = $Sprite2D
@onready var death_effect = $DeathEffect

signal health_changed(player_id: int, health: int)

func _enter_tree():
	set_multiplayer_authority(int(str(name)))
	if get_parent():
		get_parent().name = "Game"

func _ready():
	step_timer.wait_time = step_interval
	step_timer.timeout.connect(_play_footstep)
	respawn_timer = Timer.new()
	respawn_timer.wait_time = 3.0
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	add_child(respawn_timer)
	
	invulnerability_timer = Timer.new()
	invulnerability_timer.wait_time = 0.3
	invulnerability_timer.one_shot = true
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(invulnerability_timer)
	
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		var areas = get_tree().get_nodes_in_group("out_of_bounds")
		if areas.size() > 0:
			out_of_bounds_area = areas[0] as Area2D
			out_of_bounds_area.body_entered.connect(_on_out_of_bounds_entered)
		# Delay health signal to ensure server registration
		await get_tree().create_timer(0.5).timeout
		if get_parent().player_ids.has(int(str(name))):
			health_changed.emit(int(str(name)), health)
			get_parent()._on_player_health_changed.rpc(int(str(name)), health)
		else:
			print("Delayed health signal skipped: Player ID %s not in player_ids" % name)
	
	setup_weapons()

@rpc("any_peer", "call_local", "reliable")
func set_player_color(color: Color):
	if is_instance_valid(sprite):
		player_color = color
		sprite.modulate = player_color
		print("Player %s on peer %d set to color %s" % [name, multiplayer.get_unique_id(), player_color])
	else:
		print("Sprite2D invalid for player %s on peer %d" % [name, multiplayer.get_unique_id()])
		# Retry color assignment after a short delay
		var retry_timer = Timer.new()
		retry_timer.wait_time = 0.1
		retry_timer.one_shot = true
		retry_timer.timeout.connect(func():
			if is_instance_valid(sprite):
				sprite.modulate = color
				print("Retry succeeded: Player %s on peer %d set to color %s" % [name, multiplayer.get_unique_id(), color])
			else:
				print("Retry failed: Sprite2D still invalid for player %s on peer %d" % [name, multiplayer.get_unique_id()])
			retry_timer.queue_free()
		)
		add_child(retry_timer)
		retry_timer.start()

	setup_weapons()
func _process(delta):
	if not can_shoot_missile:
		missile_cooldown_timer -= delta
		if missile_cooldown_timer <= 0.0:
			can_shoot_missile = true
			
func setup_weapons():
	if has_node("GunContainer"):
		$GunContainer.queue_free()
	
	switch_weapons(0)

@rpc("call_local")
func switch_weapons(index):
	if current_weapon_node:
		if current_weapon_index == 1:  # Stop flamethrower sound if switching from flamethrower
			stop_flamethrower_sound()
		remove_child(current_weapon_node)
		current_weapon_node.queue_free()
		current_weapon_node = null
	
	match index:
		0: # gun
			current_weapon_node = GUN.instantiate()
		1: # flamethrower
			current_weapon_node = FLAMETHROWER.instantiate()
		2: #new cool and fancy weapon
			current_weapon_node = ROCKET_LAUNCHER.instantiate()
	add_child(current_weapon_node)
	current_weapon_index = index
	if is_dead:
		current_weapon_node.hide()
func fire_current_weapon():
	match current_weapon_index:
		0: # gun
			shoot.rpc(multiplayer.get_unique_id())
		1: # flamethrower
			flamethrower_shoot.rpc(multiplayer.get_unique_id())
		2: # rocket launcher
			if can_shoot_missile:
				rocket_shoot.rpc(multiplayer.get_unique_id())
				can_shoot_missile = false
				missile_cooldown_timer = MISSILE_COOLDOWN


func _physics_process(delta):
	if !is_multiplayer_authority():
		return
		
	if Input.is_action_just_pressed("weapon_1") and !is_dead:
		switch_weapons.rpc(0)
	elif Input.is_action_just_pressed("weapon_2") and !is_dead:
		switch_weapons.rpc(1)
	elif Input.is_action_just_pressed("weapon_3") and !is_dead:
		switch_weapons.rpc(2)
		
	if current_weapon_node:
		var mouse_pos = get_global_mouse_position()
		sync_weapon_rotation.rpc(mouse_pos)
	
	
	if is_multiplayer_authority():
		if Input.is_action_pressed("shoot") and !is_dead:
			var can_fire = true
			if current_weapon_index == 2 and not can_shoot_missile:
				can_fire = false
			
			if can_fire and can_shoot:
				fire_current_weapon()
				can_shoot = false
				
				var cooldown_time = fire_rate
				match current_weapon_index:
					0: cooldown_time = 0.25 # gun
					1: cooldown_time = 0.05 # flame
					2: cooldown_time = 0.5  # rocket
					
				get_tree().create_timer(cooldown_time).timeout.connect(_reset_shoot_cooldown)

			if current_weapon_index == 1:
				start_flamethrower_sound()
		else:
			if current_weapon_index == 1:
				stop_flamethrower_sound()

	if ! is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and jump_count < max_jumps and !is_dead:
		if jump_count == 0:
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = JUMP_VELOCITY * 0.751
			play_poof_effect.rpc()
			$Sounds/JumpSound.pitch_scale = randf_range(0.8, 1.2)
			$Sounds/JumpSound.play()
		jump_count += 1
		is_jumping = true
		

	

	if is_jumping and Input.is_action_just_released("jump"):
		if velocity.y < MIN_JUMP_VELOCITY:  
			velocity.y *= JUMP_CUT_MULTIPLIER
		is_jumping = false
		
	if is_on_floor() and velocity.y >= 0:
		is_jumping = false
		jump_count = 0

	var direction = Input.get_axis("left", "right")
	if direction and !is_dead:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	var should_play_footsteps = direction != 0 and not is_dead and is_on_floor()
	if should_play_footsteps and not footsteps_playing:
		footsteps_playing = true
		_play_footstep()
		step_timer.start()
	elif not should_play_footsteps and footsteps_playing:
		footsteps_playing = false
		step_timer.stop()
	move_and_slide()
		
		
func _reset_shoot_cooldown():
	can_shoot = true
func _play_footstep():
	if not footsteps_playing or is_dead:
		return
	var footstep1 = find_child("Step1")
	var footstep2 = find_child("Step2")
	if current_footstep == 0 and footstep1:
		footstep1.pitch_scale = randf_range(1.8, 2.1)
		footstep1.play()
		current_footstep = 1
	elif current_footstep == 1 and footstep2:
		footstep2.pitch_scale = randf_range(1.8, 2.1)
		footstep2.play()
		current_footstep = 0
@rpc("call_local", "unreliable")
func sync_weapon_rotation(mouse_position: Vector2):
	if current_weapon_node:
		current_weapon_node.look_at(mouse_position)
		
		var weapon_sprite
		match current_weapon_index:
			0: # gun
				weapon_sprite = current_weapon_node.get_node("GunSprite")
			1: # flamethrower
				weapon_sprite = current_weapon_node.get_node("FlameThrowerSprite")
			2: weapon_sprite = current_weapon_node.get_node("RocketLauncherSprite")
		if weapon_sprite:
			if mouse_position.x < global_position.x:
				weapon_sprite.flip_v = true
			else:
				weapon_sprite.flip_v = false
			if sprite:
				if mouse_position.x < global_position.x:
					sprite.flip_h = true
				else:
					sprite.flip_h = false
			
func _on_out_of_bounds_entered(body: Node):
	if body == self and is_multiplayer_authority() and not is_invulnerable:
		take_damage(health)
		print("out of bounds")
@rpc("call_local")
func shoot(shooter_pid):
	if current_weapon_node and current_weapon_index == 0:
		var bullet = BULLET.instantiate()
		bullet.set_multiplayer_authority(shooter_pid)
		get_parent().call_deferred("add_child", bullet)
		
		
		var muzzle = current_weapon_node.find_child("Muzzle")  
		if muzzle:
			bullet.transform = muzzle.global_transform
			
		if is_multiplayer_authority():
			var shoot_sound = current_weapon_node.find_child("gun_sound")
			if shoot_sound:
				shoot_sound.play()
		
		var muzzle_flash = current_weapon_node.find_child("MuzzleFlash")  
		if not muzzle_flash:
			muzzle_flash = current_weapon_node.find_child("MuzzleFlash")  
		
		if muzzle_flash:
			muzzle_flash.emitting = true

		

@rpc("call_local")
func flamethrower_shoot(shooter_pid):
	if current_weapon_node and current_weapon_index == 1:
		# Spawn multiple flame bullets for spread effect
		var flame_count = 25
		for i in range(flame_count):
			var flame = FLAME_BULLET.instantiate()
			flame.set_multiplayer_authority(shooter_pid)
			flame.name = "FlameBullet_" + str(i) + "_" + str(randi())
			get_parent().call_deferred("add_child", flame)

			var muzzle = current_weapon_node.find_child("Muzzle")
			if muzzle:
				flame.global_position = muzzle.global_position
				# Add spread to flame direction
				var spread_angle = randf_range(-0.3, 0.3)  # Random spread
				flame.rotation = muzzle.global_rotation + spread_angle
			else:
				flame.global_position = current_weapon_node.global_position
				flame.rotation = current_weapon_node.rotation
			
					
		var muzzle_flash = current_weapon_node.find_child("MuzzleFlash")
		if not muzzle_flash:
			muzzle_flash = current_weapon_node.find_child("MuzzleFlash")
		if muzzle_flash:
			muzzle_flash.emitting = true

@rpc("call_local")
func rocket_shoot(shooter_pid):
	if current_weapon_node and current_weapon_index == 2:
		var missile = MISSILE.instantiate()
		missile.set_multiplayer_authority(shooter_pid)
		missile.name = "Missile_" + str(randi())
		get_parent().call_deferred("add_child", missile)
		
		var muzzle = current_weapon_node.find_child("Muzzle")
		if muzzle:
			missile.global_position = muzzle.global_position
			missile.rotation = muzzle.global_rotation
		else:
			missile.global_position = current_weapon_node.global_position
			missile.rotation = current_weapon_node.rotation
			
		if is_multiplayer_authority():
			var rocket_sound = current_weapon_node.find_child("rocket_sound")
			if rocket_sound:
				rocket_sound.play()
				
		var muzzle_flash = current_weapon_node.find_child("MuzzleFlash")
		if muzzle_flash:
			muzzle_flash.emitting = true
			
func start_flamethrower_sound():
	if current_weapon_node and current_weapon_index == 1:
		var flamethrower_sound = current_weapon_node.find_child("flamethrower_sound")
		if flamethrower_sound:
			if not flamethrower_sound.playing:
				if flamethrower_sound.stream:
					flamethrower_sound.stream.loop = true
				flamethrower_sound.play()
		else:
			print("Error: flamethrower_sound node not found")
		
		var crackle_sound = current_weapon_node.find_child("crackle_sound")
		if crackle_sound:
			if not crackle_sound.playing:
				if crackle_sound.stream:
					crackle_sound.stream.loop = true
				crackle_sound.play()
		else:
			print("Error: crackle_sound node not found")

func stop_flamethrower_sound():
	if current_weapon_node and current_weapon_index == 1:
		var flamethrower_sound = current_weapon_node.find_child("flamethrower_sound")
		if flamethrower_sound and flamethrower_sound.playing:
			flamethrower_sound.stop()
		
		var crackle_sound = current_weapon_node.find_child("crackle_sound")
		if crackle_sound and crackle_sound.playing:
			crackle_sound.stop()



@rpc("call_local")
func fblood(blood_pid):
	var blood_count = 2
	for i in range(blood_count):
		var blood = BLOOD.instantiate()
		blood.set_multiplayer_authority(blood_pid)
		blood.name = "BloodDrop_" + str(i) + "_" + str(randi())
		get_parent().call_deferred("add_child", blood)
		blood.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		blood.rotation = 0
		if blood.has_method("set_velocity"):
			var random_velocity = Vector2(randf_range(-50, 50), randf_range(-100, -50))
			blood.set_velocity(random_velocity)

@rpc("any_peer", "reliable", "call_local")
func take_damage(amount):
	print("take_damage called on peer ", multiplayer.get_unique_id(), " for player ", name, " with amount ", amount)
	if ! is_multiplayer_authority():
		return
	health -= amount
	print("Health now: ", health)
	play_blood_effect.rpc()
	fblood.rpc(multiplayer.get_unique_id())
	health_changed.emit(int(str(name)), health)
	if health <= 0:
		is_dead = true
		set_collision_layer_value(1,false)
		set_collision_mask_value(1,false)
		sprite.hide() # FIX sprite update after death
		if current_weapon_node:
			current_weapon_node.hide()
			play_death_effect.rpc()
			var splat_sound = $Sounds/Splat
			if splat_sound:
				splat_sound.play()
		respawn_timer.start()
		rpc("sync_dead_state", is_dead)
	get_parent()._on_player_health_changed.rpc(int(str(name)), health)
	
@rpc("any_peer", "reliable")
func _on_respawn_timer_timeout():
	health = MAX_HEALTH
	is_dead = false
	is_invulnerable = true
	invulnerability_timer.start()
	shimmer.emitting = true
	set_collision_layer_value(1,true)
	set_collision_mask_value(1, true)
	sprite.show() # fix sprite show on respawn over peer
	if player_color != Color(0, 0, 0,):
		sprite.modulate = player_color
	else:
		print("warning: player_color not set for %s on respawn")
	global_position = game.get_random_spawnpoint()
	health_changed.emit(int(str(name)), health)
	get_parent()._on_player_health_changed.rpc(int(str(name)), health)
	rpc("sync_dead_state", is_dead)

func _on_invulnerability_timeout():
	is_invulnerable = false
	print(Player , name, " invulnerability ended")
	
@rpc("authority","call_local","reliable")
func sync_dead_state(dead: bool):
	is_dead = dead
	if dead:
		sprite.hide()
		if current_weapon_node:
			current_weapon_node.hide()
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
	else:
		sprite.show()
		if current_weapon_node:
			current_weapon_node.show()
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		
func play_shimmer_effect():
	shimmer.emitting = true
	
@rpc("call_local")
func play_blood_effect():
	stains.emitting = true

@rpc("call_local")
func play_poof_effect():
	poof.emitting = true
	
@rpc("call_local")
func play_death_effect():
	death_effect.global_position = global_position
	death_effect.emitting = true

	
	

func can_fire_missile() -> bool:
	return can_shoot_missile
	
func get_missile_cooldown_remaining() -> float:
	if can_shoot_missile:
		return 0.0
	return missile_cooldown_timer
