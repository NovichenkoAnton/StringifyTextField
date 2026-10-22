//
//  MaskedEdit.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 22.10.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import Foundation

/// Inserts or deletes at a UTF-16 range, then formats the value and reports where the caret belongs.
struct MaskedEdit {
    /// What to do with a new value that is not a single key.
    enum Replacing {
        /// Edit at the caret. Leave the text unchanged when the result does not fit.
        case atCaret
        /// Replace the field only when the new value length is the mask limit and it does not fit at the caret.
        case fullValue
        /// More than one character replaces the field. One character is edited at the caret.
        case pastedValue
        /// A whole IBAN replaces the field. A short fragment does not.
        /// `wholeNumberLength` is the shortest length that still looks like a complete IBAN.
        case iban(wholeNumberLength: Int)
    }
    
    var isContent: (Character) -> Bool
    var sanitize: (String) -> String?
    var format: (String) -> String?
    var filledCount: Int?
    var replacing: Replacing = .atCaret
    
    struct Outcome {
        let text: String
        let caretOffset: Int
        let isFilled: Bool
    }
    
    func outcome(in text: String, range: NSRange, replacement: String, isForwardDelete: Bool) -> Outcome? {
        if replacement.isEmpty {
            return deleted(in: text, range: range, isForwardDelete: isForwardDelete)
        }
        
        guard let inserted = sanitize(replacement), !inserted.isEmpty else { return nil }
        
        if case .pastedValue = replacing, inserted.count > 1 {
            return replacedField(inserted, replacement: replacement)
        }
        
        if case .iban(let wholeNumberLength) = replacing,
           inserted.count > 1,
           replacesIBAN(inserted, in: text, range: range, wholeNumberLength: wholeNumberLength) {
            return replacedField(inserted, replacement: replacement)
        }
        
        if let edited = editedAtCaret(in: text, range: range, inserted: inserted, replacement: replacement) {
            return edited
        }
        
        guard case .fullValue = replacing, inserted.count == filledCount else { return nil }
        return replacedField(inserted, replacement: replacement)
    }
    
    /// The value fits in the mask and is either at least as long as the current text,
    /// or it no longer fits at the caret and is long enough to be a complete IBAN.
    private func replacesIBAN(_ inserted: String, in text: String, range: NSRange, wholeNumberLength: Int) -> Bool {
        guard let filledCount, inserted.count <= filledCount else { return false }
        
        let currentCount = text.filter(isContent).count
        if inserted.count >= currentCount { return true }
        
        let fitsAtCaret = editedAtCaret(in: text, range: range, inserted: inserted, replacement: inserted) != nil
        return !fitsAtCaret && inserted.count >= wholeNumberLength
    }
    
    private func deleted(in text: String, range: NSRange, isForwardDelete: Bool) -> Outcome? {
        let source = UTF16Text(text)
        let deletionRange = source.deletionRange(expanding: range, isContent: isContent, forward: isForwardDelete)
        return editedAtCaret(in: text, range: deletionRange, inserted: "", replacement: "")
    }
    
    private func editedAtCaret(in text: String, range: NSRange, inserted: String, replacement: String) -> Outcome? {
        let source = UTF16Text(text)
        guard NSMaxRange(range) <= source.length else { return nil }
        
        let edited = source.replacingCharacters(in: range, with: inserted)
        let content = String(edited.filter(isContent))
        guard let formatted = format(content) else { return nil }
        
        let suffix = source.suffix(from: NSMaxRange(range))
        let caretOffset = UTF16Text(formatted).offset(
            beforeTrailingContent: suffix.filter(isContent).count,
            isContent: isContent
        )
        return Outcome(
            text: formatted,
            caretOffset: caretOffset,
            isFilled: didFill(contentCount: content.count, replacement: replacement)
        )
    }
    
    private func replacedField(_ inserted: String, replacement: String) -> Outcome? {
        guard let formatted = format(inserted) else { return nil }
        
        return Outcome(
            text: formatted,
            caretOffset: UTF16Text(formatted).length,
            isFilled: didFill(contentCount: inserted.count, replacement: replacement)
        )
    }
    
    private func didFill(contentCount: Int, replacement: String) -> Bool {
        guard let filledCount, !replacement.isEmpty else { return false }
        return contentCount == filledCount
    }
}
