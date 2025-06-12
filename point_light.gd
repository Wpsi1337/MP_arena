extends PointLight2D

@onready var point_light = $"."
var start_pos = Vector2(-623.0, -271.0)
var end_pos = Vector2(-150.0, -271.0)
var t = 0.0
var duration = 60
var moving_to_end = true

func _process(delta:):
	if is_multiplayer_authority():
		t += delta / duration
		if t > 1.0:
			t = 0.0	
			moving_to_end = not moving_to_end
		var lerp_t = t if moving_to_end else 1.0 - t
		point_light.position = start_pos.lerp(end_pos, lerp_t)
		rpc("sync_light_position", point_light.position)
			
@rpc("authority", "call_local", "reliable")
func sync_light_position(pos: Vector2):
	point_light.position = pos
