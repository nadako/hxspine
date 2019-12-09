package spine;

import spine.attachments.VertexAttachment;
import spine.utils.MathUtils;
import spine.utils.Utils;

/** A simple container for a list of timelines and a name. */
class Animation {
	/** The animation's name, which is unique across all animations in the skeleton. */
	public final name:String;

	public final timelines:Array<Timeline>;

	/** The duration of the animation in seconds, which is the highest time of all keys in the timeline. */
	public var duration:Float;

	final timelineIds:Map<Int, Bool>;

	public function new(name:String, timelines:Array<Timeline>, duration:Float) {
		if (name == null)
			throw new Error("name cannot be null.");
		if (timelines == null)
			throw new Error("timelines cannot be null.");
		this.name = name;
		this.timelines = timelines;
		this.timelineIds = [for (timeline in timelines) timeline.getPropertyId() => true];
		this.duration = duration;
	}

	public function hasTimeline(id:Int) {
		return timelineIds.exists(id);
	}

	/** Applies all the animation's timelines to the specified skeleton.
	 *
	 * @see `Timeline.apply`.
	 * @param loop If true, the animation repeats after `duration`.
	 * @param events May be null to ignore fired events. */
	public function apply(skeleton:Skeleton, lastTime:Float, time:Float, loop:Bool, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		if (skeleton == null)
			throw new Error("skeleton cannot be null.");

		if (loop && this.duration != 0) {
			time %= this.duration;
			if (lastTime > 0)
				lastTime %= this.duration;
		}

		for (timeline in timelines)
			timeline.apply(skeleton, lastTime, time, events, alpha, blend, direction);
	}

	/** @param target After the first and before the last value.
	 * @returns index of first value greater than the target. */
	public static function binarySearch(values:Array<Float>, target:Float, step:Int = 1):Int {
		var low = 0;
		var high = Std.int(values.length / step - 2);
		if (high == 0)
			return step;
		var current = high >>> 1;
		while (true) {
			if (values[(current + 1) * step] <= target)
				low = current + 1;
			else
				high = current;
			if (low == high)
				return (low + 1) * step;
			current = (low + high) >>> 1;
		}
	}

	public static function linearSearch(values:Array<Float>, target:Float, step:Int) {
		var i = 0, last = values.length - step;
		while (i <= last) {
			if (values[i] > target)
				return i;
			i += step;
		}
		return -1;
	}
}

/** The interface for all timelines. */
interface Timeline {
	/** Applies this timeline to the skeleton.
	 * @param skeleton The skeleton the timeline is being applied to. This provides access to the bones, slots, and other
	 *           skeleton components the timeline may change.
	 * @param lastTime The time this timeline was last applied. Timelines such as `EventTimeline` trigger only at specific
	 *           times rather than every frame. In that case, the timeline triggers everything between `lastTime`
	 *           (exclusive) and `time` (inclusive).
	 * @param time The time within the animation. Most timelines find the key before and the key after this time so they can
	 *           interpolate between the keys.
	 * @param events If any events are fired, they are added to this list. Can be null to ignore fired events or if the timeline
	 *           does not fire events.
	 * @param alpha 0 applies the current or setup value (depending on `blend`). 1 applies the timeline value.
	 *           Between 0 and 1 applies a value between the current or setup value and the timeline value. By adjusting
	 *           `alpha` over time, an animation can be mixed in or out. `alpha` can also be useful to
	 *           apply animations on top of each other (layering).
	 * @param blend Controls how mixing is applied when `alpha` < 1.
	 * @param direction Indicates whether the timeline is mixing in or out. Used by timelines which perform instant transitions,
	 *           such as `DrawOrderTimeline` or `AttachmentTimeline`. */
	function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection):Void;

	/** Uniquely encodes both the type of this timeline and the skeleton property that it affects. */
	function getPropertyId():Int;
}

/** Controls how a timeline value is mixed with the setup pose value or current pose value when a timeline's `alpha` < 1.
 *
 * @see `Timeline.apply`. */
enum abstract MixBlend(Int) {
	/** Transitions from the setup value to the timeline value (the current value is not used). Before the first key, the setup
	 * value is set. */
	var setup;

	/** Transitions from the current value to the timeline value. Before the first key, transitions from the current value to
	 * the setup value. Timelines which perform instant transitions, such as `DrawOrderTimeline` or
	 * `AttachmentTimeline`, use the setup value before the first key.
	 *
	 * `first` is intended for the first animations applied, not for animations layered on top of those. */
	var first;

	/** Transitions from the current value to the timeline value. No change is made before the first key (the current value is
	 * kept until the first key).
	 *
	 * `replace` is intended for animations layered on top of others, not for the first animations applied. */
	var replace;

	/** Transitions from the current value to the current value plus the timeline value. No change is made before the first key
	 * (the current value is kept until the first key).
	 *
	 * `add` is intended for animations layered on top of others, not for the first animations applied. Properties
	 * keyed by additive animations must be set manually or by another animation before applying the additive animations, else
	 * the property values will increase continually. */
	var add;
}

/** Indicates whether a timeline's `alpha` is mixing out over time toward 0 (the setup or current pose value) or
 * mixing in toward 1 (the timeline's value).
 *
 * @see `Timeline.apply`. */
enum abstract MixDirection(Int) {
	var mixIn;
	var mixOut;
}

enum abstract TimelineType(Int) to Int {
	var rotate;
	var translate;
	var scale;
	var shear;
	var attachment;
	var color;
	var deform;
	var event;
	var drawOrder;
	var ikConstraint;
	var transformConstraint;
	var pathConstraintPosition;
	var pathConstraintSpacing;
	var pathConstraintMix;
	var twoColor;
}

