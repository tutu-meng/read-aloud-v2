//
//  LegacyTextProcessor.h
//  ReadAloudApp
//
//  This is a demonstration Objective-C class to verify Swift/Objective-C interoperability.
//  In a real implementation, this could be replaced with performance-critical C++ code
//  wrapped in Objective-C++ or legacy Objective-C libraries.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A demonstration Objective-C class for text processing
/// This shows how legacy Objective-C code or C++ wrapped in Objective-C can be integrated
@interface LegacyTextProcessor : NSObject

/// Process text using legacy algorithm (demonstration)
/// @param text The input text to process
/// @return Processed text with character count appended
- (NSString *)processText:(NSString *)text;

/// Calculate a hash for the given text (demonstration of C-style function integration)
/// @param text The input text
/// @return A simple hash value
- (NSUInteger)calculateHash:(NSString *)text;

@end

NS_ASSUME_NONNULL_END 