package spine;

import spine.utils.MathUtils;
import spine.utils.Vector2;

/** Stores a bone's current pose.
 *
 * A bone has a local transform which is used to compute its world transform. A bone also has an applied transform, which is a
 * local transform that can be applied to compute the world transform. The local transform and applied transform may differ if a
 * constraint or application code modifies the world transform after it was computed from the local transform. */
class Bone implements Updatable {
	/** The bone's setup pose data. */
	public final data:BoneData;

	/** The skeleton this bone belongs to. */
	public final skeleton:Skeleton;

	/** The parent bone, or null if this is the root bone. */
	public final parent:Null<Bone>;

	/** The immediate children of this bone. */
	public final children = new Array<Bone>();

	/** The local x translation. */
	public var x:Float = 0.0;

	/** The local y translation. */
	public var y:Float = 0.0;

	/** The local rotation in degrees, counter clockwise. */
	public var rotation:Float = 0.0;

	/** The local scaleX. */
	public var scaleX:Float = 0.0;

	/** The local scaleY. */
	public var scaleY:Float = 0.0;

	/** The local shearX. */
	public var shearX:Float = 0.0;

	/** The local shearY. */
	public var shearY:Float = 0.0;

	/** The applied local x translation. */
	public var ax:Float = 0.0;

	/** The applied local y translation. */
	public var ay:Float = 0.0;

	/** The applied local rotation in degrees, counter clockwise. */
	public var arotation:Float = 0.0;

	/** The applied local scaleX. */
	public var ascaleX:Float = 0.0;

	/** The applied local scaleY. */
	public var ascaleY:Float = 0.0;

	/** The applied local shearX. */
	public var ashearX:Float = 0.0;

	/** The applied local shearY. */
	public var ashearY:Float = 0.0;

	/** If true, the applied transform matches the world transform. If false, the world transform has been modified since it was
	 * computed and `updateAppliedTransform` must be called before accessing the applied transform. */
	public var appliedValid:Bool = false;

	/** Part of the world transform matrix for the X axis. If changed, `appliedValid` should be set to false. */
	public var a:Float = 0.0;

	/** Part of the world transform matrix for the Y axis. If changed, `appliedValid` should be set to false. */
	public var b:Float = 0.0;

	/** Part of the world transform matrix for the X axis. If changed, `appliedValid` should be set to false. */
	public var c:Float = 0.0;

	/** Part of the world transform matrix for the Y axis. If changed, `appliedValid` should be set to false. */
	public var d:Float = 0.0;

	/** The world X position. If changed, `appliedValid` should be set to false. */
	public var worldY:Float = 0.0;

	/** The world Y position. If changed, `appliedValid` should be set to false. */
	public var worldX:Float = 0.0;

	/** Returns false when the bone has not been computed because `BoneData.skinRequired` is true and the
	 * active `Skeleton.skin` skin does not contain this bone in `Skin.bones`. */
	@:allow(spine.Skeleton)
	public var active(default,null):Bool = false;

	@:allow(spine.Skeleton)
	var sorted:Bool = false;

	public function new(data:BoneData, skeleton:Skeleton, parent:Null<Bone>) {
		if (data == null)
			throw new Error("data cannot be null.");
		if (skeleton == null)
			throw new Error("skeleton cannot be null.");
		this.data = data;
		this.skeleton = skeleton;
		this.parent = parent;
		setToSetupPose();
	}

	/** Returns false when the bone has not been computed because `BoneData.skinRequired` is true and the
	 * active `Skeleton.skin` skin does not contain this bone in `Skin.bones`. */
	public inline function isActive():Bool {
		return active;
	}

	/** Same as `updateWorldTransform`. This method exists for Bone to implement `Updatable`. */
	public inline function update() {
		updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
	}

	/** Computes the world transform using the parent bone and this bone's local transform.
	 *
	 * See `updateWorldTransformWith`. */
	public function updateWorldTransform() {
		updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
	}

