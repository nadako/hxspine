package spine.utils;

class Pool<T> {
	var items = new Array<T>();
	var instantiator:() -> T;

	public function new(instantiator:() -> T) {
		this.instantiator = instantiator;
	}

	public function obtain() {
		return this.items.length > 0 ? this.items.pop() : this.instantiator();
	}

	public function free(item:T) {
		if ((item : Dynamic).reset != null)
			(item : Dynamic).reset();
		this.items.push(item);
	}

	public function freeAll(items:Array<T>) {
		for (i in 0...items.length) {
			if ((items[i] : Dynamic).reset != null)
				(items[i] : Dynamic).reset();
			this.items[i] = items[i];
		}
	}

	public function clear() {
		this.items.resize(0);
	}
}
