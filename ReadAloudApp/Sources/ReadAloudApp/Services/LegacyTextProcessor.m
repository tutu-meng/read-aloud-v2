//
//  LegacyTextProcessor.m
//  ReadAloudApp
//
//  Implementation of the demonstration Objective-C class.
//  This shows how legacy algorithms or C/C++ code can be integrated.
//

#import "LegacyTextProcessor.h"
#include <string.h> // C standard library example

@implementation LegacyTextProcessor

- (NSString *)processText:(NSString *)text {
    if (!text || text.length == 0) {
        return @"[Empty Text]";
    }
    
    // Demonstration: Using C string functions (could be C++ in real implementation)
    const char *cString = [text UTF8String];
    size_t length = strlen(cString);
    
    // Example processing: append character count
    NSString *processedText = [NSString stringWithFormat:@"%@ [Processed: %zu characters]", 
                               text, length];
    
    return processedText;
}

- (NSUInteger)calculateHash:(NSString *)text {
    if (!text) return 0;
    
    // Simple demonstration hash using C-style approach
    const char *str = [text UTF8String];
    NSUInteger hash = 5381;
    int c;
    
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c; // hash * 33 + c
    }
    
    return hash;
}

@end 