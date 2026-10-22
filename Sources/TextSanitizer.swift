//
//  TextSanitizer.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 22.10.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import Foundation

/// Turns raw input into the characters a mask is allowed to store.
struct TextSanitizer {
    struct DecimalDigits {
        func isDigit(_ character: Character) -> Bool {
            guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
                return false
            }
            return CharacterSet.decimalDigits.contains(scalar)
        }
        
        /// Keeps digits. Spaces and date separators (`/`, `-`, `.`) are dropped, so `12/25` and `03-28` paste.
        /// Any other character rejects the whole string.
        func sanitize(_ string: String) -> String? {
            var result = ""
            for character in string {
                if character.isWhitespace || isSeparator(character) {
                    continue
                }
                guard isDigit(character) else { return nil }
                result.append(character)
            }
            return result
        }
        
        private func isSeparator(_ character: Character) -> Bool {
            character == "/" || character == "-" || character == "."
        }
    }
    
    struct NonWhitespace {
        func isContent(_ character: Character) -> Bool {
            !character.isWhitespace
        }
        
        func sanitize(_ string: String) -> String? {
            String(string.filter(isContent))
        }
    }
    
    struct Amount {
        var allowsDecimal: Bool
        var decimalSeparator: String
        var maxFractionDigits: Int
        var currencyMark: String
        
        private let digits = DecimalDigits()
        
        func sanitize(_ string: String) -> String? {
            var working = string
            if !currencyMark.isEmpty {
                working = working.replacingOccurrences(of: currencyMark, with: "")
            }
            
            var filtered = ""
            for character in working {
                if character.isWhitespace { continue }
                if digits.isDigit(character) || character == "," || character == "." {
                    filtered.append(character)
                    continue
                }
                return nil
            }
            return normalized(filtered)
        }
        
        /// Keeps the pasted number.
        /// A repeated mark is grouping (`1.234.567`).
        /// When both marks appear, the last one is decimal (`1,234.56`, `1.234,56`).
        /// A single foreign mark with three digits after it is a thousands group, so `2.500` stays 2500.
        private func normalized(_ string: String) -> String? {
            let separatorIndexes = string.indices.filter { string[$0] == "," || string[$0] == "." }
            guard let firstSeparator = separatorIndexes.first else { return string }
            
            let decimalIndex = decimalIndex(in: string, separatorIndexes: separatorIndexes, firstSeparator: firstSeparator)
            guard decimalIndex != .reject else { return nil }
            
            var integer = ""
            var fraction: String?
            for index in string.indices {
                let character = string[index]
                if digits.isDigit(character) {
                    if fraction == nil {
                        integer.append(character)
                    } else {
                        fraction?.append(character)
                    }
                    continue
                }
                if case .position(let decimal) = decimalIndex, index == decimal {
                    fraction = ""
                }
            }
            
            guard let fraction else { return integer }
            guard allowsDecimal else { return nil }
            return integer + decimalSeparator + fraction
        }
        
        private enum DecimalIndex: Equatable {
            case position(String.Index)
            case grouping
            case reject
        }
        
        private func decimalIndex(in string: String, separatorIndexes: [String.Index], firstSeparator: String.Index) -> DecimalIndex {
            let hasComma = string.contains(",")
            let hasDot = string.contains(".")
            
            if hasComma && hasDot {
                guard allowsDecimal, let last = separatorIndexes.last else { return .reject }
                return .position(last)
            }
            if separatorIndexes.count > 1 {
                return .grouping
            }
            
            let separator = string[firstSeparator]
            let tailCount = string[string.index(after: firstSeparator)...].filter(digits.isDigit).count
            switch separatorRole(separator, tailCount: tailCount) {
            case .decimal:
                return .position(firstSeparator)
            case .grouping:
                return .grouping
            case .reject:
                return .reject
            }
        }
        
        private enum SeparatorRole {
            case decimal
            case grouping
            case reject
        }
        
        /// `.decimal` keeps the mark, `.grouping` drops it, `.reject` cancels the paste.
        private func separatorRole(_ separator: Character, tailCount: Int) -> SeparatorRole {
            let matchesFieldSeparator = decimalSeparatorCharacter == separator
            if !allowsDecimal {
                return tailCount == 3 ? .grouping : .reject
            }
            if tailCount == 0 { return .decimal }
            if !matchesFieldSeparator, tailCount == 3 { return .grouping }
            if tailCount > maxFractionDigits { return .reject }
            return .decimal
        }
        
        private var decimalSeparatorCharacter: Character? {
            guard decimalSeparator.count == 1 else { return nil }
            return decimalSeparator.first
        }
    }
}
