//
//  QYJFieldManager.m
//  QYJ-Avalanching
//
//  Created by Avalanching on 2017/9/13.
//  Copyright © 2017年 Avalanching. All rights reserved.
//

#import "QYJFileManager.h"
#import "EncryptionTools.h"
#import "ZipArchive.h"

// 文件 NSFileManager
#define QYJFileSingle [NSFileManager defaultManager]

// 沙盒中的Document路径
#define QYJPaths NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)

// 沙盒中Document路径具体的路径
#define QYJDocumentPath ([QYJPaths count] > 0) ? [QYJPaths objectAtIndex:0] : @""

// NSUserDefaulst 存取类 这里用来标识，app是否进行了解码，app进行热更之后需要重新解码
#define QYJUserDefaults [NSUserDefaults standardUserDefaults]

// 解密的文件夹 存放在沙盒中的路径
#define QYJSuffixPath @"/Customer"

#define QYJWidgetPath QYJSuffixPath@"/widget"

// 这两个是用于判断设备是否越狱了
#define ARRAY_SIZE(a) sizeof(a)/sizeof(a[0])
const char* jailbreak_tool_pathes[] = {
    "/Applications/Cydia.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/bin/bash",
    "/usr/sbin/sshd",
    "/etc/apt"
};

// app是否热更的标识
static NSString *const QYJResetSymbolKey = @"AvalanchingSymbolKey";

/**
 *  测试的时候发现不满足16个字符的长度，也是可以成功的，
 *  但是Android那边只能是16个字符，故这里都写成16个字符。
 *  偏移量同理。
 */
// 加密的密码 这里需要16个字符
static NSString *const key = @"qwertyuiopasdfgh";

// 数据的偏移量（CBC所谓的链条）这里需要16个字符
static NSString *const iv = @"0102030405060708";

@implementation QYJFileManager

/**
 * load 方法是先于main函数加载的，是app启动，资源文件和相关代码加入内存
 * 时候调用的，系统自动调用。将这里东西全部打包到.a库中，它会自动去执行，无需外部去调用和引用。
 */
+ (void)load {
    [super load];
    
    NSLog(@"sandbox Path:%@", QYJDocumentPath);
    [self handleKeyChainFile];
    
//    // 解压缩解码
//    [self zipArchive];

//    [self dencrytionFileBySandBox];

}

+ (void)handleKeyChainFile {
    
    [self fileMoveToSandBox];
    
    [self encrytionFileBySandBox];
    
    [self zipArchiveToFile];
}

+ (void)handleHtmlFile {
    if ([self isResetting]) {
        // 移动文件夹到沙盒子
        [self fileMoveToSandBox];
        // copy成功->解密
        [self dencrytionFileBySandBox];
        // 保存标字符
        [self saveSymbol:NO];
    }
}

// 工程里面的文件移动到沙盒里面

+ (BOOL)fileMoveToSandBox {
    
    NSString *appLib = [QYJDocumentPath stringByAppendingString:QYJSuffixPath];
    // 判断是否存在 Customer 文件夹
    BOOL flag = [QYJFileSingle fileExistsAtPath:appLib];
    if (flag) {
        // 存在且不需要升级
        flag = [QYJFileSingle isDeletableFileAtPath:appLib];
        if (flag) {
            // 删除重新拷贝文件
            [self cleanSandBoxFile];
        } else {
            return NO;
        }
    }
    
    // 将加密的文件 copy到沙盒
    /**
     * - (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext;
     * 获取工程中一个"文件"的路径
     */
    
    /**
     * - (nullable NSString *)pathForAuxiliaryExecutable:(NSString *)executableName;
     * 获取工程中一个"文件夹"的路径
     */
    NSString *path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"widget"];
    
    // 创建文件夹
    [QYJFileManager createFolder:appLib];
    
    // 将项目中的文件加copy到沙盒
    BOOL filesPresent = [self copyMissingFile:path toPath:appLib];
    
    // 这里判断是否成功了。添加额外的操作
    if (filesPresent) {
        return YES;
    } else {
        return NO;
    }
}

