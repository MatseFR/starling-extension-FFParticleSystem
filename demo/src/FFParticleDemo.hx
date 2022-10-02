package;

import openfl.Vector;
import openfl.geom.Rectangle;
import starling.animation.Transitions;
import starling.animation.Tween;
import starling.assets.AssetManager;
import starling.core.Starling;
import starling.display.Button;
import starling.display.DisplayObject;
import starling.display.Image;
import starling.display.Quad;
import starling.display.Sprite;
import starling.events.Event;
import starling.events.ResizeEvent;
import starling.extensions.ColorArgb;
import starling.extensions.ffparticle.FFParticleSystem;
import starling.extensions.ffparticle.Particle;
import starling.extensions.ffparticle.SystemOptions;
import starling.extensions.ffparticle.rendering.FFParticleEffect;
import starling.extensions.ffparticle.style.FFParticleStyle;
import starling.textures.RenderTexture;
import starling.textures.Texture;
import starling.textures.TextureAtlas;
import starling.utils.Max;

/**
 * ...
 * @author Matse
 */
class FFParticleDemo extends Sprite 
{
	private var _assets:AssetManager;
	
	private var firstRun:Bool = true;
	private var bgr:Image;
	private var systems:Map<String, Dynamic>;
	private var particleSystemDefaultStyle:Class<Dynamic>;
	private var ffpsStyle:FFParticleStyle;
	
	// texture atlas
	private var atlasTexture:Texture;
	private var atlasXML:Xml;
	private var texUFO:Texture;
	
	// particle systems
	
	private var psBuildingLeft:FFParticleSystem;
	private var psBuildingRight:FFParticleSystem;
	private var psSmokeScreen:FFParticleSystem;
	private var psJets:FFParticleSystem;
	private var psUFOs:FFParticleSystem;
	private var psBurningCarFireSmoke:FFParticleSystem;
	private var psLaserChaos:FFParticleSystem;
	private var psBurningCarSparks:FFParticleSystem;
	private var psAshFar:FFParticleSystem;
	private var psAshClose:FFParticleSystem;
	private var psUFOBurningFX:FFParticleSystem;
	private var psDust:FFParticleSystem;
	private var psStarling:FFParticleSystem;
	
	// particle system options
	
	private var soBuildingLeft:SystemOptions;
	private var soBuildingRight:SystemOptions;
	private var soSmokeScreen:SystemOptions;
	private var soJets:SystemOptions;
	private var soBurningCarFireSmoke:SystemOptions;
	private var soLaserChaos:SystemOptions;
	private var soBurningCarSparks:SystemOptions;
	private var soAshFar:SystemOptions;
	private var soAshClose:SystemOptions;
	private var soUFOBurningFX:SystemOptions;
	private var soUFOs:SystemOptions;
	private var soDust:SystemOptions;
	private var soStarling:SystemOptions;
	private var soUFOHit:SystemOptions;
	
	private var psMap:Map<String, FFParticleSystem> = new Map<String, FFParticleSystem>();
	private var soMap:Map<String, SystemOptions> = new Map<String, SystemOptions>();
	private var idList:Array<String> = new Array<String>();
	private var spriteMain:Sprite;
	private var spriteUI:Sprite;
	private var spriteControls:Sprite;
	private var buttonControls:Button;
	private var buttons:Array<Button> = new Array<Button>();
	private var buttonTextureON:RenderTexture;
	private var buttonTextureOFF:RenderTexture;
	
	/**
	   
	**/
	public function new() 
	{
		super();
		
	}
	
