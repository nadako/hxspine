package spine;

import spine.utils.Color;
import spine.utils.Utils;
import spine.attachments.ClippingAttachment;

class SkeletonClipping {
	var triangulator = new Triangulator();
	var clippingPolygon = new Array<Float>();
	var clipOutput = new Array<Float>();

	public var clippedVertices = new Array<Float>();
	public var clippedTriangles = new Array<Float>();

	var scratch = new Array<Float>();

	var clipAttachment:ClippingAttachment;
	var clippingPolygons:Array<Array<Float>>;

	public function new() {
	}

	public function clipStart(slot:Slot, clip:ClippingAttachment):Int {
		if (this.clipAttachment != null)
			return 0;
		this.clipAttachment = clip;

		var n = clip.worldVerticesLength;
		var vertices = Utils.setArraySize(this.clippingPolygon, n, 0.0);
		clip.computeWorldVertices(slot, 0, n, vertices, 0, 2);
		var clippingPolygon = this.clippingPolygon;
		SkeletonClipping.makeClockwise(clippingPolygon);
		var clippingPolygons = this.clippingPolygons = this.triangulator.decompose(clippingPolygon, this.triangulator.triangulate(clippingPolygon));
		for (polygon in clippingPolygons) {
			SkeletonClipping.makeClockwise(polygon);
			polygon.push(polygon[0]);
			polygon.push(polygon[1]);
		}

		return clippingPolygons.length;
	}

	public function clipEndWithSlot(slot:Slot) {
		if (this.clipAttachment != null && this.clipAttachment.endSlot == slot.data)
			this.clipEnd();
	}

	public function clipEnd() {
		if (this.clipAttachment == null)
			return;
		this.clipAttachment = null;
		this.clippingPolygons = null;
		this.clippedVertices.resize(0);
		this.clippedTriangles.resize(0);
		this.clippingPolygon.resize(0);
	}

	public function isClipping():Bool {
		return this.clipAttachment != null;
	}

