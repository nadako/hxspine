package spine;

import spine.attachments.MeshAttachment;
import spine.utils.Utils;
import spine.attachments.RegionAttachment;
import spine.attachments.PathAttachment;
import spine.attachments.Attachment;
import spine.utils.Color;
import spine.utils.Vector2;

/** Stores the current pose for a skeleton.
 *
 * See [Instance objects](http://esotericsoftware.com/spine-runtime-architecture#Instance-objects) in the Spine Runtimes Guide. */
class Skeleton {
	/** The skeleton's setup pose data. */
	public var data:SkeletonData;

	/** The skeleton's bones, sorted parent first. The root bone is always the first bone. */
	public var bones:Array<Bone>;

	/** The skeleton's slots. */
	public var slots:Array<Slot>;

	/** The skeleton's slots in the order they should be drawn. The returned array may be modified to change the draw order. */
	public var drawOrder:Array<Slot>;

	/** The skeleton's IK constraints. */
	public var ikConstraints:Array<IkConstraint>;

	/** The skeleton's transform constraints. */
	public var transformConstraints:Array<TransformConstraint>;

	/** The skeleton's path constraints. */
	public var pathConstraints:Array<PathConstraint>;

	/** The list of bones and constraints, sorted in the order they should be updated, as computed by {@link #updateCache()}. */
	public var _updateCache = new Array<Updatable>();

	public var updateCacheReset = new Array<Updatable>();

	/** The skeleton's current skin. May be null. */
	public var skin:Skin;

	/** The color to tint all the skeleton's attachments. */
	public var color:Color;

	/** Returns the skeleton's time. This can be used for tracking, such as with Slot {@link Slot#attachmentTime}.
	 * <p>
	 * See {@link #update()}. */
	public var time = 0.0;

	/** Scales the entire skeleton on the X axis. This affects all bones, even if the bone's transform mode disallows scale
	 * inheritance. */
	public var scaleX = 1.0;

	/** Scales the entire skeleton on the Y axis. This affects all bones, even if the bone's transform mode disallows scale
	 * inheritance. */
	public var scaleY = 1.0;

	/** Sets the skeleton X position, which is added to the root bone worldX position. */
	public var x = 0.0;

	/** Sets the skeleton Y position, which is added to the root bone worldY position. */
	public var y = 0.0;

	public function new(data:SkeletonData) {
		if (data == null)
			throw new Error("data cannot be null.");
		this.data = data;

		this.bones = new Array<Bone>();
		for (boneData in data.bones) {
			var bone:Bone;
			if (boneData.parent == null)
				bone = new Bone(boneData, this, null);
			else {
				var parent = this.bones[boneData.parent.index];
				bone = new Bone(boneData, this, parent);
				parent.children.push(bone);
			}
			this.bones.push(bone);
		}

		this.slots = new Array<Slot>();
		this.drawOrder = new Array<Slot>();
		for (slotData in data.slots) {
			var bone = this.bones[slotData.boneData.index];
			var slot = new Slot(slotData, bone);
			this.slots.push(slot);
			this.drawOrder.push(slot);
		}

		this.ikConstraints = new Array<IkConstraint>();
		for (ikConstraintData in data.ikConstraints) {
			this.ikConstraints.push(new IkConstraint(ikConstraintData, this));
		}

		this.transformConstraints = new Array<TransformConstraint>();
		for (transformConstraintData in data.transformConstraints) {
			this.transformConstraints.push(new TransformConstraint(transformConstraintData, this));
		}

		this.pathConstraints = new Array<PathConstraint>();
		for (pathConstraintData in data.pathConstraints) {
			this.pathConstraints.push(new PathConstraint(pathConstraintData, this));
		}

		this.color = new Color(1, 1, 1, 1);
		this.updateCache();
	}

