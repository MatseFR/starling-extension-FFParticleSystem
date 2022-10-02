package starling.extensions.ffparticle.rendering;
import openfl.Vector;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DBufferUsage;
import openfl.display3D.Context3DProgramType;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.VertexBuffer3D;
import openfl.errors.Error;
import openfl.utils.ByteArray;
import starling.core.Starling;
import starling.errors.MissingContextError;
import starling.extensions.ffparticle.FFParticleSystem;
import starling.extensions.ffparticle.Frame;
import starling.extensions.ffparticle.Particle;
import starling.rendering.Program;
import starling.utils.RenderUtil;

/**
 *  FFInstancedParticleEffect
 *
 *  <p>For more information about the usage and creation of effects, please have a look at
 *  the documentation of the root class, "Effect".</p>
 *
 *  @see Effect
 *  @see FilterEffect
 *  @see starling.styles.MeshStyle
 *  @see de.flintfabrik.starling.styles.FFParticleStyle
 */
class FFInstancedParticleEffect extends FFParticleEffect 
{
	public static inline var ELEMENTS_PER_PARTICLE:Int = 3 + 3 + 4 + 4;
	public static inline var MAX_CAPACITY:Int = 16383;
	
	private static var _instances:Vector<FFParticleSystem> = new Vector<FFParticleSystem>(0, false);
	private static var _bufferSize:UInt = 0;
	private static var _indexBuffer:IndexBuffer3D;
	private static var _vertexBuffer:VertexBuffer3D;
	private static var _instanceBufferIdx:Int = -1;
	private static var _instanceBuffers:Vector<VertexBuffer3D>;
	private static var _numberOfInstanceBuffers:UInt = 1;
	private static var _renderAlpha:Vector<Float> = new Vector<Float>(4, true);
	
	public static var isSupported(get, never):Bool;
	private static function get_isSupported():Bool
	{
		// OpenFL's Context3D class is missing the createVertexBufferForInstances function
		
		//try
		//{
			//var context:Context3D = Starling.current.context;
			//if (context == null)
			//{
				//throw new MissingContextError();
			//}
			//var testBuffer:VertexBuffer3D = context.createVertexBufferForInstances(5, 12, 1, "dynamicDraw");
			//testBuffer.dispose()
			//trace('[FFInstancedParticleEffect] instance drawing supported');
			//return true;
		//}
		//catch (err:Error)
		//{
			//trace('[FFInstancedParticleEffect] Feature not available on this platform.');
			//return false;
		//}
		return false;
	}
	
	private var __maxCapacity:Int;
	private var __rawData:Vector<Float> = new Vector<Float>(0, true);
	
	/** Creates a new FFInstancedParticleEffect instance. */
	public function new() 
	{
		super();
		_alpha = 1.0;
	}
	
	override function createProgram():Program 
	{
		var vertexShader:String, fragmentShader:String;
		
		vertexShader = "mov vt0, va0    \n" + // vertex.pos
		"m33 vt0.xyz, va0, va2          \n" + // * p.matrix
		"m44 op, vt0, vc0               \n" + // * mvpMatrix
		
		"mul vt4, va1, va4              \n" + // texelCoords *= vertexFlag
		"add v4, vt4.xy, vt4.zw         \n" + // sum texelCoords
		
		"mov v5, va5                    \n"; // output color
		
		fragmentShader = tex("ft0", "v4", 0, texture) +        // read texel color
		"mul oc, ft0, v5                \n";  // texel color * color
		
		return Program.fromSource(vertexShader, fragmentShader);
	}
	
