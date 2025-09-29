//
//  BorderedStringifyTextField.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 19.12.23.
//  Copyright © 2023 Anton Novichenko. All rights reserved.
//

import UIKit

open class BorderedStringifyTextField: StringifyTextField {
    // MARK: - Public properies
    
    public var cornerRadius: CGFloat = .zero {
        didSet {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
        }
    }
    
    public var borderWidth: CGFloat = .zero {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    
    public var borderColor: UIColor? = UIColor.clear {
        didSet {
            layer.borderColor = borderColor?.cgColor
        }
    }
    
    public var activeBorderColor: UIColor? = UIColor.clear
    public var errorBorderColor: UIColor? = UIColor.red
    
    public var textPadding: CGFloat = 14

    // MARK: - Private properties

    private var padding: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: textPadding, bottom: 0, right: textPadding)
    }

    private let borderColorAnimation = CABasicAnimation(keyPath: "borderColor")

    // MARK: - Inits

    public init(type inputType: StringifyTextField.TextType) {
        super.init(type: inputType, style: .native(borderStyle: .none))
        
        setup()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setup()
    }
    
    private func setup() {
        floatingPlaceholder = false
        
        layer.borderColor = borderColor?.cgColor
        layer.borderWidth = borderWidth
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = cornerRadius > 0
    }

    // MARK: - Overridden functions

    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return rect.inset(by: padding)
    }

    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.placeholderRect(forBounds: bounds)
        return rect.inset(by: padding)
    }

    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return rect.inset(by: padding)
    }

    // MARK: - Overridden UITextFieldDelegate functions

    override open func textFieldDidBeginEditing(_ textField: UITextField) {
        animateShowBorder()
        super.textFieldDidBeginEditing(textField)
    }

    override open func textFieldDidEndEditing(_ textField: UITextField) {
        animateHideBorder()
        super.textFieldDidEndEditing(textField)
    }

    // MARK: - Public API

    public func highlightError() {
        borderColorAnimation.fromValue = layer.borderColor
        borderColorAnimation.toValue = errorBorderColor?.cgColor
        borderColorAnimation.duration = 0.2

        layer.removeAllAnimations()
        layer.add(borderColorAnimation, forKey: nil)

        layer.borderColor = errorBorderColor?.cgColor
    }

    public func hideError() {
        animateHideBorder()
    }
}

// MARK: - Private API

private extension BorderedStringifyTextField {
    func animateShowBorder() {
        borderColorAnimation.fromValue = layer.borderColor
        borderColorAnimation.toValue = activeBorderColor?.cgColor
        borderColorAnimation.duration = 0.2

        layer.removeAllAnimations()
        layer.add(borderColorAnimation, forKey: nil)

        layer.borderColor = activeBorderColor?.cgColor
    }

    func animateHideBorder() {
        borderColorAnimation.fromValue = layer.borderColor
        borderColorAnimation.toValue = UIColor.clear.cgColor
        borderColorAnimation.duration = 0.2

        layer.removeAllAnimations()
        layer.add(borderColorAnimation, forKey: nil)

        layer.borderColor = UIColor.clear.cgColor
    }
}
