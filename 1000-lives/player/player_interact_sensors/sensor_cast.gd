extends ShapeCast3D

@onready var update_timer :Timer = Timer.new()
@onready var player : CharacterBody3D = get_parent()
# Called when the node enters the scene tree for the first time.
func _ready():
	update_timer.timeout.connect(_on_update_timer_timeout)
	update_timer.autostart = true
	update_timer.wait_time = .1
	add_child(update_timer)
	
	player.sensor_cast = self
	collision_mask = 8
	position = Vector3(0, 0.6, 0)
	# Walking the player faces +Z (see rotate_player's atan2 yaw), and the
	# timer's look_at(..., true) also aims +Z at the interactable, so cast +Z.
	# While climbing the player faces the wall along -Z (Basis.looking_at),
	# and player_charbody3D.gd flips this to -1.5 for the dismount check.
	target_position = Vector3(0,0,1.5)



func _on_update_timer_timeout():
	## During ladder transitions/climbing the sensor must point straight ahead
	## so the dismount check in set_root_climb() sees the wall in front.
	if player.current_state != player.state.FREE:
		rotation = Vector3.ZERO
		return
	if is_instance_valid(player.interactable): # try ot maintain the currently set interacactble
		look_at(Vector3(player.interactable.global_position.x,global_position.y,player.interactable.global_position.z),Vector3.UP,true)
	if self.is_colliding():
		var body = get_collider(0)
		if is_instance_valid(body) and body.is_in_group("interactable"):
			player.interactable = body

	else: # Clear interactable and reset to looking forward
		player.interactable = null
		rotation = Vector3.ZERO
