package;

import haxe.Int32;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.display.StageScaleMode;
import openfl.display3D.Context3DRenderMode;
import openfl.system.Capabilities;
import openfl.utils.Assets;
import starling.assets.AssetManager;
import starling.core.Starling;
import starling.events.Event;
import starling.utils.Max;

/**
 * ...
 * @author Matse
 */
class Main extends Sprite 
{
	private var _starling:Starling;
	private var _assets:AssetManager;
	
	/**
	   
	**/
	public function new() 
	{
		super();
		
		if (stage != null) start();
		else addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
	}
	
	private function onAddedToStage(event:Dynamic):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

		stage.scaleMode = StageScaleMode.NO_BORDER;

		start();
	}
	
	private function start():Void
	{
		_starling = new Starling(FFParticleDemo, stage, null, null, Context3DRenderMode.AUTO, "auto");
		_starling.enableErrorChecking = Capabilities.isDebugger;
		_starling.showStats = true;
		_starling.skipUnchangedFrames = true;
		_starling.supportBrowserZoom = true;
		_starling.supportHighResolutions = true;
		_starling.simulateMultitouch = true;
		_starling.addEventListener(Event.ROOT_CREATED, function():Void
		{
			loadAssets(startGame);
		});

		this.stage.addEventListener(Event.RESIZE, onResize, false, Max.INT_MAX_VALUE, true);

		_starling.start();
	}
	
	private function loadAssets(onComplete:Void->Void):Void
	{
		_assets = new AssetManager();
		
		_assets.verbose = Capabilities.isDebugger;
		_assets.enqueue([
			Assets.getPath("assets/img/ash.pex"),
			Assets.getPath("assets/img/burning.pex"),
			Assets.getPath("assets/img/burningHouseLeft.pex"),
			Assets.getPath("assets/img/burningHouseRight.pex"),
			Assets.getPath("assets/img/dust.pex"),
			Assets.getPath("assets/img/fire.pex"),
			Assets.getPath("assets/img/jets.pex"),
			Assets.getPath("assets/img/laserChaos.pex"),
			Assets.getPath("assets/img/smokeScreen.pex"),
			Assets.getPath("assets/img/sparks.pex"),
			Assets.getPath("assets/img/starling_bird_pex.pex"),
			Assets.getPath("assets/img/starling_bird.png"),
			Assets.getPath("assets/img/starling_bird.xml"),
			Assets.getPath("assets/img/taA.png"),
			Assets.getPath("assets/img/taA.xml"),
			Assets.getPath("assets/img/ufo.pex")
		]);
		_assets.loadQueue(onComplete);
	}
	
	private function startGame():Void
	{
		var demo:FFParticleDemo = cast(_starling.root, FFParticleDemo);
		demo.start(_assets);
	}
	
	private function onResize(e:openfl.events.Event):Void
    {
        //var viewPort:Rectangle = RectangleUtil.fit(new Rectangle(0, 0, Constants.GameWidth, Constants.GameHeight), new Rectangle(0, 0, stage.stageWidth, stage.stageHeight));
        //try
        //{
            //this._starling.viewPort = viewPort;
        //}
        //catch(error:Error) {}
    }

}
