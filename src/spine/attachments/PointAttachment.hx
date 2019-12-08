package spine.attachments;

import spine.utils.MathUtils;
import spine.utils.Color;
import spine.utils.Vector2;

/** An attachment which is a single point and a rotation. This can be used to spawn projectiles, particles, etc. A bone can be
 * used in similar ways, but a PointAttachment is slightly less expensive to compute and can be hidden, shown, and placed in a
 * skin.
 *
 * See [Point Attachments](http://esotericsoftware.com/spine-point-attachments) in the Spine User Guide. */
class PointAttachment extends VertexAttachment {
	public var x:Float;
	public var y:Float;
	public var rotation:Float;

	/** The color of the point attachment as it was in Spine. Available only when nonessential data was exported. Point attachments
	 * are not usually rendered at runtime. */
	public var color = new Color(0.38, 0.94, 0, 1);

	public function new(name:String) {
		super(name);
	}

	public function computeWorldPosition(bone:Bone, point:Vector2):Vector2 {
		point.x = this.x * bone.a + this.y * bone.b + bone.worldX;
		point.y = this.x * bone.c + this.y * bone.d + bone.worldY;
		return point;
	}

	public function computeWorldRotation(bone:Bone):Float {
		var cos = MathUtils.cosDeg(this.rotation),
			sin = MathUtils.sinDeg(this.rotation);
		var x = cos * bone.a + sin * bone.b;
		var y = cos * bone.c + sin * bone.d;
		return Math.atan2(y, x) * MathUtils.radDeg;
	}

	override function copy():PointAttachment {
		var copy = new PointAttachment(name);
		copy.x = this.x;
		copy.y = this.y;
		copy.rotation = this.rotation;
		copy.color.setFromColor(this.color);
		return copy;
	}
}
