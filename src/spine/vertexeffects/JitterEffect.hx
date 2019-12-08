package spine.vertexeffects;

import spine.utils.MathUtils;
import spine.utils.Color;
import spine.utils.Vector2;

class JitterEffect implements VertexEffect {
	public var jitterX:Float;
	public var jitterY:Float;

	public function new(jitterX:Float, jitterY:Float) {
		this.jitterX = jitterX;
		this.jitterY = jitterY;
	}

	public function begin(skeleton:Skeleton) {}

	public function transform(position:Vector2, uv:Vector2, light:Color, dark:Color) {
		position.x += MathUtils.randomTriangular(-this.jitterX, this.jitterY);
		position.y += MathUtils.randomTriangular(-this.jitterX, this.jitterY);
	}

	public function end() {}
}
