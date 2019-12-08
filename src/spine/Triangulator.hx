package spine;

import spine.utils.Pool;

class Triangulator {
	var convexPolygons = new Array<Array<Float>>();
	var convexPolygonsIndices = new Array<Array<Int>>();

	var indicesArray = new Array<Int>();
	var isConcaveArray = new Array<Bool>();
	var triangles = new Array<Int>();

	var polygonPool = new Pool<Array<Float>>(() -> new Array<Float>());
	var polygonIndicesPool = new Pool<Array<Int>>(() -> new Array<Int>());

	public function new() {}

	public function triangulate(verticesArray:Array<Float>):Array<Int> {
		var vertices = verticesArray;
		var vertexCount = verticesArray.length >> 1;

		var indices = this.indicesArray;
		indices.resize(0);
		for (i in 0...vertexCount)
			indices[i] = i;

		var isConcave = this.isConcaveArray;
		isConcave.resize(0);
		for (i in 0...vertexCount)
			isConcave[i] = Triangulator.isConcave(i, vertexCount, vertices, indices);

		var triangles = this.triangles;
		triangles.resize(0);

		while (vertexCount > 3) {
			// Find ear tip.
			var previous = vertexCount - 1, i = 0, next = 1;
			while (true) {
				var outerBreak = false;
				if (!isConcave[i]) {
					var p1 = indices[previous] << 1,
						p2 = indices[i] << 1,
						p3 = indices[next] << 1;
					var p1x = vertices[p1], p1y = vertices[p1 + 1];
					var p2x = vertices[p2], p2y = vertices[p2 + 1];
					var p3x = vertices[p3], p3y = vertices[p3 + 1];
					var ii = (next + 1) % vertexCount;
					while (ii != previous) {
						if (!isConcave[ii]) {
							ii = (ii + 1) % vertexCount;
							continue;
						}
						var v = indices[ii] << 1;
						var vx = vertices[v], vy = vertices[v + 1];
						if (Triangulator.positiveArea(p3x, p3y, p1x, p1y, vx, vy)) {
							if (Triangulator.positiveArea(p1x, p1y, p2x, p2y, vx, vy)) {
								if (Triangulator.positiveArea(p2x, p2y, p3x, p3y, vx, vy)) {
									outerBreak = true;
									break;
								}
							}
						}
						ii = (ii + 1) % vertexCount;
					}
					if (!outerBreak) {
						break;
					}
				}

				if (next == 0) {
					do {
						if (!isConcave[i])
							break;
						i--;
					} while (i > 0);
					break;
				}

				previous = i;
				i = next;
				next = (next + 1) % vertexCount;
			}

			// Cut ear tip.
			triangles.push(indices[(vertexCount + i - 1) % vertexCount]);
			triangles.push(indices[i]);
			triangles.push(indices[(i + 1) % vertexCount]);
			indices.splice(i, 1);
			isConcave.splice(i, 1);
			vertexCount--;

			var previousIndex = (vertexCount + i - 1) % vertexCount;
			var nextIndex = i == vertexCount ? 0 : i;
			isConcave[previousIndex] = Triangulator.isConcave(previousIndex, vertexCount, vertices, indices);
			isConcave[nextIndex] = Triangulator.isConcave(nextIndex, vertexCount, vertices, indices);
		}

		if (vertexCount == 3) {
			triangles.push(indices[2]);
			triangles.push(indices[0]);
			triangles.push(indices[1]);
		}

		return triangles;
	}

