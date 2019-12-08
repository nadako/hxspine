package spine;

import spine.utils.Utils;
import spine.attachments.BoundingBoxAttachment;
import spine.utils.Pool;

/** Collects each visible {@link BoundingBoxAttachment} and computes the world vertices for its polygon. The polygon vertices are
 * provided along with convenience methods for doing hit detection. */
class SkeletonBounds {
	/** The left edge of the axis aligned bounding box. */
	public var minX = 0.0;

	/** The bottom edge of the axis aligned bounding box. */
	public var minY = 0.0;

	/** The right edge of the axis aligned bounding box. */
	public var maxX = 0.0;

	/** The top edge of the axis aligned bounding box. */
	public var maxY = 0.0;

	/** The visible bounding boxes. */
	public var boundingBoxes = new Array<BoundingBoxAttachment>();

	/** The world vertices for the bounding box polygons. */
	public var polygons = new Array<Array<Float>>();

	var polygonPool = new Pool<Array<Float>>(() -> Utils.newFloatArray(16));

	public function new() {}

	/** Clears any previous polygons, finds all visible bounding box attachments, and computes the world vertices for each bounding
	 * box's polygon.
	 * @param updateAabb If true, the axis aligned bounding box containing all the polygons is computed. If false, the
	 *           SkeletonBounds AABB methods will always return true. */
	public function update(skeleton:Skeleton, updateAabb:Bool) {
		if (skeleton == null)
			throw new Error("skeleton cannot be null.");
		var boundingBoxes = this.boundingBoxes;
		var polygons = this.polygons;
		var polygonPool = this.polygonPool;
		var slots = skeleton.slots;

		boundingBoxes.resize(0);
		polygonPool.freeAll(polygons);
		polygons.resize(0);

		for (slot in slots) {
			if (!slot.bone.active)
				continue;
			switch Std.downcast(slot.getAttachment(), BoundingBoxAttachment) {
				case null:
				case boundingBox:
					boundingBoxes.push(boundingBox);

					var polygon = polygonPool.obtain();
					if (polygon.length != boundingBox.worldVerticesLength) {
						polygon = Utils.newFloatArray(boundingBox.worldVerticesLength);
					}
					polygons.push(polygon);
					boundingBox.computeWorldVertices(slot, 0, boundingBox.worldVerticesLength, polygon, 0, 2);
			}
		}

		if (updateAabb) {
			this.aabbCompute();
		} else {
			this.minX = Math.POSITIVE_INFINITY;
			this.minY = Math.POSITIVE_INFINITY;
			this.maxX = Math.NEGATIVE_INFINITY;
			this.maxY = Math.NEGATIVE_INFINITY;
		}
	}

	public function aabbCompute() {
		var minX = Math.POSITIVE_INFINITY,
			minY = Math.POSITIVE_INFINITY,
			maxX = Math.NEGATIVE_INFINITY,
			maxY = Math.NEGATIVE_INFINITY;
		for (polygon in polygons) {
			var vertices = polygon;
			var ii = 0, nn = polygon.length;
			while (ii < nn) {
				var x = vertices[ii];
				var y = vertices[ii + 1];
				minX = Math.min(minX, x);
				minY = Math.min(minY, y);
				maxX = Math.max(maxX, x);
				maxY = Math.max(maxY, y);

				ii += 2;
			}
		}
		this.minX = minX;
		this.minY = minY;
		this.maxX = maxX;
		this.maxY = maxY;
	}

	/** Returns true if the axis aligned bounding box contains the point. */
	public function aabbContainsPoint(x:Float, y:Float):Bool {
		return x >= this.minX && x <= this.maxX && y >= this.minY && y <= this.maxY;
	}

	/** Returns true if the axis aligned bounding box intersects the line segment. */
	public function aabbIntersectsSegment(x1:Float, y1:Float, x2:Float, y2:Float):Bool {
		var minX = this.minX;
		var minY = this.minY;
		var maxX = this.maxX;
		var maxY = this.maxY;
		if ((x1 <= minX && x2 <= minX) || (y1 <= minY && y2 <= minY) || (x1 >= maxX && x2 >= maxX) || (y1 >= maxY && y2 >= maxY))
			return false;
		var m = (y2 - y1) / (x2 - x1);
		var y = m * (minX - x1) + y1;
		if (y > minY && y < maxY)
			return true;
		y = m * (maxX - x1) + y1;
		if (y > minY && y < maxY)
			return true;
		var x = (minY - y1) / m + x1;
		if (x > minX && x < maxX)
			return true;
		x = (maxY - y1) / m + x1;
		if (x > minX && x < maxX)
			return true;
		return false;
	}

