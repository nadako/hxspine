package spine;

import spine.utils.MathUtils;

/** Stores the current pose for an IK constraint. An IK constraint adjusts the rotation of 1 or 2 constrained bones so the tip of
 * the last bone is as close to the target bone as possible.
 *
 * See [IK constraints](http://esotericsoftware.com/spine-ik-constraints) in the Spine User Guide. */
class IkConstraint implements Updatable {
	/** The IK constraint's setup pose data. */
	public var data:IkConstraintData;

	/** The bones that will be modified by this IK constraint. */
	public var bones:Array<Bone>;

	/** The bone that is the IK target. */
	public var target:Bone;

	/** Controls the bend direction of the IK bones, either 1 or -1. */
	public var bendDirection = 0;

	/** When true and only a single bone is being constrained, if the target is too close, the bone is scaled to reach it. */
	public var compress = false;

	/** When true, if the target is out of range, the parent bone is scaled to reach it. If more than one bone is being constrained
	 * and the parent bone has local nonuniform scale, stretch is not applied. */
	public var stretch = false;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained rotations. */
	public var mix = 1.0;

	/** For two bone IK, the distance from the maximum reach of the bones that rotation will slow. */
	public var softness = 0.0;

	public var active = false;

	public function new(data:IkConstraintData, skeleton:Skeleton) {
		if (data == null)
			throw new Error("data cannot be null.");
		if (skeleton == null)
			throw new Error("skeleton cannot be null.");
		this.data = data;
		this.mix = data.mix;
		this.softness = data.softness;
		this.bendDirection = data.bendDirection;
		this.compress = data.compress;
		this.stretch = data.stretch;

		this.bones = new Array<Bone>();
		for (bone in data.bones)
			this.bones.push(skeleton.findBone(bone.name));
		this.target = skeleton.findBone(data.target.name);
	}

	public function isActive() {
		return this.active;
	}

	/** Applies the constraint to the constrained bones. */
	public function apply() {
		this.update();
	}

	public function update() {
		var target = this.target;
		switch bones {
			case [bone]:
				apply1(bone, target.worldX, target.worldY, this.compress, this.stretch, this.data.uniform, this.mix);
			case [parent, child]:
				apply2(parent, child, target.worldX, target.worldY, this.bendDirection, this.stretch, this.softness, this.mix);
		}
	}

	/** Applies 1 bone IK. The target is specified in the world coordinate system. */
	public function apply1(bone:Bone, targetX:Float, targetY:Float, compress:Bool, stretch:Bool, uniform:Bool, alpha:Float) {
		if (!bone.appliedValid)
			bone.updateAppliedTransform();
		var p = bone.parent;

		var pa = p.a, pb = p.b, pc = p.c, pd = p.d;
		var rotationIK = -bone.ashearX - bone.arotation, tx = 0, ty = 0;

		var tx, ty;
		switch (bone.data.transformMode) {
			case OnlyTranslation:
				tx = targetX - bone.worldX;
				ty = targetY - bone.worldY;
			case NoRotationOrReflection:
				rotationIK += Math.atan2(pc, pa) * MathUtils.radDeg;
				var ps = Math.abs(pa * pd - pb * pc) / (pa * pa + pc * pc);
				pb = -pc * ps;
				pd = pa * ps;
				// Fall through was here
				var x = targetX - p.worldX, y = targetY - p.worldY;
				var d = pa * pd - pb * pc;
				tx = (x * pd - y * pb) / d - bone.ax;
				ty = (y * pa - x * pc) / d - bone.ay;
			default:
				var x = targetX - p.worldX, y = targetY - p.worldY;
				var d = pa * pd - pb * pc;
				tx = (x * pd - y * pb) / d - bone.ax;
				ty = (y * pa - x * pc) / d - bone.ay;
		}
		rotationIK += Math.atan2(ty, tx) * MathUtils.radDeg;

		if (bone.ascaleX < 0)
			rotationIK += 180;
		if (rotationIK > 180)
			rotationIK -= 360;
		else if (rotationIK < -180)
			rotationIK += 360;
		var sx = bone.ascaleX, sy = bone.ascaleY;
		if (compress || stretch) {
			switch (bone.data.transformMode) {
				case NoScale | NoScaleOrReflection:
					tx = targetX - bone.worldX;
					ty = targetY - bone.worldY;
				case _:
			}
			var b = bone.data.length * sx, dd = Math.sqrt(tx * tx + ty * ty);
			if ((compress && dd < b) || (stretch && dd > b) && b > 0.0001) {
				var s = (dd / b - 1) * alpha + 1;
				sx *= s;
				if (uniform)
					sy *= s;
			}
		}
		bone.updateWorldTransformWith(bone.ax, bone.ay, bone.arotation + rotationIK * alpha, sx, sy, bone.ashearX, bone.ashearY);
	}

