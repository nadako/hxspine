package spine;

import haxe.io.Bytes;
import spine.Animation;
import spine.utils.Utils;
import spine.utils.Color;
import spine.attachments.VertexAttachment;
import spine.attachments.Attachment;
import spine.attachments.AttachmentLoader;
import spine.attachments.MeshAttachment;
import spine.PathConstraintData.RotateMode;
import spine.PathConstraintData.SpacingMode;
import spine.PathConstraintData.PositionMode;
import spine.BoneData.TransformMode;

/** Loads skeleton data in the Spine binary format.
 *
 * See [Spine binary format](http://esotericsoftware.com/spine-binary-format) and
 * [JSON and binary data](http://esotericsoftware.com/spine-loading-skeleton-data#JSON-and-binary-data) in the Spine
 * Runtimes Guide. */
class SkeletonBinary {
	public static inline final BONE_ROTATE = 0;
	public static inline final BONE_TRANSLATE = 1;
	public static inline final BONE_SCALE = 2;
	public static inline final BONE_SHEAR = 3;

	public static inline final SLOT_ATTACHMENT = 0;
	public static inline final SLOT_COLOR = 1;
	public static inline final SLOT_TWO_COLOR = 2;

	public static inline final PATH_POSITION = 0;
	public static inline final PATH_SPACING = 1;
	public static inline final PATH_MIX = 2;

	public static inline final CURVE_LINEAR = 0;
	public static inline final CURVE_STEPPED = 1;
	public static inline final CURVE_BEZIER = 2;

	/** Scales bone positions, image sizes, and translations as they are loaded. This allows different size images to be used at
	 * runtime than were used in Spine.
	 *
	 * See [Scaling](http://esotericsoftware.com/spine-loading-skeleton-data#Scaling) in the Spine Runtimes Guide. */
	public var scale = 1.0;

	public var attachmentLoader:AttachmentLoader;

	var linkedMeshes = new Array<LinkedMesh>();

	public function new(attachmentLoader:AttachmentLoader) {
		this.attachmentLoader = attachmentLoader;
	}

