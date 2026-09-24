//
//  InnerFloatedStringifyTextField.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 10.09.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import UIKit

/// `StringifyTextField` with an inner floated label.
/// The standard clear button stays vertically centered; value text is clipped to the button
/// and truncated with an ellipsis.
open class InnerFloatedStringifyTextField: StringifyTextField {
    /// How the inner floated label is shown.
    public enum FloatedPlaceholderDisplay {
        /// Label stays at the top of the field, including while the field is empty.
        case alwaysOnTop
        /// Label occupies the text position until a value is entered, then floats to the top.
        case onInput
    }

    // MARK: - Public properties

    /// Floated label visibility.
    /// Default value is `.alwaysOnTop`.
    public var floatedPlaceholderDisplay: FloatedPlaceholderDisplay = .alwaysOnTop {
        didSet {
            setNeedsLayout()
        }
    }

    /// Font size of the floated label.
    /// Default value is `14`.
    @IBInspectable public var floatedLabelFontSize: CGFloat = 14 {
        didSet {
            guard floatedLabelFontSize != oldValue else { return }

            floatingPlaceholderFont = floatingPlaceholderFont.withSize(floatedLabelFontSize)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    /// Insets between the field bounds and inner content.
    /// Default value is `UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)`.
    public var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16) {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    /// Spacing between the inner floated label and the value text.
    /// Default value is `2`.
    public var labelToTextSpacing: CGFloat = 2 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    // MARK: - Private properties

    private let innerFloatedLabel: UILabel = {
        let innerFloatedLabel = UILabel()
        innerFloatedLabel.lineBreakMode = .byTruncatingTail
        return innerFloatedLabel
    }()

    private var isLabelFloated = true
    private var isAnimatingFloatedLabel = false

    private var isFloatedLabelAtTop: Bool {
        switch floatedPlaceholderDisplay {
        case .alwaysOnTop:
            return true
        case .onInput:
            return hasText
        }
    }

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

    private var valueFont: UIFont {
        font ?? UIFont.systemFont(ofSize: 17)
    }

    private var floatedLabelFont: UIFont {
        floatingPlaceholderFont.withSize(floatedLabelFontSize)
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
            setNeedsLayout()
        }
    }

    open override var intrinsicContentSize: CGSize {
        let labelHeight = ceil(floatedLabelFont.lineHeight)
        let textHeight = ceil(valueFont.lineHeight)
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

        let floated = isFloatedLabelAtTop
        let targetFrame = floated ? floatedLabelRect(forBounds: bounds) : restingValueRect(forBounds: bounds)
        let targetFont = floated ? floatedLabelFont : valueFont
        let isInitialLayout = innerFloatedLabel.frame == .zero
        let shouldAnimate = !isInitialLayout && isLabelFloated != floated && !isAnimatingFloatedLabel

        innerFloatedLabel.text = attributedPlaceholder?.string ?? placeholder
        updateInnerFloatedLabelColor(animated: false)

        if shouldAnimate {
            isLabelFloated = floated
            isAnimatingFloatedLabel = true

            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: {
                    self.innerFloatedLabel.frame = targetFrame
                    self.innerFloatedLabel.font = targetFont
                },
                completion: { _ in
                    self.isAnimatingFloatedLabel = false
                }
            )
        } else if !isAnimatingFloatedLabel {
            innerFloatedLabel.frame = targetFrame
            innerFloatedLabel.font = targetFont
            isLabelFloated = floated
        }

        applyDisplayLabelTruncation()

        if !innerFloatedLabel.frame.intersects(valueRect(forBounds: bounds)) {
            bringSubviewToFront(innerFloatedLabel)
        }
    }

    open override func textRect(forBounds bounds: CGRect) -> CGRect {
        valueRect(forBounds: bounds)
    }

    open override func editingRect(forBounds bounds: CGRect) -> CGRect {
        valueRect(forBounds: bounds)
    }

    open override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        .zero
    }

    open override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.clearButtonRect(forBounds: bounds)

        return CGRect(
            x: bounds.width - contentInsets.right - rect.width,
            y: (bounds.height - rect.height) / 2,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Overridden UITextFieldDelegate functions

    override open func textFieldDidBeginEditing(_ textField: UITextField) {
        super.textFieldDidBeginEditing(textField)
        updateInnerFloatedLabelColor(animated: true)
        setNeedsLayout()
    }

    override open func textFieldDidEndEditing(_ textField: UITextField) {
        super.textFieldDidEndEditing(textField)
        updateInnerFloatedLabelColor(animated: true)
        setNeedsLayout()
    }
}

// MARK: - Private API

private extension InnerFloatedStringifyTextField {
    func setup() {
        applyInnerFloatedConfiguration()

        innerFloatedLabel.font = floatedLabelFont
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

    func floatedLabelRect(forBounds bounds: CGRect) -> CGRect {
        let rightEdge = contentRightEdge(forBounds: bounds)

        return CGRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: max(0, rightEdge - contentInsets.left),
            height: ceil(floatedLabelFont.lineHeight)
        )
    }

    func restingValueRect(forBounds bounds: CGRect) -> CGRect {
        let textHeight = ceil(valueFont.lineHeight)
        let topLimit = contentInsets.top
        let bottomLimit = max(topLimit + textHeight, bounds.height - contentInsets.bottom)
        let availableHeight = bottomLimit - topLimit
        let yPosition = topLimit + max(0, (availableHeight - textHeight) / 2)
        let rightEdge = contentRightEdge(forBounds: bounds)

        return CGRect(
            x: contentInsets.left,
            y: yPosition,
            width: max(0, rightEdge - contentInsets.left),
            height: textHeight
        )
    }

    func valueRect(forBounds bounds: CGRect) -> CGRect {
        guard isFloatedLabelAtTop else {
            return restingValueRect(forBounds: bounds)
        }

        let textHeight = ceil(valueFont.lineHeight)
        let slotTop = floatedLabelRect(forBounds: bounds).maxY + labelToTextSpacing
        let slotBottom = max(slotTop + textHeight, bounds.height - contentInsets.bottom)
        let slotHeight = slotBottom - slotTop
        let yPosition = slotTop + max(0, (slotHeight - textHeight) / 2)
        let rightEdge = contentRightEdge(forBounds: bounds)

        return CGRect(
            x: contentInsets.left,
            y: yPosition,
            width: max(0, rightEdge - contentInsets.left),
            height: max(textHeight, slotBottom - yPosition)
        )
    }

    func contentRightEdge(forBounds bounds: CGRect) -> CGFloat {
        if isClearButtonDisplayed {
            return clearButtonRect(forBounds: bounds).minX
        }

        if trailingImage != nil {
            return rightViewRect(forBounds: bounds).minX
        }

        return bounds.width - contentInsets.right
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
