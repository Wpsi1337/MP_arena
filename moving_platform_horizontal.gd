extends TileMapLayer

@export var vertical_offset: float = 90.0  
@export var period: float = 10.0 

var start_pos: Vector2
var end_pos: Vector2
var speed: float
var elapsed_time: float = 0.0

func _enter_tree():
	set_multiplayer_authority(1)

func _ready():
	start_pos = position
	end_pos = position + Vector2(vertical_offset, 0) 
	speed = 2 * PI / period

func _process(delta):
	if is_multiplayer_authority():
		elapsed_time += delta
		var phase = (1 - cos(elapsed_time * speed)) / 2
		position = start_pos.lerp(end_pos, phase)
		rpc("sync_platform_position", position)

@rpc("authority", "call_local", "reliable")
func sync_platform_position(pos: Vector2):
	position = pos
