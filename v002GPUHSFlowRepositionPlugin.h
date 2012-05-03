//
//  v002GPUHSFlowRepositionPlugin.h
//  v002 Optical Flow
//
//  Created by vade on 3/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import "v002MasterPluginInterface.h"

@interface v002GPUHSFlowRepositionPlugin : v002MasterPluginInterface 
{
}

@property (assign) id<QCPlugInInputImageSource> inputImage;
@property (assign) id<QCPlugInInputImageSource> inputImage2;
@property (assign) double inputAmountX;
@property (assign) double inputAmountY;
@property (assign) NSUInteger inputFilterMode;
//@property (assign) double inputScaleR;
//@property (assign) double inputScaleG;
//@property (assign) double inputScaleB;
//@property (assign) double inputBiasR;
//@property (assign) double inputBiasG;
//@property (assign) double inputBiasB;

@property (assign) id<QCPlugInOutputImageProvider> outputImage;

@end

@interface v002GPUHSFlowRepositionPlugin (Execution)
- (GLuint) renderToFBO:(CGLContextObj)cgl_ctx width:(NSUInteger)pixelsWide height:(NSUInteger)pixelsHigh previousWidth:(NSUInteger)previousPixelsWide previousHeight:(NSUInteger)previousPixelsHigh bounds:(NSRect)bounds texture:(GLuint)videoTexture previousTexture:(GLuint)previousVideoTexture amountX:(double)amountx amountY:(double)amounty filter:(BOOL)linear;
@end