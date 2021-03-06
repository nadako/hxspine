package spine.utils;

class Pool<T> {
	final items = new Array<T>();
	final instantiator:() -> T;
	final reset:Null<T->Void>;

	public function new(instantiator:() -> T, ?reset:T->Void) {
		this.instantiator = instantiator;
		this.reset = reset;
	}

	public function obtain():T {
		return items.length > 0 ? items.pop() : instantiator();
	}

	public function free(item:T) {
		if (reset != null)
			reset(item);
		items.push(item);
	}

	public function freeAll(items:Array<T>) {
		for (item in items) {
			free(item);
		}
	}

	public function clear() {
		items.resize(0);
	}
}
