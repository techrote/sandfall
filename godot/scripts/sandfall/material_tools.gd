class_name SandfallMaterialTools
extends RefCounted

const WIDTH: int = 1024
const MAX_CELLS: int = WIDTH * WIDTH

# Incremental, cancellable category fill over an owned immutable logical view.
# No native/Web call per cell, no writes until the single completed transaction.
var _fill_cells: PackedByteArray = PackedByteArray()
var _visited: PackedByteArray = PackedByteArray()
var _queue: PackedInt32Array = PackedInt32Array()
var _head: int = 0
var _tail: int = 0
var _category: int = 0
var _filling: bool = false


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < WIDTH


static func cell_tuple(material: int, state_a: int, state_b: int, temperature: int) -> PackedByteArray:
	if material < 0 or material > 255 or state_a < 0 or state_a > 255 or state_b < 0 or state_b > 255 or temperature < -32768 or temperature > 32767:
		return PackedByteArray()
	return PackedByteArray([material, state_a, state_b, temperature & 255, (temperature >> 8) & 255])


static func tuple_values(value: PackedByteArray) -> Dictionary:
	if value.size() != 5:
		return {}
	var temperature: int = int(value[3]) | (int(value[4]) << 8)
	if temperature >= 32768:
		temperature -= 65536
	return {"id": int(value[0]), "state_a": int(value[1]), "state_b": int(value[2]), "temperature": temperature}


static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if not in_bounds(a) or not in_bounds(b):
		return points
	var x: int = a.x
	var y: int = a.y
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var error: int = dx + dy
	while true:
		points.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var doubled: int = error * 2
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy
	return points


static func stamp(target: Dictionary, centre: Vector2i, dimensions: Vector2i, shape: String) -> void:
	# Extracted lattice convention from the frozen CyberSand main.gd
	# brush_footprint_cells: odd circles use emit_disc's integer radius;
	# even circles use cell centres; even footprints bias toward +x/+y.
	var width: int = clampi(dimensions.x, 1, 32)
	var height: int = width if shape != "rectangle" else clampi(dimensions.y, 1, 32)
	var start: Vector2i = centre - Vector2i((width - 1) / 2, (height - 1) / 2)
	for y: int in range(height):
		for x: int in range(width):
			if shape == "circle":
				if width % 2 == 1:
					var radius: int = (width - 1) / 2
					if (x - radius) * (x - radius) + (y - radius) * (y - radius) > radius * radius:
						continue
				else:
					var u: int = 2 * x + 1 - width
					var v: int = 2 * y + 1 - height
					if u * u + v * v > width * width:
						continue
			var point: Vector2i = start + Vector2i(x, y)
			if in_bounds(point):
				target[point.y * WIDTH + point.x] = true


static func stroke(points: Array[Vector2i], dimensions: Vector2i, shape: String) -> PackedInt32Array:
	var cells: Dictionary = {}
	for i: int in range(points.size()):
		var from: Vector2i = points[maxi(0, i - 1)]
		for point: Vector2i in line(from, points[i]):
			stamp(cells, point, dimensions, shape)
	return sorted_indices(cells)


static func selection(a: Vector2i, b: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1))


static func rectangle(a: Vector2i, b: Vector2i, filled: bool) -> PackedInt32Array:
	var indices: PackedInt32Array = PackedInt32Array()
	if not in_bounds(a) or not in_bounds(b):
		return indices
	var rect: Rect2i = selection(a, b)
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if filled or y == rect.position.y or y == rect.end.y - 1 or x == rect.position.x or x == rect.end.x - 1:
				indices.append(y * WIDTH + x)
	return indices


static func sorted_indices(cells: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array(cells.keys())
	out.sort()
	return out


func start_fill(cells: PackedByteArray, seed: Vector2i) -> bool:
	cancel_fill()
	if cells.size() != MAX_CELLS * 5 or not in_bounds(seed):
		return false
	_fill_cells = cells.duplicate()
	_visited.resize(MAX_CELLS)
	_visited.fill(0)
	_queue.resize(MAX_CELLS)
	var index: int = seed.y * WIDTH + seed.x
	_category = int(_fill_cells[index * 5])
	_queue[0] = index
	_visited[index] = 1
	_tail = 1
	_head = 0
	_filling = true
	return true


func pump_fill(max_work: int = 4096, budget_usec: int = 2000) -> Dictionary:
	if not _filling:
		return {"done": false, "active": false, "processed": 0}
	var deadline: int = Time.get_ticks_usec() + clampi(budget_usec, 100, 5000)
	var stop: int = mini(_head + clampi(max_work, 1, 4096), MAX_CELLS)
	while _head < _tail and _head < stop:
		var index: int = _queue[_head]
		_head += 1
		var x: int = index % WIDTH
		var y: int = index / WIDTH
		if x > 0: _visit(index - 1)
		if x < WIDTH - 1: _visit(index + 1)
		if y > 0: _visit(index - WIDTH)
		if y < WIDTH - 1: _visit(index + WIDTH)
		if Time.get_ticks_usec() >= deadline:
			break
	if _head == _tail:
		var indices: PackedInt32Array = _queue.slice(0, _tail)
		indices.sort()
		var processed: int = _head
		cancel_fill()
		return {"done": true, "active": false, "indices": indices, "processed": processed}
	return {"done": false, "active": true, "processed": _head, "queued": _tail}


func _visit(index: int) -> void:
	if _visited[index] != 0 or int(_fill_cells[index * 5]) != _category:
		return
	_visited[index] = 1
	_queue[_tail] = index
	_tail += 1


func cancel_fill() -> void:
	_filling = false
	_fill_cells = PackedByteArray()
	_visited = PackedByteArray()
	_queue = PackedInt32Array()
	_head = 0
	_tail = 0
