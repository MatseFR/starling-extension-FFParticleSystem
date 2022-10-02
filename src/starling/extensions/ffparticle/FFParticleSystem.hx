package starling.extensions.ffparticle;

import haxe.Constraints.Function;
import openfl.Vector;
import openfl.display3D.Context3DBlendFactor;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import starling.animation.IAnimatable;
import starling.animation.Juggler;
import starling.core.Starling;
import starling.display.BlendMode;
import starling.display.DisplayObject;
import starling.errors.MissingContextError;
import starling.events.Event;
import starling.extensions.ColorArgb;
import starling.extensions.ffparticle.Particle;
import starling.extensions.ffparticle.rendering.FFParticleEffect;
import starling.extensions.ffparticle.style.FFParticleStyle;
import starling.extensions.ffparticle.utils.FFPS_LUT;
import starling.filters.FragmentFilter;
import starling.rendering.Painter;
import starling.textures.Texture;
import starling.textures.TextureSmoothing;
import starling.utils.MatrixUtil;
import starling.utils.Max;

/**
 * <p>The FFParticleSystem is an extension for the <a target="_top" href="http://starling-framework.org">Starling Framework v2</a>.
 * It's basically an optimized version of the original ParticleSystem.
 *
 * <p>In addition it comes with a few new features:
 * <ul>
 *   <li>particle pooling</li>
 *   <li>multi buffering</li>
 *   <li>batching (of particle systems)</li>
 *   <li>animated Texture loops</li>
 *   <li>random start frame</li>
 *   <li>ATF support</li>
 *   <li>filter support</li>
 *   <li>optional custom sorting, code and variables</li>
 *   <li>calculating exact bounds (optional)</li>
 *   <li>spawnTime</li>
 *   <li>fadeInTime</li>
 *   <li>fadeOutTime</li>
 *   <li>emit angle aligned particle rotation</li>
 * </ul>
 * </p>
 *
 * <p>This extension has been kindly sponsored by the fabulous <a target="_top" href="http://colinnorthway.com/">Colin Northway</a>. :)</p>
 *
 * <a target="_top" href="http://www.flintfabrik.de/blog/">Live Demo</a>
 *
 * @author Michael Trenkler
 * @see http://flintfabrik.de
 * @see #FFParticleSystem()
 * @see #initPool() FFParticleSystem.initPool()
 */
class FFParticleSystem extends DisplayObject implements IAnimatable
{
	public static inline var EMITTER_TYPE_GRAVITY:Int = 0;
	public static inline var EMITTER_TYPE_RADIAL:Int = 1;
	
	/**
	 * If the systems duration exceeds as well as all particle lifespans, a complete event is fired and
	 * the system will be stopped. If this value is set to true, the particles will be returned to the pool.
	 * This does not affect any manual calls of stop.
	 * @see #start()
	 * @see #stop()
	 */
	public static var AUTO_CLEAR_ON_COMPLETE:Bool = true;
	
	/**
	 * If the systems duration exceeds as well as all particle lifespans, a complete event is fired and
	 * the system will be stopped. If this value is set to true, the particles will be returned to the pool.
	 * This does not affect any manual calls of stop.
	 * @see #start()
	 * @see #stop()
	 */
	public var autoClearOnComplete:Bool = AUTO_CLEAR_ON_COMPLETE;
	/**
	 * Forces the the sort flag for custom sorting on every frame instead of setting it when particles are removed.
	 */
	public var forceSortFlag:Bool = false;
	
	/**
	 * Set this Boolean to automatically add/remove the system to/from juggler, on calls of start()/stop().
	 * @see #start()
	 * @see #stop()
	 * @see #defaultJuggler
	 * @see #juggler()
	 */
	public static var automaticJugglerManagement:Bool = true;
	
	/**
	 * Default juggler to use when <a href="#automaticJugglerManagement">automaticJugglerManagement</a>
	 * is active (by default this value is the Starling's juggler).
	 * Setting this value will affect only new particle system instances.
	 * Juggler to use can be also manually set by particle system instance.
	 * @see #automaticJugglerManagement
	 * @see #juggler()
	 */
	public static var defaultJuggler:Juggler;// = Starling.current.juggler;
	
	private var __juggler:Juggler = defaultJuggler;
	
	private var __batched:Bool = false;
	private var __bounds:Rectangle;
	private var __disposed:Bool = false;
	private var __numParticles:Int = 0;
	private var __numBatchedParticles:Int = 0;
	private var __playing:Bool = false;
	
	private var __batching:Bool = true;
	private var __completed:Bool;
	private var __customFunction:Vector<Particle>->Int->Void;
	private var __fadeInTime:Float = 0;
	private var __fadeOutTime:Float = 0;
	private var ___filter:FragmentFilter;
	private var __randomStartFrames:Bool = false;
	private var __smoothing:String = TextureSmoothing.BILINEAR;
	private var __sortFunction:Particle->Particle->Int;
	private var __spawnTime:Float = 0;
	private var ___alpha:Float = 1;
	private var __texture:Texture;
	private var __tinted:Bool = false;
	private var __premultipliedAlpha:Bool = false;
	private var __exactBounds:Bool = false;
	private var __effect:FFParticleEffect;
	private var __style:FFParticleStyle;
	
	private static var _defaultEffect:Class<Dynamic>;
	private static var _defaultStyle:Class<Dynamic>;
	
	/**
	 * Default styles to test against for fallback initialization.
	 */
	public static var styles:Vector<Class<Dynamic>> = new Vector<Class<Dynamic>>(0, false, [FFParticleStyle]);
	
	private static var registeredEffects:Vector<Class<Dynamic>> = new Vector<Class<Dynamic>>(0, false);
	
	public static function registerEffect(effectClass:Class<Dynamic>):Void
	{
		if (registeredEffects.indexOf(effectClass) == -1)
		{
			registeredEffects.push(effectClass);
		}
	}
	
	public static function unregisterEffect(effectClass:Class<Dynamic>):Void
	{
		var idx:Int = registeredEffects.indexOf(effectClass);
		if (idx != -1)
		{
			registeredEffects.splice(idx, 1);
		}
	}
	
	public static var defaultStyle(get, set):Class<Dynamic>;
	private static function get_defaultStyle():Class<Dynamic>
	{
		if (_defaultStyle != null)
		{
			return _defaultStyle;
		}
		
		for (effectClass in styles)
		{
			//if (effectClass != null && effectClass.effectType != null && effectClass.effectType.isSupported)
			if (effectClass != null && Reflect.getProperty(effectClass, "effectType") != null && Reflect.getProperty(Reflect.getProperty(effectClass, "effectType"), "isSupported"))
			{
				trace("[FFParticleSystem] defaultStyle set to " + Type.getClassName(effectClass));
				_defaultStyle = effectClass;
				//_defaultEffect = _defaultStyle.effectType;
				_defaultEffect = Reflect.getProperty(_defaultStyle, "effectType");
				return _defaultStyle;
			}
		}
		trace('[FFParticleSystem] no supported style found');
		_defaultStyle = FFParticleStyle;
		//_defaultEffect = _defaultStyle.effectType;
		_defaultEffect = Reflect.getProperty(_defaultStyle, "effectType");
		return _defaultStyle;
	}
	private static function set_defaultStyle(styleClass:Class<Dynamic>):Class<Dynamic>
	{
		if (styleClass == null)
		{
			_defaultStyle = null;
			_defaultEffect = null;
		}
		//else if (styleClass.effectType.isSupported)
		else if (Reflect.getProperty(Reflect.getProperty(styleClass, "EFFECT_TYPE"), "isSupported"))
		{
			trace("[FFParticleSystem] defaultStyle set to " + Type.getClassName(styleClass));
			_defaultStyle = styleClass;
			_defaultEffect = Reflect.getProperty(styleClass, "EFFECT_TYPE");
		}
		return styleClass;
	}
	
	// particles / data / buffers
	
	private static var _particlePool:Vector<Particle>;
	private static var _poolSize:UInt = 0;
	private var __particles:Vector<Particle>;
	
	// emitter configuration
	private var __emitterType:Int; // emitterType
	private var __emitterXVariance:Float; // sourcePositionVariance x
	private var __emitterYVariance:Float; // sourcePositionVariance y
	
	// particle configuration
	private var __maxNumParticles:Int; // maxParticles
	private var __lifespan:Float; // particleLifeSpan
	private var __lifespanVariance:Float; // particleLifeSpanVariance
	private var __startSize:Float; // startParticleSize
	private var __startSizeVariance:Float; // startParticleSizeVariance
	private var __endSize:Float; // finishParticleSize
	private var __endSizeVariance:Float; // finishParticleSizeVariance
	private var __emitAngle:Float; // angle
	private var __emitAngleVariance:Float; // angleVariance
	private var __emitAngleAlignedRotation:Bool = false;
	private var __startRotation:Float; // rotationStart
	private var __startRotationVariance:Float; // rotationStartVariance
	private var __endRotation:Float; // rotationEnd
	private var __endRotationVariance:Float; // rotationEndVariance
	
	// gravity configuration
	private var __speed:Float; // speed
	private var __speedVariance:Float; // speedVariance
	private var __gravityX:Float; // gravity x
	private var __gravityY:Float; // gravity y
	private var __radialAcceleration:Float; // radialAcceleration
	private var __radialAccelerationVariance:Float; // radialAccelerationVariance
	private var __tangentialAcceleration:Float; // tangentialAcceleration
	private var __tangentialAccelerationVariance:Float; // tangentialAccelerationVariance
	
	// radial configuration 
	private var __maxRadius:Float; // maxRadius
	private var __maxRadiusVariance:Float; // maxRadiusVariance
	private var __minRadius:Float; // minRadius
	private var __minRadiusVariance:Float; // minRadiusVariance
	private var __rotatePerSecond:Float; // rotatePerSecond
	private var __rotatePerSecondVariance:Float; // rotatePerSecondVariance
	
