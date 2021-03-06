package spine;

import spine.Animation;
import spine.utils.MathUtils;
import spine.utils.Utils;
import spine.utils.Pool;
import spine.utils.IntSet;

/** Applies animations over time, queues animations for later playback, mixes (crossfading) between animations, and applies
 * multiple animations on top of each other (layering).
 *
 * See [Applying Animations](http://esotericsoftware.com/spine-applying-animations/) in the Spine Runtimes Guide. */
@:access(spine.TrackEntry)
class AnimationState {
	static final emptyAnimation = new Animation("<empty>", [], 0);

	/** 1. A previously applied timeline has set this property.
	 *
	 * Result: Mix from the current pose to the timeline pose. */
	static inline final SUBSEQUENT = 0;

	/** 1. This is the first timeline to set this property.
	 * 2. The next track entry applied after this one does not have a timeline to set this property.
	 *
	 * Result: Mix from the setup pose to the timeline pose. */
	static inline final FIRST = 1;

	/** 1) A previously applied timeline has set this property.<br>
	 * 2) The next track entry to be applied does have a timeline to set this property.<br>
	 * 3) The next track entry after that one does not have a timeline to set this property.<br>
	 * Result: Mix from the current pose to the timeline pose, but do not mix out. This avoids "dipping" when crossfading
	 * animations that key the same property. A subsequent timeline will set this property using a mix. */
	static inline final HOLD_SUBSEQUENT = 2;

	/** 1) This is the first timeline to set this property.<br>
	 * 2) The next track entry to be applied does have a timeline to set this property.<br>
	 * 3) The next track entry after that one does not have a timeline to set this property.<br>
	 * Result: Mix from the setup pose to the timeline pose, but do not mix out. This avoids "dipping" when crossfading animations
	 * that key the same property. A subsequent timeline will set this property using a mix. */
	static inline final HOLD_FIRST = 3;

	/** 1. This is the first timeline to set this property.
	 * 2. The next track entry to be applied does have a timeline to set this property.
	 * 3. The next track entry after that one does have a timeline to set this property.
	 * 4. timelineHoldMix stores the first subsequent track entry that does not have a timeline to set this property.
	 *
	 * Result: The same as HOLD except the mix percentage from the timelineHoldMix track entry is used. This handles when more than
	 * 2 track entries in a row have a timeline that sets the same property.
	 *
	 * Eg, A -> B -> C -> D where A, B, and C have a timeline setting same property, but D does not. When A is applied, to avoid
	 * "dipping" A is not mixed out, however D (the first entry that doesn't set the property) mixing in is used to mix out A
	 * (which affects B and C). Without using D to mix out, A would be applied fully until mixing completes, then snap into
	 * place. */
	static inline final HOLD_MIX = 4;

	static inline final SETUP = 1;
	static inline final CURRENT = 2;

	/** The AnimationStateData to look up mix durations. */
	public var data:AnimationStateData;

	/** The list of tracks that currently have animations, which may contain null entries. */
	public final tracks = new Array<Null<TrackEntry>>();

	/** Multiplier for the delta time when the animation state is updated, causing time for all animations and mixes to play slower
	 * or faster. Defaults to 1.
	 *
	 * See TrackEntry `TrackEntry.timeScale` for affecting a single animation. */
	public var timeScale = 1.0;
	var unkeyedState = 0;

	final events = new Array<Event>();
	final listeners = new Array<AnimationStateListener>();
	final queue:EventQueue;
	final propertyIDs = new IntSet();
	final trackEntryPool = new Pool(TrackEntry.new, e -> e.reset());
	var animationsChanged = false;

	public function new(data:AnimationStateData) {
		this.data = data;
		this.queue = new EventQueue(this);
	}

	/** Increments each track entry `TrackEntry.trackTime`, setting queued animations as current if needed. */
	public function update(delta:Float) {
		delta *= this.timeScale;
		var tracks = this.tracks;
		for (i in 0...tracks.length) {
			var current = tracks[i];
			if (current == null)
				continue;

			current.animationLast = current.nextAnimationLast;
			current.trackLast = current.nextTrackLast;

			var currentDelta = delta * current.timeScale;

			if (current.delay > 0) {
				current.delay -= currentDelta;
				if (current.delay > 0)
					continue;
				currentDelta = -current.delay;
				current.delay = 0;
			}

			var next = current.next;
			if (next != null) {
				// When the next entry's delay is passed, change to the next entry, preserving leftover time.
				var nextTime = current.trackLast - next.delay;
				if (nextTime >= 0) {
					next.delay = 0;
					next.trackTime += current.timeScale == 0 ? 0 : (nextTime / current.timeScale + delta) * next.timeScale;
					current.trackTime += currentDelta;
					this.setCurrent(i, next, true);
					while (next.mixingFrom != null) {
						next.mixTime += delta;
						next = next.mixingFrom;
					}
					continue;
				}
			} else if (current.trackLast >= current.trackEnd && current.mixingFrom == null) {
				tracks[i] = null;
				this.queue.end(current);
				this.disposeNext(current);
				continue;
			}
			if (current.mixingFrom != null && this.updateMixingFrom(current, delta)) {
				// End mixing from entries once all have completed.
				var from = current.mixingFrom;
				current.mixingFrom = null;
				if (from != null)
					from.mixingTo = null;
				while (from != null) {
					this.queue.end(from);
					from = from.mixingFrom;
				}
			}

			current.trackTime += currentDelta;
		}

		this.queue.drain();
	}

