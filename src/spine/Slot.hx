package spine;

import spine.attachments.Attachment;
import spine.utils.Color;

/** Stores a slot's current pose. Slots organize attachments for {@link Skeleton#drawOrder} purposes and provide a place to store
 * state for an attachment. State cannot be stored in an attachment itself because attachments are stateless and may be shared
 * across multiple skeletons. */
class Slot {
	/** The slot's setup pose data. */
	public var data:SlotData;

	/** The bone this slot belongs to. */
	public var bone:Bone;

	/** The color used to tint the slot's attachment. If {@link #getDarkColor()} is set, this is used as the light color for two
	 * color tinting. */
	public var color:Color;

	/** The dark color used to tint the slot's attachment for two color tinting, or null if two color tinting is not used. The dark
	 * color's alpha is not used. */
	public var darkColor:Color;

	var attachment:Attachment;

	var attachmentTime:Float;

	/** Values to deform the slot's attachment. For an unweighted mesh, the entries are local positions for each vertex. For a
	 * weighted mesh, the entries are an offset for each vertex which will be added to the mesh's local vertex positions.
	 *
	 * See {@link VertexAttachment#computeWorldVertices()} and {@link DeformTimeline}. */
	public var deform = new Array<Float>();

	public function new(data:SlotData, bone:Bone) {
		if (data == null)
			throw new Error("data cannot be null.");
		if (bone == null)
			throw new Error("bone cannot be null.");
		this.data = data;
		this.bone = bone;
		this.color = new Color();
		this.darkColor = data.darkColor == null ? null : new Color();
		setToSetupPose();
	}

	/** The skeleton this slot belongs to. */
	public function getSkeleton():Skeleton {
		return this.bone.skeleton;
	}

	/** The current attachment for the slot, or null if the slot has no attachment. */
	public function getAttachment():Attachment {
		return this.attachment;
	}

	/** Sets the slot's attachment and, if the attachment changed, resets {@link #attachmentTime} and clears {@link #deform}.
	 * @param attachment May be null. */
	public function setAttachment(attachment:Attachment) {
		if (this.attachment == attachment)
			return;
		this.attachment = attachment;
		this.attachmentTime = this.bone.skeleton.time;
		this.deform.resize(0);
	}

	public function setAttachmentTime(time:Float) {
		this.attachmentTime = this.bone.skeleton.time - time;
	}

	/** The time that has elapsed since the last time the attachment was set or cleared. Relies on Skeleton
	 * {@link Skeleton#time}. */
	public function getAttachmentTime():Float {
		return this.bone.skeleton.time - this.attachmentTime;
	}

	/** Sets this slot to the setup pose. */
	public function setToSetupPose() {
		this.color.setFromColor(this.data.color);
		if (this.darkColor != null)
			this.darkColor.setFromColor(this.data.darkColor);
		if (this.data.attachmentName == null)
			this.attachment = null;
		else {
			this.attachment = null;
			this.setAttachment(this.bone.skeleton.getAttachment(this.data.index, this.data.attachmentName));
		}
	}
}
