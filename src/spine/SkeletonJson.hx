package spine;

import haxe.DynamicAccess;
import haxe.extern.EitherType;
import spine.Animation;
import spine.BoneData.TransformMode;
import spine.PathConstraintData;
import spine.attachments.VertexAttachment;
import spine.attachments.Attachment;
import spine.attachments.AttachmentLoader;
import spine.attachments.MeshAttachment;
import spine.utils.Color;
import spine.utils.Utils;

private typedef JRoot = {
	var skeleton:JSkeleton;
	var bones:Array<JBone>;
	var slots:Array<JSlot>;
	var ik:Array<JIKConstraint>;
	var transform:Array<JTransformConstraint>;
	var path:Array<JPathConstraint>;
	var skins:Array<JSkin>;
	var events:DynamicAccess<JEvent>;
	var animations:DynamicAccess<JAnimation>;
}

private typedef JSkeleton = {
	var hash:String;
	var spine:String;
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var fps:Float;
	var images:String;
}

private typedef JBone = {
	var name:String;
	var length:Float;
	var transform:String;
	var skin:Bool;
	var x:Float;
	var y:Float;
	var rotation:Float;
	var scaleX:Float;
	var scaleY:Float;
	var shearX:Float;
	var shearY:Float;
	var color:Int;
}

private typedef JSlot = {
	var name:String;
	var bone:String;
	var color:String;
	var dark:String;
	var attachment:String;
	var blend:String;
}

private typedef JIKConstraint = {
	var name:String;
	var order:Int;
	var skin:Bool;
	var bones:Array<String>;
	var target:String;
	var mix:Float;
	var softness:Float;
	var bendPositive:Bool;
	var compress:Bool;
	var stretch:Bool;
	var uniform:Bool;
}

private typedef JTransformConstraint = {
	var name:String;
	var order:Int;
	var skin:Bool;
	var bones:Array<String>;
	var target:String;
	var rotation:Float;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var shearY:Float;
	var rotateMix:Float;
	var translateMix:Float;
	var scaleMix:Float;
	var shearMix:Float;
	var local:Bool;
	var relative:Bool;
}

private typedef JPathConstraint = {
	var name:String;
	var order:Int;
	var skin:Bool;
	var bones:Array<String>;
	var target:String;
	var positionMode:String;
	var spacingMode:String;
	var rotateMode:String;
	var rotation:Float;
	var position:Float;
	var spacing:Float;
	var rotateMix:Float;
	var translateMix:Float;
}

private typedef JSkin = {
	var name:String;
	var bones:Array<String>;
	var ik:Array<String>;
	var transform:Array<String>;
	var path:Array<String>;
	var attachments:DynamicAccess<DynamicAccess<JAttachment>>;
}

private typedef JAttachment = {
	var name:String;
	var type:String;
}

private typedef JAttachmentRegion = JAttachment & {
	var path:String;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var rotation:Float;
	var width:Float;
	var height:Float;
	var color:String;
}

private typedef JAttachmentWithVertices = JAttachment & {
	var vertices:JVertices;
}

private typedef JAttachmentMesh = JAttachmentWithVertices & {
	var path:String;
	var uvs:Array<Float>;
	var triangles:Array<Int>;
	var hull:Float;
	var edges:Array<Int>;
	var color:String;
	var width:Float;
	var height:Float;
}

private typedef JVertices = Array<Float>;

private typedef JAttachmentBoundingBox = JAttachmentWithVertices & {
	var vertexCount:Int;
	var color:String;
}

private typedef JAttachmentPath = JAttachmentWithVertices & {
	var closed:Bool;
	var constantSpeed:Bool;
	var lengths:Array<Float>;
	var vertexCount:Int;
	var color:String;
}

private typedef JAttachmentPoint = JAttachment & {
	var x:Float;
	var y:Float;
	var rotation:Float;
	var color:String;
}

private typedef JAttachmentClipping = JAttachmentWithVertices & {
	var end:String;
	var vertexCount:Int;
	var color:String;
}

private typedef JEvent = {
	var int:Int;
	var float:Float;
	var string:String;
	var audio:String;
	var volume:Float;
	var balance:Float;
}

private typedef JAnimation = {
	var slots:DynamicAccess<DynamicAccess<JSlotTimeline>>;
	var bones:DynamicAccess<DynamicAccess<JBoneTimeline>>;
	var ik:DynamicAccess<JIKTimeline>;
	var transform:DynamicAccess<JTransformTimeline>;
	var path:DynamicAccess<DynamicAccess<JPathTimeline>>;
	var deform:DynamicAccess<DynamicAccess<DynamicAccess<JDeformTimeline>>>;
	var drawOrder:JDrawOrderTimeline;
	var draworder:JDrawOrderTimeline;
	var events:JEventTimeline;
}

private typedef JKeyframe = {
	var time:Float;
}

