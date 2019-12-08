package spine;

import spine.utils.Utils;
import spine.attachments.PathAttachment;
import spine.utils.MathUtils;
import spine.PathConstraintData;

/** Stores the current pose for a path constraint. A path constraint adjusts the rotation, translation, and scale of the
 * constrained bones so they follow a {@link PathAttachment}.
 *
 * See [Path constraints](http://esotericsoftware.com/spine-path-constraints) in the Spine User Guide. */
class PathConstraint implements Updatable {
	public static inline var NONE = -1;
	public static inline var BEFORE = -2;
	public static inline var AFTER = -3;
	public static inline var epsilon = 0.00001;

	/** The path constraint's setup pose data. */
	public var data:PathConstraintData;

	/** The bones that will be modified by this path constraint. */
	public var bones:Array<Bone>;

	/** The slot whose path attachment will be used to constrained the bones. */
	public var target:Slot;

	/** The position along the path. */
	public var position = 0.0;

	/** The spacing between bones. */
	public var spacing = 0.0;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained rotations. */
	public var rotateMix = 0.0;

	/** A percentage (0-1) that controls the mix between the constrained and unconstrained translations. */
	public var translateMix = 0.0;

	public var spaces = new Array<Float>();
	public var positions = new Array<Float>();
	public var world = new Array<Float>();
	public var curves = new Array<Float>();
	public var lengths = new Array<Float>();
	public var segments = new Array<Float>();

	public var active = false;

	public function new(data:PathConstraintData, skeleton:Skeleton) {
		if (data == null)
			throw new Error("data cannot be null.");
		if (skeleton == null)
			throw new Error("skeleton cannot be null.");
		this.data = data;
		this.bones = new Array<Bone>();
		for (bone in data.bones)
			this.bones.push(skeleton.findBone(bone.name));
		this.target = skeleton.findSlot(data.target.name);
		this.position = data.position;
		this.spacing = data.spacing;
		this.rotateMix = data.rotateMix;
		this.translateMix = data.translateMix;
	}

	public function isActive() {
		return this.active;
	}

	/** Applies the constraint to the constrained bones. */
	public function apply() {
		this.update();
	}

	public function update() {
		var attachment = this.target.getAttachment();
		if (!Std.is(attachment, PathAttachment))
			return;

		var rotateMix = this.rotateMix, translateMix = this.translateMix;
		var translate = translateMix > 0, rotate = rotateMix > 0;
		if (!translate && !rotate)
			return;

		var data = this.data;
		var percentSpacing = data.spacingMode == SpacingMode.Percent;
		var rotateMode = data.rotateMode;
		var tangents = rotateMode == RotateMode.Tangent,
			scale = rotateMode == RotateMode.ChainScale;
		var boneCount = this.bones.length,
			spacesCount = tangents ? boneCount : boneCount + 1;
		var bones = this.bones;
		var spaces = Utils.setArraySize(this.spaces, spacesCount, 0),
			lengths:Array<Float> = null;
		var spacing = this.spacing;
		if (scale || !percentSpacing) {
			if (scale)
				lengths = Utils.setArraySize(this.lengths, boneCount, 0);
			var lengthSpacing = data.spacingMode == SpacingMode.Length;
			var i = 0, n = spacesCount - 1;
			while (i < n) {
				var bone = bones[i];
				var setupLength = bone.data.length;
				if (setupLength < PathConstraint.epsilon) {
					if (scale)
						lengths[i] = 0;
					spaces[++i] = 0;
				} else if (percentSpacing) {
					if (scale) {
						var x = setupLength * bone.a, y = setupLength * bone.c;
						var length = Math.sqrt(x * x + y * y);
						lengths[i] = length;
					}
					spaces[++i] = spacing;
				} else {
					var x = setupLength * bone.a, y = setupLength * bone.c;
					var length = Math.sqrt(x * x + y * y);
					if (scale)
						lengths[i] = length;
					spaces[++i] = (lengthSpacing ? setupLength + spacing : spacing) * length / setupLength;
				}
			}
		} else {
			for (i in 1...spacesCount)
				spaces[i] = spacing;
		}

		var positions = this.computeWorldPositions(cast attachment, spacesCount, tangents, data.positionMode == PositionMode.Percent, percentSpacing);
		var boneX = positions[0],
			boneY = positions[1],
			offsetRotation = data.offsetRotation;
		var tip = false;
		if (offsetRotation == 0)
			tip = rotateMode == RotateMode.Chain;
		else {
			tip = false;
			var p = this.target.bone;
			offsetRotation *= p.a * p.d - p.b * p.c > 0 ? MathUtils.degRad : -MathUtils.degRad;
		}
		var i = 0, p = 3;
		while (i < boneCount) {
			var bone = bones[i];
			bone.worldX += (boneX - bone.worldX) * translateMix;
			bone.worldY += (boneY - bone.worldY) * translateMix;
			var x = positions[p],
				y = positions[p + 1],
				dx = x - boneX,
				dy = y - boneY;
			if (scale) {
				var length = lengths[i];
				if (length != 0) {
					var s = (Math.sqrt(dx * dx + dy * dy) / length - 1) * rotateMix + 1;
					bone.a *= s;
					bone.c *= s;
				}
			}
			boneX = x;
			boneY = y;
			if (rotate) {
				var a = bone.a, b = bone.b, c = bone.c, d = bone.d, r = 0.0, cos = 0.0, sin = 0.0;
				if (tangents)
					r = positions[p - 1];
				else if (spaces[i + 1] == 0)
					r = positions[p + 2];
				else
					r = Math.atan2(dy, dx);
				r -= Math.atan2(c, a);
				if (tip) {
					cos = Math.cos(r);
					sin = Math.sin(r);
					var length = bone.data.length;
					boneX += (length * (cos * a - sin * c) - dx) * rotateMix;
					boneY += (length * (sin * a + cos * c) - dy) * rotateMix;
				} else {
					r += offsetRotation;
				}
				if (r > MathUtils.PI)
					r -= MathUtils.PI2;
				else if (r < -MathUtils.PI) //
					r += MathUtils.PI2;
				r *= rotateMix;
				cos = Math.cos(r);
				sin = Math.sin(r);
				bone.a = cos * a - sin * c;
				bone.b = cos * b - sin * d;
				bone.c = sin * a + cos * c;
				bone.d = sin * b + cos * d;
			}
			bone.appliedValid = false;

			i++;
			p += 3;
		}
	}

