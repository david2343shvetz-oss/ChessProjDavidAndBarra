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
	# A list of positions we still need to explore
	# Each entry is [f_score, position] — lowest f_score gets explored first
	var open = []
	
	# Dictionary that remembers "how did we get to this position?"
	# came_from[B] = A means "we reached B by coming from A"
	var came_from = {}
	
	# Dictionary tracking how many steps it took to reach each position
	# We start at our own position with 0 steps taken
	var g_score = { grid_position: 0 }
	
	# Add our starting position to the open list
	# f_score at the start is just the raw distance to the player (0 steps taken so far)
	open.append([get_distance_to_player(grid_position), grid_position])
	
	# Keep looping as long as there are positions left to explore
	while open.size() > 0:
		
		# Sort the open list so the lowest f_score (most promising) is at the front
		open.sort()
		
		# Grab the most promising position to explore next
		# pop_front() removes and returns the first entry, [1] gets the position (index 0 is the score)
		var current = open.pop_front()[1]
		
		# If the position we're looking at IS the player, we found the path!
		if current == player.grid_position:
			var path = []
			var node = current
			
			# Walk backwards through came_from to reconstruct the path
			# We go from the player's position back to our starting position
			while came_from.has(node):
				var prev = came_from[node]
				
				# The direction of this step is current - previous
				# e.g. (3,2) - (2,2) = (1,0) which means "moved right"
				# push_front adds to the beginning so directions stay in the right order
				path.push_front(node - prev)
				
				# Move one step further back
				node = prev
			
			return path
		# Try every possible direction from the current position
		for direction in available_directions:
			
			# Skip the "no movement" direction
			if direction == Vector2i.ZERO:
					continue
				
				# Check if moving this direction is actually valid (not a wall etc.)
			var result = get_target(current, direction, 1)
				
				# If the move is blocked, skip this direction
			if not result.success:
				continue
				
				# This is the position we'd land on
			var neighbor = result.target
				
				# How many steps would it take to reach this neighbor?
				# It's however many steps to reach current, plus 1 more
			var tentative_g = g_score[current] + 1
				
				# Only update this neighbor if:
				# - we've never visited it before, OR
				# - we just found a shorter way to reach it
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
					
					# Record the step count to reach this neighbor
				g_score[neighbor] = tentative_g
					
					# Record that we reached this neighbor from current
				came_from[neighbor] = current
					
					# f = steps taken so far + estimated steps remaining
				var f = tentative_g + get_distance_to_player(neighbor)
					
				open.append([f, neighbor])
	
	# If we emptied the open list and never reached the player,
	# there is no valid path — return empty
	return []
			
			
			
			
			
			
#func get_path_to_player(available_directions):
	#var path = []
	#var path_position = grid_position
	#var last_position = grid_position
#
	#while path_position != player.grid_position:
		#var best_score = get_distance_to_player(path_position)
		#var best_direction = Vector2i.ZERO
		#var best_target = path_position
		#var i = 0
		#for direction in available_directions:
			#print(i)
			#var result = get_target(path_position, direction, 1)
			#if not result.success:
				#continue
#
			#var new_pos = result.target
			#var score = get_distance_to_player(new_pos)
#
			## Avoid going back
			#if new_pos == last_position:
				#print("back")
				#score += 30
#
			## Avoid invalid direction
			#if direction == Vector2i.ZERO:
				#score += 50
#
			## Penalize wall situations
			#if is_stuck_on_wall():
				#score += 100
				#print("stuck")
				##print(score)
				##print(best_score)
			#if score < best_score:
				#best_score = score
				#best_direction = direction
				#best_target = new_pos
			#i +=1
		## No valid move → stop
		#if best_direction == Vector2i.ZERO:
			#break

		#path.append(best_direction)
		#print("Added")
		#i = 0
		#last_position = path_position
		#path_position = best_target
#
	#return path


# =========================================================
# ENEMY MOVE RULES
# =========================================================
# unused func
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
# unused func so far
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
