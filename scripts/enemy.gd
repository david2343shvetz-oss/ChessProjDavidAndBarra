extends CharacterBody2D

# =========================
# SETTINGS
# =========================
const TILE_SIZE = 16
const MOVE_TIME = 2

enum EnemyType {
	PAWN,
	ROOK,
	BISHOP,
	KNIGHT,
	QUEEN,
	KING
}

@export var enemy_type: EnemyType


# =========================
# REFERENCES
# =========================
@onready var tile_map: TileMap = $"../../TileMap"
@onready var player: CharacterBody2D = $"../../Player"


# =========================
# STATE
# =========================
var can_move := true
var grid_position: Vector2i
var grid = []


# =========================
# INITIALIZATION
# =========================
func _ready():
	grid_position = Vector2i(
		floor(position.x / TILE_SIZE),
		floor(position.y / TILE_SIZE)
	)

	# Snap perfectly to grid center
	var half_tile = TILE_SIZE * 0.5
	position = Vector2(
		grid_position.x * TILE_SIZE + half_tile,
		grid_position.y * TILE_SIZE + half_tile
	)

	prepare_grid()


# =========================
# GRID BUILDING
# =========================
func prepare_grid():
	var used_rect = tile_map.get_used_rect()
	grid.clear()

	# Create empty grid
	for x in range(used_rect.size.x):
		grid.append([])
		for y in range(used_rect.size.y):
			grid[x].append(false)

	# Fill blocked tiles (collision)
	for x in range(used_rect.size.x):
		for y in range(used_rect.size.y):
			var cell_pos = Vector2i(x, y) + used_rect.position

			var source_id = tile_map.get_cell_source_id(0, cell_pos)
			if source_id == -1:
				continue

			var tile_data = tile_map.get_cell_tile_data(0, cell_pos)
			if tile_data:
				grid[x][y] = tile_data.get_collision_polygons_count(0) > 0


# =========================
# DISTANCE (Manhattan)
# =========================
func get_distance_to_player(pos: Vector2i) -> int:
	return abs(pos.x - player.grid_position.x) + abs(pos.y - player.grid_position.y)


# =========================
# PATHFINDING (Greedy)
# =========================
func get_path_to_player(available_directions):
	var path = []
	var current = grid_position

	# Greedy approach: always step closer to player
	while current != player.grid_position:
		var best_direction = Vector2i.ZERO
		var best_position = current

		for direction in available_directions:
			var result = get_target(current, direction, 1)

			if not result.success:
				continue

			var new_pos = result.target

			# Pick move that reduces distance
			if get_distance_to_player(new_pos) < get_distance_to_player(best_position):
				best_position = new_pos
				best_direction = direction

		# No progress possible → stop
		if best_direction == Vector2i.ZERO:
			if grid_position != player.grid_position:
				print("stuck on a wall")
				# find a way around walls
			else:
				print("No valid move found")
				break

		path.append(best_direction)
		current = best_position

	return path


# =========================
# ENEMY DECISION
# =========================
func handle_enemy_movement():
	var directions = get_directions_for_type()

	var path = get_path_to_player(directions)

	# Convert to long moves for sliding pieces
	if enemy_type in [EnemyType.ROOK, EnemyType.BISHOP, EnemyType.QUEEN]:
		path = compress_path(path)

	move_enemy(path)


func get_directions_for_type():
	match enemy_type:
		EnemyType.PAWN:
			return [Vector2i(0, -1)]

		EnemyType.ROOK:
			return [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]

		_:
			# default (like rook for now)
			return [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]


# =========================
# PATH COMPRESSION (rook-style)
# =========================
func compress_path(path: Array) -> Array:
	var result = []
	var i = 0

	while i < path.size():
		var dir = path[i]
		var count = 1

		# Count consecutive same directions
		while i < path.size() - 1 and path[i + 1] == dir:
			i += 1
			count += 1

		result.append({
			"direction": dir,
			"distance": count
		})

		i += 1

	return result


# =========================
# MAIN LOOP
# =========================
func _physics_process(_delta: float) -> void:
	if can_move:
		handle_enemy_movement()


# =========================
# TARGET CHECKING
# =========================
func get_target(origin, direction: Vector2i, distance):
	var target = origin + direction * distance

	if grid.is_empty():
		return { "success": false }

	if target.x < 0 or target.y < 0:
		return { "success": false }

	if target.x >= grid.size() or target.y >= grid[0].size():
		return { "success": false }

	if grid[target.x][target.y]:
		return { "success": false }

	return { "success": true, "target": target }


# =========================
# MOVEMENT
# =========================
func move_enemy(path):
	can_move = false

	# Apply movement logically first
	for step in path:
		for i in range(step["distance"]):  # 👈 THIS is the fix
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
	can_move = true
	
func tween_to(grid_pos):
	var half_tile := TILE_SIZE * 0.5

	var world_target = Vector2(
		grid_pos.x * TILE_SIZE + half_tile,
		grid_pos.y * TILE_SIZE + half_tile
	)

	var tween = create_tween()
	tween.tween_property(self, "position", world_target, MOVE_TIME / 2.0) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	await tween.finished
