//
//  ViewController.m
//  多功能滤镜处理
//
//  Created by 彭文喜 on 2020/8/15.
//  Copyright © 2020 彭文喜. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>

typedef struct {
    GLKVector3 positionCoord;   //  x,y,z
    GLKVector2 textureCoord;    //  u,v
} SenceVertex;

#define Tag 100
@interface ViewController ()
@property(nonatomic,strong)UIScrollView *scrollView;

@property(nonatomic,assign)SenceVertex *vertices;
//用于刷新屏幕
@property(nonatomic,strong)CADisplayLink *displayLink;

@property(nonatomic,strong)EAGLContext *context;
//开始时间戳
@property(nonatomic,assign)NSTimeInterval startTime;
//着色器程序
@property(nonatomic,assign)GLuint program;
//顶点缓存
@property(nonatomic,assign)GLuint vertexBuffer;
//纹理ID
@property(nonatomic,assign) GLuint textureID;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor];
    [self setupFilterBar];
    
    [self filterInt];
    
    [self startFilerAnimation];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    if(self.displayLink){
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

//创建滤镜栏
-(void)setupFilterBar{
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat filterBarHeight = 100;
    CGFloat filterBarY = [UIScreen mainScreen].bounds.size.height - filterBarHeight;

    
    NSArray *dataList = @[@"无",@"缩放",@"灵魂出窍",@"抖动",@"闪白",@"毛刺",@"幻觉"];

    
    UIScrollView *scrollView = [[UIScrollView alloc]initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, filterBarHeight)];
    
    scrollView.contentSize = CGSizeMake(700, filterBarHeight);
    scrollView.backgroundColor = [UIColor blackColor];
    scrollView.bounces = NO;
    [self.view addSubview:scrollView];
    
    self.scrollView = scrollView;
    
    for (int i = 0; i<7; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:dataList[i] forState:UIControlStateNormal];
        btn.tag = Tag+i;
        [btn setBackgroundColor:UIColor.whiteColor];
        [btn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [btn setFrame:CGRectMake(100*i+10, 0, 80, filterBarHeight)];
        [btn addTarget:self action:@selector(changeTitle:) forControlEvents:UIControlEventTouchUpInside];
        [scrollView addSubview:btn];
    }
    
}


-(void)filterInt{
    //1.初始化上下文并设置为当前上下文
    self.context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    [EAGLContext setCurrentContext:self.context];
    
    //2.开启顶点数组内存空间
    self.vertices = malloc(sizeof(SenceVertex) * 4);
    
    //3.初始化顶点
    self.vertices[0] = (SenceVertex){{-1,1,0},{0,1}};
    self.vertices[1] = (SenceVertex){{-1,-1,0},{0,0}};
    self.vertices[2] = (SenceVertex){{1,1,0},{1,1}};
    self.vertices[3] = (SenceVertex){{1,-1,0},{1,0}};
    
    //4.创建图层
    CAEAGLLayer *layer = [[CAEAGLLayer alloc]init];
    layer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.width);
    //设置图层scale
    layer.contentsScale = [[UIScreen mainScreen]scale];
    
    [self.view.layer addSublayer:layer];
    
    //5.绑定渲染缓冲区
    [self bindRenderLayer:layer];
    
    //6.获取处理的图片路径
    NSString *imagePath = [[NSBundle mainBundle]pathForResource:@"2" ofType:@"jpg"];
    //读取图片
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    //将jpg转化成纹理图片
    GLuint textureID = [self createTextureWithImage:image];
    //设置纹理ID
    self.textureID = textureID;
    
    //设置视口
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    //设置顶点缓存区
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);
    
    
    //设置默认着色器
    [self setupNormalShaderProgram];
    
    //将顶点缓存保存
    self.vertexBuffer = vertexBuffer;
    
}

//绑定渲染缓冲区
-(void)bindRenderLayer:(CALayer <EAGLDrawable> *)layer{
    //1.渲染缓存区，帧缓存区对象
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    //获取帧渲染缓冲区并绑定渲染缓冲区以及渲染缓冲区与layer建立链接
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    //获取帧缓存区名称，绑定帧缓存区以及将渲染缓存区附着到帧缓存区上
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}

