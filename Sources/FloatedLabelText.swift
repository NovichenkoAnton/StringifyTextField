//
//  FloatedLabelText.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 02.10.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import UIKit

func containsFontAttribute(_ string: NSAttributedString) -> Bool {
    guard string.length > 0 else { return false }

    var found = false
    string.enumerateAttribute(.font, in: NSRange(location: 0, length: string.length)) { value, _, stop in
        guard value is UIFont else { return }
        found = true
        stop.pointee = true
    }
    return found
}

/// Keeps the PostScript name of a custom font. `UIFont.withSize` can resolve that
/// descriptor back to the system font.
func fontMatching(_ font: UIFont, pointSize: CGFloat) -> UIFont {
    guard abs(font.pointSize - pointSize) > 0.01 else { return font }
    if let namedFont = UIFont(name: font.fontName, size: pointSize) {
        return namedFont
    }
    return font.withSize(pointSize)
}

func attributedStringForFloatedLabel(_ source: NSAttributedString, fitting pointSize: CGFloat?, fallbackFont: UIFont, color: UIColor) -> NSAttributedString {
    let styled = NSMutableAttributedString(attributedString: source)
    let fullRange = NSRange(location: 0, length: styled.length)
    guard fullRange.length > 0 else { return styled }

    var largestPointSize: CGFloat = 0
    if pointSize != nil {
        styled.enumerateAttribute(.font, in: fullRange) { value, _, _ in
            if let font = value as? UIFont {
                largestPointSize = max(largestPointSize, font.pointSize)
            }
        }
    }

    let scale: CGFloat
    if let pointSize, largestPointSize > 0 {
        scale = pointSize / largestPointSize
    } else {
        scale = 1
    }

    var fontUpdates: [(NSRange, UIFont)] = []
    styled.enumerateAttribute(.font, in: fullRange) { value, range, _ in
        let font: UIFont
        if let existing = value as? UIFont {
            if abs(scale - 1) < 0.001 {
                font = existing
            } else {
                font = fontMatching(existing, pointSize: existing.pointSize * scale)
            }
        } else if let pointSize {
            font = fontMatching(fallbackFont, pointSize: pointSize)
        } else {
            font = fallbackFont
        }
        fontUpdates.append((range, font))
    }

    for (range, font) in fontUpdates {
        styled.addAttribute(.font, value: font, range: range)
    }

    styled.addAttribute(.foregroundColor, value: color, range: fullRange)
    return styled
}

func maximumFontLineHeight(in attributedText: NSAttributedString, fallback: UIFont) -> CGFloat {
    guard attributedText.length > 0 else { return fallback.lineHeight }

    var maxLineHeight: CGFloat = 0
    attributedText.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedText.length)) { value, _, _ in
        if let font = value as? UIFont {
            maxLineHeight = max(maxLineHeight, font.lineHeight)
        }
    }

    return maxLineHeight > 0 ? maxLineHeight : fallback.lineHeight
}

/// Field placeholder text. Keeps fonts and colors from `attributedPlaceholder`.
/// Missing fonts and colors use the fallbacks.
func attributedStringForFieldText(_ source: NSAttributedString, fallbackFont: UIFont, fallbackColor: UIColor) -> NSAttributedString {
    let styled = NSMutableAttributedString(attributedString: source)
    let fullRange = NSRange(location: 0, length: styled.length)
    guard fullRange.length > 0 else { return styled }

    var fontUpdates: [(NSRange, UIFont)] = []
    styled.enumerateAttribute(.font, in: fullRange) { value, range, _ in
        if !(value is UIFont) {
            fontUpdates.append((range, fallbackFont))
        }
    }
    for (range, font) in fontUpdates {
        styled.addAttribute(.font, value: font, range: range)
    }

    var colorUpdates: [(NSRange, UIColor)] = []
    styled.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
        if !(value is UIColor) {
            colorUpdates.append((range, fallbackColor))
        }
    }
    for (range, color) in colorUpdates {
        styled.addAttribute(.foregroundColor, value: color, range: range)
    }

    return styled
}

func setFloatedLabelForegroundColor(_ color: UIColor, of label: UILabel) {
    guard let attributedText = label.attributedText, attributedText.length > 0 else {
        label.textColor = color
        return
    }

    let mutable = NSMutableAttributedString(attributedString: attributedText)
    mutable.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutable.length))
    label.attributedText = mutable
}
