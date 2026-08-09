extends Node
## ItemIcons — auto-generates 2D inventory icons from 3D item scenes at runtime.
##
## No separate 2D textures are needed: for every ItemResource that has a
## physical_instance (its 3D scene) this autoload renders a snapshot of that
## scene into an off-screen SubViewport and caches it. The menu always shows the
## rendered 3D model. Items that share a scene (and weight) share the icon.
##
## Usage from UI code:
##     item_texture.texture = ItemIcons.get_icon(current_item)
##
## Renders are strictly serialised (one SubViewport at a time) and each captured
## frame is validated to contain visible content, so icons never leak pixels from
## a concurrent or not-yet-rendered viewport. Hand-authored textures are used
## only as a fallback while the render for an item is pending.

signal icon_ready

const ICON_SIZE := 160
const ITEMS_DIR := "res://player/item_system/items/"

## Cached generated icons, keyed by 3D scene path + item weight.
var _cache : Dictionary = {}
## Scenes still waiting to be rendered (one at a time).
var _queue : Array = []
## True while a render job is in flight, so new requests only append to the queue.
var _busy : bool = false

func _ready():
	call_deferred("_prewarm_all")

## Returns the icon for an item: the runtime-rendered snapshot of its 3D scene
## (cached once per scene + weight), so the menu always shows the real model.
## A hand-authored `texture` is only a temporary fallback while the first
## render is still pending. Returns null if the item has neither a scene nor a
## texture.
func get_icon(item) -> Texture2D:
	if item == null:
		return null
	var scene : PackedScene = item.physical_instance
	if scene == null:
		return item.texture if item.texture != null else null
	var key : String = _key_for(scene, item)
	if _cache.has(key):
		return _cache[key]
	_enqueue(scene, item, key)
	return item.texture if item.texture != null else null

## Icons are cached per 3D scene AND per weight: some scenes (e.g. rocks.glb)
## pick their visual variant from the item's weight, so two weights must not
## share an icon.
func _key_for(scene : PackedScene, item) -> String:
	var path : String = scene.resource_path if scene.resource_path != "" else str(scene.get_instance_id())
	return path + "#w=" + str(item.weight)

## Scans the items folder and queues a render for every pickable item that has
## a 3D scene.
func _prewarm_all():
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".tres"):
			var res = load(ITEMS_DIR + f)
			if res is ItemResource and res.physical_instance:
				_enqueue(res.physical_instance, res, _key_for(res.physical_instance, res))
		f = dir.get_next()
	dir.list_dir_end()
	_consume_queue()

## Appends a render job (deduplicated by key) and starts the render loop if it
## is not already running.
func _enqueue(scene : PackedScene, item, key : String):
	for job in _queue:
		if job[2] == key:
			return
	_queue.append([scene, item, key])
	_consume_queue()

## Renders queued scenes strictly one at a time so two SubViewports never exist
## in the same frame. Emits icon_ready once the whole queue has drained.
func _consume_queue():
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		var job : Array = _queue.pop_front()
		var tex := await _bake(job[0], job[1])
		if tex != null:
			_cache[job[2]] = tex
		await get_tree().process_frame
	_busy = false
	icon_ready.emit()

## Renders a single snapshot of `scene` into an off-screen viewport and returns
## it as a texture. Returns null if the scene has no visible meshes or if the
## project runs without a rendering device (e.g. --headless).
func _bake(scene : PackedScene, item) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var viewport := SubViewport.new()
	viewport.name = "IconViewport"
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.2
	# Sky reflections keep metallic surfaces (sword, shield) from rendering as
	# black voids: they need an environment to reflect.
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.2
	key_light.rotation_degrees = Vector3(-35, 45, 0)
	viewport.add_child(key_light)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.6
	fill.rotation_degrees = Vector3(15, -120, 0)
	viewport.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.5
	rim.rotation_degrees = Vector3(20, 150, 0)
	viewport.add_child(rim)

	var front := DirectionalLight3D.new()
	front.light_energy = 0.7
	front.position = Vector3(0.65, 0.75, 1.2).normalized()
	viewport.add_child(front)
	front.look_at(Vector3.ZERO, Vector3.UP)

	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.001
	cam.far = 1000.0
	viewport.add_child(cam)

	var instance := scene.instantiate()
	if instance is RigidBody3D:
		instance.freeze = true
		if item != null and "item_resource" in instance:
			instance.item_resource = item
	viewport.add_child(instance)

	var aabb := _visual_aabb(instance)
	if aabb.size.length_squared() <= 0.0001:
		viewport.queue_free()
		return null
	instance.position = -aabb.get_center()
	var radius : float = aabb.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(cam.fov) * 0.5) * 1.15
	cam.position = Vector3(0.65, 0.75, 1.2).normalized() * dist
	cam.look_at(Vector3.ZERO, Vector3.UP)

	# Wait until the viewport actually produced visible pixels, then capture the
	# first non-empty frame. A fixed single capture can otherwise grab an empty
	# or stale frame while the freshly added viewport is still rendering.
	for i in range(10):
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var img := viewport.get_texture().get_image()
		if img != null and img.get_used_rect().size != Vector2i.ZERO:
			var rect := _opaque_bbox(img)
			rect = rect.grow(3).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var cropped := img.get_region(rect)
			viewport.queue_free()
			return ImageTexture.create_from_image(cropped)
	viewport.queue_free()
	return null

## Bounding box of all pixels with alpha above the visibility threshold.
func _opaque_bbox(img : Image) -> Rect2i:
	var min_x := 9999
	var min_y := 9999
	var max_x := -1
	var max_y := -1
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			if img.get_pixel(x, y).a > 0.1:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i(0, 0, 1, 1)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

## Union of all visible mesh AABBs under `root`, in root's local space.
func _visual_aabb(root : Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var result := AABB()
	var found := false
	var stack : Array[Node] = [root]
	while not stack.is_empty():
		var n : Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi and mi.visible and mi.is_visible_in_tree():
			var world_aabb : AABB = mi.global_transform * mi.get_aabb()
			var local_aabb : AABB = inv * world_aabb
			result = local_aabb if not found else result.merge(local_aabb)
			found = true
		for c in n.get_children():
			stack.append(c)
	return result
