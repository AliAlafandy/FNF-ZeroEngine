package funkin.states.editors;

import funkin.data.backend.Song;
import funkin.data.backend.Section;
import funkin.data.backend.Rating;
import mobile.data.backend.MobileData;
import mobile.data.objects.TouchButton;
import mobile.input.MobileInputID;
import mobile.input.MobileInputManager;

import funkin.data.objects.Note;
import funkin.data.objects.NoteSplash;
import funkin.data.objects.StrumNote;

import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.animation.FlxAnimationController;
import flixel.math.FlxPoint;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

import haxe.Json;
import funkin.data.objects.Character;
import openfl.utils.Assets as OpenFlAssets;

class EditorPlayState extends MusicBeatSubstate
{
	// Borrowed from original PlayState
	var finishTimer:FlxTimer = null;
	var noteKillOffset:Float = 350;
	var spawnTime:Float = 2000;
	var startingSong:Bool = true;

	var playbackRate:Float = 1;
	var vocals:FlxSound;
	var opponentVocals:FlxSound;
	var inst:FlxSound;
	
	var notes:FlxTypedGroup<Note>;
	var unspawnNotes:Array<Note> = [];
	var ratingsData:Array<Rating> = Rating.loadDefault();
	
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var opponentStrums:FlxTypedGroup<StrumNote>;
	var playerStrums:FlxTypedGroup<StrumNote>;
	var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	
	var combo:Int = 0;
	var lastRating:FlxSprite;
	var lastCombo:FlxSprite;
	var lastScore:Array<FlxSprite> = [];
	var keysArray:Array<String> = [
		'note_left',
		'note_down',
		'note_up',
		'note_right'
	];

	#if mobile
	private var mobileStrumTouchState:Array<Bool> = [false, false, false, false];
	private var mobileExtraTouchState:Array<Bool> = [false, false];

	private function updateOfficialExtraTouchZones():Void
	{
		var active:Array<Bool> = [false, false];
		if (MobileData.mode == 4 && ClientPrefs.data.extraButtons != 'NONE')
		{
			var top:Float = FlxG.height * 0.25;
			var bottom:Float = (playerStrums != null && playerStrums.length > 0) ? playerStrums.members[0].y : FlxG.height;
			for (touch in FlxG.touches.list)
			{
				if (!touch.pressed) continue;
				var point:FlxPoint = touch.getScreenPosition(FlxG.camera, FlxPoint.get());
				if (point.y >= top && point.y < bottom)
				{
					if (point.x < FlxG.width * 0.5) active[0] = true;
					else if (ClientPrefs.data.extraButtons == 'DOUBLE') active[1] = true;
				}
				point.put();
			}
		}
		for (i in 0...2)
		{
			if (i == 1 && ClientPrefs.data.extraButtons != 'DOUBLE') active[i] = false;
			// Chart-editor playtesting has no script callback host; retain the touch zones here.
			mobileExtraTouchState[i] = active[i];
		}
	}
	private function updateMobileStrums():Void
	{
		updateOfficialExtraTouchZones();
		updateOfficialExtraButtons();
		if (MobileData.mode != 4)
		{
			for (lane in 0...4)
			{
				if (mobileStrumTouchState[lane]) keyReleased(lane);
				mobileStrumTouchState[lane] = false;
			}
			return;
		}

		var touched:Array<Bool> = [false, false, false, false];
		for (touch in FlxG.touches.list)
		{
			if (!touch.pressed) continue;

			var point:FlxPoint = touch.getScreenPosition(FlxG.camera, FlxPoint.get());
			for (lane in 0...playerStrums.length)
			{
				var receptor:StrumNote = playerStrums.members[lane];
				if (receptor == null || !receptor.exists || !receptor.visible || receptor.alpha <= 0.05) continue;

				// Match the broad, thumb-friendly FNF Mobile lane hit areas.
				// Keep the touch target close to the actual receptor instead
				// of treating the entire screen half as a lane.
				// Extend each hit area to the midpoint between adjacent lanes,
				// plus a small overlap. Touching the gap can then activate both
				// neighboring directions (e.g. Left + Down).
				var laneGap:Float = Math.max(0, Note.swagWidth - receptor.width);
				var pairOverlap:Float = laneGap * 0.5 + 8;
				var laneLeft:Float = receptor.x;
				var laneRight:Float = receptor.x + receptor.width;
				// Only the intended pairs share touch space:
				// Left + Down (0/1) and Up + Right (2/3).
				// The Down + Up boundary stays separate.
				if (lane == 1 || lane == 3) laneLeft -= pairOverlap;
				if (lane == 0 || lane == 2) laneRight += pairOverlap;
				var laneTop:Float = receptor.y - receptor.height * 0.35;
				var laneBottom:Float = receptor.y + receptor.height * 1.35;
				if (point.x >= laneLeft && point.x <= laneRight
					&& point.y >= laneTop && point.y <= laneBottom)
					touched[lane] = true;
			}
			point.put();
		}

		for (lane in 0...4)
		{
			if (touched[lane] && !mobileStrumTouchState[lane])
				keyPressed(lane);
			else if (!touched[lane] && mobileStrumTouchState[lane])
				keyReleased(lane);
			mobileStrumTouchState[lane] = touched[lane];
		}
	}
	#end

	private function onButtonPress(button:TouchButton):Void
	{
		if (button.IDs.filter(id -> id.toString().startsWith("EXTRA")).length > 0)
			return;

		var buttonCode:Int = (button.IDs[0].toString().startsWith('NOTE')) ? button.IDs[0] : button.IDs[1];
		if (button.justPressed) keyPressed(buttonCode);
	}