	/** Caches information about bones and constraints. Must be called if the {@link #getSkin()} is modified or if bones,
	 * constraints, or weighted path attachments are added or removed. */
	public function updateCache() {
		var updateCache = this._updateCache;
		updateCache.resize(0);
		this.updateCacheReset.resize(0);

		var bones = this.bones;
		for (bone in bones) {
			bone.sorted = bone.data.skinRequired;
			bone.active = !bone.sorted;
		}

		if (this.skin != null) {
			var skinBones = this.skin.bones;
			for (i in 0...this.skin.bones.length) {
				var bone = this.bones[skinBones[i].index];
				do {
					bone.sorted = false;
					bone.active = true;
					bone = bone.parent;
				} while (bone != null);
			}
		}

		// IK first, lowest hierarchy depth first.
		var ikConstraints = this.ikConstraints;
		var transformConstraints = this.transformConstraints;
		var pathConstraints = this.pathConstraints;
		var ikCount = ikConstraints.length,
			transformCount = transformConstraints.length,
			pathCount = pathConstraints.length;
		var constraintCount = ikCount + transformCount + pathCount;

		for (i in 0...constraintCount) {
			var outerContinue = false;
			for (ii in 0...ikCount) {
				var constraint = ikConstraints[ii];
				if (constraint.data.order == i) {
					this.sortIkConstraint(constraint);
					outerContinue = true;
					break;
				}
			}
			if (outerContinue)
				continue;
			for (ii in 0...transformCount) {
				var constraint = transformConstraints[ii];
				if (constraint.data.order == i) {
					this.sortTransformConstraint(constraint);
					outerContinue = true;
					break;
				}
			}
			if (outerContinue)
				continue;
			for (ii in 0...pathCount) {
				var constraint = pathConstraints[ii];
				if (constraint.data.order == i) {
					this.sortPathConstraint(constraint);
					break;
				}
			}
		}

		for (bone in bones)
			this.sortBone(bone);
	}

	public function sortIkConstraint(constraint:IkConstraint) {
		constraint.active = constraint.target.isActive()
			&& (!constraint.data.skinRequired || (this.skin != null && Utils.contains(this.skin.constraints, constraint.data)));
		if (!constraint.active)
			return;

		var target = constraint.target;
		this.sortBone(target);

		var constrained = constraint.bones;
		var parent = constrained[0];
		this.sortBone(parent);

		if (constrained.length > 1) {
			var child = constrained[constrained.length - 1];
			if (!(this._updateCache.indexOf(child) > -1))
				this.updateCacheReset.push(child);
		}

		this._updateCache.push(constraint);

		this.sortReset(parent.children);
		constrained[constrained.length - 1].sorted = true;
	}

	public function sortPathConstraint(constraint:PathConstraint) {
		constraint.active = constraint.target.bone.isActive()
			&& (!constraint.data.skinRequired || (this.skin != null && Utils.contains(this.skin.constraints, constraint.data)));
		if (!constraint.active)
			return;

		var slot = constraint.target;
		var slotIndex = slot.data.index;
		var slotBone = slot.bone;
		if (this.skin != null)
			this.sortPathConstraintAttachment(this.skin, slotIndex, slotBone);
		if (this.data.defaultSkin != null && this.data.defaultSkin != this.skin)
			this.sortPathConstraintAttachment(this.data.defaultSkin, slotIndex, slotBone);
		for (skin in this.data.skins)
			this.sortPathConstraintAttachment(skin, slotIndex, slotBone);

		var attachment = slot.getAttachment();
		if (Std.is(attachment, PathAttachment))
			this.sortPathConstraintAttachmentWith(attachment, slotBone);

		var constrained = constraint.bones;
		var boneCount = constrained.length;
		for (i in 0...boneCount)
			this.sortBone(constrained[i]);

		this._updateCache.push(constraint);

		for (i in 0...boneCount)
			this.sortReset(constrained[i].children);
		for (i in 0...boneCount)
			constrained[i].sorted = true;
	}

	public function sortTransformConstraint(constraint:TransformConstraint) {
		constraint.active = constraint.target.isActive()
			&& (!constraint.data.skinRequired || (this.skin != null && Utils.contains(this.skin.constraints, constraint.data)));
		if (!constraint.active)
			return;

		this.sortBone(constraint.target);

		var constrained = constraint.bones;
		var boneCount = constrained.length;
		if (constraint.data.local) {
			for (i in 0...boneCount) {
				var child = constrained[i];
				this.sortBone(child.parent);
				if (!(this._updateCache.indexOf(child) > -1))
					this.updateCacheReset.push(child);
			}
		} else {
			for (i in 0...boneCount) {
				this.sortBone(constrained[i]);
			}
		}

		this._updateCache.push(constraint);

		for (ii in 0...boneCount)
			this.sortReset(constrained[ii].children);
		for (ii in 0...boneCount)
			constrained[ii].sorted = true;
	}

