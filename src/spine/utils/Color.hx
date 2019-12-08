package spine.utils;

class Color {
	public static final WHITE = new Color(1, 1, 1, 1);
	public static final RED = new Color(1, 0, 0, 1);
	public static final GREEN = new Color(0, 1, 0, 1);
	public static final BLUE = new Color(0, 0, 1, 1);
	public static final MAGENTA = new Color(1, 0, 1, 1);

	public var r:Float;
	public var g:Float;
	public var b:Float;
	public var a:Float;

	public function new(r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 0) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

	public function set(r:Float, g:Float, b:Float, a:Float):Color {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
		this.clamp();
		return this;
	}

	public function setFromColor(c:Color):Color {
		this.r = c.r;
		this.g = c.g;
		this.b = c.b;
		this.a = c.a;
		return this;
	}

	public function setFromString(hex:String):Color {
		hex = hex.charAt(0) == '#' ? hex.substr(1) : hex;
		this.r = Std.parseInt("0x" + hex.substr(0, 2)) / 255.0;
		this.g = Std.parseInt("0x" + hex.substr(2, 2)) / 255.0;
		this.b = Std.parseInt("0x" + hex.substr(4, 2)) / 255.0;
		this.a = (hex.length != 8 ? 255 : Std.parseInt("0x" + hex.substr(6, 2))) / 255.0;
		return this;
	}

	public function add(r:Float, g:Float, b:Float, a:Float):Color {
		this.r += r;
		this.g += g;
		this.b += b;
		this.a += a;
		this.clamp();
		return this;
	}

	public function clamp():Color {
		if (this.r < 0)
			this.r = 0;
		else if (this.r > 1)
			this.r = 1;

		if (this.g < 0)
			this.g = 0;
		else if (this.g > 1)
			this.g = 1;

		if (this.b < 0)
			this.b = 0;
		else if (this.b > 1)
			this.b = 1;

		if (this.a < 0)
			this.a = 0;
		else if (this.a > 1)
			this.a = 1;
		return this;
	}

	public static function rgba8888ToColor(color:Color, value:Int) {
		color.r = ((value & 0xff000000) >>> 24) / 255;
		color.g = ((value & 0x00ff0000) >>> 16) / 255;
		color.b = ((value & 0x0000ff00) >>> 8) / 255;
		color.a = ((value & 0x000000ff)) / 255;
	}

	public static function rgb888ToColor(color:Color, value:Int) {
		color.r = ((value & 0x00ff0000) >>> 16) / 255;
		color.g = ((value & 0x0000ff00) >>> 8) / 255;
		color.b = ((value & 0x000000ff)) / 255;
	}
}