// 拷贝文件夹到指定目录 传入两个文件夹路径
+ (BOOL)copyMissingFile:(NSString *)sourcePath toPath:(NSString *)toPath {
    
    BOOL retVal = YES;
    
    NSString * finalLocation = [toPath stringByAppendingPathComponent:[sourcePath lastPathComponent]];
    
    if (![QYJFileSingle fileExistsAtPath:finalLocation]) {
        retVal = [QYJFileSingle copyItemAtPath:sourcePath toPath:finalLocation error:NULL];
    }
    
    return retVal;
}

// 传入了一个文件路径（包含文件夹名字）
+ (BOOL)createFolder:(NSString *)createDir {
    
    BOOL isDir = NO;
    
    BOOL existed = [QYJFileSingle fileExistsAtPath:createDir isDirectory:&isDir];
    
    if (!(YES == isDir && YES == existed)) {
        [QYJFileSingle createDirectoryAtPath:createDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return isDir;
}

// 获取需要加解密的文件路径 只能获取到文件下下的路径，完整的路径需要再拼接
+ (NSArray *)getWidgetFinderAllFile {
    NSString* widgetPath = [QYJDocumentPath stringByAppendingString:QYJWidgetPath];
    NSError *err = nil;
    NSArray *files = [QYJFileSingle subpathsOfDirectoryAtPath:widgetPath error:&err];
    NSMutableArray *results = @[].mutableCopy;
    
    for (NSString *name in files) {
        // 选择要操作文件
        if ([name hasSuffix:@".png"]                ||
            [name hasSuffix:@".pubxml"]             ||
            [name hasSuffix:@".p12"]                ||
            [name hasSuffix:@".TTF"]                ||
            [name hasSuffix:@".csproj"]             ||
            [name hasSuffix:@".project"]            ||
            [name rangeOfString:@"."].length == 0   ||
            [name hasSuffix:@".gif"]                ||
            [name hasSuffix:@".jpg"]                ||
            [name hasSuffix:@".xml"]) {
            continue;
        } else {
            [results addObject:name];
        }
    }
    
    return results;
}

#pragma mark - decrytion 解密 begin
//  解密的入口
+ (void)dencrytionFileBySandBox {
    NSArray *array = [self getWidgetFinderAllFile];
    if (array) {
        [self dencryptionHTMLFileWithFiles:array];
    } else {
        return;
    }
}

// 解密
+ (NSString *)dencrytionFileWithNSString:(NSString *)content {
    EncryptionTools *tool = [EncryptionTools sharedEncryptionTools];
    // AES -- CBC
    NSData *data = [iv dataUsingEncoding:NSUTF8StringEncoding];
    NSString *result = [tool decryptString:content keyString:key iv:data];
    
    return result;
}

// 拼接解密路径
+ (void)dencryptionHTMLFileWithFiles:(NSArray *)names {
    for (NSString *name in names) {
        NSString *suffix = [NSString stringWithFormat:@"%@/%@", QYJWidgetPath, name];
        NSString *path = [QYJDocumentPath stringByAppendingString:suffix];
        NSError *error = nil;
        NSString *content = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            // 解密
            content = [self dencrytionFileWithNSString:content];
            if (!content || content.length == 0) {
                NSLog(@"解密失败了！！！！content is nil");
                continue;
            }
            // 重新写入文件
            [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"%@", error);
            }
        } else {
            NSLog(@"解密失败");
        }
    }
}
#pragma mark - Dencrytion 解密 end

#pragma mark - Encrytion 加密 begin

+ (void)encrytionFileBySandBox {
    NSArray *array = [self getWidgetFinderAllFile];
    if (array) {
        [self encryptionHTMLFileWithFiles:array];
    } else {
        return;
    }
}

+ (void)encryptionHTMLFileWithFiles:(NSArray *)names {
    for (NSString *name in names) {
        NSString *suffix = [NSString stringWithFormat:@"/Customer/widget/%@", name];
        NSString *path = [QYJDocumentPath stringByAppendingString:suffix];
        
        NSError *error = nil;
        NSString *content = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            // 加密
            content = [self encrytionFileWithNSString:content];
            
            // 写入文件
            [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
        } else {
            NSLog(@"加密失败");
        }
    }
}

