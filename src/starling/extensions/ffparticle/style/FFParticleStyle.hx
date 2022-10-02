package starling.extensions.ffparticle.style;

import haxe.Constraints.Function;
import openfl.display3D.textures.TextureBase;
import openfl.errors.Error;
import openfl.geom.Point;
import starling.events.Event;
import starling.events.EventDispatcher;
import starling.extensions.ffparticle.FFParticleSystem;
import starling.extensions.ffparticle.rendering.FFParticleEffect;
import starling.rendering.IndexData;
import starling.rendering.RenderState;
import starling.rendering.VertexData;
import starling.textures.Texture;
import starling.textures.TextureSmoothing;

/** FFParticleStyles provide a means to completely modify the way a mesh is rendered.
 *  The base class provides Starling's standard mesh rendering functionality: colored and
 *  (optionally) textured meshes. Subclasses may add support for additional features like
 *  color transformations, normal mapping, etc.
 *
 *  <p><strong>Using styles</strong></p>
 *
 *  <p>First, create an instance of the desired style. Configure the style by updating its
 *  properties, then assign it to the mesh. Here is an example that uses a fictitious
 *  <code>ColorStyle</code>:</p>
 *
 *  <listing>
 *  var image:Image = new Image(heroTexture);
 *  var colorStyle:ColorStyle = new ColorStyle();
 *  colorStyle.redOffset = 0.5;
 *  colorStyle.redMultiplier = 2.0;
 *  image.style = colorStyle;</listing>
 *
 *  <p>Beware:</p>
 *
 *  <ul>
 *    <li>A style instance may only be used on one object at a time.</li>
 *    <li>A style might require the use of a specific vertex format;
 *        when the style is assigned, the mesh is converted to that format.</li>
 *  </ul>
 *
 *  <p><strong>Creating your own styles</strong></p>
 *
 *  <p>To create custom rendering code in Starling, you need to extend two classes:
 *  <code>FFParticleStyle</code> and <code>FFParticleEffect</code>. While the effect class contains
 *  the actual AGAL rendering code, the style provides the API that other developers will
 *  interact with.</p>
 *
 *  <p>Subclasses of <code>FFParticleStyle</code> will add specific properties that configure the
 *  style's outcome, like the <code>redOffset</code> and <code>redMultiplier</code> properties
 *  in the sample above. Here's how to properly create such a class:</p>
 *
 *  <ul>
 *    <li>Always provide a constructor that can be called without any arguments.</li>
 *    <li>Override <code>copyFrom</code> — that's necessary for batching.</li>
 *    <li>Override <code>createEffect</code> — this method must return the
 *        <code>FFParticleEffect</code> that will do the actual Stage3D rendering.</li>
 *    <li>Override <code>updateEffect</code> — this configures the effect created above
 *        right before rendering.</li>
 *    <li>Override <code>canBatchWith</code> if necessary — this method figures out if one
 *        instance of the style can be batched with another. If they all can, you can leave
 *        this out.</li>
 *  </ul>
 *
 *  <p>If the style requires a custom vertex format, you must also:</p>
 *
 *  <ul>
 *    <li>add a static constant called <code>VERTEX_FORMAT</code> to the class and</li>
 *    <li>override <code>get vertexFormat</code> and let it return exactly that format.</li>
 *  </ul>
 *
 *  <p>When that's done, you can turn to the implementation of your <code>FFParticleEffect</code>;
 *  the <code>createEffect</code>-override will return an instance of this class.
 *  Directly before rendering begins, Starling will then call <code>updateEffect</code>
 *  to set it up.</p>
 *
 *  @see FFParticleEffect
 *  @see VertexDataFormat
 *  @see starling.display.Mesh
 */
class FFParticleStyle extends EventDispatcher 
{
	/** The vertex format expected by this style (the same as found in the FFParticleEffect-class). */
	private var _type:Class<Dynamic>;
	private var _target:FFParticleSystem;
	private var _texture:Texture;
	private var _textureBase:TextureBase;
	private var _textureSmoothing:String;
	private var _textureRepeat:Bool;
	
	public static var EFFECT_TYPE(get, never):Class<Dynamic>;
	private static function get_EFFECT_TYPE():Class<Dynamic> { return FFParticleEffect; }
	
	public var effectType(get, never):Class<Dynamic>;
	private function get_effectType():Class<Dynamic> { return Reflect.getProperty(_type, "EFFECT_TYPE"); }
	
	// helper objects
	private static var sPoint:Point = new Point();
	
	/** Creates a new FFParticleStyle instance.
	 *  Subclasses must provide a constructor that can be called without any arguments. */
	public function new() 
	{
		super();
		
		_textureSmoothing = TextureSmoothing.BILINEAR;
		_type = Type.getClass(this);
	}
	
	/** Copies all properties of the given style to the current instance (or a subset, if the
	 *  classes don't match). Must be overridden by all subclasses!
	 */
	public function copyFrom(particleStyle:FFParticleStyle):Void
	{
		_texture = particleStyle._texture;
		_textureBase = particleStyle._textureBase;
		_textureRepeat = particleStyle._textureRepeat;
		_textureSmoothing = particleStyle._textureSmoothing;
	}
	