/** The base class for timelines that use interpolation between key frame values. */
/* abstract */ class CurveTimeline implements Timeline {
	public static inline final LINEAR = 0;
	public static inline final STEPPED = 1;
	public static inline final BEZIER = 2;
	public static inline final BEZIER_SIZE = 10 * 2 - 1;

	final curves:Array<Float>; // type, x, y, ...

	/* abstract */ public function getPropertyId():Int
		throw "abstract";

	public function new(frameCount:Int) {
		if (frameCount <= 0)
			throw new Error("frameCount must be > 0: " + frameCount);
		this.curves = Utils.newFloatArray((frameCount - 1) * CurveTimeline.BEZIER_SIZE);
	}

	/** The number of key frames for this timeline. */
	public function getFrameCount():Int {
		return Std.int(this.curves.length / CurveTimeline.BEZIER_SIZE + 1);
	}

	/** Sets the specified key frame to linear interpolation. */
	public function setLinear(frameIndex:Int) {
		this.curves[frameIndex * CurveTimeline.BEZIER_SIZE] = CurveTimeline.LINEAR;
	}

	/** Sets the specified key frame to stepped interpolation. */
	public function setStepped(frameIndex:Int) {
		this.curves[frameIndex * CurveTimeline.BEZIER_SIZE] = CurveTimeline.STEPPED;
	}

	/** Returns the interpolation type for the specified key frame.
	 * @returns Linear is 0, stepped is 1, Bezier is 2. */
	public function getCurveType(frameIndex:Int):Int {
		var index = frameIndex * CurveTimeline.BEZIER_SIZE;
		if (index == this.curves.length)
			return CurveTimeline.LINEAR;
		var type = this.curves[index];
		if (type == CurveTimeline.LINEAR)
			return CurveTimeline.LINEAR;
		if (type == CurveTimeline.STEPPED)
			return CurveTimeline.STEPPED;
		return CurveTimeline.BEZIER;
	}

	/** Sets the specified key frame to Bezier interpolation. `cx1` and `cx2` are from 0 to 1,
	 * representing the percent of time between the two key frames. `cy1` and `cy2` are the percent of the
	 * difference between the key frame's values. */
	public function setCurve(frameIndex:Int, cx1:Float, cy1:Float, cx2:Float, cy2:Float) {
		var tmpx = (-cx1 * 2 + cx2) * 0.03, tmpy = (-cy1 * 2 + cy2) * 0.03;
		var dddfx = ((cx1 - cx2) * 3 + 1) * 0.006,
			dddfy = ((cy1 - cy2) * 3 + 1) * 0.006;
		var ddfx = tmpx * 2 + dddfx, ddfy = tmpy * 2 + dddfy;
		var dfx = cx1 * 0.3 + tmpx + dddfx * 0.16666667,
			dfy = cy1 * 0.3 + tmpy + dddfy * 0.16666667;

		var i = frameIndex * CurveTimeline.BEZIER_SIZE;
		var curves = this.curves;
		curves[i++] = CurveTimeline.BEZIER;

		var x = dfx, y = dfy;
		var n = i + CurveTimeline.BEZIER_SIZE - 1;
		while (i < n) {
			curves[i] = x;
			curves[i + 1] = y;
			dfx += ddfx;
			dfy += ddfy;
			ddfx += dddfx;
			ddfy += dddfy;
			x += dfx;
			y += dfy;

			i += 2;
		}
	}

	/** Returns the interpolated percentage for the specified key frame and linear percentage. */
	public function getCurvePercent(frameIndex:Int, percent:Float) {
		percent = MathUtils.clamp(percent, 0, 1);
		var curves = this.curves;
		var i = frameIndex * CurveTimeline.BEZIER_SIZE;
		var type = curves[i];
		if (type == CurveTimeline.LINEAR)
			return percent;
		if (type == CurveTimeline.STEPPED)
			return 0;
		i++;
		var x = 0.0;
		var start = i, n = i + CurveTimeline.BEZIER_SIZE - 1;
		while (i < n) {
			x = curves[i];
			if (x >= percent) {
				var prevX:Float, prevY:Float;
				if (i == start) {
					prevX = 0;
					prevY = 0;
				} else {
					prevX = curves[i - 2];
					prevY = curves[i - 1];
				}
				return prevY + (curves[i + 1] - prevY) * (percent - prevX) / (x - prevX);
			}

			i += 2;
		}
		var y = curves[i - 1];
		return y + (1 - y) * (percent - x) / (1 - x); // Last point is 1,1.
	}

	/** Applies this timeline to the skeleton.
	 * @see `Timeline.apply` */
	/* abstract */ public function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend,
			direction:MixDirection)
		throw "abstract";
}

/** Changes a bone's local `Bone.rotation`. */
class RotateTimeline extends CurveTimeline {
	public static inline final ENTRIES = 2;
	public static inline final PREV_TIME = -2;
	public static inline final PREV_ROTATION = -1;
	public static inline final ROTATION = 1;

	/** The index of the bone in `Skeleton.bones` that will be changed. */
	public var boneIndex:Int;

	/** The time in seconds and rotation in degrees for each key frame. */
	public final frames:Array<Float>; // time, degrees, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount << 1);
	}

	override function getPropertyId():Int {
		return (TimelineType.rotate << 24) + this.boneIndex;
	}

	/** Sets the time and angle of the specified keyframe. */
	public function setFrame(frameIndex:Int, time:Float, degrees:Float) {
		frameIndex <<= 1;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + RotateTimeline.ROTATION] = degrees;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;

		var bone = skeleton.bones[this.boneIndex];
		if (!bone.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					bone.rotation = bone.data.rotation;
				case MixBlend.first:
					var r = bone.data.rotation - bone.rotation;
					bone.rotation += (r - (16384 - Std.int(16384.499999999996 - r / 360)) * 360) * alpha;
				case _:
			}
			return;
		}

		if (time >= frames[frames.length - RotateTimeline.ENTRIES]) { // Time is after last frame.
			var r = frames[frames.length + RotateTimeline.PREV_ROTATION];
			switch (blend) {
				case MixBlend.setup:
					bone.rotation = bone.data.rotation + r * alpha;
				case MixBlend.first | MixBlend.replace:
					r += bone.data.rotation - bone.rotation;
					r -= (16384 - Std.int(16384.499999999996 - r / 360)) * 360; // Wrap within -180 and 180.
					bone.rotation += r * alpha;
				case MixBlend.add:
					bone.rotation += r * alpha;
			}
			return;
		}

		// Interpolate between the previous frame and the current frame.
		var frame = Animation.binarySearch(frames, time, RotateTimeline.ENTRIES);
		var prevRotation = frames[frame + RotateTimeline.PREV_ROTATION];
		var frameTime = frames[frame];
		var percent = this.getCurvePercent((frame >> 1) - 1, 1 - (time - frameTime) / (frames[frame + RotateTimeline.PREV_TIME] - frameTime));

		var r = frames[frame + RotateTimeline.ROTATION] - prevRotation;
		r = prevRotation + (r - (16384 - Std.int(16384.499999999996 - r / 360)) * 360) * percent;
		switch (blend) {
			case MixBlend.setup:
				bone.rotation = bone.data.rotation + (r - (16384 - Std.int(16384.499999999996 - r / 360)) * 360) * alpha;
			case MixBlend.first | MixBlend.replace:
				r += bone.data.rotation - bone.rotation;
				bone.rotation += (r - (16384 - Std.int(16384.499999999996 - r / 360)) * 360) * alpha;
			case MixBlend.add:
				bone.rotation += (r - (16384 - Std.int(16384.499999999996 - r / 360)) * 360) * alpha;
		}
	}
}

/** Changes a bone's local `Bone.x` and `Bone.y` */
class TranslateTimeline extends CurveTimeline {
	public static inline final ENTRIES = 3;
	public static inline final PREV_TIME = -3;
	public static inline final PREV_X = -2;
	public static inline final PREV_Y = -1;
	public static inline final X = 1;
	public static inline final Y = 2;

	/** The index of the bone in `Skeleton.bones` that will be changed. */
	public var boneIndex:Int;

	/** The time in seconds, x, and y values for each key frame. */
	public final frames:Array<Float>; // time, x, y, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * TranslateTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.translate << 24) + this.boneIndex;
	}

	/** Sets the time in seconds, x, and y values for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, x:Float, y:Float) {
		frameIndex *= TranslateTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + TranslateTimeline.X] = x;
		this.frames[frameIndex + TranslateTimeline.Y] = y;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;

		var bone = skeleton.bones[this.boneIndex];
		if (!bone.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					bone.x = bone.data.x;
					bone.y = bone.data.y;
				case MixBlend.first:
					bone.x += (bone.data.x - bone.x) * alpha;
					bone.y += (bone.data.y - bone.y) * alpha;
				case _:
			}
			return;
		}

		var x = 0.0, y = 0.0;
		if (time >= frames[frames.length - TranslateTimeline.ENTRIES]) { // Time is after last frame.
			x = frames[frames.length + TranslateTimeline.PREV_X];
			y = frames[frames.length + TranslateTimeline.PREV_Y];
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, TranslateTimeline.ENTRIES);
			x = frames[frame + TranslateTimeline.PREV_X];
			y = frames[frame + TranslateTimeline.PREV_Y];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / TranslateTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + TranslateTimeline.PREV_TIME] - frameTime));

			x += (frames[frame + TranslateTimeline.X] - x) * percent;
			y += (frames[frame + TranslateTimeline.Y] - y) * percent;
		}
		switch (blend) {
			case MixBlend.setup:
				bone.x = bone.data.x + x * alpha;
				bone.y = bone.data.y + y * alpha;
			case MixBlend.first | MixBlend.replace:
				bone.x += (bone.data.x + x - bone.x) * alpha;
				bone.y += (bone.data.y + y - bone.y) * alpha;
			case MixBlend.add:
				bone.x += x * alpha;
				bone.y += y * alpha;
		}
	}
}

/** Changes a bone's local `Bone.scaleX` and `Bone.scaleY`. */
class ScaleTimeline extends TranslateTimeline {
	public function new(frameCount:Int) {
		super(frameCount);
	}