+ (NSString *)encrytionFileWithNSString:(NSString *)content {
    EncryptionTools *tool = [EncryptionTools sharedEncryptionTools];
    // AES -- CBC
    NSData *data = [iv dataUsingEncoding:NSUTF8StringEncoding];
    NSString *result = [tool encryptString:content keyString:key iv:data];
    return result;
}

#pragma mark - Encrytion 加密 end


// 保存是否重新导入
+ (BOOL)isResetting {
    id object = [QYJUserDefaults objectForKey:QYJResetSymbolKey];
    if (object) {
        return [object boolValue];
    } else {
        return YES;
    }
}

// 设置热更的标识，判断是否需要更新
+ (void)saveSymbol:(BOOL)flag {
    [QYJUserDefaults setObject:@(flag) forKey:QYJResetSymbolKey];
    [QYJUserDefaults synchronize];
}

// 判断手机是否是越狱的
+ (BOOL)authorityJudgment {
    for (int i = 0; i < ARRAY_SIZE(jailbreak_tool_pathes); i++) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:jailbreak_tool_pathes[i]]]) {
            // 越狱了
            return YES;
        }
    }
    // 没有越狱
    return NO;
}

// 清除沙盒里面的文件
+ (void)cleanSandBoxFile {
    NSString *appLib = [QYJDocumentPath stringByAppendingString:QYJSuffixPath];
    NSError *error = nil;
    [QYJFileSingle removeItemAtPath:appLib error:&error];
    [self saveSymbol:YES];
}

// 这里是热更需要的，这里简单滴做了一次热更新，从服务器下载文件，然后将下载的文件拷贝到相应的目录下，再解码
+ (void)copyUpdateFileToCustomPath {
    // 将更新的文件拷贝到指定的文件目录下
    NSString *filePath = [QYJDocumentPath  stringByAppendingString:@"XXXXXXXXX"];
    [self cleanSandBoxFile];
    NSString *appLib = [QYJDocumentPath stringByAppendingString:QYJSuffixPath];
    [QYJFileManager createFolder:appLib];
    BOOL flag = [self copyMissingFile:filePath toPath:appLib];
    if (flag) {
        [self dencrytionFileBySandBox];
    }
}

#pragma mark - ZipArchive 压缩成zip包

+ (void)zipArchiveToFile {
    // zip包的路径
    NSString* zipFile = [QYJDocumentPath stringByAppendingString:@"/Customer/widget.zip"] ;
    // 解压的目标路径
    NSString* sourcePath = [QYJDocumentPath stringByAppendingString:@"/Customer/"] ;
    
    
    ZipArchive * zipArchive = [ZipArchive new];
    
    [zipArchive CreateZipFile2:zipFile];
    NSArray *subPaths = [QYJFileSingle subpathsAtPath:sourcePath];// 关键是subpathsAtPath方法
    for(NSString *subPath in subPaths){
        NSString *fullPath = [sourcePath stringByAppendingPathComponent:subPath];
        BOOL isDir;
        if([QYJFileSingle fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir)// 只处理文件
        {
            [zipArchive addFileToZip:fullPath newname:subPath];
        }
    }
    [zipArchive CloseZipFile2];
}

#pragma mark - ZipArchive 解压成文件夹

+ (void)zipArchive {
    
    ZipArchive* zip = [[ZipArchive alloc] init];
    // zip包的路径
    NSString* zipFile = [QYJDocumentPath stringByAppendingString:@"/Customer/widget.zip"] ;
    // 解压的目标路径
    NSString* unZipTo = [QYJDocumentPath stringByAppendingString:@"/Customer/"] ;
    
    if( [zip UnzipOpenFile:zipFile] ) {
        BOOL result = [zip UnzipFileTo:unZipTo overWrite:YES];
        if(NO == result) {
            //添加代码
        }
        [zip UnzipCloseFile];
    }
    
}

@end
