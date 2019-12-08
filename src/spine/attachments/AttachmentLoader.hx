package spine.attachments;

/** The interface which can be implemented to customize creating and populating attachments.
 *
 * See [Loading skeleton data](http://esotericsoftware.com/spine-loading-skeleton-data#AttachmentLoader) in the Spine
 * Runtimes Guide. */
interface AttachmentLoader {
	/** @return May be null to not load an attachment. */
	function newRegionAttachment(skin:Skin, name:String, path:String):RegionAttachment;

	/** @return May be null to not load an attachment. */
	function newMeshAttachment(skin:Skin, name:String, path:String):MeshAttachment;

	/** @return May be null to not load an attachment. */
	function newBoundingBoxAttachment(skin:Skin, name:String):BoundingBoxAttachment;

	/** @return May be null to not load an attachment */
	function newPathAttachment(skin:Skin, name:String):PathAttachment;

	/** @return May be null to not load an attachment */
	function newPointAttachment(skin:Skin, name:String):PointAttachment;

	/** @return May be null to not load an attachment */
	function newClippingAttachment(skin:Skin, name:String):ClippingAttachment;
}