	public function clipTriangles(vertices:Array<Float>, verticesLength:Int, triangles:Array<Int>, trianglesLength:Int, uvs:Array<Float>, light:Color,
			dark:Color, twoColor:Bool) {
		var clipOutput = this.clipOutput,
			clippedVertices = this.clippedVertices;
		var clippedTriangles = this.clippedTriangles;
		var polygons = this.clippingPolygons;
		var polygonsCount = this.clippingPolygons.length;
		var vertexSize = twoColor ? 12 : 8;

		var index = 0;
		clippedVertices.resize(0);
		clippedTriangles.resize(0);
		var i = 0;
		while (i < trianglesLength) {
			var vertexOffset = triangles[i] << 1;
			var x1 = vertices[vertexOffset], y1 = vertices[vertexOffset + 1];
			var u1 = uvs[vertexOffset], v1 = uvs[vertexOffset + 1];

			vertexOffset = triangles[i + 1] << 1;
			var x2 = vertices[vertexOffset], y2 = vertices[vertexOffset + 1];
			var u2 = uvs[vertexOffset], v2 = uvs[vertexOffset + 1];

			vertexOffset = triangles[i + 2] << 1;
			var x3 = vertices[vertexOffset], y3 = vertices[vertexOffset + 1];
			var u3 = uvs[vertexOffset], v3 = uvs[vertexOffset + 1];

			for (p in 0...polygonsCount) {
				var s = clippedVertices.length;
				if (this.clip(x1, y1, x2, y2, x3, y3, polygons[p], clipOutput)) {
					var clipOutputLength = clipOutput.length;
					if (clipOutputLength == 0)
						continue;
					var d0 = y2 - y3, d1 = x3 - x2, d2 = x1 - x3, d4 = y3 - y1;
					var d = 1 / (d0 * d2 + d1 * (y1 - y3));

					var clipOutputCount = clipOutputLength >> 1;
					var clipOutputItems = this.clipOutput;
					var clippedVerticesItems = Utils.setArraySize(clippedVertices, s + clipOutputCount * vertexSize, 0.0);
					var ii = 0;
					while (ii < clipOutputLength) {
						var x = clipOutputItems[ii],
							y = clipOutputItems[ii + 1];
						clippedVerticesItems[s] = x;
						clippedVerticesItems[s + 1] = y;
						clippedVerticesItems[s + 2] = light.r;
						clippedVerticesItems[s + 3] = light.g;
						clippedVerticesItems[s + 4] = light.b;
						clippedVerticesItems[s + 5] = light.a;
						var c0 = x - x3, c1 = y - y3;
						var a = (d0 * c0 + d1 * c1) * d;
						var b = (d4 * c0 + d2 * c1) * d;
						var c = 1 - a - b;
						clippedVerticesItems[s + 6] = u1 * a + u2 * b + u3 * c;
						clippedVerticesItems[s + 7] = v1 * a + v2 * b + v3 * c;
						if (twoColor) {
							clippedVerticesItems[s + 8] = dark.r;
							clippedVerticesItems[s + 9] = dark.g;
							clippedVerticesItems[s + 10] = dark.b;
							clippedVerticesItems[s + 11] = dark.a;
						}
						s += vertexSize;
						ii += 2;
					}

					s = clippedTriangles.length;
					var clippedTrianglesItems = Utils.setArraySize(clippedTriangles, s + 3 * (clipOutputCount - 2), 0);
					clipOutputCount--;
					for (ii in 1...clipOutputCount) {
						clippedTrianglesItems[s] = index;
						clippedTrianglesItems[s + 1] = (index + ii);
						clippedTrianglesItems[s + 2] = (index + ii + 1);
						s += 3;
					}
					index += clipOutputCount + 1;
				} else {
					var clippedVerticesItems = Utils.setArraySize(clippedVertices, s + 3 * vertexSize, 0.0);
					clippedVerticesItems[s] = x1;
					clippedVerticesItems[s + 1] = y1;
					clippedVerticesItems[s + 2] = light.r;
					clippedVerticesItems[s + 3] = light.g;
					clippedVerticesItems[s + 4] = light.b;
					clippedVerticesItems[s + 5] = light.a;
					if (!twoColor) {
						clippedVerticesItems[s + 6] = u1;
						clippedVerticesItems[s + 7] = v1;

						clippedVerticesItems[s + 8] = x2;
						clippedVerticesItems[s + 9] = y2;
						clippedVerticesItems[s + 10] = light.r;
						clippedVerticesItems[s + 11] = light.g;
						clippedVerticesItems[s + 12] = light.b;
						clippedVerticesItems[s + 13] = light.a;
						clippedVerticesItems[s + 14] = u2;
						clippedVerticesItems[s + 15] = v2;

						clippedVerticesItems[s + 16] = x3;
						clippedVerticesItems[s + 17] = y3;
						clippedVerticesItems[s + 18] = light.r;
						clippedVerticesItems[s + 19] = light.g;
						clippedVerticesItems[s + 20] = light.b;
						clippedVerticesItems[s + 21] = light.a;
						clippedVerticesItems[s + 22] = u3;
						clippedVerticesItems[s + 23] = v3;
					} else {
						clippedVerticesItems[s + 6] = u1;
						clippedVerticesItems[s + 7] = v1;
						clippedVerticesItems[s + 8] = dark.r;
						clippedVerticesItems[s + 9] = dark.g;
						clippedVerticesItems[s + 10] = dark.b;
						clippedVerticesItems[s + 11] = dark.a;

						clippedVerticesItems[s + 12] = x2;
						clippedVerticesItems[s + 13] = y2;
						clippedVerticesItems[s + 14] = light.r;
						clippedVerticesItems[s + 15] = light.g;
						clippedVerticesItems[s + 16] = light.b;
						clippedVerticesItems[s + 17] = light.a;
						clippedVerticesItems[s + 18] = u2;
						clippedVerticesItems[s + 19] = v2;
						clippedVerticesItems[s + 20] = dark.r;
						clippedVerticesItems[s + 21] = dark.g;
						clippedVerticesItems[s + 22] = dark.b;
						clippedVerticesItems[s + 23] = dark.a;

						clippedVerticesItems[s + 24] = x3;
						clippedVerticesItems[s + 25] = y3;
						clippedVerticesItems[s + 26] = light.r;
						clippedVerticesItems[s + 27] = light.g;
						clippedVerticesItems[s + 28] = light.b;
						clippedVerticesItems[s + 29] = light.a;
						clippedVerticesItems[s + 30] = u3;
						clippedVerticesItems[s + 31] = v3;
						clippedVerticesItems[s + 32] = dark.r;
						clippedVerticesItems[s + 33] = dark.g;
						clippedVerticesItems[s + 34] = dark.b;
						clippedVerticesItems[s + 35] = dark.a;
					}

					s = clippedTriangles.length;
					var clippedTrianglesItems = Utils.setArraySize(clippedTriangles, s + 3, 0);
					clippedTrianglesItems[s] = index;
					clippedTrianglesItems[s + 1] = (index + 1);
					clippedTrianglesItems[s + 2] = (index + 2);
					index += 3;
					break;
				}
			}
			i += 3;
		}
	}

