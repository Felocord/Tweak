#import <Foundation/Foundation.h>

#define LOG_PREFIX @"[Felocord]"
#define FelocordLog(fmt, ...) NSLog((LOG_PREFIX @" " fmt), ##__VA_ARGS__)