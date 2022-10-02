package starling.extensions.ffparticle;
import haxe.xml.Access;
import openfl.Vector;
import openfl.display3D.Context3DBlendFactor;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.geom.Rectangle;
import starling.extensions.ColorArgb;
import starling.filters.FragmentFilter;
import starling.textures.SubTexture;
import starling.textures.Texture;

/**
 * The SystemOption object is ment to interprete given PEX and TextureAtlas xml files
 * cache and modify the values for instanciation of a particle system, since XML parsing
 * is extremly expensive.
 */
class SystemOptions 
{
	private var mFirstFrameName:String = "";
	private var mLastFrameName:String = "";
	
	/**
	 * The number of frames to animate, alternatively to setting the index with lastFrame.
	 */
	public var animationLength:UInt = 1;
	/**
	 * A Boolean setting whether the texture should be animated or not.
	 */
	public var isAnimated:Bool = false;
	/**
	 * A int to set the first frames index in the texture atlas.
	 */
	public var firstFrame:UInt = 0;
	/**
	 * A int to set the last frames index in the texture atlas.
	 * -1 will be set the last frame to the highest value possible.
	 */
	public var lastFrame:Int = -1;
	/**
	 * A uint (1 or higher) setting the number of animation loops if the texture is animated.
	 */
	public var loops:UInt = 1;
	/**
	 * A Boolean setting whether the initial frame should be chosen randomly.
	 */
	public var randomStartFrames:Bool = false;
	/**
	 * A Boolean setting whether particles shall be tinted.
	 */
	public var tinted:Bool = true;
	/**
	 * A Boolean overriding the premultiplied alpha value of the system.
	 */
	public var premultipliedAlpha:Bool = true;
	/**
	 * A Number between 0 and 1 setting the timespan to fade in particles.
	 */
	public var spawnTime:Float = 0;
	/**
	 * A Number between 0 and 1 setting the timespan to fade in particles.
	 */
	public var fadeInTime:Float = 0;
	/**
	 * A Number between 0 and 1 setting the timespan to fade out particles.
	 */
	public var fadeOutTime:Float = 0;
	/**
	 * A uint setting the emitter type to EMITTER_TYPE_GRAVITY:int = 0; or
	 * EMITTER_TYPE_RADIAL:int = 1;
	 */
	public var emitterType:Int = 0;
	/**
	 * A uint setting the maximum number of particles used by this FFParticleSystem
	 */
	public var maxParticles:UInt = 10;
	/**
	 * The horizontal emitter position
	 */
	public var sourceX:Float = 0;
	/**
	 * The vertical emitter position
	 */
	public var sourceY:Float = 0;
	
	public var sourceVarianceX:Float = 0;
	public var sourceVarianceY:Float = 0;
	public var lifespan:Float = 1;
	public var lifespanVariance:Float = 0;
	public var angle:Float = 0;
	public var angleVariance:Float = 0;
	/**
	 * Aligns the particles to their emit angle at birth.
	 *
	 * @see angle
	 */
	public var emitAngleAlignedRotation:Bool = false;
	public var startParticleSize:Float = 20;
	public var startParticleSizeVariance:Float = 0;
	public var finishParticleSize:Float = 20;
	public var finishParticleSizeVariance:Float = 0;
	public var rotationStart:Float = 0;
	public var rotationStartVariance:Float = 0;
	public var rotationEnd:Float = 0;
	public var rotationEndVariance:Float = 0;
	/**
	 * The emission time span. Pass to -1 set the emission time to infinite.
	 */
	public var duration:Float = 2;
	
	public var gravityX:Float = 0;
	public var gravityY:Float = 0;
	/**
	 * The speed of a particle in pixel per seconds.
	 */
	public var speed:Float = 50;
	public var speedVariance:Float = 0;
	
	public var radialAcceleration:Float = 0;
	public var radialAccelerationVariance:Float = 0;
	public var tangentialAcceleration:Float = 0;
	public var tangentialAccelerationVariance:Float = 0;
	
	public var maxRadius:Float = 100;
	public var maxRadiusVariance:Float = 0;
	public var minRadius:Float = 0;
	public var minRadiusVariance:Float = 0;
	public var rotatePerSecond:Float = 0;
	public var rotatePerSecondVariance:Float = 0;
	
