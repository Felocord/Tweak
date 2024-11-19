#import "Fonts.h"
#import "Logger.h"
#import "Utils.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

NSMutableDictionary<NSString *, NSString *> *fontMap;

%hook UIFont

+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)size {
    NSString *replacementName = fontMap[name];
    if (replacementName) {
        UIFontDescriptor *replacementDescriptor =
            [UIFontDescriptor fontDescriptorWithName:replacementName size:size];
        UIFontDescriptor *fallbackDescriptor =
            [replacementDescriptor fontDescriptorByAddingAttributes:@{
                UIFontDescriptorNameAttribute : @[ name ]
            }];
        UIFontDescriptor *finalDescriptor =
            [replacementDescriptor fontDescriptorByAddingAttributes:@{
                UIFontDescriptorCascadeListAttribute : @[ fallbackDescriptor ]
            }];

        return [UIFont fontWithDescriptor:finalDescriptor size:size];
    }
    return %orig;
}

+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)size {
    NSString *replacementName = fontMap[descriptor.postscriptName];
    if (replacementName) {
        UIFontDescriptor *replacementDescriptor =
            [UIFontDescriptor fontDescriptorWithName:replacementName size:size];
        UIFontDescriptor *finalDescriptor =
            [replacementDescriptor fontDescriptorByAddingAttributes:@{
                UIFontDescriptorCascadeListAttribute : @[ descriptor ]
            }];

        return [UIFont fontWithDescriptor:finalDescriptor size:size];
    }
    return %orig;
}

+ (UIFont *)systemFontOfSize:(CGFloat)size {
    NSString *replacementName = fontMap[@"systemFont"];
    if (replacementName) {
        return [UIFont fontWithName:replacementName size:size];
    }
    return %orig;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
    NSString *replacementName = fontMap[@"systemFont"];
    if (replacementName) {
        return [UIFont fontWithName:replacementName size:[UIFont systemFontSize]];
    }
    return %orig;
}

%end

void patchFonts(NSDictionary<NSString *, NSString *> *mainFonts, NSString *fontDefName) {
    FelocordLog(@"patchFonts called with fonts: %@ and def name: %@", mainFonts, fontDefName);

    if (!fontMap) {
        FelocordLog(@"Creating new fontMap");
        fontMap = [NSMutableDictionary dictionary];
    }

    NSString *fontJson = [NSString
        stringWithContentsOfURL:[getFelitendoDirectory() URLByAppendingPathComponent:@"fonts.json"]
                       encoding:NSUTF8StringEncoding
                          error:nil];
    if (fontJson) {
        FelocordLog(@"Found existing fonts.json: %@", fontJson);
    }

    for (NSString *fontName in mainFonts) {
        NSString *url = mainFonts[fontName];
        FelocordLog(@"Replacing font %@ with URL: %@", fontName, url);

        NSURL *fontURL          = [NSURL URLWithString:url];
        NSString *fontExtension = fontURL.pathExtension;

        NSURL *fontCachePath = [[[getFelitendoDirectory() URLByAppendingPathComponent:@"downloads"
                                                                         isDirectory:YES]
            URLByAppendingPathComponent:@"fonts"
                            isDirectory:YES] URLByAppendingPathComponent:fontDefName
                                                             isDirectory:YES];

        fontCachePath = [fontCachePath
            URLByAppendingPathComponent:[NSString
                                            stringWithFormat:@"%@.%@", fontName, fontExtension]];

        NSURL *parentDir = [fontCachePath URLByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:parentDir.path]) {
            FelocordLog(@"Creating parent directory: %@", parentDir.path);
            [[NSFileManager defaultManager] createDirectoryAtURL:parentDir
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:nil];
        }

        if (![[NSFileManager defaultManager] fileExistsAtPath:fontCachePath.path]) {
            FelocordLog(@"Downloading font %@ from %@", fontName, url);
            NSData *data = [NSData dataWithContentsOfURL:fontURL];
            if (data) {
                FelocordLog(@"Writing font data to: %@", fontCachePath.path);
                [data writeToURL:fontCachePath atomically:YES];
            }
        }

        NSData *fontData = [NSData dataWithContentsOfURL:fontCachePath];
        if (fontData) {
            FelocordLog(@"Registering font %@ with provider", fontName);
            CGDataProviderRef provider =
                CGDataProviderCreateWithCFData((__bridge CFDataRef)fontData);
            CGFontRef font = CGFontCreateWithDataProvider(provider);

            if (font) {
                CFStringRef postScriptName = CGFontCopyPostScriptName(font);

                CTFontRef existingFont = CTFontCreateWithName(postScriptName, 0, NULL);
                if (existingFont) {
                    CFErrorRef unregisterError = NULL;
                    if (!CTFontManagerUnregisterGraphicsFont(font, &unregisterError)) {
                        FelocordLog(@"Failed to deregister font %@: %@",
                                 (__bridge NSString *)postScriptName,
                                 unregisterError
                                     ? (__bridge NSString *)CFErrorCopyDescription(unregisterError)
                                     : @"Unknown error");
                        if (unregisterError)
                            CFRelease(unregisterError);
                    }
                    CFRelease(existingFont);
                }

                CFErrorRef error = NULL;
                if (CTFontManagerRegisterGraphicsFont(font, &error)) {
                    fontMap[fontName] = (__bridge NSString *)postScriptName;
                    FelocordLog(@"Successfully registered font %@ to %@", fontName,
                             (__bridge NSString *)postScriptName);

                    NSError *jsonError;
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fontMap
                                                                       options:0
                                                                         error:&jsonError];
                    if (!jsonError) {
                        [jsonData writeToURL:[getFelitendoDirectory()
                                                 URLByAppendingPathComponent:@"fontMap.json"]
                                  atomically:YES];
                    }
                } else {
                    NSString *errorDesc = error ? (__bridge NSString *)CFErrorCopyDescription(error)
                                                : @"Unknown error";
                    FelocordLog(@"Failed to register font %@: %@", fontName, errorDesc);
                    if (error)
                        CFRelease(error);
                }

                CFRelease(postScriptName);
                CFRelease(font);
            }
            CGDataProviderRelease(provider);
        }
    }
}

%ctor {
    @autoreleasepool {
        fontMap = [NSMutableDictionary dictionary];
        FelocordLog(@"Font hooks initialized");
        %init;
    }
}
