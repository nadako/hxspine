package spine.attachments;

import spine.utils.Color;

/** An attachment with vertices that make up a polygon used for clipping the rendering of other attachments. */
class ClippingAttachment extends VertexAttachment {
	/** Clipping is performed between the clipping polygon's slot and the end slot. Returns null if clipping is done until the end of
	 * the skeleton's rendering. */
	public var endSlot:SlotData;

	// Nonessential.

	/** The color of the clipping polygon as it was in Spine. Available only when nonessential data was exported. Clipping polygons
	 * are not usually rendered at runtime. */
	public var color = new Color(0.2275, 0.2275, 0.8078, 1); // ce3a3aff

	public function new(name:String) {
		super(name);
	}

	override function copy():ClippingAttachment {
		var copy = new ClippingAttachment(name);
		this.copyTo(copy);
		copy.endSlot = this.endSlot;
		copy.color.setFromColor(this.color);
		return copy;
	}
}
