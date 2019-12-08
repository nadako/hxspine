package spine;

/** Stores the setup pose and all of the stateless data for a skeleton.
 *
 * See [Data objects](http://esotericsoftware.com/spine-runtime-architecture#Data-objects) in the Spine Runtimes
 * Guide. */
class SkeletonData {
	/** The skeleton's name, which by default is the name of the skeleton data file, if possible. May be null. */
	public var name:String;

	/** The skeleton's bones, sorted parent first. The root bone is always the first bone. */
	public var bones = new Array<BoneData>(); // Ordered parents first.

	/** The skeleton's slots. */
	public var slots = new Array<SlotData>(); // Setup pose draw order.

	public var skins = new Array<Skin>();

	/** The skeleton's default skin. By default this skin contains all attachments that were not in a skin in Spine.
	 *
	 * See {@link Skeleton#getAttachmentByName()}.
	 * May be null. */
	public var defaultSkin:Skin;

	/** The skeleton's events. */
	public var events = new Array<EventData>();

	/** The skeleton's animations. */
	public var animations = new Array<Animation>();

	/** The skeleton's IK constraints. */
	public var ikConstraints = new Array<IkConstraintData>();

	/** The skeleton's transform constraints. */
	public var transformConstraints = new Array<TransformConstraintData>();

	/** The skeleton's path constraints. */
	public var pathConstraints = new Array<PathConstraintData>();

	/** The X coordinate of the skeleton's axis aligned bounding box in the setup pose. */
	public var x:Float;

	/** The Y coordinate of the skeleton's axis aligned bounding box in the setup pose. */
	public var y:Float;

	/** The width of the skeleton's axis aligned bounding box in the setup pose. */
	public var width:Float;

	/** The height of the skeleton's axis aligned bounding box in the setup pose. */
	public var height:Float;

	/** The Spine version used to export the skeleton data, or null. */
	public var version:String;

	/** The skeleton data hash. This value will change if any of the skeleton data has changed. May be null. */
	public var hash:String;

	// Nonessential

	/** The dopesheet FPS in Spine. Available only when nonessential data was exported. */
	public var fps = 0.0;

	/** The path to the images directory as defined in Spine. Available only when nonessential data was exported. May be null. */
	public var imagesPath:String;

	/** The path to the audio directory as defined in Spine. Available only when nonessential data was exported. May be null. */
	public var audioPath:String;

	public function new() {}

	/** Finds a bone by comparing each bone's name. It is more efficient to cache the results of this method than to call it
	 * multiple times.
	 * @returns May be null. */
	public function findBone(boneName:String) {
		if (boneName == null)
			throw new Error("boneName cannot be null.");
		for (bone in bones) {
			if (bone.name == boneName)
				return bone;
		}
		return null;
	}

	public function findBoneIndex(boneName:String) {
		if (boneName == null)
			throw new Error("boneName cannot be null.");
		var bones = this.bones;
		for (i in 0...bones.length)
			if (bones[i].name == boneName)
				return i;
		return -1;
	}

	/** Finds a slot by comparing each slot's name. It is more efficient to cache the results of this method than to call it
	 * multiple times.
	 * @returns May be null. */
	public function findSlot(slotName:String) {
		if (slotName == null)
			throw new Error("slotName cannot be null.");
		for (slot in slots) {
			if (slot.name == slotName)
				return slot;
		}
		return null;
	}

	public function findSlotIndex(slotName:String) {
		if (slotName == null)
			throw new Error("slotName cannot be null.");
		var slots = this.slots;
		for (i in 0...slots.length)
			if (slots[i].name == slotName)
				return i;
		return -1;
	}

	/** Finds a skin by comparing each skin's name. It is more efficient to cache the results of this method than to call it
	 * multiple times.
	 * @returns May be null. */
	public function findSkin(skinName:String) {
		if (skinName == null)
			throw new Error("skinName cannot be null.");
		for (skin in skins) {
			if (skin.name == skinName)
				return skin;
		}
		return null;
	}

	/** Finds an event by comparing each events's name. It is more efficient to cache the results of this method than to call it
	 * multiple times.
	 * @returns May be null. */
	public function findEvent(eventDataName:String) {
		if (eventDataName == null)
			throw new Error("eventDataName cannot be null.");
		for (event in events) {
			if (event.name == eventDataName)
				return event;
		}
		return null;
	}

	/** Finds an animation by comparing each animation's name. It is more efficient to cache the results of this method than to
	 * call it multiple times.
	 * @returns May be null. */
	public function findAnimation(animationName:String) {
		if (animationName == null)
			throw new Error("animationName cannot be null.");
		for (animation in animations) {
			if (animation.name == animationName)
				return animation;
		}
		return null;
	}

	/** Finds an IK constraint by comparing each IK constraint's name. It is more efficient to cache the results of this method
	 * than to call it multiple times.
	 * @return May be null. */
	public function findIkConstraint(constraintName:String) {
		if (constraintName == null)
			throw new Error("constraintName cannot be null.");
		for (constraint in ikConstraints) {
			if (constraint.name == constraintName)
				return constraint;
		}
		return null;
	}

	/** Finds a transform constraint by comparing each transform constraint's name. It is more efficient to cache the results of
	 * this method than to call it multiple times.
	 * @return May be null. */
	public function findTransformConstraint(constraintName:String) {
		if (constraintName == null)
			throw new Error("constraintName cannot be null.");
		for (constraint in transformConstraints) {
			if (constraint.name == constraintName)
				return constraint;
		}
		return null;
	}

	/** Finds a path constraint by comparing each path constraint's name. It is more efficient to cache the results of this method
	 * than to call it multiple times.
	 * @return May be null. */
	public function findPathConstraint(constraintName:String) {
		if (constraintName == null)
			throw new Error("constraintName cannot be null.");
		for (constraint in pathConstraints) {
			if (constraint.name == constraintName)
				return constraint;
		}
		return null;
	}

	public function findPathConstraintIndex(pathConstraintName:String) {
		if (pathConstraintName == null)
			throw new Error("pathConstraintName cannot be null.");
		var pathConstraints = this.pathConstraints;
		for (i in 0...pathConstraints.length)
			if (pathConstraints[i].name == pathConstraintName)
				return i;
		return -1;
	}
}
