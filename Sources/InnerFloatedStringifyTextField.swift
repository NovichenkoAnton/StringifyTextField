//
//  InnerFloatedStringifyTextField.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 10.09.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import UIKit

/// `StringifyTextField` with a persistent inner floated label at the top of the field bounds.
/// The standard clear button stays vertically centered; value text is clipped to the button
/// and truncated with an ellipsis.
open class InnerFloatedStringifyTextField: StringifyTextField {
    // MARK: - Public properties

    /// Insets between the field bounds and inner content.
    /// Default value is `UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)`.
    public var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16) {
        didSet {
            setNeedsLayout()
        }
    }

    /// Spacing between the inner floated label and the value text.
    /// Default value is `2`.
    public var labelToTextSpacing: CGFloat = 2 {
        didSet {
            setNeedsLayout()
        }
    }

    // MARK: - Private properties

    private let innerFloatedLabel: UILabel = {
        let innerFloatedLabel = UILabel()
        innerFloatedLabel.numberOfLines = 1
        innerFloatedLabel.lineBreakMode = .byTruncatingTail
        innerFloatedLabel.isUserInteractionEnabled = false
        return innerFloatedLabel
    }()
    
    private var isClearButtonDisplayed: Bool {
        guard hasText else { return false }

        switch clearButtonMode {
        case .always:
            return true
        case .whileEditing:
            return isEditing || isFirstResponder
        case .unlessEditing:
            return !isEditing
        default:
            return false
        }
    }
    
    // MARK: - Overridden properties

    open override var placeholder: String? {
        didSet {
            innerFloatedLabel.text = placeholder
        }
    }

    open override var attributedPlaceholder: NSAttributedString? {
        didSet {
            innerFloatedLabel.text = attributedPlaceholder?.string ?? placeholder
        }
    }

    open override var textAlignment: NSTextAlignment {
        didSet {
            innerFloatedLabel.textAlignment = textAlignment
        }
    }

    open override var font: UIFont? {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    open override var intrinsicContentSize: CGSize {
        let labelHeight = ceil(floatingPlaceholderFont.lineHeight)
        let textHeight = ceil((font ?? UIFont.systemFont(ofSize: 17)).lineHeight)
        let height = contentInsets.top + labelHeight + labelToTextSpacing + textHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - Inits

    public init(type inputType: StringifyTextField.TextType, cornerRadius: CGFloat = 16) {
        super.init(type: inputType, style: .border(cornerRadius: cornerRadius))

        setup()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    open override func awakeFromNib() {
        super.awakeFromNib()

        applyInnerFloatedConfiguration()
        syncInnerFloatedLabel()
    }

    // MARK: - Overridden functions

    open override func layoutSubviews() {
        super.layoutSubviews()

        innerFloatedLabel.font = floatingPlaceholderFont
        innerFloatedLabel.frame = innerFloatedLabelRect(forBounds: bounds)
        innerFloatedLabel.text = attributedPlaceholder?.string ?? placeholder
        updateInnerFloatedLabelColor(animated: false)
        bringSubviewToFront(innerFloatedLabel)

        applyDisplayLabelTruncation()
    }

    open override func textRect(forBounds bounds: CGRect) -> CGRect {
        innerTextRect(from: super.textRect(forBounds: bounds), bounds: bounds)
    }

    open override func editingRect(forBounds bounds: CGRect) -> CGRect {
        innerTextRect(from: super.editingRect(forBounds: bounds), bounds: bounds)
    }

    open override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        .zero
    }

    open override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.clearButtonRect(forBounds: bounds)

        return CGRect(
            x: rect.origin.x,
            y: (bounds.height - rect.height) / 2,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Overridden UITextFieldDelegate functions

    override open func textFieldDidBeginEditing(_ textField: UITextField) {
        super.textFieldDidBeginEditing(textField)
        updateInnerFloatedLabelColor(animated: true)
    }

    override open func textFieldDidEndEditing(_ textField: UITextField) {
        super.textFieldDidEndEditing(textField)
        updateInnerFloatedLabelColor(animated: true)
    }
}

// MARK: - Private API

private extension InnerFloatedStringifyTextField {
    func setup() {
        applyInnerFloatedConfiguration()

        innerFloatedLabel.font = floatingPlaceholderFont
        innerFloatedLabel.textColor = floatingPlaceholderColor
        innerFloatedLabel.textAlignment = textAlignment
        syncInnerFloatedLabel()

        addSubview(innerFloatedLabel)
    }

    func applyInnerFloatedConfiguration() {
        floatingPlaceholder = false
        contentVerticalAlignment = .top
        clipsToBounds = true
        layer.masksToBounds = true

        if case .border = style {
            return
        }

        style = .border(cornerRadius: layer.cornerRadius > 0 ? layer.cornerRadius : 16)
    }

    func syncInnerFloatedLabel() {
        innerFloatedLabel.text = attributedPlaceholder?.string ?? placeholder
    }

    func innerFloatedLabelRect(forBounds bounds: CGRect) -> CGRect {
        let xPosition = contentInsets.left
        let rightEdge = isClearButtonDisplayed
            ? clearButtonRect(forBounds: bounds).minX
            : bounds.width - contentInsets.right

        return CGRect(
            x: xPosition,
            y: contentInsets.top,
            width: max(0, rightEdge - xPosition),
            height: ceil(floatingPlaceholderFont.lineHeight)
        )
    }

    func innerTextRect(from original: CGRect, bounds: CGRect) -> CGRect {
        let top = innerFloatedLabelRect(forBounds: bounds).maxY + labelToTextSpacing
        let height = max(0, bounds.height - top - contentInsets.bottom)
        let rightEdge = isClearButtonDisplayed
            ? clearButtonRect(forBounds: bounds).minX
            : original.maxX
        let width = max(0, rightEdge - original.origin.x)

        return CGRect(
            x: original.origin.x,
            y: top,
            width: width,
            height: height
        )
    }

    func updateInnerFloatedLabelColor(animated: Bool) {
        let color = isFirstResponder ? floatingPlaceholderActiveColor : floatingPlaceholderColor
        let animationBlock = {
            self.innerFloatedLabel.textColor = color
        }

        if animated {
            UIView.transition(
                with: innerFloatedLabel,
                duration: 0.2,
                options: .transitionCrossDissolve,
                animations: animationBlock,
                completion: nil
            )
        } else {
            animationBlock()
        }
    }

    func applyDisplayLabelTruncation() {
        for subview in subviews {
            guard let label = subview as? UILabel, label !== innerFloatedLabel else { continue }
            label.lineBreakMode = .byTruncatingTail
            label.numberOfLines = 1
        }
    }
}
