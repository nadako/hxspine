package spine;

interface Texture {
	function getWidth():Int;
	function getHeight():Int;
	function setFilters(minFilter:TextureFilter, magFilter:TextureFilter):Void;
	function setWraps(uWrap:TextureWrap, vWrap:TextureWrap):Void;
	function dispose():Void;
}

enum abstract TextureFilter(Int) {
	var Nearest = 9728; // WebGLRenderingContext.NEAREST
	var Linear = 9729; // WebGLRenderingContext.LINEAR
	var MipMap = 9987; // WebGLRenderingContext.LINEAR_MIPMAP_LINEAR
	var MipMapNearestNearest = 9984; // WebGLRenderingContext.NEAREST_MIPMAP_NEAREST
	var MipMapLinearNearest = 9985; // WebGLRenderingContext.LINEAR_MIPMAP_NEAREST
	var MipMapNearestLinear = 9986; // WebGLRenderingContext.NEAREST_MIPMAP_LINEAR
	var MipMapLinearLinear = 9987; // WebGLRenderingContext.LINEAR_MIPMAP_LINEAR

	public static function fromString(text:String):TextureFilter {
		return switch (text.toLowerCase()) {
			case "nearest": Nearest;
			case "linear": Linear;
			case "mipmap": MipMap;
			case "mipmapnearestnearest": MipMapNearestNearest;
			case "mipmaplinearnearest": MipMapLinearNearest;
			case "mipmapnearestlinear": MipMapNearestLinear;
			case "mipmaplinearlinear": MipMapLinearLinear;
			default: throw new Error('Unknown texture filter ${text}');
		};
	}
}

enum abstract TextureWrap(Int) {
	var MirroredRepeat = 33648; // WebGLRenderingContext.MIRRORED_REPEAT
	var ClampToEdge = 33071; // WebGLRenderingContext.CLAMP_TO_EDGE
	var Repeat = 10497; // WebGLRenderingContext.REPEAT

	public static function fromString(text:String):TextureWrap {
		return switch (text.toLowerCase()) {
			case "mirroredtepeat": MirroredRepeat;
			case "clamptoedge": ClampToEdge;
			case "repeat": Repeat;
			default: throw new Error('Unknown texture wrap ${text}');
		};
	}
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

class FakeTexture implements Texture {
	final w:Int;
	final h:Int;

	public function new(w, h) {
		this.w = w;
		this.h = h;
	}

	public function setFilters(minFilter:TextureFilter, magFilter:TextureFilter) {}

	public function setWraps(uWrap:TextureWrap, vWrap:TextureWrap) {}

	public function dispose() {}

	public function getHeight():Int {
		return h;
	}

	public function getWidth():Int {
		return w;
	}
}