	override function getPropertyId():Int {
		return (TimelineType.scale << 24) + this.boneIndex;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;

		var bone = skeleton.bones[this.boneIndex];
		if (!bone.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					bone.scaleX = bone.data.scaleX;
					bone.scaleY = bone.data.scaleY;
				case MixBlend.first:
					bone.scaleX += (bone.data.scaleX - bone.scaleX) * alpha;
					bone.scaleY += (bone.data.scaleY - bone.scaleY) * alpha;
				case _:
			}
			return;
		}

		var x = 0.0, y = 0.0;
		if (time >= frames[frames.length - TranslateTimeline.ENTRIES]) { // Time is after last frame.
			x = frames[frames.length + TranslateTimeline.PREV_X] * bone.data.scaleX;
			y = frames[frames.length + TranslateTimeline.PREV_Y] * bone.data.scaleY;
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, TranslateTimeline.ENTRIES);
			x = frames[frame + TranslateTimeline.PREV_X];
			y = frames[frame + TranslateTimeline.PREV_Y];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / TranslateTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + TranslateTimeline.PREV_TIME] - frameTime));

			x = (x + (frames[frame + TranslateTimeline.X] - x) * percent) * bone.data.scaleX;
			y = (y + (frames[frame + TranslateTimeline.Y] - y) * percent) * bone.data.scaleY;
		}
		if (alpha == 1) {
			if (blend == MixBlend.add) {
				bone.scaleX += x - bone.data.scaleX;
				bone.scaleY += y - bone.data.scaleY;
			} else {
				bone.scaleX = x;
				bone.scaleY = y;
			}
		} else {
			var bx = 0.0, by = 0.0;
			if (direction == MixDirection.mixOut) {
				switch (blend) {
					case MixBlend.setup:
						bx = bone.data.scaleX;
						by = bone.data.scaleY;
						bone.scaleX = bx + (Math.abs(x) * MathUtils.signum(bx) - bx) * alpha;
						bone.scaleY = by + (Math.abs(y) * MathUtils.signum(by) - by) * alpha;
					case MixBlend.first | MixBlend.replace:
						bx = bone.scaleX;
						by = bone.scaleY;
						bone.scaleX = bx + (Math.abs(x) * MathUtils.signum(bx) - bx) * alpha;
						bone.scaleY = by + (Math.abs(y) * MathUtils.signum(by) - by) * alpha;
					case MixBlend.add:
						bx = bone.scaleX;
						by = bone.scaleY;
						bone.scaleX = bx + (Math.abs(x) * MathUtils.signum(bx) - bone.data.scaleX) * alpha;
						bone.scaleY = by + (Math.abs(y) * MathUtils.signum(by) - bone.data.scaleY) * alpha;
				}
			} else {
				switch (blend) {
					case MixBlend.setup:
						bx = Math.abs(bone.data.scaleX) * MathUtils.signum(x);
						by = Math.abs(bone.data.scaleY) * MathUtils.signum(y);
						bone.scaleX = bx + (x - bx) * alpha;
						bone.scaleY = by + (y - by) * alpha;
					case MixBlend.first | MixBlend.replace:
						bx = Math.abs(bone.scaleX) * MathUtils.signum(x);
						by = Math.abs(bone.scaleY) * MathUtils.signum(y);
						bone.scaleX = bx + (x - bx) * alpha;
						bone.scaleY = by + (y - by) * alpha;
					case MixBlend.add:
						bx = MathUtils.signum(x);
						by = MathUtils.signum(y);
						bone.scaleX = Math.abs(bone.scaleX) * bx + (x - Math.abs(bone.data.scaleX) * bx) * alpha;
						bone.scaleY = Math.abs(bone.scaleY) * by + (y - Math.abs(bone.data.scaleY) * by) * alpha;
				}
			}
		}
	}
}

/** Changes a bone's local `Bone.shearX` and `Bone.shearY`. */
class ShearTimeline extends TranslateTimeline {
	public function new(frameCount:Int) {
		super(frameCount);
	}

	override function getPropertyId():Int {
		return (TimelineType.shear << 24) + this.boneIndex;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;

		var bone = skeleton.bones[this.boneIndex];
		if (!bone.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					bone.shearX = bone.data.shearX;
					bone.shearY = bone.data.shearY;
				case MixBlend.first:
					bone.shearX += (bone.data.shearX - bone.shearX) * alpha;
					bone.shearY += (bone.data.shearY - bone.shearY) * alpha;
				case _:
			}
			return;
		}

		var x = 0.0, y = 0.0;
		if (time >= frames[frames.length - TranslateTimeline.ENTRIES]) { // Time is after last frame.
			x = frames[frames.length + TranslateTimeline.PREV_X];
			y = frames[frames.length + TranslateTimeline.PREV_Y];
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, TranslateTimeline.ENTRIES);
			x = frames[frame + TranslateTimeline.PREV_X];
			y = frames[frame + TranslateTimeline.PREV_Y];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / TranslateTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + TranslateTimeline.PREV_TIME] - frameTime));

			x = x + (frames[frame + TranslateTimeline.X] - x) * percent;
			y = y + (frames[frame + TranslateTimeline.Y] - y) * percent;
		}
		switch (blend) {
			case MixBlend.setup:
				bone.shearX = bone.data.shearX + x * alpha;
				bone.shearY = bone.data.shearY + y * alpha;
			case MixBlend.first | MixBlend.replace:
				bone.shearX += (bone.data.shearX + x - bone.shearX) * alpha;
				bone.shearY += (bone.data.shearY + y - bone.shearY) * alpha;
			case MixBlend.add:
				bone.shearX += x * alpha;
				bone.shearY += y * alpha;
		}
	}
}

/** Changes a slot's `Slot.color`. */
class ColorTimeline extends CurveTimeline {
	public static inline final ENTRIES = 5;
	public static inline final PREV_TIME = -5;
	public static inline final PREV_R = -4;
	public static inline final PREV_G = -3;
	public static inline final PREV_B = -2;
	public static inline final PREV_A = -1;
	public static inline final R = 1;
	public static inline final G = 2;
	public static inline final B = 3;
	public static inline final A = 4;

	/** The index of the slot in `Skeleton.slots` that will be changed. */
	public var slotIndex:Int;

