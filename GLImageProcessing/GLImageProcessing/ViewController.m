//
//  ViewController.m
//  GLImageProcessing
//
//  Created by 23 on 9/8/12.
//  Copyright (c) 2012 Aged & Distilled. All rights reserved.
//

#import "ViewController.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniforms
enum {
    UNIFORM_SOURCE_TEXTURE,
        // identifies the uniform shader var that will
        // be the texture sampler for our source image
    UNIFORM_AMOUNT_SCALAR,
        // identifies a uniform we will use to pass a
        // floating point 'scalar' value to various shaders
    NUM_UNIFORMS
};



#pragma mark - Statics


// This will hold the identifiers for the uniforms we will reference in our shader programs
static GLint uniforms[NUM_UNIFORMS];


// Here we declare the vertices that will make up our quad. For each vertex we also include a
// texture coordinate. This will make each corner of the source image to a corner on the quad

GLfloat gQuadVertexData[] =
{
    // Data layout for each line below is:
    // X, Y,              // u, v
    -1.0f, -1.0f,       0.0f, 0.0f,
    1.0f, -1.0f,        1.0f, 0.0f,
    -1.0f,  1.0f,       0.0f, 1.0f,
    1.0f,  1.0f,        1.0f, 1.0f,
};

#pragma mark -

@interface ViewController () <GLKViewDelegate>
{
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo* textureInfo;
@property (weak, nonatomic) IBOutlet UISlider *slider;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ViewController
@synthesize slider = _slider;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.delegate = self;
    
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    [self setupGL];
}

- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    [self loadSourceImageTexture];
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(gQuadVertexData), gQuadVertexData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, 16, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 16, BUFFER_OFFSET(8));
    
    glBindVertexArrayOES(0);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - Source Image Texture

- (void) loadSourceImageTexture
{
    NSError* loadError = nil;
    NSString* imagePath = [[NSBundle mainBundle] pathForResource:@"source_image" ofType:@"jpg"];

    NSDictionary* options = @{GLKTextureLoaderOriginBottomLeft: [NSNumber numberWithBool:YES]};
    self.textureInfo = [GLKTextureLoader textureWithContentsOfFile:imagePath options:options error:&loadError];
    
    if ( self.textureInfo == nil )
    {
        NSLog(@"Could not load texture: %@", loadError.localizedFailureReason);
    }
}

#pragma mark - Actions

- (IBAction)sliderValueChanged:(id)sender
{
    [self.view setNeedsDisplay];
}

- (void)viewTapped:(id)sender
{
    // We'll double the size of the veiw just to demonstrate how it works. On a Retina device this will result in scaling the content larger than the original 640 x 960 iamge
    
    GLsizei width = self.view.bounds.size.width * self.view.contentScaleFactor * 2.0;
    GLsizei height = self.view.bounds.size.height * self.view.contentScaleFactor * 2.0;
    UIImage* image = [self imageByRenderingViewAtSize:(CGSize){width, height}];
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    UIAlertView* view = [[UIAlertView alloc] initWithTitle:@"Image Saved" message:@"Processed image has been saved to the Camera Roll in the Photo Library" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [view show];
}

#pragma mark - GLKView Delegate


- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // bind the vertex data that defines our 'scene'
    glBindVertexArrayOES(_vertexArray);
    
    // Bind the source texture to a texture unit #
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureInfo.name);
    
    glUseProgram(_program);

    // set the sampler uniform value to the texture unit # to sample from
    glUniform1i(uniforms[UNIFORM_SOURCE_TEXTURE], 0);
    
    // Set the scalar amount based on the current slider value
    glUniform1f(uniforms[UNIFORM_AMOUNT_SCALAR], self.slider.value);
    
    // Render
    
    // This causes GL to draw our scene with the current state- including the vertices and color attributes we have supplied to the state above. The drawing is raterized into the current framebuffer
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}


#pragma mark - Offscreen rendering

- (UIImage*)imageByRenderingViewAtSize:(CGSize)size;
{
    // Explicitly make a new Framebuffer so there is control over the size of the final rendered image. If the source image is smaller than the destination framebuffer, scaling will occur, which could degrade image quality. This techinque is useful when the original image is larger than the screen size and you want to maintain that resolution. Note that the device HW limits the renderBuffer size, just like the maxium texture size. On latest generation iOS Devices the limit is 2048 x 2048 (4096 x 4096 for iPad 2 & 3). On older devices the limit is 1024 x 1024.
    
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    GLuint colorRenderbuffer;
    glGenRenderbuffers(1, &colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, size.width, size.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if(status != GL_FRAMEBUFFER_COMPLETE)
        NSLog(@"failed to make complete framebuffer object %x", status);
    
    // establish the viewport coordinates to match the size of the buffer;
    glViewport(0, 0, size.width, size.height);
    
    // draw into the framebuffer
    GLKView *view = (GLKView *)self.view;
    [self glkView:view drawInRect:view.bounds];
    
    // Create a Core Graphics bitmap context
    CGContextRef context = [self newBitmapContextForSize:size];
    CGContextClearRect(context, (CGRect){0.0, 0.0, size.width, size.height});
     
    // copy the rendered pixels from the GL Framebuffer to the Core Graphics bitmap
    void* pixelData = CGBitmapContextGetData(context);
    glReadPixels(0, 0, size.width, size.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelData);
     
    CGImageRef contextImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
        
    UIImage* image = [[UIImage alloc] initWithCGImage:contextImage];
    CGImageRelease(contextImage);
    
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteRenderbuffers(1, &colorRenderbuffer);
    
    // restore the view's normal framebuffer
    [view bindDrawable];
    
    return image;
}

- (CGContextRef) newBitmapContextForSize:(CGSize)size
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGBitmapInfo	bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
	int				rowByteWidth = size.width * 4;
	
	CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, rowByteWidth, colorSpace, bitmapInfo);
    CGColorSpaceRelease( colorSpace );
    
    return context;
}


#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"VignetteShader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "textureCoordinate");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get Uniform locations from the linked programs

    uniforms[UNIFORM_SOURCE_TEXTURE] = glGetUniformLocation(_program, "sourceTexture");
    uniforms[UNIFORM_AMOUNT_SCALAR] =  glGetUniformLocation(_program, "amount");

    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (void)viewDidUnload {
    [self setSlider:nil];
    [super viewDidUnload];
}
@end
