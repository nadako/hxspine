package spine;

/** Stores the setup pose values for an {@link Event}.
 *
 * See [Events](http://esotericsoftware.com/spine-events) in the Spine User Guide. */
class EventData {
	public var name:String;
	public var intValue:Int;
	public var floatValue:Float;
	public var stringValue:String;
	public var audioPath:String;
	public var volume:Float;
	public var balance:Float;

	public function new(name:String) {
		this.name = name;
	}
}