	/** The time in seconds, red, green, blue, and alpha values for each key frame. */
	public final frames:Array<Float>; // time, r, g, b, a, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * ColorTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.color << 24) + this.slotIndex;
	}

	/** Sets the time in seconds, red, green, blue, and alpha for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, r:Float, g:Float, b:Float, a:Float) {
		frameIndex *= ColorTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + ColorTimeline.R] = r;
		this.frames[frameIndex + ColorTimeline.G] = g;
		this.frames[frameIndex + ColorTimeline.B] = b;
		this.frames[frameIndex + ColorTimeline.A] = a;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var slot = skeleton.slots[this.slotIndex];
		if (!slot.bone.active)
			return;
		var frames = this.frames;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					slot.color.setFromColor(slot.data.color);
				case MixBlend.first:
					var color = slot.color, setup = slot.data.color;
					color.add((setup.r - color.r) * alpha, (setup.g - color.g) * alpha, (setup.b - color.b) * alpha, (setup.a - color.a) * alpha);
				case _:
			}
			return;
		}

		var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
		if (time >= frames[frames.length - ColorTimeline.ENTRIES]) { // Time is after last frame.
			var i = frames.length;
			r = frames[i + ColorTimeline.PREV_R];
			g = frames[i + ColorTimeline.PREV_G];
			b = frames[i + ColorTimeline.PREV_B];
			a = frames[i + ColorTimeline.PREV_A];
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, ColorTimeline.ENTRIES);
			r = frames[frame + ColorTimeline.PREV_R];
			g = frames[frame + ColorTimeline.PREV_G];
			b = frames[frame + ColorTimeline.PREV_B];
			a = frames[frame + ColorTimeline.PREV_A];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / ColorTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + ColorTimeline.PREV_TIME] - frameTime));

			r += (frames[frame + ColorTimeline.R] - r) * percent;
			g += (frames[frame + ColorTimeline.G] - g) * percent;
			b += (frames[frame + ColorTimeline.B] - b) * percent;
			a += (frames[frame + ColorTimeline.A] - a) * percent;
		}
		if (alpha == 1)
			slot.color.set(r, g, b, a);
		else {
			var color = slot.color;
			if (blend == MixBlend.setup)
				color.setFromColor(slot.data.color);
			color.add((r - color.r) * alpha, (g - color.g) * alpha, (b - color.b) * alpha, (a - color.a) * alpha);
		}
	}
}

/** Changes a slot's `Slot.color` and `Slot.darkColor` for two color tinting. */
class TwoColorTimeline extends CurveTimeline {
	public static inline final ENTRIES = 8;
	public static inline final PREV_TIME = -8;
	public static inline final PREV_R = -7;
	public static inline final PREV_G = -6;
	public static inline final PREV_B = -5;
	public static inline final PREV_A = -4;
	public static inline final PREV_R2 = -3;
	public static inline final PREV_G2 = -2;
	public static inline final PREV_B2 = -1;
	public static inline final R = 1;
	public static inline final G = 2;
	public static inline final B = 3;
	public static inline final A = 4;
	public static inline final R2 = 5;
	public static inline final G2 = 6;
	public static inline final B2 = 7;

	/** The index of the slot in `Skeleton.slots` that will be changed. The `Slot.darkColor` must not be null. */
	public var slotIndex:Int;

	/** The time in seconds, red, green, blue, and alpha values of the color, red, green, blue of the dark color, for each key frame. */
	public final frames:Array<Float>; // time, r, g, b, a, r2, g2, b2, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * TwoColorTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.twoColor << 24) + this.slotIndex;
	}

	/** Sets the time in seconds, light, and dark colors for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, r:Float, g:Float, b:Float, a:Float, r2:Float, g2:Float, b2:Float) {
		frameIndex *= TwoColorTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + TwoColorTimeline.R] = r;
		this.frames[frameIndex + TwoColorTimeline.G] = g;
		this.frames[frameIndex + TwoColorTimeline.B] = b;
		this.frames[frameIndex + TwoColorTimeline.A] = a;
		this.frames[frameIndex + TwoColorTimeline.R2] = r2;
		this.frames[frameIndex + TwoColorTimeline.G2] = g2;
		this.frames[frameIndex + TwoColorTimeline.B2] = b2;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var slot = skeleton.slots[this.slotIndex];
		if (!slot.bone.active)
			return;
		var frames = this.frames;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					slot.color.setFromColor(slot.data.color);
					slot.darkColor.setFromColor(slot.data.darkColor);
				case MixBlend.first:
					var light = slot.color,
						dark = slot.darkColor,
						setupLight = slot.data.color,
						setupDark = slot.data.darkColor;
					light.add((setupLight.r - light.r) * alpha, (setupLight.g - light.g) * alpha, (setupLight.b - light.b) * alpha,
						(setupLight.a - light.a) * alpha);
					dark.add((setupDark.r - dark.r) * alpha, (setupDark.g - dark.g) * alpha, (setupDark.b - dark.b) * alpha, 0);
				case _:
			}
			return;
		}

		var r = 0.0, g = 0.0, b = 0.0, a = 0.0, r2 = 0.0, g2 = 0.0, b2 = 0.0;
		if (time >= frames[frames.length - TwoColorTimeline.ENTRIES]) { // Time is after last frame.
			var i = frames.length;
			r = frames[i + TwoColorTimeline.PREV_R];
			g = frames[i + TwoColorTimeline.PREV_G];
			b = frames[i + TwoColorTimeline.PREV_B];
			a = frames[i + TwoColorTimeline.PREV_A];
			r2 = frames[i + TwoColorTimeline.PREV_R2];
			g2 = frames[i + TwoColorTimeline.PREV_G2];
			b2 = frames[i + TwoColorTimeline.PREV_B2];
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, TwoColorTimeline.ENTRIES);
			r = frames[frame + TwoColorTimeline.PREV_R];
			g = frames[frame + TwoColorTimeline.PREV_G];
			b = frames[frame + TwoColorTimeline.PREV_B];
			a = frames[frame + TwoColorTimeline.PREV_A];
			r2 = frames[frame + TwoColorTimeline.PREV_R2];
			g2 = frames[frame + TwoColorTimeline.PREV_G2];
			b2 = frames[frame + TwoColorTimeline.PREV_B2];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / TwoColorTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + TwoColorTimeline.PREV_TIME] - frameTime));

			r += (frames[frame + TwoColorTimeline.R] - r) * percent;
			g += (frames[frame + TwoColorTimeline.G] - g) * percent;
			b += (frames[frame + TwoColorTimeline.B] - b) * percent;
			a += (frames[frame + TwoColorTimeline.A] - a) * percent;
			r2 += (frames[frame + TwoColorTimeline.R2] - r2) * percent;
			g2 += (frames[frame + TwoColorTimeline.G2] - g2) * percent;
			b2 += (frames[frame + TwoColorTimeline.B2] - b2) * percent;
		}
		if (alpha == 1) {
			slot.color.set(r, g, b, a);
			slot.darkColor.set(r2, g2, b2, 1);
		} else {
			var light = slot.color, dark = slot.darkColor;
			if (blend == MixBlend.setup) {
				light.setFromColor(slot.data.color);
				dark.setFromColor(slot.data.darkColor);
			}
			light.add((r - light.r) * alpha, (g - light.g) * alpha, (b - light.b) * alpha, (a - light.a) * alpha);
			dark.add((r2 - dark.r) * alpha, (g2 - dark.g) * alpha, (b2 - dark.b) * alpha, 0);
		}
	}
}

/** Changes a slot's `Slot.attachment`. */
class AttachmentTimeline implements Timeline {
	/** The index of the slot in `Skeleton.slots` that will be changed. */
	public var slotIndex:Int;

	/** The time in seconds for each key frame. */
	public final frames:Array<Float>; // time, ...

	/** The attachment name for each key frame. May contain null values to clear the attachment. */
	public final attachmentNames:Array<Null<String>>;

	public function new(frameCount:Int) {
		this.frames = Utils.newFloatArray(frameCount);
		this.attachmentNames = [for (i in 0...frameCount) null];
	}

	public function getPropertyId():Int {
		return (TimelineType.attachment << 24) + this.slotIndex;
	}

	/** The number of key frames for this timeline. */
	public function getFrameCount():Int {
		return this.frames.length;
	}

