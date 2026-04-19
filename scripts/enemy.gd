extends CharacterBody2D

# =========================================================
# SETTINGS
# =========================================================
const TILE_SIZE := 16
const MOVE_TIME := 2.0


# =========================================================
# ENEMY TYPE
# =========================================================
enum EnemyType {
	PAWN,
	ROOK,
	BISHOP,
	KNIGHT,
	QUEEN,
	KING
}

@export var enemy_type: EnemyType


# =========================================================
# REFERENCES
# =========================================================
@onready var player: CharacterBody2D = $"../../Player"
var tile_map: TileMap


# =========================================================
# STATE
# =========================================================
var can_move := true
var grid_position: Vector2i
var grid := []


# =========================================================
# INITIALIZATION
# =========================================================
func _ready():
	tile_map = get_tree().get_first_node_in_group("tilemap")
	
	if tile_map == null:
		push_error("TileMap not found!")
	_set_initial_grid_position()
	prepare_grid()


func _set_initial_grid_position():
	grid_position = Vector2i(
		floor(position.x / TILE_SIZE),
		floor(position.y / TILE_SIZE)
	)

	var half := TILE_SIZE * 0.5
	position = Vector2(
		grid_position.x * TILE_SIZE + half,
		grid_position.y * TILE_SIZE + half
	)


# =========================================================
# GRID SETUP
# =========================================================
func prepare_grid():
	var used_rect = tile_map.get_used_rect()
	grid.clear()

	for x in range(used_rect.size.x):
		grid.append([])
		for y in range(used_rect.size.y):
			grid[x].append(false)

	for x in range(used_rect.size.x):
		for y in range(used_rect.size.y):
			var cell = Vector2i(x, y) + used_rect.position

			var source_id = tile_map.get_cell_source_id(0, cell)
			if source_id == -1:
				continue

			var tile_data = tile_map.get_cell_tile_data(0, cell)
			if tile_data:
				grid[x][y] = tile_data.get_collision_polygons_count(0) > 0


# =========================================================
# GAME LOOP
# =========================================================
func _physics_process(_delta):
	if can_move:
		handle_enemy_movement()


# =========================================================
# MOVEMENT FLOW
# =========================================================
func handle_enemy_movement():
	var directions = get_directions_for_type()
	var path = get_path_to_player(directions)

	# special handling for sliding pieces
	if enemy_type in [EnemyType.ROOK, EnemyType.BISHOP, EnemyType.QUEEN]:
		path = compress_path(path)
	move_enemy(path)


# =========================================================
# PATHFINDING
# =========================================================
func get_path_to_player(available_directions):
	var path = []
	var path_position = grid_position
	var last_position = grid_position

	while path_position != player.grid_position:
		var best_score = get_distance_to_player(path_position)
		var best_direction = Vector2i.ZERO
		var best_target = path_position
		var i = 0
		for direction in available_directions:
			print(i)
			var result = get_target(path_position, direction, 1)
			if not result.success:
				continue

			var new_pos = result.target
			var score = get_distance_to_player(new_pos)

			# Avoid going back
			if new_pos == last_position:
				score += 20

			# Avoid invalid direction
			if direction == Vector2i.ZERO:
				score += 50

			# Penalize wall situations
			if is_stuck_on_wall():
				score += 100
				print("stuck")
				#print(score)
				#print(best_score)
			if score < best_score:
				best_score = score
				best_direction = direction
				best_target = new_pos
			i +=1
		# No valid move → stop
		if best_direction == Vector2i.ZERO:
			break

		path.append(best_direction)
		print("Added")
		i = 0
		last_position = path_position
		path_position = best_target

	return path


# =========================================================
# ENEMY MOVE RULES
# =========================================================
func is_stuck_on_wall() -> bool:
	var second_result
	var directions = [
		Vector2i(1, 0),   # right
		Vector2i(1, 1),   # down-right
		Vector2i(0, 1),   # down
		Vector2i(-1, 1),  # down-left
		Vector2i(-1, 0),  # left
		Vector2i(-1, -1), # up-left
		Vector2i(0, -1),  # up
		Vector2i(1, -1)   # up-right
	]
	for direction in directions:
		var result = get_target(grid_position, direction, 1)
		if not result.success:
			second_result = get_target(result.target, direction, 1)
			if second_result.target == player.grid_position:
				return true
	return false
	
func get_directions_for_type():
	match enemy_type:

		EnemyType.PAWN:
			return [] # TODO

		EnemyType.ROOK:
			return [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]

		EnemyType.BISHOP:
			return [
				Vector2i(1, 1),
				Vector2i(1, -1),
				Vector2i(-1, 1),
				Vector2i(-1, -1)
			]

		EnemyType.QUEEN:
			return [
				Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1)
			]

		EnemyType.KING:
			return [
				Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1)
			]

		EnemyType.KNIGHT:
			return [] # TODO

		_:
			return [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]

func is_near_wall(pos: Vector2i) -> bool:
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in directions:
		var check = pos + dir

		if check.x < 0 or check.y < 0:
			return true

		if check.x >= grid.size() or check.y >= grid[0].size():
			return true

		if grid[check.x][check.y] == true:
			return true

	return false
# =========================================================
# SLIDING PIECES OPTIMIZATION
# =========================================================
func compress_path(path: Array) -> Array:
	var result := []
	var i := 0

	while i < path.size():
		var dir = path[i]
		var count = 1

		while i < path.size() - 1 and path[i + 1] == dir:
			i += 1
			count += 1

		result.append({
			"direction": dir,
			"distance": count
		})

		i += 1

	return result


# =========================================================
# EXECUTE MOVEMENT
# =========================================================
func move_enemy(path):
	can_move = false

	for step in path:
		for i in range(step["distance"]):
			var result = get_target(
				grid_position,
				step["direction"],
				1
			)

			if not result.success:
				can_move = true
				return

			grid_position = result.target

		await tween_to(grid_position)
		check_player_collision()

	can_move = true


func tween_to(grid_pos):
	var half := TILE_SIZE * 0.5

	var world_pos = Vector2(
		grid_pos.x * TILE_SIZE + half,
		grid_pos.y * TILE_SIZE + half
	)

	var tween = create_tween()
	tween.tween_property(self, "position", world_pos, MOVE_TIME / 2.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	await tween.finished


# =========================================================
# COLLISION / GAME OVER
# =========================================================
func check_player_collision():
	if grid_position == player.grid_position:
		print("you died")
		get_tree().change_scene_to_file("res://scenes/levels_menu.tscn")


# =========================================================
# HELPERS
# =========================================================
func get_distance_to_player(pos: Vector2i) -> int:
	return abs(pos.x - player.grid_position.x) + abs(pos.y - player.grid_position.y)


func get_target(origin, direction: Vector2i, distance):
	var target = origin + direction * distance

	if grid.is_empty():
		return {"success": false, "target": target}

	if target.x < 0 or target.y < 0:
		return {"success": false, "target": target}

	if target.x >= grid.size() or target.y >= grid[0].size():
		return {"success": false, "target": target}

	if grid[target.x][target.y]:
		return {"success": false, "target": target}

	return {"success": true, "target": target}
