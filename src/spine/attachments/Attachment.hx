package spine.attachments;

/** The base class for all attachments. */
/* abstract */ class Attachment {
	public var name:String;

	function new(name:String) {
		if (name == null)
			throw new Error("name cannot be null.");
		this.name = name;
	}

	public function copy():Attachment
		throw "abstract";
}