	public function sortPathConstraintAttachment(skin:Skin, slotIndex:Int, slotBone:Bone) {
		var attachments = skin.attachments[slotIndex];
		if (attachments == null)
			return;
		for (attachment in attachments) {
			this.sortPathConstraintAttachmentWith(attachment, slotBone);
		}
	}

	public function sortPathConstraintAttachmentWith(attachment:Attachment, slotBone:Bone) {
		if (!Std.is(attachment, PathAttachment))
			return;
		var pathBones = (cast attachment : PathAttachment).bones;
		if (pathBones == null)
			this.sortBone(slotBone);
		else {
			var bones = this.bones;
			var i = 0;
			while (i < pathBones.length) {
				var boneCount = pathBones[i++];
				var n = i + boneCount;
				while (i < n) {
					var boneIndex = pathBones[i];
					this.sortBone(bones[boneIndex]);
					i++;
				}
			}
		}
	}

	public function sortBone(bone:Bone) {
		if (bone.sorted)
			return;
		var parent = bone.parent;
		if (parent != null)
			this.sortBone(parent);
		bone.sorted = true;
		this._updateCache.push(bone);
	}

	public function sortReset(bones:Array<Bone>) {
		for (bone in bones) {
			if (!bone.active)
				continue;
			if (bone.sorted)
				this.sortReset(bone.children);
			bone.sorted = false;
		}
	}

	/** Updates the world transform for each bone and applies all constraints.
	 *
	 * See [World transforms](http://esotericsoftware.com/spine-runtime-skeletons#World-transforms) in the Spine
	 * Runtimes Guide. */
	public function updateWorldTransform() {
		var updateCacheReset = this.updateCacheReset;
		for (updatable in updateCacheReset) {
			var bone:Bone = cast updatable;
			bone.ax = bone.x;
			bone.ay = bone.y;
			bone.arotation = bone.rotation;
			bone.ascaleX = bone.scaleX;
			bone.ascaleY = bone.scaleY;
			bone.ashearX = bone.shearX;
			bone.ashearY = bone.shearY;
			bone.appliedValid = true;
		}
		var updateCache = this._updateCache;
		for (c in updateCache)
			c.update();
	}

	/** Sets the bones, constraints, and slots to their setup pose values. */
	public function setToSetupPose() {
		this.setBonesToSetupPose();
		this.setSlotsToSetupPose();
	}

	/** Sets the bones and constraints to their setup pose values. */
	public function setBonesToSetupPose() {
		var bones = this.bones;
		for (bone in bones)
			bone.setToSetupPose();

		var ikConstraints = this.ikConstraints;
		for (constraint in ikConstraints) {
			constraint.mix = constraint.data.mix;
			constraint.softness = constraint.data.softness;
			constraint.bendDirection = constraint.data.bendDirection;
			constraint.compress = constraint.data.compress;
			constraint.stretch = constraint.data.stretch;
		}

		var transformConstraints = this.transformConstraints;
		for (constraint in transformConstraints) {
			var data = constraint.data;
			constraint.rotateMix = data.rotateMix;
			constraint.translateMix = data.translateMix;
			constraint.scaleMix = data.scaleMix;
			constraint.shearMix = data.shearMix;
		}

		var pathConstraints = this.pathConstraints;
		for (constraint in pathConstraints) {
			var data = constraint.data;
			constraint.position = data.position;
			constraint.spacing = data.spacing;
			constraint.rotateMix = data.rotateMix;
			constraint.translateMix = data.translateMix;
		}
	}

	/** Sets the slots and draw order to their setup pose values. */
	public function setSlotsToSetupPose() {
		var slots = this.slots;
		Utils.arrayCopy(slots, 0, this.drawOrder, 0, slots.length);
		for (slot in slots)
			slot.setToSetupPose();
	}

	/** @returns May return null. */
	public function getRootBone() {
		if (this.bones.length == 0)
			return null;
		return this.bones[0];
	}