	/** Returns true when all mixing from entries are complete. */
	function updateMixingFrom(to:TrackEntry, delta:Float):Bool {
		var from = to.mixingFrom;
		if (from == null)
			return true;

		var finished = this.updateMixingFrom(from, delta);

		from.animationLast = from.nextAnimationLast;
		from.trackLast = from.nextTrackLast;

		// Require mixTime > 0 to ensure the mixing from entry was applied at least once.
		if (to.mixTime > 0 && to.mixTime >= to.mixDuration) {
			// Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame).
			if (from.totalAlpha == 0 || to.mixDuration == 0) {
				to.mixingFrom = from.mixingFrom;
				if (from.mixingFrom != null)
					from.mixingFrom.mixingTo = to;
				to.interruptAlpha = from.interruptAlpha;
				this.queue.end(from);
			}
			return finished;
		}

		from.trackTime += delta * from.timeScale;
		to.mixTime += delta;
		return false;
	}

	/** Poses the skeleton using the track entry animations. There are no side effects other than invoking listeners, so the
	 * animation state can be applied to multiple skeletons to pose them identically.
	 * @returns True if any animations were applied. */
	public function apply(skeleton:Skeleton):Bool {
		if (skeleton == null)
			throw new Error("skeleton cannot be null.");
		if (this.animationsChanged)
			this._animationsChanged();

		var events = this.events;
		var tracks = this.tracks;
		var applied = false;

		for (i in 0...tracks.length) {
			var current = tracks[i];
			if (current == null || current.delay > 0)
				continue;
			applied = true;
			var blend = i == 0 ? MixBlend.first : current.mixBlend;

			// Apply mixing from entries first.
			var mix = current.alpha;
			if (current.mixingFrom != null)
				mix *= this.applyMixingFrom(current, skeleton, blend);
			else if (current.trackTime >= current.trackEnd && current.next == null)
				mix = 0;

			// Apply current entry.
			var animationLast = current.animationLast,
				animationTime = current.getAnimationTime();
			var timelineCount = current.animation.timelines.length;
			var timelines = current.animation.timelines;
			if ((i == 0 && mix == 1) || blend == MixBlend.add) {
				for (ii in 0...timelineCount) {
					// Fixes issue #302 on IOS9 where mix, blend sometimes became undefined and caused assets
					// to sometimes stop rendering when using color correction, as their RGBA values become NaN.
					// (https://github.com/pixijs/pixi-spine/issues/302)
					Utils.webkit602BugfixHelper(mix, blend);
					var timeline = timelines[ii];
					if (Std.is(timeline, AttachmentTimeline))
						applyAttachmentTimeline(cast timeline, skeleton, animationTime, blend, true);
					else
						timeline.apply(skeleton, animationLast, animationTime, events, mix, blend, MixDirection.mixIn);
				}
			} else {
				var timelineMode = current.timelineMode;

				var firstFrame = current.timelinesRotation.length == 0;
				if (firstFrame)
					Utils.setArraySize(current.timelinesRotation, timelineCount << 1, 0.0);
				var timelinesRotation = current.timelinesRotation;

				for (ii in 0...timelineCount) {
					var timeline = timelines[ii];
					var timelineBlend = timelineMode[ii] == AnimationState.SUBSEQUENT ? blend : MixBlend.setup;
					if (Std.is(timeline, RotateTimeline)) {
						applyRotateTimeline(timeline, skeleton, animationTime, mix, timelineBlend, timelinesRotation, ii << 1, firstFrame);
					} else if (Std.is(timeline, AttachmentTimeline)) {
						applyAttachmentTimeline(cast timeline, skeleton, animationTime, blend, true);
					} else {
						// This fixes the WebKit 602 specific issue described at http://esotericsoftware.com/forum/iOS-10-disappearing-graphics-10109
						Utils.webkit602BugfixHelper(mix, blend);
						timeline.apply(skeleton, animationLast, animationTime, events, mix, timelineBlend, MixDirection.mixIn);
					}
				}
			}
			this.queueEvents(current, animationTime);
			events.resize(0);
			current.nextAnimationLast = animationTime;
			current.nextTrackLast = current.trackTime;
		}

		// Set slots attachments to the setup pose, if needed. This occurs if an animation that is mixing out sets attachments so
		// subsequent timelines see any deform, but the subsequent timelines don't set an attachment (eg they are also mixing out or
		// the time is before the first key).
		var setupState = this.unkeyedState + AnimationState.SETUP;
		var slots = skeleton.slots;
		for (i in 0...skeleton.slots.length) {
			var slot = slots[i];
			if (slot.attachmentState == setupState) {
				var attachmentName = slot.data.attachmentName;
				slot.setAttachment(attachmentName == null ? null : skeleton.getAttachment(slot.data.index, attachmentName));
			}
		}
		this.unkeyedState += 2; // Increasing after each use avoids the need to reset attachmentState for every slot.

		this.queue.drain();
		return applied;
	}

