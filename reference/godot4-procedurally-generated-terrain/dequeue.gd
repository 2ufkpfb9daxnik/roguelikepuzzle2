extends RefCounted

class_name Dequeue

var buffer : Array
var capacity : int
var head : int = 0
var tail : int = 0
var count : int = 0

func _init(initial_capacity: int = 1024) -> void:
	capacity = initial_capacity
	buffer = []
	for i in range(capacity):
		buffer.append(null)

# --- ヘルパー ---
func is_empty() -> bool:
	return count == 0

func is_full() -> bool:
	return count == capacity

func size() -> int:
	return count

func _grow() -> void:
	var new_capacity = capacity * 2
	var new_buffer = []
	for i in range(new_capacity):
		new_buffer.append(null)
	# 既存データをコピー
	for i in range(count):
		new_buffer[i] = buffer[(head + i) % capacity]
	buffer = new_buffer
	head = 0
	tail = count
	capacity = new_capacity

# --- 両端操作 ---
func push_back(item) -> void:
	if is_full():
		_grow()
	buffer[tail] = item
	tail = (tail + 1) % capacity
	count += 1

func push_front(item) -> void:
	if is_full():
		_grow()
	head = (head - 1 + capacity) % capacity
	buffer[head] = item
	count += 1

func pop_front():
	if is_empty():
		return null
	var item = buffer[head]
	head = (head + 1) % capacity
	count -= 1
	return item

func pop_back():
	if is_empty():
		return null
	tail = (tail - 1 + capacity) % capacity
	var item = buffer[tail]
	count -= 1
	return item

func peek_front():
	if is_empty():
		return null
	return buffer[head]

func peek_back():
	if is_empty():
		return null
	return buffer[(tail - 1 + capacity) % capacity]