	/** Sets the time in seconds and the attachment name for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, attachmentName:String) {
		this.frames[frameIndex] = time;
		this.attachmentNames[frameIndex] = attachmentName;
	}

	public function apply(skeleton:Skeleton, lastTime:Float, time:Float, events:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var slot = skeleton.slots[this.slotIndex];
		if (!slot.bone.active)
			return;
		if (direction == MixDirection.mixOut && blend == MixBlend.setup) {
			var attachmentName = slot.data.attachmentName;
			slot.setAttachment(attachmentName == null ? null : skeleton.getAttachment(this.slotIndex, attachmentName));
			return;
		}

		var frames = this.frames;
		if (time < frames[0]) {
			if (blend == MixBlend.setup || blend == MixBlend.first) {
				var attachmentName = slot.data.attachmentName;
				slot.setAttachment(attachmentName == null ? null : skeleton.getAttachment(this.slotIndex, attachmentName));
			}
			return;
		}

		var frameIndex = 0;
		if (time >= frames[frames.length - 1]) // Time is after last frame.
			frameIndex = frames.length - 1;
		else
			frameIndex = Animation.binarySearch(frames, time, 1) - 1;

		var attachmentName = this.attachmentNames[frameIndex];
		skeleton.slots[this.slotIndex].setAttachment(attachmentName == null ? null : skeleton.getAttachment(this.slotIndex, attachmentName));
	}
}

/** Changes a slot's `Slot.deform` to deform a `VertexAttachment`. */
class DeformTimeline extends CurveTimeline {
	static var zeros:Array<Float>;

	/** The index of the slot in `Skeleton.slots` that will be changed. */
	public var slotIndex:Int;

	/** The attachment that will be deformed. */
	public var attachment:VertexAttachment;

	/** The time in seconds for each key frame. */
	public final frames:Array<Float>; // time, ...

	/** The vertices for each key frame. */
	public final frameVertices:Array<Array<Float>>;

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount);
		this.frameVertices = [for (i in 0...frameCount) null];
		if (zeros == null)
			zeros = Utils.newFloatArray(64);
	}

	override function getPropertyId():Int {
		return (TimelineType.deform << 27) + this.attachment.id + this.slotIndex;
	}

	/** Sets the time in seconds and the vertices for the specified key frame.
	 * @param vertices Vertex positions for an unweighted `VertexAttachment`, or deform offsets if it has weights. */
	public function setFrame(frameIndex:Int, time:Float, vertices:Array<Float>) {
		this.frames[frameIndex] = time;
		this.frameVertices[frameIndex] = vertices;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var slot = skeleton.slots[this.slotIndex];
		if (!slot.bone.active)
			return;
		var slotAttachment = slot.getAttachment();
		if (!Std.is(slotAttachment, VertexAttachment) || !((cast slotAttachment : VertexAttachment).deformAttachment == this.attachment))
			return;

		var deformArray = slot.deform;
		if (deformArray.length == 0)
			blend = MixBlend.setup;

		var frameVertices = this.frameVertices;
		var vertexCount = frameVertices[0].length;

		var frames = this.frames;
		if (time < frames[0]) {
			var vertexAttachment:VertexAttachment = cast slotAttachment;
			switch (blend) {
				case MixBlend.setup:
					deformArray.resize(0);
				case MixBlend.first:
					if (alpha == 1) {
						deformArray.resize(0);
						return;
					}
					var deform = Utils.setArraySize(deformArray, vertexCount, 0);
					if (vertexAttachment.bones == null) {
						// Unweighted vertex positions.
						var setupVertices = vertexAttachment.vertices;
						for (i in 0...vertexCount)
							deform[i] += (setupVertices[i] - deform[i]) * alpha;
					} else {
						// Weighted deform offsets.
						alpha = 1 - alpha;
						for (i in 0...vertexCount)
							deform[i] *= alpha;
					}
				case _:
			}
			return;
		}

		var deform = Utils.setArraySize(deformArray, vertexCount, 0);
		if (time >= frames[frames.length - 1]) { // Time is after last frame.
			var lastVertices = frameVertices[frames.length - 1];
			if (alpha == 1) {
				if (blend == MixBlend.add) {
					var vertexAttachment:VertexAttachment = cast slotAttachment;
					if (vertexAttachment.bones == null) {
						// Unweighted vertex positions, with alpha.
						var setupVertices = vertexAttachment.vertices;
						for (i in 0...vertexCount) {
							deform[i] += lastVertices[i] - setupVertices[i];
						}
					} else {
						// Weighted deform offsets, with alpha.
						for (i in 0...vertexCount)
							deform[i] += lastVertices[i];
					}
				} else {
					Utils.arrayCopy(lastVertices, 0, deform, 0, vertexCount);
				}
			} else {
				switch (blend) {
					case MixBlend.setup:
						{
							var vertexAttachment:VertexAttachment = cast slotAttachment;
							if (vertexAttachment.bones == null) {
								// Unweighted vertex positions, with alpha.
								var setupVertices = vertexAttachment.vertices;
								for (i in 0...vertexCount) {
									var setup = setupVertices[i];
									deform[i] = setup + (lastVertices[i] - setup) * alpha;
								}
							} else {
								// Weighted deform offsets, with alpha.
								for (i in 0...vertexCount)
									deform[i] = lastVertices[i] * alpha;
							}
						}
					case MixBlend.first | MixBlend.replace:
						for (i in 0...vertexCount)
							deform[i] += (lastVertices[i] - deform[i]) * alpha;
					case MixBlend.add:
						var vertexAttachment:VertexAttachment = cast slotAttachment;
						if (vertexAttachment.bones == null) {
							// Unweighted vertex positions, with alpha.
							var setupVertices = vertexAttachment.vertices;
							for (i in 0...vertexCount) {
								deform[i] += (lastVertices[i] - setupVertices[i]) * alpha;
							}
						} else {
							// Weighted deform offsets, with alpha.
							for (i in 0...vertexCount)
								deform[i] += lastVertices[i] * alpha;
						}
				}
			}
			return;
		}

		// Interpolate between the previous frame and the current frame.
		var frame = Animation.binarySearch(frames, time);
		var prevVertices = frameVertices[frame - 1];
		var nextVertices = frameVertices[frame];
		var frameTime = frames[frame];
		var percent = this.getCurvePercent(frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

		if (alpha == 1) {
			if (blend == MixBlend.add) {
				var vertexAttachment:VertexAttachment = cast slotAttachment;
				if (vertexAttachment.bones == null) {
					// Unweighted vertex positions, with alpha.
					var setupVertices = vertexAttachment.vertices;
					for (i in 0...vertexCount) {
						var prev = prevVertices[i];
						deform[i] += prev + (nextVertices[i] - prev) * percent - setupVertices[i];
					}
				} else {
					// Weighted deform offsets, with alpha.
					for (i in 0...vertexCount) {
						var prev = prevVertices[i];
						deform[i] += prev + (nextVertices[i] - prev) * percent;
					}
				}
			} else {
				for (i in 0...vertexCount) {
					var prev = prevVertices[i];
					deform[i] = prev + (nextVertices[i] - prev) * percent;
				}
			}
		} else {
			switch (blend) {
				case MixBlend.setup:
					{
						var vertexAttachment:VertexAttachment = cast slotAttachment;
						if (vertexAttachment.bones == null) {
							// Unweighted vertex positions, with alpha.
							var setupVertices = vertexAttachment.vertices;
							for (i in 0...vertexCount) {
								var prev = prevVertices[i],
									setup = setupVertices[i];
								deform[i] = setup + (prev + (nextVertices[i] - prev) * percent - setup) * alpha;
							}
						} else {
							// Weighted deform offsets, with alpha.
							for (i in 0...vertexCount) {
								var prev = prevVertices[i];
								deform[i] = (prev + (nextVertices[i] - prev) * percent) * alpha;
							}
						}
					}
				case MixBlend.first | MixBlend.replace:
					for (i in 0...vertexCount) {
						var prev = prevVertices[i];
						deform[i] += (prev + (nextVertices[i] - prev) * percent - deform[i]) * alpha;
					}
				case MixBlend.add:
					var vertexAttachment:VertexAttachment = cast slotAttachment;
					if (vertexAttachment.bones == null) {
						// Unweighted vertex positions, with alpha.
						var setupVertices = vertexAttachment.vertices;
						for (i in 0...vertexCount) {
							var prev = prevVertices[i];
							deform[i] += (prev + (nextVertices[i] - prev) * percent - setupVertices[i]) * alpha;
						}
					} else {
						// Weighted deform offsets, with alpha.
						for (i in 0...vertexCount) {
							var prev = prevVertices[i];
							deform[i] += (prev + (nextVertices[i] - prev) * percent) * alpha;
						}
					}
			}
		}
	}
}

