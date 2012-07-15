//
//  v002GPUHSFlowRepositionPlugin.m
//  v002 Optical Flow
//
//  Created by vade on 3/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002GPUHSFlowRepositionPlugin.h"

#define	kQCPlugIn_Name				@"v002 Optical Flow Displace"
#define	kQCPlugIn_Description		@"Image Displace via Optical Flow input. Feed the output of GPU Optical Flow into this plugin to distort based on motion vectors. Based on original code by Andrew Benson. Kindly ported with permission.\n \rhttp://pixlpa.com - Thanks Andrew!"

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

@implementation v002GPUHSFlowRepositionPlugin

@dynamic inputImage;
@dynamic inputImage2;
@dynamic inputAmountX;
@dynamic inputAmountY;
@dynamic inputFilterMode;
//@dynamic inputScaleR;
//@dynamic inputScaleG;
//@dynamic inputScaleB;
//@dynamic inputBiasR;
//@dynamic inputBiasG;
//@dynamic inputBiasB;
@dynamic outputImage;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey,
            [kQCPlugIn_Description stringByAppendingString:kv002DescriptionAddOnText], QCPlugInAttributeDescriptionKey,
            kQCPlugIn_Category, QCPlugInAttributeCategoriesKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	if([key isEqualToString:@"inputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputImage2"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Reposition Image", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputAmountX"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Amount (X)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputAmountY"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Amount (Y)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputFilterMode"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Filter Mode", QCPortAttributeNameKey,
				[NSArray arrayWithObjects:@"Nearest", @"Linear", nil], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithUnsignedInteger:0.0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey,
				[NSNumber numberWithUnsignedInteger:1.0], QCPortAttributeDefaultValueKey,
				nil];
		
		
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Amount (Y)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputScaleR"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Scale (Red)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputScaleG"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Scale (Green)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputScaleB"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Scale (Blue)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputBiasR"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Bias (Red)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputBiasG"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Bias (Green)", QCPortAttributeNameKey, nil];
	}

	if([key isEqualToString:@"inputBiasB"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Bias (Blue)", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputImage",@"inputImage2" , @"inputAmountX", @"inputAmountY", @"inputFilterMode", @"inputScaleR", @"inputScaleG", @"inputScaleB",  @"inputBiasR",  @"inputBiasG",  @"inputBiasB", nil];
	
}

+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	if(self = [super init])
	{
		self.pluginShaderName = @"v002.GPUHSFLowFlowRepos";
	}
	
	return self;
}

@end

