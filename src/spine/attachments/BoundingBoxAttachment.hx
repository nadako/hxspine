package spine.attachments;

import spine.utils.Color;

/** An attachment with vertices that make up a polygon. Can be used for hit detection, creating physics bodies, spawning particle
 * effects, and more.
 *
 * See `SkeletonBounds` and [Bounding Boxes](http://esotericsoftware.com/spine-bounding-boxes) in the Spine User
 * Guide. */
class BoundingBoxAttachment extends VertexAttachment {
	public var color = new Color(1, 1, 1, 1);

	public function new(name:String) {
		super(name);
	}

	override function copy():BoundingBoxAttachment {
		var copy = new BoundingBoxAttachment(name);
		this.copyTo(copy);
		copy.color.setFromColor(this.color);
		return copy;
	}
}
