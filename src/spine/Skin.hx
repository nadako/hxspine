package spine;

import spine.attachments.MeshAttachment;
import spine.attachments.Attachment;

/** Stores an entry in the skin consisting of the slot index, name, and attachment **/
class SkinEntry {
	public var slotIndex:Int;
	public var name:String;
	public var attachment:Attachment;

	public function new(slotIndex:Int, name:String, attachment:Attachment) {
		this.slotIndex = slotIndex;
		this.name = name;
		this.attachment = attachment;
	}
}

/** Stores attachments by slot index and attachment name.
 *
 * See SkeletonData {@link SkeletonData#defaultSkin}, Skeleton {@link Skeleton#skin}, and
 * [Runtime skins](http://esotericsoftware.com/spine-runtime-skins) in the Spine Runtimes Guide. */
class Skin {
	/** The skin's name, which is unique across all skins in the skeleton. */
	public var name:String;

	public var attachments = new Array<Map<String, Attachment>>();
	public var bones = new Array<BoneData>();
	public var constraints = new Array<ConstraintData>();

	public function new(name:String) {
		if (name == null)
			throw new Error("name cannot be null.");
		this.name = name;
	}

	/** Adds an attachment to the skin for the specified slot index and name. */
	public function setAttachment(slotIndex:Int, name:String, attachment:Attachment) {
		if (attachment == null)
			throw new Error("attachment cannot be null.");
		var attachments = this.attachments;
		if (slotIndex >= attachments.length)
			attachments.resize(slotIndex + 1);
		if (attachments[slotIndex] == null)
			attachments[slotIndex] = new Map();
		attachments[slotIndex][name] = attachment;
	}

	/** Adds all attachments, bones, and constraints from the specified skin to this skin. */
	public function addSkin(skin:Skin) {
		for (bone in skin.bones) {
			var contained = false;
			for (ourBone in this.bones) {
				if (ourBone == bone) {
					contained = true;
					break;
				}
			}
			if (!contained)
				this.bones.push(bone);
		}

		for (constraint in skin.constraints) {
			var contained = false;
			for (ourConstraint in this.constraints) {
				if (ourConstraint == constraint) {
					contained = true;
					break;
				}
			}
			if (!contained)
				this.constraints.push(constraint);
		}

		var attachments = skin.getAttachments();
		for (attachment in attachments) {
			this.setAttachment(attachment.slotIndex, attachment.name, attachment.attachment);
		}
	}

	/** Adds all bones and constraints and copies of all attachments from the specified skin to this skin. Mesh attachments are not
	 * copied, instead a new linked mesh is created. The attachment copies can be modified without affecting the originals. */
	public function copySkin(skin:Skin) {
		for (bone in skin.bones) {
			var contained = false;
			for (ourBone in this.bones) {
				if (ourBone == bone) {
					contained = true;
					break;
				}
			}
			if (!contained)
				this.bones.push(bone);
		}

		for (constraint in skin.constraints) {
			var contained = false;
			for (ourConstraint in this.constraints) {
				if (ourConstraint == constraint) {
					contained = true;
					break;
				}
			}
			if (!contained)
				this.constraints.push(constraint);
		}

		var attachments = skin.getAttachments();
		for (attachment in attachments) {
			if (attachment.attachment == null)
				continue;
			if (Std.is(attachment.attachment, MeshAttachment)) {
				attachment.attachment = (cast attachment.attachment : MeshAttachment).newLinkedMesh();
				this.setAttachment(attachment.slotIndex, attachment.name, attachment.attachment);
			} else {
				attachment.attachment = attachment.attachment.copy();
				this.setAttachment(attachment.slotIndex, attachment.name, attachment.attachment);
			}
		}
	}

	/** Returns the attachment for the specified slot index and name, or null. */
	public function getAttachment(slotIndex:Int, name:String):Attachment {
		var dictionary = this.attachments[slotIndex];
		return dictionary != null ? dictionary[name] : null;
	}

	/** Removes the attachment in the skin for the specified slot index and name, if any. */
	public function removeAttachment(slotIndex:Int, name:String) {
		var dictionary = this.attachments[slotIndex];
		if (dictionary != null)
			dictionary.remove(name);
	}

	/** Returns all attachments in this skin. */
	public function getAttachments():Array<SkinEntry> {
		var entries = new Array<SkinEntry>();
		for (i in 0...this.attachments.length) {
			var slotAttachments = this.attachments[i];
			if (slotAttachments != null) {
				for (name => attachment in slotAttachments) {
					entries.push(new SkinEntry(i, name, attachment));
				}
			}
		}
		return entries;
	}

	/** Returns all attachments in this skin for the specified slot index. */
	public function getAttachmentsForSlot(slotIndex:Int, attachments:Array<SkinEntry>) {
		var slotAttachments = this.attachments[slotIndex];
		if (slotAttachments != null) {
			for (name => attachment in slotAttachments) {
				attachments.push(new SkinEntry(slotIndex, name, attachment));
			}
		}
	}

	/** Clears all attachments, bones, and constraints. */
	public function clear() {
		this.attachments.resize(0);
		this.bones.resize(0);
		this.constraints.resize(0);
	}

	/** Attach each attachment in this skin if the corresponding attachment in the old skin is currently attached. */
	public function attachAll(skeleton:Skeleton, oldSkin:Skin) {
		var slotIndex = 0;
		for (slot in skeleton.slots) {
			var slotAttachment = slot.getAttachment();
			if (slotAttachment != null && slotIndex < oldSkin.attachments.length) {
				var dictionary = oldSkin.attachments[slotIndex];
				for (key => skinAttachment in dictionary) {
					if (slotAttachment == skinAttachment) {
						var attachment = this.getAttachment(slotIndex, key);
						if (attachment != null)
							slot.setAttachment(attachment);
						break;
					}
				}
			}
			slotIndex++;
		}
	}
}