	/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
	public function aabbIntersectsSkeleton(bounds:SkeletonBounds):Bool {
		return this.minX < bounds.maxX && this.maxX > bounds.minX && this.minY < bounds.maxY && this.maxY > bounds.minY;
	}

	/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
	 * efficient to only call this method if {@link #aabbContainsPoint(float, float)} returns true. */
	public function containsPoint(x:Float, y:Float):Null<BoundingBoxAttachment> {
		var polygons = this.polygons;
		for (i in 0...polygons.length)
			if (this.containsPointPolygon(polygons[i], x, y))
				return this.boundingBoxes[i];
		return null;
	}

	/** Returns true if the polygon contains the point. */
	public function containsPointPolygon(polygon:Array<Float>, x:Float, y:Float):Bool {
		var vertices = polygon;
		var nn = polygon.length;

		var prevIndex = nn - 2;
		var inside = false;
		var ii = 0;
		while (ii < nn) {
			var vertexY = vertices[ii + 1];
			var prevY = vertices[prevIndex + 1];
			if ((vertexY < y && prevY >= y) || (prevY < y && vertexY >= y)) {
				var vertexX = vertices[ii];
				if (vertexX + (y - vertexY) / (prevY - vertexY) * (vertices[prevIndex] - vertexX) < x)
					inside = !inside;
			}
			prevIndex = ii;
			ii += 2;
		}
		return inside;
	}

	/** Returns the first bounding box attachment that contains any part of the line segment, or null. When doing many checks, it
	 * is usually more efficient to only call this method if {@link #aabbIntersectsSegment()} returns
	 * true. */
	public function intersectsSegment(x1:Float, y1:Float, x2:Float, y2:Float):Null<BoundingBoxAttachment> {
		var polygons = this.polygons;
		for (i in 0...polygons.length)
			if (this.intersectsSegmentPolygon(polygons[i], x1, y1, x2, y2))
				return this.boundingBoxes[i];
		return null;
	}

	/** Returns true if the polygon contains any part of the line segment. */
	public function intersectsSegmentPolygon(polygon:Array<Float>, x1:Float, y1:Float, x2:Float, y2:Float):Bool {
		var vertices = polygon;
		var nn = polygon.length;

		var width12 = x1 - x2, height12 = y1 - y2;
		var det1 = x1 * y2 - y1 * x2;
		var x3 = vertices[nn - 2], y3 = vertices[nn - 1];
		var ii = 0;
		while (ii < nn) {
			var x4 = vertices[ii], y4 = vertices[ii + 1];
			var det2 = x3 * y4 - y3 * x4;
			var width34 = x3 - x4, height34 = y3 - y4;
			var det3 = width12 * height34 - height12 * width34;
			var x = (det1 * width34 - width12 * det2) / det3;
			if (((x >= x3 && x <= x4) || (x >= x4 && x <= x3)) && ((x >= x1 && x <= x2) || (x >= x2 && x <= x1))) {
				var y = (det1 * height34 - height12 * det2) / det3;
				if (((y >= y3 && y <= y4) || (y >= y4 && y <= y3)) && ((y >= y1 && y <= y2) || (y >= y2 && y <= y1)))
					return true;
			}
			x3 = x4;
			y3 = y4;

			ii += 2;
		}
		return false;
	}

	/** Returns the polygon for the specified bounding box, or null. */
	public function getPolygon(boundingBox:BoundingBoxAttachment):Null<Array<Float>> {
		if (boundingBox == null)
			throw new Error("boundingBox cannot be null.");
		var index = this.boundingBoxes.indexOf(boundingBox);
		return index == -1 ? null : this.polygons[index];
	}

	/** The width of the axis aligned bounding box. */
	public function getWidth():Float {
		return this.maxX - this.minX;
	}

	/** The height of the axis aligned bounding box. */
	public function getHeight():Float {
		return this.maxY - this.minY;
	}
}