	function applyMixingFrom(to:TrackEntry, skeleton:Skeleton, blend:MixBlend):Float {
		var from = to.mixingFrom;
		if (from.mixingFrom != null)
			this.applyMixingFrom(from, skeleton, blend);

		var mix = 0.0;
		if (to.mixDuration == 0) { // Single frame mix to undo mixingFrom changes.
			mix = 1;
			if (blend == MixBlend.first)
				blend = MixBlend.setup;
		} else {
			mix = to.mixTime / to.mixDuration;
			if (mix > 1)
				mix = 1;
			if (blend != MixBlend.first)
				blend = from.mixBlend;
		}

		var events = mix < from.eventThreshold ? this.events : null;
		var attachments = mix < from.attachmentThreshold,
			drawOrder = mix < from.drawOrderThreshold;
		var animationLast = from.animationLast,
			animationTime = from.getAnimationTime();
		var timelineCount = from.animation.timelines.length;
		var timelines = from.animation.timelines;
		var alphaHold = from.alpha * to.interruptAlpha,
			alphaMix = alphaHold * (1 - mix);
		if (blend == MixBlend.add) {
			for (i in 0...timelineCount)
				timelines[i].apply(skeleton, animationLast, animationTime, events, alphaMix, blend, MixDirection.mixOut);
		} else {
			var timelineMode = from.timelineMode;
			var timelineHoldMix = from.timelineHoldMix;

			var firstFrame = from.timelinesRotation.length == 0;
			if (firstFrame)
				Utils.setArraySize(from.timelinesRotation, timelineCount << 1, 0.0);
			var timelinesRotation = from.timelinesRotation;

			from.totalAlpha = 0;
			for (i in 0...timelineCount) {
				var timeline = timelines[i];
				var direction = MixDirection.mixOut;
				var timelineBlend:MixBlend;
				var alpha = 0.0;
				switch (timelineMode[i]) {
					case AnimationState.SUBSEQUENT:
						if (!drawOrder && Std.is(timeline, DrawOrderTimeline))
							continue;
						timelineBlend = blend;
						alpha = alphaMix;
					case AnimationState.FIRST:
						timelineBlend = MixBlend.setup;
						alpha = alphaMix;
					case AnimationState.HOLD_SUBSEQUENT:
						timelineBlend = blend;
						alpha = alphaHold;
					case AnimationState.HOLD_FIRST:
						timelineBlend = MixBlend.setup;
						alpha = alphaHold;
					default:
						timelineBlend = MixBlend.setup;
						var holdMix = timelineHoldMix[i];
						alpha = alphaHold * Math.max(0, 1 - holdMix.mixTime / holdMix.mixDuration);
				}
				from.totalAlpha += alpha;

				if (Std.is(timeline, RotateTimeline))
					this.applyRotateTimeline(timeline, skeleton, animationTime, alpha, timelineBlend, timelinesRotation, i << 1, firstFrame);
				else if (Std.is(timeline, AttachmentTimeline))
					this.applyAttachmentTimeline(cast timeline, skeleton, animationTime, timelineBlend, attachments);
				else {
					// This fixes the WebKit 602 specific issue described at http://esotericsoftware.com/forum/iOS-10-disappearing-graphics-10109
					Utils.webkit602BugfixHelper(alpha, blend);
					if (drawOrder && Std.is(timeline, DrawOrderTimeline) && timelineBlend == MixBlend.setup)
						direction = MixDirection.mixIn;
					timeline.apply(skeleton, animationLast, animationTime, events, alpha, timelineBlend, direction);
				}
			}
		}

		if (to.mixDuration > 0)
			this.queueEvents(from, animationTime);
		this.events.resize(0);
		from.nextAnimationLast = animationTime;
		from.nextTrackLast = from.trackTime;

		return mix;
	}

	function applyAttachmentTimeline(timeline: AttachmentTimeline, skeleton: Skeleton, time: Float, blend: MixBlend, attachments: Bool) {

		var slot = skeleton.slots[timeline.slotIndex];
		if (!slot.bone.active) return;

		var frames = timeline.frames;
		if (time < frames[0]) { // Time is before first frame.
			if (blend == MixBlend.setup || blend == MixBlend.first)
				this.setAttachment(skeleton, slot, slot.data.attachmentName, attachments);
		}
		else {
			var frameIndex;
			if (time >= frames[frames.length - 1]) // Time is after last frame.
				frameIndex = frames.length - 1;
			else
				frameIndex = Animation.binarySearch(frames, time) - 1;
			this.setAttachment(skeleton, slot, timeline.attachmentNames[frameIndex], attachments);
		}

		// If an attachment wasn't set (ie before the first frame or attachments is false), set the setup attachment later.
		if (slot.attachmentState <= this.unkeyedState) slot.attachmentState = this.unkeyedState + AnimationState.SETUP;
	}

	function setAttachment(skeleton: Skeleton, slot: Slot, attachmentName: String, attachments: Bool) {
		slot.setAttachment(attachmentName == null ? null : skeleton.getAttachment(slot.data.index, attachmentName));
		if (attachments) slot.attachmentState = this.unkeyedState + AnimationState.CURRENT;
	}

	function applyRotateTimeline(timeline:Timeline, skeleton:Skeleton, time:Float, alpha:Float, blend:MixBlend, timelinesRotation:Array<Float>, i:Int,
			firstFrame:Bool) {
		if (firstFrame)
			timelinesRotation[i] = 0;

		if (alpha == 1) {
			timeline.apply(skeleton, 0, time, null, 1, blend, MixDirection.mixIn);
			return;
		}

		var rotateTimeline:RotateTimeline = cast timeline;
		var frames = rotateTimeline.frames;
		var bone = skeleton.bones[rotateTimeline.boneIndex];
		if (!bone.active)
			return;
		var r1 = 0.0, r2 = 0.0;
		if (time < frames[0]) {
			switch (blend) {
				case MixBlend.first:
					r1 = bone.rotation;
					r2 = bone.data.rotation;
				case MixBlend.setup:
					bone.rotation = bone.data.rotation;
					return;
				case _:
					return;
			}
		} else {
			r1 = blend == MixBlend.setup ? bone.data.rotation : bone.rotation;
			if (time >= frames[frames.length - RotateTimeline.ENTRIES]) // Time is after last frame.
				r2 = bone.data.rotation + frames[frames.length + RotateTimeline.PREV_ROTATION];
			else {
				// Interpolate between the previous frame and the current frame.
				var frame = Animation.binarySearch(frames, time, RotateTimeline.ENTRIES);
				var prevRotation = frames[frame + RotateTimeline.PREV_ROTATION];
				var frameTime = frames[frame];
				var percent = rotateTimeline.getCurvePercent((frame >> 1) - 1,
					1 - (time - frameTime) / (frames[frame + RotateTimeline.PREV_TIME] - frameTime));

				r2 = frames[frame + RotateTimeline.ROTATION] - prevRotation;
				r2 -= (16384 - Std.int(16384.499999999996 - r2 / 360)) * 360;
				r2 = prevRotation + r2 * percent + bone.data.rotation;
				r2 -= (16384 - Std.int(16384.499999999996 - r2 / 360)) * 360;
			}
		}

		// Mix between rotations using the direction of the shortest route on the first frame while detecting crosses.
		var total = 0.0, diff = r2 - r1;
		diff -= (16384 - Std.int(16384.499999999996 - diff / 360)) * 360;
		if (diff == 0) {
			total = timelinesRotation[i];
		} else {
			var lastTotal = 0.0, lastDiff = 0.0;
			if (firstFrame) {
				lastTotal = 0;
				lastDiff = diff;
			} else {
				lastTotal = timelinesRotation[i]; // Angle and direction of mix, including loops.
				lastDiff = timelinesRotation[i + 1]; // Difference between bones.
			}
			var current = diff > 0, dir = lastTotal >= 0;
			// Detect cross at 0 (not 180).
			if (MathUtils.signum(lastDiff) != MathUtils.signum(diff) && Math.abs(lastDiff) <= 90) {
				// A cross after a 360 rotation is a loop.
				if (Math.abs(lastTotal) > 180)
					lastTotal += 360 * MathUtils.signum(lastTotal);
				dir = current;
			}
			total = diff + lastTotal - lastTotal % 360; // Store loops as part of lastTotal.
			if (dir != current)
				total += 360 * MathUtils.signum(lastTotal);
			timelinesRotation[i] = total;
		}
		timelinesRotation[i + 1] = diff;
		r1 += total * alpha;
		bone.rotation = r1 - (16384 - Std.int(16384.499999999996 - r1 / 360)) * 360;
	}

