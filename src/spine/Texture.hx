package spine;

/* abstract */ class Texture {
	/* abstract */ public function getWidth():Int
		throw "abstract";

	/* abstract */ public function getHeight():Int
		throw "abstract";

	/* abstract */ public function setFilters(minFilter:TextureFilter, magFilter:TextureFilter)
		throw "abstract";

	/* abstract */ public function setWraps(uWrap:TextureWrap, vWrap:TextureWrap)
		throw "abstract";

	/* abstract */ public function dispose()
		throw "abstract";

	public static function filterFromString(text:String):TextureFilter {
		switch (text.toLowerCase()) {
			case "nearest":
				return TextureFilter.Nearest;
			case "linear":
				return TextureFilter.Linear;
			case "mipmap":
				return TextureFilter.MipMap;
			case "mipmapnearestnearest":
				return TextureFilter.MipMapNearestNearest;
			case "mipmaplinearnearest":
				return TextureFilter.MipMapLinearNearest;
			case "mipmapnearestlinear":
				return TextureFilter.MipMapNearestLinear;
			case "mipmaplinearlinear":
				return TextureFilter.MipMapLinearLinear;
			default:
				throw new Error('Unknown texture filter ${text}');
		}
	}

	public static function wrapFromString(text:String):TextureWrap {
		switch (text.toLowerCase()) {
			case "mirroredtepeat":
				return TextureWrap.MirroredRepeat;
			case "clamptoedge":
				return TextureWrap.ClampToEdge;
			case "repeat":
				return TextureWrap.Repeat;
			default:
				throw new Error('Unknown texture wrap ${text}');
		}
	}
}

enum abstract TextureFilter(Int) {
	var Nearest = 9728; // WebGLRenderingContext.NEAREST
	var Linear = 9729; // WebGLRenderingContext.LINEAR
	var MipMap = 9987; // WebGLRenderingContext.LINEAR_MIPMAP_LINEAR
	var MipMapNearestNearest = 9984; // WebGLRenderingContext.NEAREST_MIPMAP_NEAREST
	var MipMapLinearNearest = 9985; // WebGLRenderingContext.LINEAR_MIPMAP_NEAREST
	var MipMapNearestLinear = 9986; // WebGLRenderingContext.NEAREST_MIPMAP_LINEAR
	var MipMapLinearLinear = 9987; // WebGLRenderingContext.LINEAR_MIPMAP_LINEAR
}

enum abstract TextureWrap(Int) {
	var MirroredRepeat = 33648; // WebGLRenderingContext.MIRRORED_REPEAT
	var ClampToEdge = 33071; // WebGLRenderingContext.CLAMP_TO_EDGE
	var Repeat = 10497; // WebGLRenderingContext.REPEAT
}

class TextureRegion {
	public var renderObject:Dynamic;
	public var u = 0.0;
	public var v = 0.0;
	public var u2 = 0.0;
	public var v2 = 0.0;
	public var width = 0;
	public var height = 0;
	public var rotate = false;
	public var offsetX = 0;
	public var offsetY = 0;
	public var originalWidth = 0;
	public var originalHeight = 0;
}

class FakeTexture extends Texture {
	final w:Int;
	final h:Int;

	public function new(w, h) {
		this.w = w;
		this.h = h;
	}

	override function setFilters(minFilter:TextureFilter, magFilter:TextureFilter) {}

	override function setWraps(uWrap:TextureWrap, vWrap:TextureWrap) {}

	override function dispose() {}

	override function getHeight():Int
		return h;

	override function getWidth():Int
		return w;
}