	public function computeWorldPositions(path:PathAttachment, spacesCount:Int, tangents:Bool, percentPosition:Bool, percentSpacing:Bool) {
		var target = this.target;
		var position = this.position;
		var spaces = this.spaces,
			out = Utils.setArraySize(this.positions, spacesCount * 3 + 2, 0),
			world:Array<Float> = null;
		var closed = path.closed;
		var verticesLength = path.worldVerticesLength,
			curveCount = Std.int(verticesLength / 6),
			prevCurve = PathConstraint.NONE;

		if (!path.constantSpeed) {
			var lengths = path.lengths;
			curveCount -= closed ? 1 : 2;
			var pathLength = lengths[curveCount];
			if (percentPosition)
				position *= pathLength;
			if (percentSpacing) {
				for (i in 1...spacesCount)
					spaces[i] *= pathLength;
			}
			world = Utils.setArraySize(this.world, 8, 0);
			var i = 0, o = 0, curve = 0;
			while (i < spacesCount) {
				var space = spaces[i];
				position += space;
				var p = position;

				if (closed) {
					p %= pathLength;
					if (p < 0)
						p += pathLength;
					curve = 0;
				} else if (p < 0) {
					if (prevCurve != PathConstraint.BEFORE) {
						prevCurve = PathConstraint.BEFORE;
						path.computeWorldVertices(target, 2, 4, world, 0, 2);
					}
					this.addBeforePosition(p, world, 0, out, o);
					i++;
					o += 3;
					continue;
				} else if (p > pathLength) {
					if (prevCurve != PathConstraint.AFTER) {
						prevCurve = PathConstraint.AFTER;
						path.computeWorldVertices(target, verticesLength - 6, 4, world, 0, 2);
					}
					this.addAfterPosition(p - pathLength, world, 0, out, o);
					i++;
					o += 3;
					continue;
				}

				// Determine curve containing position.
				while (true) {
					var length = lengths[curve];
					if (p > length) {
						curve++;
						continue;
					}
					if (curve == 0)
						p /= length;
					else {
						var prev = lengths[curve - 1];
						p = (p - prev) / (length - prev);
					}
					break;
				}
				if (curve != prevCurve) {
					prevCurve = curve;
					if (closed && curve == curveCount) {
						path.computeWorldVertices(target, verticesLength - 4, 4, world, 0, 2);
						path.computeWorldVertices(target, 0, 4, world, 4, 2);
					} else
						path.computeWorldVertices(target, curve * 6 + 2, 8, world, 0, 2);
				}
				this.addCurvePosition(p, world[0], world[1], world[2], world[3], world[4], world[5], world[6], world[7], out, o, tangents || (i > 0
					&& space == 0));
			}
			return out;
		}

		// World vertices.
		if (closed) {
			verticesLength += 2;
			world = Utils.setArraySize(this.world, verticesLength, 0);
			path.computeWorldVertices(target, 2, verticesLength - 4, world, 0, 2);
			path.computeWorldVertices(target, 0, 2, world, verticesLength - 4, 2);
			world[verticesLength - 2] = world[0];
			world[verticesLength - 1] = world[1];
		} else {
			curveCount--;
			verticesLength -= 4;
			world = Utils.setArraySize(this.world, verticesLength, 0);
			path.computeWorldVertices(target, 2, verticesLength, world, 0, 2);
		}

		// Curve lengths.
		var curves = Utils.setArraySize(this.curves, curveCount, 0);
		var pathLength = 0.0;
		var x1 = world[0], y1 = world[1], cx1 = 0.0, cy1 = 0.0, cx2 = 0.0, cy2 = 0.0, x2 = 0.0, y2 = 0.0;
		var tmpx = 0.0, tmpy = 0.0, dddfx = 0.0, dddfy = 0.0, ddfx = 0.0, ddfy = 0.0, dfx = 0.0, dfy = 0.0;
		var i = 0, w = 2;
		while (i < curveCount) {
			cx1 = world[w];
			cy1 = world[w + 1];
			cx2 = world[w + 2];
			cy2 = world[w + 3];
			x2 = world[w + 4];
			y2 = world[w + 5];
			tmpx = (x1 - cx1 * 2 + cx2) * 0.1875;
			tmpy = (y1 - cy1 * 2 + cy2) * 0.1875;
			dddfx = ((cx1 - cx2) * 3 - x1 + x2) * 0.09375;
			dddfy = ((cy1 - cy2) * 3 - y1 + y2) * 0.09375;
			ddfx = tmpx * 2 + dddfx;
			ddfy = tmpy * 2 + dddfy;
			dfx = (cx1 - x1) * 0.75 + tmpx + dddfx * 0.16666667;
			dfy = (cy1 - y1) * 0.75 + tmpy + dddfy * 0.16666667;
			pathLength += Math.sqrt(dfx * dfx + dfy * dfy);
			dfx += ddfx;
			dfy += ddfy;
			ddfx += dddfx;
			ddfy += dddfy;
			pathLength += Math.sqrt(dfx * dfx + dfy * dfy);
			dfx += ddfx;
			dfy += ddfy;
			pathLength += Math.sqrt(dfx * dfx + dfy * dfy);
			dfx += ddfx + dddfx;
			dfy += ddfy + dddfy;
			pathLength += Math.sqrt(dfx * dfx + dfy * dfy);
			curves[i] = pathLength;
			x1 = x2;
			y1 = y2;

			i++;
			w += 6;
		}
		if (percentPosition)
			position *= pathLength;
		else
			position *= pathLength / path.lengths[curveCount - 1];
		if (percentSpacing) {
			for (i in 1...spacesCount)
				spaces[i] *= pathLength;
		}

		var segments = this.segments;
		var curveLength = 0.0;
		var i = 0, o = 0, curve = 0, segment = 0;
		while (i < spacesCount) {
			var space = spaces[i];
			position += space;
			var p = position;

			if (closed) {
				p %= pathLength;
				if (p < 0)
					p += pathLength;
				curve = 0;
			} else if (p < 0) {
				this.addBeforePosition(p, world, 0, out, o);

				i++;
				o += 3;
				continue;
			} else if (p > pathLength) {
				this.addAfterPosition(p - pathLength, world, verticesLength - 4, out, o);

				i++;
				o += 3;
				continue;
			}

			// Determine curve containing position.
			while (true) {
				var length = curves[curve];
				if (p > length) {
					curve++;
					continue;
				}
				if (curve == 0)
					p /= length;
				else {
					var prev = curves[curve - 1];
					p = (p - prev) / (length - prev);
				}
				break;
			}

			// Curve segment lengths.
			if (curve != prevCurve) {
				prevCurve = curve;
				var ii = curve * 6;
				x1 = world[ii];
				y1 = world[ii + 1];
				cx1 = world[ii + 2];
				cy1 = world[ii + 3];
				cx2 = world[ii + 4];
				cy2 = world[ii + 5];
				x2 = world[ii + 6];
				y2 = world[ii + 7];
				tmpx = (x1 - cx1 * 2 + cx2) * 0.03;
				tmpy = (y1 - cy1 * 2 + cy2) * 0.03;
				dddfx = ((cx1 - cx2) * 3 - x1 + x2) * 0.006;
				dddfy = ((cy1 - cy2) * 3 - y1 + y2) * 0.006;
				ddfx = tmpx * 2 + dddfx;
				ddfy = tmpy * 2 + dddfy;
				dfx = (cx1 - x1) * 0.3 + tmpx + dddfx * 0.16666667;
				dfy = (cy1 - y1) * 0.3 + tmpy + dddfy * 0.16666667;
				curveLength = Math.sqrt(dfx * dfx + dfy * dfy);
				segments[0] = curveLength;
				for (ii in 1...8) {
					dfx += ddfx;
					dfy += ddfy;
					ddfx += dddfx;
					ddfy += dddfy;
					curveLength += Math.sqrt(dfx * dfx + dfy * dfy);
					segments[ii] = curveLength;
				}
				dfx += ddfx;
				dfy += ddfy;
				curveLength += Math.sqrt(dfx * dfx + dfy * dfy);
				segments[8] = curveLength;
				dfx += ddfx + dddfx;
				dfy += ddfy + dddfy;
				curveLength += Math.sqrt(dfx * dfx + dfy * dfy);
				segments[9] = curveLength;
				segment = 0;
			}

			// Weight by segment length.
			p *= curveLength;
			while (true) {
				var length = segments[segment];
				if (p > length) {
					segment++;
					continue;
				}
				if (segment == 0)
					p /= length;
				else {
					var prev = segments[segment - 1];
					p = segment + (p - prev) / (length - prev);
				}
				break;
			}
			this.addCurvePosition(p * 0.1, x1, y1, cx1, cy1, cx2, cy2, x2, y2, out, o, tangents || (i > 0 && space == 0));

			i++;
			o += 3;
		}
		return out;
	}