	function queueEvents(entry:TrackEntry, animationTime:Float) {
		var animationStart = entry.animationStart,
			animationEnd = entry.animationEnd;
		var duration = animationEnd - animationStart;
		var trackLastWrapped = entry.trackLast % duration;

		// Queue events before complete.
		var events = this.events;
		var i = 0, n = events.length;
		while (i < n) {
			var event = events[i];
			if (event.time < trackLastWrapped)
				break;
			i++;
			if (event.time > animationEnd)
				continue; // Discard events outside animation start/end.
			this.queue.event(entry, event);
		}

		// Queue complete if completed a loop iteration or the animation.
		var complete = false;
		if (entry.loop)
			complete = duration == 0 || trackLastWrapped > entry.trackTime % duration;
		else
			complete = animationTime >= animationEnd && entry.animationLast < animationEnd;
		if (complete)
			this.queue.complete(entry);

		// Queue events after complete.
		while (i < n) {
			var event = events[i];
			if (event.time < animationStart) {
				i++;
				continue; // Discard events outside animation start/end.
			}
			this.queue.event(entry, events[i]);
			i++;
		}
	}

	/** Removes all animations from all tracks, leaving skeletons in their current pose.
	 *
	 * It may be desired to use `AnimationState.setEmptyAnimation` to mix the skeletons back to the setup pose,
	 * rather than leaving them in their current pose. */
	public function clearTracks() {
		var oldDrainDisabled = this.queue.drainDisabled;
		this.queue.drainDisabled = true;
		for (i in 0...this.tracks.length)
			this.clearTrack(i);
		this.tracks.resize(0);
		this.queue.drainDisabled = oldDrainDisabled;
		this.queue.drain();
	}

	/** Removes all animations from the track, leaving skeletons in their current pose.
	 *
	 * It may be desired to use `AnimationState.setEmptyAnimation` to mix the skeletons back to the setup pose,
	 * rather than leaving them in their current pose. */
	public function clearTrack(trackIndex:Int) {
		if (trackIndex >= this.tracks.length)
			return;
		var current = this.tracks[trackIndex];
		if (current == null)
			return;

		this.queue.end(current);

		this.disposeNext(current);

		var entry = current;
		while (true) {
			var from = entry.mixingFrom;
			if (from == null)
				break;
			this.queue.end(from);
			entry.mixingFrom = null;
			entry.mixingTo = null;
			entry = from;
		}

		this.tracks[current.trackIndex] = null;

		this.queue.drain();
	}

	function setCurrent(index:Int, current:TrackEntry, interrupt:Bool) {
		var from = this.expandToIndex(index);
		this.tracks[index] = current;

		if (from != null) {
			if (interrupt)
				this.queue.interrupt(from);
			current.mixingFrom = from;
			from.mixingTo = current;
			current.mixTime = 0;

			// Store the interrupted mix percentage.
			if (from.mixingFrom != null && from.mixDuration > 0)
				current.interruptAlpha *= Math.min(1, from.mixTime / from.mixDuration);

			from.timelinesRotation.resize(0); // Reset rotation for mixing out, in case entry was mixed in.
		}

		this.queue.start(current);
	}

	/** Sets an animation by name.
	 *
	 * @see `setAnimationWith`. */
	public function setAnimation(trackIndex:Int, animationName:String, loop:Bool):TrackEntry {
		var animation = this.data.skeletonData.findAnimation(animationName);
		if (animation == null)
			throw new Error("Animation not found: " + animationName);
		return this.setAnimationWith(trackIndex, animation, loop);
	}

	/** Sets the current animation for a track, discarding any queued animations. If the formerly current track entry was never
	 * applied to a skeleton, it is replaced (not mixed from).
	 * @param loop If true, the animation will repeat. If false it will not, instead its last frame is applied if played beyond its
	 *           duration. In either case `TrackEntry.trackEnd` determines when the track is cleared.
	 * @returns A track entry to allow further customization of animation playback. References to the track entry must not be kept
	 *         after the `AnimationStateListener.dispose` event occurs. */
	public function setAnimationWith(trackIndex:Int, animation:Animation, loop:Bool):TrackEntry {
		if (animation == null)
			throw new Error("animation cannot be null.");
		var interrupt = true;
		var current = this.expandToIndex(trackIndex);
		if (current != null) {
			if (current.nextTrackLast == -1) {
				// Don't mix from an entry that was never applied.
				this.tracks[trackIndex] = current.mixingFrom;
				this.queue.interrupt(current);
				this.queue.end(current);
				this.disposeNext(current);
				current = current.mixingFrom;
				interrupt = false;
			} else
				this.disposeNext(current);
		}
		var entry = this.trackEntry(trackIndex, animation, loop, current);
		this.setCurrent(trackIndex, entry, interrupt);
		this.queue.drain();
		return entry;
	}

