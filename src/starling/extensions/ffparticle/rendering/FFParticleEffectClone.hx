package starling.extensions.ffparticle.rendering;

import openfl.Vector;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DBufferUsage;
import openfl.display3D.Context3DProgramType;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.VertexBuffer3D;
import openfl.system.ApplicationDomain;
import openfl.utils.ByteArray;
import starling.core.Starling;
import starling.errors.MissingContextError;
import starling.extensions.ffparticle.FFParticleSystem;
import starling.extensions.ffparticle.Frame;
import starling.extensions.ffparticle.Particle;
import starling.extensions.ffparticle.utils.FFPS_LUT;
import starling.rendering.FilterEffect;
import starling.rendering.Program;
import starling.utils.RenderUtil;

/**
 *  FFParticleEffectBeta
 *
 *  <p>For more information about the usage and creation of effects, please have a look at
 *  the documentation of the root class, "Effect".</p>
 *
 *  @see Effect
 *  @see FilterEffect
 *  @see starling.styles.MeshStyle
 *  @see de.flintfabrik.starling.styles.FFParticleStyle
 */
class FFParticleEffectClone extends FFParticleEffect 
{
	public static inline var VERTICES_PER_PARTICLE:Int = 4;
	public static inline var ELEMENTS_PER_VERTEX:Int = 2 + 2 + 4;
	public static inline var ELEMENTS_PER_PARTICLE:Int = VERTICES_PER_PARTICLE * ELEMENTS_PER_VERTEX;
	public static inline var MAX_CAPACITY:Int = 16383;
	
	public static function get isSupported():Boolean
	{
		return true;
	}
	
	private static var __instances:Vector<FFParticleSystem> = new Vector<FFParticleSystem>(0, false);
	private static var _bufferSize:UInt = 0;
	private static var _indices:Vector<UInt>;
	private static var __indexBuffer:IndexBuffer3D;
	private static var _vertexBufferIdx:Int = -1;
	private static var _vertexBuffers:Vector<VertexBuffer3D>;
	private static var _numberOfVertexBuffers:UInt = 1;
	private static var _renderAlpha:Vector<Float> = new Vector<Float>(4, true);
	private static var _instances:Vector.<FFParticleSystem> = new Vector.<FFParticleSystem>(0, false);
	
	private var __maxCapacity:Int;
	private var __rawData:Vector<Float> = new Vector<Float>(0, true);
	
	/** Creates a new FFParticleEffectClone instance. */
	public function new() 
	{
		super();
		_alpha = 1.0;
	}
	
	override function createProgram():Program 
	{
		var vertexShader:String, fragmentShader:String;
		
		vertexShader = "m44 op, va0, vc0 \n" + // 4x4 matrix transform to output clip-space
		"mov v0, va1      \n" + // pass texture coordinates to fragment program
		"mul v1, va2, vc4 \n";  // multiply alpha (vc4) with color (va2), pass to fp
		
		fragmentShader = tex("ft0", "v0", 0, texture) + // read texel color
		"mul oc, ft0, v1         \n"; // multiply texel color with color
		
		return Program.fromSource(vertexShader, fragmentShader);
	}
	
	override public function render(firstIndex:Int = 0, numParticles:Int = -1):Void 
	{
		if (_vertexBuffers == null) return;
		
		if (numParticles < 0) numParticles = 0;
		if (numParticles == 0) return;
		
		var numTriangles:Int = numParticles * 2;
		
		var context:Context3D = Starling.current.context;
		if (context == null) throw new MissingContextError();
		
		_vertexBufferIdx = ++_vertexBufferIdx % _numberOfVertexBuffers;
		var vertexBuffer:VertexBuffer3D = _vertexBuffers[_vertexBufferIdx];
		vertexBuffer.uploadFromVector(__rawData, 0, Std.int(Math.min(_bufferSize, numParticles)) * 4);
		context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
		context.setVertexBufferAt(1, vertexBuffer, 2, Context3DVertexBufferFormat.FLOAT_2);
		context.setVertexBufferAt(2, vertexBuffer, 4, Context3DVertexBufferFormat.FLOAT_4);
		
		beforeDraw(context);
		context.drawTriangles(__indexBuffer, firstIndex, numTriangles);
		afterDraw(context);
	}
	