	// color configuration
	private var __startColor:ColorArgb = new ColorArgb(1, 1, 1, 1); // startColor
	private var __startColorVariance:ColorArgb = new ColorArgb(0, 0, 0, 0); // startColorVariance
	private var __endColor:ColorArgb = new ColorArgb(1, 1, 1, 1); // finishColor
	private var __endColorVariance:ColorArgb = new ColorArgb(0, 0, 0, 0); // finishColorVariance
	
	// texture animation
	private var __animationLoops:UInt = 1;
	private var __animationLoopLength:Int = 1;
	private var __firstFrame:UInt = 0;
	private var __frameLUT:Vector<Frame>;
	private var __frameLUTLength:UInt;
	private var __frameTime:Float;
	private var __lastFrame:UInt = Max.UINT_MAX_VALUE;
	private var __numberOfFrames:Int = 1;
	private var __textureAnimation:Bool = false;
	
	private var __blendFuncSource:String;
	private var __blendFuncDestination:String;
	private var __emissionRate:Float; // emitted particles per second
	private var __emissionTime:Float = -1;
	private var __emissionTimePredefined:Float = -1;
	private var __emitterX:Float = 0.0;
	private var __emitterY:Float = 0.0;
	
	/**
	 * A point to set your emitter position.
	 * @see #emitterX
	 * @see #emitterY
	 */
	public var emitter:Point = new Point();
	public var ignoreSystemAlpha:Bool = true;
	
	private var __emitterObject:Dynamic;
	
	/** Helper objects. */
	
	private static var _helperMatrix:Matrix = new Matrix();
	private static var _helperPoint:Point = new Point();
	private static var _renderAlpha:Vector<Float> = new Vector<Float>(0, false, [1.0, 1.0, 1.0, 1.0]);
	private static var _instances:Vector<FFParticleSystem> = new Vector<FFParticleSystem>();
	private static var _fixedPool:Bool = false;
	private static var _randomSeed:Int = 1;
	
	/*
	   Too bad, [Inline] doesn't work in inlined functions?!
	   This has been inlined by hand in initParticle() a lot
	   [Inline]
	   private static function random():Number
	   {
	   return ((sRandomSeed = (sRandomSeed * 16807) & 0x7FFFFFFF) / 0x80000000);
	   }
	 */
	
	/**
	 * Creates a FFParticleSystem instance.
	 *
	 * <p><strong>Note:  </strong>For best performance setup the system buffers by calling
	 * <a href="#FFParticleSystem.initPool()">FFParticleSystem.initPool()</a> <strong>before</strong> you create any instances!</p>
	 *
	 * <p>The config file has to be a XML in the following format, known as .pex file</p>
	 *
	 * <p><strong>Note:  </strong>It's strongly recommended to use textures with mipmaps.</p>
	 *
	 * <p><strong>Note:  </strong>You shouldn't create any instance before Starling created the context. Just wait some
	 * frames. Otherwise this might slow down Starling's creation process, since every FFParticleSystem instance is listening
	 * for onContextCreated events, which are necessary to handle a context loss properly.</p>
	 *
	 * @example The following example shows a complete .pex file, starting with the newly introduced properties of this version:
	   <listing version="3.0">
	   &lt;?xml version="1.0"?&gt;
	   &lt;particleEmitterConfig&gt;
	
	   &lt;animation&gt;
	   &lt;isAnimated value="1"/&gt;
	   &lt;loops value="10"/&gt;
	   &lt;firstFrame value="0"/&gt;
	   &lt;lastFrame value="-1"/&gt;
	   &lt;/animation&gt;
	
	   &lt;spawnTime value="0.02"/&gt;
	   &lt;fadeInTime value="0.1"/&gt;
	   &lt;fadeOutTime value="0.1"/&gt;
	   &lt;tinted value="1"/&gt;
	   &lt;emitAngleAlignedRotation value="1"/&gt;
	
	   &lt;texture name="texture.png"/&gt;
	   &lt;sourcePosition x="300.00" y="300.00"/&gt;
	   &lt;sourcePositionVariance x="0.00" y="200"/&gt;
	   &lt;speed value="150.00"/&gt;
	   &lt;speedVariance value="75"/&gt;
	   &lt;particleLifeSpan value="10"/&gt;
	   &lt;particleLifespanVariance value="2"/&gt;
	   &lt;angle value="345"/&gt;
	   &lt;angleVariance value="25.00"/&gt;
	   &lt;gravity x="0.00" y="0.00"/&gt;
	   &lt;radialAcceleration value="0.00"/&gt;
	   &lt;tangentialAcceleration value="0.00"/&gt;
	   &lt;radialAccelVariance value="0.00"/&gt;
	   &lt;tangentialAccelVariance value="0.00"/&gt;
	   &lt;startColor red="1" green="1" blue="1" alpha="1"/&gt;
	   &lt;startColorVariance red="1" green="1" blue="1" alpha="0"/&gt;
	   &lt;finishColor red="1" green="1" blue="1" alpha="1"/&gt;
	   &lt;finishColorVariance red="0" green="0" blue="0" alpha="0"/&gt;
	   &lt;maxParticles value="500"/&gt;
	   &lt;startParticleSize value="50"/&gt;
	   &lt;startParticleSizeVariance value="25"/&gt;
	   &lt;finishParticleSize value="25"/&gt;
	   &lt;FinishParticleSizeVariance value="25"/&gt;
	   &lt;duration value="-1.00"/&gt;
	   &lt;emitterType value="0"/&gt;
	   &lt;maxRadius value="100.00"/&gt;
	   &lt;maxRadiusVariance value="0.00"/&gt;
	   &lt;minRadius value="0.00"/&gt;
	   &lt;rotatePerSecond value="0.00"/&gt;
	   &lt;rotatePerSecondVariance value="0.00"/&gt;
	   &lt;blendFuncSource value="770"/&gt;
	   &lt;blendFuncDestination value="771"/&gt;
	   &lt;rotationStart value="0.00"/&gt;
	   &lt;rotationStartVariance value="0.00"/&gt;
	   &lt;rotationEnd value="0.00"/&gt;
	   &lt;rotationEndVariance value="0.00"/&gt;
	   &lt;emitAngleAlignedRotation value="0"/&gt;
	   &lt;/particleEmitterConfig&gt;
	   </listing>
	 *
	 * @param	config A SystemOptions instance
	 * @param	style The style setting the rendering effect of this instance
	 *
	 * @see #initPool() FFParticleSystem.initPool()
	 */
	public function new(config:SystemOptions, style:FFParticleStyle = null) 
	{
		super();
		
		if (config == null)
		{
			throw new ArgumentError("config must not be null");
		}
		
		_instances.push(this);
		parseSystemOptions(config);
		//if (style != null && !style.effectType.isSupported)
		if (style != null && !Reflect.getProperty(style.effectType, "isSupported"))
		{
			throw new Error("[FFParticleSystem] style not supported!");
		}
		setStyle(style, false);
		initInstance();
	}
	
	private function addedToStageHandler(e:starling.events.Event):Void
	{
		__effect.maxCapacity = __maxNumParticles;
		
		if (e != null)
		{
			getParticlesFromPool();
			if (__playing)
				start(__emissionTime);
		}
	}
	
	/**
	 * Calculating property changes of a particle.
	 * @param	aParticle
	 * @param	passedTime
	 */
	@:final
	private inline function advanceParticle(particle:Particle, passedTime:Float):Void
	{
		var restTime:Float = particle.totalTime - particle.currentTime;
		passedTime = restTime > passedTime ? passedTime : restTime;
		particle.currentTime += passedTime;
		
		if (__emitterType == EMITTER_TYPE_RADIAL)
		{
			particle.emitRotation += particle.emitRotationDelta * passedTime;
			particle.emitRadius += particle.emitRadiusDelta * passedTime;
			var angle:UInt = Std.int(particle.emitRotation * 325.94932345220164765467394738691) & 2047;
			particle.x = __emitterX - FFPS_LUT.cos[angle] * particle.emitRadius;
			particle.y = __emitterY - FFPS_LUT.sin[angle] * particle.emitRadius;
		}
		else if (particle.radialAcceleration != 0 || particle.tangentialAcceleration != 0)
		{
			var distanceX:Float = particle.x - particle.startX;
			var distanceY:Float = particle.y - particle.startY;
			var distanceScalar:Float = Math.sqrt(distanceX * distanceX + distanceY * distanceY);
			if (distanceScalar < 0.01)
				distanceScalar = 0.01;
			
			var radialX:Float = distanceX / distanceScalar;
			var radialY:Float = distanceY / distanceScalar;
			var tangentialX:Float = radialX;
			var tangentialY:Float = radialY;
			
			radialX *= particle.radialAcceleration;
			radialY *= particle.radialAcceleration;
			
			var newY:Float = tangentialX;
			tangentialX = -tangentialY * particle.tangentialAcceleration;
			tangentialY = newY * particle.tangentialAcceleration;
			
			particle.velocityX += passedTime * (__gravityX + radialX + tangentialX);
			particle.velocityY += passedTime * (__gravityY + radialY + tangentialY);
			particle.x += particle.velocityX * passedTime;
			particle.y += particle.velocityY * passedTime;
		}
		else
		{
			particle.velocityX += passedTime * __gravityX;
			particle.velocityY += passedTime * __gravityY;
			particle.x += particle.velocityX * passedTime;
			particle.y += particle.velocityY * passedTime;
		}
		
		particle.scale += particle.scaleDelta * passedTime;
		particle.rotation += particle.rotationDelta * passedTime;
		
		if (__textureAnimation)
		{
			particle.frame = particle.frame + particle.frameDelta * passedTime;
			particle.frameIdx = Std.int(particle.frame);
			if (particle.frameIdx > __frameLUTLength)
				particle.frameIdx = __frameLUTLength;
		}
		
		if (__tinted)
		{
			particle.colorRed += particle.colorDeltaRed * passedTime;
			particle.colorGreen += particle.colorDeltaGreen * passedTime;
			particle.colorBlue += particle.colorDeltaBlue * passedTime;
			particle.colorAlpha += particle.colorDeltaAlpha * passedTime;
		}
	}
	
