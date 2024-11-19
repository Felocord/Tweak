#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NSURL *getFelitendoDirectory(void);
UIColor *hexToUIColor(NSString *hex);
void showErrorAlert(NSString *title, NSString *message, void (^completion)(void));