	public function start(assets:AssetManager):Void
	{
		_assets = assets;
		
		atlasTexture = _assets.getTexture("taA");
		atlasXML = _assets.getXml("taA");
		
		var starlingTexture:Texture = _assets.getTexture("starling_bird");
		var starlingXML:Xml = _assets.getXml("starling_bird");
		var texUFO = _assets.getTexture("ufo");
		
		soBuildingLeft = SystemOptions.fromXML(_assets.getXml("burningHouseLeft"), atlasTexture, atlasXML);
		soMap["buildingLeft"] = soBuildingLeft;
		
		soBuildingRight = SystemOptions.fromXML(_assets.getXml("burningHouseRight"), atlasTexture, atlasXML);
		soMap["buildingRight"] = soBuildingRight;
		
		soSmokeScreen = SystemOptions.fromXML(_assets.getXml("smokeScreen"), atlasTexture, atlasXML);
		soSmokeScreen.sortFunction = ageSortDesc;
		soMap["smokeScreen"] = soSmokeScreen;
		
		soJets = SystemOptions.fromXML(_assets.getXml("jets"), atlasTexture, atlasXML);
		soMap["jets"] = soJets;
		
		soBurningCarFireSmoke = SystemOptions.fromXML(_assets.getXml("burning"), atlasTexture, atlasXML);
		soMap["burningCarFireSmoke"] = soBurningCarFireSmoke;
		
		soLaserChaos = SystemOptions.fromXML(_assets.getXml("laserChaos"), atlasTexture, atlasXML);
		soMap["laserChaos"] = soLaserChaos;
		
		soBurningCarSparks = SystemOptions.fromXML(_assets.getXml("sparks"), atlasTexture, atlasXML);
		soMap["burningCarSparks"] = soBurningCarSparks;
		
		soAshFar = SystemOptions.fromXML(_assets.getXml("ash"), atlasTexture, atlasXML);
		soMap["ashFar"] = soAshFar;
		
		soAshClose = soAshFar.clone().appendFromObject({maxParticles:100, gravityY:75, lifespan:3, lifespanVariance:0.1, startParticleSize:2, startParticleSizeVariance:1, finishParticleSize:2, finishParticleSizeVariance:1});
		soMap["ashClose"] = soAshClose;
		
		soUFOBurningFX = SystemOptions.fromXML(_assets.getXml("burning"), atlasTexture, atlasXML);
		soUFOBurningFX.appendFromObject({sourceX: -100, sourceY: -100});
		soMap["UFOBurningFX"] = soUFOBurningFX;
		
		soUFOs = SystemOptions.fromXML(_assets.getXml("ufo"), texUFO);
		soUFOs.customFunction = customFunctionUFO;
		soMap["UFOs"] = soUFOs;
		
		soDust = SystemOptions.fromXML(_assets.getXml("dust"), atlasTexture, atlasXML);
		soMap["dust"] = soDust;
		
		soStarling = SystemOptions.fromXML(_assets.getXml("starling_bird_pex"), starlingTexture, starlingXML);
		soStarling.customFunction = customFunctionBirds;
		soStarling.sortFunction = sizeSort;
		soStarling.forceSortFlag = true;
		soMap["starling"] = soStarling;
		
		soUFOHit = soLaserChaos.clone();
		soUFOHit.duration = 0.25;
		soUFOHit.fadeOutTime = 0.1;
		soUFOHit.finishColor = new ColorArgb(1, 1, 1, 1);
		soUFOHit.finishColorVariance = new ColorArgb(1, 1, 1, 0);
		soUFOHit.finishParticleSize = 3;
		soUFOHit.finishParticleSizeVariance = 2;
		soUFOHit.lastFrameName = "ash_8";
		soUFOHit.maxParticles = 300;
		soUFOHit.lifespan = 0.5;
		soUFOHit.lifespanVariance = 0.25;
		soUFOHit.startColor = new ColorArgb(1, 1, 1.5, 1);
		soUFOHit.startColorVariance = new ColorArgb(0, 0, 0.5, 0);
		soUFOHit.sourceVarianceX = 0;
		soUFOHit.sourceVarianceY = 0;
		soUFOHit.updateFrameLUT();
		soMap["UFOHit"] = soUFOHit;
		
		systems = new Map<String, Dynamic>();
		systems["buildingLeft"] = {name:"buildingLeft", keys:"Q", active:true, paused:false};
		systems["smokeScreen"] = {name:"smokeScreen", keys:"W", active:true, paused:false};
		systems["jets"] = {name:"jets", keys:"E", active:true, paused:false};
		systems["UFOs"] = {name:"UFOs", keys:"R", active:true, paused:false};
		systems["UFOBurningFX"] = {name:"UFOBurningFX", keys:"ZY", active:true, paused:false};
		systems["buildingRight"] = {name:"buildingRight", keys:"T", active:true, paused:false};
		systems["starling"] = {name:"starling", keys:"U", active:false, paused:false};
		systems["burningCarFireSmoke"] = {name:"burningCarFireSmoke", keys:"I", active:true, paused:false};
		systems["ashFar"] = {name:"ashFar", keys:"O", active:true, paused:false};
		systems["ashClose"] = {name:"ashClose", keys:"P", active:true, paused:false};
		systems["burningCarSparks"] = {name:"burningCarSparks", keys:"A", active:true, paused:false};
		systems["laserChaos"] = {name:"laserChaos", keys:"S", active:true, paused:false};
		systems["dust"] = {name:"dust", keys:"D", active:true, paused:false};
		
		idList.push("buildingLeft");
		idList.push("smokeScreen");
		idList.push("jets");
		idList.push("UFOs");
		idList.push("UFOBurningFX");
		idList.push("buildingRight");
		idList.push("starling");
		idList.push("burningCarFireSmoke");
		idList.push("ashFar");
		idList.push("ashClose");
		idList.push("burningCarSparks");
		idList.push("laserChaos");
		idList.push("dust");
		
		spriteMain = new Sprite();
		addChild(spriteMain);
		spriteUI = new Sprite();
		addChild(spriteUI);
		spriteControls = new Sprite();
		spriteControls.visible = false;
		spriteUI.addChild(spriteControls);
		
		// background
		bgr = new Image(_assets.getTexture("timesSquare"));
		spriteMain.addChild(bgr);
		
		// ui
		var quad:Quad = new Quad(200, 32);
		buttonTextureON = new RenderTexture(Std.int(quad.width), Std.int(quad.height));
		buttonTextureON.draw(quad);
		
		quad.color = 0x666666;
		buttonTextureOFF = new RenderTexture(Std.int(quad.width), Std.int(quad.height));
		buttonTextureOFF.draw(quad);
		
		buttonControls = new Button(buttonTextureON, "show controls");
		buttonControls.addEventListener(Event.TRIGGERED, onControlButtonClick);
		spriteUI.addChild(buttonControls);
		
		var btn:Button;
		var system:Dynamic;
		for (id in idList)
		{
			system = systems[id];
			if (system.active)
			{
				btn = new Button(buttonTextureON, system.name);
			}
			else
			{
				btn = new Button(buttonTextureOFF, system.name);
			}
			btn.name = system.name;
			btn.addEventListener(Event.TRIGGERED, onButtonClick);
			buttons.push(btn);
		}
		
		var gap:Float = 4;
		var tY:Float = 0;
		for (button in buttons)
		{
			button.y = tY;
			spriteControls.addChild(button);
			tY += quad.height + gap;
		}
		
		updateStageContent(Starling.current.nativeStage.stageWidth, Starling.current.nativeStage.stageHeight);
		
		stage.addEventListener(ResizeEvent.RESIZE, stageResize);
		
		Starling.current.juggler.delayCall(autoStartTimerComplete, 1);
	}
	
