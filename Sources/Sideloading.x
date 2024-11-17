#import "Logger.h"
#import "Utils.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

typedef struct __CMSDecoder *CMSDecoderRef;
extern CFTypeRef SecCMSDecodeGetContent(CFDataRef message);
extern OSStatus CMSDecoderCreate(CMSDecoderRef *cmsDecoder);
extern OSStatus CMSDecoderUpdateMessage(CMSDecoderRef cmsDecoder, const void *content,
                                        size_t contentLength);
extern OSStatus CMSDecoderFinalizeMessage(CMSDecoderRef cmsDecoder);
extern OSStatus CMSDecoderCopyContent(CMSDecoderRef cmsDecoder, CFDataRef *content);

#define DISCORD_BUNDLE_ID @"com.hammerandchisel.discord"
#define DISCORD_NAME @"Discord"

typedef NS_ENUM(NSInteger, BundleIDError) {
    BundleIDErrorFiles,
    BundleIDErrorIcon
};

static void showBundleIDError(BundleIDError error) {
    NSString *message = @"For this to work change the Bundle ID so that it matches your "
                        @"provisioning profile's App ID (excluding the Team ID prefix).";
    NSString *title = error == BundleIDErrorFiles ? @"Cannot Access Files" : @"Cannot Change Icon";
    showErrorAlert(title, message);
}

static NSString *getProvisioningAppID(void) {
    NSString *provisionPath = [NSBundle.mainBundle pathForResource:@"embedded"
                                                            ofType:@"mobileprovision"];
    if (!provisionPath)
        return nil;
    NSData *provisionData = [NSData dataWithContentsOfFile:provisionPath];
    if (!provisionData)
        return nil;
    CMSDecoderRef decoder = NULL;
    CMSDecoderCreate(&decoder);
    CMSDecoderUpdateMessage(decoder, provisionData.bytes, provisionData.length);
    CMSDecoderFinalizeMessage(decoder);
    CFDataRef dataRef = NULL;
    CMSDecoderCopyContent(decoder, &dataRef);
    NSData *data = (__bridge_transfer NSData *)dataRef;
    if (decoder)
        CFRelease(decoder);
    NSError *error = nil;
    id plist       = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:NULL
                                                           error:&error];
    if (!plist || ![plist isKindOfClass:[NSDictionary class]])
        return nil;
    NSString *appID = plist[@"Entitlements"][@"application-identifier"];
    if (!appID)
        return nil;
    NSArray *components = [appID componentsSeparatedByString:@"."];
    if (components.count > 1) {
        return [[components subarrayWithRange:NSMakeRange(1, components.count - 1)]
            componentsJoinedByString:@"."];
    }
    return nil;
}

static NSString *getAccessGroupID(void) {
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass : (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrAccount : @"bundleSeedID",
        (__bridge NSString *)kSecAttrService : @"",
        (__bridge NSString *)kSecReturnAttributes : @YES
    };

    CFDictionaryRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);

    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }

    if (status != errSecSuccess)
        return nil;

    NSString *accessGroup =
        [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
    if (result)
        CFRelease(result);

    return accessGroup;
}

static BOOL isSelfCall(void) {
    NSArray *address = [NSThread callStackReturnAddresses];
    Dl_info info     = {0};
    if (dladdr((void *)[address[2] longLongValue], &info) == 0)
        return NO;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    return [path hasPrefix:NSBundle.mainBundle.bundlePath];
}

%group Sideloading

%hook NSBundle
- (NSString *)bundleIdentifier {
    return isSelfCall() ? DISCORD_BUNDLE_ID : %orig;
}

- (NSDictionary *)infoDictionary {
    if (!isSelfCall())
        return %orig;

    NSMutableDictionary *info    = [%orig mutableCopy];
    info[@"CFBundleIdentifier"]  = DISCORD_BUNDLE_ID;
    info[@"CFBundleDisplayName"] = DISCORD_NAME;
    info[@"CFBundleName"]        = DISCORD_NAME;
    return info;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (!isSelfCall())
        return %orig;

    if ([key isEqualToString:@"CFBundleIdentifier"])
        return DISCORD_BUNDLE_ID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"])
        return DISCORD_NAME;
    return %orig;
}
%end

%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    BunnyLog(@"containerURLForSecurityApplicationGroupIdentifier called! %@",
             groupIdentifier ?: @"nil");

    NSArray *paths  = [self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *lastPath = [paths lastObject];
    return [lastPath URLByAppendingPathComponent:@"AppGroup"];
}
%end

%hook UIPasteboard
- (NSString *)_accessGroup {
    return getAccessGroupID();
}
%end

%hook UIApplication
- (void)setAlternateIconName:(NSString *)iconName
           completionHandler:(void (^)(NSError *))completion {
    void (^wrappedCompletion)(NSError *) = ^(NSError *error) {
        if (error) {
            showErrorAlert(@"Cannot Change Icon",
                           @"For this to work change the Bundle ID so that it "
                           @"matches your provisioning profile's App ID "
                           @"(excluding the Team ID prefix).");
        }

        if (completion) {
            completion(error);
        }
    };

    %orig(iconName, wrappedCompletion);
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[UIDocumentPickerViewController class]]) {
        NSString *provisioningAppID = getProvisioningAppID();
        NSString *currentBundleID   = [[NSBundle mainBundle] bundleIdentifier];

        if (provisioningAppID && ![provisioningAppID isEqualToString:currentBundleID]) {
            BunnyLog(
                @"Intercepted UIDocumentPickerViewController presentation - bundle ID mismatch");
            showBundleIDError(BundleIDErrorFiles);
            return;
        }
    }
    %orig;
}
%end

%end

%ctor {
    BOOL isAppStoreApp = [[NSFileManager defaultManager]
        fileExistsAtPath:[[NSBundle mainBundle] appStoreReceiptURL].path];
    if (!isAppStoreApp) {
        %init(Sideloading);
    }
}
