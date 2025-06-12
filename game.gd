# game.gd
class_name Game
extends Node

@onready var multiplayer_ui = $UI/Multiplayer
@onready var status_label = $UI/Multiplayer/MainMenu/StatusLabel
@onready var game_ui = $UI/GameUI
@onready var p1_bar = $UI/GameUI/HealthBars/Player1Health/P1Bar
@onready var p2_bar = $UI/GameUI/HealthBars/Player2Health/P2Bar
@onready var p3_bar = $UI/GameUI/HealthBars/Player3Health/P3Bar
@onready var p4_bar = $UI/GameUI/HealthBars/Player4Health/P4Bar

const PLAYER = preload("res://player/player.tscn")
var peer = ENetMultiplayerPeer.new()
var players: Array[Player] = []
var player_ids: Dictionary = {} 
const PLAYER_COLORS = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.DARK_ORANGE #Braannguuul
]
func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	$MultiplayerSpawner.spawn_function = add_player
	print("Game initialized. MultiplayerSpawner configured")
	

	p1_bar.max_value = 100 
	p1_bar.value = 100
	p2_bar.max_value = 100
	p2_bar.value = 100
	p3_bar.max_value = 100 
	p3_bar.value = 100
	p4_bar.max_value = 100
	p4_bar.value = 100
	
	update_health_bar_color(p1_bar, 100, 100)
	update_health_bar_color(p2_bar, 100, 100)
	update_health_bar_color(p3_bar, 100, 100)
	update_health_bar_color(p4_bar, 100, 100)
	game_ui.hide()
	p1_bar.get_parent().hide()
	p2_bar.get_parent().hide()
	p3_bar.get_parent().hide()
	p4_bar.get_parent().hide()
	
	# Handle connection events
	multiplayer.connected_to_server.connect(
		func():
			print("Client connected to server! Peer ID: %s" % multiplayer.get_unique_id())
			status_label.text = "Connected to server!"
			if not is_multiplayer_authority():
				rpc("show_game_ui_for_all")
	)
	
	multiplayer.connection_failed.connect(
		func():
			print("Client failed to connect to server!")
			status_label.text = "Connection failed. Check IP/port or server status."
			multiplayer.multiplayer_peer = null
			peer.close()
			multiplayer_ui.show()
	)
	
	multiplayer.server_disconnected.connect(
		func():
			print("Server disconnected!")
			status_label.text = "Server disconnected. Rejoining required."
			multiplayer.multiplayer_peer = null
			peer.close()
			multiplayer_ui.show()
	)

@rpc("any_peer", "call_local", "reliable")
func show_game_ui_for_all():
	game_ui.show()
	for i in range(players.size()):
		if i == 0:
			p1_bar.get_parent().show()
		elif i == 1:
			p2_bar.get_parent().show()
		elif i == 2:
			p3_bar.get_parent().show()
		elif i == 3:
			p4_bar.get_parent().show()