	public function decompose(verticesArray:Array<Float>, triangles:Array<Int>):Array<Array<Float>> {
		var vertices = verticesArray;
		var convexPolygons = this.convexPolygons;
		this.polygonPool.freeAll(convexPolygons);
		convexPolygons.resize(0);

		var convexPolygonsIndices = this.convexPolygonsIndices;
		this.polygonIndicesPool.freeAll(convexPolygonsIndices);
		convexPolygonsIndices.resize(0);

		var polygonIndices = this.polygonIndicesPool.obtain();
		polygonIndices.resize(0);

		var polygon = this.polygonPool.obtain();
		polygon.resize(0);

		// Merge subsequent triangles if they form a triangle fan.
		var fanBaseIndex = -1, lastWinding = 0;
		var i = 0, n = triangles.length;
		while (i < n) {
			var t1 = triangles[i] << 1,
				t2 = triangles[i + 1] << 1,
				t3 = triangles[i + 2] << 1;
			var x1 = vertices[t1], y1 = vertices[t1 + 1];
			var x2 = vertices[t2], y2 = vertices[t2 + 1];
			var x3 = vertices[t3], y3 = vertices[t3 + 1];

			// If the base of the last triangle is the same as this triangle, check if they form a convex polygon (triangle fan).
			var merged = false;
			if (fanBaseIndex == t1) {
				var o = polygon.length - 4;
				var winding1 = Triangulator.winding(polygon[o], polygon[o + 1], polygon[o + 2], polygon[o + 3], x3, y3);
				var winding2 = Triangulator.winding(x3, y3, polygon[0], polygon[1], polygon[2], polygon[3]);
				if (winding1 == lastWinding && winding2 == lastWinding) {
					polygon.push(x3);
					polygon.push(y3);
					polygonIndices.push(t3);
					merged = true;
				}
			}

			// Otherwise make this triangle the new base.
			if (!merged) {
				if (polygon.length > 0) {
					convexPolygons.push(polygon);
					convexPolygonsIndices.push(polygonIndices);
				} else {
					this.polygonPool.free(polygon);
					this.polygonIndicesPool.free(polygonIndices);
				}
				polygon = this.polygonPool.obtain();
				polygon.resize(0);
				polygon.push(x1);
				polygon.push(y1);
				polygon.push(x2);
				polygon.push(y2);
				polygon.push(x3);
				polygon.push(y3);
				polygonIndices = this.polygonIndicesPool.obtain();
				polygonIndices.resize(0);
				polygonIndices.push(t1);
				polygonIndices.push(t2);
				polygonIndices.push(t3);
				lastWinding = Triangulator.winding(x1, y1, x2, y2, x3, y3);
				fanBaseIndex = t1;
			}

			i += 3;
		}

		if (polygon.length > 0) {
			convexPolygons.push(polygon);
			convexPolygonsIndices.push(polygonIndices);
		}

		// Go through the list of polygons and try to merge the remaining triangles with the found triangle fans.
		var n = convexPolygons.length;
		for (i in 0...n) {
			polygonIndices = convexPolygonsIndices[i];
			if (polygonIndices.length == 0)
				continue;
			var firstIndex = polygonIndices[0];
			var lastIndex = polygonIndices[polygonIndices.length - 1];

			polygon = convexPolygons[i];
			var o = polygon.length - 4;
			var prevPrevX = polygon[o], prevPrevY = polygon[o + 1];
			var prevX = polygon[o + 2], prevY = polygon[o + 3];
			var firstX = polygon[0], firstY = polygon[1];
			var secondX = polygon[2], secondY = polygon[3];
			var winding = Triangulator.winding(prevPrevX, prevPrevY, prevX, prevY, firstX, firstY);

			var ii = 0;
			while (ii < n) {
				if (ii == i) {
					ii++;
					continue;
				}
				var otherIndices = convexPolygonsIndices[ii];
				if (otherIndices.length != 3) {
					ii++;
					continue;
				}
				var otherFirstIndex = otherIndices[0];
				var otherSecondIndex = otherIndices[1];
				var otherLastIndex = otherIndices[2];

				var otherPoly = convexPolygons[ii];
				var x3 = otherPoly[otherPoly.length - 2],
					y3 = otherPoly[otherPoly.length - 1];

				if (otherFirstIndex != firstIndex || otherSecondIndex != lastIndex)
					continue;
				var winding1 = Triangulator.winding(prevPrevX, prevPrevY, prevX, prevY, x3, y3);
				var winding2 = Triangulator.winding(x3, y3, firstX, firstY, secondX, secondY);
				if (winding1 == winding && winding2 == winding) {
					otherPoly.resize(0);
					otherIndices.resize(0);
					polygon.push(x3);
					polygon.push(y3);
					polygonIndices.push(otherLastIndex);
					prevPrevX = prevX;
					prevPrevY = prevY;
					prevX = x3;
					prevY = y3;
					ii = 0;
				}
				ii++;
			}
		}

		// Remove empty polygons that resulted from the merge step above.
		var i = convexPolygons.length - 1;
		while (i >= 0) {
			polygon = convexPolygons[i];
			if (polygon.length == 0) {
				convexPolygons.splice(i, 1);
				this.polygonPool.free(polygon);
				polygonIndices = convexPolygonsIndices[i];
				convexPolygonsIndices.splice(i, 1);
				this.polygonIndicesPool.free(polygonIndices);
			}
			i--;
		}

		return convexPolygons;
	}

	static function isConcave(index:Int, vertexCount:Int, vertices:Array<Float>, indices:Array<Int>):Bool {
		var previous = indices[(vertexCount + index - 1) % vertexCount] << 1;
		var current = indices[index] << 1;
		var next = indices[(index + 1) % vertexCount] << 1;
		return !positiveArea(vertices[previous], vertices[previous + 1], vertices[current], vertices[current + 1], vertices[next], vertices[next + 1]);
	}

	static function positiveArea(p1x:Float, p1y:Float, p2x:Float, p2y:Float, p3x:Float, p3y:Float):Bool {
		return p1x * (p3y - p2y) + p2x * (p1y - p3y) + p3x * (p2y - p1y) >= 0;
	}

	static function winding(p1x:Float, p1y:Float, p2x:Float, p2y:Float, p3x:Float, p3y:Float):Int {
		var px = p2x - p1x, py = p2y - p1y;
		return p3x * py - p3y * px + px * p1y - p1x * py >= 0 ? 1 : -1;
	}
}
