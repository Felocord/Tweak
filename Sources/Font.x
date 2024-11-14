#import "Font.h"
#import "Utils.h"
#import "Logger.h"
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>

NSMutableDictionary<NSString *, NSString *> *fontMap;

%hook UIFont

+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size {
    NSString *replacementName = fontMap[name];
    if (replacementName) {
        return %orig(replacementName, size);
    }
    return %orig;
}

+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)size {
    NSString *replacementName = fontMap[descriptor.postscriptName];
    if (replacementName) {
        UIFontDescriptor *replacementDescriptor = [UIFontDescriptor fontDescriptorWithName:replacementName size:size];
        UIFontDescriptor *finalDescriptor = [replacementDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorCascadeListAttribute: @[descriptor]}];
        
        return [UIFont fontWithDescriptor:finalDescriptor size:size];
    }
    return %orig;
}

%end

void patchFonts(NSDictionary<NSString *, NSString *> *mainFonts, NSString *fontDefName) {
    if (!fontMap) {
        fontMap = [NSMutableDictionary dictionary];
    }
    
    for (NSString *fontName in mainFonts) {
        NSString *url = mainFonts[fontName];
        BunnyLog(@"Replacing font %@ with URL: %@", fontName, url);
        
        NSURL *fontURL = [NSURL URLWithString:url];
        NSString *fontExtension = fontURL.pathExtension;
        
        NSURL *fontCachePath = [[[getPyoncordDirectory()
                                 URLByAppendingPathComponent:@"downloads" isDirectory:YES]
                                URLByAppendingPathComponent:@"fonts" isDirectory:YES]
                               URLByAppendingPathComponent:fontDefName isDirectory:YES];
        
        fontCachePath = [fontCachePath URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", fontName, fontExtension]];
        
        NSURL *parentDir = [fontCachePath URLByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:parentDir.path]) {
            BunnyLog(@"Creating parent directory: %@", parentDir.path);
            [[NSFileManager defaultManager] createDirectoryAtURL:parentDir
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:nil];
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:fontCachePath.path]) {
            BunnyLog(@"Downloading font %@ from %@", fontName, url);
            NSData *data = [NSData dataWithContentsOfURL:fontURL];
            if (data) {
                BunnyLog(@"Writing font data to: %@", fontCachePath.path);
                [data writeToURL:fontCachePath atomically:YES];
            }
        }
        
        NSData *fontData = [NSData dataWithContentsOfURL:fontCachePath];
        if (fontData) {
            BunnyLog(@"Registering font %@ with provider", fontName);
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)fontData);
            CGFontRef font = CGFontCreateWithDataProvider(provider);
            
            if (font) {
                CFStringRef postScriptName = CGFontCopyPostScriptName(font);
                
                CFErrorRef error = NULL;
                if (CTFontManagerRegisterGraphicsFont(font, &error)) {
                    fontMap[fontName] = (__bridge NSString *)postScriptName;
                    BunnyLog(@"Successfully registered font %@ to %@", fontName, (__bridge NSString *)postScriptName);
                } else {
                    NSString *errorDesc = error ? (__bridge NSString *)CFErrorCopyDescription(error) : @"Unknown error";
                    BunnyLog(@"Failed to register font %@: %@", fontName, errorDesc);
                    if (error) {
                        CFRelease(error);
                    }
                }
                
                CFRelease(postScriptName);
                CFRelease(font);
            }
            CGDataProviderRelease(provider);
        }
    }
} 