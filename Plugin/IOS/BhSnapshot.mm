//
// BhSnapshot.mm
// Screen snapshot plugin for Gideros Studio (IOS Only)

// Will dump the current contents of the OpenGL frame buffer to a temporary file and then
// answer the filename. You can then load this back in as a texture etc. Okay for deployment
// to IOS 3.1 and up.
//
// Example usage:
//
//  require "BhSnapshot"
// 	local filename=BhSnapshot.snapshot(BhSnapshot.PORTRAIT)
//  local image=Bitmap.new(Texture.new(filename))
//  image:setAnchorPoint(0.5, 0.5)
//  image:setPosition(application:getContentWidth(), application:getContentHeight())
//  stage:addChild(image)
//
// MIT License
// Copyright (C) 2012. Andy Bower, Bowerhaus LLP
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
// BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#include "gideros.h"
#include "UIImage+Resize.h"
#include "UIImage+RotScale.h"

@interface SnapshotHelper : NSObject
@end

@interface SnapshotHelper ()
@property(nonatomic, assign) CGRect bounds;
@property(nonatomic, assign) UIImageOrientation orientation;
@property(nonatomic, assign) CGFloat maxSize;
@end

@implementation SnapshotHelper {
@private
    CGRect _bounds;
    UIImageOrientation _orientation;
    CGFloat _maxSize;
}

@synthesize bounds = _bounds;
@synthesize orientation = _orientation;
@synthesize maxSize = _maxSize;


void freeImageData(void *, const void *data, size_t)
{
    NSLog(@"Image data freed");
    free((void*)data);
}

-(UIImage *)getImageFromFrameBuffer {
    UIViewController* controller = g_getRootViewController();
    CGRect bounds=controller.view.bounds;

    // Find screen scale. Note that this is only valid for IOS 4 and above so guard it.
    CGFloat scale=1.0;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        scale=UIScreen.mainScreen.scale;
    }

    size_t backingWidth= (size_t) (bounds.size.width*scale);
    size_t backingHeight= (size_t) (bounds.size.height*scale);
    GLubyte *buffer = (GLubyte *) malloc(backingWidth * backingHeight * 4);

    glReadPixels(0, 0, backingWidth, backingHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid *)buffer);

    // Make data provider from buffer
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, backingWidth * backingHeight * 4, freeImageData);

    // Set up for CGImage creation
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = 32;
    size_t bytesPerRow = 4 * backingWidth;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(backingWidth, backingHeight, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);

    // Make UIImage from CGImage
    UIImage *newUIImage = [[[UIImage alloc] initWithCGImage: imageRef] autorelease];
    UIImage *answerImage= [newUIImage rotate: self.orientation];

    // If we have a bounds rectangle then crop to this
    if (_bounds.origin.x || _bounds.origin.y || _bounds.size.width || _bounds.size.height) {
        UIImage *croppedImage= [answerImage croppedImage: _bounds];
        answerImage=croppedImage;
    }

    // If we have a max size then scale to this
    if (_maxSize !=0) {
        UIImage *scaledImage= [answerImage scaleWithMaxSize: _maxSize];
        answerImage=scaledImage;
    }

    NSLog(@"Snapshot image is extent (%f, %f)", answerImage.size.width, answerImage.size.height);

    // Free up our temporaries
    CGDataProviderRelease(provider);
    CGImageRelease(imageRef);

    return answerImage;
}

-(NSString *)pathForTemporaryFileWithFormat: (NSString *)format
{
    NSString *  result;
    CFUUIDRef   uuid;
    CFStringRef uuidStr;

    uuid = CFUUIDCreate(NULL);
    uuidStr = CFUUIDCreateString(NULL, uuid);
    result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat: format, uuidStr]];
    assert(result != nil);

    CFRelease(uuidStr);
    CFRelease(uuid);

    return result;
}

@end

static CGRect getBoundsRect(lua_State *L, int stackOffset)   {
    // Gets a bounds rectangle (CGRect) from the table parameter at (stackOffset)
    // on the Lua stack. The rectangle is assumed to have {left, top, width, height}
    // components.
    lua_pushstring(L, "left");
    lua_gettable(L, stackOffset);
    double left = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_pushstring(L, "top");
    lua_gettable(L, stackOffset);
    double top = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_pushstring(L, "width");
    lua_gettable(L, stackOffset);
    double width = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_pushstring(L, "height");
    lua_gettable(L, stackOffset);
    double height = lua_tonumber(L, -1);
    lua_pop(L, 1);

    return CGRectMake((CGFloat) left, (CGFloat) top, (CGFloat) width, (CGFloat) height);
}

