package spine;

import spine.Texture;
import spine.utils.Disposable;

using StringTools;

class TextureAtlas implements Disposable {
	public var pages = new Array<TextureAtlasPage>();
	public var regions = new Array<TextureAtlasRegion>();

	public function new(atlasText:String, textureLoader:(path:String) -> Texture) {
		this.load(atlasText, textureLoader);
	}

	function load(atlasText:String, textureLoader:(path:String) -> Texture) {
		if (textureLoader == null)
			throw new Error("textureLoader cannot be null.");

		var reader = new TextureAtlasReader(atlasText);
		var tuple:Array<String> = [null, null, null, null];
		var page:TextureAtlasPage = null;
		while (true) {
			var line = reader.readLine();
			if (line == null)
				break;
			line = line.trim();
			if (line.length == 0)
				page = null;
			else if (page == null) {
				page = new TextureAtlasPage();
				page.name = line;

				if (reader.readTuple(tuple) == 2) { // size is only optional for an atlas packed with an old TexturePacker.
					page.width = Std.parseInt(tuple[0]);
					page.height = Std.parseInt(tuple[1]);
					reader.readTuple(tuple);
				}
				// page.format = Format[tuple[0]]; we don't need format in WebGL

				reader.readTuple(tuple);
				page.minFilter = TextureFilter.fromString(tuple[0]);
				page.magFilter = TextureFilter.fromString(tuple[1]);

				var direction = reader.readValue();
				page.uWrap = TextureWrap.ClampToEdge;
				page.vWrap = TextureWrap.ClampToEdge;
				if (direction == "x")
					page.uWrap = TextureWrap.Repeat;
				else if (direction == "y")
					page.vWrap = TextureWrap.Repeat;
				else if (direction == "xy")
					page.uWrap = page.vWrap = TextureWrap.Repeat;

				page.texture = textureLoader(line);
				page.texture.setFilters(page.minFilter, page.magFilter);
				page.texture.setWraps(page.uWrap, page.vWrap);
				page.width = page.texture.getWidth();
				page.height = page.texture.getHeight();
				this.pages.push(page);
			} else {
				var region = new TextureAtlasRegion();
				region.name = line;
				region.page = page;

				var rotateValue = reader.readValue();
				if (rotateValue.toLowerCase() == "true") {
					region.degrees = 90;
				} else if (rotateValue.toLowerCase() == "false") {
					region.degrees = 0;
				} else {
					region.degrees = Std.parseFloat(rotateValue);
				}
				region.rotate = region.degrees == 90;

				reader.readTuple(tuple);
				var x = Std.parseInt(tuple[0]);
				var y = Std.parseInt(tuple[1]);

				reader.readTuple(tuple);
				var width = Std.parseInt(tuple[0]);
				var height = Std.parseInt(tuple[1]);

				region.u = x / page.width;
				region.v = y / page.height;
				if (region.rotate) {
					region.u2 = (x + height) / page.width;
					region.v2 = (y + width) / page.height;
				} else {
					region.u2 = (x + width) / page.width;
					region.v2 = (y + height) / page.height;
				}
				region.x = x;
				region.y = y;
				region.width = Std.int(Math.abs(width));
				region.height = Std.int(Math.abs(height));

				if (reader.readTuple(tuple) == 4) { // split is optional
					// region.splits = new Vector.<int>(parseInt(tuple[0]), parseInt(tuple[1]), parseInt(tuple[2]), parseInt(tuple[3]));
					if (reader.readTuple(tuple) == 4) { // pad is optional, but only present with splits
						// region.pads = Vector.<int>(parseInt(tuple[0]), parseInt(tuple[1]), parseInt(tuple[2]), parseInt(tuple[3]));
						reader.readTuple(tuple);
					}
				}

				region.originalWidth = Std.parseInt(tuple[0]);
				region.originalHeight = Std.parseInt(tuple[1]);

				reader.readTuple(tuple);
				region.offsetX = Std.parseInt(tuple[0]);
				region.offsetY = Std.parseInt(tuple[1]);

				region.index = Std.parseInt(reader.readValue());

				region.texture = page.texture;
				this.regions.push(region);
			}
		}
	}

	public function findRegion(name:String):TextureAtlasRegion {
		for (region in regions) {
			if (region.name == name) {
				return region;
			}
		}
		return null;
	}

	public function dispose() {
		for (page in pages) {
			page.texture.dispose();
		}
	}
}

class TextureAtlasReader {
	public var lines:Array<String>;
	public var index:Int = 0;

	public function new(text:String) {
		this.lines = ~/\r\n|\r|\n/g.split(text);
	}

	public function readLine():String {
		if (this.index >= this.lines.length)
			return null;
		return this.lines[this.index++];
	}

	public function readValue():String {
		var line = this.readLine();
		var colon = line.indexOf(":");
		if (colon == -1)
			throw new Error("Invalid line: " + line);
		return line.substring(colon + 1).trim();
	}

	public function readTuple(tuple:Array<String>):Int {
		var line = this.readLine();
		var colon = line.indexOf(":");
		if (colon == -1)
			throw new Error("Invalid line: " + line);
		var i = 0, lastMatch = colon + 1;
		while (i < 3) {
			var comma = line.indexOf(",", lastMatch);
			if (comma == -1)
				break;
			tuple[i] = line.substr(lastMatch, comma - lastMatch).trim();
			lastMatch = comma + 1;
			i++;
		}
		tuple[i] = line.substring(lastMatch).trim();
		return i + 1;
	}
}

class TextureAtlasPage {
	public var name:String;
	public var minFilter:TextureFilter;
	public var magFilter:TextureFilter;
	public var uWrap:TextureWrap;
	public var vWrap:TextureWrap;
	public var texture:Texture;
	public var width:Int;
	public var height:Int;

	public function new() {}
}

class TextureAtlasRegion extends TextureRegion {
	public var page:TextureAtlasPage;
	public var name:String;
	public var x:Int;
	public var y:Int;
	public var index:Int;
	public var degrees:Float;
	public var texture:Texture;

	public function new() {}
}
