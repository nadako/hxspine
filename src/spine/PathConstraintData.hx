package spine;

/** Stores the setup pose for a {@link PathConstraint}.
 *
 * See [Path constraints](http://esotericsoftware.com/spine-path-constraints) in the Spine User Guide. */
class PathConstraintData extends ConstraintData {
	/** The bones that will be modified by this path constraint. */
	public var bones = new Array<BoneData>();

	/** The slot whose path attachment will be used to constrained the bones. */
	public var target:SlotData;

	/** The mode for positioning the first bone on the path. */
	public var positionMode:PositionMode;

	/** The mode for positioning the bones after the first bone on the path. */
	public var spacingMode:SpacingMode;

	/** The mode for adjusting the rotation of the bones. */
	public var rotateMode:RotateMode;

	/** An offset added to the constrained bone rotation. */
	public var offsetRotation:Float;

	/** The position along the path. */
	public var position:Float;

	/** The spacing between bones. */
	public var spacing:Float;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained rotations. */
	public var rotateMix:Float;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained translations. */
	public var translateMix:Float;

	public function new(name:String) {
		super(name, 0, false);
	}
}

/** Controls how the first bone is positioned along the path.
 *
 * See [Position mode](http://esotericsoftware.com/spine-path-constraints#Position-mode) in the Spine User Guide. */
enum abstract PositionMode(Int) {
	var Fixed;
	var Percent;
}

/** Controls how bones after the first bone are positioned along the path.
 *
 * [Spacing mode](http://esotericsoftware.com/spine-path-constraints#Spacing-mode) in the Spine User Guide. */
enum abstract SpacingMode(Int) {
	var Length;
	var Fixed;
	var Percent;
}

/** Controls how bones are rotated, translated, and scaled to match the path.
 *
 * [Rotate mode](http://esotericsoftware.com/spine-path-constraints#Rotate-mod) in the Spine User Guide. */
enum abstract RotateMode(Int) {
	var Tangent;
	var Chain;
	var ChainScale;
}
