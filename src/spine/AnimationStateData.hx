package spine;

/** Stores mix (crossfade) durations to be applied when `AnimationState` animations are changed. */
class AnimationStateData {
	/** The SkeletonData to look up animations when they are specified by name. */
	public final skeletonData:SkeletonData;

	/** The mix duration to use when no mix duration has been defined between two animations. */
	public var defaultMix = 0.0;

	final animationToMixTime = new Map<String, Float>();

	public function new(skeletonData:SkeletonData) {
		if (skeletonData == null)
			throw new Error("skeletonData cannot be null.");
		this.skeletonData = skeletonData;
	}

	/** Sets a mix duration by animation name.
	 *
	 * @see `setMixWith`. */
	public function setMix(fromName:String, toName:String, duration:Float) {
		var from = skeletonData.findAnimation(fromName);
		if (from == null)
			throw new Error("Animation not found: " + fromName);
		var to = skeletonData.findAnimation(toName);
		if (to == null)
			throw new Error("Animation not found: " + toName);
		setMixWith(from, to, duration);
	}

	/** Sets the mix duration when changing from the specified animation to the other.
	 *
	 * See `TrackEntry.mixDuration`. */
	public function setMixWith(from:Animation, to:Animation, duration:Float) {
		if (from == null)
			throw new Error("from cannot be null.");
		if (to == null)
			throw new Error("to cannot be null.");
		var key = from.name + "." + to.name;
		animationToMixTime[key] = duration;
	}

	/** Returns the mix duration to use when changing from the specified animation to the other, or the {@link #defaultMix} if
	 * no mix duration has been set. */
	public function getMix(from:Animation, to:Animation):Float {
		var key = from.name + "." + to.name;
		var value = animationToMixTime[key];
		return value == null ? defaultMix : value;
	}
}