	/** Clips the input triangle against the convex, clockwise clipping area. If the triangle lies entirely within the clipping
	 * area, false is returned. The clipping area must duplicate the first vertex at the end of the vertices list. */
	public function clip(x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float, clippingArea:Array<Float>, output:Array<Float>) {
		var originalOutput = output;
		var clipped = false;

		// Avoid copy at the end.
		var input:Array<Float>;
		if (clippingArea.length % 4 >= 2) {
			input = output;
			output = this.scratch;
		} else
			input = this.scratch;

		input.resize(0);
		input.push(x1);
		input.push(y1);
		input.push(x2);
		input.push(y2);
		input.push(x3);
		input.push(y3);
		input.push(x1);
		input.push(y1);
		output.resize(0);

		var clippingVertices = clippingArea;
		var clippingVerticesLast = clippingArea.length - 4;
		var i = 0;
		while (true) {
			var edgeX = clippingVertices[i], edgeY = clippingVertices[i + 1];
			var edgeX2 = clippingVertices[i + 2],
				edgeY2 = clippingVertices[i + 3];
			var deltaX = edgeX - edgeX2, deltaY = edgeY - edgeY2;

			var inputVertices = input;
			var inputVerticesLength = input.length - 2,
				outputStart = output.length;
			var ii = 0;
			while (ii < inputVerticesLength) {
				var inputX = inputVertices[ii], inputY = inputVertices[ii + 1];
				var inputX2 = inputVertices[ii + 2],
					inputY2 = inputVertices[ii + 3];
				var side2 = deltaX * (inputY2 - edgeY2) - deltaY * (inputX2 - edgeX2) > 0;
				if (deltaX * (inputY - edgeY2) - deltaY * (inputX - edgeX2) > 0) {
					if (side2) { // v1 inside, v2 inside
						output.push(inputX2);
						output.push(inputY2);
						ii += 2;
						continue;
					}
					// v1 inside, v2 outside
					var c0 = inputY2 - inputY, c2 = inputX2 - inputX;
					var s = c0 * (edgeX2 - edgeX) - c2 * (edgeY2 - edgeY);
					if (Math.abs(s) > 0.000001) {
						var ua = (c2 * (edgeY - inputY) - c0 * (edgeX - inputX)) / s;
						output.push(edgeX + (edgeX2 - edgeX) * ua);
						output.push(edgeY + (edgeY2 - edgeY) * ua);
					} else {
						output.push(edgeX);
						output.push(edgeY);
					}
				} else if (side2) { // v1 outside, v2 inside
					var c0 = inputY2 - inputY, c2 = inputX2 - inputX;
					var s = c0 * (edgeX2 - edgeX) - c2 * (edgeY2 - edgeY);
					if (Math.abs(s) > 0.000001) {
						var ua = (c2 * (edgeY - inputY) - c0 * (edgeX - inputX)) / s;
						output.push(edgeX + (edgeX2 - edgeX) * ua);
						output.push(edgeY + (edgeY2 - edgeY) * ua);
					} else {
						output.push(edgeX);
						output.push(edgeY);
					}
					output.push(inputX2);
					output.push(inputY2);
				}
				clipped = true;
				ii += 2;
			}

			if (outputStart == output.length) { // All edges outside.
				originalOutput.resize(0);
				return true;
			}

			output.push(output[0]);
			output.push(output[1]);

			if (i == clippingVerticesLast)
				break;
			var temp = output;
			output = input;
			output.resize(0);
			input = temp;

			i += 2;
		}

		if (originalOutput != output) {
			originalOutput.resize(0);
			for (i in 0...output.length - 2)
				originalOutput[i] = output[i];
		} else
			originalOutput.resize(originalOutput.length - 2);

		return clipped;
	}

	public static function makeClockwise(polygon:Array<Float>) {
		var vertices = polygon;
		var verticeslength = polygon.length;

		var area = vertices[verticeslength - 2] * vertices[1] - vertices[0] * vertices[verticeslength - 1],
			p1x = 0.0,
			p1y = 0.0,
			p2x = 0.0,
			p2y = 0.0;
		var i = 0, n = verticeslength - 3;
		while (i < n) {
			p1x = vertices[i];
			p1y = vertices[i + 1];
			p2x = vertices[i + 2];
			p2y = vertices[i + 3];
			area += p1x * p2y - p2x * p1y;
			i += 2;
		}
		if (area < 0)
			return;

		var i = 0, lastX = verticeslength - 2, n = verticeslength >> 1;
		while (i < n) {
			var x = vertices[i], y = vertices[i + 1];
			var other = lastX - i;
			vertices[i] = vertices[other];
			vertices[i + 1] = vertices[other + 1];
			vertices[other] = x;
			vertices[other + 1] = y;
			i += 2;
		}
	}
}
