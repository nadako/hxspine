package spine;

/** Stores the setup pose for a {@link TransformConstraint}.
 *
 * See [Transform constraints](http://esotericsoftware.com/spine-transform-constraints) in the Spine User Guide. */
class TransformConstraintData extends ConstraintData {
	/** The bones that will be modified by this transform constraint. */
	public var bones = new Array<BoneData>();

	/** The target bone whose world transform will be copied to the constrained bones. */
	public var target:BoneData;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained rotations. */
	public var rotateMix = 0.0;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained translations. */
	public var translateMix = 0.0;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained scales. */
	public var scaleMix = 0.0;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained shears. */
	public var shearMix = 0.0;

	/** An offset added to the constrained bone rotation. */
	public var offsetRotation = 0.0;

	/** An offset added to the constrained bone X translation. */
	public var offsetX = 0.0;

	/** An offset added to the constrained bone Y translation. */
	public var offsetY = 0.0;

	/** An offset added to the constrained bone scaleX. */
	public var offsetScaleX = 0.0;

	/** An offset added to the constrained bone scaleY. */
	public var offsetScaleY = 0.0;

	/** An offset added to the constrained bone shearY. */
	public var offsetShearY = 0.0;

	public var relative = false;
	public var local = false;

	public function new(name:String) {
		super(name, 0, false);
	}
}
