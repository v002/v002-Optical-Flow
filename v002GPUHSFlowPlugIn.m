//
//  v002GPUHSFlowPlugin.h
//  v002 Optical Flow
//
//  Created by vade on 3/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "v002GPUHSFlowPlugIn.h"

#define	kQCPlugIn_Name				@"v002 Optical Flow"
#define	kQCPlugIn_Description		@"GPU based Horn-Schunke Optical Flow Implementation. Note this patch requires input frames to be black and white. - Based on original code by Andrew Benson. Kindly ported with permission.\n \rhttp://pixlpa.com - Thanks Andrew!"

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}

@implementation v002GPUHSFlowPlugIn

@dynamic inputImage;
@dynamic inputImage2;
@dynamic inputScale;
@dynamic inputOffset;
@dynamic inputLambda;
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
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Previous Image", QCPortAttributeNameKey, nil];
	}
	
	if([key isEqualToString:@"inputScale"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"HSFlow Scale", QCPortAttributeNameKey, nil];
	}

	if([key isEqualToString:@"inputOffset"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"HSFlow Offset", QCPortAttributeNameKey, nil];
	}

	if([key isEqualToString:@"inputLambda"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"HSFlow Noise Removal", QCPortAttributeNameKey, nil];
	}

	if([key isEqualToString:@"outputImage"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	}
	
	return nil;
}
+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputImage",@"inputImage2", @"inputScale", @"inputOffset", @"inputLambda", nil];
	
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
		self.pluginShaderName = @"v002.GPUHSFlow";
	}
	
	return self;
}

@end

@implementation v002GPUHSFlowPlugIn (Execution)

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
	
	GLfloat scale = self.inputScale;
	GLfloat offset = self.inputOffset;
	GLfloat lambda = self.inputLambda;
		
	CGColorSpaceRef cspace = ([image shouldColorMatch]) ? [context colorSpace] : [image imageColorSpace];
	CGColorSpaceRef prevcspace = ([previousImage shouldColorMatch]) ? [context colorSpace] : [previousImage imageColorSpace];
	
	if(image &&  [image lockTextureRepresentationWithColorSpace:cspace forBounds:[image imageBounds]]
		&& previousImage && [previousImage lockTextureRepresentationWithColorSpace:prevcspace forBounds:[previousImage imageBounds]])
	{	
		
		[image bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
		[previousImage bindTextureRepresentationToCGLContext:cgl_ctx textureUnit:GL_TEXTURE1 normalizeCoordinates:YES];
		
		GLuint finalOutput;
		
		finalOutput = [self renderToFBO:cgl_ctx width:width height:height previousWidth:previousWidth previousHeight:previousHeight bounds:bounds texture:[image textureName] previousTexture:[previousImage textureName] scale:scale offset:offset lambda:lambda]; 
		
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
				
		[previousImage unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE1];
		[previousImage unlockTextureRepresentation];
		
		[image unbindTextureRepresentationFromCGLContext:cgl_ctx textureUnit:GL_TEXTURE0];
		[image unlockTextureRepresentation];
	}	
	else
		self.outputImage = nil;
	
	return YES;
}

- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh previousWidth:(NSUInteger)previousPixelsWide previousHeight:(NSUInteger)previousPixelsHigh bounds:(NSRect)bounds texture:(GLuint)videoTexture previousTexture:(GLuint)previousVideoTexture scale:(double)scale offset:(double)offset lambda:(double)lambda
{
	GLsizei width = bounds.size.width,	height = bounds.size.height;
	
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
    
    // new texture
    GLuint fboTex = 0;
    glGenTextures(1, &fboTex);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, fboTex);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
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

	glActiveTexture(GL_TEXTURE0);
	glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, videoTexture);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);	

	// bind our shader program
	glUseProgramObjectARB([pluginShader programObject]);
		
	// set program vars
	glUniform1iARB([pluginShader getUniformLocation:"tex0"], 0); // load tex0 sampler to texture unit 0 
	glUniform1iARB([pluginShader getUniformLocation:"tex1"], 1); // load tex1 sampler to texture unit 1 
	glUniform2fARB([pluginShader getUniformLocation:"scale"], scale, scale); 
	glUniform2fARB([pluginShader getUniformLocation:"offset"], offset, offset);  
	glUniform1fARB([pluginShader getUniformLocation:"lambda"], lambda);
	
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
