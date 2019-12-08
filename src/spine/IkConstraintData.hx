package spine;

/** Stores the setup pose for an {@link IkConstraint}.
 * <p>
 * See [IK constraints](http://esotericsoftware.com/spine-ik-constraints) in the Spine User Guide. */
class IkConstraintData extends ConstraintData {
	/** The bones that are constrained by this IK constraint. */
	public var bones = new Array<BoneData>();

	/** The bone that is the IK target. */
	public var target:BoneData;

	/** Controls the bend direction of the IK bones, either 1 or -1. */
	public var bendDirection = 1;

	/** When true and only a single bone is being constrained, if the target is too close, the bone is scaled to reach it. */
	public var compress = false;

	/** When true, if the target is out of range, the parent bone is scaled to reach it. If more than one bone is being constrained
	 * and the parent bone has local nonuniform scale, stretch is not applied. */
	public var stretch = false;

	/** When true, only a single bone is being constrained, and {@link #getCompress()} or {@link #getStretch()} is used, the bone
	 * is scaled on both the X and Y axes. */
	public var uniform = false;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained rotations. */
	public var mix = 1.0;

	/** For two bone IK, the distance from the maximum reach of the bones that rotation will slow. */
	public var softness = 0.0;

	public function new(name:String) {
		super(name, 0, false);
	}
}
