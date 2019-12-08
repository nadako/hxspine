package spine.utils;

class MathUtils {
	public static inline final PI = 3.1415927;
	public static inline final PI2 = PI * 2;
	public static inline final radiansToDegrees = 180 / PI;
	public static inline final radDeg = radiansToDegrees;
	public static inline final degreesToRadians = PI / 180;
	public static inline final degRad = degreesToRadians;

	public static function clamp(value:Float, min:Float, max:Float):Float {
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
	}

	public static function cosDeg(degrees:Float):Float {
		return Math.cos(degrees * MathUtils.degRad);
	}

	public static function sinDeg(degrees:Float):Float {
		return Math.sin(degrees * MathUtils.degRad);
	}

	public static function signum(value:Float):Int {
		return value > 0 ? 1 : value < 0 ? -1 : 0;
	}

	public static function toInt(x:Float):Int {
		return x > 0 ? Math.floor(x) : Math.ceil(x);
	}

	public static function cbrt(x:Float):Float {
		var y = Math.pow(Math.abs(x), 1 / 3);
		return x < 0 ? -y : y;
	}

	public static function randomTriangular(min:Float, max:Float):Float {
		return MathUtils.randomTriangularWith(min, max, (min + max) * 0.5);
	}

	public static function randomTriangularWith(min:Float, max:Float, mode:Float):Float {
		var u = Math.random();
		var d = max - min;
		if (u <= (mode - min) / d)
			return min + Math.sqrt(u * d * (mode - min));
		return max - Math.sqrt((1 - u) * d * (max - mode));
	}
}