	public function readSkeletonData(binary:Bytes):SkeletonData {
		var scale = this.scale;

		var skeletonData = new SkeletonData();
		skeletonData.name = ""; // BOZO

		var input = new BinaryInput(binary);

		skeletonData.hash = input.readString();
		skeletonData.version = input.readString();
		skeletonData.x = input.readFloat();
		skeletonData.y = input.readFloat();
		skeletonData.width = input.readFloat();
		skeletonData.height = input.readFloat();

		var nonessential = input.readBoolean();
		if (nonessential) {
			skeletonData.fps = input.readFloat();

			skeletonData.imagesPath = input.readString();
			skeletonData.audioPath = input.readString();
		}

		var n:Int;
		// Strings.
		n = input.readInt(true);
		for (i in 0...n)
			input.strings.push(input.readString());

		// Bones.
		n = input.readInt(true);
		for (i in 0...n) {
			var name = input.readString();
			var parent = i == 0 ? null : skeletonData.bones[input.readInt(true)];
			var data = new BoneData(i, name, parent);
			data.rotation = input.readFloat();
			data.x = input.readFloat() * scale;
			data.y = input.readFloat() * scale;
			data.scaleX = input.readFloat();
			data.scaleY = input.readFloat();
			data.shearX = input.readFloat();
			data.shearY = input.readFloat();
			data.length = input.readFloat() * scale;
			data.transformMode = cast input.readInt(true);
			data.skinRequired = input.readBoolean();
			if (nonessential)
				Color.rgba8888ToColor(data.color, input.readInt32());
			skeletonData.bones.push(data);
		}

		// Slots.
		n = input.readInt(true);
		for (i in 0...n) {
			var slotName = input.readString();
			var boneData = skeletonData.bones[input.readInt(true)];
			var data = new SlotData(i, slotName, boneData);
			Color.rgba8888ToColor(data.color, input.readInt32());

			var darkColor = input.readInt32();
			if (darkColor != -1)
				Color.rgb888ToColor(data.darkColor = new Color(), darkColor);

			data.attachmentName = input.readStringRef();
			data.blendMode = cast input.readInt(true);
			skeletonData.slots.push(data);
		}

		// IK constraints.
		n = input.readInt(true);
		for (i in 0...n) {
			var data = new IkConstraintData(input.readString());
			data.order = input.readInt(true);
			data.skinRequired = input.readBoolean();
			for (ii in 0...input.readInt(true))
				data.bones.push(skeletonData.bones[input.readInt(true)]);
			data.target = skeletonData.bones[input.readInt(true)];
			data.mix = input.readFloat();
			data.softness = input.readFloat() * scale;
			data.bendDirection = input.readByte();
			data.compress = input.readBoolean();
			data.stretch = input.readBoolean();
			data.uniform = input.readBoolean();
			skeletonData.ikConstraints.push(data);
		}

		// Transform constraints.
		n = input.readInt(true);
		for (i in 0...n) {
			var data = new TransformConstraintData(input.readString());
			data.order = input.readInt(true);
			data.skinRequired = input.readBoolean();
			for (ii in 0...input.readInt(true))
				data.bones.push(skeletonData.bones[input.readInt(true)]);
			data.target = skeletonData.bones[input.readInt(true)];
			data.local = input.readBoolean();
			data.relative = input.readBoolean();
			data.offsetRotation = input.readFloat();
			data.offsetX = input.readFloat() * scale;
			data.offsetY = input.readFloat() * scale;
			data.offsetScaleX = input.readFloat();
			data.offsetScaleY = input.readFloat();
			data.offsetShearY = input.readFloat();
			data.rotateMix = input.readFloat();
			data.translateMix = input.readFloat();
			data.scaleMix = input.readFloat();
			data.shearMix = input.readFloat();
			skeletonData.transformConstraints.push(data);
		}

		// Path constraints.
		n = input.readInt(true);
		for (i in 0...n) {
			var data = new PathConstraintData(input.readString());
			data.order = input.readInt(true);
			data.skinRequired = input.readBoolean();
			for (ii in 0...input.readInt(true))
				data.bones.push(skeletonData.bones[input.readInt(true)]);
			data.target = skeletonData.slots[input.readInt(true)];
			data.positionMode = cast input.readInt(true);
			data.spacingMode = cast input.readInt(true);
			data.rotateMode = cast input.readInt(true);
			data.offsetRotation = input.readFloat();
			data.position = input.readFloat();
			if (data.positionMode == PositionMode.Fixed)
				data.position *= scale;
			data.spacing = input.readFloat();
			if (data.spacingMode == SpacingMode.Length || data.spacingMode == SpacingMode.Fixed)
				data.spacing *= scale;
			data.rotateMix = input.readFloat();
			data.translateMix = input.readFloat();
			skeletonData.pathConstraints.push(data);
		}

		// Default skin.
		var defaultSkin = this.readSkin(input, skeletonData, true, nonessential);
		if (defaultSkin != null) {
			skeletonData.defaultSkin = defaultSkin;
			skeletonData.skins.push(defaultSkin);
		}

		// Skins.
		{
			var i = skeletonData.skins.length;
			Utils.setArraySize(skeletonData.skins, n = i + input.readInt(true), null);
			while (i < n)
				skeletonData.skins[i++] = this.readSkin(input, skeletonData, false, nonessential);
		}

		// Linked meshes.
		n = this.linkedMeshes.length;
		for (i in 0...n) {
			var linkedMesh = this.linkedMeshes[i];
			var skin = linkedMesh.skin == null ? skeletonData.defaultSkin : skeletonData.findSkin(linkedMesh.skin);
			if (skin == null)
				throw new Error("Skin not found: " + linkedMesh.skin);
			var parent = skin.getAttachment(linkedMesh.slotIndex, linkedMesh.parent);
			if (parent == null)
				throw new Error("Parent mesh not found: " + linkedMesh.parent);
			var parent:MeshAttachment = cast parent;
			linkedMesh.mesh.deformAttachment = linkedMesh.inheritDeform ? parent : linkedMesh.mesh;
			linkedMesh.mesh.setParentMesh(parent);
			linkedMesh.mesh.updateUVs();
		}
		this.linkedMeshes.resize(0);

		// Events.
		n = input.readInt(true);
		for (i in 0...n) {
			var data = new EventData(input.readStringRef());
			data.intValue = input.readInt(false);
			data.floatValue = input.readFloat();
			data.stringValue = input.readString();
			data.audioPath = input.readString();
			if (data.audioPath != null) {
				data.volume = input.readFloat();
				data.balance = input.readFloat();
			}
			skeletonData.events.push(data);
		}

		// Animations.
		n = input.readInt(true);
		for (i in 0...n)
			skeletonData.animations.push(this.readAnimation(input, input.readString(), skeletonData));
		return skeletonData;
	}