	public var startColor:ColorArgb = new ColorArgb(1, 1, 1, 1);
	public var startColorVariance:ColorArgb = new ColorArgb(0, 0, 0, 0);
	public var finishColor:ColorArgb = new ColorArgb(1, 1, 1, 1);
	public var finishColorVariance:ColorArgb = new ColorArgb(0, 0, 0, 0);
	
	public var filter:FragmentFilter;
	public var customFunction:Vector<Particle>->Int->Void;
	public var sortFunction:Particle->Particle->Int;
	public var forceSortFlag:Bool = false;
	
	/**
	 * Sets the blend function for rendering the source.
	 * @see #blendFactorDestination
	 * @see flash.display3D.Context3DBlendFactor
	 */
	public var blendFuncSource:String = Context3DBlendFactor.ONE;
	/**
	 * Sets the blend function for rendering the destination.
	 * @see #blendFactorSource
	 * @see flash.display3D.Context3DBlendFactor
	 */
	public var blendFuncDestination:String = Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
	
	/**
	 * A Boolean that determines whether the FFParticleSystem should calculate it's exact bounds or return stage dimensions
	 */
	public var excactBounds:Bool = false;
	
	/**
	 * The look up table containing information about all frames within the animation
	 */
	public var mFrameLUT:Vector<Frame>;
	
	private function get_frameLUT():Vector<Frame>
	{
		if (mFrameLUT == null)
			updateFrameLUT();
		return mFrameLUT;
	}
	/**
	 * The texture used by the particle system.
	 */
	public var texture:Texture;
	/**
	 * The atlas xml file for the used texture
	 */
	public var atlasXML:Xml;
	
	/**
	 * Creates a new SystemOptions instance.
	 *
	 * @see fromXML()
	 * @see clone()
	 */
	public function new(texture:Texture, atlasXML:Xml = null, config:Xml = null) 
	{
		if (texture == null) throw new Error("texture must not be null");
		
		this.texture = texture;
		this.atlasXML = atlasXML;
		
		if (config != null)
		{
			SystemOptions.fromXML(config, texture, atlasXML, this);
		}
	}
	
	/**
	 * Modifies given properties of a SystemOptions instance.
	 * @param	object
	 * @return	A new SystemOptions instance with given parameters
	 */
	public function appendFromObject(object:Dynamic):SystemOptions
	{
		var fields:Array<String>;
		var objClass:Class<Dynamic> = Type.getClass(object);
		if (objClass != null)
		{
			fields = Type.getInstanceFields(objClass);
		}
		else
		{
			fields = Reflect.fields(objClass);
		}
		
		for (p in fields)
		{
			try
			{
				Reflect.setProperty(this, p, Reflect.getProperty(object, p));
			}
			catch (err:Error)
			{
				trace(err);
			}
		}
		
		updateFrameLUT();
		
		return this;
	}
	
