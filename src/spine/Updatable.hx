package spine;

/** The interface for items updated by {@link Skeleton#updateWorldTransform()}. */
interface Updatable {
	function update():Void;

	/** Returns false when this item has not been updated because a skin is required and the {@link Skeleton#skin active skin}
	 * does not contain this item.
	 * @see Skin#getBones()
	 * @see Skin#getConstraints() */
	function isActive():Bool;
}