	/** Queues an animation by name.
	 *
	 * @see `addAnimationWith`. */
	public function addAnimation(trackIndex:Int, animationName:String, loop:Bool, delay:Float):TrackEntry {
		var animation = this.data.skeletonData.findAnimation(animationName);
		if (animation == null)
			throw new Error("Animation not found: " + animationName);
		return this.addAnimationWith(trackIndex, animation, loop, delay);
	}

	/** Adds an animation to be played after the current or last queued animation for a track. If the track is empty, it is
	 * equivalent to calling `setAnimationWith`.
	 * @param delay If > 0, sets `TrackEntry.delay`. If <= 0, the delay set is the duration of the previous track entry
	 *           minus any mix duration (from the `AnimationStateData`) plus the specified `delay` (ie the mix
	 *           ends at (`delay` = 0) or before (`delay` < 0) the previous track entry duration). If the
	 *           previous entry is looping, its next loop completion is used instead of its duration.
	 * @returns A track entry to allow further customization of animation playback. References to the track entry must not be kept
	 *         after the `AnimationStateListener.dispose` event occurs. */
	public function addAnimationWith(trackIndex:Int, animation:Animation, loop:Bool, delay:Float):TrackEntry {
		if (animation == null)
			throw new Error("animation cannot be null.");

		var last = this.expandToIndex(trackIndex);
		if (last != null) {
			while (last.next != null)
				last = last.next;
		}

		var entry = this.trackEntry(trackIndex, animation, loop, last);

		if (last == null) {
			this.setCurrent(trackIndex, entry, true);
			this.queue.drain();
		} else {
			last.next = entry;
			if (delay <= 0) {
				var duration = last.animationEnd - last.animationStart;
				if (duration != 0) {
					if (last.loop)
						delay += duration * (1 + Std.int(last.trackTime / duration));
					else
						delay += Math.max(duration, last.trackTime);
					delay -= this.data.getMix(last.animation, animation);
				} else
					delay = last.trackTime;
			}
		}

		entry.delay = delay;
		return entry;
	}

	/** Sets an empty animation for a track, discarding any queued animations, and sets the track entry's
	 * `TrackEntry.mixduration`. An empty animation has no timelines and serves as a placeholder for mixing in or out.
	 *
	 * Mixing out is done by setting an empty animation with a mix duration using either `setEmptyAnimation`,
	 * `setEmptyAnimations`, or `addEmptyAnimation`. Mixing to an empty animation causes
	 * the previous animation to be applied less and less over the mix duration. Properties keyed in the previous animation
	 * transition to the value from lower tracks or to the setup pose value if no lower tracks key the property. A mix duration of
	 * 0 still mixes out over one frame.
	 *
	 * Mixing in is done by first setting an empty animation, then adding an animation using
	 * `addAnimation` and on the returned track entry, set the
	 * `TrackEntry.mixDuration`. Mixing from an empty animation causes the new animation to be applied more and
	 * more over the mix duration. Properties keyed in the new animation transition from the value from lower tracks or from the
	 * setup pose value if no lower tracks key the property to the value keyed in the new animation. */
	public function setEmptyAnimation(trackIndex:Int, mixDuration:Float):TrackEntry {
		var entry = this.setAnimationWith(trackIndex, AnimationState.emptyAnimation, false);
		entry.mixDuration = mixDuration;
		entry.trackEnd = mixDuration;
		return entry;
	}

	/** Adds an empty animation to be played after the current or last queued animation for a track, and sets the track entry's
	 * `TrackEntry.mixDuration`. If the track is empty, it is equivalent to calling `setEmptyAnimation`.
	 *
	 * @see `setEmptyAnimation`.
	 * @param delay If > 0, sets `TrackEntry.delay`. If <= 0, the delay set is the duration of the previous track entry
	 *           minus any mix duration plus the specified `delay` (ie the mix ends at (`delay` = 0) or
	 *           before (`delay` < 0) the previous track entry duration). If the previous entry is looping, its next
	 *           loop completion is used instead of its duration.
	 * @return A track entry to allow further customization of animation playback. References to the track entry must not be kept
	 *         after the `AnimationStateListener.dispose` event occurs. */
	public function addEmptyAnimation(trackIndex:Int, mixDuration:Float, delay:Float):TrackEntry {
		if (delay <= 0)
			delay -= mixDuration;
		var entry = this.addAnimationWith(trackIndex, AnimationState.emptyAnimation, false, delay);
		entry.mixDuration = mixDuration;
		entry.trackEnd = mixDuration;
		return entry;
	}

	/** Sets an empty animation for every track, discarding any queued animations, and mixes to it over the specified mix
	 * duration. */
	public function setEmptyAnimations(mixDuration:Float) {
		var oldDrainDisabled = this.queue.drainDisabled;
		this.queue.drainDisabled = true;
		for (current in tracks) {
			if (current != null)
				this.setEmptyAnimation(current.trackIndex, mixDuration);
		}
		this.queue.drainDisabled = oldDrainDisabled;
		this.queue.drain();
	}

	function expandToIndex(index:Int):Null<TrackEntry> {
		if (index < tracks.length)
			return tracks[index];
		Utils.ensureArrayCapacity(tracks, index + 1, null);
		tracks.resize(index + 1);
		return null;
	}