	/**
	 * Returns a copy of the SystemOptions instance.
	 * @param	systemOptions A SystemOptions instance
	 * @return	A new SystemOptions instance with given parameters
	 */
	public function clone(target:SystemOptions = null):SystemOptions
	{
		if (target == null)
			target = new SystemOptions(this.texture, this.atlasXML);
		
		target.texture = texture;
		target.atlasXML = atlasXML;
		
		target.sourceX = this.sourceX;
		target.sourceY = this.sourceY;
		target.sourceVarianceX = this.sourceVarianceX;
		target.sourceVarianceY = this.sourceVarianceY;
		target.gravityX = this.gravityX;
		target.gravityY = this.gravityY;
		target.emitterType = this.emitterType;
		target.maxParticles = this.maxParticles;
		target.lifespan = this.lifespan;
		target.lifespanVariance = this.lifespanVariance;
		target.startParticleSize = this.startParticleSize;
		target.startParticleSizeVariance = this.startParticleSizeVariance;
		target.finishParticleSize = this.finishParticleSize;
		target.finishParticleSizeVariance = this.finishParticleSizeVariance;
		target.angle = this.angle;
		target.angleVariance = this.angleVariance;
		target.rotationStart = this.rotationStart;
		target.rotationStartVariance = this.rotationStartVariance;
		target.rotationEnd = this.rotationEnd;
		target.rotationEndVariance = this.rotationEndVariance;
		target.emitAngleAlignedRotation = this.emitAngleAlignedRotation;
		target.speed = this.speed;
		target.speedVariance = this.speedVariance;
		target.radialAcceleration = this.radialAcceleration;
		target.radialAccelerationVariance = this.radialAccelerationVariance;
		target.tangentialAcceleration = this.tangentialAcceleration;
		target.tangentialAccelerationVariance = this.tangentialAccelerationVariance;
		target.maxRadius = this.maxRadius;
		target.maxRadiusVariance = this.maxRadiusVariance;
		target.minRadius = this.minRadius;
		target.minRadiusVariance = this.minRadiusVariance;
		target.rotatePerSecond = this.rotatePerSecond;
		target.rotatePerSecondVariance = this.rotatePerSecondVariance;
		target.startColor = this.startColor;
		target.startColorVariance = this.startColorVariance;
		target.finishColor = this.finishColor;
		target.finishColorVariance = this.finishColorVariance;
		target.blendFuncSource = this.blendFuncSource;
		target.blendFuncDestination = this.blendFuncDestination;
		target.duration = this.duration;
		
		target.isAnimated = this.isAnimated;
		target.firstFrameName = this.firstFrameName;
		target.firstFrame = this.firstFrame;
		target.lastFrameName = this.lastFrameName;
		target.lastFrame = this.lastFrame;
		target.lastFrame = this.lastFrame;
		target.loops = this.loops;
		target.randomStartFrames = this.randomStartFrames;
		target.tinted = this.tinted;
		target.spawnTime = this.spawnTime;
		target.fadeInTime = this.fadeInTime;
		target.fadeOutTime = this.fadeOutTime;
		target.excactBounds = this.excactBounds;
		
		target.filter = this.filter;
		target.customFunction = this.customFunction;
		target.sortFunction = this.sortFunction;
		target.forceSortFlag = this.forceSortFlag;
		
		target.mFrameLUT = this.mFrameLUT;
		
		return target;
	}
	
