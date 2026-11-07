package mobile.substates;

import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxGradient;

import funkin.data.objects.Note;
import funkin.data.objects.StrumNote;

import mobile.data.backend.TouchUtil;

import flixel.input.touch.FlxTouch;
import flixel.ui.FlxButton as UIButton;

class MobileControlSelectSubState extends MusicBeatSubstate
{
	var options:Array<String> = ['Pad-Right', 'Pad-Left', 'Pad-Custom', 'Hitbox', 'Official'];
	var control:MobileControls;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var itemText:Alphabet;
	var positionText:FlxText;
	var positionTextBg:FlxSprite;
	var bg:FlxBackdrop;
	var ui:FlxCamera;
	var curOption:Int = MobileData.mode;
	var buttonBinded:Bool = false;
	var bindButton:TouchButton;
	var reset:UIButton;
	var tweenieShit:Float = 0;

	#if mobile
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var opponentStrums:FlxTypedGroup<StrumNote>;
	var playerStrums:FlxTypedGroup<StrumNote>;

	private var mobileStrumTouchState:Array<Bool> = [false, false, false, false];
	public var mobileExtraButtons:MobileInputManager;
	private var mobileExtraButtonMode:String = '';
	#end

	public function new()
	{
		super();
		if (ClientPrefs.data.extraButtons != 'NONE')
			options.push('Pad-Extra');

		bg = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true,
			FlxColor.fromRGB(FlxG.random.int(0, 255), FlxG.random.int(0, 255), FlxG.random.int(0, 255)),
			FlxColor.fromRGB(FlxG.random.int(0, 255), FlxG.random.int(0, 255), FlxG.random.int(0, 255))));
		bg.velocity.set(40, 40);
		bg.alpha = 0;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		FlxTween.tween(bg, {alpha: 0.45}, 0.3, {
			ease: FlxEase.quadOut,
			onComplete: (twn:FlxTween) ->
			{
				FlxTween.tween(ui, {alpha: 1}, 0.2, {ease: FlxEase.circOut});
			}
		});
		add(bg);

		FlxG.mouse.visible = !FlxG.onMobile;

		ui = new FlxCamera();
		ui.bgColor.alpha = 0;
		ui.alpha = 0;
		FlxG.cameras.add(ui, false);

		itemText = new Alphabet(0, 60, '');
		itemText.alignment = LEFT;
		itemText.cameras = [ui];
		add(itemText);

		leftArrow = new FlxSprite(0, itemText.y - 25);
		leftArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		leftArrow.cameras = [ui];
		add(leftArrow);

		itemText.x = leftArrow.width + 70;
		leftArrow.x = itemText.x - 60;

		rightArrow = new FlxSprite().loadGraphicFromSprite(leftArrow);
		rightArrow.flipX = true;
		rightArrow.setPosition(itemText.x + itemText.width + 10, itemText.y - 25);
		rightArrow.cameras = [ui];
		add(rightArrow);

		positionText = new FlxText(0, FlxG.height, FlxG.width / 4, '');
		positionText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, FlxTextAlign.LEFT);
		positionText.visible = false;

		positionTextBg = FlxGradient.createGradientFlxSprite(250, 150, [FlxColor.BLACK, FlxColor.BLACK, FlxColor.BLACK, FlxColor.TRANSPARENT], 1, 360);
		positionTextBg.setPosition(0, FlxG.height - positionTextBg.height);
		positionTextBg.visible = false;
		positionTextBg.alpha = 0.8;
		add(positionTextBg);
		positionText.cameras = [ui];
		add(positionText);

		if (options[curOption] == 'Official') {
			strumLineNotes = new FlxTypedGroup<StrumNote>();
			opponentStrums = new FlxTypedGroup<StrumNote>();
			playerStrums = new FlxTypedGroup<StrumNote>();
			generateStaticArrows(1);
		}

		var exit = new UIButton(0, itemText.y - 25, "Exit & Save", () ->
		{
			if (options[curOption].toLowerCase().contains('pad'))
				control.touchPad.setExtrasDefaultPos();
			if (options[curOption] == 'Pad-Extra')
			{
				var nuhuh = new FlxText(0, 0, FlxG.width / 2, 'Pad-Extra Is Just A Binding Option\nPlease Select A Different Option To Exit.');
				nuhuh.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
				nuhuh.screenCenter();
				nuhuh.cameras = [ui];
				add(nuhuh);
				FlxTween.tween(nuhuh, {alpha: 0}, 3.4, {
					ease: FlxEase.circOut,
					onComplete: (twn:FlxTween) ->
					{
						nuhuh.destroy();
						remove(nuhuh);
					}
				});
				return;
			}
			MobileData.mode = curOption;
			if (options[curOption] == 'Pad-Custom')
				MobileData.setTouchPadCustom(control.touchPad);
			controls.isInSubstate = FlxG.mouse.visible = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MobileData.forcedMode = null;
			close();
		});
		exit.color = FlxColor.LIME;
		exit.setGraphicSize(Std.int(exit.width) * 3);
		exit.updateHitbox();
		exit.x = FlxG.width - exit.width - 70;
		exit.label.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, FlxTextAlign.CENTER);
		exit.label.fieldWidth = exit.width;
		exit.label.x = ((exit.width - exit.label.width) / 2) + exit.x;
		exit.label.offset.y = -10; // WHY THE FUCK I CAN'T CHANGE THE LABEL Y
		exit.cameras = [ui];
		add(exit);

		reset = new UIButton(exit.x, exit.height + exit.y + 20, "Reset", () ->
		{
			changeOption(0); // realods the current control mode ig?
			FlxG.sound.play(Paths.sound('cancelMenu'));
		});
		reset.color = FlxColor.RED;
		reset.setGraphicSize(Std.int(reset.width) * 3);
		reset.updateHitbox();
		reset.label.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, FlxTextAlign.CENTER);
		reset.label.fieldWidth = reset.width;
		reset.label.x = ((reset.width - reset.label.width) / 2) + reset.x;
		reset.label.offset.y = -10;
		reset.cameras = [ui];
		add(reset);

		changeOption(0);
	}

	override function update(elapsed:Float)
	{
		checkArrowButton(leftArrow, () ->
		{
			changeOption(-1);
		});

		checkArrowButton(rightArrow, () ->
		{
			changeOption(1);
		});

		if (options[curOption] == 'Pad-Custom' || options[curOption] == 'Pad-Extra')
		{
			if (buttonBinded)
			{
				if (TouchUtil.justReleased)
				{
					bindButton = null;
					buttonBinded = false;
				}
				else
					moveButton(TouchUtil.touch, bindButton);
			}
			else
			{
				control.touchPad.forEachAlive((button:TouchButton) ->
				{
					if (button.justPressed)
						moveButton(TouchUtil.touch, button);
				});
			}
			control.touchPad.forEachAlive((button:TouchButton) ->
			{
				if (button != bindButton && buttonBinded)
				{
					bindButton.centerBounds();
					button.bounds.immovable = true;
					bindButton.bounds.immovable = false;
					button.centerBounds();
					FlxG.overlap(bindButton.bounds, button.bounds, function(a:Dynamic, b:Dynamic)
					{ // these args dosen't work fuck them :/
						bindButton.centerInBounds();
						button.centerBounds();
						bindButton.bounds.immovable = true;
						button.bounds.immovable = false;
						// trace('button${bindButton.tag} & button${button.tag} collided');
					}, function(a:Dynamic, b:Dynamic)
					{
						if (!bindButton.bounds.immovable)
						{
							if (bindButton.bounds.x > button.bounds.x)
								bindButton.bounds.x = button.bounds.x + button.bounds.width;
							else
								bindButton.bounds.x = button.bounds.x - button.bounds.width;

							if (bindButton.bounds.y > button.bounds.y)
								bindButton.bounds.y = button.bounds.y + button.bounds.height;
							else if (bindButton.bounds.y != button.bounds.y)
								bindButton.bounds.y = button.bounds.y - button.bounds.height;
						}
						return true;
					});
					/*FlxG.collide(bindButton.bounds, button.bounds, function(a:Dynamic, b:Dynamic) { // these args dosen't work fuck them :/
						bindButton.centerInBounds();
						button.centerBounds();
						bindButton.bounds.immovable = true;
						button.bounds.immovable = false;
						trace('button${bindButton.tag} & button${button.tag} collided');
					});*/
				}
			});
		}

		#if mobile
		if (options[curOption] == 'Official') {
			updateMobileStrums();
		}
		#end

		tweenieShit += 180 * elapsed;

		super.update(elapsed);
	}

	function changeControls(?type:Int, ?extraMode:Bool = false)
	{
		if (type == null)
			type = curOption;
		if (control != null)
			control.destroy();
		if (members.contains(control))
			remove(control);
		control = new MobileControls(type, extraMode);
		add(control);
		control.cameras = [ui];
	}

	function changeOption(change:Int)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		curOption += change;

		if (curOption < 0)
			curOption = options.length - 1;
		if (curOption >= options.length)
			curOption = 0;

		switch (curOption)
		{
			case 0 | 1 | 3 | 4:
				reset.visible = false;
				changeControls();
			case 2:
				reset.visible = true;
				changeControls();
			case 5:
				reset.visible = true;
				changeControls(0, true);
				control.touchPad.forEachAlive((button:TouchButton) ->
				{
					var ignore = ['G', 'S'];
					if (!ignore.contains(button.tag.toUpperCase()))
						button.visible = button.active = false;
				});
		}
		updatePosText();
		setOptionText();
	}

	function setOptionText()
	{
		itemText.text = options[curOption].replace('-', ' ');
		itemText.updateHitbox();
		itemText.offset.set(0, 15);
		FlxTween.tween(rightArrow, {x: itemText.x + itemText.width + 10}, 0.1, {ease: FlxEase.quintOut});
	}

	function updatePosText()
	{
		var optionName = options[curOption];
		if (optionName == 'Pad-Custom' || optionName == 'Pad-Extra')
		{
			positionText.visible = positionTextBg.visible = true;
			if (optionName == 'Pad-Custom')
			{
				positionText.text = 'LEFT X: ${control.touchPad.buttonLeft.x} - Y: ${control.touchPad.buttonLeft.y}\nDOWN X: ${control.touchPad.buttonDown.x} - Y: ${control.touchPad.buttonDown.y}\n\nUP X: ${control.touchPad.buttonUp.x} - Y: ${control.touchPad.buttonUp.y}\nRIGHT X: ${control.touchPad.buttonRight.x} - Y: ${control.touchPad.buttonRight.y}';
			}
			else
			{
				positionText.text = 'S X: ${control.touchPad.buttonExtra.x} - Y: ${control.touchPad.buttonExtra.y}\n\n\n\nG X: ${control.touchPad.buttonExtra2.x} - Y: ${control.touchPad.buttonExtra2.y}';
			}
			positionText.setPosition(0, (((positionTextBg.height - positionText.height) / 2) + positionTextBg.y));
		}
		else
			positionText.visible = positionTextBg.visible = false;
	}

	function checkArrowButton(button:FlxSprite, func:Void->Void)
	{
		if (TouchUtil.overlaps(button))
		{
			if (TouchUtil.pressed)
				button.animation.play('press');
			if (TouchUtil.justPressed)
			{
				if (options[curOption] == "Pad-Extra" && control.touchPad != null)
					control.touchPad.setExtrasDefaultPos();
				func();
			}
		}
		if (TouchUtil.justReleased && button.animation.curAnim.name == 'press')
			button.animation.play('idle');
		if (FlxG.keys.justPressed.LEFT && button == leftArrow || FlxG.keys.justPressed.RIGHT && button == rightArrow)
			func();
	}

	function moveButton(touch:FlxTouch, button:TouchButton):Void
	{
		bindButton = button;
		buttonBinded = bindButton == null ? false : true;
		bindButton.x = touch.x - Std.int(bindButton.width / 2);
		bindButton.y = touch.y - Std.int(bindButton.height / 2);
		updatePosText();
	}

	private inline function mobilePlayerLaneX(lane:Int):Float
	{
		var laneWidth:Float = Note.swagWidth;
		var groupWidth:Float = laneWidth * 4;
		return (FlxG.width - groupWidth) * 0.75 + laneWidth * lane;
	}

	private inline function mobilePlayerNoteX(lane:Int, noteWidth:Float):Float
	{
		return mobilePlayerLaneX(lane) + (Note.swagWidth - noteWidth) * 0.75;
	}

	private function generateStaticArrows(player:Int):Void
	{
		var useMobileLayout:Bool = (options[curOption] == 'Official');

		var strumLineX:Float = useMobileLayout ? 0 : (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X);
		var strumLineY:Float = useMobileLayout ? 0 : (ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50);

		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1 && !useMobileLayout)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = useMobileLayout ? player == 1 : ClientPrefs.data.downScroll;

			if (useMobileLayout) targetAlpha = 1;

			babyArrow.alpha = targetAlpha;

			if (player == 1) {
				playerStrums.add(babyArrow);
			} else {
				if(ClientPrefs.data.middleScroll && !useMobileLayout)
				{
					babyArrow.x += 310;
					if(i > 1) babyArrow.x += FlxG.width / 2 + 25;
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();

			if (useMobileLayout && player == 1)
			{
				babyArrow.updateHitbox();
				babyArrow.x = (FlxG.width / 2) - mobilePlayerLaneX(i);
				if(i > 1) babyArrow.x = (FlxG.width / 2) + mobilePlayerLaneX(i);
				babyArrow.y = FlxG.height - babyArrow.height - 104;
			} else if (useMobileLayout && player < 1) {
				babyArrow.scale.set(0.4, 0.4);
				babyArrow.updateHitbox();
				babyArrow.x = 32 + (babyArrow.width * i);
				babyArrow.y = 54;
			}
		}
	}

	private function updateOfficialExtraButtons():Void
	{
		if (mobileExtraButtons == null || mobileExtraButtonMode != ClientPrefs.data.extraButtons)
		{
			if (mobileExtraButtons != null)
			{
				remove(mobileExtraButtons, true);
				mobileExtraButtons.destroy();
			}
			mobileExtraButtons = new MobileInputManager();
			mobileExtraButtonMode = ClientPrefs.data.extraButtons;
			createOfficialExtraButton(MobileInputID.EXTRA_1, 'S', 0xFF0066FF);
			if (mobileExtraButtonMode == 'DOUBLE')
				createOfficialExtraButton(MobileInputID.EXTRA_2, 'G', 0xFFA6FF00);
			mobileExtraButtons.updateTrackedButtons();
			mobileExtraButtons.cameras = [FlxG.camera];
			mobileExtraButtons.scrollFactor.set();
			add(mobileExtraButtons);
		}

		var firstStrum:StrumNote = (playerStrums != null && playerStrums.length > 0) ? playerStrums.members[0] : null;
		var buttonY:Float = FlxG.height * 0.43;
		if (firstStrum != null)
			buttonY = (FlxG.height * 0.25 + firstStrum.y - mobileExtraButtons.members[0].height) * 0.5;

		var count:Int = mobileExtraButtons.length;
		var buttonWidth:Float = mobileExtraButtons.members[0].width;
		var spacing:Float = 16;
		var totalWidth:Float = count * buttonWidth + (count - 1) * spacing;
		var startX:Float = (FlxG.width - totalWidth) * 0.5;
		for (i in 0...count)
			mobileExtraButtons.members[i].setPosition(startX + i * (buttonWidth + spacing), buttonY);
	}

	private function createOfficialExtraButton(id:MobileInputID, graphic:String, tint:FlxColor):Void
	{
		var button:TouchButton = new TouchButton(0, 0, [id]);
		button.label = new FlxSprite();
		button.loadGraphic(Paths.image('touchpad/bg', 'mobile'));
		button.label.loadGraphic(Paths.image('touchpad/' + graphic, 'mobile'));
		button.scale.set(0.243, 0.243);
		button.updateHitbox();
		button.updateLabelPosition();
		button.statusBrightness = [1, 0.8, 0.4];
		button.statusIndicatorType = BRIGHTNESS;
		button.indicateStatus();
		button.label.antialiasing = button.antialiasing = ClientPrefs.data.antialiasing;
		button.color = tint;
		button.parentAlpha = ClientPrefs.data.controlsAlpha;
		button.onDown.callback = function() {};
		button.onOut.callback = button.onUp.callback = function() {};
		mobileExtraButtons.add(button);
	}
	private function updateMobileStrums():Void
	{
		updateOfficialExtraButtons();

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
			var receptor:StrumNote = playerStrums.members[lane];
			if (receptor != null)
			{
				if (touched[lane] && !mobileStrumTouchState[lane])
				{
					receptor.playAnim('pressed');
					receptor.resetAnim = 0;
				}
				else if (!touched[lane] && mobileStrumTouchState[lane])
				{
					receptor.playAnim('static');
					receptor.resetAnim = 0;
				}
			}
			mobileStrumTouchState[lane] = touched[lane];
		}
	}
}
