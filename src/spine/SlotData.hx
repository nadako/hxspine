package spine;

import spine.utils.Color;

/** Stores the setup pose for a `Slot`. */
class SlotData {
	/** The index of the slot in `Skeleton.slots`. */
	public final index:Int;

	/** The name of the slot, which is unique across all slots in the skeleton. */
	public final name:String;

	/** The bone this slot belongs to. */
	public final boneData:BoneData;

	/** The color used to tint the slot's attachment. If `darkColor` is set, this is used as the light color for two
	 * color tinting. */
	public var color = new Color(1, 1, 1, 1);

	/** The dark color used to tint the slot's attachment for two color tinting, or null if two color tinting is not used. The dark
	 * color's alpha is not used. */
	public var darkColor:Null<Color>;

	/** The name of the attachment that is visible for this slot in the setup pose, or null if no attachment is visible. */
	public var attachmentName:Null<String>;

	/** The blend mode for drawing the slot's attachment. */
	public var blendMode:BlendMode;

	public function new(index:Int, name:String, boneData:BoneData) {
		if (index < 0)
			throw new Error("index must be >= 0.");
		if (name == null)
			throw new Error("name cannot be null.");
		if (boneData == null)
			throw new Error("boneData cannot be null.");
		this.index = index;
		this.name = name;
		this.boneData = boneData;
	}
}
