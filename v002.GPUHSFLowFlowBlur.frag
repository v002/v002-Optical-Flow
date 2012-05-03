//setup for 2 texture
varying vec2 texcoord0;
varying vec2 texcoord1;

uniform float amt;
uniform sampler2DRect tex0;
uniform sampler2DRect tex1;


void main()
{
    vec4 blurVector = texture2DRect(tex1,texcoord1);	//sample flow texture
	
	vec2 blurAmount = vec2(blurVector.y-blurVector.x, blurVector.w-blurVector.z);	

/*	vec4 blur1 = texture2DRect(tex1, texcoord1 + blurAmount);
	vec2 blurAmount1 = vec2(blur1.y-blur1.x, blur1.w-blur1.z);	
	
	vec4 blur2 = texture2DRect(tex1, texcoord1 + blurAmount * 2.0);
	vec2 blurAmount2 = vec2(blur2.y-blur2.x, blur2.w-blur2.z);	
*/
	vec2 amount1 = blurAmount;// + blurAmount1 + blurAmount2;
 	amount1 *= amt;

	vec2 amount2,amount3,amount4,amount5,amount6,amount7,amount8; 

	amount2 = amount1 *1.5;
	amount3 = amount1 *3.0;
	amount4 = amount1 *6.0;

	amount5 = amount1 * 8.0;
	amount6 = amount1 * 10.0;
	amount7 = amount1 * 12.0;
	amount8 = amount1 * 18.0;

	// sample our textures
	vec4 sample0 = texture2DRect(tex0, texcoord0);
	vec4 sample1 = texture2DRect(tex0, texcoord0 + amount1);
	vec4 sample2 = texture2DRect(tex0, texcoord0 + amount2);
	vec4 sample3 = texture2DRect(tex0, texcoord0 + amount3);
	vec4 sample4 = texture2DRect(tex0, texcoord0 + amount4);
	vec4 sample5 = texture2DRect(tex0, texcoord0 + amount5);
	vec4 sample6 = texture2DRect(tex0, texcoord0 + amount6);
	vec4 sample7 = texture2DRect(tex0, texcoord0 + amount7);
	vec4 sample8 = texture2DRect(tex0, texcoord0 + amount8);
	
	gl_FragColor = (sample0 + sample1 + sample2 + sample3 + sample4 + sample5 + sample6 + sample7 + sample8) / 9.0;
}