	function readSkin(input:BinaryInput, skeletonData:SkeletonData, defaultSkin:Bool, nonessential:Bool):Skin {
		var skin = null;
		var slotCount = 0;

		if (defaultSkin) {
			slotCount = input.readInt(true);
			if (slotCount == 0)
				return null;
			skin = new Skin("default");
		} else {
			skin = new Skin(input.readStringRef());
			skin.bones.resize(input.readInt(true));
			for (i in 0...skin.bones.length)
				skin.bones[i] = skeletonData.bones[input.readInt(true)];

			for (i in 0...input.readInt(true))
				skin.constraints.push(skeletonData.ikConstraints[input.readInt(true)]);
			for (i in 0...input.readInt(true))
				skin.constraints.push(skeletonData.transformConstraints[input.readInt(true)]);
			for (i in 0...input.readInt(true))
				skin.constraints.push(skeletonData.pathConstraints[input.readInt(true)]);

			slotCount = input.readInt(true);
		}

		for (i in 0...slotCount) {
			var slotIndex = input.readInt(true);
			for (ii in 0...input.readInt(true)) {
				var name = input.readStringRef();
				var attachment = this.readAttachment(input, skeletonData, skin, slotIndex, name, nonessential);
				if (attachment != null)
					skin.setAttachment(slotIndex, name, attachment);
			}
		}
		return skin;
	}