	/** @returns May be null. */
	public function findBone(boneName:String) {
		if (boneName == null)
			throw new Error("boneName cannot be null.");
		for (bone in bones) {
			if (bone.data.name == boneName)
				return bone;
		}
		return null;
	}

	/** @returns -1 if the bone was not found. */
	public function findBoneIndex(boneName:String) {
		if (boneName == null)
			throw new Error("boneName cannot be null.");
		var bones = this.bones;
		for (i in 0...bones.length)
			if (bones[i].data.name == boneName)
				return i;
		return -1;
	}

	/** Finds a slot by comparing each slot's name. It is more efficient to cache the results of this method than to call it
	 * repeatedly.
	 * @returns May be null. */
	public function findSlot(slotName:String) {
		if (slotName == null)
			throw new Error("slotName cannot be null.");
		for (slot in slots) {
			if (slot.data.name == slotName)
				return slot;
		}
		return null;
	}

	/** @returns -1 if the bone was not found. */
	public function findSlotIndex(slotName:String) {
		if (slotName == null)
			throw new Error("slotName cannot be null.");
		var slots = this.slots;
		for (i in 0...slots.length)
			if (slots[i].data.name == slotName)
				return i;
		return -1;
	}

	/** Sets a skin by name.
	 *
	 * See {@link #setSkin()}. */
	public function setSkinByName(skinName:String) {
		var skin = data.findSkin(skinName);
		if (skin == null)
			throw new Error("Skin not found: " + skinName);
		this.setSkin(skin);
	}

	/** Sets the skin used to look up attachments before looking in the {@link SkeletonData#defaultSkin default skin}. If the
	 * skin is changed, {@link #updateCache()} is called.
	 *
	 * Attachments from the new skin are attached if the corresponding attachment from the old skin was attached. If there was no
	 * old skin, each slot's setup mode attachment is attached from the new skin.
	 *
	 * After changing the skin, the visible attachments can be reset to those attached in the setup pose by calling
	 * {@link #setSlotsToSetupPose()}. Also, often {@link AnimationState#apply()} is called before the next time the
	 * skeleton is rendered to allow any attachment keys in the current animation(s) to hide or show attachments from the new skin.
	 * @param newSkin May be null. */
	public function setSkin(newSkin:Skin) {
		if (newSkin == this.skin)
			return;
		if (newSkin != null) {
			if (this.skin != null)
				newSkin.attachAll(this, this.skin);
			else {
				var slots = this.slots;
				for (i in 0...slots.length) {
					var slot = slots[i];
					var name = slot.data.attachmentName;
					if (name != null) {
						var attachment = newSkin.getAttachment(i, name);
						if (attachment != null)
							slot.setAttachment(attachment);
					}
				}
			}
		}
		this.skin = newSkin;
		this.updateCache();
	}

	/** Finds an attachment by looking in the {@link #skin} and {@link SkeletonData#defaultSkin} using the slot name and attachment
	 * name.
	 *
	 * See {@link #getAttachment()}.
	 * @returns May be null. */
	public function getAttachmentByName(slotName:String, attachmentName:String):Attachment {
		return this.getAttachment(this.data.findSlotIndex(slotName), attachmentName);
	}

	/** Finds an attachment by looking in the {@link #skin} and {@link SkeletonData#defaultSkin} using the slot index and
	 * attachment name. First the skin is checked and if the attachment was not found, the default skin is checked.
	 *
	 * See [Runtime skins](http://esotericsoftware.com/spine-runtime-skins) in the Spine Runtimes Guide.
	 * @returns May be null. */
	public function getAttachment(slotIndex:Int, attachmentName:String):Attachment {
		if (attachmentName == null)
			throw new Error("attachmentName cannot be null.");
		if (this.skin != null) {
			var attachment = this.skin.getAttachment(slotIndex, attachmentName);
			if (attachment != null)
				return attachment;
		}
		if (this.data.defaultSkin != null)
			return this.data.defaultSkin.getAttachment(slotIndex, attachmentName);
		return null;
	}

