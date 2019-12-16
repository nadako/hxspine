package spine.attachments;

import spine.utils.Utils;
import spine.utils.Color;
import spine.Texture.TextureRegion;
import spine.TextureAtlas.TextureAtlasRegion;

/** An attachment that displays a textured mesh. A mesh has hull vertices and internal vertices within the hull. Holes are not
 * supported. Each vertex has UVs (texture coordinates) and triangles are used to map an image on to the mesh.
 *
 * See [Mesh attachments](http://esotericsoftware.com/spine-meshes) in the Spine User Guide. */
class MeshAttachment extends VertexAttachment {
	public var region:TextureRegion;

	/** The name of the texture region for this attachment. */
	public var path:String;

	/** The UV pair for each vertex, normalized within the texture region. */
	public var regionUVs:Array<Float>;

	/** The UV pair for each vertex, normalized within the entire texture.
	 *
	 * See `updateUVs`. */
	public var uvs:Array<Float>;

	/** Triplets of vertex indices which describe the mesh's triangulation. */
	public var triangles:Array<Int>;

	/** The color to tint the mesh. */
	public var color = new Color(1, 1, 1, 1);

	/** The width of the mesh's image. Available only when nonessential data was exported. */
	public var width:Float;

	/** The height of the mesh's image. Available only when nonessential data was exported. */
	public var height:Float;

	/** The number of entries at the beginning of `vertices` that make up the mesh hull. */
	public var hullLength:Int;

	/** Vertex index pairs describing edges for controling triangulation. Mesh triangles will never cross edges. Only available if
	 * nonessential data was exported. Triangulation is not performed at runtime. */
	public var edges:Null<Array<Int>>;

	var parentMesh:Null<MeshAttachment>;

	public function new(name:String) {
		super(name);
	}

	/** Calculates `uvs` using `regionUVs` and the `region`. Must be called after changing the region UVs or region. */
	public function updateUVs() {
		var regionUVs = this.regionUVs;
		if (this.uvs == null || this.uvs.length != regionUVs.length)
			this.uvs = Utils.newFloatArray(regionUVs.length);
		var uvs = this.uvs;
		var n = this.uvs.length;
		var u = this.region.u, v = this.region.v, width = 0.0, height = 0.0;
		if (Std.is(this.region, TextureAtlasRegion)) {
			var region:TextureAtlasRegion = cast this.region;
			var textureWidth = region.texture.getWidth(),
				textureHeight = region.texture.getHeight();
			switch (region.degrees) {
				case 90:
					u -= (region.originalHeight - region.offsetY - region.height) / textureWidth;
					v -= (region.originalWidth - region.offsetX - region.width) / textureHeight;
					width = region.originalHeight / textureWidth;
					height = region.originalWidth / textureHeight;
					var i = 0;
					while (i < n) {
						uvs[i] = u + regionUVs[i + 1] * width;
						uvs[i + 1] = v + (1 - regionUVs[i]) * height;
						i += 2;
					}
					return;
				case 180:
					u -= (region.originalWidth - region.offsetX - region.width) / textureWidth;
					v -= region.offsetY / textureHeight;
					width = region.originalWidth / textureWidth;
					height = region.originalHeight / textureHeight;
					var i = 0;
					while (i < n) {
						uvs[i] = u + (1 - regionUVs[i]) * width;
						uvs[i + 1] = v + (1 - regionUVs[i + 1]) * height;
						i += 2;
					}
					return;
				case 270:
					u -= region.offsetY / textureWidth;
					v -= region.offsetX / textureHeight;
					width = region.originalHeight / textureWidth;
					height = region.originalWidth / textureHeight;
					var i = 0;
					while (i < n) {
						uvs[i] = u + (1 - regionUVs[i + 1]) * width;
						uvs[i + 1] = v + regionUVs[i] * height;
						i += 2;
					}
					return;
			}
			u -= region.offsetX / textureWidth;
			v -= (region.originalHeight - region.offsetY - region.height) / textureHeight;
			width = region.originalWidth / textureWidth;
			height = region.originalHeight / textureHeight;
		} else if (this.region == null) {
			u = v = 0;
			width = height = 1;
		} else {
			width = this.region.u2 - u;
			height = this.region.v2 - v;
		}

		var i = 0;
		while (i < n) {
			uvs[i] = u + regionUVs[i] * width;
			uvs[i + 1] = v + regionUVs[i + 1] * height;
			i += 2;
		}
	}

	/** The parent mesh if this is a linked mesh, else null. A linked mesh shares the `bones`, `vertices`,
	 * `regionUVs`, `triangles`, `hullLength`, `edges`, `width`, and `height` with the parent mesh,
	 * but may have a different `name` or `path` (and therefore a different texture). */
	public inline function getParentMesh():Null<MeshAttachment> {
		return parentMesh;
	}

	public function setParentMesh(parentMesh:Null<MeshAttachment>) {
		this.parentMesh = parentMesh;
		if (parentMesh != null) {
			this.bones = parentMesh.bones;
			this.vertices = parentMesh.vertices;
			this.worldVerticesLength = parentMesh.worldVerticesLength;
			this.regionUVs = parentMesh.regionUVs;
			this.triangles = parentMesh.triangles;
			this.hullLength = parentMesh.hullLength;
			this.worldVerticesLength = parentMesh.worldVerticesLength;
		}
	}

	override function copy():MeshAttachment {
		if (parentMesh != null)
			return newLinkedMesh();

		var copy = new MeshAttachment(this.name);
		copy.region = this.region;
		copy.path = this.path;
		copy.color.setFromColor(this.color);

		this.copyTo(copy);
		copy.regionUVs = this.regionUVs.copy();
		copy.uvs = this.uvs.copy();
		copy.triangles = this.triangles.copy();
		copy.hullLength = this.hullLength;

		// Nonessential.
		if (this.edges != null) {
			copy.edges = this.edges.copy();
		}
		copy.width = this.width;
		copy.height = this.height;

		return copy;
	}

	/** Returns a new mesh with the `parentMesh` set to this mesh's parent mesh, if any, else to this mesh. **/
	public function newLinkedMesh():MeshAttachment {
		var copy = new MeshAttachment(this.name);
		copy.region = this.region;
		copy.path = this.path;
		copy.color.setFromColor(this.color);
		copy.deformAttachment = this.deformAttachment;
		copy.setParentMesh(this.parentMesh != null ? this.parentMesh : this);
		copy.updateUVs();
		return copy;
	}
}