	/**
	 * Loops over all particles and adds/removes/advances them according to the current time;
	 * writes the data directly to the raw vertex data.
	 *
	 * <p>Note: This function is called by Starling's Juggler, so there will most likely be no reason for
	 * you to call it yourself, unless you want to implement slow/quick motion effects.</p>
	 *
	 * @param	passedTime
	 */
	public function advanceTime(passedTime:Float):Void
	{
		setRequiresRedraw();
		var sortFlag:Bool = forceSortFlag;
		
		__frameTime += passedTime;
		if (__particles == null)
		{
			if (__emissionTime > 0)
			{
				__emissionTime -= passedTime;
				if (__emissionTime != Max.MAX_VALUE)
					__emissionTime = Math.max(0.0, __emissionTime - passedTime);
			}
			else
			{
				stop(autoClearOnComplete);
				complete();
				return;
			}
			return;
		}
		
		var particleIndex:Int = 0;
		var particle:Particle;
		if (__emitterObject != null)
		{
			__emitterX = emitter.x = __emitterObject.x;
			__emitterY = emitter.y = __emitterObject.y;
		}
		else
		{
			__emitterX = emitter.x;
			__emitterY = emitter.y;
		}
		
		// advance existing particles
		while (particleIndex < __numParticles)
		{
			particle = __particles[particleIndex];
			
			if (particle.currentTime < particle.totalTime)
			{
				advanceParticle(particle, passedTime);
				++particleIndex;
			}
			else
			{
				particle.active = false;
				
				if (particleIndex != --__numParticles)
				{
					var nextParticle:Particle = __particles[__numParticles];
					__particles[__numParticles] = particle; // put dead p at end
					__particles[particleIndex] = nextParticle;
					sortFlag = true;
				}
				
				if (__numParticles == 0 && __emissionTime < 0)
				{
					stop(autoClearOnComplete);
					complete();
					return;
				}
			}
		}
		
		// create and advance new particles
		
		if (__emissionTime > 0)
		{
			var timeBetweenParticles:Float = 1.0 / __emissionRate;
			
			while (__frameTime > 0 && __numParticles < __effect.maxCapacity)
			{
				if (__numParticles == __effect.capacity)
					__effect.raiseCapacity(__effect.capacity);
				
				particle = __particles[__numParticles];
				initParticle(particle);
				advanceParticle(particle, __frameTime);
				
				++__numParticles;
				
				__frameTime -= timeBetweenParticles;
			}
			
			if (__emissionTime != Max.MAX_VALUE)
				__emissionTime = Math.max(0.0, __emissionTime - passedTime);
		}
		else if (!__completed && __numParticles == 0)
		{
			stop(autoClearOnComplete);
			complete();
			return;
		}
		
		// update vertex data
		
		if (__particles == null)
			return;
		
		if (__customFunction != null)
		{
			__customFunction(__particles, __numParticles);
		}
		
		if (sortFlag && __sortFunction != null)
		{
			__particles.sort(__sortFunction);
			
		}
		
		// upadate particle fading factors
		
		if (__spawnTime != 0 || __fadeInTime != 0 || __fadeOutTime != 0)
		{
			var deltaTime:Float;
			for (i in 0...__numParticles)
			{
				particle = __particles[i];
				deltaTime = particle.currentTime / particle.totalTime;
				
				if (__spawnTime != 0)
					particle.spawnFactor = deltaTime < __spawnTime ? deltaTime / __spawnTime : 1;
				
				if (__fadeInTime != 0)
					particle.fadeInFactor = deltaTime < __fadeInTime ? deltaTime / __fadeInTime : 1;
				
				if (__fadeOutTime != 0)
				{
					deltaTime = 1 - deltaTime;
					particle.fadeOutFactor = deltaTime < __fadeOutTime ? deltaTime / __fadeOutTime : 1;
				}
			}
		}
	}
	
	/**
	 * Remaining initiation of the current instance (for JIT optimization).
	 */
	private function initInstance():Void
	{
		__emissionRate = __maxNumParticles / __lifespan;
		__emissionTime = 0.0;
		__frameTime = 0.0;
		
		__effect.maxCapacity = __maxNumParticles;
		if (!FFParticleSystem.poolCreated)
			initPool();
		
		if (defaultJuggler == null)
			defaultJuggler = Starling.current.juggler;
		
		addEventListener(starling.events.Event.ADDED_TO_STAGE, addedToStageHandler);
		addedToStageHandler(null);
	}
	
	/**
	 * Initiation of anything shared between all systems. Call this function <strong>before</strong> you create any instance
	 * to set a custom size of your pool and Stage3D buffers.
	 *
	 * <p>If you don't call this method explicitly before createing an instance, the first constructor will
	 * create a default pool and buffers; which is OK but might slow down especially mobile devices.</p>
	 *
	 * <p>Set the <em>poolSize</em> to the absolute maximum of particles created by all particle systems together. Creating the pool
	 * will only hit you once (unless you dispose/recreate it/context loss). It will not harm runtime, but a number way to big will waste
	 * memory and take a longer creation process.</p>
	 *
	 * <p>If you're satisfied with the number of particles and want to avoid any accidental enhancement of the pool, set <em>fixed</em>
	 * to true. If you're not sure how much particles you will need, and fear particle systems might not show up more than the consumption
	 * of memory and a little slowdown for newly created particles, set <em>fixed</em> to false.</p>
	 *
	 * <p>The <em>bufferSize</em> determins how many particles can be rendered by one particle system. The <strong>minimum</strong>
	 * should be the maxParticles value set number in your pex file.</p>
	 * <p><strong>Note:   </strong>The bufferSize is always fixed!</p>
	 * <p><strong>Note:   </strong>If you want to profit from batching, take a higher value, e. g. enough for 5 systems. But avoid
	 * choosing an unrealistic high value, since the complete buffer will have to be uploaded each time a particle system (batch) is drawn.</p>
	 *
	 * <p>The <em>numberOfBuffers</em> sets the amount of vertex buffers in use by the particle systems. Multi buffering can avoid stalling of
	 * the GPU but will also increases it's memory consumption.</p>
	 *
	 * @param	poolSize Length of the particle pool.
	 * @param	fixed Whether the poolSize has a fixed length.
	 *
	 * @see #FFParticleSystem()
	 * @see #dispose() FFParticleSystem.dispose()
	 * @see #disposePool() FFParticleSystem.disposePool()
	 */
	public static function initPool(poolSize:UInt = 16383, fixed:Bool = false):Void
	{
		FFPS_LUT.init();
		initParticlePool(poolSize, fixed);
		
		if (defaultJuggler == null)
			defaultJuggler = Starling.current.juggler;
		
		// handle a lost device context
		Starling.current.stage3D.addEventListener(flash.events.Event.CONTEXT3D_CREATE, onContextCreated, false, 0, true);
	}
	
	public static var poolCreated(get, never):Bool;
	public static function get_poolCreated():Bool
	{
		return (_particlePool != null && _particlePool.length != 0);
	}
	
	private static function initParticlePool(poolSize:UInt = 16383, fixed:Bool = false):Void
	{
		if (_particlePool == null)
		{
			_fixedPool = fixed;
			_particlePool = new Vector<Particle>();
			_poolSize = poolSize;
			for (i in 0...poolSize)
			{
				_particlePool[i] = new Particle();
			}
		}
	}
	
	/**
	 * Sets the start values for a newly created particle, according to your system settings.
	 *
	 * <p>Note:
	 * 		The following snippet ...
	 *
	 * 			(((sRandomSeed = (sRandomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
	 *
	 * 		... is a pseudo random number generator; directly inlined; to reduce function calls.
	 * 		Unfortunatelly it seems impossible to inline within inline functions.</p>
	 *
	 * @param	aParticle
	 */
	@:final
	inline private function initParticle(particle:Particle):Void
	{
		// for performance reasons, the random variances are calculated inline instead
		// of calling a function
		
		var lifespan:Float = __lifespan + __lifespanVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (lifespan <= 0.0)
			return;
		
		particle.active = true;
		particle.currentTime = 0.0;
		particle.totalTime = lifespan;
		
		particle.x = __emitterX + __emitterXVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.y = __emitterY + __emitterYVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.startX = __emitterX;
		particle.startY = __emitterY;
		
		var angleDeg:Float = (__emitAngle + __emitAngleVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0));
		var angle:UInt = Std.int(angleDeg * 325.94932345220164765467394738691) & 2047;
		var speed:Float = __speed + __speedVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.velocityX = speed * FFPS_LUT.cos[angle];
		particle.velocityY = speed * FFPS_LUT.sin[angle];
		