	function readAttachment(input:BinaryInput, skeletonData:SkeletonData, skin:Skin, slotIndex:Int, attachmentName:String, nonessential:Bool):Attachment {
		var scale = this.scale;

		var name = input.readStringRef();
		if (name == null)
			name = attachmentName;

		var type:AttachmentType = cast input.readByte();
		switch (type) {
			case Region:
				{
					var path = input.readStringRef();
					var rotation = input.readFloat();
					var x = input.readFloat();
					var y = input.readFloat();
					var scaleX = input.readFloat();
					var scaleY = input.readFloat();
					var width = input.readFloat();
					var height = input.readFloat();
					var color = input.readInt32();

					if (path == null)
						path = name;
					var region = this.attachmentLoader.newRegionAttachment(skin, name, path);
					if (region == null)
						return null;
					region.path = path;
					region.x = x * scale;
					region.y = y * scale;
					region.scaleX = scaleX;
					region.scaleY = scaleY;
					region.rotation = rotation;
					region.width = width * scale;
					region.height = height * scale;
					Color.rgba8888ToColor(region.color, color);
					region.updateOffset();
					return region;
				}
			case BoundingBox:
				{
					var vertexCount = input.readInt(true);
					var vertices = this.readVertices(input, vertexCount);
					var color = nonessential ? input.readInt32() : 0;

					var box = this.attachmentLoader.newBoundingBoxAttachment(skin, name);
					if (box == null)
						return null;
					box.worldVerticesLength = vertexCount << 1;
					box.vertices = vertices.vertices;
					box.bones = vertices.bones;
					if (nonessential)
						Color.rgba8888ToColor(box.color, color);
					return box;
				}
			case Mesh:
				{
					var path = input.readStringRef();
					var color = input.readInt32();
					var vertexCount = input.readInt(true);
					var uvs = this.readFloatArray(input, vertexCount << 1, 1);
					var triangles = this.readShortArray(input);
					var vertices = this.readVertices(input, vertexCount);
					var hullLength = input.readInt(true);
					var edges = null;
					var width = 0.0, height = 0.0;
					if (nonessential) {
						edges = this.readShortArray(input);
						width = input.readFloat();
						height = input.readFloat();
					}

					if (path == null)
						path = name;
					var mesh = this.attachmentLoader.newMeshAttachment(skin, name, path);
					if (mesh == null)
						return null;
					mesh.path = path;
					Color.rgba8888ToColor(mesh.color, color);
					mesh.bones = vertices.bones;
					mesh.vertices = vertices.vertices;
					mesh.worldVerticesLength = vertexCount << 1;
					mesh.triangles = triangles;
					mesh.regionUVs = uvs;
					mesh.updateUVs();
					mesh.hullLength = hullLength << 1;
					if (nonessential) {
						mesh.edges = edges;
						mesh.width = width * scale;
						mesh.height = height * scale;
					}
					return mesh;
				}
			case LinkedMesh:
				{
					var path = input.readStringRef();
					var color = input.readInt32();
					var skinName = input.readStringRef();
					var parent = input.readStringRef();
					var inheritDeform = input.readBoolean();
					var width = 0.0, height = 0.0;
					if (nonessential) {
						width = input.readFloat();
						height = input.readFloat();
					}

					if (path == null)
						path = name;
					var mesh = this.attachmentLoader.newMeshAttachment(skin, name, path);
					if (mesh == null)
						return null;
					mesh.path = path;
					Color.rgba8888ToColor(mesh.color, color);
					if (nonessential) {
						mesh.width = width * scale;
						mesh.height = height * scale;
					}
					this.linkedMeshes.push(new LinkedMesh(mesh, skinName, slotIndex, parent, inheritDeform));
					return mesh;
				}
			case Path:
				{
					var closed = input.readBoolean();
					var constantSpeed = input.readBoolean();
					var vertexCount = input.readInt(true);
					var vertices = this.readVertices(input, vertexCount);
					var lengths = Utils.newArray(Std.int(vertexCount / 3), 0.0);
					for (i in 0...lengths.length)
						lengths[i] = input.readFloat() * scale;
					var color = nonessential ? input.readInt32() : 0;

					var path = this.attachmentLoader.newPathAttachment(skin, name);
					if (path == null)
						return null;
					path.closed = closed;
					path.constantSpeed = constantSpeed;
					path.worldVerticesLength = vertexCount << 1;
					path.vertices = vertices.vertices;
					path.bones = vertices.bones;
					path.lengths = lengths;
					if (nonessential)
						Color.rgba8888ToColor(path.color, color);
					return path;
				}
			case Point:
				{
					var rotation = input.readFloat();
					var x = input.readFloat();
					var y = input.readFloat();
					var color = nonessential ? input.readInt32() : 0;

					var point = this.attachmentLoader.newPointAttachment(skin, name);
					if (point == null)
						return null;
					point.x = x * scale;
					point.y = y * scale;
					point.rotation = rotation;
					if (nonessential)
						Color.rgba8888ToColor(point.color, color);
					return point;
				}
			case Clipping:
				{
					var endSlotIndex = input.readInt(true);
					var vertexCount = input.readInt(true);
					var vertices = this.readVertices(input, vertexCount);
					var color = nonessential ? input.readInt32() : 0;

					var clip = this.attachmentLoader.newClippingAttachment(skin, name);
					if (clip == null)
						return null;
					clip.endSlot = skeletonData.slots[endSlotIndex];
					clip.worldVerticesLength = vertexCount << 1;
					clip.vertices = vertices.vertices;
					clip.bones = vertices.bones;
					if (nonessential)
						Color.rgba8888ToColor(clip.color, color);
					return clip;
				}
		}
		return null;
	}