	/** Computes the world transform using the parent bone and the specified local transform. Child bones are not updated.
	 *
	 * See [World transforms](http://esotericsoftware.com/spine-runtime-skeletons#World-transforms) in the Spine
	 * Runtimes Guide. */
	public function updateWorldTransformWith(x:Float, y:Float, rotation:Float, scaleX:Float, scaleY:Float, shearX:Float, shearY:Float) {
		this.ax = x;
		this.ay = y;
		this.arotation = rotation;
		this.ascaleX = scaleX;
		this.ascaleY = scaleY;
		this.ashearX = shearX;
		this.ashearY = shearY;
		this.appliedValid = true;

		var sx = skeleton.scaleX;
		var sy = skeleton.scaleY * -1;

		var parent = this.parent;
		if (parent == null) { // Root bone.
			var skeleton = this.skeleton;
			var rotationY = rotation + 90 + shearY;
			this.a = MathUtils.cosDeg(rotation + shearX) * scaleX * sx;
			this.b = MathUtils.cosDeg(rotationY) * scaleY * sx;
			this.c = MathUtils.sinDeg(rotation + shearX) * scaleX * sy;
			this.d = MathUtils.sinDeg(rotationY) * scaleY * sy;
			this.worldX = x * sx + skeleton.x;
			this.worldY = y * sy + skeleton.y;
			return;
		}

		var pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d;
		this.worldX = pa * x + pb * y + parent.worldX;
		this.worldY = pc * x + pd * y + parent.worldY;

		switch (this.data.transformMode) {
			case Normal:
				var rotationY = rotation + 90 + shearY;
				var la = MathUtils.cosDeg(rotation + shearX) * scaleX;
				var lb = MathUtils.cosDeg(rotationY) * scaleY;
				var lc = MathUtils.sinDeg(rotation + shearX) * scaleX;
				var ld = MathUtils.sinDeg(rotationY) * scaleY;
				this.a = pa * la + pb * lc;
				this.b = pa * lb + pb * ld;
				this.c = pc * la + pd * lc;
				this.d = pc * lb + pd * ld;
				return;
			case OnlyTranslation:
				var rotationY = rotation + 90 + shearY;
				this.a = MathUtils.cosDeg(rotation + shearX) * scaleX;
				this.b = MathUtils.cosDeg(rotationY) * scaleY;
				this.c = MathUtils.sinDeg(rotation + shearX) * scaleX;
				this.d = MathUtils.sinDeg(rotationY) * scaleY;
			case NoRotationOrReflection:
				var s = pa * pa + pc * pc;
				var prx = 0.0;
				if (s > 0.0001) {
					s = Math.abs(pa * pd - pb * pc) / s;
					pa /= skeleton.scaleX;
					pc /= skeleton.scaleY;
					pb = pc * s;
					pd = pa * s;
					prx = Math.atan2(pc, pa) * MathUtils.radDeg;
				} else {
					pa = 0;
					pc = 0;
					prx = 90 - Math.atan2(pd, pb) * MathUtils.radDeg;
				}
				var rx = rotation + shearX - prx;
				var ry = rotation + shearY - prx + 90;
				var la = MathUtils.cosDeg(rx) * scaleX;
				var lb = MathUtils.cosDeg(ry) * scaleY;
				var lc = MathUtils.sinDeg(rx) * scaleX;
				var ld = MathUtils.sinDeg(ry) * scaleY;
				this.a = pa * la - pb * lc;
				this.b = pa * lb - pb * ld;
				this.c = pc * la + pd * lc;
				this.d = pc * lb + pd * ld;
			case NoScale | NoScaleOrReflection:
				var cos = MathUtils.cosDeg(rotation);
				var sin = MathUtils.sinDeg(rotation);
				var za = (pa * cos + pb * sin) / sx;
				var zc = (pc * cos + pd * sin) / sy;
				var s = Math.sqrt(za * za + zc * zc);
				if (s > 0.00001)
					s = 1 / s;
				za *= s;
				zc *= s;
				s = Math.sqrt(za * za + zc * zc);
				if (this.data.transformMode == NoScale && (pa * pd - pb * pc < 0) != ((sx < 0) != (sy < 0))) // TODO: recheck this
					s = -s;
				var r = Math.PI / 2 + Math.atan2(zc, za);
				var zb = Math.cos(r) * s;
				var zd = Math.sin(r) * s;
				var la = MathUtils.cosDeg(shearX) * scaleX;
				var lb = MathUtils.cosDeg(90 + shearY) * scaleY;
				var lc = MathUtils.sinDeg(shearX) * scaleX;
				var ld = MathUtils.sinDeg(90 + shearY) * scaleY;
				this.a = za * la + zb * lc;
				this.b = za * lb + zb * ld;
				this.c = zc * la + zd * lc;
				this.d = zc * lb + zd * ld;
		}
		this.a *= sx;
		this.b *= sx;
		this.c *= sy;
		this.d *= sy;
	}

	/** Sets this bone's local transform to the setup pose. */
	public function setToSetupPose() {
		var data = this.data;
		this.x = data.x;
		this.y = data.y;
		this.rotation = data.rotation;
		this.scaleX = data.scaleX;
		this.scaleY = data.scaleY;
		this.shearX = data.shearX;
		this.shearY = data.shearY;
	}

	/** The world rotation for the X axis, calculated using `a` and `c. */
	public function getWorldRotationX():Float {
		return Math.atan2(this.c, this.a) * MathUtils.radDeg;
	}

	/** The world rotation for the Y axis, calculated using `b` and `d. */
	public function getWorldRotationY():Float {
		return Math.atan2(this.d, this.b) * MathUtils.radDeg;
	}

	/** The magnitude (always positive) of the world scale X, calculated using `a` and `c`. */
	public function getWorldScaleX():Float {
		return Math.sqrt(this.a * this.a + this.c * this.c);
	}