		particle.emitRadius = __maxRadius + __maxRadiusVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.emitRadiusDelta = __maxRadius / lifespan;
		particle.emitRadius = __maxRadius + __maxRadiusVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.emitRadiusDelta = (__minRadius + __minRadiusVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0) - particle.emitRadius) / lifespan;
		particle.emitRotation = __emitAngle + __emitAngleVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.emitRotationDelta = __rotatePerSecond + __rotatePerSecondVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.radialAcceleration = __radialAcceleration + __radialAccelerationVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		particle.tangentialAcceleration = __tangentialAcceleration + __tangentialAccelerationVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		
		var startSize:Float = __startSize + __startSizeVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		var endSize:Float = __endSize + __endSizeVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (startSize < 0.1)
			startSize = 0.1;
		if (endSize < 0.1)
			endSize = 0.1;
		
		var firstFrameWidth:Float = __frameLUT[0].particleHalfWidth * 2;
		particle.scale = startSize / firstFrameWidth;
		particle.scaleDelta = ((endSize - startSize) / lifespan) / firstFrameWidth;
		particle.frame = __randomStartFrames ? __animationLoopLength * ((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 2147483648) : 0;
		particle.frameIdx = Std.int(particle.frame);
		particle.frameDelta = __numberOfFrames / lifespan;
		
		// colors
		var startColorRed:Float = __startColor.red;
		var startColorGreen:Float = __startColor.green;
		var startColorBlue:Float = __startColor.blue;
		var startColorAlpha:Float = __startColor.alpha;
		
		if (__startColorVariance.red != 0)
			startColorRed += __startColorVariance.red * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (__startColorVariance.green != 0)
			startColorGreen += __startColorVariance.green * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (__startColorVariance.blue != 0)
			startColorBlue += __startColorVariance.blue * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (__startColorVariance.alpha != 0)
			startColorAlpha += __startColorVariance.alpha * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		
		var endColorRed:Float = __endColor.red;
		var endColorGreen:Float = __endColor.green;
		var endColorBlue:Float = __endColor.blue;
		var endColorAlpha:Float = __endColor.alpha;
		
		if (__endColorVariance.red != 0)
			endColorRed += __endColorVariance.red * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (__endColorVariance.green != 0)
			endColorGreen += __endColorVariance.green * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (__endColorVariance.blue != 0)
			endColorBlue += __endColorVariance.blue * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		if (__endColorVariance.alpha != 0)
			endColorAlpha += __endColorVariance.alpha * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		
		particle.colorRed = startColorRed;
		particle.colorGreen = startColorGreen;
		particle.colorBlue = startColorBlue;
		particle.colorAlpha = startColorAlpha;
		
		particle.colorDeltaRed = (endColorRed - startColorRed) / lifespan;
		particle.colorDeltaGreen = (endColorGreen - startColorGreen) / lifespan;
		particle.colorDeltaBlue = (endColorBlue - startColorBlue) / lifespan;
		particle.colorDeltaAlpha = (endColorAlpha - startColorAlpha) / lifespan;
		
		// rotation
		var startRotation:Float;
		var endRotation:Float;
		if (__emitAngleAlignedRotation)
		{
			startRotation = angleDeg + __startRotation + __startRotationVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
			endRotation = angleDeg + __endRotation + __endRotationVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		}
		else
		{
			startRotation = __startRotation + __startRotationVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
			endRotation = __endRotation + __endRotationVariance * (((_randomSeed = (_randomSeed * 16807) & 0x7FFFFFFF) / 0x40000000) - 1.0);
		}
		
		particle.rotation = startRotation;
		particle.rotationDelta = (endRotation - startRotation) / lifespan;
		
		particle.spawnFactor = 1;
		particle.fadeInFactor = 1;
		particle.fadeOutFactor = 1;
	}
	
	/**
	 * Setting the complete state and throwing the event.
	 */
	private function complete():Void
	{
		if (!__completed)
		{
			__completed = true;
			dispatchEventWith(starling.events.Event.COMPLETE);
		}
	}
	
	/**
	 * Disposes the system instance and frees it's resources
	 */
	public override function dispose():Void
	{
		style.setTarget(null);
		_instances.splice(_instances.indexOf(this), 1);
		removeEventListener(starling.events.Event.ADDED_TO_STAGE, addedToStageHandler);
		stop(true);
		__batched = false;
		super.filter = ___filter = null;
		removeFromParent();
		
		super.dispose();
		__disposed = true;
	}
	
	/**
	 *  Whether the system has been disposed earlier
	 */
	public var disposed(get, never):Bool;
	private function get_disposed():Bool
	{
		return __disposed;
	}
	
	/**
	 * Disposes the created particle pool and Stage3D buffers, shared by all instances.
	 * Warning: Therefore all instances will get disposed as well!
	 */
	public static function disposeAll():Void
	{
		Starling.current.stage3D.removeEventListener(flash.events.Event.CONTEXT3D_CREATE, onContextCreated);
		
		//for (var i:int = registeredEffects.length - 1; i >= 0; --i)
		//{
			//var effectClass:Class = registeredEffects[i];
			//effectClass['disposeBuffers']();
		//}
		for (effectClass in registeredEffects)
		{
			Reflect.callMethod(effectClass, Reflect.field(effectClass, "disposeBuffers"), null);
		}
		disposePool();
	}
	
	/**
	 * Disposes all system instances
	 */
	public static function disposeInstances():Void
	{
		for (instance in _instances)
		{
			instance.dispose();
		}
	}
	
	/**
	 * Clears the current particle pool.
	 * Warning: Also disposes all system instances!
	 */
	public static function disposePool():Void
	{
		disposeInstances();
		_particlePool = null;
	}
	
	/** @inheritDoc */
	override function set_filter(value:FragmentFilter):FragmentFilter 
	{
		if (!__batched)
			___filter = value;
		return super.filter = value;
	}
	
	/**
	 * Returns a rectangle in stage dimensions (to support filters) if possible, or an empty rectangle
	 * at the particle system's position. Calculating the actual bounds might be too expensive.
	 */
	public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle = null):Rectangle
	{
		if (resultRect == null)
			resultRect = new Rectangle();
		
		if (targetSpace == this || targetSpace == null) // optimization
		{
			if (__bounds != null)
				resultRect = __bounds;
			else if (stage != null)
			{
				// return full stage size to support filters ... may be expensive, but we have no other options, do we?
				resultRect.x = 0;
				resultRect.y = 0;
				resultRect.width = stage.stageWidth;
				resultRect.height = stage.stageHeight;
			}
			else
			{
				getTransformationMatrix(targetSpace, _helperMatrix);
				MatrixUtil.transformCoords(_helperMatrix, 0, 0, _helperPoint);
				resultRect.x = _helperPoint.x;
				resultRect.y = _helperPoint.y;
				resultRect.width = resultRect.height = 0;
			}
			return resultRect;
		}
		else if (targetSpace != null)
		{
			if (__bounds != null)
			{
				getTransformationMatrix(targetSpace, _helperMatrix);
				MatrixUtil.transformCoords(_helperMatrix, __bounds.x, __bounds.y, _helperPoint);
				resultRect.x = _helperPoint.x;
				resultRect.y = _helperPoint.y;
				MatrixUtil.transformCoords(_helperMatrix, __bounds.width, __bounds.height, _helperPoint);
				resultRect.width = _helperPoint.x;
				resultRect.height = _helperPoint.y;
			}
			else if (stage != null)
			{
				// return full stage size to support filters ... may be pretty expensive
				resultRect.x = 0;
				resultRect.y = 0;
				resultRect.width = stage.stageWidth;
				resultRect.height = stage.stageHeight;
			}
			else
			{
				getTransformationMatrix(targetSpace, _helperMatrix);
				MatrixUtil.transformCoords(_helperMatrix, 0, 0, _helperPoint);
				resultRect.x = _helperPoint.x;
				resultRect.y = _helperPoint.y;
				resultRect.width = resultRect.height = 0;
			}
			
			return resultRect;
		}
		return resultRect = __bounds;
	}
	
	/**
	 * Takes particles from the pool and assigns them to the system instance.
	 * If the particle pool doesn't have enough unused particles left, it will
	 * - either create new particles, if the pool size is expandable
	 * - or return false, if the pool size has been fixed
	 *
	 * Returns a Boolean for success
	 *
	 * @return
	 */
	private function getParticlesFromPool():Bool
	{
		if (__particles != null)
			return true;
		
		if (__disposed)
			return false;
		
		if (_particlePool.length >= __maxNumParticles)
		{
			__particles = new Vector<Particle>(__maxNumParticles, true);
			var particleIdx:Int = __maxNumParticles;
			var poolIdx:Int = _particlePool.length;
			
			_particlePool.fixed = false;
			while (particleIdx != 0)
			{
				__particles[--particleIdx] = _particlePool[--poolIdx];
				__particles[particleIdx].active = false;
				_particlePool[poolIdx] = null;
			}
			_particlePool.length = poolIdx;
			_particlePool.fixed = true;
			
			__numParticles = 0;
			__effect.raiseCapacity(__maxNumParticles - __particles.length);
			return true;
		}
		
		if (_fixedPool)
			return false;
		
		var i:Int = _particlePool.length - 1;
		var len:Int = __maxNumParticles;
		_particlePool.fixed = false;
		while (++i < len)
			_particlePool[i] = new Particle();
		_particlePool.fixed = true;
		return getParticlesFromPool();
	}
	
	/**
	 * (Re)Inits the system (after context loss)
	 * @param	event
	 */
	private static function onContextCreated(event:flash.events.Event):Void
	{
		for (effectClass in registeredEffects)
		{
			Reflect.callMethod(effectClass, Reflect.field(effectClass, "createBuffers"), null);
		}
	}
	
	private function parseSystemOptions(systemOptions:SystemOptions):Void
	{
		if (systemOptions == null)
			return;
		
		var DEG2RAD:Float = 1 / 180 * Math.PI;
		
		__textureAnimation = systemOptions.isAnimated;
		__animationLoops = systemOptions.loops;
		__firstFrame = systemOptions.firstFrame;
		__lastFrame = systemOptions.lastFrame;
		__randomStartFrames = systemOptions.randomStartFrames;
		__tinted = systemOptions.tinted;
		__spawnTime = systemOptions.spawnTime;
		__fadeInTime = systemOptions.fadeInTime;
		__fadeOutTime = systemOptions.fadeOutTime;
		__emitterType = systemOptions.emitterType;
		__maxNumParticles = systemOptions.maxParticles;
		emitter.x = __emitterX = systemOptions.sourceX;
		emitter.y = __emitterY = systemOptions.sourceY;
		__emitterXVariance = systemOptions.sourceVarianceX;
		__emitterYVariance = systemOptions.sourceVarianceY;
		__lifespan = systemOptions.lifespan;
		lifespanVariance = systemOptions.lifespanVariance;
		__emitAngle = systemOptions.angle * DEG2RAD;
		__emitAngleVariance = systemOptions.angleVariance * DEG2RAD;
		__startSize = systemOptions.startParticleSize;
		__startSizeVariance = systemOptions.startParticleSizeVariance;
		__endSize = systemOptions.finishParticleSize;
		__endSizeVariance = systemOptions.finishParticleSizeVariance;
		__startRotation = systemOptions.rotationStart * DEG2RAD;
		__startRotationVariance = systemOptions.rotationStartVariance * DEG2RAD;
		__endRotation = systemOptions.rotationEnd * DEG2RAD;
		__endRotationVariance = systemOptions.rotationEndVariance * DEG2RAD;
		__emissionTimePredefined = systemOptions.duration;
		__emissionTimePredefined = __emissionTimePredefined < 0 ? Max.MAX_VALUE : __emissionTimePredefined;
		
		__gravityX = systemOptions.gravityX;
		__gravityY = systemOptions.gravityY;
		__speed = systemOptions.speed;
		__speedVariance = systemOptions.speedVariance;
		__radialAcceleration = systemOptions.radialAcceleration;
		__radialAccelerationVariance = systemOptions.radialAccelerationVariance;
		__tangentialAcceleration = systemOptions.tangentialAcceleration;
		__tangentialAccelerationVariance = systemOptions.tangentialAccelerationVariance;
		
		__maxRadius = systemOptions.maxRadius;
		__maxRadiusVariance = systemOptions.maxRadiusVariance;
		__minRadius = systemOptions.minRadius;
		__minRadiusVariance = systemOptions.minRadiusVariance;
		__rotatePerSecond = systemOptions.rotatePerSecond * DEG2RAD;
		__rotatePerSecondVariance = systemOptions.rotatePerSecondVariance * DEG2RAD;
		
		__startColor.red = systemOptions.startColor.red;
		__startColor.green = systemOptions.startColor.green;
		__startColor.blue = systemOptions.startColor.blue;
		__startColor.alpha = systemOptions.startColor.alpha;
		
		__startColorVariance.red = systemOptions.startColorVariance.red;
		__startColorVariance.green = systemOptions.startColorVariance.green;
		__startColorVariance.blue = systemOptions.startColorVariance.blue;
		__startColorVariance.alpha = systemOptions.startColorVariance.alpha;
		
		__endColor.red = systemOptions.finishColor.red;
		__endColor.green = systemOptions.finishColor.green;
		__endColor.blue = systemOptions.finishColor.blue;
		__endColor.alpha = systemOptions.finishColor.alpha;
		
		__endColorVariance.red = systemOptions.finishColorVariance.red;
		__endColorVariance.green = systemOptions.finishColorVariance.green;
		__endColorVariance.blue = systemOptions.finishColorVariance.blue;
		__endColorVariance.alpha = systemOptions.finishColorVariance.alpha;
		
		__blendFuncSource = systemOptions.blendFuncSource;
		__blendFuncDestination = systemOptions.blendFuncDestination;
		updateBlendMode();
		__emitAngleAlignedRotation = systemOptions.emitAngleAlignedRotation;
		
		exactBounds = systemOptions.excactBounds;
		__texture = systemOptions.texture;
		__premultipliedAlpha = systemOptions.premultipliedAlpha;
		
		___filter = systemOptions.filter;
		__customFunction = systemOptions.customFunction;
		__sortFunction = systemOptions.sortFunction;
		forceSortFlag = systemOptions.forceSortFlag;
		
		__frameLUT = systemOptions.mFrameLUT;
		
		__animationLoopLength = __lastFrame - __firstFrame + 1;
		__numberOfFrames = __frameLUT.length - 1 - (__randomStartFrames && __textureAnimation ? __animationLoopLength : 0);
		__frameLUTLength = __frameLUT.length - 1;
	}
	
	/**
	 * Returns current properties to SystemOptions Object
	 * @param	target A SystemOptions instance
	 */
	public function exportSystemOptions(target:SystemOptions = null):SystemOptions
	{
		if (target == null)
			target = new SystemOptions(__texture);
		
		var RAD2DEG:Float = 180 / Math.PI;
		
		target.isAnimated = __textureAnimation;
		target.loops = __animationLoops;
		target.firstFrame = __firstFrame;
		target.lastFrame = __lastFrame;
		target.randomStartFrames = __randomStartFrames;
		target.tinted = __tinted;
		target.premultipliedAlpha = __premultipliedAlpha;
		target.spawnTime = __spawnTime;
		target.fadeInTime = __fadeInTime;
		target.fadeOutTime = __fadeOutTime;
		target.emitterType = __emitterType;
		target.maxParticles = __maxNumParticles;
		target.sourceX = __emitterX;
		target.sourceY = __emitterY;
		target.sourceVarianceX = __emitterXVariance;
		target.sourceVarianceY = __emitterYVariance;
		target.lifespan = __lifespan;
		target.lifespanVariance = __lifespanVariance;
		target.angle = __emitAngle * RAD2DEG;
		target.angleVariance = __emitAngleVariance * RAD2DEG;
		target.startParticleSize = __startSize;
		target.startParticleSizeVariance = __startSizeVariance;
		target.finishParticleSize = __endSize;
		target.finishParticleSizeVariance = __endSizeVariance;
		target.rotationStart = __startRotation * RAD2DEG;
		target.rotationStartVariance = __startRotationVariance * RAD2DEG;
		target.rotationEnd = __endRotation * RAD2DEG;
		target.rotationEndVariance = __endRotationVariance * RAD2DEG;
		target.duration = __emissionTimePredefined == Max.MAX_VALUE ? -1 : __emissionTimePredefined;
		
		target.gravityX = __gravityX;
		target.gravityY = __gravityY;
		target.speed = __speed;
		target.speedVariance = __speedVariance;
		target.radialAcceleration = __radialAcceleration;
		target.radialAccelerationVariance = __radialAccelerationVariance;
		target.tangentialAcceleration = __tangentialAcceleration;
		target.tangentialAccelerationVariance = __tangentialAccelerationVariance;
		
		target.maxRadius = __maxRadius;
		target.maxRadiusVariance = __maxRadiusVariance;
		target.minRadius = __minRadius;
		target.minRadiusVariance = __minRadiusVariance;
		target.rotatePerSecond = __rotatePerSecond * RAD2DEG;
		target.rotatePerSecondVariance = __rotatePerSecondVariance * RAD2DEG;
		
		target.startColor = __startColor;
		target.startColorVariance = __startColorVariance;
		target.finishColor = __endColor;
		target.finishColorVariance = __endColorVariance;
		
		target.blendFuncSource = __blendFuncSource;
		target.blendFuncDestination = __blendFuncDestination;
		target.emitAngleAlignedRotation = __emitAngleAlignedRotation;
		
		target.excactBounds = __exactBounds;
		target.texture = __texture;
		
		target.filter = ___filter;
		target.customFunction = __customFunction;
		target.sortFunction = __sortFunction;
		target.forceSortFlag = forceSortFlag;
		
		target.mFrameLUT = __frameLUT;
		
		target.firstFrame = __firstFrame;
		target.lastFrame = __lastFrame;
		
		return target;
	}
	
	/**
	 * Removes the system from the juggler and stops animation.
	 */
	public function pause():Void
	{
		if (automaticJugglerManagement)
			__juggler.remove(this);
		__playing = false;
	}
	
	/** @inheritDoc */
	private static var sHelperRect:Rectangle = new Rectangle();
	private var batchBounds:Rectangle = new Rectangle();
	
	/*@:final
	inline private function updateExactBounds(start:Int, end:Int):Void
	{
		if (!mExactBounds)
		return;

		if (!mBounds)
		mBounds = new Rectangle();

		var posX:int = 0;
		var posY:int = 1;
		var tX:Number = 0;
		var tY:Number = 0;
		var minX:Number = Max.MAX_VALUE;
		var maxX:Number = Max.MIN_VALUE;
		var minY:Number = Max.MAX_VALUE;
		var maxY:Number = Max.MIN_VALUE;

		for (var i:int = start; i < end; ++i)
		{
			tX = rawData[posX];
			tY = rawData[posY];
			if (minX > tX)
			minX = tX;
			if (maxX < tX)
			maxX = tX;
			if (minY > tY)
			minY = tY;
			if (maxY < tY)
			maxY = tY;
			posX += ELEMENTS_PER_VERTEX;
			posY += ELEMENTS_PER_VERTEX;
		}
		mBounds.x = minX;
		mBounds.y = minY;
		mBounds.width = maxX - minX;
		mBounds.height = maxY - minY;
	}*/
	
	/** @inheritDoc */
	public override function render(painter:Painter):Void
	{
		painter.excludeFromCache(this);
		__numBatchedParticles = 0;
		getBounds(stage, batchBounds);
		
		if (!ignoreSystemAlpha && ___alpha == 0)
			return;
		
		if (__numParticles > 0)
		{
			if (__batching)
			{
				if (!__batched)
				{
					var first:Int = parent.getChildIndex(this);
					var last:Int = first;
					var numChildren:Int = parent.numChildren;
					
					__numBatchedParticles += __effect.writeParticleDataToBuffers(__particles, __frameLUT, 0, numParticles, ___alpha);
					//updateExactBounds(offset, offset + mNumParticles);
					
					while (++last < numChildren)
					{
						var next:DisplayObject = parent.getChildAt(last);
						if (Std.isOfType(next, FFParticleSystem))
						{
							var nextps:FFParticleSystem = cast next;
							
							// filters don't seam to be "batchable" anymore?
							if (___filter == null && blendMode == nextps.blendMode && ___filter == nextps.filter && style.canBatchWith(nextps.style))
							{
								
								var newcapacity:Int = __numParticles + __numBatchedParticles + nextps.__numParticles;
								//if (newcapacity > __style.effectType.bufferSize)
								if (newcapacity > Reflect.getProperty(__style.effectType, "bufferSize"))
									break;
								
								__numBatchedParticles += __effect.writeParticleDataToBuffers(nextps.__particles, nextps.__frameLUT, __numBatchedParticles, nextps.numParticles, nextps.___alpha);
								//updateExactBounds(offset, offset + mNumParticles);
								
								nextps.__batched = true;
								
								//disable filter of batched system temporarily
								nextps.filter = null;
								
								nextps.getBounds(stage, sHelperRect);
								if (batchBounds.intersects(sHelperRect))
									batchBounds = batchBounds.union(sHelperRect);
							}
							else
							{
								break;
							}
						}
						else
						{
							break;
						}
					}
					renderCustom(painter);
				}
			}
			else
			{
				__numBatchedParticles += __effect.writeParticleDataToBuffers(__particles, __frameLUT, 0, numParticles, ___alpha);
				//updateExactBounds(offset, offset + mNumParticles);
				renderCustom(painter);
			}
		}
		// reset filter
		super.filter = ___filter;
		__batched = false;
	}
	
	@:final
	inline private function renderCustom(painter:Painter):Void
	{
		if (__numBatchedParticles == 0)
			return;
		
		// always call this method when you write custom rendering code!
		// it causes all previously batched quads/images to render.
		painter.finishMeshBatch();
		++painter.drawCount;
		
		var clipRect:Rectangle = painter.state.clipRect;
		if (clipRect != null)
		{
			batchBounds = batchBounds.intersection(clipRect);
		}
		painter.state.clipRect = batchBounds;
		painter.prepareToDraw();
		
		style.updateEffect(__effect, painter.state);
		
		if (Starling.current.context == null)
			throw new MissingContextError();
		
		__effect.render(0, __numBatchedParticles);
	}
	
	private function updateBlendMode():Void
	{
		var pma:Bool = texture != null ? texture.premultipliedAlpha : true;
		
		// Particle Designer uses special logic for a certain blend factor combination
		if (__blendFuncSource == Context3DBlendFactor.ONE && __blendFuncDestination == Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA)
		{
			//_vertexData.premultipliedAlpha = pma;
			if (!pma) __blendFuncSource = Context3DBlendFactor.SOURCE_ALPHA;
		}
		else
		{
			//_vertexData.premultipliedAlpha = false;
		}
		
		blendMode = __blendFuncSource + ", " + __blendFuncDestination;
		BlendMode.register(blendMode, __blendFuncSource, __blendFuncDestination);
	}
	
	public function setStyle(particleStyle:FFParticleStyle = null, mergeWithPredecessor:Bool = true):Void
	{
		if (particleStyle == null) particleStyle = cast Type.createInstance(_defaultStyle, []);//new $defaultStyle() as FFParticleStyle;
		else if (particleStyle == __style || !Reflect.getProperty(particleStyle.effectType, "isSupported")) return;
		else if (particleStyle.target != null) particleStyle.target.setStyle();
		
		if (__style != null)
		{
			if (mergeWithPredecessor) particleStyle.copyFrom(__style);
			__style.setTarget(null);
		}
		
		__style = particleStyle;
		__style.setTarget(this);
		
		if (__effect != null)
			__effect.dispose();
		
		__effect = style.createEffect();
		__effect.texture = __texture;
	}
	
	public var style(get, set):FFParticleStyle;
	private function get_style():FFParticleStyle { return __style; }
	private function set_style(value:FFParticleStyle):FFParticleStyle
	{
		setStyle(value);
		return value;
	}
	
	/**
	 * Adds the system to the juggler and resumes animation.
	 */
	public function resume():Void
	{
		if (automaticJugglerManagement)
			__juggler.add(this);
		__playing = true;
	}
	
	/**
	 * Starts the system to emit particles and adds it to the defaultJuggler if automaticJugglerManagement is enabled.
	 * @param	duration Emitting time in seconds.
	 */
	public function start(duration:Float = 0):Void
	{
		if (__completed)
			reset();
		
		if (__emissionRate != 0 && !__completed)
		{
			if (duration == 0)
			{
				duration = __emissionTimePredefined;
			}
			else if (duration < 0)
			{
				duration = Max.MAX_VALUE;
			}
			__playing = true;
			__emissionTime = duration;
			__frameTime = 0;
			if (automaticJugglerManagement)
				__juggler.add(this);
		}
	}
	
	/**
	 * Stopping the emitter creating particles.
	 * @param	clear Unlinks the particles returns them back to the pool and stops the animation.
	 */
	public function stop(clear:Bool = false):Void
	{
		__emissionTime = 0.0;
		
		if (clear)
		{
			if (automaticJugglerManagement)
				__juggler.remove(this);
			
			__playing = false;
			returnParticlesToPool();
			dispatchEventWith(starling.events.Event.CANCEL);
		}
	}
	
	/**
	 * Resets complete state and enables the system to play again if it has not been disposed.
	 * @return
	 */
	public function reset():Bool
	{
		if (!__disposed)
		{
			__emissionRate = __maxNumParticles / __lifespan;
			__frameTime = 0.0;
			__playing = false;
			while (__numParticles > 0)
			{
				__particles[--__numParticles].active = false;
			}
			__effect.maxCapacity = __maxNumParticles;
			__completed = false;
			if (__particles == null)
				getParticlesFromPool();
			return __particles != null;
		}
		return false;
	}
	
	private function returnParticlesToPool():Void
	{
		__numParticles = 0;
		
		if (__particles != null)
		{
			// handwritten concat to avoid gc
			var particleIdx:Int = __particles.length;
			var poolIdx:Int = _particlePool.length - 1;
			_particlePool.fixed = false;
			while (particleIdx > 0)
				_particlePool[++poolIdx] = __particles[--particleIdx];
			_particlePool.fixed = true;
			__particles = null;
		}
		__effect.clearData();
		
		// link cache to next waiting system
		if (_fixedPool)
		{
			//for (var i:int = 0; i < $instances.length; ++i)
			//{
				//var instance:FFParticleSystem = $instances[i];
			for (instance in _instances)
			{
				if (instance != this && !instance.__completed && instance.__playing && instance.parent != null && instance.__particles == null)
				{
					if (instance.getParticlesFromPool())
						break;
				}
			}
		}
	}
	
	private function updateEmissionRate():Void
	{
		emissionRate = __maxNumParticles / __lifespan;
	}
	
	override function get_alpha():Float { return ___alpha; }
	override function set_alpha(value:Float):Float 
	{
		return ___alpha = value;
	}
	
	/**
	 * Enables/Disables System internal batching.
	 *
	 * Only FFParticleSystems which share the same parent and are siblings next to each other, can be batched.
	 * Of course the rules of "stateChanges" also apply.
	 * @see #isStateChange()
	 */
	public var batching(get, set):Bool;
	private function get_batching():Bool { return __batching; }
	private function set_batching(value:Bool):Bool
	{
		return __batching = value;
	}
	
	/**
	 * Source blend factor of the particles.
	 *
	 * @see #blendFactorDestination
	 * @see flash.display3D.Context3DBlendFactor
	 */
	public var blendFuncSource(get, set):String;
	private function get_blendFuncSource():String { return __blendFuncSource; }
	private function set_blendFuncSource(value:String):String
	{
		__blendFuncSource = value;
		updateBlendMode();
		return value;
	}
	
	/**
	 * Destination blend factor of the particles.
	 * @see #blendFactorSource
	 * @see flash.display3D.Context3DBlendFactor;
	 */
	public var blendFuncDestination(get, set):String;
	private function get_blendFuncDestination():String { return __blendFuncDestination; }
	private function set_blendFuncDestination(value:String):String
	{
		__blendFuncDestination = value;
		updateBlendMode();
		return value;
	}
	
	/**
	 * Returns complete state of the system. The value is true if the system is done or has been
	 * stopped with the parameter clear.
	 */
	public var completed(get, never):Bool;
	private function get_completed():Bool { return __completed; }
	
	/**
	 * A custom function that can be applied to run code after every particle
	 * has been advanced, (sorted) and before it will be written to buffers/uploaded to the GPU.
	 *
	 * @default undefined
	 */
	public var customFunction(get, set):Vector<Particle>->Int->Void;
	private function get_customFunction():Vector<Particle>->Int->Void { return __customFunction; }
	private function set_customFunction(value:Vector<Particle>->Int->Void):Vector<Particle>->Int->Void
	{
		return __customFunction = value;
	}
	
	/**
	 * The number of particles, currently used by the system. (Not necessaryly all of them are visible).
	 */
	public var numParticles(get, never):Int;
	private function get_numParticles():Int { return __numParticles; }
	
	/**
	 * The duration of one animation cycle.
	 */
	public var cycleDuration(get, never):Float;
	private function get_cycleDuration():Float { return __maxNumParticles / __emissionRate; }
	
	/**
	 * Number of emitted particles/second.
	 */
	public var emissionRate(get, set):Float;
	private function get_emissionRate():Float { return __emissionRate; }
	private function set_emissionRate(value:Float):Float
	{
		return __emissionRate = value;
	}
	
	/**
	 * Angle of the emitter in degrees.
	 */
	public var emitAngle(get, set):Float;
	private function get_emitAngle():Float { return __emitAngle; }
	private function set_emitAngle(value:Float):Float
	{
		return __emitAngle = value;
	}
	
	/**
	 * Whether the particles rotation should respect the emit angle at birth or not.
	 */
	public var emitAngleAlignedRotation(get, set):Bool;
	private function get_emitAngleAlignedRotation():Bool { return __emitAngleAlignedRotation; }
	private function set_emitAngleAlignedRotation(value:Bool):Bool
	{
		return __emitAngleAlignedRotation = value;
	}
	
	/**
	 * Variance of the emit angle in degrees.
	 */
	public var emitAngleVariance(get, set):Float;
	private function get_emitAngleVariance():Float { return __emitAngleVariance; }
	private function set_emitAngleVariance(value:Float):Float
	{
		return __emitAngleVariance = value;
	}
	
	/**
	 * The type of the emitter.
	 *
	 * @see #EMITTER_TYPE_GRAVITY
	 * @see #EMITTER_TYPE_RADIAL
	 */
	public var emitterType(get, set):Int;
	private function get_emitterType():Int { return __emitterType; }
	private function set_emitterType(value:Int):Int
	{
		return __emitterType = value;
	}
	
	/**
	 * An Object setting the emitter position automatically.
	 *
	 * @see #emitter
	 * @see #emitterX
	 * @see #emitterY
	 */
	public var emitterObject(get, set):Dynamic;
	private function get_emitterObject():Dynamic { return __emitterObject; }
	private function set_emitterObject(value:Dynamic):Dynamic
	{
		return __emitterObject = value;
	}
	
	/**
	 * Emitter x position.
	 *
	 * @see #emitter
	 * @see #emitterObject
	 * @see #emitterY
	 */
	public var emitterX(get, set):Float;
	private function get_emitterX():Float { return emitter.x; }
	private function set_emitterX(value:Float):Float
	{
		return emitter.x = value;
	}
	
	/**
	 * Variance of the emitters x position.
	 *
	 * @see #emitter
	 * @see #emitterObject
	 * @see #emitterX
	 */
	public var emitterXVariance(get, set):Float;
	private function get_emitterXVariance():Float { return __emitterXVariance; }
	private function set_emitterXVariance(value:Float):Float
	{
		return __emitterXVariance = value;
	}
	
	/**
	 * Emitter y position.
	 *
	 * @see #emitterX
	 * @see #emitterObject
	 * @see #emitter
	 */
	public var emitterY(get, set):Float;
	private function get_emitterY():Float { return emitter.y; }
	private function set_emitterY(value:Float):Float
	{
		return emitter.y = value;
	}
	
	/**
	 * Variance of the emitters y position.
	 *
	 * @see #emitter
	 * @see #emitterObject
	 * @see #emitterY
	 */
	public var emitterYVariance(get, set):Float;
	private function get_emitterYVariance():Float { return __emitterYVariance; }
	private function set_emitterYVariance(value:Float):Float
	{
		return __emitterYVariance = value;
	}
	
	/**
	 * Returns true if the system is currently emitting particles.
	 * @see playing
	 * @see start()
	 * @see stop()
	 */
	public var emitting(get, never):Bool;
	private function get_emitting():Bool { return __emissionTime > 0; }
	
	/**
	 * Final particle color.
	 * @see #endColor
	 * @see #startColor
	 * @see #startColorVariance
	 * @see #tinted
	 */
	public var endColor(get, set):ColorArgb;
	private function get_endColor():ColorArgb { return __endColor; }
	private function set_endColor(value:ColorArgb):ColorArgb
	{
		if (value != null) __endColor = value;
		return __endColor;
	}
	
	/**
	 * Variance of final particle color
	 * @see #endColorVariance
	 * @see #startColor
	 * @see #startColorVariance
	 * @see #tinted
	 */
	public var endColorVariance(get, set):ColorArgb;
	private function get_endColorVariance():ColorArgb { return __endColorVariance; }
	private function set_endColorVariance(value:ColorArgb):ColorArgb
	{
		if (value != null) __endColorVariance = value;
		return __endColorVariance;
	}
	
	/**
	 * Final particle rotation in degrees.
	 * @see #endRotationVariance
	 * @see #startRotation
	 * @see #startRotationVariance
	 */
	public var endRotation(get, set):Float;
	private function get_endRotation():Float { return __endRotation; }
	private function set_endRotation(value:Float):Float
	{
		return __endRotation = value;
	}
	
	/**
	 * Variation of final particle rotation in degrees.
	 * @see #endRotation
	 * @see #startRotation
	 * @see #startRotationVariance
	 */
	public var endRotationVariance(get, set):Float;
	private function get_endRotationVariance():Float { return __endRotationVariance; }
	private function set_endRotationVariance(value:Float):Float
	{
		return __endRotationVariance = value;
	}
	
	/**
	 * Final particle size in pixels.
	 *
	 * The size is calculated according to the width of the texture.
	 * If the particle is animated and SubTextures have differnt dimensions, the size is
	 * based on the width of the first frame.
	 *
	 * @see #endSizeVariance
	 * @see #startSize
	 * @see #startSizeVariance
	 */
	public var endSize(get, set):Float;
	private function get_endSize():Float { return __endSize; }
	private function set_endSize(value:Float):Float
	{
		return __endSize = value;
	}
	
	/**
	 * Variance of the final particle size in pixels.
	 * @see #endSize
	 * @see #startSize
	 * @see #startSizeVariance
	 */
	public var endSizeVariance(get, set):Float;
	private function get_endSizeVariance():Float { return __endSizeVariance; }
	private function set_endSizeVariance(value:Float):Float
	{
		return __endSizeVariance = value;
	}
	
	/**
	 * Whether the bounds of the particle system will be calculated or set to screen size.
	 * The bounds will be used for clipping while rendering, therefore depending on the size;
	 * the number of particles; applied filters etc. this setting might in-/decrease performance.
	 *
	 * Keep in mind:
	 * - that the bounds of batches will be united.
	 * - filters may have to change the texture size (performance impact)
	 *
	 * @see #getBounds()
	 */
	public var exactBounds(get, set):Bool;
	private function get_exactBounds():Bool { return __exactBounds; }
	private function set_exactBounds(value:Bool):Bool
	{
		__bounds = value ? new Rectangle() : null;
		return __exactBounds = value;
	}
	
	/**
	 * The time to fade in spawning particles; set as percentage according to it's livespan.
	 */
	public var fadeInTime(get, set):Float;
	private function get_fadeInTime():Float { return __fadeInTime; }
	private function set_fadeInTime(value:Float):Float
	{
		return __fadeInTime = Math.max(0, Math.min(value, 1));
	}
	
	/**
	 * The time to fade out dying particles; set as percentage according to it's livespan.
	 */
	public var fadeOutTime(get, set):Float;
	private function get_fadeOutTime():Float { return __fadeOutTime; }
	private function set_fadeOutTime(value:Float):Float
	{
		return __fadeOutTime = Math.max(0, Math.min(value, 1));
	}
	
	/**
	 * The horizontal gravity value.
	 * @see #EMITTER_TYPE_GRAVITY
	 */
	public var gravityX(get, set):Float;
	private function get_gravityX():Float { return __gravityX; }
	private function set_gravityX(value:Float):Float
	{
		return __gravityX = value;
	}
	
	/**
	 * The vertical gravity value.
	 * @see #EMITTER_TYPE_GRAVITY
	 */
	public var gravityY(get, set):Float;
	private function get_gravityY():Float { return __gravityX; }
	private function set_gravityY(value:Float):Float
	{
		return __gravityY = value;
	}
	
	/**
	 * Lifespan of each particle in seconds.
	 * Setting this value also affects the emissionRate which is calculated in the following way
	 *
	 * 		emissionRate = maxNumParticles / mLifespan
	 *
	 * @see #emissionRate
	 * @see #maxNumParticles
	 * @see #lifespanVariance
	 */
	public var lifespan(get, set):Float;
	private function get_lifespan():Float { return __lifespan; }
	private function set_lifespan(value:Float):Float
	{
		__lifespan = Math.max(0.01, value);
		__lifespanVariance = Math.min(__lifespan, __lifespanVariance);
		updateEmissionRate();
		return __lifespan;
	}
	
	/**
	 * Variance of the particles lifespan.
	 * Setting this value does NOT affect the emissionRate.
	 * @see #lifespan
	 */
	public var lifespanVariance(get, set):Float;
	private function get_lifespanVariance():Float { return __lifespanVariance; }
	private function set_lifespanVariance(value:Float):Float
	{
		return __lifespanVariance = Math.min(__lifespan, value);
	}
	
	/**
	 * The maximum number of particles taken from the particle pool between 1 and 16383
	 * Changing this value while the system is running may impact performance.
	 *
	 * @see #maxCapacity
	 */
	public var maxNumParticles(get, set):UInt;
	private function get_maxNumParticles():UInt { return __maxNumParticles; }
	private function set_maxNumParticles(value:UInt):UInt
	{
		returnParticlesToPool();
		__effect.maxCapacity = value;
		__maxNumParticles = __effect.maxCapacity;
		if (!getParticlesFromPool())
		{
			stop();
		}
		updateEmissionRate();
		return __maxNumParticles;
	}
	
	/**
	 * The maximum emitter radius.
	 * @see #maxRadiusVariance
	 * @see #EMITTER_TYPE_RADIAL
	 */
	public var maxRadius(get, set):Float;
	private function get_maxRadius():Float { return __maxRadius; }
	private function set_maxRadius(value:Float):Float
	{
		return __maxRadius = value;
	}
	
	/**
	 * Variance of the emitter's maximum radius.
	 * @see #maxRadius
	 * @see #EMITTER_TYPE_RADIAL
	 */
	public var maxRadiusVariance(get, set):Float;
	private function get_maxRadiusVariance():Float { return __maxRadiusVariance; }
	private function set_maxRadiusVariance(value:Float):Float
	{
		return __maxRadiusVariance = value;
	}
	
	/**
	 * The minimal emitter radius.
	 * @see #EMITTER_TYPE_RADIAL
	 */
	public var minRadius(get, set):Float;
	private function get_minRadius():Float { return __minRadius; }
	private function set_minRadius(value:Float):Float
	{
		return __minRadius = value;
	}
	
	/**
	 * The minimal emitter radius variance.
	 * @see #EMITTER_TYPE_RADIAL
	 */
	public var minRadiusVariance(get, set):Float;
	private function get_minRadiusVariance():Float { return __minRadiusVariance; }
	private function set_minRadiusVariance(value:Float):Float
	{
		return __minRadiusVariance = value;
	}
	
	/**
	 * The number of unused particles remaining in the particle pool.
	 */
	public static var particlesInPool(get, never):UInt;
	private static function get_particlesInPool():UInt { return _particlePool.length; }
	
	/**
	 * Whether the system is playing or paused.
	 *
	 * <p><strong>Note:</strong> If you're not using automaticJugglermanagement the returned value may be wrong.</p>
	 * @see emitting
	 */
	public var playing(get, never):Bool;
	private function get_playing():Bool { return __playing; }
	
	/**
	 * The number of all particles created for the particle pool.
	 */
	public static var poolSize(get, never):UInt;
	private static function get_poolSize():UInt { return _poolSize; }
	
	/**
	 * Overrides the standard premultiplied alpha value set by the system.
	 */
	public var premultipliedAlpha(get, set):Bool;
	private function get_premultipliedAlpha():Bool { return __premultipliedAlpha; }
	private function set_premultipliedAlpha(value:Bool):Bool
	{
		return __premultipliedAlpha = value;
	}
	
	/**
	 * Radial acceleration of particles.
	 * @see #radialAccelerationVariance
	 * @see #EMITTER_TYPE_GRAVITY
	 */
	public var radialAcceleration(get, set):Float;
	private function get_radialAcceleration():Float { return __radialAcceleration; }
	private function set_radialAcceleration(value:Float):Float
	{
		return __radialAcceleration = value;
	}
	
	/**
	 * Variation of the particles radial acceleration.
	 * @see #radialAcceleration
	 * @see #EMITTER_TYPE_GRAVITY
	 */
	public var radialAccelerationVariance(get, set):Float;
	private function get_radialAccelerationVariance():Float { return __radialAccelerationVariance; }
	private function set_radialAccelerationVariance(value:Float):Float
	{
		return __radialAccelerationVariance = value;
	}
	
	/**
	 * If this property is set to true, new initiated particles will start at a random frame.
	 * This can be done even though isAnimated is false.
	 */
	public var randomStartFrames(get, set):Bool;
	private function get_randomStartFrames():Bool { return __randomStartFrames; }
	private function set_randomStartFrames(value:Bool):Bool
	{
		return __randomStartFrames = value;
	}
	
	/**
	 * Particles rotation per second in degerees.
	 * @see #rotatePerSecondVariance
	 */
	public var rotatePerSecond(get, set):Float;
	private function get_rotatePerSecond():Float { return __rotatePerSecond; }
	private function set_rotatePerSecond(value:Float):Float
	{
		return __rotatePerSecond = value;
	}
	
	/**
	 * Variance of the particles rotation per second in degerees.
	 * @see #rotatePerSecond
	 */
	public var rotatePerSecondVariance(get, set):Float;
	private function get_rotatePerSecondVariance():Float { return __rotatePerSecondVariance; }
	private function set_rotatePerSecondVariance(value:Float):Float
	{
		return __rotatePerSecondVariance = value;
	}
	
	/**
	 *  Sets the smoothing of the texture.
	 *  It's not recommended to change this value.
	 *  @default TextureSmoothing.BILINEAR
	 */
	public var smoothing(get, set):String;
	private function get_smoothing():String { return __smoothing; }
	private function set_smoothing(value:String):String
	{
		if (TextureSmoothing.isValid(value))
		{
			__smoothing = value;
		}
		return __smoothing;
	}
	
	/**
	 * A custom function that can be set to sort the Vector of particles.
	 * It will only be called if particles get added/removed.
	 * Anyway it should only be applied if absolutely necessary.
	 * Keep in mind, that it sorts the complete Vector.<Particle> and not just the active particles!
	 *
	 * @default undefined
	 * @see Vector#sort()
	 */
	public var sortFunction(get, set):Particle->Particle->Int;
	private function get_sortFunction():Particle->Particle->Int { return __sortFunction; }
	private function set_sortFunction(value:Particle->Particle->Int):Particle->Particle->Int
	{
		return __sortFunction = value;
	}
	
	/**
	 * The particles start color.
	 * @see #startColorVariance
	 * @see #endColor
	 * @see #endColorVariance
	 * @see #tinted
	 */
	public var startColor(get, set):ColorArgb;
	private function get_startColor():ColorArgb { return __startColor; }
	private function set_startColor(value:ColorArgb):ColorArgb
	{
		if (value != null)
		{
			__startColor = value;
		}
		return __startColor;
	}
	
	/**
	 * Variance of the particles start color.
	 * @see #startColor
	 * @see #endColor
	 * @see #endColorVariance
	 * @see #tinted
	 */
	public var startColorVariance(get, set):ColorArgb;
	private function get_startColorVariance():ColorArgb { return __startColorVariance; }
	private function set_startColorVariance(value:ColorArgb):ColorArgb
	{
		if (value != null)
		{
			__startColorVariance = value;
		}
		return __startColorVariance;
	}
	
	/**
	 * The particles start size.
	 *
	 * The size is calculated according to the width of the texture.
	 * If the particle is animated and SubTextures have differnt dimensions, the size is
	 * based on the width of the first frame.
	 *
	 * @see #startSizeVariance
	 * @see #endSize
	 * @see #endSizeVariance
	 */
	public var startSize(get, set):Float;
	private function get_startSize():Float { return __startSize; }
	private function set_startSize(value:Float):Float
	{
		return __startSize = value;
	}
	
	/**
	 * Variance of the particles start size.
	 * @see #startSize
	 * @see #endSize
	 * @see #endSizeVariance
	 */
	public var startSizeVariance(get, set):Float;
	private function get_startSizeVariance():Float { return __startSizeVariance; }
	private function set_startSizeVariance(value:Float):Float
	{
		return __startSize = value;
	}
	
	/**
	 * Start rotation of the particle in degrees.
	 * @see #startRotationVariance
	 * @see #endRotation
	 * @see #endRotationVariance
	 */
	public var startRotation(get, set):Float;
	private function get_startRotation():Float { return __startRotation; }
	private function set_startRotation(value:Float):Float
	{
		return __startRotation = value;
	}
	
	/**
	 * Variation of the particles start rotation in degrees.
	 * @see #startRotation
	 * @see #endRotation
	 * @see #endRotationVariance
	 */
	public var startRotationVariance(get, set):Float;
	private function get_startRotationVariance():Float { return __startRotationVariance; }
	private function set_startRotationVariance(value:Float):Float
	{
		return __startRotationVariance = value;
	}
	
	/**
	 * The time to scale new born particles from 0 to it's actual size; set as percentage according to it's livespan.
	 */
	public var spawnTime(get, set):Float;
	private function get_spawnTime():Float { return __spawnTime; }
	private function set_spawnTime(value:Float):Float
	{
		return __spawnTime = Math.max(0, Math.min(value, 1));
	}
	
	/**
	 * The particles velocity in pixels.
	 * @see #speedVariance
	 */
	public var speed(get, set):Float;
	private function get_speed():Float { return __speed; }
	private function set_speed(value:Float):Float
	{
		return __speed = value;
	}
	
	/**
	 * Variation of the particles velocity in pixels.
	 * @see #speed
	 */
	public var speedVariance(get, set):Float;
	private function get_speedVariance():Float { return __speedVariance; }
	private function set_speedVariance(value:Float):Float
	{
		return __speedVariance = value;
	}
	
	/**
	 * Tangential acceleration of particles.
	 * @see #EMITTER_TYPE_GRAVITY
	 */
	public var tangentialAcceleration(get, set):Float;
	private function get_tangentialAcceleration():Float { return __tangentialAcceleration; }
	private function set_tangentialAcceleration(value:Float):Float
	{
		return __tangentialAcceleration = value;
	}
	
	/**
	 * Variation of the particles tangential acceleration.
	 * @see #EMITTER_TYPE_GRAVITY
	 */
	public var tangentialAccelerationVariance(get, set):Float;
	private function get_tangentialAccelerationVariance():Float { return __tangentialAccelerationVariance; }
	private function set_tangentialAccelerationVariance(value:Float):Float
	{
		return __tangentialAccelerationVariance = value;
	}
	
	/**
	 * The Texture/SubTexture which has been passed to the constructor.
	 */
	public var texture(get, never):Texture;
	private function get_texture():Texture { return __texture; }
	
	/**
	 * Enables/Disables particle coloring
	 * @see #startColor
	 * @see #startColorVariance
	 * @see #endColor
	 * @see #endColorVariance
	 */
	public var tinted(get, set):Bool;
	private function get_tinted():Bool { return __tinted; }
	private function set_tinted(value:Bool):Bool
	{
		return __tinted = value;
	}
	
	/**
	 * Juggler to use when <a href="#automaticJugglerManagement">automaticJugglerManagement</a>
	 * is active.
	 * @see #automaticJugglerManagement
	 */
	public var juggler(get, set):Juggler;
	private function get_juggler():Juggler { return __juggler; }
	private function set_juggler(value:Juggler):Juggler
	{
		// Not null and different required
		if (value == null || value == __juggler)
		{
			return __juggler;
		}
		
		// Remove from current and add to new if needed
		if (__juggler.contains(this))
		{
			__juggler.remove(this);
			value.add(this);
		}
		
		return __juggler = value;
	}
	
	override function set_x(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem - use emitterX instead");
	}
	
	override function set_y(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem - use emitterY instead");
	}
	
	override function set_rotation(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_scale(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_scaleX(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_scaleY(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_skewX(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_skewY(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_pivotX(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_pivotY(value:Float):Float 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
	override function set_transformationMatrix(matrix:Matrix):Matrix 
	{
		throw new Error("Not supported by FFParticleSystem");
	}
	
}