	/**
	 * Exports current settings to XML file.
	 * @param	target
	 * @return
	 */
	//public function exportConfig(atlasXML:XML = null):XML
	//{
		//var tempAtlas:XML = atlasXML ? atlasXML : this.atlasXML;
		//var target:XML = XML('<particleEmitterConfig/>');
		//
		//target.angle.@value = isNaN(angle) ? 0 : angle.toFixed(2);
		//target.angleVariance.@value = isNaN(angleVariance) ? 0 : angleVariance.toFixed(2);
		//target.duration.@value = isNaN(duration) ? 0 : duration.toFixed(2);
		//target.emitterType.@value = isNaN(emitterType) ? 0 : emitterType.toFixed(2);
		//target.emitAngleAlignedRotation.@value = int(emitAngleAlignedRotation);
		//target.excactBounds.@value = int(excactBounds);
		//target.finishParticleSize.@value = isNaN(finishParticleSize) ? 10 : finishParticleSize.toFixed(2);
		//target.finishParticleSizeVariance.@value = isNaN(finishParticleSizeVariance) ? 0 : finishParticleSizeVariance.toFixed(2);
		//target.gravity.@x = isNaN(gravityX) ? 0 : gravityX.toFixed(2);
		//target.gravity.@y = isNaN(gravityY) ? 0 : gravityY.toFixed(2);
		//if (isAnimated || randomStartFrames || firstFrame != 0)
		//{
			//if (!tempAtlas)
				//trace("Warning: atlasXML is not defined - frame names will be set as integers.");
			//target.animation.isAnimated.@value = int(isAnimated);
			//target.animation.firstFrame.@value = getFrameNameFromAtlas(firstFrame, tempAtlas);
			//target.animation.lastFrame.@value = getFrameNameFromAtlas(lastFrame, tempAtlas);
			//target.animation.loops.@value = loops;
			//target.animation.randomStartFrames.@value = int(randomStartFrames);
		//}
		//target.maxParticles.@value = isNaN(maxParticles) ? 0 : maxParticles.toFixed(2);
		//target.maxRadius.@value = isNaN(maxRadius) ? 0 : maxRadius.toFixed(2);
		//target.maxRadiusVariance.@value = isNaN(maxRadiusVariance) ? 0 : maxRadiusVariance.toFixed(2);
		//target.minRadius.@value = isNaN(minRadius) ? 0 : minRadius.toFixed(2);
		//target.minRadiusVariance.@value = isNaN(minRadiusVariance) ? 0 : minRadiusVariance.toFixed(2);
		//target.particleLifeSpan.@value = isNaN(lifespan) ? 0 : lifespan.toFixed(2);
		//target.particleLifespanVariance.@value = isNaN(lifespanVariance) ? 0 : lifespanVariance.toFixed(2);
		//target.radialAcceleration.@value = isNaN(radialAcceleration) ? 0 : radialAcceleration.toFixed(2);
		//target.radialAccelVariance.@value = isNaN(radialAccelerationVariance) ? 0 : radialAccelerationVariance.toFixed(2);
		//target.rotatePerSecond.@value = isNaN(rotatePerSecond) ? 0 : rotatePerSecond.toFixed(2);
		//target.rotatePerSecondVariance.@value = isNaN(rotatePerSecondVariance) ? 0 : rotatePerSecondVariance.toFixed(2);
		//target.rotationEnd.@value = isNaN(rotationEnd) ? 0 : rotationEnd.toFixed(2);
		//target.rotationEndVariance.@value = isNaN(rotationEndVariance) ? 0 : rotationEndVariance.toFixed(2);
		//target.rotationStart.@value = isNaN(rotationStart) ? 0 : rotationStart.toFixed(2);
		//target.rotationStartVariance.@value = isNaN(rotationStartVariance) ? 0 : rotationStartVariance.toFixed(2);
		//target.sourcePosition.@x = isNaN(sourceX) ? 0 : sourceX.toFixed(2);
		//target.sourcePosition.@y = isNaN(sourceY) ? 0 : sourceY.toFixed(2);
		//target.sourcePositionVariance.@x = isNaN(sourceVarianceX) ? 0 : sourceVarianceX.toFixed(2);
		//target.sourcePositionVariance.@y = isNaN(sourceVarianceY) ? 0 : sourceVarianceY.toFixed(2);
		//target.speed.@value = isNaN(speed) ? 0 : speed.toFixed(2);
		//target.speedVariance.@value = isNaN(speedVariance) ? 0 : speedVariance.toFixed(2);
		//target.startParticleSize.@value = isNaN(startParticleSize) ? 10 : startParticleSize.toFixed(2);
		//target.startParticleSizeVariance.@value = isNaN(startParticleSizeVariance) ? 0 : startParticleSizeVariance.toFixed(2);
		//target.tangentialAcceleration.@value = isNaN(tangentialAcceleration) ? 0 : tangentialAcceleration.toFixed(2);
		//target.tangentialAccelVariance.@value = isNaN(tangentialAccelerationVariance) ? 0 : tangentialAccelerationVariance.toFixed(2);
		//target.tinted.@value = int(tinted);
		//target.premultipliedAlpha.@value = Boolean(premultipliedAlpha);
		//
		//target.startColor.@red = isNaN(startColor.red) ? 1 : startColor.red;
		//target.startColor.@green = isNaN(startColor.green) ? 1 : startColor.green;
		//target.startColor.@blue = isNaN(startColor.blue) ? 1 : startColor.blue;
		//target.startColor.@alpha = isNaN(startColor.alpha) ? 1 : startColor.alpha;
		//
		//target.startColorVariance.@red = isNaN(startColorVariance.red) ? 0 : startColorVariance.red;
		//target.startColorVariance.@green = isNaN(startColorVariance.green) ? 0 : startColorVariance.green;
		//target.startColorVariance.@blue = isNaN(startColorVariance.blue) ? 0 : startColorVariance.blue;
		//target.startColorVariance.@alpha = isNaN(startColorVariance.alpha) ? 0 : startColorVariance.alpha;
		//
		//target.finishColor.@red = isNaN(finishColor.red) ? 1 : finishColor.red;
		//target.finishColor.@green = isNaN(finishColor.green) ? 1 : finishColor.green;
		//target.finishColor.@blue = isNaN(finishColor.blue) ? 1 : finishColor.blue;
		//target.finishColor.@alpha = isNaN(finishColor.alpha) ? 1 : finishColor.alpha;
		//
		//target.finishColorVariance.@red = isNaN(finishColorVariance.red) ? 0 : finishColorVariance.red;
		//target.finishColorVariance.@green = isNaN(finishColorVariance.green) ? 0 : finishColorVariance.green;
		//target.finishColorVariance.@blue = isNaN(finishColorVariance.blue) ? 0 : finishColorVariance.blue;
		//target.finishColorVariance.@alpha = isNaN(finishColorVariance.alpha) ? 0 : finishColorVariance.alpha;
		//
		//target.blendFuncSource.@value = blendFuncSource.replace(/([A-Z])/g, '_$1').toUpperCase();
		//target.blendFuncDestination.@value = blendFuncDestination.replace(/([A-Z])/g, '_$1').toUpperCase();
		//
		//return target;
	//}
	
