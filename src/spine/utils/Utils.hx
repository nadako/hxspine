package spine.utils;

import haxe.io.Float32Array;
import spine.Animation.MixBlend;

class Utils {
	public static function newArray<T>(size:Int, defaultValue:T):Array<T> {
		return [for (i in 0...size) defaultValue];
	}

	public static function arrayCopy<T>(source:Array<T>, sourceStart:Int, dest:Array<T>, destStart:Int, numElements:Int) {
		var i = sourceStart, j = destStart;
		while (i < sourceStart + numElements) {
			dest[j++] = source[i++];
		}
	}

	public static inline function contains<T>(array:Array<T>, element:T):Bool {
		return array.indexOf(element) != -1;
	}

	public static inline function toFloatArray(array:Array<Float>):Array<Float> {
		// return new Float32Array(array);
		return array;
	}

	public static function newFloatArray(size:Int):Array<Float> {
		// TODO: return new Float32Array(size)
		return [for (i in 0...size) 0.0];
	}

	public static function setArraySize<T>(array:Array<T>, size:Int, value:T):Array<T> {
		var oldSize = array.length;
		if (oldSize == size)
			return array;
		array.resize(size);
		if (oldSize < size) {
			for (i in oldSize...size)
				array[i] = value;
		}
		return array;
	}

	public static function ensureArrayCapacity<T>(array:Array<T>, size:Int, value:Dynamic):Array<T> {
		if (array.length >= size)
			return array;
		return Utils.setArraySize(array, size, value);
	}

	// This function is used to fix WebKit 602 specific issue described at http://esotericsoftware.com/forum/iOS-10-disappearing-graphics-10109
	public static function webkit602BugfixHelper(alpha:Float, blend:MixBlend) {}

	static final _f32 = new Float32Array(1);

	public static function toSinglePrecision(value:Float):Float {
		_f32[0] = value;
		return _f32[0];
	}
}
