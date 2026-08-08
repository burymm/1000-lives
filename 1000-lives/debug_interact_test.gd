extends SceneTree

var world: Node
var player: Node
var chest: Node
var door: Node
var frame := 0
var phase := 0
var reported_detect := false

func _initialize():
	world = (load("res://demo_level/world_castle.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_delta):
	frame += 1
	if phase == 0 and frame >= 40:
		player = world.get_node("PlayerCharacterBodySoulsBase")
		player.current_state = player.state.FREE
		player.global_position = Vector3(-6.5, 0, 2.39)
		player.global_rotation = Vector3.ZERO
		chest = (load("res://interactable objects/chest/chest.tscn") as PackedScene).instantiate()
		chest.global_position = Vector3(-6.5, 0, 3.6)
		world.add_child(chest)
		print("CHEST placed at ", chest.global_position)
		phase = 1
	elif phase == 1:
		var s = player.sensor_cast
		if s and s.is_colliding() and not reported_detect:
			var b = s.get_collider(0)
			print("f", frame, " SENSOR HIT ", b, " is_interactable=", b.is_in_group("interactable"))
			reported_detect = true
		if not reported_detect and frame % 10 == 0:
			print("f", frame, " no hit yet; interactable=", player.interactable)
		if frame >= 100 and not reported_detect:
			print("FAIL: sensor never hit the chest")
			quit(1)
		elif reported_detect and frame >= 120:
			player.interact()
			print("INTERACT called at f", frame)
			phase = 2
	elif phase == 2:
		if frame % 20 == 0:
			print("f", frame, " chest.opened=", chest.opened, " anim=", chest.chest_anim_player.get_current_animation(), " is_playing=", chest.chest_anim_player.is_playing(), " interactable=", player.interactable)
		if frame >= 320 and frame % 5 == 0:
			chest.queue_free()
			door = (load("res://interactable objects/doors/door_object.tscn") as PackedScene).instantiate()
			door.global_position = Vector3(-6.5, 0, 5.0)
			world.add_child(door)
			player.interactable = null
			player.global_position = Vector3(-6.5, 0, 3.9)
			player.global_rotation = Vector3.ZERO
			print("DOOR placed at ", door.global_position, " player=", player.global_position)
			phase = 3
	elif phase == 3:
		if frame % 20 == 0:
			print("f", frame, " door.opened=", door.opened, " anim=", door.door_anim_player.get_current_animation(), " is_playing=", door.door_anim_player.is_playing(), " interactable=", player.interactable)
		if frame >= 400 and frame % 5 == 0:
			player.interact()
			print("INTERACT door called at f", frame)
		if frame > 560:
			print("RESULT door opened=", door.opened)
			quit(0)
	return false