	//private function getFrameNameFromAtlas(idx:int, atlasXML:XML = null):String
	//{
		//if (atlasXML == null)
			//return idx.toString();
		//var name:String = atlasXML.SubTexture[idx].@name;
		//if (atlasXML.SubTexture.(@name == name).length() == 1)
		//{
			//return name;
		//}
		//else
		//{
			//return idx.toString();
		//}
	//}
	
	/**
	 * Interpretation of the .pex config XML
	 * @param	config The .pex config XML file
	 * @param	texture	The texture used by the FFParticleSystem
	 * @param	atlasXML TextureAtlas XML file necessary for animated Particles
	 * @param	target An optional to write data
	 * @return
	 */
	public static function fromXML(config:Xml, texture:Texture, atlasXML:Xml = null, target:SystemOptions = null):SystemOptions
	{
		if (target == null)
			target = new SystemOptions(texture, atlasXML);
		
		target.texture = texture;
		target.atlasXML = atlasXML;
		
		var xml:Access = new Access(config.firstElement());
		target.sourceX = Std.parseFloat(xml.node.sourcePosition.att.x);
		target.sourceY = Std.parseFloat(xml.node.sourcePosition.att.y);
		target.sourceVarianceX = Std.parseFloat(xml.node.sourcePositionVariance.att.x);
		target.sourceVarianceY = Std.parseFloat(xml.node.sourcePositionVariance.att.y);
		target.gravityX = Std.parseFloat(xml.node.gravity.att.x);
		target.gravityY = Std.parseFloat(xml.node.gravity.att.y);
		target.emitterType = Std.parseInt(xml.node.emitterType.att.value);
		target.maxParticles = Std.parseInt(xml.node.maxParticles.att.value);
		if (xml.hasNode.particleLifeSpan)
		{
			target.lifespan = Math.max(0.01, Std.parseFloat(xml.node.particleLifeSpan.att.value));
		}
		else
		{
			target.lifespan = Math.max(0.01, Std.parseFloat(xml.node.particleLifespan.att.value));
		}
		if (xml.hasNode.particleLifespanVariance)
		{
			target.lifespanVariance = Std.parseFloat(xml.node.particleLifespanVariance.att.value);
		}
		else
		{
			target.lifespanVariance = Std.parseFloat(xml.node.particleLifeSpanVariance.att.value);
		}
		target.startParticleSize = Std.parseFloat(xml.node.startParticleSize.att.value);
		target.startParticleSizeVariance = Std.parseFloat(xml.node.startParticleSizeVariance.att.value);
		target.finishParticleSize = Std.parseFloat(xml.node.finishParticleSize.att.value);
		if (xml.hasNode.finishParticleSize)
		{
			target.finishParticleSizeVariance = Std.parseFloat(xml.node.finishParticleSizeVariance.att.value);
		}
		else
		{
			target.finishParticleSizeVariance = Std.parseFloat(xml.node.FinishParticleSizeVariance.att.value);
		}
		target.angle = Std.parseFloat(xml.node.angle.att.value);
		target.angleVariance = Std.parseFloat(xml.node.angleVariance.att.value);
		target.rotationStart = Std.parseFloat(xml.node.rotationStart.att.value);
		target.rotationStartVariance = Std.parseFloat(xml.node.rotationStartVariance.att.value);
		if (xml.hasNode.rotationEnd)
		{
			target.rotationEnd = Std.parseFloat(xml.node.rotationEnd.att.value);
		}
		if (xml.hasNode.rotationEndVariance)
		{
			target.rotationEndVariance = Std.parseFloat(xml.node.rotationEndVariance.att.value);
		}
		if (xml.hasNode.emitAngleAlignedRotation) 
		{
			target.emitAngleAlignedRotation = getBoolValue(xml.node.emitAngleAlignedRotation.att.value);
		}
		target.speed = Std.parseFloat(xml.node.speed.att.value);
		target.speedVariance = Std.parseFloat(xml.node.speedVariance.att.value);
		target.radialAcceleration = Std.parseFloat(xml.node.radialAcceleration.att.value);
		target.radialAccelerationVariance = Std.parseFloat(xml.node.radialAccelVariance.att.value);
		target.tangentialAcceleration = Std.parseFloat(xml.node.tangentialAcceleration.att.value);
		target.tangentialAccelerationVariance = Std.parseFloat(xml.node.tangentialAccelVariance.att.value);
		target.maxRadius = Std.parseFloat(xml.node.maxRadius.att.value);
		target.maxRadiusVariance = Std.parseFloat(xml.node.maxRadiusVariance.att.value);
		target.minRadius = Std.parseFloat(xml.node.minRadius.att.value);
		if (xml.hasNode.minRadiusVariance)
		{
			target.minRadiusVariance = Std.parseFloat(xml.node.minRadiusVariance.att.value);
		}
		target.rotatePerSecond = Std.parseFloat(xml.node.rotatePerSecond.att.value);
		target.rotatePerSecondVariance = Std.parseFloat(xml.node.rotatePerSecondVariance.att.value);
		getColor(xml.node.startColor, target.startColor);
		getColor(xml.node.startColorVariance, target.startColorVariance);
		getColor(xml.node.finishColor, target.finishColor);
		getColor(xml.node.finishColorVariance, target.finishColorVariance);
		target.blendFuncSource = getBlendFunc(xml.node.blendFuncSource.att.value);
		target.blendFuncDestination = getBlendFunc(xml.node.blendFuncDestination.att.value);
		target.duration = Std.parseFloat(xml.node.duration.att.value);
		
		// new introduced properties //
		if (xml.hasNode.animation)
		{
			var anim:Access = xml.node.animation;
			if (anim.hasNode.isAnimated)
			{
				target.isAnimated = getBoolValue(anim.node.isAnimated.att.value);
			}
			if (anim.hasNode.firstFrame)
			{
				target.firstFrameName = anim.node.firstFrame.att.value;
				if (target.firstFrameName == "")
				{
					target.firstFrame = getIntValue(anim.node.firstFrame.att.value);
				}
			}
			if (anim.hasNode.lastFrame)
			{
				target.lastFrameName = anim.node.lastFrame.att.value;
				if (target.lastFrameName == "")
				{
					target.lastFrame = getIntValue(anim.node.lastFrame.att.value);
				}
			}
			if (anim.hasNode.numberOfAnimatedFrames)
			{
				target.animationLength = getIntValue(anim.node.numberOfAnimatedFrames.att.value);
				target.lastFrame = target.firstFrame + target.animationLength;
			}
			if (anim.hasNode.loops)
			{
				target.loops = Std.parseInt(anim.node.loops.att.value);
			}
			if (anim.hasNode.randomStartFrames)
			{
				target.randomStartFrames = getBoolValue(anim.node.randomStartFrames.att.value);
			}
		}
		
		if (xml.hasNode.tinted)
		{
			target.tinted = getBoolValue(xml.node.tinted.att.value);
		}
		if (xml.hasNode.premultipliedAlpha)
		{
			target.premultipliedAlpha = getBoolValue(xml.node.premultipliedAlpha.att.value);
		}
		if (xml.hasNode.spawnTime)
		{
			target.spawnTime = Std.parseFloat(xml.node.spawnTime.att.value);
		}
		if (xml.hasNode.fadeInTime)
		{
			target.fadeInTime = Std.parseFloat(xml.node.fadeInTime.att.value);
		}
		if (xml.hasNode.fadeOutTime)
		{
			target.fadeOutTime = Std.parseFloat(xml.node.fadeOutTime.att.value);
		}
		if (xml.hasNode.exactBounds)
		{
			target.excactBounds = getBoolValue(xml.node.exactBounds.att.value);
		}
		
		target.updateFrameLUT();
		
		return target;
	}
	