	function readVertices(input:BinaryInput, vertexCount:Int):Vertices {
		var verticesLength = vertexCount << 1;
		var vertices = new Vertices();
		var scale = this.scale;
		if (!input.readBoolean()) {
			vertices.vertices = this.readFloatArray(input, verticesLength, scale);
			return vertices;
		}
		var weights = new Array<Float>();
		var bonesArray = new Array<Int>();
		for (i in 0...vertexCount) {
			var boneCount = input.readInt(true);
			bonesArray.push(boneCount);
			for (ii in 0...boneCount) {
				bonesArray.push(input.readInt(true));
				weights.push(input.readFloat() * scale);
				weights.push(input.readFloat() * scale);
				weights.push(input.readFloat());
			}
		}
		vertices.vertices = Utils.toFloatArray(weights);
		vertices.bones = bonesArray;
		return vertices;
	}

	function readFloatArray(input:BinaryInput, n:Int, scale:Float):Array<Float> {
		var array = new Array<Float>();
		array.resize(n);
		if (scale == 1) {
			for (i in 0...n)
				array[i] = input.readFloat();
		} else {
			for (i in 0...n)
				array[i] = input.readFloat() * scale;
		}
		return array;
	}

	function readShortArray(input:BinaryInput):Array<Int> {
		var n = input.readInt(true);
		var array = new Array<Int>();
		array.resize(n);
		for (i in 0...n)
			array[i] = input.readShort();
		return array;
	}