	override function beforeDraw(context:Context3D):Void 
	{
		program.activate(context);
		_renderAlpha[0] = _renderAlpha[1] = _renderAlpha[2] = 1;
		_renderAlpha[3] = _alpha;
		context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, _renderAlpha);
		context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, mvpMatrix3D, true);
		
		context.setTextureAt(0, texture.base);
		RenderUtil.setSamplerStateAt(0, texture.mipMapping, textureSmoothing, super.textureRepeat);
	}
	
	override function afterDraw(context:Context3D):Void 
	{
		context.setVertexBufferAt(2, null);
		context.setVertexBufferAt(1, null);
		context.setVertexBufferAt(0, null);
		context.setTextureAt(0, null);
	}
	
	/** The alpha value of the object rendered by the effect. Must be taken into account
	 *  by all subclasses. */
	public var alpha(get, set):Float;
	private function get_alpha():Float { return _alpha; }
	private function set_alpha(value:Float):Float { return _alpha = value; }
	
	override public function writeParticleDataToBuffers(particles:Vector<Particle>, frameLUT:Vector<Frame>, offset:Int, numParticles:Int, systemAlpha:Float = 1):UInt
	{
		var DEG90RAD:Float = Math.PI * 0.5;
		
		var vertexID:Int = 0;
		var particle:Particle;
		
		var red:Float;
		var green:Float;
		var blue:Float;
		var particleAlpha:Float;
		
		var rotation:Float;
		var x:Float, y:Float;
		var xOffset:Float, yOffset:Float;
		var frameDimensions:Frame;
		
		var angle:Int;
		var cos:Float;
		var sin:Float;
		var cosX:Float;
		var cosY:Float;
		var sinX:Float;
		var sinY:Float;
		var position:UInt;
		var particlesWritten:Int = -1;
		__rawData.fixed = false;
		
		for (i in 0...numParticles)
		{
			particle = particles[i];
			
			particleAlpha = particle.colorAlpha * particle.fadeInFactor * particle.fadeOutFactor;
			
			if ((testParticleAlpha && particleAlpha <= 0) || particle.scale <= 0)
				continue;
			
			vertexID = (offset + ++particlesWritten) << 2;
			
			frameDimensions = frameLUT[particle.frameIdx];
			
			red = particle.colorRed;
			green = particle.colorGreen;
			blue = particle.colorBlue;
			particleAlpha *= systemAlpha;
			
			rotation = particle.rotation;
			if (frameDimensions.rotated)
			{
				rotation -= DEG90RAD;
			}
			
			x = particle.x;
			y = particle.y;
			
			xOffset = frameDimensions.particleHalfWidth * particle.scale * particle.spawnFactor;
			yOffset = frameDimensions.particleHalfHeight * particle.scale * particle.spawnFactor;
			
			if (rotation != 0)
			{
				angle = Std.int(rotation * 325.94932345220164765467394738691) & 2047;
				cos = FFPS_LUT.cos[angle];
				sin = FFPS_LUT.sin[angle];
				cosX = cos * xOffset;
				cosY = cos * yOffset;
				sinX = sin * xOffset;
				sinY = sin * yOffset;
				
				position = vertexID << 3; // * ELEMENTS_PER_VERTEX
				__rawData[position] = x - cosX + sinY;
				__rawData[++position] = y - sinX - cosY;
				__rawData[++position] = frameDimensions.textureX;
				__rawData[++position] = frameDimensions.textureY;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
				
				__rawData[++position] = x + cosX + sinY;
				__rawData[++position] = y + sinX - cosY;
				__rawData[++position] = frameDimensions.textureWidth;
				__rawData[++position] = frameDimensions.textureY;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
				
				__rawData[++position] = x - cosX - sinY;
				__rawData[++position] = y - sinX + cosY;
				__rawData[++position] = frameDimensions.textureX;
				__rawData[++position] = frameDimensions.textureHeight;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
				
				__rawData[++position] = x + cosX - sinY;
				__rawData[++position] = y + sinX + cosY;
				__rawData[++position] = frameDimensions.textureWidth;
				__rawData[++position] = frameDimensions.textureHeight;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
			}
			else
			{
				position = vertexID << 3; // * ELEMENTS_PER_VERTEX
				__rawData[position] = x - xOffset;
				__rawData[++position] = y - yOffset;
				__rawData[++position] = frameDimensions.textureX;
				__rawData[++position] = frameDimensions.textureY;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
				
				__rawData[++position] = x + xOffset;
				__rawData[++position] = y - yOffset;
				__rawData[++position] = frameDimensions.textureWidth;
				__rawData[++position] = frameDimensions.textureY;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
				
				__rawData[++position] = x - xOffset;
				__rawData[++position] = y + yOffset;
				__rawData[++position] = frameDimensions.textureX;
				__rawData[++position] = frameDimensions.textureHeight;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
				
				__rawData[++position] = x + xOffset;
				__rawData[++position] = y + yOffset;
				__rawData[++position] = frameDimensions.textureWidth;
				__rawData[++position] = frameDimensions.textureHeight;
				__rawData[++position] = red;
				__rawData[++position] = green;
				__rawData[++position] = blue;
				__rawData[++position] = particleAlpha;
			}
		}
		
		__rawData.fixed = true;
		return ++particlesWritten;
	}
	
	public static var BUFFERS_CREATED(get, never):Bool;
	private static function get_BUFFERS_CREATED():Bool
	{
		return _vertexBuffers != null && _vertexBuffers[0] != null;
	}
	
	public var buffersCreated(get, never):Bool
	private function get_buffersCreated():Bool { return BUFFERS_CREATED; }
	
	/**
	 * creating vertex and index buffers for the number of particles.
	 * @param	bufferSize a value between 1 and 16383
	 */
	public static function createBuffers(bufferSize:UInt = 0, numberOfBuffers:UInt = 0):Void
	{
		if (bufferSize == 0 && _bufferSize != 0)
		{
			bufferSize = _bufferSize;
		}
		
		if (bufferSize > MAX_CAPACITY)
		{
			bufferSize = MAX_CAPACITY;
			trace("Warning: bufferSize exceeds the limit and is set to it's maximum value (16383)");
		}
		else if (bufferSize <= 0)
		{
			bufferSize = MAX_CAPACITY;
			trace("Warning: bufferSize can't be lower than 1 and is set to it's maximum value (16383)");
		}
		_bufferSize = bufferSize;
		
		if (numberOfBuffers != 0)
		{
			_numberOfVertexBuffers = numberOfBuffers;
		}
		
		if (__instances != null)
		{
			for (instance in __instances)
			{
				instance.dispose();
			}
		}
		
		if (_vertexBuffers != null)
		{
			for (vertexBuffer in _vertexBuffers)
			{
				vertexBuffer.dispose();
			}
		}
		
		if (__indexBuffer != null)
		{
			__indexBuffer.dispose();
		}
		
		var context:Context3D = Starling.current.context;
		if (context == null)
		{
			throw new MissingContextError();
		}
		
		if (context.driverInfo == "Disposed")
		{
			return;
		}
		
		_vertexBuffers = new Vector<VertexBuffer3D>();
		_vertexBufferIdx = -1;
		
		//if (ApplicationDomain.currentDomain.hasDefinition("openfl.display3D.Context3DBufferUsage"))
		for (i in 0..._numberOfVertexBuffers)
		{
			_vertexBuffers[i] = context.createVertexBuffer(_bufferSize * 4, ELEMENTS_PER_VERTEX, Context3DBufferUsage.DYNAMIC_DRAW);
		}
		
		var zeroBytes:ByteArray = new ByteArray();
		zeroBytes.length = _bufferSize * VERTICES_PER_PARTICLE * ELEMENTS_PER_PARTICLE;
		for (i in 0..._numberOfVertexBuffers)
		{
			_vertexBuffers[i].uploadFromByteArray(zeroBytes, 0, 0, _bufferSize * VERTICES_PER_PARTICLE);
		}
		zeroBytes.length = 0;
		
		if (_indices == null)
		{
			_indices = new Vector<UInt>();
			var numVertices:Int = 0;
			var indexPosition:Int = -1;
			for (i in 0...MAX_CAPACITY)
			{
				_indices[++indexPosition] = numVertices;
				_indices[++indexPosition] = numVertices + 1;
				_indices[++indexPosition] = numVertices + 2;
				
				_indices[++indexPosition] = numVertices + 1;
				_indices[++indexPosition] = numVertices + 2;
				_indices[++indexPosition] = numVertices + 3;
				numVertices += 4;
			}
		}
		__indexBuffer = context.createIndexBuffer(_bufferSize * 6);
		__indexBuffer.uploadFromVector(_indices, 0, _bufferSize * 6);
		
		FFParticleSystem.registerEffect(FFParticleEffect);
	}
	
	/**
	 * Disposes the Stage3D buffers and therefore disposes all system instances!
	 * Call this function to free the GPU resources or if you have to set
	 * the buffers to another size.
	 */
	public static function disposeBuffers():Void
	{
		for (instance in __instances)
		{
			instance.dispose();
		}
		
		if (_vertexBuffers != null)
		{
			for (i in 0..._numberOfVertexBuffers)
			{
				_vertexBuffers[i].dispose();
				_vertexBuffers[i] = null;
			}
			_vertexBuffers = null;
			_numberOfVertexBuffers = 0;
		}
		
		if (__indexBuffer != null)
		{
			__indexBuffer.dispose();
			__indexBuffer = null;
		}
		_bufferSize = 0;
		FFParticleSystem.unregisterEffect(FFParticleEffect);
	}
	
	public static var bufferSize(get, never):Int;
	private static function get_bufferSize():Int { return _bufferSize; }
	
	public function raiseCapacity(byAmount:Int):Void
	{
		var oldCapacity:Int = capacity;
		var newCapacity:Int = Std.int(Math.min(__maxCapacity, oldCapacity + byAmount));
		
		if (oldCapacity < newCapacity)
		{
			__rawData.fixed = false;
			__rawData.length = newCapacity * ELEMENTS_PER_PARTICLE;
			__rawData.fixed = true;
		}
	}
	
	public function clearData():Void
	{
		__rawData.fixed = false;
		__rawData.length = 0;
		__rawData.fixed = true;
	}
	
	/**
	 * The number of particles, currently fitting into the vertexData instance of the system.
	 * (Not necessarily all of them are visible)
	 */
	public var capacity(get, never):Int;
	private function get_capacity():Int
	{
		return __rawData != null ? Std.int(__rawData.length / ELEMENTS_PER_PARTICLE) : 0;
	}
	
	/**
	 * The maximum number of particles processed by the system.
	 * It has to be a value between 1 and 16383.
	 */
	public var maxCapacity(get, set):UInt;
	private function get_maxCapacity():UInt { return __maxCapacity; }
	private function set_maxCapacity(value:UInt):UInt
	{
		return __maxCapacity = Std.int(Math.min(MAX_CAPACITY, value));
	}
	
}