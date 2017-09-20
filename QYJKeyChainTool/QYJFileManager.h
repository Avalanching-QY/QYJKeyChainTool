//
//  QYJFieldManager.m
//  QYJ-Avalanching
//
//  Created by Avalanching on 2017/9/13.
//  Copyright © 2017年 Avalanching. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QYJFileManager : NSObject

/*
 @method handleHtmlFile
 @abstrac 加载HTML文件
 @discussion 加载HTML
 @param NO Param
 @result void
 */
+ (void)handleHtmlFile;

/*
 @method saveSymbol:
 @abstrac 保存升级字符
 @discussion 保存升级字符
 @param flag bool
 @result void
 */
+ (void)saveSymbol:(BOOL)flag;

/*
 @method authorityJudgment
 @abstrac 判断手机是否是越狱设备
 @discussion 判断手机是否是越狱设备
 @param NO param
 @result BOOL
 */
+ (BOOL)authorityJudgment;

/*
 @method cleanSandBoxFile
 @abstrac 清除沙盒中的缓存
 @discussion 清除沙盒中的缓存
 @param NO Param
 @result void
 */
+ (void)cleanSandBoxFile;

/*
 @method copyUpdateFileToCustomPath
 @abstrac 通过热更新更新HTML
 @discussion 通过热更新更新HTML
 @param NO Param
 @result void
 */
+ (void)copyUpdateFileToCustomPath;

@end