	/** Applies 2 bone IK. The target is specified in the world coordinate system.
	 * @param child A direct descendant of the parent bone. */
	public function apply2(parent:Bone, child:Bone, targetX:Float, targetY:Float, bendDir:Int, stretch:Bool, softness:Float, alpha:Float) {
		if (alpha == 0) {
			child.updateWorldTransform();
			return;
		}
		if (!parent.appliedValid)
			parent.updateAppliedTransform();
		if (!child.appliedValid)
			child.updateAppliedTransform();
		var px = parent.ax,
			py = parent.ay,
			psx = parent.ascaleX,
			sx = psx,
			psy = parent.ascaleY,
			csx = child.ascaleX;
		var os1 = 0, os2 = 0, s2 = 0;
		if (psx < 0) {
			psx = -psx;
			os1 = 180;
			s2 = -1;
		} else {
			os1 = 0;
			s2 = 1;
		}
		if (psy < 0) {
			psy = -psy;
			s2 = -s2;
		}
		if (csx < 0) {
			csx = -csx;
			os2 = 180;
		} else
			os2 = 0;
		var cx = child.ax, cy = 0.0, cwx = 0.0, cwy = 0.0, a = parent.a, b = parent.b, c = parent.c, d = parent.d;
		var u = Math.abs(psx - psy) <= 0.0001;
		if (!u) {
			cy = 0;
			cwx = a * cx + parent.worldX;
			cwy = c * cx + parent.worldY;
		} else {
			cy = child.ay;
			cwx = a * cx + b * cy + parent.worldX;
			cwy = c * cx + d * cy + parent.worldY;
		}
		var pp = parent.parent;
		a = pp.a;
		b = pp.b;
		c = pp.c;
		d = pp.d;
		var id = 1 / (a * d - b * c), x = cwx - pp.worldX, y = cwy - pp.worldY;
		var dx = (x * d - y * b) * id - px, dy = (y * a - x * c) * id - py;
		var l1 = Math.sqrt(dx * dx + dy * dy),
			l2 = child.data.length * csx,
			a1 = 0.0,
			a2 = 0.0;
		if (l1 < 0.0001) {
			this.apply1(parent, targetX, targetY, false, stretch, false, alpha);
			child.updateWorldTransformWith(cx, cy, 0, child.ascaleX, child.ascaleY, child.ashearX, child.ashearY);
			return;
		}
		x = targetX - pp.worldX;
		y = targetY - pp.worldY;
		var tx = (x * d - y * b) * id - px, ty = (y * a - x * c) * id - py;
		var dd = tx * tx + ty * ty;
		if (softness != 0) {
			softness *= psx * (csx + 1) / 2;
			var td = Math.sqrt(dd), sd = td - l1 - l2 * psx + softness;
			if (sd > 0) {
				var p = Math.min(1, sd / (softness * 2)) - 1;
				p = (sd - softness * (1 - p * p)) / td;
				tx -= p * tx;
				ty -= p * ty;
				dd = tx * tx + ty * ty;
			}
		}
		if (u) {
			l2 *= psx;
			var cos = (dd - l1 * l1 - l2 * l2) / (2 * l1 * l2);
			if (cos < -1)
				cos = -1;
			else if (cos > 1) {
				cos = 1;
				if (stretch)
					sx *= (Math.sqrt(dd) / (l1 + l2) - 1) * alpha + 1;
			}
			a2 = Math.acos(cos) * bendDir;
			a = l1 + l2 * cos;
			b = l2 * Math.sin(a2);
			a1 = Math.atan2(ty * a - tx * b, tx * a + ty * b);
		} else {
			a = psx * l2;
			b = psy * l2;
			var aa = a * a, bb = b * b, ta = Math.atan2(ty, tx);
			c = bb * l1 * l1 + aa * dd - aa * bb;
			var c1 = -2 * bb * l1, c2 = bb - aa;
			d = c1 * c1 - 4 * c2 * c;
			var breakOuter = false;
			if (d >= 0) {
				var q = Math.sqrt(d);
				if (c1 < 0)
					q = -q;
				q = -(c1 + q) / 2;
				var r0 = q / c2, r1 = c / q;
				var r = Math.abs(r0) < Math.abs(r1) ? r0 : r1;
				if (r * r <= dd) {
					y = Math.sqrt(dd - r * r) * bendDir;
					a1 = ta - Math.atan2(y, r);
					a2 = Math.atan2(y / psy, (r - l1) / psx);
					breakOuter = true;
				}
			}
			if (!breakOuter) {
				var minAngle = MathUtils.PI,
					minX = l1 - a,
					minDist = minX * minX,
					minY = 0.0;
				var maxAngle = 0.0,
					maxX = l1 + a,
					maxDist = maxX * maxX,
					maxY = 0.0;
				c = -a * l1 / (aa - bb);
				if (c >= -1 && c <= 1) {
					c = Math.acos(c);
					x = a * Math.cos(c) + l1;
					y = b * Math.sin(c);
					d = x * x + y * y;
					if (d < minDist) {
						minAngle = c;
						minDist = d;
						minX = x;
						minY = y;
					}
					if (d > maxDist) {
						maxAngle = c;
						maxDist = d;
						maxX = x;
						maxY = y;
					}
				}
				if (dd <= (minDist + maxDist) / 2) {
					a1 = ta - Math.atan2(minY * bendDir, minX);
					a2 = minAngle * bendDir;
				} else {
					a1 = ta - Math.atan2(maxY * bendDir, maxX);
					a2 = maxAngle * bendDir;
				}
			}
		}
		var os = Math.atan2(cy, cx) * s2;
		var rotation = parent.arotation;
		a1 = (a1 - os) * MathUtils.radDeg + os1 - rotation;
		if (a1 > 180)
			a1 -= 360;
		else if (a1 < -180)
			a1 += 360;
		parent.updateWorldTransformWith(px, py, rotation + a1 * alpha, sx, parent.ascaleY, 0, 0);
		rotation = child.arotation;
		a2 = ((a2 + os) * MathUtils.radDeg - child.ashearX) * s2 + os2 - rotation;
		if (a2 > 180)
			a2 -= 360;
		else if (a2 < -180)
			a2 += 360;
		child.updateWorldTransformWith(cx, cy, rotation + a2 * alpha, child.ascaleX, child.ascaleY, child.ashearX, child.ashearY);
	}
}