	function readAnimation(input:BinaryInput, name:String, skeletonData:SkeletonData):Animation {
		var timelines = new Array<Timeline>();
		var scale = this.scale;
		var duration = 0.0;
		var tempColor1 = new Color();
		var tempColor2 = new Color();

		// Slot timelines.
		for (i in 0...input.readInt(true)) {
			var slotIndex = input.readInt(true);
			for (ii in 0...input.readInt(true)) {
				var timelineType = input.readByte();
				var frameCount = input.readInt(true);
				switch (timelineType) {
					case SkeletonBinary.SLOT_ATTACHMENT:
						{
							var timeline = new AttachmentTimeline(frameCount);
							timeline.slotIndex = slotIndex;
							for (frameIndex in 0...frameCount)
								timeline.setFrame(frameIndex, input.readFloat(), input.readStringRef());
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[frameCount - 1]);
						}
					case SkeletonBinary.SLOT_COLOR:
						{
							var timeline = new ColorTimeline(frameCount);
							timeline.slotIndex = slotIndex;
							for (frameIndex in 0...frameCount) {
								var time = input.readFloat();
								Color.rgba8888ToColor(tempColor1, input.readInt32());
								timeline.setFrame(frameIndex, time, tempColor1.r, tempColor1.g, tempColor1.b, tempColor1.a);
								if (frameIndex < frameCount - 1)
									this.readCurve(input, frameIndex, timeline);
							}
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[(frameCount - 1) * ColorTimeline.ENTRIES]);
						}
					case SkeletonBinary.SLOT_TWO_COLOR:
						{
							var timeline = new TwoColorTimeline(frameCount);
							timeline.slotIndex = slotIndex;
							for (frameIndex in 0...frameCount) {
								var time = input.readFloat();
								Color.rgba8888ToColor(tempColor1, input.readInt32());
								Color.rgb888ToColor(tempColor2, input.readInt32());
								timeline.setFrame(frameIndex, time, tempColor1.r, tempColor1.g, tempColor1.b, tempColor1.a, tempColor2.r, tempColor2.g,
									tempColor2.b);
								if (frameIndex < frameCount - 1)
									this.readCurve(input, frameIndex, timeline);
							}
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[(frameCount - 1) * TwoColorTimeline.ENTRIES]);
						}
				}
			}
		}

		// Bone timelines.
		for (i in 0...input.readInt(true)) {
			var boneIndex = input.readInt(true);
			for (ii in 0...input.readInt(true)) {
				var timelineType = input.readByte();
				var frameCount = input.readInt(true);
				switch (timelineType) {
					case SkeletonBinary.BONE_ROTATE:
						{
							var timeline = new RotateTimeline(frameCount);
							timeline.boneIndex = boneIndex;
							for (frameIndex in 0...frameCount) {
								timeline.setFrame(frameIndex, input.readFloat(), input.readFloat());
								if (frameIndex < frameCount - 1)
									this.readCurve(input, frameIndex, timeline);
							}
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[(frameCount - 1) * RotateTimeline.ENTRIES]);
						}
					case SkeletonBinary.BONE_TRANSLATE | SkeletonBinary.BONE_SCALE | SkeletonBinary.BONE_SHEAR:
						{
							var timeline:TranslateTimeline;
							var timelineScale = 1.0;
							if (timelineType == SkeletonBinary.BONE_SCALE)
								timeline = new ScaleTimeline(frameCount);
							else if (timelineType == SkeletonBinary.BONE_SHEAR)
								timeline = new ShearTimeline(frameCount);
							else {
								timeline = new TranslateTimeline(frameCount);
								timelineScale = scale;
							}
							timeline.boneIndex = boneIndex;
							for (frameIndex in 0...frameCount) {
								timeline.setFrame(frameIndex, input.readFloat(), input.readFloat() * timelineScale, input.readFloat() * timelineScale);
								if (frameIndex < frameCount - 1)
									this.readCurve(input, frameIndex, timeline);
							}
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[(frameCount - 1) * TranslateTimeline.ENTRIES]);
						}
				}
			}
		}

		// IK constraint timelines.
		for (i in 0...input.readInt(true)) {
			var index = input.readInt(true);
			var frameCount = input.readInt(true);
			var timeline = new IkConstraintTimeline(frameCount);
			timeline.ikConstraintIndex = index;
			for (frameIndex in 0...frameCount) {
				timeline.setFrame(frameIndex, input.readFloat(), input.readFloat(), input.readFloat() * scale, input.readByte(), input.readBoolean(),
					input.readBoolean());
				if (frameIndex < frameCount - 1)
					this.readCurve(input, frameIndex, timeline);
			}
			timelines.push(timeline);
			duration = Math.max(duration, timeline.frames[(frameCount - 1) * IkConstraintTimeline.ENTRIES]);
		}

		// Transform constraint timelines.
		for (i in 0...input.readInt(true)) {
			var index = input.readInt(true);
			var frameCount = input.readInt(true);
			var timeline = new TransformConstraintTimeline(frameCount);
			timeline.transformConstraintIndex = index;
			for (frameIndex in 0...frameCount) {
				timeline.setFrame(frameIndex, input.readFloat(), input.readFloat(), input.readFloat(), input.readFloat(), input.readFloat());
				if (frameIndex < frameCount - 1)
					this.readCurve(input, frameIndex, timeline);
			}
			timelines.push(timeline);
			duration = Math.max(duration, timeline.frames[(frameCount - 1) * TransformConstraintTimeline.ENTRIES]);
		}

		// Path constraint timelines.
		for (i in 0...input.readInt(true)) {
			var index = input.readInt(true);
			var data = skeletonData.pathConstraints[index];
			for (ii in 0...input.readInt(true)) {
				var timelineType = input.readByte();
				var frameCount = input.readInt(true);
				switch (timelineType) {
					case SkeletonBinary.PATH_POSITION | SkeletonBinary.PATH_SPACING:
						{
							var timeline:PathConstraintPositionTimeline;
							var timelineScale = 1.0;
							if (timelineType == SkeletonBinary.PATH_SPACING) {
								timeline = new PathConstraintSpacingTimeline(frameCount);
								if (data.spacingMode == SpacingMode.Length || data.spacingMode == SpacingMode.Fixed)
									timelineScale = scale;
							} else {
								timeline = new PathConstraintPositionTimeline(frameCount);
								if (data.positionMode == PositionMode.Fixed)
									timelineScale = scale;
							}
							timeline.pathConstraintIndex = index;
							for (frameIndex in 0...frameCount) {
								timeline.setFrame(frameIndex, input.readFloat(), input.readFloat() * timelineScale);
								if (frameIndex < frameCount - 1)
									this.readCurve(input, frameIndex, timeline);
							}
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[(frameCount - 1) * PathConstraintPositionTimeline.ENTRIES]);
						}
					case SkeletonBinary.PATH_MIX:
						{
							var timeline = new PathConstraintMixTimeline(frameCount);
							timeline.pathConstraintIndex = index;
							for (frameIndex in 0...frameCount) {
								timeline.setFrame(frameIndex, input.readFloat(), input.readFloat(), input.readFloat());
								if (frameIndex < frameCount - 1)
									this.readCurve(input, frameIndex, timeline);
							}
							timelines.push(timeline);
							duration = Math.max(duration, timeline.frames[(frameCount - 1) * PathConstraintMixTimeline.ENTRIES]);
						}
				}
			}
		}

		// Deform timelines.
		for (i in 0...input.readInt(true)) {
			var skin = skeletonData.skins[input.readInt(true)];
			for (ii in 0...input.readInt(true)) {
				var slotIndex = input.readInt(true);
				for (iii in 0...input.readInt(true)) {
					var attachment:VertexAttachment = cast skin.getAttachment(slotIndex, input.readStringRef());
					var weighted = attachment.bones != null;
					var vertices = attachment.vertices;
					var deformLength = weighted ? Std.int(vertices.length / 3 * 2) : vertices.length;

					var frameCount = input.readInt(true);
					var timeline = new DeformTimeline(frameCount);
					timeline.slotIndex = slotIndex;
					timeline.attachment = attachment;

					for (frameIndex in 0...frameCount) {
						var time = input.readFloat();
						var deform;
						var end = input.readInt(true);
						if (end == 0)
							deform = weighted ? Utils.newFloatArray(deformLength) : vertices;
						else {
							deform = Utils.newFloatArray(deformLength);
							var start = input.readInt(true);
							end += start;
							if (scale == 1) {
								for (v in start...end)
									deform[v] = input.readFloat();
							} else {
								for (v in start...end)
									deform[v] = input.readFloat() * scale;
							}
							if (!weighted) {
								for (v in 0...deform.length)
									deform[v] += vertices[v];
							}
						}

						timeline.setFrame(frameIndex, time, deform);
						if (frameIndex < frameCount - 1)
							this.readCurve(input, frameIndex, timeline);
					}
					timelines.push(timeline);
					duration = Math.max(duration, timeline.frames[frameCount - 1]);
				}
			}
		}

		// Draw order timeline.
		var drawOrderCount = input.readInt(true);
		if (drawOrderCount > 0) {
			var timeline = new DrawOrderTimeline(drawOrderCount);
			var slotCount = skeletonData.slots.length;
			for (i in 0...drawOrderCount) {
				var time = input.readFloat();
				var offsetCount = input.readInt(true);
				var drawOrder = Utils.newArray(slotCount, 0);
				var ii = slotCount - 1;
				while (ii >= 0)
					drawOrder[ii--] = -1;
				var unchanged = Utils.newArray(slotCount - offsetCount, 0);
				var originalIndex = 0, unchangedIndex = 0;
				for (ii in 0...offsetCount) {
					var slotIndex = input.readInt(true);
					// Collect unchanged items.
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					// Set changed items.
					drawOrder[originalIndex + input.readInt(true)] = originalIndex++;
				}
				// Collect remaining unchanged items.
				while (originalIndex < slotCount)
					unchanged[unchangedIndex++] = originalIndex++;
				// Fill in unchanged items.
				var ii = slotCount - 1;
				while (ii >= 0) {
					if (drawOrder[ii] == -1)
						drawOrder[ii] = unchanged[--unchangedIndex];
					ii--;
				}
				timeline.setFrame(i, time, drawOrder);
			}
			timelines.push(timeline);
			duration = Math.max(duration, timeline.frames[drawOrderCount - 1]);
		}

		// Event timeline.
		var eventCount = input.readInt(true);
		if (eventCount > 0) {
			var timeline = new EventTimeline(eventCount);
			for (i in 0...eventCount) {
				var time = input.readFloat();
				var eventData = skeletonData.events[input.readInt(true)];
				var event = new Event(time, eventData);
				event.intValue = input.readInt(false);
				event.floatValue = input.readFloat();
				event.stringValue = input.readBoolean() ? input.readString() : eventData.stringValue;
				if (event.data.audioPath != null) {
					event.volume = input.readFloat();
					event.balance = input.readFloat();
				}
				timeline.setFrame(i, event);
			}
			timelines.push(timeline);
			duration = Math.max(duration, timeline.frames[eventCount - 1]);
		}

		return new Animation(name, timelines, duration);
	}

	function readCurve(input:BinaryInput, frameIndex:Int, timeline:CurveTimeline) {
		switch (input.readByte()) {
			case SkeletonBinary.CURVE_STEPPED:
				timeline.setStepped(frameIndex);
			case SkeletonBinary.CURVE_BEZIER:
				setCurve(timeline, frameIndex, input.readFloat(), input.readFloat(), input.readFloat(), input.readFloat());
		}
	}

	public function setCurve(timeline:CurveTimeline, frameIndex:Int, cx1:Float, cy1:Float, cx2:Float, cy2:Float) {
		timeline.setCurve(frameIndex, cx1, cy1, cx2, cy2);
	}
}