	public function addBeforePosition(p:Float, temp:Array<Float>, i:Int, out:Array<Float>, o:Int) {
		var x1 = temp[i],
			y1 = temp[i + 1],
			dx = temp[i + 2] - x1,
			dy = temp[i + 3] - y1,
			r = Math.atan2(dy, dx);
		out[o] = x1 + p * Math.cos(r);
		out[o + 1] = y1 + p * Math.sin(r);
		out[o + 2] = r;
	}

	public function addAfterPosition(p:Float, temp:Array<Float>, i:Int, out:Array<Float>, o:Int) {
		var x1 = temp[i + 2],
			y1 = temp[i + 3],
			dx = x1 - temp[i],
			dy = y1 - temp[i + 1],
			r = Math.atan2(dy, dx);
		out[o] = x1 + p * Math.cos(r);
		out[o + 1] = y1 + p * Math.sin(r);
		out[o + 2] = r;
	}

	public function addCurvePosition(p:Float, x1:Float, y1:Float, cx1:Float, cy1:Float, cx2:Float, cy2:Float, x2:Float, y2:Float, out:Array<Float>, o:Int,
			tangents:Bool) {
		if (p == 0 || Math.isNaN(p)) {
			out[o] = x1;
			out[o + 1] = y1;
			out[o + 2] = Math.atan2(cy1 - y1, cx1 - x1);
			return;
		}
		var tt = p * p, ttt = tt * p, u = 1 - p, uu = u * u, uuu = uu * u;
		var ut = u * p, ut3 = ut * 3, uut3 = u * ut3, utt3 = ut3 * p;
		var x = x1 * uuu + cx1 * uut3 + cx2 * utt3 + x2 * ttt,
			y = y1 * uuu + cy1 * uut3 + cy2 * utt3 + y2 * ttt;
		out[o] = x;
		out[o + 1] = y;
		if (tangents) {
			if (p < 0.001)
				out[o + 2] = Math.atan2(cy1 - y1, cx1 - x1);
			else
				out[o + 2] = Math.atan2(y - (y1 * uu + cy1 * ut * 2 + cy2 * tt), x - (x1 * uu + cx1 * ut * 2 + cx2 * tt));
		}
	}
}