/** Fires an `Event` when specific animation times are reached. */
class EventTimeline implements Timeline {
	/** The time in seconds for each key frame. */
	public final frames:Array<Float>; // time, ...

	/** The event for each key frame. */
	public final events:Array<Event>;

	public function new(frameCount:Int) {
		this.frames = Utils.newFloatArray(frameCount);
		this.events = [for (i in 0...frameCount) null];
	}

	public function getPropertyId() {
		return TimelineType.event << 24;
	}

	/** The number of key frames for this timeline. */
	public function getFrameCount() {
		return this.frames.length;
	}

	/** Sets the time in seconds and the event for the specified key frame. */
	public function setFrame(frameIndex:Int, event:Event) {
		this.frames[frameIndex] = event.time;
		this.events[frameIndex] = event;
	}

	/** Fires events for frames > `lastTime` and <= `time`. */
	public function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		if (firedEvents == null)
			return;
		var frames = this.frames;
		var frameCount = this.frames.length;

		if (lastTime > time) { // Fire events after last time for looped animations.
			this.apply(skeleton, lastTime, 1.7976931348623157e+308 /* Number.MAX_VALUE */, firedEvents, alpha, blend, direction);
			lastTime = -1;
		} else if (lastTime >= frames[frameCount - 1]) // Last time is after last frame.
			return;
		if (time < frames[0])
			return; // Time is before first frame.

		var frame = 0;
		if (lastTime < frames[0])
			frame = 0;
		else {
			frame = Animation.binarySearch(frames, lastTime);
			var frameTime = frames[frame];
			while (frame > 0) { // Fire multiple events with the same frame.
				if (frames[frame - 1] != frameTime)
					break;
				frame--;
			}
		}
		while (frame < frameCount && time >= frames[frame])
			firedEvents.push(this.events[frame++]);
	}
}

/** Changes a skeleton's `Skeleton.drawOrder`. */
class DrawOrderTimeline implements Timeline {
	/** The time in seconds for each key frame. */
	public final frames:Array<Float>; // time, ...

	/** The draw order for each key frame. See `setFrame`. */
	public final drawOrders:Array<Null<Array<Int>>>;

	public function new(frameCount:Int) {
		this.frames = Utils.newFloatArray(frameCount);
		this.drawOrders = [for (i in 0...frameCount) null];
	}

	public function getPropertyId() {
		return TimelineType.drawOrder << 24;
	}

	/** The number of key frames for this timeline. */
	public function getFrameCount() {
		return this.frames.length;
	}

	/** Sets the time in seconds and the draw order for the specified key frame.
	 * @param drawOrder For each slot in `Skeleton.slots`, the index of the new draw order. May be `null` to use setup pose
	 *           draw order. */
	public function setFrame(frameIndex:Int, time:Float, drawOrder:Null<Array<Int>>) {
		this.frames[frameIndex] = time;
		this.drawOrders[frameIndex] = drawOrder;
	}

	public function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var drawOrder = skeleton.drawOrder;
		var slots = skeleton.slots;
		if (direction == MixDirection.mixOut && blend == MixBlend.setup) {
			Utils.arrayCopy(skeleton.slots, 0, skeleton.drawOrder, 0, skeleton.slots.length);
			return;
		}

		var frames = this.frames;
		if (time < frames[0]) {
			if (blend == MixBlend.setup || blend == MixBlend.first)
				Utils.arrayCopy(skeleton.slots, 0, skeleton.drawOrder, 0, skeleton.slots.length);
			return;
		}

		var frame = 0;
		if (time >= frames[frames.length - 1]) // Time is after last frame.
			frame = frames.length - 1;
		else
			frame = Animation.binarySearch(frames, time) - 1;

		var drawOrderToSetupIndex = this.drawOrders[frame];
		if (drawOrderToSetupIndex == null)
			Utils.arrayCopy(slots, 0, drawOrder, 0, slots.length);
		else {
			for (i in 0...drawOrderToSetupIndex.length)
				drawOrder[i] = slots[drawOrderToSetupIndex[i]];
		}
	}
}

/** Changes an IK constraint's `IkConstraint.mix`, `IkConstraint.softness`,
 * `IkConstraint.bendDirection`, `IkConstraint.stretch`, and `IkConstraint.compress`. */
class IkConstraintTimeline extends CurveTimeline {
	public static inline final ENTRIES = 6;
	public static inline final PREV_TIME = -6;
	public static inline final PREV_MIX = -5;
	public static inline final PREV_SOFTNESS = -4;
	public static inline final PREV_BEND_DIRECTION = -3;
	public static inline final PREV_COMPRESS = -2;
	public static inline final PREV_STRETCH = -1;
	public static inline final MIX = 1;
	public static inline final SOFTNESS = 2;
	public static inline final BEND_DIRECTION = 3;
	public static inline final COMPRESS = 4;
	public static inline final STRETCH = 5;

	/** The index of the IK constraint slot in `Skeleton.ikConstraints` that will be changed. */
	public var ikConstraintIndex:Int;

