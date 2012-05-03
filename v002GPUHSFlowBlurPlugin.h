//
//  v002GPUHSFlowBlurPlugin.h
//  v002 Optical Flow
//
//  Created by vade on 3/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "v002MasterPluginInterface.h"


@interface v002GPUHSFlowBlurPlugin : v002MasterPluginInterface 
{
}

@property (assign) id<QCPlugInInputImageSource> inputImage;
@property (assign) id<QCPlugInInputImageSource> inputImage2;
@property (assign) double inputAmount;


@property (assign) id<QCPlugInOutputImageProvider> outputImage;

@end

@interface v002GPUHSFlowBlurPlugin (Execution)
- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh previousWidth:(NSUInteger)previousPixelsWide previousHeight:(NSUInteger)previousPixelsHigh bounds:(NSRect)bounds texture:(GLuint)videoTexture previousTexture:(GLuint)previousVideoTexture amount:(double)amount;
@end