private typedef JKeyframeWithCurve = JKeyframe & {
	var curve:EitherType<String, Float>;
	var c2:Float;
	var c3:Float;
	var c4:Float;
}

private typedef JSlotTimeline = Array<JSlotKeyframe>;
private typedef JSlotKeyframe = JKeyframe;

private typedef JSlotKeyframeAttachment = JKeyframe & {
	var name:String;
}

private typedef JSlotKeyframeColor = JKeyframeWithCurve & {
	var color:String;
}

private typedef JSlotKeyframeTwoColor = JKeyframeWithCurve & {
	var light:String;
	var dark:String;
}

private typedef JBoneTimeline = Array<JBoneKeyframe>;
private typedef JBoneKeyframe = JKeyframeWithCurve;

private typedef JBoneKeyframeRotate = JBoneKeyframe & {
	var angle:Float;
}

private typedef JBoneKeyframeCoords = JBoneKeyframe & {
	var x:Float;
	var y:Float;
}

private typedef JIKTimeline = Array<JIKKeyframe>;

private typedef JIKKeyframe = JKeyframeWithCurve & {
	var mix:Float;
	var softness:Float;
	var bendPositive:Bool;
	var compress:Bool;
	var stretch:Bool;
}

private typedef JTransformTimeline = Array<JTransformKeyframe>;

private typedef JTransformKeyframe = JKeyframeWithCurve & {
	var rotateMix:Float;
	var translateMix:Float;
	var scaleMix:Float;
	var shearMix:Float;
}

private typedef JPathTimeline = Array<JPathKeyframe>;

private typedef JPathKeyframe = JKeyframeWithCurve & {
	var position:Float;
	var spacing:Float;
	var rotateMix:Float;
	var translateMix:Float;
}

private typedef JDeformTimeline = Array<JDeformKeyframe>;

private typedef JDeformKeyframe = JKeyframeWithCurve & {
	var offset:Int;
	var vertices:Array<Float>;
}

private typedef JDrawOrderTimeline = Array<JDrawOrderKeyframe>;

private typedef JDrawOrderKeyframe = JKeyframe & {
	var offsets:Array<JDrawOrderOffet>;
}

private typedef JDrawOrderOffet = {
	var slot:String;
	var offset:Int;
}

private typedef JEventTimeline = Array<JEventKeyframe>;

private typedef JEventKeyframe = JKeyframe & {
	var name:String;
	var int:Int;
	var float:Float;
	var string:String;
	var volume:Float;
	var balance:Float;
}

/** Loads skeleton data in the Spine JSON format.
 *
 * See [Spine JSON format](http://esotericsoftware.com/spine-json-format) and
 * [JSON and binary data](http://esotericsoftware.com/spine-loading-skeleton-data#JSON-and-binary-data) in the Spine
 * Runtimes Guide. */
class SkeletonJson {
	/** Scales bone positions, image sizes, and translations as they are loaded. This allows different size images to be used at
	 * runtime than were used in Spine.
	 *
	 * See [Scaling](http://esotericsoftware.com/spine-loading-skeleton-data#Scaling) in the Spine Runtimes Guide. */
	public var scale = 1.0;

	final attachmentLoader:AttachmentLoader;
	final linkedMeshes = new Array<LinkedMesh>();

	public function new(attachmentLoader:AttachmentLoader) {
		this.attachmentLoader = attachmentLoader;
	}