	/** The time in seconds, mix, softness, bend direction, compress, and stretch for each key frame. */
	public final frames:Array<Float>; // time, mix, softness, bendDirection, compress, stretch, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * IkConstraintTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.ikConstraint << 24) + this.ikConstraintIndex;
	}

	/** Sets the time in seconds, mix, softness, bend direction, compress, and stretch for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, mix:Float, softness:Float, bendDirection:Int, compress:Bool, stretch:Bool) {
		frameIndex *= IkConstraintTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + IkConstraintTimeline.MIX] = mix;
		this.frames[frameIndex + IkConstraintTimeline.SOFTNESS] = softness;
		this.frames[frameIndex + IkConstraintTimeline.BEND_DIRECTION] = bendDirection;
		this.frames[frameIndex + IkConstraintTimeline.COMPRESS] = compress ? 1 : 0;
		this.frames[frameIndex + IkConstraintTimeline.STRETCH] = stretch ? 1 : 0;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;
		var constraint = skeleton.ikConstraints[this.ikConstraintIndex];
		if (!constraint.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					constraint.mix = constraint.data.mix;
					constraint.softness = constraint.data.softness;
					constraint.bendDirection = constraint.data.bendDirection;
					constraint.compress = constraint.data.compress;
					constraint.stretch = constraint.data.stretch;
				case MixBlend.first:
					constraint.mix += (constraint.data.mix - constraint.mix) * alpha;
					constraint.softness += (constraint.data.softness - constraint.softness) * alpha;
					constraint.bendDirection = constraint.data.bendDirection;
					constraint.compress = constraint.data.compress;
					constraint.stretch = constraint.data.stretch;
				case _:
			}
			return;
		}

		if (time >= frames[frames.length - IkConstraintTimeline.ENTRIES]) { // Time is after last frame.
			if (blend == MixBlend.setup) {
				constraint.mix = constraint.data.mix + (frames[frames.length + IkConstraintTimeline.PREV_MIX] - constraint.data.mix) * alpha;
				constraint.softness = constraint.data.softness
					+ (frames[frames.length + IkConstraintTimeline.PREV_SOFTNESS] - constraint.data.softness) * alpha;
				if (direction == MixDirection.mixOut) {
					constraint.bendDirection = constraint.data.bendDirection;
					constraint.compress = constraint.data.compress;
					constraint.stretch = constraint.data.stretch;
				} else {
					constraint.bendDirection = Std.int(frames[frames.length + IkConstraintTimeline.PREV_BEND_DIRECTION]);
					constraint.compress = frames[frames.length + IkConstraintTimeline.PREV_COMPRESS] != 0;
					constraint.stretch = frames[frames.length + IkConstraintTimeline.PREV_STRETCH] != 0;
				}
			} else {
				constraint.mix += (frames[frames.length + IkConstraintTimeline.PREV_MIX] - constraint.mix) * alpha;
				constraint.softness += (frames[frames.length + IkConstraintTimeline.PREV_SOFTNESS] - constraint.softness) * alpha;
				if (direction == MixDirection.mixIn) {
					constraint.bendDirection = Std.int(frames[frames.length + IkConstraintTimeline.PREV_BEND_DIRECTION]);
					constraint.compress = frames[frames.length + IkConstraintTimeline.PREV_COMPRESS] != 0;
					constraint.stretch = frames[frames.length + IkConstraintTimeline.PREV_STRETCH] != 0;
				}
			}
			return;
		}

		// Interpolate between the previous frame and the current frame.
		var frame = Animation.binarySearch(frames, time, IkConstraintTimeline.ENTRIES);
		var mix = frames[frame + IkConstraintTimeline.PREV_MIX];
		var softness = frames[frame + IkConstraintTimeline.PREV_SOFTNESS];
		var frameTime = frames[frame];
		var percent = this.getCurvePercent(Std.int(frame / IkConstraintTimeline.ENTRIES - 1),
			1 - (time - frameTime) / (frames[frame + IkConstraintTimeline.PREV_TIME] - frameTime));

		if (blend == MixBlend.setup) {
			constraint.mix = constraint.data.mix + (mix + (frames[frame + IkConstraintTimeline.MIX] - mix) * percent - constraint.data.mix) * alpha;
			constraint.softness = constraint.data.softness
				+ (softness + (frames[frame + IkConstraintTimeline.SOFTNESS] - softness) * percent - constraint.data.softness) * alpha;
			if (direction == MixDirection.mixOut) {
				constraint.bendDirection = constraint.data.bendDirection;
				constraint.compress = constraint.data.compress;
				constraint.stretch = constraint.data.stretch;
			} else {
				constraint.bendDirection = Std.int(frames[frame + IkConstraintTimeline.PREV_BEND_DIRECTION]);
				constraint.compress = frames[frame + IkConstraintTimeline.PREV_COMPRESS] != 0;
				constraint.stretch = frames[frame + IkConstraintTimeline.PREV_STRETCH] != 0;
			}
		} else {
			constraint.mix += (mix + (frames[frame + IkConstraintTimeline.MIX] - mix) * percent - constraint.mix) * alpha;
			constraint.softness += (softness + (frames[frame + IkConstraintTimeline.SOFTNESS] - softness) * percent - constraint.softness) * alpha;
			if (direction == MixDirection.mixIn) {
				constraint.bendDirection = Std.int(frames[frame + IkConstraintTimeline.PREV_BEND_DIRECTION]);
				constraint.compress = frames[frame + IkConstraintTimeline.PREV_COMPRESS] != 0;
				constraint.stretch = frames[frame + IkConstraintTimeline.PREV_STRETCH] != 0;
			}
		}
	}
}

/** Changes a transform constraint's `TransformConstraint.rotateMix`, `TransformConstraint.translateMix`,
 * `TransformConstraint.scaleMix`, and `TransformConstraint.shearMix`. */
class TransformConstraintTimeline extends CurveTimeline {
	public static inline final ENTRIES = 5;
	public static inline final PREV_TIME = -5;
	public static inline final PREV_ROTATE = -4;
	public static inline final PREV_TRANSLATE = -3;
	public static inline final PREV_SCALE = -2;
	public static inline final PREV_SHEAR = -1;
	public static inline final ROTATE = 1;
	public static inline final TRANSLATE = 2;
	public static inline final SCALE = 3;
	public static inline final SHEAR = 4;

	/** The index of the transform constraint slot in `Skeleton.transformConstraints` that will be changed. */
	public var transformConstraintIndex:Int;

	/** The time in seconds, rotate mix, translate mix, scale mix, and shear mix for each key frame. */
	public final frames:Array<Float>; // time, rotate mix, translate mix, scale mix, shear mix, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * TransformConstraintTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.transformConstraint << 24) + this.transformConstraintIndex;
	}

	/** The time in seconds, rotate mix, translate mix, scale mix, and shear mix for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, rotateMix:Float, translateMix:Float, scaleMix:Float, shearMix:Float) {
		frameIndex *= TransformConstraintTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + TransformConstraintTimeline.ROTATE] = rotateMix;
		this.frames[frameIndex + TransformConstraintTimeline.TRANSLATE] = translateMix;
		this.frames[frameIndex + TransformConstraintTimeline.SCALE] = scaleMix;
		this.frames[frameIndex + TransformConstraintTimeline.SHEAR] = shearMix;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;

		var constraint:TransformConstraint = skeleton.transformConstraints[this.transformConstraintIndex];
		if (!constraint.active)
			return;
		if (time < frames[0]) {
			var data = constraint.data;
			switch (blend) {
				case MixBlend.setup:
					constraint.rotateMix = data.rotateMix;
					constraint.translateMix = data.translateMix;
					constraint.scaleMix = data.scaleMix;
					constraint.shearMix = data.shearMix;
				case MixBlend.first:
					constraint.rotateMix += (data.rotateMix - constraint.rotateMix) * alpha;
					constraint.translateMix += (data.translateMix - constraint.translateMix) * alpha;
					constraint.scaleMix += (data.scaleMix - constraint.scaleMix) * alpha;
					constraint.shearMix += (data.shearMix - constraint.shearMix) * alpha;
				case _:
			}
			return;
		}

		var rotate = 0.0, translate = 0.0, scale = 0.0, shear = 0.0;
		if (time >= frames[frames.length - TransformConstraintTimeline.ENTRIES]) { // Time is after last frame.
			var i = frames.length;
			rotate = frames[i + TransformConstraintTimeline.PREV_ROTATE];
			translate = frames[i + TransformConstraintTimeline.PREV_TRANSLATE];
			scale = frames[i + TransformConstraintTimeline.PREV_SCALE];
			shear = frames[i + TransformConstraintTimeline.PREV_SHEAR];
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, TransformConstraintTimeline.ENTRIES);
			rotate = frames[frame + TransformConstraintTimeline.PREV_ROTATE];
			translate = frames[frame + TransformConstraintTimeline.PREV_TRANSLATE];
			scale = frames[frame + TransformConstraintTimeline.PREV_SCALE];
			shear = frames[frame + TransformConstraintTimeline.PREV_SHEAR];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / TransformConstraintTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + TransformConstraintTimeline.PREV_TIME] - frameTime));

			rotate += (frames[frame + TransformConstraintTimeline.ROTATE] - rotate) * percent;
			translate += (frames[frame + TransformConstraintTimeline.TRANSLATE] - translate) * percent;
			scale += (frames[frame + TransformConstraintTimeline.SCALE] - scale) * percent;
			shear += (frames[frame + TransformConstraintTimeline.SHEAR] - shear) * percent;
		}
		if (blend == MixBlend.setup) {
			var data = constraint.data;
			constraint.rotateMix = data.rotateMix + (rotate - data.rotateMix) * alpha;
			constraint.translateMix = data.translateMix + (translate - data.translateMix) * alpha;
			constraint.scaleMix = data.scaleMix + (scale - data.scaleMix) * alpha;
			constraint.shearMix = data.shearMix + (shear - data.shearMix) * alpha;
		} else {
			constraint.rotateMix += (rotate - constraint.rotateMix) * alpha;
			constraint.translateMix += (translate - constraint.translateMix) * alpha;
			constraint.scaleMix += (scale - constraint.scaleMix) * alpha;
			constraint.shearMix += (shear - constraint.shearMix) * alpha;
		}
	}
}

/** Changes a path constraint's `PathConstraint.position`. */
class PathConstraintPositionTimeline extends CurveTimeline {
	public static inline final ENTRIES = 2;
	public static inline final PREV_TIME = -2;
	public static inline final PREV_VALUE = -1;
	public static inline final VALUE = 1;

