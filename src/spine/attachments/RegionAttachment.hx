package spine.attachments;

import spine.Texture.TextureRegion;
import spine.utils.Utils;
import spine.utils.Color;

/** An attachment that displays a textured quadrilateral.
 *
 * See [Region attachments](http://esotericsoftware.com/spine-regions) in the Spine User Guide. */
class RegionAttachment extends Attachment {
	public static inline final OX1 = 0;
	public static inline final OY1 = 1;
	public static inline final OX2 = 2;
	public static inline final OY2 = 3;
	public static inline final OX3 = 4;
	public static inline final OY3 = 5;
	public static inline final OX4 = 6;
	public static inline final OY4 = 7;

	public static inline final X1 = 0;
	public static inline final Y1 = 1;
	public static inline final C1R = 2;
	public static inline final C1G = 3;
	public static inline final C1B = 4;
	public static inline final C1A = 5;
	public static inline final U1 = 6;
	public static inline final V1 = 7;

	public static inline final X2 = 8;
	public static inline final Y2 = 9;
	public static inline final C2R = 10;
	public static inline final C2G = 11;
	public static inline final C2B = 12;
	public static inline final C2A = 13;
	public static inline final U2 = 14;
	public static inline final V2 = 15;

	public static inline final X3 = 16;
	public static inline final Y3 = 17;
	public static inline final C3R = 18;
	public static inline final C3G = 19;
	public static inline final C3B = 20;
	public static inline final C3A = 21;
	public static inline final U3 = 22;
	public static inline final V3 = 23;

	public static inline final X4 = 24;
	public static inline final Y4 = 25;
	public static inline final C4R = 26;
	public static inline final C4G = 27;
	public static inline final C4B = 28;
	public static inline final C4A = 29;
	public static inline final U4 = 30;
	public static inline final V4 = 31;

	/** The local x translation. */
	public var x:Float = 0.0;

	/** The local y translation. */
	public var y:Float = 0.0;

	/** The local scaleX. */
	public var scaleX:Float = 1.0;

	/** The local scaleY. */
	public var scaleY:Float = 1.0;

	/** The local rotation. */
	public var rotation:Float = 0.0;

	/** The width of the region attachment in Spine. */
	public var width:Float = 0.0;

	/** The height of the region attachment in Spine. */
	public var height:Float = 0.0;

	/** The color to tint the region attachment. */
	public var color:Color = new Color(1, 1, 1, 1);

	/** The name of the texture region for this attachment. */
	public var path:String;

	public var region:TextureRegion;

	/** For each of the 4 vertices, a pair of `x,y` values that is the local position of the vertex.
	 *
	 * @see `updateOffset`. */
	public final offset = Utils.newFloatArray(8);

	public final uvs = Utils.newFloatArray(8);

	public function new(name:String) {
		super(name);
	}

	/** Calculates the `offset` using the region settings. Must be called after changing region settings. */
	public function updateOffset() {
		var regionScaleX = this.width / this.region.originalWidth * this.scaleX;
		var regionScaleY = this.height / this.region.originalHeight * this.scaleY;
		var localX = -this.width / 2 * this.scaleX + this.region.offsetX * regionScaleX;
		var localY = -this.height / 2 * this.scaleY + this.region.offsetY * regionScaleY;
		var localX2 = localX + this.region.width * regionScaleX;
		var localY2 = localY + this.region.height * regionScaleY;
		var radians = this.rotation * Math.PI / 180;
		var cos = Math.cos(radians);
		var sin = Math.sin(radians);
		var localXCos = localX * cos + this.x;
		var localXSin = localX * sin;
		var localYCos = localY * cos + this.y;
		var localYSin = localY * sin;
		var localX2Cos = localX2 * cos + this.x;
		var localX2Sin = localX2 * sin;
		var localY2Cos = localY2 * cos + this.y;
		var localY2Sin = localY2 * sin;
		var offset = this.offset;
		offset[RegionAttachment.OX1] = localXCos - localYSin;
		offset[RegionAttachment.OY1] = localYCos + localXSin;
		offset[RegionAttachment.OX2] = localXCos - localY2Sin;
		offset[RegionAttachment.OY2] = localY2Cos + localXSin;
		offset[RegionAttachment.OX3] = localX2Cos - localY2Sin;
		offset[RegionAttachment.OY3] = localY2Cos + localX2Sin;
		offset[RegionAttachment.OX4] = localX2Cos - localYSin;
		offset[RegionAttachment.OY4] = localYCos + localX2Sin;
	}

	public function setRegion(region:TextureRegion) {
		this.region = region;
		var uvs = this.uvs;
		if (region.rotate) {
			uvs[2] = region.u;
			uvs[3] = region.v2;
			uvs[4] = region.u;
			uvs[5] = region.v;
			uvs[6] = region.u2;
			uvs[7] = region.v;
			uvs[0] = region.u2;
			uvs[1] = region.v2;
		} else {
			uvs[0] = region.u;
			uvs[1] = region.v2;
			uvs[2] = region.u;
			uvs[3] = region.v;
			uvs[4] = region.u2;
			uvs[5] = region.v;
			uvs[6] = region.u2;
			uvs[7] = region.v2;
		}
	}

	/** Transforms the attachment's four vertices to world coordinates.
	 *
	 * See [World transforms](http://esotericsoftware.com/spine-runtime-skeletons#World-transforms) in the Spine
	 * Runtimes Guide.
	 * @param worldVertices The output world vertices. Must have a length >= `offset` + 8.
	 * @param offset The `worldVertices` index to begin writing values.
	 * @param stride The number of `worldVertices` entries between the value pairs written. */
	public function computeWorldVertices(bone:Bone, worldVertices:Array<Float>, offset:Int, stride:Int) {
		var vertexOffset = this.offset;
		var x = bone.worldX, y = bone.worldY;
		var a = bone.a, b = bone.b, c = bone.c, d = bone.d;
		var offsetX = 0.0, offsetY = 0.0;

		offsetX = vertexOffset[RegionAttachment.OX1];
		offsetY = vertexOffset[RegionAttachment.OY1];
		worldVertices[offset] = offsetX * a + offsetY * b + x; // br
		worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
		offset += stride;

		offsetX = vertexOffset[RegionAttachment.OX2];
		offsetY = vertexOffset[RegionAttachment.OY2];
		worldVertices[offset] = offsetX * a + offsetY * b + x; // bl
		worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
		offset += stride;

		offsetX = vertexOffset[RegionAttachment.OX3];
		offsetY = vertexOffset[RegionAttachment.OY3];
		worldVertices[offset] = offsetX * a + offsetY * b + x; // ul
		worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
		offset += stride;

		offsetX = vertexOffset[RegionAttachment.OX4];
		offsetY = vertexOffset[RegionAttachment.OY4];
		worldVertices[offset] = offsetX * a + offsetY * b + x; // ur
		worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
	}

	override function copy():RegionAttachment {
		var copy = new RegionAttachment(name);
		copy.region = this.region;
		copy.path = this.path;
		copy.x = this.x;
		copy.y = this.y;
		copy.scaleX = this.scaleX;
		copy.scaleY = this.scaleY;
		copy.rotation = this.rotation;
		copy.width = this.width;
		copy.height = this.height;
		Utils.arrayCopy(this.uvs, 0, copy.uvs, 0, 8);
		Utils.arrayCopy(this.offset, 0, copy.offset, 0, 8);
		copy.color.setFromColor(this.color);
		return copy;
	}
}
