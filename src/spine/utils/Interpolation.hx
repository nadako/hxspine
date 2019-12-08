package spine.utils;

/* abstract */ class Interpolation {
	/* abstract */ function applyInternal(a:Float):Float
		throw "abstract";

	public function apply(start:Float, end:Float, a:Float):Float {
		return start + (end - start) * this.applyInternal(a);
	}
}

class Pow extends Interpolation {
	var power:Float = 2;

	public function new(power:Float) {
		this.power = power;
	}

	override function applyInternal(a:Float):Float {
		if (a <= 0.5)
			return Math.pow(a * 2, this.power) / 2;
		return Math.pow((a - 1) * 2, this.power) / (this.power % 2 == 0 ? -2 : 2) + 1;
	}
}

class PowOut extends Pow {
	public function new(power:Float) {
		super(power);
	}

	override function applyInternal(a:Float):Float {
		return Math.pow(a - 1, this.power) * (this.power % 2 == 0 ? -1 : 1) + 1;
	}
}
