package starling.extensions.ffparticle;

/**
 * ...
 * @author Matse
 */
class Particle 
{

	public var x:Float = 0.0;
	public var y:Float = 0.0;
	public var scale:Float = 1.0;
	public var rotation:Float = 0.0;
	public var currentTime:Float = 0;
	public var totalTime:Float = 1.0;
	
	public var colorRed:Float = 1.0;
	public var colorGreen:Float = 1.0;
	public var colorBlue:Float = 1.0;
	public var colorAlpha:Float = 1.0;
	
	public var colorDeltaRed:Float = 0.0;
	public var colorDeltaGreen:Float = 0.0;
	public var colorDeltaBlue:Float = 0.0;
	public var colorDeltaAlpha:Float = 0.0;
	
	public var startX:Float = 0.0;
	public var startY:Float = 0.0;
	public var velocityX:Float = 0.0;
	public var velocityY:Float = 0.0;
	public var radialAcceleration:Float = 0.0;
	public var tangentialAcceleration:Float = 0.0;
	public var emitRadius:Float = 1.0;
	public var emitRadiusDelta:Float = 0.0;
	public var emitRotation:Float = 0.0;
	public var emitRotationDelta:Float = 0.0;
	public var rotationDelta:Float = 0.0;
	public var scaleDelta:Float = 0.0;
	public var frameIdx:UInt = 0;
	public var frame:Float = 0;
	public var frameDelta:Float = 0;
	
	public var fadeInFactor:Float = 0;
	public var fadeOutFactor:Float = 0;
	public var spawnFactor:Float = 0;
	
	public var active:Bool = false;

	public var customValues:Dynamic;
	
	public function new() { }
	
}