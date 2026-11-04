package mobile.data.backend;

import flixel.system.scaleModes.BaseScaleMode;

/**
 * Mobile fullscreen scale mode.
 *
 * Fill the complete device display instead of fitting a 16:9 game viewport
 * inside a wider screen. This removes the vertical black bars on phones.
 */
class MobileScaleMode extends BaseScaleMode
{
	public static var allowWideScreen(default, set):Bool = true;

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		// Match the physical display dimensions. BaseScaleMode will calculate
		// the X/Y scale factors from this size and the virtual game resolution.
		gameSize.set(Width, Height);
	}

	override function updateGamePosition():Void
	{
		// The viewport fills the display, so it must not be centered with an offset.
		if (FlxG.game != null)
		{
			FlxG.game.x = 0;
			FlxG.game.y = 0;
		}
	}

	@:noCompletion
	private static function set_allowWideScreen(value:Bool):Bool
	{
		allowWideScreen = value;
		FlxG.scaleMode = new MobileScaleMode();
		return value;
	}
}
