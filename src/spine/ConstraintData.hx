package spine;

/** The base class for all constraint datas. */
/* abstract */ class ConstraintData {
	public var name:String;
	public var order:Int;
	public var skinRequired:Bool;

	function new(name:String, order:Int, skinRequired:Bool) {
		this.name = name;
		this.order = order;
		this.skinRequired = skinRequired;
	}
}