	private static function getFrameIdx(value:String, atlasXML:Xml):Int
	{
		if (atlasXML != null && Math.isNaN(Std.parseFloat(value)))
		{
			var idx:Int = -1;
			for (elem in atlasXML.firstElement().elementsNamed("SubTexture"))
			{
				idx++;
				if (elem.get("name") == value) return idx;
			}
			if (idx == -1) trace('frame "' + value + '" not found in atlas!');
			return idx;
		}
		else
		{
			return Std.parseInt(value);
		}
	}
	
	
	private static function getBoolValue(str:String):Bool
	{
		if (str == null) return false;
		var valueStr:String = str.toLowerCase();
		var valueInt:Int = Std.parseInt(str);
		return valueStr == "true" || valueInt > 0;
	}
	
	private static function getIntValue(str:String):Int
	{
		var result:Float = Std.parseFloat(str);
		return Math.isNaN(result) ? 0 : Std.int(result);
	}
	
	private static function getFloatValue(str:String):Float
	{
		var result:Float = Std.parseFloat(str);
		return Math.isNaN(result) ? 0 : result;
	}
	
	private static function getColor(element:Access, color:ColorArgb = null):ColorArgb
	{
		if (color == null) color = new ColorArgb();
		if (element.has.red) color.red = Std.parseFloat(element.att.red);
		if (element.has.green) color.green = Std.parseFloat(element.att.green);
		if (element.has.blue) color.blue = Std.parseFloat(element.att.blue);
		if (element.has.alpha) color.alpha = Std.parseFloat(element.att.alpha);
		return color;
	}
	