	/** A convenience method to set an attachment by finding the slot with {@link #findSlot()}, finding the attachment with
	 * {@link #getAttachment()}, then setting the slot's {@link Slot#attachment}.
	 * @param attachmentName May be null to clear the slot's attachment. */
	public function setAttachment(slotName:String, attachmentName:String) {
		if (slotName == null)
			throw new Error("slotName cannot be null.");
		var slots = this.slots;
		for (i in 0...slots.length) {
			var slot = slots[i];
			if (slot.data.name == slotName) {
				var attachment:Attachment = null;
				if (attachmentName != null) {
					attachment = this.getAttachment(i, attachmentName);
					if (attachment == null)
						throw new Error("Attachment not found: " + attachmentName + ", for slot: " + slotName);
				}
				slot.setAttachment(attachment);
				return;
			}
		}
		throw new Error("Slot not found: " + slotName);
	}

	/** Finds an IK constraint by comparing each IK constraint's name. It is more efficient to cache the results of this method
	 * than to call it repeatedly.
	 * @return May be null. */
	public function findIkConstraint(constraintName:String) {
		if (constraintName == null)
			throw new Error("constraintName cannot be null.");
		for (ikConstraint in ikConstraints) {
			if (ikConstraint.data.name == constraintName)
				return ikConstraint;
		}
		return null;
	}

	/** Finds a transform constraint by comparing each transform constraint's name. It is more efficient to cache the results of
	 * this method than to call it repeatedly.
	 * @return May be null. */
	public function findTransformConstraint(constraintName:String) {
		if (constraintName == null)
			throw new Error("constraintName cannot be null.");
		for (constraint in transformConstraints) {
			if (constraint.data.name == constraintName)
				return constraint;
		}
		return null;
	}

	/** Finds a path constraint by comparing each path constraint's name. It is more efficient to cache the results of this method
	 * than to call it repeatedly.
	 * @return May be null. */
	public function findPathConstraint(constraintName:String) {
		if (constraintName == null)
			throw new Error("constraintName cannot be null.");
		for (constraint in pathConstraints) {
			if (constraint.data.name == constraintName)
				return constraint;
		}
		return null;
	}

	/** Returns the axis aligned bounding box (AABB) of the region and mesh attachments for the current pose.
	 * @param offset An output value, the distance from the skeleton origin to the bottom left corner of the AABB.
	 * @param size An output value, the width and height of the AABB.
	 * @param temp Working memory to temporarily store attachments' computed world vertices. */
	public function getBounds(offset:Vector2, size:Vector2, ?temp:Array<Float>) {
		if (offset == null)
			throw new Error("offset cannot be null.");
		if (size == null)
			throw new Error("size cannot be null.");
		if (temp == null)
			temp = [0.0, 0.0];
		var drawOrder = this.drawOrder;
		var minX = Math.POSITIVE_INFINITY,
			minY = Math.POSITIVE_INFINITY,
			maxX = Math.NEGATIVE_INFINITY,
			maxY = Math.NEGATIVE_INFINITY;
		for (slot in drawOrder) {
			if (!slot.bone.active)
				continue;
			var verticesLength = 0;
			var vertices = null;
			var attachment = slot.getAttachment();
			if (Std.is(attachment, RegionAttachment)) {
				verticesLength = 8;
				vertices = Utils.setArraySize(temp, verticesLength, 0);
				(cast attachment : RegionAttachment).computeWorldVertices(slot.bone, vertices, 0, 2);
			} else if (Std.is(attachment, MeshAttachment)) {
				var mesh:MeshAttachment = cast attachment;
				verticesLength = mesh.worldVerticesLength;
				vertices = Utils.setArraySize(temp, verticesLength, 0);
				mesh.computeWorldVertices(slot, 0, verticesLength, vertices, 0, 2);
			}
			if (vertices != null) {
				var ii = 0, nn = vertices.length;
				while (ii < nn) {
					var x = vertices[ii], y = vertices[ii + 1];
					minX = Math.min(minX, x);
					minY = Math.min(minY, y);
					maxX = Math.max(maxX, x);
					maxY = Math.max(maxY, y);
					ii += 2;
				}
			}
		}
		offset.set(minX, minY);
		size.set(maxX - minX, maxY - minY);
	}

	/** Increments the skeleton's {@link #time}. */
	public function update(delta:Float) {
		this.time += delta;
	}
}
