#if 0
#import <Foundation/Foundation.h>

/* PSTRegularExpression is a class used to represent and apply regular expressions.  An instance of this class is an immutable representation of a compiled regular expression pattern and various option flags.
 */

typedef NS_OPTIONS(NSUInteger, PSTRegularExpressionOptions) {
	PSTRegularExpressionCaseInsensitive             = 1 << 0,     /* Match letters in the pattern independent of case. */
	PSTRegularExpressionAllowCommentsAndWhitespace  = 1 << 1,     /* Ignore whitespace and #-prefixed comments in the pattern. */
	PSTRegularExpressionIgnoreMetacharacters        = 1 << 2,     /* Treat the entire pattern as a literal string. */
	PSTRegularExpressionDotMatchesLineSeparators    = 1 << 3,     /* Allow . to match any character, including line separators. */
	PSTRegularExpressionAnchorsMatchLines           = 1 << 4,     /* Allow ^ and $ to match the start and end of lines. */
	PSTRegularExpressionUseUnixLineSeparators       = 1 << 5,     /* Treat only \n as a line separator (otherwise, all standard line separators are used). */
	PSTRegularExpressionUseUnicodeWordBoundaries    = 1 << 6      /* Use Unicode TR#29 to specify word boundaries (otherwise, traditional regular expression word boundaries are used). */
};

@interface PSTRegularExpression : NSObject <NSCopying, NSCoding> {
@protected   // all instance variables are private
	NSString *_pattern;
	NSUInteger _options;
	void *_internal;
	id _reserved1;
	int32_t _checkout;
	int32_t _reserved2;
}

/* An instance of PSTRegularExpression is created from a regular expression pattern and a set of options.  If the pattern is invalid, nil will be returned and an NSError will be returned by reference.  The pattern syntax currently supported is that specified by ICU.
 */
+ (PSTRegularExpression *)regularExpressionWithPattern:(NSString *)pattern options:(PSTRegularExpressionOptions)options error:(NSError **)error;
- (id)initWithPattern:(NSString *)pattern options:(PSTRegularExpressionOptions)options error:(NSError **)error;

@property (readonly) NSString *pattern;
@property (readonly) PSTRegularExpressionOptions options;
@property (readonly) NSUInteger numberOfCaptureGroups;

/* This class method will produce a string by adding backslash escapes as necessary to the given string, to escape any characters that would otherwise be treated as pattern metacharacters.
 */
+ (NSString *)escapedPatternForString:(NSString *)string;

@end


typedef NS_OPTIONS(NSUInteger, PSTMatchingOptions) {
	PSTMatchingReportProgress         = 1 << 0,       /* Call the block periodically during long-running match operations. */
	PSTMatchingReportCompletion       = 1 << 1,       /* Call the block once after the completion of any matching. */
	PSTMatchingAnchored               = 1 << 2,       /* Limit matches to those at the start of the search range. */
	PSTMatchingWithTransparentBounds  = 1 << 3,       /* Allow matching to look beyond the bounds of the search range. */
	PSTMatchingWithoutAnchoringBounds = 1 << 4        /* Prevent ^ and $ from automatically matching the beginning and end of the search range. */
};

typedef NS_OPTIONS(NSUInteger, PSTMatchingFlags) {
	PSTMatchingProgress               = 1 << 0,       /* Set when the block is called to report progress during a long-running match operation. */
	PSTMatchingCompleted              = 1 << 1,       /* Set when the block is called after completion of any matching. */
	PSTMatchingHitEnd                 = 1 << 2,       /* Set when the current match operation reached the end of the search range. */
	PSTMatchingRequiredEnd            = 1 << 3,       /* Set when the current match depended on the location of the end of the search range. */
	PSTMatchingInternalError          = 1 << 4        /* Set when matching failed due to an internal error. */
};

@interface PSTRegularExpression (PSTMatching)

/* The fundamental matching method on PSTRegularExpression is a block iterator.  There are several additional convenience methods, for returning all matches at once, the number of matches, the first match, or the range of the first match.  Each match is specified by an instance of NSTextCheckingResult (of type NSTextCheckingTypeRegularExpression) in which the overall match range is given by the range property (equivalent to rangeAtIndex:0) and any capture group ranges are given by rangeAtIndex: for indexes from 1 to numberOfCaptureGroups.  {NSNotFound, 0} is used if a particular capture group does not participate in the match.
 */

#if NS_BLOCKS_AVAILABLE
- (void)enumerateMatchesInString:(NSString *)string options:(PSTMatchingOptions)options range:(NSRange)range usingBlock:(void (^)(NSTextCheckingResult *result, PSTMatchingFlags flags, BOOL *stop))block;
#endif /* NS_BLOCKS_AVAILABLE */

- (NSArray *)matchesInString:(NSString *)string options:(PSTMatchingOptions)options range:(NSRange)range;
- (NSUInteger)numberOfMatchesInString:(NSString *)string options:(PSTMatchingOptions)options range:(NSRange)range;
- (NSTextCheckingResult *)firstMatchInString:(NSString *)string options:(PSTMatchingOptions)options range:(NSRange)range;
- (NSRange)rangeOfFirstMatchInString:(NSString *)string options:(PSTMatchingOptions)options range:(NSRange)range;

@end


@interface PSTRegularExpression (NSReplacement)

/* PSTRegularExpression also provides find-and-replace methods for both immutable and mutable strings.  The replacement is treated as a template, with $0 being replaced by the contents of the matched range, $1 by the contents of the first capture group, and so on.  Additional digits beyond the maximum required to represent the number of capture groups will be treated as ordinary characters, as will a $ not followed by digits.  Backslash will escape both $ and itself.
 */
- (NSString *)stringByReplacingMatchesInString:(NSString *)string options:(PSTMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ;
- (NSUInteger)replaceMatchesInString:(NSMutableString *)string options:(PSTMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ;

/* For clients implementing their own replace functionality, this is a method to perform the template substitution for a single result, given the string from which the result was matched, an offset to be added to the location of the result in the string (for example, in case modifications to the string moved the result since it was matched), and a replacement template.
 */
- (NSString *)replacementStringForResult:(NSTextCheckingResult *)result inString:(NSString *)string offset:(NSInteger)offset template:(NSString *)templ;

/* This class method will produce a string by adding backslash escapes as necessary to the given string, to escape any characters that would otherwise be treated as template metacharacters. 
 */
+ (NSString *)escapedTemplateForString:(NSString *)string;

@end
#endif