	private function stageResize(e:ResizeEvent):Void
	{
		updateStageContent(e.width, e.height);
	}
	
	private function updateStageContent(width:Float, height:Float):Void
	{
		var scaleX:Float = width / bgr.texture.width;
		var scaleY:Float = height / bgr.texture.height;
		this.scale = Math.min(scaleX, scaleY);
		
		this.x = (width - bgr.width * this.scale) / 2;
		this.y = (height - bgr.height * this.scale) / 2;
		
		if (this.mask == null)
		{
			this.mask = new Quad(1, 1);
		}
		this.mask.x = bgr.x;
		this.mask.y = bgr.y;
		this.mask.width = bgr.width;
		this.mask.height = bgr.height;
		
		var viewPortRectangle:Rectangle = new Rectangle();
		viewPortRectangle.width = width;
		viewPortRectangle.height = height;
		
		// assign the new stage width and height
		stage.stageWidth = Std.int(width);
		stage.stageHeight = Std.int(height);
		
		// resize the viewport
		Starling.current.viewPort = viewPortRectangle;
		
		// position ui controls
		updateUIControls();
	}
	
	private function updateUIControls():Void
	{
		var spacing:Float = 8;
		buttonControls.y = bgr.height - buttonControls.height - spacing;
		buttonControls.x = spacing;
		
		spriteControls.x = buttonControls.x;
		spriteControls.y = buttonControls.y - spriteControls.height - spacing;
	}
	