	/** The magnitude (always positive) of the world scale Y, calculated using `b` and `d`. */
	public function getWorldScaleY():Float {
		return Math.sqrt(this.b * this.b + this.d * this.d);
	}

	/** Computes the applied transform values from the world transform. This allows the applied transform to be accessed after the
	 * world transform has been modified (by a constraint, `rotateWorld`, etc).
	 *
	 * If `updateWorldTransform` has been called for a bone and `appliedValid` is false, then
	 * `updateAppliedTransform` must be called before accessing the applied transform.
	 *
	 * Some information is ambiguous in the world transform, such as -1,-1 scale versus 180 rotation. The applied transform after
	 * calling this method is equivalent to the local tranform used to compute the world transform, but may not be identical. */
	public function updateAppliedTransform() {
		this.appliedValid = true;
		var parent = this.parent;
		if (parent == null) {
			this.ax = this.worldX;
			this.ay = this.worldY;
			this.arotation = Math.atan2(this.c, this.a) * MathUtils.radDeg;
			this.ascaleX = Math.sqrt(this.a * this.a + this.c * this.c);
			this.ascaleY = Math.sqrt(this.b * this.b + this.d * this.d);
			this.ashearX = 0;
			this.ashearY = Math.atan2(this.a * this.b + this.c * this.d, this.a * this.d - this.b * this.c) * MathUtils.radDeg;
			return;
		}
		var pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d;
		var pid = 1 / (pa * pd - pb * pc);
		var dx = this.worldX - parent.worldX, dy = this.worldY - parent.worldY;
		this.ax = (dx * pd * pid - dy * pb * pid);
		this.ay = (dy * pa * pid - dx * pc * pid);
		var ia = pid * pd;
		var id = pid * pa;
		var ib = pid * pb;
		var ic = pid * pc;
		var ra = ia * this.a - ib * this.c;
		var rb = ia * this.b - ib * this.d;
		var rc = id * this.c - ic * this.a;
		var rd = id * this.d - ic * this.b;
		this.ashearX = 0;
		this.ascaleX = Math.sqrt(ra * ra + rc * rc);
		if (this.ascaleX > 0.0001) {
			var det = ra * rd - rb * rc;
			this.ascaleY = det / this.ascaleX;
			this.ashearY = Math.atan2(ra * rb + rc * rd, det) * MathUtils.radDeg;
			this.arotation = Math.atan2(rc, ra) * MathUtils.radDeg;
		} else {
			this.ascaleX = 0;
			this.ascaleY = Math.sqrt(rb * rb + rd * rd);
			this.ashearY = 0;
			this.arotation = 90 - Math.atan2(rd, rb) * MathUtils.radDeg;
		}
	}

	/** Transforms a point from world coordinates to the bone's local coordinates. */
	public function worldToLocal(world:Vector2):Vector2 {
		var a = this.a, b = this.b, c = this.c, d = this.d;
		var invDet = 1 / (a * d - b * c);
		var x = world.x - this.worldX, y = world.y - this.worldY;
		world.x = (x * d * invDet - y * b * invDet);
		world.y = (y * a * invDet - x * c * invDet);
		return world;
	}

	/** Transforms a point from the bone's local coordinates to world coordinates. */
	public function localToWorld(local:Vector2):Vector2 {
		var x = local.x, y = local.y;
		local.x = x * this.a + y * this.b + this.worldX;
		local.y = x * this.c + y * this.d + this.worldY;
		return local;
	}

	/** Transforms a world rotation to a local rotation. */
	public function worldToLocalRotation(worldRotation:Float):Float {
		var sin = MathUtils.sinDeg(worldRotation),
			cos = MathUtils.cosDeg(worldRotation);
		return Math.atan2(this.a * sin - this.c * cos, this.d * cos - this.b * sin) * MathUtils.radDeg + this.rotation - this.shearX;
	}

	/** Transforms a local rotation to a world rotation. */
	public function localToWorldRotation(localRotation:Float):Float {
		localRotation -= this.rotation - this.shearX;
		var sin = MathUtils.sinDeg(localRotation),
			cos = MathUtils.cosDeg(localRotation);
		return Math.atan2(cos * this.c + sin * this.d, cos * this.a + sin * this.b) * MathUtils.radDeg;
	}

	/** Rotates the world transform the specified amount and sets `appliedValid` to false.
	 * `updateWorldTransform` will need to be called on any child bones, recursively, and any constraints reapplied. */
	public function rotateWorld(degrees:Float) {
		var a = this.a, b = this.b, c = this.c, d = this.d;
		var cos = MathUtils.cosDeg(degrees), sin = MathUtils.sinDeg(degrees);
		this.a = cos * a - sin * c;
		this.b = cos * b - sin * d;
		this.c = sin * a + cos * c;
		this.d = sin * b + cos * d;
		this.appliedValid = false;
	}
}