private class BinaryInput {
	public final strings = new Array<String>();

	final bytes:Bytes;
	var index:Int = 0;

	public function new(bytes:Bytes) {
		this.bytes = bytes;
	}

	// we reimplement all the reading functions because we need Big-Endian, not Little-Endian,
	// and haxe.io.Bytes currently lacks API for this (and haxe.io.BytesInput is a bit of an overkill)

	public inline function readByte():Int {
		return bytes.get(index++);
	}

	public function readBoolean():Bool {
		return readByte() != 0;
	}

	public function readShort():Int {
		return (readByte() << 8) | readByte();
	}

	public function readInt32():Int {
		return (readByte() << 24) | (readByte() << 16) | (readByte() << 8) | readByte();
	}

	public function readFloat():Float {
		return haxe.io.FPHelper.i32ToFloat(inline readInt32());
	}

	public function readInt(optimizePositive:Bool):Int {
		var b = this.readByte();
		var result = b & 0x7F;
		if ((b & 0x80) != 0) {
			b = this.readByte();
			result |= (b & 0x7F) << 7;
			if ((b & 0x80) != 0) {
				b = this.readByte();
				result |= (b & 0x7F) << 14;
				if ((b & 0x80) != 0) {
					b = this.readByte();
					result |= (b & 0x7F) << 21;
					if ((b & 0x80) != 0) {
						b = this.readByte();
						result |= (b & 0x7F) << 28;
					}
				}
			}
		}
		return optimizePositive ? result : ((result >>> 1) ^ -(result & 1));
	}

