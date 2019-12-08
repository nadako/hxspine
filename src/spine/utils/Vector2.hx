package spine.utils;

class Vector2 {
	public var x:Float;
	public var y:Float;

	public function new(x = 0.0, y = 0.0) {
		this.x = x;
		this.y = y;
	}

	public function set(x:Float, y:Float):Vector2 {
		this.x = x;
		this.y = y;
		return this;
	}

	public function length():Float {
		var x = this.x;
		var y = this.y;
		return Math.sqrt(x * x + y * y);
	}

	public function normalize():Vector2 {
		var len = this.length();
		if (len != 0) {
			this.x /= len;
			this.y /= len;
		}
		return this;
	}
}