	private static function getBlendFunc(str:String):String
	{
		if (Math.isNaN(Std.parseFloat(str)))
		{
			switch (str)
			{
				case "DESTINATION_ALPHA" :
					return Context3DBlendFactor.DESTINATION_ALPHA;
					
				case "DESTINATION_COLOR" :
					return Context3DBlendFactor.DESTINATION_COLOR;
					
				case "ONE" :
					return Context3DBlendFactor.ONE;
					
				case "ONE_MINUS_DESTINATION_ALPHA" :
					return Context3DBlendFactor.ONE_MINUS_DESTINATION_ALPHA;
					
				case "ONE_MINUS_DESTINATION_COLOR" :
					return Context3DBlendFactor.ONE_MINUS_DESTINATION_COLOR;
					
				case "ONE_MINUS_SOURCE_ALPHA" :
					return Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
					
				case "ONE_MINUS_SOURCE_COLOR" :
					return Context3DBlendFactor.ONE_MINUS_SOURCE_COLOR;
					
				case "SOURCE_ALPHA" :
					return Context3DBlendFactor.SOURCE_ALPHA;
					
				case "SOURCE_COLOR" :
					return Context3DBlendFactor.SOURCE_COLOR;
					
				case "ZERO" :
					return Context3DBlendFactor.ZERO;
			}
		}
		
		var value:Int = getIntValue(str);
		switch (value)
		{
			case 0: 
				return Context3DBlendFactor.ZERO;
				
			case 1: 
				return Context3DBlendFactor.ONE;
				
			case 0x300: 
				return Context3DBlendFactor.SOURCE_COLOR;
				
			case 0x301: 
				return Context3DBlendFactor.ONE_MINUS_SOURCE_COLOR;
				
			case 0x302: 
				return Context3DBlendFactor.SOURCE_ALPHA;
				
			case 0x303: 
				return Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA;
				
			case 0x304: 
				return Context3DBlendFactor.DESTINATION_ALPHA;
				
			case 0x305: 
				return Context3DBlendFactor.ONE_MINUS_DESTINATION_ALPHA;
				
			case 0x306: 
				return Context3DBlendFactor.DESTINATION_COLOR;
				
			case 0x307: 
				return Context3DBlendFactor.ONE_MINUS_DESTINATION_COLOR;
				
			default : throw new ArgumentError("unsupported blending function: " + str);
		}
	}
	