	/** The index of the path constraint slot in `Skeleton.pathConstraints` that will be changed. */
	public var pathConstraintIndex:Int;

	/** The time in seconds and path constraint position for each key frame. */
	public final frames:Array<Float>; // time, position, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * PathConstraintPositionTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.pathConstraintPosition << 24) + this.pathConstraintIndex;
	}

	/** Sets the time in seconds and path constraint position for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, value:Float) {
		frameIndex *= PathConstraintPositionTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + PathConstraintPositionTimeline.VALUE] = value;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;
		var constraint:PathConstraint = skeleton.pathConstraints[this.pathConstraintIndex];
		if (!constraint.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					constraint.position = constraint.data.position;
				case MixBlend.first:
					constraint.position += (constraint.data.position - constraint.position) * alpha;
				case _:
			}
			return;
		}

		var position = 0.0;
		if (time >= frames[frames.length - PathConstraintPositionTimeline.ENTRIES]) // Time is after last frame.
			position = frames[frames.length + PathConstraintPositionTimeline.PREV_VALUE];
		else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, PathConstraintPositionTimeline.ENTRIES);
			position = frames[frame + PathConstraintPositionTimeline.PREV_VALUE];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / PathConstraintPositionTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + PathConstraintPositionTimeline.PREV_TIME] - frameTime));

			position += (frames[frame + PathConstraintPositionTimeline.VALUE] - position) * percent;
		}
		if (blend == MixBlend.setup)
			constraint.position = constraint.data.position + (position - constraint.data.position) * alpha;
		else
			constraint.position += (position - constraint.position) * alpha;
	}
}

/** Changes a path constraint's `PathConstraint.spacing`. */
class PathConstraintSpacingTimeline extends PathConstraintPositionTimeline {
	public function new(frameCount:Int) {
		super(frameCount);
	}

	override function getPropertyId():Int {
		return (TimelineType.pathConstraintSpacing << 24) + this.pathConstraintIndex;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;
		var constraint:PathConstraint = skeleton.pathConstraints[this.pathConstraintIndex];
		if (!constraint.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					constraint.spacing = constraint.data.spacing;
				case MixBlend.first:
					constraint.spacing += (constraint.data.spacing - constraint.spacing) * alpha;
				case _:
			}
			return;
		}

		var spacing = 0.0;
		if (time >= frames[frames.length - PathConstraintPositionTimeline.ENTRIES]) // Time is after last frame.
			spacing = frames[frames.length + PathConstraintPositionTimeline.PREV_VALUE];
		else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, PathConstraintPositionTimeline.ENTRIES);
			spacing = frames[frame + PathConstraintPositionTimeline.PREV_VALUE];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / PathConstraintPositionTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + PathConstraintPositionTimeline.PREV_TIME] - frameTime));

			spacing += (frames[frame + PathConstraintPositionTimeline.VALUE] - spacing) * percent;
		}

		if (blend == MixBlend.setup)
			constraint.spacing = constraint.data.spacing + (spacing - constraint.data.spacing) * alpha;
		else
			constraint.spacing += (spacing - constraint.spacing) * alpha;
	}
}

/** Changes a transform constraint's `PathConstraint.rotateMix` and
 * `TransformConstraint.translateMix`. */
class PathConstraintMixTimeline extends CurveTimeline {
	public static inline final ENTRIES = 3;
	public static inline final PREV_TIME = -3;
	public static inline final PREV_ROTATE = -2;
	public static inline final PREV_TRANSLATE = -1;
	public static inline final ROTATE = 1;
	public static inline final TRANSLATE = 2;

	/** The index of the path constraint slot in `Skeleton.pathConstraints` that will be changed. */
	public var pathConstraintIndex:Int;

	/** The time in seconds, rotate mix, and translate mix for each key frame. */
	public final frames:Array<Float>; // time, rotate mix, translate mix, ...

	public function new(frameCount:Int) {
		super(frameCount);
		this.frames = Utils.newFloatArray(frameCount * PathConstraintMixTimeline.ENTRIES);
	}

	override function getPropertyId():Int {
		return (TimelineType.pathConstraintMix << 24) + this.pathConstraintIndex;
	}

	/** The time in seconds, rotate mix, and translate mix for the specified key frame. */
	public function setFrame(frameIndex:Int, time:Float, rotateMix:Float, translateMix:Float) {
		frameIndex *= PathConstraintMixTimeline.ENTRIES;
		this.frames[frameIndex] = time;
		this.frames[frameIndex + PathConstraintMixTimeline.ROTATE] = rotateMix;
		this.frames[frameIndex + PathConstraintMixTimeline.TRANSLATE] = translateMix;
	}

	override function apply(skeleton:Skeleton, lastTime:Float, time:Float, firedEvents:Array<Event>, alpha:Float, blend:MixBlend, direction:MixDirection) {
		var frames = this.frames;
		var constraint:PathConstraint = skeleton.pathConstraints[this.pathConstraintIndex];
		if (!constraint.active)
			return;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.setup:
					constraint.rotateMix = constraint.data.rotateMix;
					constraint.translateMix = constraint.data.translateMix;
				case MixBlend.first:
					constraint.rotateMix += (constraint.data.rotateMix - constraint.rotateMix) * alpha;
					constraint.translateMix += (constraint.data.translateMix - constraint.translateMix) * alpha;
				case _:
			}
			return;
		}

		var rotate = 0.0, translate = 0.0;
		if (time >= frames[frames.length - PathConstraintMixTimeline.ENTRIES]) { // Time is after last frame.
			rotate = frames[frames.length + PathConstraintMixTimeline.PREV_ROTATE];
			translate = frames[frames.length + PathConstraintMixTimeline.PREV_TRANSLATE];
		} else {
			// Interpolate between the previous frame and the current frame.
			var frame = Animation.binarySearch(frames, time, PathConstraintMixTimeline.ENTRIES);
			rotate = frames[frame + PathConstraintMixTimeline.PREV_ROTATE];
			translate = frames[frame + PathConstraintMixTimeline.PREV_TRANSLATE];
			var frameTime = frames[frame];
			var percent = this.getCurvePercent(Std.int(frame / PathConstraintMixTimeline.ENTRIES - 1),
				1 - (time - frameTime) / (frames[frame + PathConstraintMixTimeline.PREV_TIME] - frameTime));

			rotate += (frames[frame + PathConstraintMixTimeline.ROTATE] - rotate) * percent;
			translate += (frames[frame + PathConstraintMixTimeline.TRANSLATE] - translate) * percent;
		}

		if (blend == MixBlend.setup) {
			constraint.rotateMix = constraint.data.rotateMix + (rotate - constraint.data.rotateMix) * alpha;
			constraint.translateMix = constraint.data.translateMix + (translate - constraint.data.translateMix) * alpha;
		} else {
			constraint.rotateMix += (rotate - constraint.rotateMix) * alpha;
			constraint.translateMix += (translate - constraint.translateMix) * alpha;
		}
	}
}
