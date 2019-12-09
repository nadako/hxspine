package spine.attachments;

/** Base class for an attachment with vertices that are transformed by one or more bones and can be deformed by a slot's `Slot.deform`. */
/* abstract */ class VertexAttachment extends Attachment {
	static var nextID = 0;

	/** The unique ID for this attachment. */
	public final id:Int = (VertexAttachment.nextID++ & 65535) << 11;

	/** The bones which affect the `vertices`. The array entries are, for each vertex, the number of bones affecting
	 * the vertex followed by that many bone indices, which is the index of the bone in `Skeleton.bones`. Will be null
	 * if this attachment has no weights. */
	public var bones:Null<Array<Int>>;

	/** The vertex positions in the bone's coordinate system. For a non-weighted attachment, the values are `x,y`
	 * entries for each vertex. For a weighted attachment, the values are `x,y,weight` entries for each bone affecting
	 * each vertex. */
	public var vertices:Array<Float>; // TODO: Float32Array

	/** The maximum number of world vertex values that can be output by
	 * `computeWorldVertices` using the `count` parameter. */
	public var worldVerticesLength:Int = 0;

	/** Deform keys for the deform attachment are also applied to this attachment. May be null if no deform keys should be applied. */
	public var deformAttachment:Null<VertexAttachment>;

	function new(name:String) {
		super(name);
		deformAttachment = this;
	}

	/** Transforms the attachment's local `vertices` to world coordinates. If the slot's `Slot.deform` is
	 * not empty, it is used to deform the vertices.
	 *
	 * See [World transforms](http://esotericsoftware.com/spine-runtime-skeletons#World-transforms) in the Spine
	 * Runtimes Guide.
	 * @param start The index of the first `vertices` value to transform. Each vertex has 2 values, x and y.
	 * @param count The number of world vertex values to output. Must be <= `worldVerticesLength` - `start`.
	 * @param worldVertices The output world vertices. Must have a length >= `offset` + `count` *
	 *           `stride` / 2.
	 * @param offset The `worldVertices` index to begin writing values.
	 * @param stride The number of `worldVertices` entries between the value pairs written. */
	public function computeWorldVertices(slot:Slot, start:Int, count:Int, worldVertices:Array<Float>, offset:Int, stride:Int) {
		count = offset + (count >> 1) * stride;
		var skeleton = slot.bone.skeleton;
		var deformArray = slot.deform;
		var vertices = this.vertices;
		var bones = this.bones;
		if (bones == null) {
			if (deformArray.length > 0)
				vertices = deformArray;
			var bone = slot.bone;
			var x = bone.worldX;
			var y = bone.worldY;
			var a = bone.a, b = bone.b, c = bone.c, d = bone.d;

			var v = start, w = offset;
			while (w < count) {
				var vx = vertices[v], vy = vertices[v + 1];
				worldVertices[w] = vx * a + vy * b + x;
				worldVertices[w + 1] = vx * c + vy * d + y;

				v += 2;
				w += stride;
			}
			return;
		}
		var v = 0, skip = 0;
		var i = 0;
		while (i < start) {
			var n = bones[v];
			v += n + 1;
			skip += n;

			i += 2;
		}
		var skeletonBones = skeleton.bones;
		if (deformArray.length == 0) {
			var w = offset, b = skip * 3;
			while (w < count) {
				var wx = 0.0, wy = 0.0;
				var n = bones[v++];
				n += v;
				while (v < n) {
					var bone = skeletonBones[bones[v]];
					var vx = vertices[b],
						vy = vertices[b + 1],
						weight = vertices[b + 2];
					wx += (vx * bone.a + vy * bone.b + bone.worldX) * weight;
					wy += (vx * bone.c + vy * bone.d + bone.worldY) * weight;

					v++;
					b += 3;
				}
				worldVertices[w] = wx;
				worldVertices[w + 1] = wy;
				w += stride;
			}
		} else {
			var deform = deformArray;
			var w = offset, b = skip * 3, f = skip << 1;
			while (w < count) {
				var wx = 0.0, wy = 0.0;
				var n = bones[v++];
				n += v;
				while (v < n) {
					var bone = skeletonBones[bones[v]];
					var vx = vertices[b] + deform[f],
						vy = vertices[b + 1] + deform[f + 1],
						weight = vertices[b + 2];
					wx += (vx * bone.a + vy * bone.b + bone.worldX) * weight;
					wy += (vx * bone.c + vy * bone.d + bone.worldY) * weight;

					v++;
					b += 3;
					f += 2;
				}
				worldVertices[w] = wx;
				worldVertices[w + 1] = wy;

				w += stride;
			}
		}
	}

	/** Does not copy id (generated) or name (set on construction). **/
	function copyTo(attachment:VertexAttachment) {
		if (this.bones != null) {
			attachment.bones = this.bones.copy();
		} else
			attachment.bones = null;

		if (this.vertices != null) {
			attachment.vertices = this.vertices.copy();
		} else
			attachment.vertices = null;

		attachment.worldVerticesLength = this.worldVerticesLength;
		attachment.deformAttachment = this.deformAttachment;
	}
}
