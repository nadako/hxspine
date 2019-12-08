package spine.vertexeffects;

import spine.utils.MathUtils;
import spine.utils.Interpolation.PowOut;
import spine.utils.Color;
import spine.utils.Vector2;

class SwirlEffect implements VertexEffect {
	public static var interpolation = new PowOut(2);

	public var centerX = 0.0;
	public var centerY = 0.0;
	public var radius = 0.0;
	public var angle = 0.0;

	var worldX = 0.0;
	var worldY = 0.0;

	public function new(radius:Float) {
		this.radius = radius;
	}

	public function begin(skeleton:Skeleton) {
		this.worldX = skeleton.x + this.centerX;
		this.worldY = skeleton.y + this.centerY;
	}

	public function transform(position:Vector2, uv:Vector2, light:Color, dark:Color) {
		var radAngle = this.angle * MathUtils.degreesToRadians;
		var x = position.x - this.worldX;
		var y = position.y - this.worldY;
		var dist = Math.sqrt(x * x + y * y);
		if (dist < this.radius) {
			var theta = SwirlEffect.interpolation.apply(0, radAngle, (this.radius - dist) / this.radius);
			var cos = Math.cos(theta);
			var sin = Math.sin(theta);
			position.x = cos * x - sin * y + this.worldX;
			position.y = sin * x + cos * y + this.worldY;
		}
	}

	public function end() {}
}