	private function autoStartTimerComplete():Void
	{
		updateScene(true);
		var fadeTime:Float = 2;
		var delay:Float = 0.5;
		var count:Int = spriteMain.numChildren;
		var s:DisplayObject;
		var tw:Tween;
		for (i in 1...count)
		{
			s = spriteMain.getChildAt(i);
			s.alpha = 0;
			tw = new Tween(s, fadeTime, Transitions.EASE_IN);
			tw.delay = delay * i;
			tw.animate("alpha", 1);
			Starling.current.juggler.add(tw);
		}
	}
	
	private function updateScene(advanceTime:Bool = false):Void
	{
		if (firstRun)
		{
			particleSystemDefaultStyle = FFParticleSystem.defaultStyle;
			ffpsStyle = Type.createInstance(particleSystemDefaultStyle, []);
			firstRun = false;
		}
		
		if (!FFParticleSystem.poolCreated)
		{
			FFParticleSystem.initPool(4096, false);
		}
		
		if (ffpsStyle != null && !Reflect.getProperty(ffpsStyle.effectType, "buffersCreated"))
		{
			Reflect.callMethod(ffpsStyle.effectType, Reflect.field(ffpsStyle.effectType, "createBuffers"), [4096, 16]);
		}
		
		var ps:FFParticleSystem;
		var data:Dynamic;
		for (id in idList)
		{
			data = systems[id];
			ps = psMap[data.name];
			if (ps == null && data.active)
			{
				ps = new FFParticleSystem(soMap[data.name]);
				psMap[data.name] = ps;
				if (data.name == "UFOBurningFX")
				{
					psUFOBurningFX = psMap[data.name];
				}
			}
			
			if (data.active)
			{
				spriteMain.addChild(ps);
				if (!data.paused)
				{
					ps.start();
				}
				if (advanceTime)
				{
					ps.advanceTime(ps.cycleDuration);
				}
			}
		}
	}
	
	private function customFunctionBirds(birds:Vector<Particle>, activeBirdsNum:Int):Void
	{
		var bird:Particle;
		for (i in 0...activeBirdsNum)
		{
			bird = birds[i];
			bird.colorRed = bird.colorGreen = bird.colorBlue = bird.scale * 10 - 0.4;
		}
		
		var len:Int = birds.length;
		for (i in activeBirdsNum...len)
		{
			birds[i].scale = Max.MAX_VALUE;
		}
	}
	
