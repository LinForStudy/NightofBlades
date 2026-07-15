extends Node

var _pools: Dictionary = {}

func register_pool(pool_id: StringName, factory: Callable, initial_size: int = 0) -> void:
	if _pools.has(pool_id):
		push_warning("ObjectPoolManager pool already registered: %s" % pool_id)
		return

	_pools[pool_id] = {
		"factory": factory,
		"available": []
	}

	for index in initial_size:
		var item: Variant = factory.call()
		_pools[pool_id]["available"].append(item)

func get_object(pool_id: StringName) -> Variant:
	if not _pools.has(pool_id):
		push_warning("ObjectPoolManager unknown pool: %s" % pool_id)
		return null

	var available: Array = _pools[pool_id]["available"]
	if not available.is_empty():
		return available.pop_back()

	var factory: Callable = _pools[pool_id]["factory"]
	if not factory.is_valid():
		push_warning("ObjectPoolManager stale factory: %s" % pool_id)
		return null
	return factory.call()

func recycle_object(pool_id: StringName, item: Variant) -> void:
	if not _pools.has(pool_id):
		push_warning("ObjectPoolManager cannot recycle into unknown pool: %s" % pool_id)
		return

	_pools[pool_id]["available"].append(item)