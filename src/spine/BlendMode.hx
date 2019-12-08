package spine;

/** Determines how images are blended with existing pixels when drawn. */
enum abstract BlendMode(Int) to Int {
	var Normal;
	var Additive;
	var Multiply;
	var Screen;
}