	function trackEntry(trackIndex:Int, animation:Animation, loop:Bool, last:Null<TrackEntry>):TrackEntry {
		var entry = trackEntryPool.obtain();
		entry.trackIndex = trackIndex;
		entry.animation = animation;
		entry.loop = loop;
		entry.holdPrevious = false;

		entry.eventThreshold = 0;
		entry.attachmentThreshold = 0;
		entry.drawOrderThreshold = 0;

		entry.animationStart = 0;
		entry.animationEnd = animation.duration;
		entry.animationLast = -1;
		entry.nextAnimationLast = -1;

		entry.delay = 0;
		entry.trackTime = 0;
		entry.trackLast = -1;
		entry.nextTrackLast = -1;
		entry.trackEnd = 1.7976931348623157e+308 /* Number.MAX_VALUE */;
		entry.timeScale = 1;

		entry.alpha = 1;
		entry.interruptAlpha = 1;
		entry.mixTime = 0;
		entry.mixDuration = last == null ? 0 : this.data.getMix(last.animation, animation);
		entry.mixBlend = MixBlend.replace;
		return entry;
	}

	function disposeNext(entry:TrackEntry) {
		var next = entry.next;
		while (next != null) {
			this.queue.dispose(next);
			next = next.next;
		}
		entry.next = null;
	}

	function _animationsChanged() {
		this.animationsChanged = false;

		this.propertyIDs.clear();

		for (entry in tracks) {
			if (entry == null)
				continue;
			while (entry.mixingFrom != null)
				entry = entry.mixingFrom;

			do {
				if (entry.mixingFrom == null || entry.mixBlend != MixBlend.add)
					this.computeHold(entry);
				entry = entry.mixingTo;
			} while (entry != null);
		}
	}

	function computeHold(entry:TrackEntry) {
		var to = entry.mixingTo;
		var timelines = entry.animation.timelines;
		var timelinesCount = entry.animation.timelines.length;
		var timelineMode = Utils.setArraySize(entry.timelineMode, timelinesCount, 0);
		entry.timelineHoldMix.resize(0);
		var timelineDipMix = Utils.setArraySize(entry.timelineHoldMix, timelinesCount, null);
		var propertyIDs = this.propertyIDs;

		if (to != null && to.holdPrevious) {
			for (i in 0...timelinesCount) {
				timelineMode[i] = propertyIDs.add(timelines[i].getPropertyId()) ? AnimationState.HOLD_FIRST : AnimationState.HOLD_SUBSEQUENT;
			}
			return;
		}

		for (i in 0...timelinesCount) {
			var timeline = timelines[i];
			var id = timeline.getPropertyId();
			var continueOuter = false;
			if (!propertyIDs.add(id))
				timelineMode[i] = AnimationState.SUBSEQUENT;
			else if (to == null
				|| Std.is(timeline, AttachmentTimeline)
				|| Std.is(timeline, DrawOrderTimeline)
				|| Std.is(timeline, EventTimeline)
				|| !to.animation.hasTimeline(id)) {
				timelineMode[i] = AnimationState.FIRST;
			} else {
				var next = to.mixingTo;
				while (next != null) {
					if (next.animation.hasTimeline(id)) {
						next = next.mixingTo;
						continue;
					}
					if (entry.mixDuration > 0) {
						timelineMode[i] = AnimationState.HOLD_MIX;
						timelineDipMix[i] = next;
						continueOuter = true;
					}
					break;
				}
				if (continueOuter)
					continue;
				timelineMode[i] = AnimationState.HOLD_FIRST;
			}
		}
	}

	/** Returns the track entry for the animation currently playing on the track, or null if no animation is currently playing. */
	public function getCurrent(trackIndex:Int):Null<TrackEntry> {
		if (trackIndex >= this.tracks.length)
			return null;
		return this.tracks[trackIndex];
	}

	/** Adds a listener to receive events for all track entries. */
	public function addListener(listener:AnimationStateListener) {
		if (listener == null)
			throw new Error("listener cannot be null.");
		listeners.push(listener);
	}

	/** Removes the listener added with `addListener`. */
	public function removeListener(listener:AnimationStateListener) {
		listeners.remove(listener);
	}

	/** Removes all listeners added with `addListener`. */
	public function clearListeners() {
		this.listeners.resize(0);
	}

	/** Discards all listener notifications that have not yet been delivered. This can be useful to call from an
	 * `AnimationStateListener` when it is known that further notifications that may have been already queued for delivery
	 * are not wanted because new animations are being set. */
	public function clearListenerNotifications() {
		this.queue.clear();
	}
}

/** Stores settings and other state for the playback of an animation on an `AnimationState` track.
 *
 * References to a track entry must not be kept after the `AnimationStateListener.dispose` event occurs. */
class TrackEntry {
	/** The animation to apply for this track entry. */
	public var animation:Animation;

	/** The animation queued to start after this animation, or null. `next` makes up a linked list. */
	public var next(default,null):Null<TrackEntry>;

	/** The track entry for the previous animation when mixing from the previous animation to this animation, or null if no
	 * mixing is currently occuring. When mixing from multiple animations, `mixingFrom` makes up a linked list. */
	public var mixingFrom(default,null):Null<TrackEntry>;

	/** The track entry for the next animation when mixing from this animation to the next animation, or null if no mixing is
	 * currently occuring. When mixing to multiple animations, `mixingTo` makes up a linked list. */
	public var mixingTo(default,null):Null<TrackEntry>;

	/** The listener for events generated by this track entry, or null.
	 *
	 * A track entry returned from `AnimationState.setAnimation` is already the current animation
	 * for the track, so the track entry listener `AnimationStateListener.start` will not be called. */
	public var listener:Null<AnimationStateListener>;

	/** The index of the track where this track entry is either current or queued.
	 *
	 * See `AnimationState.getCurrent`. */
	public var trackIndex(default,null):Int;

	/** If true, the animation will repeat. If false it will not, instead its last frame is applied if played beyond its
	 * duration. */
	public var loop:Bool;