	/** Creates a clone of this instance. The method will work for subclasses automatically,
	 *  no need to override it. */
	public function clone():FFParticleStyle
	{
		var clone:FFParticleStyle = Type.createInstance(_type, null);
		clone.copyFrom(this);
		return clone;
	}
	
	/** Creates the effect that does the actual, low-level rendering.
	 *  To be overridden by subclasses!
	 */
	public function createEffect():FFParticleEffect
	{
		return new FFParticleEffect();
	}
	
	/** Updates the settings of the given effect to match the current style.
	 *  The given <code>effect</code> will always match the class returned by
	 *  <code>createEffect</code>.
	 *
	 *  <p>To be overridden by subclasses!</p>
	 */
	public function updateEffect(effect:FFParticleEffect, state:RenderState):Void
	{
		//effect.texture = _texture;
		effect.textureRepeat = _textureRepeat;
		effect.textureSmoothing = _textureSmoothing;
		effect.mvpMatrix3D = state.mvpMatrix3D;
		effect.alpha = state.alpha;
		//effect.tinted = _vertexData.tinted;
	}
	
	/** Indicates if the current instance can be batched with the given style.
	 *  To be overridden by subclasses if default behavior is not sufficient.
	 *  The base implementation just checks if the styles are of the same type
	 *  and if the textures are compatible.
	 */
	public function canBatchWith(particleStyle:FFParticleStyle):Bool
	{
		if (_type == particleStyle._type)
		{
			var newTexture:Texture = particleStyle._texture;
			
			if (_texture == null && newTexture == null)
			{
				return true;
			}
			else if (_texture != null && newTexture != null)
			{
				return _textureBase == particleStyle._textureBase && _textureSmoothing == particleStyle._textureSmoothing && _textureRepeat == particleStyle._textureRepeat;
			}
			else return false;
		}
		else return false;
	}
	
	/** Call this method if the target needs to be redrawn.
	 *  The call is simply forwarded to the mesh. */
	private function setRequiresRedraw():Void
	{
		if (_target != null) _target.setRequiresRedraw();
	}
	
	/** Called when assigning a target mesh. Override to plug in class-specific logic. */
	private function onTargetAssigned(target:FFParticleSystem):Void
	{
		
	}
	
	// enter frame event
	
	override public function addEventListener(type:String, listener:Function):Void 
	{
		if (type == Event.ENTER_FRAME && _target != null)
		{
			_target.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		super.addEventListener(type, listener);
	}
	
	override public function removeEventListener(type:String, listener:Function):Void 
	{
		if (type == Event.ENTER_FRAME && _target != null)
		{
			_target.removeEventListener(type, onEnterFrame);
		}
		super.removeEventListener(type, listener);
	}
	
	private function onEnterFrame(event:Event):Void
	{
		dispatchEvent(event);
	}
	
	// internal methods
	
	/** @private */
	public function setTarget(target:FFParticleSystem = null, vertexData:VertexData = null, indexData:IndexData = null):Void
	{
		if (_target != target)
		{
			if (_target != null)
			{
				_target.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
				//effectType._instances.splice(effectType._instances.indexOf(_target), 1);
				Reflect.getProperty(effectType, "_instances").splice(Reflect.getProperty(effectType, "_instances").indexOf(_target), 1);
			}
			
			_target = target;
			
			if (_target != null)
			{
				if (hasEventListener(Event.ENTER_FRAME))
				{
					_target.addEventListener(Event.ENTER_FRAME, onEnterFrame);
				}
				
				//effectType._instances.push(_target);
				Reflect.getProperty(effectType, "_instances").push(_target);
				onTargetAssigned(_target);
			}
		}
	}
	
	/** The actual class of this style. */
	public var type(get, never):Class<Dynamic>;
	private function get_type():Class<Dynamic> { return _type; }
	
	/** The texture that is mapped to the mesh (or <code>null</code>, if there is none). */
	public var texture(get, set):Texture;
	private function get_texture():Texture { return _texture; }
	private function set_texture(value:Texture):Texture
	{
		throw new Error("Use the SystemOption instance to set the texture");
	}
	
	/** The smoothing filter that is used for the texture. @default bilinear */
	public var textureSmoothing(get, set):String;
	private function get_textureSmoothing():String { return _textureSmoothing; }
	private function set_textureSmoothing(value:String):String
	{
		if (value == _textureSmoothing) return value;
		_textureSmoothing = value;
		setRequiresRedraw();
		return _textureSmoothing;
	}
	
	/** Indicates if pixels at the edges will be repeated or clamped.
	 *  Only works for power-of-two textures. @default false */
	public var textureRepeat(get, set):Bool;
	private function get_textureRepeat():Bool { return _textureRepeat; }
	private function set_textureRepeat(value:Bool):Bool
	{
		return _textureRepeat = value;
	}
	
	/** The target the style is currently assigned to. */
	public var target(get, never):FFParticleSystem;
	private function get_target():FFParticleSystem { return _target; }
	
}