func _on_host_pressed():
	var error = peer.create_server(25565)
	if error != OK:
		print("Failed to create server: %s" % error_string(error))
		status_label.text = "Failed to host: %s" % error_string(error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Server started on port 25565. Local IPs: ", IP.get_local_addresses())
	
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mapping(25565)
		print("UPnP enabled, port 25565 opened")
	else:
		print("UPnP setup failed, ensure port 25565 is forwarded manually")
	
	multiplayer.peer_connected.connect(
		func(pid):
			print("Peer %s has joined the game!" % pid)
			$MultiplayerSpawner.spawn(pid)
			rpc("show_game_ui_for_all")
	)
	await get_tree().process_frame
	$MultiplayerSpawner.spawn(multiplayer.get_unique_id())
	multiplayer_ui.hide()
	status_label.text = "Hosting server..."

func _on_join_pressed():
	var ip_address = $UI/Multiplayer/MainMenu/IPInput.text.strip_edges()
	if ip_address.is_empty():
		ip_address = "localhost"
		$UI/Multiplayer/MainMenu/IPInput.text = ip_address
	
	print("Attempting to connect to %s:25565" % ip_address)
	status_label.text = "Connecting to %s..." % ip_address
	
	var error = peer.create_client(ip_address, 25565)
	if error != OK:
		print("Failed to create client: %s" % error_string(error))
		status_label.text = "Failed to create client: %s" % error_string(error)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer_ui.hide()
	await multiplayer.connected_to_server
	rpc("show_game_ui_for_all")

func add_player(pid):
	print("Spawning player with peer ID: %s" % pid)
	var player = PLAYER.instantiate()
	player.name = str(pid)
	var player_index = players.size()
	player_ids[pid] = player_index
	player.global_position = $Level.get_child(player_index % $Level.get_child_count()).global_position
	players.append(player)
	# Sync player_ids to all peers
	if is_multiplayer_authority():
		rpc("sync_player_ids", player_ids)
	# Assign color after player is ready
	var color_index = player_index % 4
	var assign_color = func():
		if is_instance_valid(player) and is_instance_valid(player.sprite):
			player.rpc("set_player_color", PLAYER_COLORS[color_index])
		else:
			print("Player %s or sprite invalid when assigning color" % pid)
			# Retry after a short delay
			var retry_timer = Timer.new()
			retry_timer.wait_time = 0.1
			retry_timer.one_shot = true
			retry_timer.timeout.connect(func():
				if is_instance_valid(player) and is_instance_valid(player.sprite):
					player.rpc("set_player_color", PLAYER_COLORS[color_index])
				else:
					print("Retry failed: Player %s or sprite still invalid" % pid)
				retry_timer.queue_free()
			)
			add_child(retry_timer)
			retry_timer.start()
	player.ready.connect(assign_color, CONNECT_ONE_SHOT)
	# Connect health_changed signal
	player.health_changed.connect(
		func(player_id: int, health: int):
			if is_multiplayer_authority():
				if player_id in player_ids:
					print("Health changed for player %s: %s" % [player_id, health])
					_on_player_health_changed.rpc(player_id, health)
				else:
					print("Health changed ignored: Player ID %s not in player_ids" % player_id)
	)
	# Initialize healthbar after player is ready
	if is_multiplayer_authority():
		player.ready.connect(func():
			if is_instance_valid(player) and pid in player_ids:
				print("Initializing healthbar for player %s: %s" % [pid, player.health])
				_on_player_health_changed.rpc(pid, player.health)
			else:
				print("Player %s invalid or not in player_ids when initializing healthbar" % pid)
		, CONNECT_ONE_SHOT)
	return player

@rpc("authority", "call_local", "reliable")
func sync_player_ids(ids: Dictionary):
	player_ids = ids
	print("Player IDs synced: %s" % player_ids)

@rpc("any_peer", "call_local", "reliable")
func _on_player_health_changed(player_id: int, health: int):
	print("Health RPC received for player %s: %s" % [player_id, health])
	var player_index = player_ids.get(player_id, -1)
	if player_index == -1:
		print("Error: Player ID %s not found in player_ids" % player_id)
		return
	
	# Update healthbars based on player index
	match player_index:
		0:
			p1_bar.value = health
			update_health_bar_color(p1_bar, health, 100)
			p1_bar.get_parent().show()
			print("Updated P1 healthbar: %s" % health)
		1:
			p2_bar.value = health
			update_health_bar_color(p2_bar, health, 100)
			p2_bar.get_parent().show()
			print("Updated P2 healthbar: %s" % health)
		2:
			p3_bar.value = health
			update_health_bar_color(p3_bar, health, 100)
			p3_bar.get_parent().show()
			print("Updated P3 healthbar: %s" % health)
		3:
			p4_bar.value = health
			update_health_bar_color(p4_bar, health, 100)
			p4_bar.get_parent().show()
			print("Updated P4 healthbar: %s" % health)

func update_health_bar_color(progress_bar: ProgressBar, current_health: int, max_health: int):
	var health_percent = float(current_health) / float(max_health)
	var bar_color = Color.RED.lerp(Color.GREEN, health_percent)
	progress_bar.modulate = bar_color

func get_random_spawnpoint():
	return $Level.get_children().pick_random().global_position
