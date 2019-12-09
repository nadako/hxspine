package spine;

import spine.attachments.ClippingAttachment;
import spine.attachments.PointAttachment;
import spine.attachments.PathAttachment;
import spine.attachments.BoundingBoxAttachment;
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;
import spine.attachments.AttachmentLoader;

/** An `AttachmentLoader` that configures attachments using texture regions from an `TextureAtlas`.
 *
 * See [Loading skeleton data](http://esotericsoftware.com/spine-loading-skeleton-data#JSON-and-binary-data) in the
 * Spine Runtimes Guide. */
class AtlasAttachmentLoader implements AttachmentLoader {
	final atlas:TextureAtlas;

	public function new(atlas:TextureAtlas) {
		this.atlas = atlas;
	}

	public function newRegionAttachment(skin:Skin, name:String, path:String):RegionAttachment {
		var region = this.atlas.findRegion(path);
		if (region == null)
			throw new Error("Region not found in atlas: " + path + " (region attachment: " + name + ")");
		var attachment = new RegionAttachment(name);
		attachment.setRegion(region);
		return attachment;
	}

	public function newMeshAttachment(skin:Skin, name:String, path:String):MeshAttachment {
		var region = this.atlas.findRegion(path);
		if (region == null)
			throw new Error("Region not found in atlas: " + path + " (mesh attachment: " + name + ")");
		var attachment = new MeshAttachment(name);
		attachment.region = region;
		return attachment;
	}

	public function newBoundingBoxAttachment(skin:Skin, name:String):BoundingBoxAttachment {
		return new BoundingBoxAttachment(name);
	}

	public function newPathAttachment(skin:Skin, name:String):PathAttachment {
		return new PathAttachment(name);
	}

	public function newPointAttachment(skin:Skin, name:String):PointAttachment {
		return new PointAttachment(name);
	}

	public function newClippingAttachment(skin:Skin, name:String):ClippingAttachment {
		return new ClippingAttachment(name);
	}
}