	private function customFunctionUFO(ufos:Vector<Particle>, activeUFONum:Int):Void
	{
		var ps:FFParticleSystem;
		var ufo:Particle;
		for (i in 0...activeUFONum)
		{
			ufo = ufos[i];
			
			if (ufo.currentTime > 0.8 * ufo.totalTime)
			{
				ufo.colorRed = 0.2;
				ufo.colorGreen = 0.2;
				ufo.colorBlue = 0.2;
				ufo.radialAcceleration = 0;
				if (ufo.customValues == null)
				{
					ufo.customValues = {};
					ufo.customValues.rd = Math.random() - 0.5;
					
					soUFOHit.duration = 0.25;
					soUFOHit.angle = Math.random() * 360;
					soUFOHit.angleVariance = Math.random() * 180;
					soUFOHit.speed = 1000 * ufo.scale;
					soUFOHit.speedVariance = 500 * ufo.scale;
					soUFOHit.maxParticles = Std.int(400 * ufo.scale);
					soUFOHit.startParticleSize = 200 * ufo.scale;
					soUFOHit.finishParticleSize = 200 * ufo.scale;
					
					ps = new FFParticleSystem(soUFOHit);
					ufo.customValues.psHit = ps;
					ps.addEventListener(Event.COMPLETE, function(e:Event):Void
					{
						var ps:FFParticleSystem = cast e.currentTarget;
						ps.stop();
						ps.dispose();
						if (ufo.customValues != null)
						{
							ufo.customValues.psHit = null;
						}
					});
					spriteMain.addChild(ps);
					ps.start();
					
					ufo.x += Math.random() * 10 - 5;
					ufo.y += Math.random() * 10;
					ufo.customValues.ea = Math.atan2( -ufo.y, -ufo.x);
					
					ufo.velocityX = (Math.random() < 0.5 ? -1 : 1) * ufo.scale * (Math.random() * 100 + 50);
					ufo.velocityY = Math.random() * ufo.scale * 100 + 25;
					ufo.customValues.rotType = Math.random() < 0.5 ? true : false;
				}
				
				ps = ufo.customValues.psHit;
				if (ps != null && ufo.x > 0 && ufo.x < 1024 && ufo.y > 0 && ufo.y < 600)
				{
					ps.emitterX = ufo.x;
					ps.emitterY = ufo.y;
				}
				
				ufo.velocityY *= 1.01;
				
				if (psUFOBurningFX != null)
				{
					psUFOBurningFX.emitterX = ufo.x;
					psUFOBurningFX.emitterY = ufo.y;
					psUFOBurningFX.startSize = ufo.scale * 125;
					psUFOBurningFX.endSize = psUFOBurningFX.startSize * 2;
					psUFOBurningFX.emitterXVariance = ufo.scale * 100;
					psUFOBurningFX.speed = 20 * ufo.scale;
					psUFOBurningFX.speedVariance = psUFOBurningFX.speed * .75;
					psUFOBurningFX.lifespanVariance = psUFOBurningFX.lifespan * .5;
					psUFOBurningFX.gravityY = -100 * ufo.scale;
					psUFOBurningFX.gravityX = -50 * ufo.scale;
					psUFOBurningFX.emitAngle = ufo.customValues.ea;
				}
				
				if (ufo.customValues.rotType)
				{
					ufo.rotation = Math.sin(ufo.currentTime * ufo.currentTime) * 0.03 * ufo.currentTime;
				}
				else
				{
					ufo.rotationDelta += ufo.customValues.rd;
				}
				
				if (ufo.currentTime >= ufo.totalTime && ufo.customValues)
				{
					ufo.customValues = null;
					if (psUFOBurningFX != null)
					{
						psUFOBurningFX.emitterX = -100;
						psUFOBurningFX.emitterY = -100;
					}
				}
				
				if (ufo.y > 450)
				{
					ufo.velocityY *= -0.3;
				}
			}
		}
	}
	
	private function ageSort(a:Particle, b:Particle):Int
	{
		if (a.active && b.active)
		{
			if (a.currentTime < b.currentTime)
			{
				return -1;
			}
			if (a.currentTime > b.currentTime)
			{
				return 1;
			}
		}
		else if (!a.active && !b.active)
		{
			return 0;
		}
		else if (a.active && !b.active)
		{
			return -1;
		}
		else if (!a.active && b.active)
		{
			return 1;
		}
		return 0;
	}
	
	private function ageSortDesc(a:Particle, b:Particle):Int
	{
		if (a.active && b.active)
		{
			if (a.currentTime < b.currentTime)
			{
				return 1;
			}
			if (a.currentTime > b.currentTime)
			{
				return -1;
			}
		}
		else if (a.active && !b.active)
		{
			return -1;
		}
		else if (!a.active && b.active)
		{
			return 1;
		}
		return 0;
	}
	
	private function sizeSort(a:Particle, b:Particle):Int
	{
		if (a.scale > b.scale)
		{
			return 1;
		}
		if (a.scale < b.scale)
		{
			return -1;
		}
		return 0;
	}
	
	private function onButtonClick(evt:Event):Void
	{
		var btn:Button = cast evt.target;
		systems[btn.name].active = !systems[btn.name].active;
		if (systems[btn.name].active)
		{
			btn.upState = buttonTextureON;
		}
		else
		{
			var ps:FFParticleSystem = psMap[btn.name];
			ps.dispose();
			psMap[btn.name] = null;
			btn.upState = buttonTextureOFF;
		}
		updateScene();
	}
	
	private function onControlButtonClick(evt:Event):Void
	{
		spriteControls.visible = !spriteControls.visible;
		if (spriteControls.visible)
		{
			buttonControls.text = "hide controls";
		}
		else
		{
			buttonControls.text = "show controls";
		}
	}
	
}