	/**
	 * Parses the texture atlas xml and stores subtexture positions/dimensions in a look up table.
	 * If the texture is a SubTexture, it will also look for this frame in the texture atlas, to set this SubTexture as first frame.
	 *
	 * <p>Note: each frame will be stored once <i>per loop</i> in frameLUT since the modulo operator is expensive.</p>
	 */
	public function updateFrameLUT():Void
	{
		var st:SubTexture;
		var rect:Rectangle;
		
		mFrameLUT = new Vector<Frame>();
		
		if (atlasXML != null)
		{
			var w:Int = Std.int(texture.root.nativeWidth);
			var h:Int = Std.int(texture.root.nativeHeight);
			var frameCount:Int = 0;
			var subTexData:Array<Dynamic> = [];
			var entry:Dynamic;
			var matches:Array<Dynamic> = [];
			var x:Float;
			var y:Float;
			var width:Float;
			var height:Float;
			var rotated:Bool;
			//var idx:Int;
			
			for (elem in atlasXML.firstElement().elementsNamed("SubTexture"))
			{
				x = Std.parseFloat(elem.get("x"));
				y = Std.parseFloat(elem.get("y"));
				width = Std.parseFloat(elem.get("width"));
				height = Std.parseFloat(elem.get("height"));
				rotated = getBoolValue(elem.get("rotated"));
				subTexData.push({x:x, y:y, width:width, height:height, rotated:rotated, index:frameCount});
				frameCount++;
			}
			
			firstFrame = Std.int(Math.min(firstFrame, frameCount - 1));
			lastFrame = lastFrame == -1 ? frameCount : lastFrame;
			
			if (texture != null && Std.isOfType(texture, SubTexture))
			{
				// look for subtexture with same properties as the subtexture, on success we'll use it as firstFrame
				st = cast texture;
				rect = st.region;
				
				rect.x *= st.root.nativeWidth;
				rect.y *= st.root.nativeHeight;
				rect.width *= st.root.nativeWidth;
				rect.height *= st.root.nativeHeight;
				
				for (data in subTexData)
				{
					if (data.x == rect.x && data.y == rect.y && data.width == rect.width && data.height == rect.height)
					{
						matches.push(data);
					}
				}
				
				if (matches.length != 0 && firstFrame == 0)
				{
					if (matches[0].index >= 0)
					{
						firstFrame = matches[0].index;
					}
					matches.resize(0);
				}
			}
			
			lastFrame = Std.int(Math.max(firstFrame, Math.min(lastFrame, subTexData.length - 1)));
			
			var animationLoopLength:Int = lastFrame - firstFrame + 1;
			isAnimated = isAnimated && animationLoopLength > 1;
			loops = isAnimated ? loops + (randomStartFrames ? 1 : 0) : 1;
			animationLoopLength = isAnimated || randomStartFrames ? animationLoopLength : 1;
			
			for (l in 0...loops)
			{
				for (i in 0...animationLoopLength)
				{
					entry = subTexData[i + firstFrame];
					mFrameLUT[i + l * animationLoopLength] = new Frame(w, h, entry.x, entry.y, entry.width, entry.height, entry.rotated);
				}
			}
			
			//var mNumberOfFrames:Int = mFrameLUT.length - 1 - (randomStartFrames && isAnimated ? animationLoopLength : 0);
			//var mFrameLUTLength:Int = mFrameLUT.length - 1;
			isAnimated = isAnimated && mFrameLUT.length > 1;
			randomStartFrames = randomStartFrames && mFrameLUT.length > 1;
		}
		else
		{
			if (Std.isOfType(texture, SubTexture))
			{
				//subtexture
				st = cast texture;
				rect = st.region;
				var tr:Texture = texture.root;
				var frame:Frame = new Frame(tr.nativeWidth, tr.nativeHeight, rect.x, rect.y, rect.width, rect.height, st.rotated);
				mFrameLUT[0] = frame;
			}
			else
			{
				//rootTexture
				mFrameLUT[0] = new Frame(texture.width, texture.height, 0, 0, texture.width, texture.height, false);
			}
		}
		
		mFrameLUT.fixed = true;
	}
	
	public var firstFrameName(get, set):String;
	private function get_firstFrameName():String { return mFirstFrameName; }
	private function set_firstFrameName(value:String):String
	{
		var idx:Int = getFrameIdx(value, atlasXML);
		if (idx != -1)
		{
			firstFrame = idx;
			mFirstFrameName = value;
		}
		else
		{
			mFirstFrameName = "";
		}
		return value;
	}
	
	public var lastFrameName(get, set):String;
	private function get_lastFrameName():String { return mLastFrameName; }
	private function set_lastFrameName(value:String):String
	{
		var idx:Int = getFrameIdx(value, atlasXML);
		if (idx != -1)
		{
			lastFrame = idx;
			mLastFrameName = value;
		}
		else
		{
			mLastFrameName = "";
		}
		return mLastFrameName;
	}
	
}