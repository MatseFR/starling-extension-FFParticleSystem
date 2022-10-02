package starling.extensions.ffparticle;

/**
 * ...
 * @author Matse
 */
class Frame 
{

	public var particleHalfWidth:Float = 1.0;
	public var particleHalfHeight:Float = 1.0;
	public var textureX:Float = 0.0;
	public var textureY:Float = 0.0;
	public var textureWidth:Float = 1.0;
	public var textureHeight:Float = 1.0;
	public var rotated:Bool = false;

	public function new(nativeTextureWidth:Float = 64, nativeTextureHeight:Float = 64, x:Float = 0.0, y:Float = 0.0, width:Float = 64.0, height:Float = 64.0, rotated:Bool = false)
	{
		textureX = x / nativeTextureWidth;
		textureY = y / nativeTextureHeight;
		textureWidth = (x + width) / nativeTextureWidth;
		textureHeight = (y + height) / nativeTextureHeight;
		particleHalfWidth = width / 2;//(width) >> 1;
		particleHalfHeight = height / 2;//(height) >> 1;
		this.rotated = rotated;
	}
	
}