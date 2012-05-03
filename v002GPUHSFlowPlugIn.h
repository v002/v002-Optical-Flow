//
//  v002GPUHSFlowPlugin.h
//  v002 Optical Flow
//
//  Created by vade on 3/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "v002MasterPluginInterface.h"


@interface v002GPUHSFlowPlugIn : v002MasterPluginInterface 
{
}

@property (assign) id<QCPlugInInputImageSource> inputImage;
@property (assign) id<QCPlugInInputImageSource> inputImage2;
@property (assign) double inputScale;
@property (assign) double inputOffset;
@property (assign) double inputLambda;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;

@end

@interface v002GPUHSFlowPlugIn (Execution)
- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh previousWidth:(NSUInteger)previousPixelsWide previousHeight:(NSUInteger)previousPixelsHigh bounds:(NSRect)bounds texture:(GLuint)videoTexture previousTexture:(GLuint)previousVideoTexture scale:(double)scale offset:(double)offset lambda:(double)lambda;
@end