	private function onButtonRelease(button:TouchButton):Void
	{
		if (button.IDs.filter(id -> id.toString().startsWith("EXTRA")).length > 0)
			return;

		var buttonCode:Int = (button.IDs[0].toString().startsWith('NOTE')) ? button.IDs[0] : button.IDs[1];
		if(buttonCode > -1) keyReleased(buttonCode);
	}
	
	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		var laneIndex:Int = 0;
		for (key in keysArray)
		{
			var isHeld:Bool = controls.pressed(key);
			#if mobile
			if (MobileData.mode == 4 && laneIndex < mobileStrumTouchState.length)
				isHeld = isHeld || mobileStrumTouchState[laneIndex];
			#end
			holdArray.push(isHeld);
			if(controls.controllerMode)
			{
				pressArray.push(controls.justPressed(key));
				releaseArray.push(controls.justReleased(key));
			}
			laneIndex++;
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i])
					keyPressed(i);

		// rewritten inputs???
		if (notes.length > 0) {
			for (n in notes) { // I can't do a filter here, that's kinda awesome
				var canHit:Bool = (n != null && n.canBeHit && n.mustPress &&
					!n.tooLate && !n.wasGoodHit && !n.blockHit);

				if (guitarHeroSustains)
					canHit = canHit && n.parent != null && n.parent.wasGoodHit;

				if (canHit && n.isSustainNote) {
					var released:Bool = !holdArray[n.noteData];
					
					if (!released)
						goodNoteHit(n);
				}
			}
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i])
					keyReleased(i);
	}

	
	function opponentNoteHit(note:Note):Void
	{
		if (PlayState.SONG.needsVoices && opponentVocals.length <= 0)
			vocals.volume = 1;

		var strum:StrumNote = opponentStrums.members[Std.int(Math.abs(note.noteData))];
		if(strum != null) {
			strum.playAnim('confirm', true);
			strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / playbackRate;
		}
		note.hitByOpponent = true;

		if (!note.isSustainNote)
			invalidateNote(note);
	}

	function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;

		note.wasGoodHit = true;
		if (ClientPrefs.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

		if(note.hitCausesMiss) {
			noteMiss(note);
			if(!note.noteSplashData.disabled && !note.isSustainNote)
				spawnNoteSplashOnNote(note);

			if (!note.isSustainNote)
				invalidateNote(note);
			return;
		}

		if (!note.isSustainNote)
		{
			combo++;
			if(combo > 9999) combo = 9999;
			popUpScore(note);
		}

		var spr:StrumNote = playerStrums.members[note.noteData];
		if(spr != null) spr.playAnim('confirm', true);
		vocals.volume = 1;

		if (!note.isSustainNote)
			invalidateNote(note);
	}
	
	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(daNote);
		});

		if (daNote != null && guitarHeroSustains && daNote.parent == null) {
			if(daNote.tail.length > 0) {
				daNote.alpha = 0.35;
				for(childNote in daNote.tail) {
					childNote.alpha = daNote.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				daNote.missed = true;
				daNote.canBeHit = false;
			}

			if (daNote.missed)
				return;
		}

		if (daNote != null && guitarHeroSustains && daNote.parent != null && daNote.isSustainNote) {
			if (daNote.missed)
				return; 
			
			var parentNote:Note = daNote.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != daNote) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		// score and data
		songMisses++;
		totalPlayed++;
		RecalculateRating(true);
		vocals.volume = 0;
		combo = 0;
	}

	public function invalidateNote(note:Note):Void {
		//if (!ClientPrefs.data.lowQuality) note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
		}
	}

	function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}
	
	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time;
		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
		}

		if (Conductor.songPosition <= opponentVocals.length)
		{
			opponentVocals.time = Conductor.songPosition;
			#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
		}
		vocals.play();
		opponentVocals.play();
	}

	function RecalculateRating(badHit:Bool = false) {
		if(totalPlayed != 0) //Prevent divide by 0
			ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));

		fullComboUpdate();
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
	}

	function updateScore(miss:Bool = false)
	{
		var str:String = '?';
		if(totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			if (ClientPrefs.data.typeRating == 'Kade Engine')
			{
				str = '$percent% - $ratingFC';
			} else {
				str = '$percent% | $ratingFC';
			}
		}
		switch(ClientPrefs.data.typeRating)
		{
			case 'Psych Engine':
				scoreTxt.text = 'Hits: $songHits | Misses: $songMisses | Rating: $str';

			case 'Kade Engine':
				scoreTxt.text = 'Hits: $songHits | Combo Breaks: $songMisses | Accuracy: $str';

			case 'Base Game':
				scoreTxt.text = 'Hits: $songHits';
		}
	}
	
	function fullComboUpdate()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = 'Clear';
		if(songMisses < 1)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else if (songMisses < 10)
			ratingFC = 'SDCB';
	}
	
	function loadCharacterFile(char:String):CharacterFile {
		var characterPath:String = 'characters/' + char + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!FileSystem.exists(path)) {
			path = Paths.getSharedPath(characterPath);
		}

		if (!FileSystem.exists(path))
		#else
		var path:String = Paths.getSharedPath(characterPath);
		if (!OpenFlAssets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + Character.DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
		}

		#if MODS_ALLOWED
		var rawJson = File.getContent(path);
		#else
		var rawJson = OpenFlAssets.getText(path);
		#end
		return cast Json.parse(rawJson);
	}
}