	/** If true, when mixing from the previous animation to this animation, the previous animation is applied as normal instead
	 * of being mixed out.
	 *
	 * When mixing between animations that key the same property, if a lower track also keys that property then the value will
	 * briefly dip toward the lower track value during the mix. This happens because the first animation mixes from 100% to 0%
	 * while the second animation mixes from 0% to 100%. Setting `holdPrevious` to true applies the first animation
	 * at 100% during the mix so the lower track value is overwritten. Such dipping does not occur on the lowest track which
	 * keys the property, only when a higher track also keys the property.
	 *
	 * Snapping will occur if `holdPrevious` is true and this animation does not key all the same properties as the
	 * previous animation. */
	public var holdPrevious:Bool;

	/** When the mix percentage (`mixTime` / `mixDuration`) is less than the
	 * `eventThreshold`, event timelines are applied while this animation is being mixed out. Defaults to 0, so event
	 * timelines are not applied while this animation is being mixed out. */
	public var eventThreshold:Float;

	/** When the mix percentage (`mixtime` / `mixDuration`) is less than the
	 * `attachmentThreshold`, attachment timelines are applied while this animation is being mixed out. Defaults to
	 * 0, so attachment timelines are not applied while this animation is being mixed out. */
	public var attachmentThreshold:Float;

	/** When the mix percentage (`mixTime` / `mixDuration`) is less than the
	 * `drawOrderThreshold`, draw order timelines are applied while this animation is being mixed out. Defaults to 0,
	 * so draw order timelines are not applied while this animation is being mixed out. */
	public var drawOrderThreshold:Float;

	/** Seconds when this animation starts, both initially and after looping. Defaults to 0.
	 *
	 * When changing the `animationStart` time, it often makes sense to set `animationLast` to the same
	 * value to prevent timeline keys before the start time from triggering. */
	public var animationStart:Float;

	/** Seconds for the last frame of this animation. Non-looping animations won't play past this time. Looping animations will
	 * loop back to `animationStart` at this time. Defaults to the animation `Animation.duration`. */
	public var animationEnd:Float;

	/** The time in seconds this animation was last applied. Some timelines use this for one-time triggers. Eg, when this
	 * animation is applied, event timelines will fire all events between the `animationLast` time (exclusive) and
	 * `getAnimationTime()` (inclusive). Defaults to -1 to ensure triggers on frame 0 happen the first time this animation
	 * is applied. */
	public var animationLast:Float;

	/** Seconds to postpone playing the animation. When this track entry is the current track entry, `delay`
	 * postpones incrementing the `trackTime`. When this track entry is queued, `delay` is the time from
	 * the start of the previous animation to when this track entry will become the current track entry (ie when the previous
	 * track entry `TrackEntry.trackTime` >= this track entry's `delay`).
	 *
	 * `timeScale` affects the delay. */
	public var delay:Float;

	/** Current time in seconds this track entry has been the current track entry. The track time determines
	 * `getAnimationTime()`. The track time can be set to start the animation at a time other than 0, without affecting
	 * looping. */
	public var trackTime:Float;

	/** The track time in seconds when this animation will be removed from the track. Defaults to the highest possible float
	 * value, meaning the animation will be applied until a new animation is set or the track is cleared. If the track end time
	 * is reached, no other animations are queued for playback, and mixing from any previous animations is complete, then the
	 * properties keyed by the animation are set to the setup pose and the track is cleared.
	 *
	 * It may be desired to use `AnimationState.addEmptyAnimation` rather than have the animation
	 * abruptly cease being applied. */
	public var trackEnd:Float;

	/** Multiplier for the delta time when this track entry is updated, causing time for this animation to pass slower or
	 * faster. Defaults to 1.
	 *
	 * `mixTime` is not affected by track entry time scale, so `mixDuration` may need to be adjusted to
	 * match the animation speed.
	 *
	 * When using `AnimationState.addAnimation` with a `delay` <= 0, note the
	 * `delay` is set using the mix duration from the `AnimationStateData`, assuming time scale to be 1. If
	 * the time scale is not 1, the delay may need to be adjusted.
	 *
	 * See `AnimationState.timeScale` for affecting all animations. */
	public var timeScale:Float;

	/** Values < 1 mix this animation with the skeleton's current pose (usually the pose resulting from lower tracks). Defaults
	 * to 1, which overwrites the skeleton's current pose with this animation.
	 *
	 * Typically track 0 is used to completely pose the skeleton, then alpha is used on higher tracks. It doesn't make sense to
	 * use alpha on track 0 if the skeleton pose is from the last frame render. */
	public var alpha:Float;

	/** Seconds from 0 to the `mixDuration` when mixing from the previous animation to this animation. May be
	 * slightly more than `mixDuration` when the mix is complete. */
	public var mixTime:Float;

	/** Seconds for mixing from the previous animation to this animation. Defaults to the value provided by
	 * `AnimationStateData.getMix` based on the animation before this animation (if any).
	 *
	 * A mix duration of 0 still mixes out over one frame to provide the track entry being mixed out a chance to revert the
	 * properties it was animating.
	 *
	 * The `mixDuration` can be set manually rather than use the value from
	 * `AnimationStateData.getMix`. In that case, the `mixDuration` can be set for a new
	 * track entry only before `AnimationState.update` is first called.
	 *
	 * When using `AnimationState.addAnimation` with a `delay` <= 0, note the
	 * `delay` is set using the mix duration from the `AnimationStateData`, not a mix duration set
	 * afterward. */
	public var mixDuration:Float;

	/** Controls how properties keyed in the animation are mixed with lower tracks. Defaults to `MixBlend.replace`, which
	 * replaces the values from the lower tracks with the animation values. `MixBlend.add` adds the animation values to
	 * the values from the lower tracks.
	 *
	 * The `mixBlend` can be set for a new track entry only before `AnimationState.apply` is first called. */
	public var mixBlend:MixBlend = replace;

