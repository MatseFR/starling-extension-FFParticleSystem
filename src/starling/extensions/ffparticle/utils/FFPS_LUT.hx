package starling.extensions.ffparticle.utils;
import openfl.Vector;

/**
 * ...
 * @author Matse
 */
class FFPS_LUT 
{
	public static var cos:Vector<Float> = new Vector<Float>(0x800, true);
	public static var sin:Vector<Float> = new Vector<Float>(0x800, true);
	private static var initialized:Bool = false;
	
	/**
	 * Creates look up tables for sin and cos, to reduce function calls.
	 */
	public static function init() :Void
	{
		//run once
		if(!initialized){
			for (i in 0...0x800)
			{
				cos[i & 0x7FF] = Math.cos(i * 0.00306796157577128245943617517898); // 0.003067 = 2PI/2048
				sin[i & 0x7FF] = Math.sin(i * 0.00306796157577128245943617517898);
			}
			initialized = true;
		}
	}
	
}