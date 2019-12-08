package spine;

/** Stores the current pose values for an {@link Event}.
 *
 * See Timeline {@link Timeline#apply()},
 * AnimationStateListener {@link AnimationStateListener#event()}, and
 * [Events](http://esotericsoftware.com/spine-events) in the Spine User Guide. */
class Event {
	public var data:EventData;
	public var intValue:Int;
	public var floatValue:Float;
	public var stringValue:String;
	public var time:Float;
	public var volume:Float;
	public var balance:Float;

	public function new(time:Float, data:EventData) {
		if (data == null)
			throw new Error("data cannot be null.");
		this.time = time;
		this.data = data;
	}
}