	override public function render(firstIndex:Int = 0, numParticles:Int = -1):Void 
	{
		if (_instanceBuffers == null || _vertexBuffer == null) return;
		
		if (numParticles == 0) return;
		if (numParticles < 0) numParticles = 0;
		
		var numTriangles:Int = numParticles * 2;
		
		var context:Context3D = Starling.current.context;
		if (context == null) throw new MissingContextError();
		
		_instanceBufferIdx = ++_instanceBufferIdx % _numberOfInstanceBuffers;
		var instanceBuffer:VertexBuffer3D = _instanceBuffers[_instanceBufferIdx];
		instanceBuffer.uploadFromVector(__rawData, 0, Std.int(Math.min(_bufferSize, numParticles) * 4);
		context.setVertexBufferAt(2, instanceBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
		context.setVertexBufferAt(3, instanceBuffer, 3, Context3DVertexBufferFormat.FLOAT_3);
		
		context.setVertexBufferAt(4, instanceBuffer, 6, Context3DVertexBufferFormat.FLOAT_4);
		context.setVertexBufferAt(5, instanceBuffer, 10, Context3DVertexBufferFormat.FLOAT_4);
		
		beforeDraw(context);
		// OpenFL's Context3D class is missing the createVertexBufferForInstances function
		//context.drawTrianglesInstanced(_indexBuffer, numParticles, firstIndex, 2);
		afterDraw(context);
	}
	
	override function beforeDraw(context:Context3D):Void 
	{
		program.activate(context);
		_renderAlpha[0] = _renderAlpha[1] = _renderAlpha[2] = 1;
		_renderAlpha[3] = super._alpha;
		context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, _renderAlpha);
		context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, mvpMatrix3D, true);
		
		context.setVertexBufferAt(0, _vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
		context.setVertexBufferAt(1, _vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_4);
		
		context.setTextureAt(0, texture.base);
		RenderUtil.setSamplerStateAt(0, texture.mipMapping, textureSmoothing, super.textureRepeat);
	}
	
	override function afterDraw(context:Context3D):Void 
	{
		context.setVertexBufferAt(5, null);
		context.setVertexBufferAt(4, null);
		context.setVertexBufferAt(3, null);
		context.setVertexBufferAt(2, null);
		context.setVertexBufferAt(1, null);
		context.setVertexBufferAt(0, null);
		context.setTextureAt(0, null);
	}
	
	override public function writeParticleDataToBuffers(particles:Vector<Particle>, frameLUT:Vector<Frame>, offset:Int, numParticles:Int, systemAlpha:Float = 1):UInt 
	{
		var vertexID:Int = 0;
		var particle:Particle;
		var position:UInt;
		var frameDimensions:Frame;
		var angle:Int;
		var scaledWidth:Float;
		var scaledHeight:Float;
		var particleAlpha:Float;
		var particlesWritten:Int = -1;
		
		__rawData.fixed = false;
		
		for (i in 0...numParticles)
		{
			particle = particles[i];
			particleAlpha = particle.colorAlpha * particle.fadeInFactor * particle.fadeOutFactor;
			
			if ((testParticleAlpha && particleAlpha <= 0) || particle.scale <= 0)
				continue;
			
			vertexID = (offset + ++particlesWritten);
			frameDimensions = frameLUT[particle.frameIdx];
			angle = Std.int(particle.rotation * 325.94932345220164765467394738691) & 2047;
			scaledWidth = frameDimensions.particleHalfWidth * particle.scale * particle.spawnFactor;
			scaledHeight = frameDimensions.particleHalfHeight * particle.scale * particle.spawnFactor;
			position = vertexID * ELEMENTS_PER_PARTICLE;
			
			__rawData[position] = scaledWidth * FFPS_LUT.cos[angle];
			__rawData[++position] = scaledHeight * -FFPS_LUT.sin[angle];
			__rawData[++position] = particle.x;
			
			__rawData[++position] = scaledWidth * FFPS_LUT.sin[angle];
			__rawData[++position] = scaledHeight * FFPS_LUT.cos[angle];
			__rawData[++position] = particle.y;
			
			__rawData[++position] = frameDimensions.textureX;
			__rawData[++position] = frameDimensions.textureY;
			__rawData[++position] = frameDimensions.textureWidth;
			__rawData[++position] = frameDimensions.textureHeight;
			
			__rawData[++position] = particle.colorRed;
			__rawData[++position] = particle.colorGreen;
			__rawData[++position] = particle.colorBlue;
			__rawData[++position] = particleAlpha * systemAlpha;
		}
		
		__rawData.fixed = true;
		return ++particlesWritten;
	}
	
	public static var BUFFERS_CREATED(get, never):Bool;
	private static function get_BUFFERS_CREATED():Bool
	{
		return _instanceBuffers != null && _instanceBuffers[0] != null;
	}
	
	public var buffersCreated(get, never):Bool
	private function get_buffersCreated():Bool { return BUFFERS_CREATED; }
	
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
			_numberOfInstanceBuffers = numberOfBuffers;
		}
		
		if (_instanceBuffers != null)
		{
			for (instanceBuffer in _instanceBuffers)
			{
				instanceBuffer.dispose();
			}
		}
		
		if (_indexBuffer != null)
		{
			_indexBuffer.dispose();
		}
		
		if (_vertexBuffer != null)
		{
			_vertexBuffer.dispose();
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
		
		_vertexBuffer = context.createVertexBuffer(FFParticleEffect.VERTICES_PER_PARTICLE, 7, Context3DBufferUsage.STATIC_DRAW);
		_vertexBuffer.uploadFromVector(Vector<Float>[ -1.0, -1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, -1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, ]), 0, FFParticleEffect.VERTICES_PER_PARTICLE);
		
		_indexBuffer = context.createIndexBuffer(6, Context3DBufferUsage.STATIC_DRAW);
		_indexBuffer.uploadFromVector(Vector<UInt>[0, 1, 2, 0, 2, 3], 0, 6);
		
		var numInstances:UInt = Std.int(Math.max(1, _bufferSize));
		_instanceBuffers = new Vector<VertexBuffer3D>(_numberOfInstanceBuffers, true);
		for (i in 0..._numberOfInstanceBuffers)
		{
			// OpenFL's Context3D class is missing the createVertexBufferForInstances function
			//_instanceBuffers[i] = context.createVertexBufferForInstances(numInstances, ELEMENTS_PER_PARTICLE, 1, Context3DBufferUsage.DYNAMIC_DRAW);
		}
		
		var zeroBytes:ByteArray = new ByteArray();
		zeroBytes.length = numInstances * FFParticleEffect.VERTICES_PER_PARTICLE * ELEMENTS_PER_PARTICLE;
		for (i in 0..._numberOfInstanceBuffers)
		{
			_instanceBuffers[i].uploadFromByteArray(zeroBytes, 0, 0, numInstances);
		}
		zeroBytes.length = 0;
		
		FFParticleSystem.registerEffect(FFInstancedParticleEffect);
	}
	
	/**
	 * Disposes the Stage3D buffers and therefore disposes all system instances!
	 * Call this function to free the GPU resources or if you have to set
	 * the buffers to another size.
	 */
	public static function disposeBuffers():Void
	{
		for (instance in _instances)
		{
			instance.dispose();
		}
		
		if (_instanceBuffers != null)
		{
			for (i in 0..._numberOfInstanceBuffers)
			{
				_instanceBuffers[i].dispose();
				_instanceBuffers[i] = null;
			}
			_instanceBuffers = null;
			_numberOfInstanceBuffers = 0;
		}
		
		if (_indexBuffer != null)
		{
			_indexBuffer.dispose();
			_indexBuffer = null;
		}
		
		if (_vertexBuffer != null)
		{
			_vertexBuffer.dispose();
			_vertexBuffer = null;
		}
		
		_bufferSize = 0;
		FFParticleSystem.unregisterEffect(FFInstancedParticleEffect);
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