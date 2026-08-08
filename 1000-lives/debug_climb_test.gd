extends SceneTree

var world: Node
var player: Node
var ladder: Node
var frame := 0
var phase := 0
var target_ladder := "Ladder2"
var started := false

func _initialize():
	world = (load("res://demo_level/world_castle.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_delta):
	frame += 1
	if phase == 0 and frame >= 60:
		player = world.get_node("PlayerCharacterBodySoulsBase")
		ladder = world.get_node("Interactables/" + target_ladder)
		print("=== ", target_ladder, " at ", ladder.global_position)
		var ap = player.get_node("minnyquinn/AnimationPlayer")
		var anim = ap.get_animation("MeleeLib/root-LadderClimbing")
		print("root-LadderClimbing length=", anim.length, " tracks=", anim.get_track_count())
		for i in anim.get_track_count():
			var tp = anim.track_get_path(i)
			if str(tp).find("Root") >= 0:
				print("   Root track ", i, " type=", anim.track_get_type(i), " keys=", anim.track_get_key_count(i))
				for k in anim.track_get_key_count(i):
					print("      t=", anim.track_get_key_time(i, k), " v=", anim.track_get_key_value(i, k))
		player.global_position = ladder.global_position + Vector3(1.5, 0, 0)
		phase = 1
	elif phase == 1 and frame >= 90:
		print("ACTIVATE")
		var pb = player.animation_tree.get("parameters/MovementStates/playback")
		pb.start("SLASH_tree")
		ladder.activate(player)
		phase = 2
	elif phase == 2:
		if player.current_state == player.state.CLIMB and not started:
			started = true
			print("CLIMB started at f", frame, " pos=", player.global_position)
			Input.action_press("move_up")
		if player.current_state == player.state.CLIMB and frame % 3 == 0:
			var pb = player.animation_tree.get("parameters/MovementStates/playback")
			print("   rootmotion=", player.animation_tree.get_root_motion_position(), " scale=", player.animation_tree.get("parameters/MovementStates/LADDER_tree/LadderTime/scale"), " st=", pb.get_current_node())
		if frame % 5 == 0:
			var s = player.sensor_cast
			var coll = "no"
			if s and s.is_colliding():
				var b = s.get_collider(0)
				coll = "YES:" + str(b) if b else "YES"
			print("f", frame, " pos=", Vector3(round(player.global_position.x * 100) / 100.0, round(player.global_position.y * 100) / 100.0, round(player.global_position.z * 100) / 100.0), " state=", player.current_state, " coll=", coll, " floor=", player.is_on_floor())
		if frame > 420:
			quit(0)
	return false
