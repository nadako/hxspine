package spine.attachments;

import spine.utils.Color;

/** An attachment whose vertices make up a composite Bezier curve.
 *
 * See `PathConstraint` and [Paths](http://esotericsoftware.com/spine-paths) in the Spine User Guide. */
class PathAttachment extends VertexAttachment {
	/** The lengths along the path in the setup pose from the start of the path to the end of each Bezier curve. */
	public var lengths:Array<Float>;

	/** If true, the start and end knots are connected. */
	public var closed:Bool = false;

	/** If true, additional calculations are performed to make calculating positions along the path more accurate. If false, fewer
	 * calculations are performed but calculating positions along the path is less accurate. */
	public var constantSpeed:Bool = false;

	/** The color of the path as it was in Spine. Available only when nonessential data was exported. Paths are not usually
	 * rendered at runtime. */
	public var color:Color = new Color(1, 1, 1, 1);

	public function new(name:String) {
		super(name);
	}

	override function copy():PathAttachment {
		var copy = new PathAttachment(name);
		this.copyTo(copy);
		copy.lengths = this.lengths.copy();
		copy.closed = closed;
		copy.constantSpeed = this.constantSpeed;
		copy.color.setFromColor(this.color);
		return copy;
	}
}