	/** Deserializes the Spine JSON data into a SkeletonData object. */
	public function readSkeletonData(json:EitherType<String, JRoot>):SkeletonData {
		var scale = this.scale;
		var skeletonData = new SkeletonData();
		var root:JRoot = Std.is(json, String) ? haxe.Json.parse(json) : json;

		// Skeleton
		var skeletonMap = root.skeleton;
		if (skeletonMap != null) {
			skeletonData.hash = skeletonMap.hash;
			skeletonData.version = skeletonMap.spine;
			skeletonData.x = skeletonMap.x;
			skeletonData.y = skeletonMap.y;
			skeletonData.width = skeletonMap.width;
			skeletonData.height = skeletonMap.height;
			skeletonData.fps = skeletonMap.fps;
			skeletonData.imagesPath = skeletonMap.images;
		}

		// Bones
		if (root.bones != null) {
			for (boneMap in root.bones) {
				var parent:BoneData = null;
				var parentName:String = this.getValue(boneMap, "parent", null);
				if (parentName != null) {
					parent = skeletonData.findBone(parentName);
					if (parent == null)
						throw new Error("Parent bone not found: " + parentName);
				}
				var data = new BoneData(skeletonData.bones.length, boneMap.name, parent);
				data.length = this.getValue(boneMap, "length", 0.0) * scale;
				data.x = this.getValue(boneMap, "x", 0.0) * scale;
				data.y = this.getValue(boneMap, "y", 0.0) * scale;
				data.rotation = this.getValue(boneMap, "rotation", 0.0);
				data.scaleX = this.getValue(boneMap, "scaleX", 1.0);
				data.scaleY = this.getValue(boneMap, "scaleY", 1.0);
				data.shearX = this.getValue(boneMap, "shearX", 0.0);
				data.shearY = this.getValue(boneMap, "shearY", 0.0);
				data.transformMode = SkeletonJson.transformModeFromString(this.getValue(boneMap, "transform", "normal"));
				data.skinRequired = this.getValue(boneMap, "skin", false);

				skeletonData.bones.push(data);
			}
		}

		// Slots.
		if (root.slots != null) {
			for (slotMap in root.slots) {
				var slotName:String = slotMap.name;
				var boneName:String = slotMap.bone;
				var boneData = skeletonData.findBone(boneName);
				if (boneData == null)
					throw new Error("Slot bone not found: " + boneName);
				var data = new SlotData(skeletonData.slots.length, slotName, boneData);

				var color:String = this.getValue(slotMap, "color", null);
				if (color != null)
					data.color.setFromString(color);

				var dark:String = this.getValue(slotMap, "dark", null);
				if (dark != null) {
					data.darkColor = new Color(1, 1, 1, 1);
					data.darkColor.setFromString(dark);
				}

				data.attachmentName = this.getValue(slotMap, "attachment", null);
				data.blendMode = SkeletonJson.blendModeFromString(this.getValue(slotMap, "blend", "normal"));
				skeletonData.slots.push(data);
			}
		}

		// IK constraints
		if (root.ik != null) {
			for (constraintMap in root.ik) {
				var data = new IkConstraintData(constraintMap.name);
				data.order = this.getValue(constraintMap, "order", 0);
				data.skinRequired = this.getValue(constraintMap, "skin", false);

				for (boneName in constraintMap.bones) {
					var bone = skeletonData.findBone(boneName);
					if (bone == null)
						throw new Error("IK bone not found: " + boneName);
					data.bones.push(bone);
				}

				var targetName:String = constraintMap.target;
				data.target = skeletonData.findBone(targetName);
				if (data.target == null)
					throw new Error("IK target bone not found: " + targetName);

				data.mix = this.getValue(constraintMap, "mix", 1.0);
				data.softness = this.getValue(constraintMap, "softness", 0.0) * scale;
				data.bendDirection = this.getValue(constraintMap, "bendPositive", true) ? 1 : -1;
				data.compress = this.getValue(constraintMap, "compress", false);
				data.stretch = this.getValue(constraintMap, "stretch", false);
				data.uniform = this.getValue(constraintMap, "uniform", false);

				skeletonData.ikConstraints.push(data);
			}
		}

		// Transform constraints.
		if (root.transform != null) {
			for (constraintMap in root.transform) {
				var data = new TransformConstraintData(constraintMap.name);
				data.order = this.getValue(constraintMap, "order", 0);
				data.skinRequired = this.getValue(constraintMap, "skin", false);

				for (boneName in constraintMap.bones) {
					var bone = skeletonData.findBone(boneName);
					if (bone == null)
						throw new Error("Transform constraint bone not found: " + boneName);
					data.bones.push(bone);
				}

				var targetName:String = constraintMap.target;
				data.target = skeletonData.findBone(targetName);
				if (data.target == null)
					throw new Error("Transform constraint target bone not found: " + targetName);

				data.local = this.getValue(constraintMap, "local", false);
				data.relative = this.getValue(constraintMap, "relative", false);
				data.offsetRotation = this.getValue(constraintMap, "rotation", 0.0);
				data.offsetX = this.getValue(constraintMap, "x", 0.0) * scale;
				data.offsetY = this.getValue(constraintMap, "y", 0.0) * scale;
				data.offsetScaleX = this.getValue(constraintMap, "scaleX", 0.0);
				data.offsetScaleY = this.getValue(constraintMap, "scaleY", 0.0);
				data.offsetShearY = this.getValue(constraintMap, "shearY", 0.0);

				data.rotateMix = this.getValue(constraintMap, "rotateMix", 1.0);
				data.translateMix = this.getValue(constraintMap, "translateMix", 1.0);
				data.scaleMix = this.getValue(constraintMap, "scaleMix", 1.0);
				data.shearMix = this.getValue(constraintMap, "shearMix", 1.0);

				skeletonData.transformConstraints.push(data);
			}
		}

		// Path constraints.
		if (root.path != null) {
			for (constraintMap in root.path) {
				var data = new PathConstraintData(constraintMap.name);
				data.order = this.getValue(constraintMap, "order", 0);
				data.skinRequired = this.getValue(constraintMap, "skin", false);

				for (boneName in constraintMap.bones) {
					var bone = skeletonData.findBone(boneName);
					if (bone == null)
						throw new Error("Transform constraint bone not found: " + boneName);
					data.bones.push(bone);
				}

				var targetName:String = constraintMap.target;
				data.target = skeletonData.findSlot(targetName);
				if (data.target == null)
					throw new Error("Path target slot not found: " + targetName);

				data.positionMode = SkeletonJson.positionModeFromString(this.getValue(constraintMap, "positionMode", "percent"));
				data.spacingMode = SkeletonJson.spacingModeFromString(this.getValue(constraintMap, "spacingMode", "length"));
				data.rotateMode = SkeletonJson.rotateModeFromString(this.getValue(constraintMap, "rotateMode", "tangent"));
				data.offsetRotation = this.getValue(constraintMap, "rotation", 0.0);
				data.position = this.getValue(constraintMap, "position", 0.0);
				if (data.positionMode == PositionMode.Fixed)
					data.position *= scale;
				data.spacing = this.getValue(constraintMap, "spacing", 0.0);
				if (data.spacingMode == SpacingMode.Length || data.spacingMode == SpacingMode.Fixed)
					data.spacing *= scale;
				data.rotateMix = this.getValue(constraintMap, "rotateMix", 1.0);
				data.translateMix = this.getValue(constraintMap, "translateMix", 1.0);

				skeletonData.pathConstraints.push(data);
			}
		}

		// Skins.
		if (root.skins != null) {
			for (skinMap in root.skins) {
				var skin = new Skin(skinMap.name);

				if (skinMap.bones != null) {
					for (boneName in skinMap.bones) {
						var bone = skeletonData.findBone(boneName);
						if (bone == null)
							throw new Error("Skin bone not found: " + boneName);
						skin.bones.push(bone);
					}
				}

				if (skinMap.ik != null) {
					for (constraintName in skinMap.ik) {
						var constraint = skeletonData.findIkConstraint(constraintName);
						if (constraint == null)
							throw new Error("Skin IK constraint not found: " + constraintName);
						skin.constraints.push(constraint);
					}
				}

				if (skinMap.transform != null) {
					for (constraintName in skinMap.transform) {
						var constraint = skeletonData.findTransformConstraint(constraintName);
						if (constraint == null)
							throw new Error("Skin transform constraint not found: " + constraintName);
						skin.constraints.push(constraint);
					}
				}

				if (skinMap.path != null) {
					for (constraintName in skinMap.path) {
						var constraint = skeletonData.findPathConstraint(constraintName);
						if (constraint == null)
							throw new Error("Skin path constraint not found: " + constraintName);
						skin.constraints.push(constraint);
					}
				}

				for (slotName => slotMap in skinMap.attachments) {
					var slot = skeletonData.findSlot(slotName);
					if (slot == null)
						throw new Error("Slot not found: " + slotName);
					for (entryName => entry in slotMap) {
						var attachment = this.readAttachment(entry, skin, slot.index, entryName, skeletonData);
						if (attachment != null)
							skin.setAttachment(slot.index, entryName, attachment);
					}
				}
				skeletonData.skins.push(skin);
				if (skin.name == "default")
					skeletonData.defaultSkin = skin;
			}
		}

		// Linked meshes.
		for (linkedMesh in this.linkedMeshes) {
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
		if (root.events != null) {
			for (eventName => eventMap in root.events) {
				var data = new EventData(eventName);
				data.intValue = this.getValue(eventMap, "int", 0);
				data.floatValue = this.getValue(eventMap, "float", 0.0);
				data.stringValue = this.getValue(eventMap, "string", "");
				data.audioPath = this.getValue(eventMap, "audio", null);
				if (data.audioPath != null) {
					data.volume = this.getValue(eventMap, "volume", 1.0);
					data.balance = this.getValue(eventMap, "balance", 0.0);
				}
				skeletonData.events.push(data);
			}
		}

		// Animations.
		if (root.animations != null) {
			for (animationName => animationMap in root.animations) {
				this.readAnimation(animationMap, animationName, skeletonData);
			}
		}

		return skeletonData;
	}

	function readAttachment(map:JAttachment, skin:Skin, slotIndex:Int, name:String, skeletonData:SkeletonData):Attachment {
		var scale = this.scale;
		name = this.getValue(map, "name", name);

		var type = this.getValue(map, "type", "region");

		switch (type) {
			case "region":
				{
					var map:JAttachmentRegion = cast map;
					var path = this.getValue(map, "path", name);
					var region = this.attachmentLoader.newRegionAttachment(skin, name, path);
					if (region == null)
						return null;
					region.path = path;
					region.x = this.getValue(map, "x", 0.0) * scale;
					region.y = this.getValue(map, "y", 0.0) * scale;
					region.scaleX = this.getValue(map, "scaleX", 1.0);
					region.scaleY = this.getValue(map, "scaleY", 1.0);
					region.rotation = this.getValue(map, "rotation", 0.0);
					region.width = map.width * scale;
					region.height = map.height * scale;

					var color:String = this.getValue(map, "color", null);
					if (color != null)
						region.color.setFromString(color);

					region.updateOffset();
					return region;
				}
			case "boundingbox":
				{
					var map:JAttachmentBoundingBox = cast map;
					var box = this.attachmentLoader.newBoundingBoxAttachment(skin, name);
					if (box == null)
						return null;
					this.readVertices(map, box, map.vertexCount << 1);
					var color:String = this.getValue(map, "color", null);
					if (color != null)
						box.color.setFromString(color);
					return box;
				}
			case "mesh" | "linkedmesh":
				{
					var map:JAttachmentMesh = cast map;
					var path = this.getValue(map, "path", name);
					var mesh = this.attachmentLoader.newMeshAttachment(skin, name, path);
					if (mesh == null)
						return null;
					mesh.path = path;

					var color:String = this.getValue(map, "color", null);
					if (color != null)
						mesh.color.setFromString(color);

					mesh.width = this.getValue(map, "width", 0.0) * scale;
					mesh.height = this.getValue(map, "height", 0.0) * scale;

					var parent:String = this.getValue(map, "parent", null);
					if (parent != null) {
						this.linkedMeshes.push(new LinkedMesh(mesh, this.getValue(map, "skin", null), slotIndex, parent, this.getValue(map, "deform", true)));
						return mesh;
					}

					var uvs = map.uvs;
					this.readVertices(map, mesh, uvs.length);
					mesh.triangles = map.triangles;
					mesh.regionUVs = uvs;
					mesh.updateUVs();

					mesh.edges = this.getValue(map, "edges", null);
					mesh.hullLength = this.getValue(map, "hull", 0.0) * 2;
					return mesh;
				}
			case "path":
				{
					var map:JAttachmentPath = cast map;
					var path = this.attachmentLoader.newPathAttachment(skin, name);
					if (path == null)
						return null;
					path.closed = this.getValue(map, "closed", false);
					path.constantSpeed = this.getValue(map, "constantSpeed", true);

					var vertexCount = map.vertexCount;
					this.readVertices(map, path, vertexCount << 1);

					var lengths:Array<Float> = Utils.newArray(Std.int(vertexCount / 3), 0.0);
					for (i in 0...map.lengths.length)
						lengths[i] = map.lengths[i] * scale;
					path.lengths = lengths;

					var color:String = this.getValue(map, "color", null);
					if (color != null)
						path.color.setFromString(color);
					return path;
				}
			case "point":
				{
					var map:JAttachmentPoint = cast map;
					var point = this.attachmentLoader.newPointAttachment(skin, name);
					if (point == null)
						return null;
					point.x = this.getValue(map, "x", 0.0) * scale;
					point.y = this.getValue(map, "y", 0.0) * scale;
					point.rotation = this.getValue(map, "rotation", 0.0);

					var color:String = this.getValue(map, "color", null);
					if (color != null)
						point.color.setFromString(color);
					return point;
				}
			case "clipping":
				{
					var map:JAttachmentClipping = cast map;
					var clip = this.attachmentLoader.newClippingAttachment(skin, name);
					if (clip == null)
						return null;

					var end:String = this.getValue(map, "end", null);
					if (end != null) {
						var slot = skeletonData.findSlot(end);
						if (slot == null)
							throw new Error("Clipping end slot not found: " + end);
						clip.endSlot = slot;
					}

					var vertexCount = map.vertexCount;
					this.readVertices(map, clip, vertexCount << 1);

					var color:String = this.getValue(map, "color", null);
					if (color != null)
						clip.color.setFromString(color);
					return clip;
				}
		}
		return null;
	}

	function readVertices(map:JAttachmentWithVertices, attachment:VertexAttachment, verticesLength:Int) {
		var scale = this.scale;
		attachment.worldVerticesLength = verticesLength;
		var vertices = map.vertices;
		if (verticesLength == vertices.length) {
			var scaledVertices = Utils.toFloatArray(vertices);
			if (scale != 1) {
				for (i in 0...vertices.length)
					scaledVertices[i] *= scale;
			}
			attachment.vertices = scaledVertices;
			return;
		}
		var weights = new Array<Float>();
		var bones = new Array<Int>();
		var i = 0, n = vertices.length;
		while (i < n) {
			var boneCount = Std.int(vertices[i++]);
			bones.push(boneCount);
			var nn = i + boneCount * 4;
			while (i < nn) {
				bones.push(Std.int(vertices[i]));
				weights.push(vertices[i + 1] * scale);
				weights.push(vertices[i + 2] * scale);
				weights.push(vertices[i + 3]);

				i += 4;
			}
		}
		attachment.bones = bones;
		attachment.vertices = Utils.toFloatArray(weights);
	}

	function readAnimation(map:JAnimation, name:String, skeletonData:SkeletonData) {
		var scale = this.scale;
		var timelines = new Array<Timeline>();
		var duration = 0.0;

		// Slot timelines.
		if (map.slots != null) {
			for (slotName => slotMap in map.slots) {
				var slotIndex = skeletonData.findSlotIndex(slotName);
				if (slotIndex == -1)
					throw new Error("Slot not found: " + slotName);
				for (timelineName => timelineMap in slotMap) {
					if (timelineName == "attachment") {
						var timeline = new AttachmentTimeline(timelineMap.length);
						timeline.slotIndex = slotIndex;

						var frameIndex = 0;
						for (valueMap in timelineMap) {
							var valueMap:JSlotKeyframeAttachment = cast valueMap;
							timeline.setFrame(frameIndex++, this.getValue(valueMap, "time", 0.0), valueMap.name);
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[timeline.getFrameCount() - 1]);
					} else if (timelineName == "color") {
						var timeline = new ColorTimeline(timelineMap.length);
						timeline.slotIndex = slotIndex;

						var frameIndex = 0;
						for (valueMap in timelineMap) {
							var valueMap:JSlotKeyframeColor = cast valueMap;
							var color = new Color();
							color.setFromString(valueMap.color);
							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), color.r, color.g, color.b, color.a);
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * ColorTimeline.ENTRIES]);
					} else if (timelineName == "twoColor") {
						var timeline = new TwoColorTimeline(timelineMap.length);
						timeline.slotIndex = slotIndex;

						var frameIndex = 0;
						for (valueMap in timelineMap) {
							var valueMap:JSlotKeyframeTwoColor = cast valueMap;
							var light = new Color();
							var dark = new Color();
							light.setFromString(valueMap.light);
							dark.setFromString(valueMap.dark);
							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), light.r, light.g, light.b, light.a, dark.r, dark.g, dark.b);
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * TwoColorTimeline.ENTRIES]);
					} else
						throw new Error("Invalid timeline type for a slot: " + timelineName + " (" + slotName + ")");
				}
			}
		}

		// Bone timelines.
		if (map.bones != null) {
			for (boneName => boneMap in map.bones) {
				var boneIndex = skeletonData.findBoneIndex(boneName);
				if (boneIndex == -1)
					throw new Error("Bone not found: " + boneName);
				for (timelineName => timelineMap in boneMap) {
					if (timelineName == "rotate") {
						var timeline = new RotateTimeline(timelineMap.length);
						timeline.boneIndex = boneIndex;

						var frameIndex = 0;
						for (valueMap in timelineMap) {
							var valueMap:JBoneKeyframeRotate = cast valueMap;
							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), this.getValue(valueMap, "angle", 0.0));
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * RotateTimeline.ENTRIES]);
					} else if (timelineName == "translate" || timelineName == "scale" || timelineName == "shear") {
						var timeline:TranslateTimeline = null;
						var timelineScale = 1.0, defaultValue = 0.0;
						if (timelineName == "scale") {
							timeline = new ScaleTimeline(timelineMap.length);
							defaultValue = 1.0;
						} else if (timelineName == "shear")
							timeline = new ShearTimeline(timelineMap.length);
						else {
							timeline = new TranslateTimeline(timelineMap.length);
							timelineScale = scale;
						}
						timeline.boneIndex = boneIndex;

						var frameIndex = 0;
						for (valueMap in timelineMap) {
							var valueMap:JBoneKeyframeCoords = cast valueMap;
							var x = this.getValue(valueMap, "x", defaultValue),
								y = this.getValue(valueMap, "y", defaultValue);
							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), x * timelineScale, y * timelineScale);
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * TranslateTimeline.ENTRIES]);
					} else
						throw new Error("Invalid timeline type for a bone: " + timelineName + " (" + boneName + ")");
				}
			}
		}

		// IK constraint timelines.
		if (map.ik != null) {
			for (constraintName => constraintMap in map.ik) {
				var constraint = skeletonData.findIkConstraint(constraintName);
				var timeline = new IkConstraintTimeline(constraintMap.length);
				timeline.ikConstraintIndex = skeletonData.ikConstraints.indexOf(constraint);
				var frameIndex = 0;
				for (valueMap in constraintMap) {
					timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), this.getValue(valueMap, "mix", 1.0),
						this.getValue(valueMap, "softness", 0.0) * scale, this.getValue(valueMap, "bendPositive", true) ? 1 : -1,
						this.getValue(valueMap, "compress", false), this.getValue(valueMap, "stretch", false));
					this.readCurve(valueMap, timeline, frameIndex);
					frameIndex++;
				}
				timelines.push(timeline);
				duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * IkConstraintTimeline.ENTRIES]);
			}
		}

		// Transform constraint timelines.
		if (map.transform != null) {
			for (constraintName => constraintMap in map.transform) {
				var constraint = skeletonData.findTransformConstraint(constraintName);
				var timeline = new TransformConstraintTimeline(constraintMap.length);
				timeline.transformConstraintIndex = skeletonData.transformConstraints.indexOf(constraint);
				var frameIndex = 0;
				for (valueMap in constraintMap) {
					timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), this.getValue(valueMap, "rotateMix", 1.0),
						this.getValue(valueMap, "translateMix", 1.0), this.getValue(valueMap, "scaleMix", 1.0), this.getValue(valueMap, "shearMix", 1.0));
					this.readCurve(valueMap, timeline, frameIndex);
					frameIndex++;
				}
				timelines.push(timeline);
				duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * TransformConstraintTimeline.ENTRIES]);
			}
		}

		// Path constraint timelines.
		if (map.path != null) {
			for (constraintName => constraintMap in map.path) {
				var index = skeletonData.findPathConstraintIndex(constraintName);
				if (index == -1)
					throw new Error("Path constraint not found: " + constraintName);
				var data = skeletonData.pathConstraints[index];
				for (timelineName => timelineMap in constraintMap) {
					if (timelineName == "position" || timelineName == "spacing") {
						var timeline:PathConstraintPositionTimeline = null;
						var timelineScale = 1.0;
						if (timelineName == "spacing") {
							timeline = new PathConstraintSpacingTimeline(timelineMap.length);
							if (data.spacingMode == SpacingMode.Length || data.spacingMode == SpacingMode.Fixed)
								timelineScale = scale;
						} else {
							timeline = new PathConstraintPositionTimeline(timelineMap.length);
							if (data.positionMode == PositionMode.Fixed)
								timelineScale = scale;
						}
						timeline.pathConstraintIndex = index;
						var frameIndex = 0;
						for (valueMap in timelineMap) {
							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), this.getValue(valueMap, timelineName, 0) * timelineScale);
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * PathConstraintPositionTimeline.ENTRIES]);
					} else if (timelineName == "mix") {
						var timeline = new PathConstraintMixTimeline(timelineMap.length);
						timeline.pathConstraintIndex = index;
						var frameIndex = 0;
						for (valueMap in timelineMap) {
							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0.0), this.getValue(valueMap, "rotateMix", 1.0),
								this.getValue(valueMap, "translateMix", 1.0));
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[(timeline.getFrameCount() - 1) * PathConstraintMixTimeline.ENTRIES]);
					}
				}
			}
		}

		// Deform timelines.
		if (map.deform != null) {
			for (deformName => deformMap in map.deform) {
				var skin = skeletonData.findSkin(deformName);
				if (skin == null)
					throw new Error("Skin not found: " + deformName);
				for (slotName => slotMap in deformMap) {
					var slotIndex = skeletonData.findSlotIndex(slotName);
					if (slotIndex == -1)
						throw new Error("Slot not found: " + slotName);
					for (timelineName => timelineMap in slotMap) {
						var attachment:VertexAttachment = cast skin.getAttachment(slotIndex, timelineName);
						if (attachment == null)
							throw new Error("Deform attachment not found: " + timelineName);
						var weighted = attachment.bones != null;
						var vertices = attachment.vertices;
						var deformLength = weighted ? Std.int(vertices.length / 3 * 2) : vertices.length;

						var timeline = new DeformTimeline(timelineMap.length);
						timeline.slotIndex = slotIndex;
						timeline.attachment = attachment;

						var frameIndex = 0;
						for (valueMap in timelineMap) {
							var deform:Array<Float>;
							var verticesValue:Array<Float> = this.getValue(valueMap, "vertices", null);
							if (verticesValue == null)
								deform = weighted ? Utils.newFloatArray(deformLength) : vertices;
							else {
								deform = Utils.newFloatArray(deformLength);
								var start = this.getValue(valueMap, "offset", 0);
								Utils.arrayCopy(verticesValue, 0, deform, start, verticesValue.length);
								if (scale != 1) {
									for (i in start...start + verticesValue.length)
										deform[i] *= scale;
								}
								if (!weighted) {
									for (i in 0...deformLength)
										deform[i] += vertices[i];
								}
							}

							timeline.setFrame(frameIndex, this.getValue(valueMap, "time", 0), deform);
							this.readCurve(valueMap, timeline, frameIndex);
							frameIndex++;
						}
						timelines.push(timeline);
						duration = Math.max(duration, timeline.frames[timeline.getFrameCount() - 1]);
					}
				}
			}
		}

		// Draw order timeline.
		var drawOrderNode = map.drawOrder;
		if (drawOrderNode == null)
			drawOrderNode = map.draworder;
		if (drawOrderNode != null) {
			var timeline = new DrawOrderTimeline(drawOrderNode.length);
			var slotCount = skeletonData.slots.length;
			var frameIndex = 0;
			for (drawOrderMap in drawOrderNode) {
				var drawOrder:Array<Int> = null;
				var offsets:Array<JDrawOrderOffet> = this.getValue(drawOrderMap, "offsets", null);
				if (offsets != null) {
					drawOrder = Utils.newArray(slotCount, -1);
					var unchanged:Array<Int> = Utils.newArray(slotCount - offsets.length, 0);
					var originalIndex = 0, unchangedIndex = 0;
					for (offsetMap in offsets) {
						var slotIndex = skeletonData.findSlotIndex(offsetMap.slot);
						if (slotIndex == -1)
							throw new Error("Slot not found: " + offsetMap.slot);
						// Collect unchanged items.
						while (originalIndex != slotIndex)
							unchanged[unchangedIndex++] = originalIndex++;
						// Set changed items.
						drawOrder[originalIndex + offsetMap.offset] = originalIndex++;
					}
					// Collect remaining unchanged items.
					while (originalIndex < slotCount)
						unchanged[unchangedIndex++] = originalIndex++;
					// Fill in unchanged items.
					var i = slotCount - 1;
					while (i >= 0) {
						if (drawOrder[i] == -1)
							drawOrder[i] = unchanged[--unchangedIndex];
						i--;
					}
				}
				timeline.setFrame(frameIndex++, this.getValue(drawOrderMap, "time", 0.0), drawOrder);
			}
			timelines.push(timeline);
			duration = Math.max(duration, timeline.frames[timeline.getFrameCount() - 1]);
		}

		// Event timeline.
		if (map.events != null) {
			var timeline = new EventTimeline(map.events.length);
			var frameIndex = 0;
			for (eventMap in map.events) {
				var eventData = skeletonData.findEvent(eventMap.name);
				if (eventData == null)
					throw new Error("Event not found: " + eventMap.name);
				var event = new Event(Utils.toSinglePrecision(this.getValue(eventMap, "time", 0.0)), eventData);
				event.intValue = this.getValue(eventMap, "int", eventData.intValue);
				event.floatValue = this.getValue(eventMap, "float", eventData.floatValue);
				event.stringValue = this.getValue(eventMap, "string", eventData.stringValue);
				if (event.data.audioPath != null) {
					event.volume = this.getValue(eventMap, "volume", 1.0);
					event.balance = this.getValue(eventMap, "balance", 0.0);
				}
				timeline.setFrame(frameIndex++, event);
			}
			timelines.push(timeline);
			duration = Math.max(duration, timeline.frames[timeline.getFrameCount() - 1]);
		}

		if (Math.isNaN(duration)) {
			throw new Error("Error while parsing animation, duration is NaN");
		}

		skeletonData.animations.push(new Animation(name, timelines, duration));
	}

	function readCurve(map:JKeyframeWithCurve, timeline:CurveTimeline, frameIndex:Int) {
		if (map.curve == null)
			return;
		if (map.curve == "stepped")
			timeline.setStepped(frameIndex);
		else {
			var curve:Float = map.curve;
			timeline.setCurve(frameIndex, curve, this.getValue(map, "c2", 0.0), this.getValue(map, "c3", 1.0), this.getValue(map, "c4", 1.0));
		}
	}

	function getValue<T>(map:Dynamic, prop:String, defaultValue:T):T {
		return Reflect.hasField(map, prop) ? Reflect.field(map, prop) : defaultValue;
	}

	static function blendModeFromString(str:String) {
		str = str.toLowerCase();
		if (str == "normal")
			return BlendMode.Normal;
		if (str == "additive")
			return BlendMode.Additive;
		if (str == "multiply")
			return BlendMode.Multiply;
		if (str == "screen")
			return BlendMode.Screen;
		throw new Error('Unknown blend mode: ${str}');
	}

	static function positionModeFromString(str:String) {
		str = str.toLowerCase();
		if (str == "fixed")
			return PositionMode.Fixed;
		if (str == "percent")
			return PositionMode.Percent;
		throw new Error('Unknown position mode: ${str}');
	}

	static function spacingModeFromString(str:String) {
		str = str.toLowerCase();
		if (str == "length")
			return SpacingMode.Length;
		if (str == "fixed")
			return SpacingMode.Fixed;
		if (str == "percent")
			return SpacingMode.Percent;
		throw new Error('Unknown position mode: ${str}');
	}

	static function rotateModeFromString(str:String) {
		str = str.toLowerCase();
		if (str == "tangent")
			return RotateMode.Tangent;
		if (str == "chain")
			return RotateMode.Chain;
		if (str == "chainscale")
			return RotateMode.ChainScale;
		throw new Error('Unknown rotate mode: ${str}');
	}

	static function transformModeFromString(str:String) {
		str = str.toLowerCase();
		if (str == "normal")
			return TransformMode.Normal;
		if (str == "onlytranslation")
			return TransformMode.OnlyTranslation;
		if (str == "norotationorreflection")
			return TransformMode.NoRotationOrReflection;
		if (str == "noscale")
			return TransformMode.NoScale;
		if (str == "noscaleorreflection")
			return TransformMode.NoScaleOrReflection;
		throw new Error('Unknown transform mode: ${str}');
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
