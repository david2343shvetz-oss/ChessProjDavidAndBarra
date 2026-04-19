extends CharacterBody2D

# =========================
# SETTINGS
# =========================
const TILE_SIZE = 16
const MOVE_TIME = 0.2   # how long the movement animation takes

# =========================
# REFERENCES
# =========================
var tile_map: TileMap
@onready var enemy: CharacterBody2D = $"../Enemies/Enemy"
@onready var area = $Area2D
# =========================
# STATE
# =========================
var can_move := true
var grid_position: Vector2i
var grid = []
var is_dead = false

# =========================
# INITIALIZATION
# =========================
func _ready():
	# intialize collision with enemy
	area.body_entered.connect(_on_area_2d_body_entered)
	tile_map = get_tree().get_first_node_in_group("tilemap")
	
	if tile_map == null:
		push_error("TileMap not found!")
	grid_position = Vector2i(
		floor(position.x / TILE_SIZE),
		floor(position.y / TILE_SIZE)
	)
# snap position down 
	var half_tile = TILE_SIZE * 0.5

	position = Vector2(
		grid_position.x * TILE_SIZE + half_tile,
		grid_position.y * TILE_SIZE + half_tile
	)

	prepare_grid()
	print_grid()

# =========================
# BUILD GRID
# =========================
func prepare_grid():
	var used_rect = tile_map.get_used_rect()
	grid.clear()

	for x in range(used_rect.size.x):
		grid.append([])
		for y in range(used_rect.size.y):
			grid[x].append(false)

	for x in range(used_rect.size.x):
		for y in range(used_rect.size.y):
			var cell_pos = Vector2i(x, y) + used_rect.position

			var source_id = tile_map.get_cell_source_id(0, cell_pos)
			if source_id == -1:
				continue

			var tile_data = tile_map.get_cell_tile_data(0, cell_pos)
			if tile_data:
				grid[x][y] = tile_data.get_collision_polygons_count(0) > 0
				
func print_grid():
	for y in range(grid[0].size()):
		var row = ""
		for x in range(grid.size()):
			row += "1 " if grid[x][y] else "0 "
		print(row)
		
# =========================
# INPUT
# =========================
func _physics_process(_delta: float) -> void:
	if not can_move:
		return
	var direction := Vector2i.ZERO
	# get input
	if Input.is_action_pressed("right"):
		direction.x += 1
	if Input.is_action_pressed("left"):
		direction.x -= 1
	if Input.is_action_pressed("down"):
		direction.y += 1
	if Input.is_action_pressed("up"):
		direction.y -= 1
		
			
	# move to input direction
	if direction != Vector2i.ZERO:
		move_step(direction)

# =========================
# MOVE LOGIC
# =========================
func move_step(direction: Vector2i):
	var target = grid_position + direction
	# Bounds check
	if target.x < 0 or target.y < 0:
		return
	if target.x >= grid.size() or target.y >= grid[0].size():
		return

	# Collision check
	if grid[target.x][target.y]:
		return

	move_player(target)
# =========================
# ACTUAL MOVEMENT
# =========================
func move_player(target: Vector2i):
	can_move = false
	grid_position = target

	var half_tile := TILE_SIZE * 0.5

	var world_target = Vector2(
		grid_position.x * TILE_SIZE + half_tile,
		grid_position.y * TILE_SIZE + half_tile
	)
	
	var tween = create_tween()
	tween.tween_property(self, "position", world_target, MOVE_TIME)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	can_move = true
# =========================
# HELPER FUNCS
# =========================
func _on_area_2d_body_entered(body):
	if body == enemy and not is_dead:
		# body.call_deferred()
		die()
func die():
	if is_dead:
		return 
	is_dead = true
	print("You died")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/levels_menu.tscn")
	
