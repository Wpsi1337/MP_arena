extends Node2D

var polygon: Polygon2D
var collision_polygon: CollisionPolygon2D
var rigid_bodies: Array[RigidBody2D] = []

func _ready():
	# Get references to nodes
	polygon = $BlobBody/Polygon2D
	collision_polygon = $BlobBody/CollisionPolygon2D
	# Ensure CollisionPolygon2D is enabled
	collision_polygon.disabled = false
	# Set Polygon2D color for visibility
	polygon.color = Color(0, 1, 0, 1)  # Green
	# Define collision layers
	var blob_layer = 1 << 2  # Layer 2
	var ground_layer = 1 << 1  # Layer 1
	# Configure BlobMesh nodes
	for i in range(1, 9):
		var rb = get_node("BlobMesh" + str(i))
		rigid_bodies.append(rb)
		rb.continuous_cd = true
		rb.contact_monitor = true
		rb.max_contacts_reported = 5
		rb.collision_layer = blob_layer
		rb.collision_mask = ground_layer
		rb.get_node("CollisionShape2D").shape.radius = 7
		rb.body_entered.connect(_on_body_entered)
	# Configure BlobCenter
	var center_rb = $BlobCenter
	rigid_bodies.append(center_rb)
	center_rb.continuous_cd = true
	center_rb.contact_monitor = true
	center_rb.max_contacts_reported = 5
	center_rb.collision_layer = blob_layer
	center_rb.collision_mask = ground_layer
	center_rb.get_node("CollisionShape2D").shape.radius = 7
	# Configure BlobBody
	var blob_body = $BlobBody
	blob_body.body_entered.connect(_on_body_entered)
	blob_body.collision_layer = blob_layer
	blob_body.collision_mask = ground_layer
	blob_body.continuous_cd = true
	blob_body.contact_monitor = true
	blob_body.max_contacts_reported = 5
	blob_body.physics_material_override = PhysicsMaterial.new()
	blob_body.physics_material_override.bounce = 0.0
	blob_body.physics_material_override.friction = 0.5

func _physics_process(_delta):
	var points = PackedVector2Array()
	for i in range(1, 9):
		var rb = get_node("BlobMesh" + str(i))
		points.append(rb.position - $BlobBody.position)
	var convex_points = Geometry2D.convex_hull(points)
	if convex_points.size() >= 3:
		polygon.polygon = convex_points
		collision_polygon.polygon = convex_points

func _draw():
	pass

func _on_body_entered(body):
	if body.is_in_group("ground") or body.is_in_group("walls"):
		$BlobBody.linear_damp = 5.0
		for rb in rigid_bodies:
			rb.linear_damp = 5.0
		await get_tree().create_timer(1.0).timeout
		queue_free()