static int snapshotToFile(lua_State* L) {
    SnapshotHelper *snapshotHelper= [[SnapshotHelper alloc] init];
    snapshotHelper.maxSize =0;
    snapshotHelper.orientation = UIImageOrientationDownMirrored;
    if (lua_isnumber(L, 1)) {
        snapshotHelper.maxSize = (CGFloat) lua_tonumber(L, 1);
    }
    if (lua_istable(L, 2))  {
        snapshotHelper.bounds = getBoundsRect(L, 2);
    }
    if (lua_isnumber(L, 3)) {
        snapshotHelper.orientation = (UIImageOrientation) lua_tointeger(L, 3);
    }
    NSString *imageFile;
    if (lua_isstring(L, 4))
        imageFile=[NSString stringWithUTF8String: luaL_checkstring(L, 4)];
    else
        imageFile = [snapshotHelper pathForTemporaryFileWithFormat:@"screen%@.png"];

    // Fetch the pixels from the frame buffer into an UIImage
    UIImage *image= [snapshotHelper getImageFromFrameBuffer];

    // Write image to PNG
    bool ok=[UIImagePNGRepresentation(image) writeToFile:imageFile atomically:YES];
    lua_pushstring(L, [imageFile UTF8String]);
    lua_pushboolean(L, ok);

     // Free up
    [snapshotHelper release];
    return 2;
}

static int compareImages(lua_State* L) {
    bool result=false;
    
    NSString *imageFile1=NULL;
    if (lua_isstring(L, 1))
        imageFile1=[NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    NSString *imageFile2=NULL;
    if (lua_isstring(L, 2))
        imageFile2=[NSString stringWithUTF8String: luaL_checkstring(L, 2)];
    
    if (imageFile1 != NULL && imageFile2 != NULL){
        UIImage *image1=[UIImage imageWithContentsOfFile: imageFile1];
        UIImage *image2=[UIImage imageWithContentsOfFile: imageFile2];
        if (image1 != NULL && image2 != NULL){
            NSData *data1 = UIImagePNGRepresentation(image1);
            NSData *data2 = UIImagePNGRepresentation(image2);
            result = [data1 isEqual:data2];
        }
    }
    
    lua_pushboolean(L, result);
    return 1;
}

static int snapshotToAlbum(lua_State* L) {
    bool result=true;
    SnapshotHelper *snapshotHelper= [[SnapshotHelper alloc] init];
    snapshotHelper.maxSize =1.0;
    snapshotHelper.orientation = UIImageOrientationDownMirrored;
    if (lua_isnumber(L, 1)) {
        snapshotHelper.maxSize = (CGFloat) lua_tonumber(L, 1);
    }
    if (lua_istable(L, 2))  {
        snapshotHelper.bounds = getBoundsRect(L, 2);
    }
    if (lua_isnumber(L, 3)) {
        snapshotHelper.orientation = (UIImageOrientation) lua_tointeger(L, 3);
    }

    // Fetch the pixels from the frame buffer into an UIImage
    UIImage *image= [snapshotHelper getImageFromFrameBuffer];

    // Write image to album
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);

     // Free up
    [snapshotHelper release];
    result=true;

    return result;
}

static int getPathForFile(lua_State *L) {
    NSString* filename = [NSString stringWithUTF8String: luaL_checkstring(L, 1)];
    lua_pushstring(L, g_pathForFile([filename UTF8String]) );
    return 1;
}

static int loader(lua_State *L)
{
    //This is a list of functions that can be called from Lua
    const luaL_Reg functionlist[] = {
        {"snapshotToFile", snapshotToFile},
        {"snapshotToAlbum", snapshotToAlbum},
        {"compareImages", compareImages},
        {"getPathForFile", getPathForFile} ,
        {NULL, NULL},
    };
    luaL_register(L, "BhSnapshot", functionlist);

    // This is the list of constants that can be accessed from Lua.
    // These correspond to the rotation modes that one has to use for the various device orientations.
    // Note that we use the "mirrored" options to compensate for the fact that the OpenGL frame buffer
    // is inverted.
    lua_pushnumber(L, UIImageOrientationDownMirrored);
    lua_setfield(L, -2, "PORTRAIT");
    lua_pushnumber(L, UIImageOrientationUpMirrored);
    lua_setfield(L, -2, "PORTRAIT_UPSIDEDOWN");
    lua_pushnumber(L, UIImageOrientationLeftMirrored);
    lua_setfield(L, -2, "LANDSCAPE_LEFT");
    lua_pushnumber(L, UIImageOrientationRightMirrored);
    lua_setfield(L, -2, "LANDSCAPE_RIGHT");

    //return the pointer to the plugin
    return 1;
}

static void g_initializePlugin(lua_State* L)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");

    lua_pushcfunction(L, loader);
    lua_setfield(L, -2, "BhSnapshot");

    lua_pop(L, 2);
}

static void g_deinitializePlugin(lua_State *) {
}

REGISTER_PLUGIN("BhSnapshot", "1.0")