@implementation v002GPUHSFlowRepositionPlugin (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CGLContextObj cgl_ctx = [context CGLContextObj];
	
	id<QCPlugInInputImageSource>   image = self.inputImage;
	
	id<QCPlugInInputImageSource>   previousImage = self.inputImage2;
	
	NSUInteger width = [image imageBounds].size.width;
	NSUInteger height = [image imageBounds].size.height;
	NSRect bounds = [image imageBounds];
	
	
	NSUInteger previousWidth = [previousImage imageBounds].size.width;
	NSUInteger previousHeight = [previousImage imageBounds].size.height;
	
	
	GLfloat amountX = self.inputAmountX;
	GLfloat amountY = self.inputAmountY;

/*	GLfloat scaleR = self.inputScaleR;
	GLfloat scaleG = self.inputScaleG;
	GLfloat scaleB = self.inputScaleB;

	GLfloat biasR = self.inputBiasR;
	GLfloat biasG = self.inputBiasG;
	GLfloat biasB = self.inputBiasB;
*/	
	
	CGColorSpaceRef cspace = ([image shouldColorMatch]) ? [context colorSpace] : [image imageColorSpace];
	CGColorSpaceRef prevcspace = ([previousImage shouldColorMatch]) ? [context colorSpace] : [previousImage imageColorSpace];

	if(image &&  [image lockTextureRepresentationWithColorSpace:cspace forBounds:[image imageBounds]]
	   && previousImage && [previousImage lockTextureRepresentationWithColorSpace:prevcspace forBounds:[previousImage imageBounds]])
	{	
		
		[image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
		[previousImage bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE1 normalizeCoordinates:YES];
		
		GLuint finalOutput;
		
		finalOutput = [self renderToFBO:cgl_ctx width:width height:height previousWidth:previousWidth previousHeight:previousHeight bounds:bounds texture:[image textureName] previousTexture:[previousImage textureName] amountX:amountX amountY:amountY filter:self.inputFilterMode];
		
		id provider = nil;	
		
		if(finalOutput != 0)
		{
			
#if __BIG_ENDIAN__
#define v002QCPluginPixelFormat QCPlugInPixelFormatARGB8
#else
#define v002QCPluginPixelFormat QCPlugInPixelFormatBGRA8			
#endif
			// we have to use a 4 channel output format, I8 does not support alpha at fucking all, so if we want text with alpha, we need to use this and waste space. Ugh.
			provider = [context outputImageProviderFromTextureWithPixelFormat:v002QCPluginPixelFormat pixelsWide:[image imageBounds].size.width pixelsHigh:[image imageBounds].size.height name:finalOutput flipped:NO releaseCallback:_TextureReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:[image shouldColorMatch]];
			
			self.outputImage = provider;
			
		}
		
		self.outputImage = provider;
		[previousImage unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE1];
		[previousImage unlockTextureRepresentation];	
		
		[image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
		[image unlockTextureRepresentation];
	}	
	else
		self.outputImage = nil;
	
	return YES;
}

- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh previousWidth:(NSUInteger)previousPixelsWide previousHeight:(NSUInteger)previousPixelsHigh bounds:(NSRect)bounds texture:(GLuint)videoTexture previousTexture:(GLuint)previousVideoTexture amountX:(double)amountx amountY:(double)amounty filter:(BOOL)linear
{
	GLsizei width = bounds.size.width,	height = bounds.size.height;
	
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    
    // new texture
    GLuint fboTex = 0;
    glGenTextures(1, &fboTex);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, fboTex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
	// this must be called before any other FBO stuff can happen for 10.6
	[pluginFBO pushFBO:cgl_ctx];
    [pluginFBO attachFBO:cgl_ctx withTexture:fboTex width:width height:height];
	
	glColor4f(1.0, 1.0, 1.0, 1.0);
	
	// do not need blending if we use black border for alpha and replace env mode, saves a buffer wipe
	// we can do this since our image draws over the complete surface of the FBO, no pixel goes untouched.
	glDisable(GL_BLEND);

	// draw our input video
	glActiveTexture(GL_TEXTURE1);
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, previousVideoTexture);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);	

	if(linear)
	{
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	}
	else
	{
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	
	
	glActiveTexture(GL_TEXTURE0);
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, videoTexture);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);	

	glColor4f(1.0, 1.0, 1.0, 1.0);
	
	// bind our shader program
	glUseProgramObjectARB([pluginShader programObject]);
	
	// set program vars
	glUniform1iARB([pluginShader getUniformLocation:"tex0"], 0); // load tex0 sampler to texture unit 0 
	glUniform1iARB([pluginShader getUniformLocation:"tex1"], 1); // load tex1 sampler to texture unit 1 
	glUniform2fARB([pluginShader getUniformLocation:"amt"], amountx, amounty); 
	//	glUniform4fARB(getUniformLocation(program, "scale"), scaleR, scaleG, scaleB, 1.0);  
	//	glUniform4fARB(getUniformLocation(program, "bias"), biasR, biasG, biasB, 0.0);
	
	// Use VA for speed
	GLfloat texcoords[] = 
    {
        0.0f, 0.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f
    };
	
    GLfloat verts[] = 
    {
        0, 0,
        (GLfloat) width, 0,
        (GLfloat) width, (GLfloat) height,
        0, (GLfloat) height
    };
	
	glClientActiveTexture(GL_TEXTURE1);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
	glClientActiveTexture(GL_TEXTURE0);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	
	// disable shader program
	glUseProgramObjectARB(NULL);
	
    [pluginFBO detachFBO:cgl_ctx]; // pops out and resets cached FBO state from above.
    [pluginFBO popFBO:cgl_ctx];
    
    glPopClientAttrib();
    glPopAttrib();
    
	return fboTex;
}
@end
