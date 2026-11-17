#import "SharedStorage.h"

@implementation SharedStorage

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

RCT_EXPORT_METHOD(set:(NSString *)key
                  value:(NSString *)value
                  group:(NSString *)group
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:group];
  if (defaults == nil) {
    reject(@"ERR", @"Could not open App Group", nil);
    return;
  }
  [defaults setObject:value forKey:key];
  [defaults synchronize];
  
  resolve(@YES);
}

RCT_EXPORT_METHOD(get:(NSString *)key
                  group:(NSString *)group
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:group];
  if (defaults == nil) {
    reject(@"ERR", @"Could not open App Group", nil);
    return;
  }
  NSString *val = [defaults stringForKey:key];
  resolve(val ?: [NSNull null]);
}

@end
