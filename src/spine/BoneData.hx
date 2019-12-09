package spine;

import spine.utils.Color;

/** Stores the setup pose for a `Bone`. */
class BoneData {
	/** The index of the bone in `Skeleton.bones`. */
	public final index:Int;

	/** The name of the bone, which is unique within the skeleton. */
	public final name:String;

	public final parent:Null<BoneData>;

	/** The bone's length. */
	public var length:Float;

	/** The local x translation. */
	public var x:Float = 0;

	/** The local y translation. */
	public var y:Float = 0;

	/** The local rotation. */
	public var rotation:Float = 0;

	/** The local scaleX. */
	public var scaleX:Float = 1;

	/** The local scaleY. */
	public var scaleY:Float = 1;

	/** The local shearX. */
	public var shearX:Float = 0;

	/** The local shearX. */
	public var shearY:Float = 0;

	/** The transform mode for how parent world transforms affect this bone. */
	public var transformMode:TransformMode = Normal;

	/** When true, `Skeleton.updateWorldTransform` only updates this bone if the`Skeleton.skin` contains this bone.
	 * @see `Skin.bones` */
	public var skinRequired:Bool = false;

	/** The color of the bone as it was in Spine. Available only when nonessential data was exported. Bones are not usually rendered at runtime. */
	public var color:Color = new Color();

	public function new(index:Int, name:String, parent:Null<BoneData>) {
		if (index < 0)
			throw new Error("index must be >= 0.");
		if (name == null)
			throw new Error("name cannot be null.");
		this.index = index;
		this.name = name;
		this.parent = parent;
	}
}

/** Determines how a bone inherits world transforms from parent bones. */
enum abstract TransformMode(Int) {
	var Normal;
	var OnlyTranslation;
	var NoRotationOrReflection;
	var NoScale;
	var NoScaleOrReflection;
}