	var interruptAlpha:Float;
	var totalAlpha:Float;
	var trackLast:Float;
	var nextTrackLast:Float;
	var nextAnimationLast:Float;
	final timelineMode = new Array<Int>();
	final timelineHoldMix = new Array<TrackEntry>();
	final timelinesRotation = new Array<Float>();

	function new() {}

	function reset() {
		this.next = null;
		this.mixingFrom = null;
		this.mixingTo = null;
		this.animation = null;
		this.listener = null;
		this.timelineMode.resize(0);
		this.timelineHoldMix.resize(0);
		this.timelinesRotation.resize(0);
	}

	/** Uses `trackTime` to compute the `animationTime`, which is between `animationStart`
	 * and `animationEnd`. When the `trackTime` is 0, the `animationTime` is equal to the
	 * `animationStart` time. */
	public function getAnimationTime():Float {
		if (this.loop) {
			var duration = this.animationEnd - this.animationStart;
			if (duration == 0)
				return this.animationStart;
			return (this.trackTime % duration) + this.animationStart;
		}
		return Math.min(this.trackTime + this.animationStart, this.animationEnd);
	}

	/** Returns true if at least one loop has been completed.
	 *
	 * @see `AnimationStateListener.complete`. */
	public function isComplete():Bool {
		return this.trackTime >= this.animationEnd - this.animationStart;
	}

	/** Resets the rotation directions for mixing this entry's rotate timelines. This can be useful to avoid bones rotating the
	 * long way around when using `alpha` and starting animations on other tracks.
	 *
	 * Mixing with `MixBlend.replace` involves finding a rotation between two others, which has two possible solutions:
	 * the short way or the long way around. The two rotations likely change over time, so which direction is the short or long
	 * way also changes. If the short way was always chosen, bones would flip to the other side when that direction became the
	 * long way. TrackEntry chooses the short way the first time it is applied and remembers that direction. */
	public function resetRotationDirections() {
		this.timelinesRotation.resize(0);
	}
}

/** The interface to implement for receiving `TrackEntry` events. It is always safe to call `AnimationState` methods when receiving
 * events.
 *
 * See `TrackEntry.listener` and `AnimationState.addListener`. */
interface AnimationStateListener {
	/** Invoked when this entry has been set as the current entry. */
	function start(entry:TrackEntry):Void;

	/** Invoked when another entry has replaced this entry as the current entry. This entry may continue being applied for
	 * mixing. */
	function interrupt(entry:TrackEntry):Void;

	/** Invoked when this entry is no longer the current entry and will never be applied again. */
	function end(entry:TrackEntry):Void;

	/** Invoked when this entry will be disposed. This may occur without the entry ever being set as the current entry.
	 * References to the entry should not be kept after `dispose` is called, as it may be destroyed or reused. */
	function dispose(entry:TrackEntry):Void;

	/** Invoked every time this entry's animation completes a loop. */
	function complete(entry:TrackEntry):Void;

	/** Invoked when this entry's animation triggers an event. */
	function event(entry:TrackEntry, event:Event):Void;
}

@:access(spine.AnimationState)
private class EventQueue {
	public final animState:AnimationState;
	public final objects:Array<Dynamic> = [];
	public var drainDisabled = false;

	public function new(animState:AnimationState) {
		this.animState = animState;
	}

	public function start(entry:TrackEntry) {
		objects.push(EventType.start);
		objects.push(entry);
		animState.animationsChanged = true;
	}

	public function interrupt(entry:TrackEntry) {
		objects.push(EventType.interrupt);
		objects.push(entry);
	}

	public function end(entry:TrackEntry) {
		objects.push(EventType.end);
		objects.push(entry);
		animState.animationsChanged = true;
	}

	public function dispose(entry:TrackEntry) {
		objects.push(EventType.dispose);
		objects.push(entry);
	}

	public function complete(entry:TrackEntry) {
		objects.push(EventType.complete);
		objects.push(entry);
	}

	public function event(entry:TrackEntry, event:Event) {
		objects.push(EventType.event);
		objects.push(entry);
		objects.push(event);
	}

	public function drain() {
		if (drainDisabled)
			return;
		drainDisabled = true;

		var objects = this.objects;
		var listeners = animState.listeners;

		var i = 0;
		while (i < objects.length) {
			var type:EventType = objects[i];
			var entry:TrackEntry = objects[i + 1];
			switch (type) {
				case start:
					if (entry.listener != null)
						entry.listener.start(entry);
					for (listener in listeners)
						listener.start(entry);
				case interrupt:
					if (entry.listener != null)
						entry.listener.interrupt(entry);
					for (listener in listeners)
						listener.interrupt(entry);
				case end:
					if (entry.listener != null)
						entry.listener.end(entry);
					for (listener in listeners)
						listener.end(entry);
					// Fall through.
					if (entry.listener != null)
						entry.listener.dispose(entry);
					for (listener in listeners)
						listener.dispose(entry);
					animState.trackEntryPool.free(entry);
				case dispose:
					if (entry.listener != null)
						entry.listener.dispose(entry);
					for (listener in listeners)
						listener.dispose(entry);
					animState.trackEntryPool.free(entry);
				case complete:
					if (entry.listener != null)
						entry.listener.complete(entry);
					for (listener in listeners)
						listener.complete(entry);
				case event:
					var event:Event = objects[i++ + 2];
					if (entry.listener != null)
						entry.listener.event(entry, event);
					for (listener in listeners)
						listener.event(entry, event);
			}
			i += 2;
		}
		clear();

		drainDisabled = false;
	}

	public inline function clear() {
		objects.resize(0);
	}
}

private enum abstract EventType(Int) {
	var start;
	var interrupt;
	var end;
	var dispose;
	var complete;
	var event;
}