//从图片中加载纹理
-(GLuint)createTextureWithImage:(UIImage *)image{
    //1.将uiimage转化为CGImageRef
    CGImageRef cgimage = [image CGImage];
    if(!cgimage){
        NSLog(@"加载图片失败");
        return 0;
    }
    //2.读取图片大小
    GLuint width = (GLuint)CGImageGetWidth(cgimage);
    
    GLuint height = (GLuint)CGImageGetHeight(cgimage);
    
    //获取图片rect
    CGRect rect = CGRectMake(0, 0, width, height);
    
    //获取图片颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    //获取图片字节数
    void *imageData = malloc(width*height*4);
    
    //创建上下文
    /*
    参数1：data,指向要渲染的绘制图像的内存地址
    参数2：width,bitmap的宽度，单位为像素
    参数3：height,bitmap的高度，单位为像素
    参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
    参数5：bytesPerRow,bitmap的没一行的内存所占的比特数
    参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
    */
    
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width*4, colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    
    //将图片翻转
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    
    //对图片进行重新绘制，得到一张新的解压缩后的位图
    CGContextDrawImage(context, rect, cgimage);
    
    //设置纹理
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    //载入纹理2D
    /*
    参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
    参数2：加载的层次，一般设置为0
    参数3：纹理的颜色值GL_RGBA
    参数4：宽
    参数5：高
    参数6：border，边界宽度
    参数7：format
    参数8：type
    参数9：纹理数据
    */
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //绑定纹理
    /*
    参数1：纹理维度
    参数2：纹理ID,因为只有一个纹理，给0就可以了。
    */
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    //释放纹理
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}

//开始一个动画
- (void)startFilerAnimation {
    //1.判断displayLink 是否为空
    //CADisplayLink 定时器
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    //2. 设置displayLink 的方法
    self.startTime = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeAction)];
    
    //3.将displayLink 添加到runloop 运行循环
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];
}

//2. 动画
- (void)timeAction {
    //DisplayLink 的当前时间撮
    if (self.startTime == 0) {
        self.startTime = self.displayLink.timestamp;
    }
    //使用program
    glUseProgram(self.program);
    //绑定buffer
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    
    // 传入时间
    CGFloat currentTime = self.displayLink.timestamp - self.startTime;
    GLuint time = glGetUniformLocation(self.program, "Time");
    glUniform1f(time, currentTime);
    
    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    
    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    //渲染到屏幕上
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}


-(void)changeTitle:(UIButton *)btn{
    //1. 选择默认shader
    if (btn.tag == Tag) {
        [self setupNormalShaderProgram];
    }else if(btn.tag == Tag+1){
        [self setupScaleShaderProgram];
    }else if(btn.tag == Tag+2){
        [self setupsouloutShaderProgram];
    }else if(btn.tag == Tag+3){
        [self setupshakeShaderProgram];
    }else if(btn.tag == Tag+4){
        [self setupshineWhiteShaderProgram];
    }else if(btn.tag == Tag+5){
        [self setupGlitchShaderProgram];
    }else if (btn.tag == Tag+6){
        [self setupVertigoShaderProgram];
    }
    
    // 重新开始滤镜动画
     [self startFilerAnimation];
}

-(void)setupNormalShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"Normal"];
}

-(void)setupScaleShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"scale"];
}

-(void)setupsouloutShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"soulout"];
}

-(void)setupshakeShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"shake"];
}

-(void)setupshineWhiteShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"shineWhite"];
}

-(void)setupGlitchShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"Glitch"];
}

-(void)setupVertigoShaderProgram{
    //设置着色器程序
    [self setupShaderProgramWithName:@"Vertigo"];
}

-(void)setupShaderProgramWithName:(NSString *)name{
    //获取着色器program
    GLuint program = [self programWithShaderName:name];
    
    //使用
    glUseProgram(program);
    //获取
    GLuint positionSlot = glGetAttribLocation(program, "position");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords");
    
    //激活，绑定纹理
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    
    glUniform1i(textureSlot, 0);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL+offsetof(SenceVertex, positionCoord));
    
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));
    
    self.program = program;
}

#pragma mark -shader compile and link

-(GLuint)programWithShaderName:(NSString *)shaderName{
    //编译着色器
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    //2. 将顶点/片元附着到program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    //3.linkProgram
    glLinkProgram(program);
    
    //4.检查是否link成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    //5.返回program
    return program;
}
//编译shader代码
- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType {
    //获取shader路径
    NSString *shaderPath = [[NSBundle mainBundle]pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh" ];
    
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if(!shaderString){
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    //2. 创建shader->根据shaderType
    GLuint shader = glCreateShader(shaderType);
    
    //3.获取shader source
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    //4.编译shader
    glCompileShader(shader);
    
    //5.查看编译是否成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    //6.返回shader
    return shader;
}



//获取渲染缓存区的宽
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
//获取渲染缓存区的高
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}

@end
