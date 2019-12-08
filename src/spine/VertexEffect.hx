package spine;

import spine.utils.Color;
import spine.utils.Vector2;

interface VertexEffect {
	function begin(skeleton:Skeleton):Void;
	function transform(position:Vector2, uv:Vector2, light:Color, dark:Color):Void;
	function end():Void;
}
