package;

import engine.debug.FPSCounter;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;

import haxe.io.Path;

import openfl.Assets;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;

import lime.system.System as LimeSystem;
import lime.app.Application;

import funkin.states.TitleState;
import mobile.data.backend.MobileScaleMode;

import openfl.events.KeyboardEvent;

#if COPYSTATE_ALLOWED
import funkin.states.CopyState;
#end

#if linux
import lime.graphics.Image;

@:cppInclude('./engine/external/gamemode_client.h')
@:cppFileCode('
	#define GAMEMODE_AUTO
')
#end

class Main extends Sprite
{
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: false, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPSCounter;

	#if android
	public static var waterMark:Sprite;
	#end

	#if mobile
	public static final platform:String = "Phones";
	#else
	public static final platform:String = "PCs";
	#end

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
		#if cpp
        cpp.NativeGc.enable(true);
        cpp.NativeGc.run(true);
        #end
	}

	public function new()
	{
		super();

		#if mobile
		#if android
		StorageUtil.requestPermissions();
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end
		funkin.data.backend.CrashHandler.init();

		#if windows
		@:functionCode("
		#include <windows.h>
		#include <winuser.h>
		setProcessDPIAware() // allows for more crisp visuals
		DisableProcessWindowsGhosting() // lets you move the window and such if it's not responding
		")
		#end

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		#if (openfl <= "9.2.0")
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1.0)
		{
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}
		#else
		if (game.zoom == -1.0)
			game.zoom = 1.0;
		#end
	
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(funkin.data.scripts.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		addChild(new FlxGame(game.width, game.height, #if COPYSTATE_ALLOWED !CopyState.checkExistingFiles() ? CopyState : #end game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}

		#if android
		updateWaterMark();
		Lib.current.stage.addEventListener(Event.RESIZE, onWaterMarkResize);
		#end

		#if linux
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if desktop
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, toggleFullScreen);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end

		#if mobile
		LimeSystem.allowScreenTimeout = ClientPrefs.data.screensaver;
		FlxG.scaleMode = new MobileScaleMode();
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function (w, h) {
			if(fpsVar != null)
				fpsVar.positionFPS(10, 3, Math.min(Lib.current.stage.stageWidth / FlxG.width, Lib.current.stage.stageHeight / FlxG.height));
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);
		});
	}

	#if android
	static function onWaterMarkResize(event:Event):Void
	{
		updateWaterMarkPosition();
	}

	public static function updateWaterMark():Void
	{
		if (waterMark != null && waterMark.parent != null) waterMark.parent.removeChild(waterMark);
		waterMark = null;

		if (!ClientPrefs.data.waterMark || Lib.current.stage == null) return;

		var imagePath:String = switch (ClientPrefs.data.watermarkStyle)
		{
			case 'Psych Engine': "assets/shared/images/psychIcon.png";
			case 'Mods Engine': "assets/shared/images/modsIcon.png";
			case 'Zero Engine': "assets/shared/images/zeroIcon.png";
			default: "assets/shared/images/zeroIcon.png";
		};

		if (!Assets.exists(imagePath))
		{
			trace('Watermark image not found: ' + imagePath);
			return;
		}

		var bitmapData = Assets.getBitmapData(imagePath);
		waterMark = new Sprite();
		waterMark.addChild(new Bitmap(bitmapData));
		//waterMark.scale.set(2, 2);
		waterMark.alpha = 0.6; // 0.4
		updateWaterMarkPosition();
		Lib.current.stage.addChild(waterMark);
		if(waterMark != null) {
			waterMark.visible = ClientPrefs.data.waterMark;
		}
	}

	static function updateWaterMarkPosition():Void
	{
		if (waterMark == null || Lib.current.stage == null)
			return;

		var stageWidth:Float = Lib.current.stage.stageWidth;
		var stageHeight:Float = Lib.current.stage.stageHeight;

		// centered and the unused space becomes the side letterbox bars.
		// Put the watermark inside a side bar instead of over the game.
		/*if (FlxG.game != null)
		{
			var gameLeft:Float = FlxG.game.x;
			var gameRight:Float = gameLeft + FlxG.game.width;
			var leftBarWidth:Float = gameLeft;
			var rightBarWidth:Float = stageWidth - gameRight;
			var margin:Float = 10;

			if (rightBarWidth >= waterMark.width + margin * 2)
				waterMark.x = gameRight + (rightBarWidth - waterMark.width) * 0.5;
			else if (leftBarWidth >= waterMark.width + margin * 2)
				waterMark.x = (leftBarWidth - waterMark.width) * 0.5;
			else
				waterMark.x = stageWidth - margin - waterMark.width;
		}
		else
			waterMark.x = stageWidth - 10 - waterMark.width;*/

		waterMark.x = (stageWidth - 10) - waterMark.width;
		waterMark.y = (stageHeight - 10) - waterMark.height;
	}
	#end

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	function toggleFullScreen(event:KeyboardEvent){
		if(Controls.instance.justReleased('fullscreen'))
			FlxG.fullscreen = !FlxG.fullscreen;
	}
}
