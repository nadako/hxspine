package spine.utils;

abstract IntSet(Map<Int, Int>) {
	public inline function new() {
		this = new Map();
	}

	public inline function add(value:Int):Bool {
		var contains = contains(value);
		this.set(value, value);
		return !contains;
	}

	public inline function contains(value:Int) {
		return this.exists(value);
	}

	public inline function remove(value:Int) {
		this.remove(value);
	}

	public inline function clear() {
		this.clear();
	}
}
