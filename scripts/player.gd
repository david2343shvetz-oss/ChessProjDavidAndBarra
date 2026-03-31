extends CharacterBody2D

# =========================
# SETTINGS
# =========================
const TILE_SIZE = 16          # Size of each tile in pixels
const MOVE_DELAY = 0.25       # Time between moves (seconds)

# =========================
# REFERENCES
# =========================
@onready var tile_map: TileMap = $"../TileMap"

# =========================
# STATE
# =========================
var can_move = true           # Prevents moving too fast
var grid_position: Vector2i   # Player position in grid coordinates
var grid = []                 # 2D array storing collision (true = blocked)


# =========================
# INITIALIZATION
# =========================
func _ready():
	# Convert world position → grid position
	grid_position = Vector2i(
		floor(position.x / TILE_SIZE),
		floor(position.y / TILE_SIZE)
	)

	# Build collision grid from TileMap
	prepare_grid()


# =========================
# BUILD GRID FROM TILEMAP
# =========================
func prepare_grid():
	var used_rect = tile_map.get_used_rect()

	# Clear previous grid data
	grid.clear()

	# Create empty 2D array
	for x in range(used_rect.size.x):
		grid.append([])
		for y in range(used_rect.size.y):
			grid[x].append(false)  # default = walkable

	# Fill grid with collision data
	for x in range(used_rect.size.x):
		for y in range(used_rect.size.y):

			# Convert local grid coords → TileMap coords
			var cell_pos = Vector2i(x, y) + used_rect.position

			# Check if a tile exists at this position
			var source_id = tile_map.get_cell_source_id(0, cell_pos)
			if source_id == -1:
				continue  # empty tile → skip

			# Get tile data (collision info)
			var tile_data = tile_map.get_cell_tile_data(0, cell_pos)

			if tile_data:
				# Check if tile has collision
				var has_collision = tile_data.get_collision_polygons_count(0) > 0

				# Store result in grid
				grid[x][y] = has_collision


# =========================
# INPUT + MOVEMENT
# =========================
func _physics_process(_delta: float) -> void:
	if not can_move:
		return

	var direction = Vector2i.ZERO

	# Input (grid directions)
	if Input.is_action_pressed("right"):
		direction = Vector2i(1, 0)
	elif Input.is_action_pressed("left"):
		direction = Vector2i(-1, 0)
	elif Input.is_action_pressed("down"):
		direction = Vector2i(0, 1)
	elif Input.is_action_pressed("up"):
		direction = Vector2i(0, -1)

	# Move if a direction was pressed
	if direction != Vector2i.ZERO:
		move_step(direction)


# =========================
# GRID MOVEMENT LOGIC
# =========================
func move_step(direction: Vector2i) -> void:
	var target = grid_position + direction
		
	# -------------------------
	# 1. BOUNDS CHECK
	# -------------------------
	if target.x < 0 or target.y < 0:
		return
	if target.x >= grid.size() or target.y >= grid[0].size():
		return

	# -------------------------
	# 2. COLLISION CHECK
	# -------------------------
	if grid[target.x][target.y]:
		return  # tile is blocked

	# -------------------------
	# 3. MOVE PLAYER
	# -------------------------
	can_move = false

	grid_position = target
	
	# Snap player to center of tile
	position = Vector2(
		grid_position.x * TILE_SIZE + TILE_SIZE / 2,
		grid_position.y * TILE_SIZE + TILE_SIZE / 2
	)

	# -------------------------
	# 4. MOVE DELAY
	# -------------------------
	await get_tree().create_timer(MOVE_DELAY).timeout
	can_move = true
