//
//  UTF16Text.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 22.10.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import Foundation

/// A string addressed the way `UITextField` addresses it: ranges and caret offsets are UTF-16.
struct UTF16Text {
    struct Span {
        let character: Character
        let range: NSRange
        
        var end: Int {
            NSMaxRange(range)
        }
    }
    
    let value: String
    
    private var storage: NSString {
        value as NSString
    }
    
    init(_ value: String) {
        self.value = value
    }
    
    var length: Int {
        storage.length
    }
    
    func substring(with range: NSRange) -> String {
        guard range.location >= 0, NSMaxRange(range) <= length else { return "" }
        return storage.substring(with: range)
    }
    
    func suffix(from location: Int) -> String {
        guard location < length else { return "" }
        guard location > 0 else { return value }
        return storage.substring(from: location)
    }
    
    func replacingCharacters(in range: NSRange, with replacement: String) -> String {
        storage.replacingCharacters(in: range, with: replacement)
    }
    
    func characterSpans() -> [Span] {
        var spans: [Span] = []
        spans.reserveCapacity(value.count)
        
        var location = 0
        for character in value {
            let characterLength = (String(character) as NSString).length
            let range = NSRange(location: location, length: characterLength)
            spans.append(Span(character: character, range: range))
            location += characterLength
        }
        return spans
    }
    
    /// Caret offset that keeps `count` content characters after it.
    /// Mask characters between the edited prefix and that suffix stay behind the caret.
    func offset(beforeTrailingContent count: Int, isContent: (Character) -> Bool) -> Int {
        guard count > 0 else { return length }
        
        var remaining = count
        var utf16Offset = length
        for character in value.reversed() {
            utf16Offset -= (String(character) as NSString).length
            guard isContent(character) else { continue }
            
            remaining -= 1
            if remaining == 0 {
                return utf16Offset
            }
        }
        return 0
    }
    
    /// A deletion that contains only mask characters also removes the neighboring value character.
    /// Otherwise the mask is deleted and immediately inserted again by formatting.
    func deletionRange(expanding range: NSRange, isContent: (Character) -> Bool, forward: Bool) -> NSRange {
        guard range.length > 0, NSMaxRange(range) <= length else { return range }
        
        let deleted = substring(with: range)
        guard !deleted.contains(where: isContent) else { return range }
        
        let spans = characterSpans()
        if forward {
            guard let contentSpan = spans.first(where: { $0.range.location >= range.location && isContent($0.character) }) else {
                return range
            }
            return NSRange(location: range.location, length: contentSpan.end - range.location)
        }
        
        guard let contentSpan = spans.last(where: { $0.end <= NSMaxRange(range) && isContent($0.character) }) else {
            return range
        }
        return NSRange(location: contentSpan.range.location, length: NSMaxRange(range) - contentSpan.range.location)
    }
}