	public function readStringRef():String {
		var index = this.readInt(true);
		return index == 0 ? null : this.strings[index - 1];
	}

	public function readString():String {
		var byteCount = this.readInt(true);
		switch (byteCount) {
			case 0:
				return null;
			case 1:
				return "";
		}
		byteCount--;
		var chars = "";
		var charCount = 0;
		var i = 0;
		while (i < byteCount) {
			var b = this.readByte();
			switch (b >> 4) {
				case 12 | 13:
					chars += String.fromCharCode(((b & 0x1F) << 6 | this.readByte() & 0x3F));
					i += 2;
				case 14:
					chars += String.fromCharCode(((b & 0x0F) << 12 | (this.readByte() & 0x3F) << 6 | this.readByte() & 0x3F));
					i += 3;
				default:
					chars += String.fromCharCode(b);
					i++;
			}
		}
		return chars;
	}
}

private class LinkedMesh {
	public var parent:String;
	public var skin:String;
	public var slotIndex:Int;
	public var mesh:MeshAttachment;
	public var inheritDeform:Bool;

	public function new(mesh:MeshAttachment, skin:String, slotIndex:Int, parent:String, inheritDeform:Bool) {
		this.mesh = mesh;
		this.skin = skin;
		this.slotIndex = slotIndex;
		this.parent = parent;
		this.inheritDeform = inheritDeform;
	}
}

private class Vertices {
	public var bones:Array<Int>;
	public var vertices:Array<Float>;

	public function new() {}
}

private enum abstract AttachmentType(Int) {
	var Region;
	var BoundingBox;
	var Mesh;
	var LinkedMesh;
	var Path;
	var Point;
	var Clipping;
}
