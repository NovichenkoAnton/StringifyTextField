//
//  StringifyTextField.swift
//  Stringify
//
//  Created by Anton Novichenko on 3/18/20.
//  Copyright © 2020 Anton Novichenko. All rights reserved.
//

import UIKit
import Extendy

@objc public protocol StringifyTextFieldDelegate: AnyObject {
    /// Called when editing begins.
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didBeginEditing(_ textField: StringifyTextField)
    
    /// Called when editing ends.
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didEndEditing(_ textField: StringifyTextField)
    
    /// Called when the text field reaches the maximum number of entered symbols.
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didFilled(_ textField: StringifyTextField)
    
    /// Called when a symbol is entered or deleted in the text field.
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didEndChanging(_ textField: StringifyTextField)
    
    /// Asks whether the specified text should be changed.
    /// Return `false` to keep the current text, `true` to allow the change.
    /// If unimplemented, the change is allowed.
    /// - Parameters:
    ///   - textField: `StringifyTextField`
    ///   - range: The range of characters to be replaced
    ///   - string: The replacement string
    /// - Returns: `true` if the text should be changed, otherwise `false`
    @objc optional func shouldChangeCharacters(_ textField: StringifyTextField, in range: NSRange, with string: String) -> Bool
    
    /// Called when the text field is changed.
    /// - Parameters:
    ///   - textField: `StringifyTextField`
    ///   - range: The range of characters to be changed
    ///   - string: Replacement string
    @objc optional func didStartChanging(_ textField: StringifyTextField, in range: NSRange, with string: String)
    
    /// Called when the clear button is tapped.
    /// - Parameter textField: `StringifyTextField`
    @objc optional func textFieldCleared(_ textField: StringifyTextField)
}

@objc public protocol StringifyTrailingActionDelegate: AnyObject {
    /// Called when the trailing view is tapped.
    /// - Parameter sender: `UIButton`
    func didTapTrailing(_ sender: UIButton, textField: StringifyTextField)
}

open class StringifyTextField: UITextField {
    /// Styles for `StringifyTextField`
    public enum Style {
        case line
        case border(cornerRadius: CGFloat = 0)
        case native(borderStyle: UITextField.BorderStyle)
    }
    
    /**
     Possible text types for `StringifyTextField`
     
     - **amount**: formatted amount, e.g., "1 200,99"
     - **creditCard**: formatted text compatible with credit cards, e.g., "1234 5678 9012 3456"
     - **IBAN**: formatted text compatible with IBAN, e.g., "BY12 BLBB 1234 5678 0000 1234 5678"
     - **expDate**: expiration date of a credit card, e.g., "03/22"
     - **cvv**: CVV code of a credit card, e.g., "123"
     - **none**: unformatted text with optional validation
     */
    public enum TextType: UInt {
        case amount = 0, creditCard, IBAN, expDate, cvv, none
    }
    
    /// An action from the text field edit menu.
    public struct EditingAction: OptionSet {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        /// Cut the selected text.
        public static let cut = EditingAction(rawValue: 1 << 0)
        /// Copy the selected text.
        public static let copy = EditingAction(rawValue: 1 << 1)
        /// Paste from the pasteboard.
        public static let paste = EditingAction(rawValue: 1 << 2)
        /// Select the word nearest to the insertion point.
        public static let select = EditingAction(rawValue: 1 << 3)
        /// Select all text.
        public static let selectAll = EditingAction(rawValue: 1 << 4)
        /// Delete the selected text.
        public static let delete = EditingAction(rawValue: 1 << 5)
        /// Paste and match the current style. Available on iOS 15 and later.
        public static let pasteAndMatchStyle = EditingAction(rawValue: 1 << 6)
        /// Paste and open the pasted content. Available on iOS 15 and later.
        public static let pasteAndGo = EditingAction(rawValue: 1 << 7)
        /// Paste and search for the pasted content. Available on iOS 15 and later.
        public static let pasteAndSearch = EditingAction(rawValue: 1 << 8)
        /// Capture text from the camera. Available on iOS 15 and later.
        public static let captureTextFromCamera = EditingAction(rawValue: 1 << 9)
        /// Show system writing tools. Available on iOS 18.2 and later.
        public static let showWritingTools = EditingAction(rawValue: 1 << 10)
        
        /// Every action represented by this set.
        public static let all: EditingAction = [
            .cut, .copy, .paste, .select, .selectAll, .delete,
            .pasteAndMatchStyle, .pasteAndGo, .pasteAndSearch,
            .captureTextFromCamera, .showWritingTools
        ]
    }
    
    /// Which edit-menu actions `StringifyTextField` offers.
    public enum EditingActions {
        /// Every action the system offers.
        case all
        /// No edit-menu actions.
        case none
        /// Every system action except the given ones. Actions that are not listed here stay available.
        case excluding(EditingAction)
        /// Only the given actions. Any other system action is hidden.
        case only(EditingAction)
    }
    
    // MARK: - IBInspectable
    
    @available(*, unavailable, message: "This property is reserved for Interface Builder. Use 'textType' instead.")
    @IBInspectable var inputTextType: UInt {
        get {
            textType.rawValue
        }
        set {
            textType = StringifyTextField.TextType(rawValue: min(newValue, 4)) ?? .none
        }
    }
    
    /// Max symbols for `.none` type.
    /// Default value is `100`.
    @IBInspectable public var maxSymbols: UInt = 100
    
    /// Currency mark for `.amount` type.
    /// Default value is an empty string.
    @IBInspectable public var currencyMark: String = ""
    
    /// Maximum digits for integer part of amount.
    /// Default value is 10.
    @IBInspectable public var maxIntegerDigits: UInt = 10
    
    /// Use decimal separator or not. Only for `.amount` type.
    /// Default value is `true`.
    @IBInspectable public var decimal: Bool = true {
        didSet {
            if textType == .amount {
                configureDecimalFormat()
            }
        }
    }
    
    /// Add grouping separator for `NumberFormatter`. Only for `.amount` type.
    /// Default value is `true`.
    @IBInspectable public var needGroupingSeparator: Bool = true {
        didSet {
            if needGroupingSeparator {
                numberFormatter.groupingSeparator = " "
            } else {
                numberFormatter.groupingSeparator = ""
            }
        }
    }
    
    /// Max number of digits in fraction part. Only for `.amount` type.
    /// Default value is `2`.
    @IBInspectable public var maxFractionDigits: UInt = 2 {
        didSet {
            numberFormatter.maximumFractionDigits = Int(maxFractionDigits)
        }
    }
    
    /// Decimal separator between integer and fraction parts. Only for `.amount` type.
    /// Default value is `,` (comma).
    @IBInspectable public var decimalSeparator: String = "," {
        didSet {
            numberFormatter.decimalSeparator = decimalSeparator
        }
    }
    
    /// Date format for getting the expiration date from the `plainValue` property.
    /// Default value is "MMyy".
    @IBInspectable public var dateFormat: String = "MMyy"
    
    /// Color for default state of the bottom line.
    /// Default value is `UIColor.white`.
    @IBInspectable public var lineColorDefault: UIColor = UIColor.white {
        didSet {
            underlineLayer.backgroundColor = lineColorDefault.cgColor
            setNeedsDisplay()
        }
    }
    
    /// Color for active state of the bottom line.
    /// Default value is `UIColor.black`.
    @IBInspectable public var lineColorActive: UIColor = UIColor.black
    
    /// Height of the line under the text field for an inactive state.
    /// Default value is `1`.
    @IBInspectable public var lineHeightDefault: CGFloat = 1 {
        didSet {
            underlineLayer.frame.size.height = lineHeightDefault
            underlineLayer.cornerRadius = max(lineHeightDefault / 2, 1)
            setNeedsDisplay()
        }
    }
    
    /// Height of the line under the text field for an active state.
    /// Default value is `2`.
    @IBInspectable public var lineHeightActive: CGFloat = 2
    
    /// Color for border in inactive state. Only for `.border` style.
    /// Default value is `UIColor.clear`.
    @IBInspectable public var borderColorDefault: UIColor = UIColor.clear {
        didSet {
            if case .border = style {
                layer.borderColor = borderColorDefault.cgColor
            }
        }
    }
    
    /// Color for border in active state. Only for `.border` style.
    /// Default value is `UIColor.blue`.
    @IBInspectable public var borderColorActive: UIColor = UIColor.blue
    
    /// Width for border in inactive state. Only for `.border` style.
    /// Default value is `.zero`.
    @IBInspectable public var borderWidthInactive: CGFloat = .zero{
        didSet {
            if case .border = style, !isFirstResponder {
                layer.borderWidth = borderWidthInactive
            }
        }
    }
    
    /// Width for border in active state. Only for `.border` style.
    /// Default value is `1.0`.
    @IBInspectable public var borderWidthActive: CGFloat = 1.0
    
    /// Color for error state.
    /// Default value is `UIColor.red`.
    @IBInspectable public var errorColor: UIColor = UIColor.red

    /// Error display duration before auto-hiding.
    /// Default value is `1.0`.
    @IBInspectable public var errorDisplayDuration: Double = 1.0
    
    /// Top padding between text field and error label.
    /// Default value is `4.0`.
    @IBInspectable public var errorLabelTopPadding: CGFloat = 4.0
    
    /// Error message to display.
    /// Default value is an empty string.
    @IBInspectable public var errorMessage: String = "" {
        didSet {
            errorLabel.text = errorMessage
        }
    }
    
    /// Whether to show the error label.
    /// Default value is `true`.
    @IBInspectable public var showsErrorLabel: Bool = true
    
    /// Set up a floating placeholder for `UITextField`.
    /// Default value is `false`.
    @IBInspectable public var floatingPlaceholder: Bool = false {
        didSet {
            if floatingPlaceholder {
                configureFloatedPlaceholder()
            }
        }
    }
    
    /// Color for inactive state of floating placeholder.
    /// Default value is `UIColor.black`.
    @IBInspectable public var floatingPlaceholderColor: UIColor = UIColor.black {
        didSet {
            if floatingPlaceholder {
                applyFloatedLabelColor(floatingPlaceholderColor)
                setNeedsDisplay()
            }
        }
    }
    
    /// Color for active state of floating placeholder.
    /// Default value is `UIColor.black`.
    @IBInspectable public var floatingPlaceholderActiveColor: UIColor = UIColor.black
    
    /// Padding between text rect and floating label.
    /// Default value is 0.
    @IBInspectable public var floatingPadding: CGFloat = 0
    
    /// Font for the floating placeholder.
    /// When `floatingAttributedPlaceholder` contains font attributes, each run keeps its typeface,
    /// including a custom font, and is scaled so the largest font matches this font's point size.
    /// Default value is `UIFont.systemFont(ofSize: 14)`.
    public var floatingPlaceholderFont: UIFont = UIFont.systemFont(ofSize: 14) {
        didSet {
            updateFloatedPlaceholderText()
            if floatingPlaceholder {
                setNeedsLayout()
            }
        }
    }

    /// Attributed text of the floating placeholder.
    /// Font runs are copied as set, so a custom font is not replaced by the text field font.
    /// The largest font is scaled to `floatingPlaceholderFont`.
    /// `InnerFloatedStringifyTextField` keeps those sizes until the label floats, then scales them to `floatedLabelFontSize`.
    /// Foreground color still follows `floatingPlaceholderColor` and `floatingPlaceholderActiveColor`.
    /// Setting `attributedPlaceholder` updates this value. A later rewrite that drops fonts for the same text does not.
    public var floatingAttributedPlaceholder: NSAttributedString? {
        didSet {
            guard !isApplyingFloatingAttributedPlaceholder else { return }

            if let current = floatingAttributedPlaceholder,
               let copied = current.copy() as? NSAttributedString,
               copied !== current {
                isApplyingFloatingAttributedPlaceholder = true
                floatingAttributedPlaceholder = copied
                isApplyingFloatingAttributedPlaceholder = false
            }

            applyAttributedPlaceholder(floatingAttributedPlaceholder, updatesFloatingText: false)
            updateFloatedPlaceholderText()
        }
    }
    
    /// Image on the right side of `StringifyTextField`.
    @IBInspectable public var trailingImage: UIImage? {
        didSet {
            configureTrailingImage()
        }
    }
    
    @IBInspectable public var trailingTintColor: UIColor? {
        didSet {
            trailingButton.tintColor = trailingTintColor
            setNeedsDisplay()
        }
    }
    
    public var trailingImageRenderingMode: UIImage.RenderingMode = .alwaysTemplate {
        didSet {
            guard let trailingImage else { return }
            
            let originalImage = trailingImage.withRenderingMode(trailingImageRenderingMode)
            trailingButton.setImage(originalImage, for: .normal)
            setNeedsDisplay()
        }
    }
    
    /// Right padding for trailing image.
    /// Default value is 0.
    @IBInspectable public var trailingPadding: CGFloat = 0
    
    /// Allows tapping the trailing button while the text field is disabled.
    /// Default value is `false`.
    @IBInspectable public var allowsTrailingActionWhenDisabled: Bool = false {
        didSet {
            updateTrailingButtonInteraction()
        }
    }
    
    // MARK: - Public properties
    
    /// Specific `TextType` for formatting text in the text field.
    /// Default value is `.amount`.
    public var textType: TextType = .amount {
        didSet {
            configure()
        }
    }
    
    /// Specific `Style` for the text field.
    /// Default value is `.native(borderStyle: .roundedRect)`.
    public var style: Style = .native(borderStyle: .roundedRect) {
        didSet {
            configureStyle()
        }
    }
    
    /// Font for error label.
    /// Default value is `UIFont.systemFont(ofSize: 14)`.
    public var errorLabelFont: UIFont = UIFont.systemFont(ofSize: 14) {
        didSet {
            errorLabel.font = errorLabelFont
        }
    }
    
    @IBOutlet public weak var stDelegate: StringifyTextFieldDelegate?
    @IBOutlet public weak var stActionDelegate: StringifyTrailingActionDelegate?
    
    // MARK: - Private properties
    
    private lazy var numberFormatter = NumberFormatter()
    
    private lazy var floatedLabel: UILabel = UILabel(frame: .zero)
    
    private lazy var errorLabel: UILabel = {
        let errorLabel = UILabel()
        errorLabel.textColor = errorColor
        errorLabel.font = errorLabelFont
        errorLabel.text = errorMessage
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.alpha = 0.0
        return errorLabel
    }()
    
    private lazy var trailingButton: UIButton = {
        let trailingButton = UIButton(type: .system)
        trailingButton.tintColor = trailingTintColor
        trailingButton.addTarget(self, action: #selector(trailingButtonTap(_:)), for: .touchUpInside)
        return trailingButton
    }()
    
    private lazy var underlineLayer = CALayer()
    
    private let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
    private let frameAnimation = CABasicAnimation(keyPath: "frame.size.height")
    private let cornerRadiusAnimation = CABasicAnimation(keyPath: "cornerRadius")
    private let borderColorAnimation = CABasicAnimation(keyPath: "borderColor")
    private let borderWidthAnimation = CABasicAnimation(keyPath: "borderWidth")
    private let groupAnimation = CAAnimationGroup()
        
    private let borderTextPadding: CGFloat = 16
    
    private var isBorderAnimating = false
    
    private var isShowingError = false
    private var errorWorkItem: DispatchWorkItem?
    private var isAdjustingCursor = false
    private var cursorAdjustmentID = 0
    private var isEditingActionsCustomized = false
    private var isApplyingFloatingAttributedPlaceholder = false
    private var isInsideAttributedPlaceholderSuper = false
    private var isLayoutingFloatedPlaceholder = false
    
    // MARK: - Public properties
    
    /// Computed property for getting the clean value (without inner whitespaces).
    public var plainValue: String {
        switch textType {
        case .amount:
            return cleanValueForSum()
        case .creditCard:
            return cleanValue()
        case .IBAN:
            return cleanValue().uppercased()
        case .expDate:
            return expDateCleanValue()
        case .cvv:
            return cvvCleanValue()
        case .none:
            return text.orEmpty
        }
    }
    
    /// Enable animation when the floating placeholder is redrawn.
    /// Default value is `true`.
    public var floatingPlaceholderShowWithAnimation: Bool = true
    
    /// Regular expression used to validate `.none` text type.
    public var pattern: String.RegExpPattern?
    
    /// Actions available in the edit menu.
    /// Default value is `.all`.
    ///
    /// Disable actions with `.excluding`, or leave only specific ones with `.only`.
    /// `.amount` and `.expDate` hide Cut and Paste until this property is set.
    /// Setting it, including back to `.all`, replaces that restriction.
    public var editingActions: EditingActions = .all {
        didSet {
            isEditingActionsCustomized = true
        }
    }
    
    // MARK: - Overridden properties
    
    open override var placeholder: String? {
        didSet {
            guard !isInsideAttributedPlaceholderSuper, !isApplyingFloatingAttributedPlaceholder else { return }

            if placeholder != floatingAttributedPlaceholder?.string {
                isApplyingFloatingAttributedPlaceholder = true
                floatingAttributedPlaceholder = nil
                isApplyingFloatingAttributedPlaceholder = false
            }
            updateFloatedPlaceholderText()
        }
    }
    
    open override var attributedPlaceholder: NSAttributedString? {
        get { floatingAttributedPlaceholder ?? super.attributedPlaceholder }
        set { applyAttributedPlaceholder(newValue, updatesFloatingText: true) }
    }

    /// Refreshes the floating placeholder after its text or font changes.
    /// `InnerFloatedStringifyTextField` updates its inner label from here.
    open func updateFloatedPlaceholderText() {
        syncFloatedLabelText()
    }
    
    open override var textAlignment: NSTextAlignment {
        didSet {
            if floatingPlaceholder {
                floatedLabel.textAlignment = textAlignment
            }
            setNeedsLayout()
        }
    }
    
    open override var isEnabled: Bool {
        didSet {
            updateTrailingButtonInteraction()
        }
    }
    
    // MARK: - Inits
    
    public init(type inputType: TextType, style: StringifyTextField.Style) {
        self.textType = inputType
        self.style = style
        
        super.init(frame: .zero)
        
        configure()
        configureStyle()
        
        if floatingPlaceholder {
            configureFloatedPlaceholder()
        }
    }
    
    convenience public init(type inputType: TextType) {
        self.init(type: inputType, style: .line)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        configure()
        configureStyle()
        
        if floatingPlaceholder {
            configureFloatedPlaceholder()
        }
    }
    
    // MARK: - Functions
    
    private func configure() {
        delegate = self
        
        switch textType {
        case .amount:
            configureDecimalFormat()
        case .creditCard, .expDate, .cvv:
            keyboardType = .numberPad
        case .IBAN:
            keyboardType = .asciiCapable
            autocapitalizationType = .allCharacters
            autocorrectionType = .no
            returnKeyType = .done
        case .none:
            keyboardType = .default
        }
    }
    
    private func configureStyle() {
        switch style {
        case .line:
            configureBottomLine()
        case let .native(borderStyle):
            self.borderStyle = borderStyle
        case let .border(cornerRadius):
            self.borderStyle = .none
            self.layer.cornerRadius = cornerRadius
            self.layer.borderWidth = borderWidthInactive
            self.layer.borderColor = borderColorDefault.cgColor
        }
    }
    
    private func configureDecimalFormat() {
        if decimal {
            keyboardType = .decimalPad
            
            if needGroupingSeparator {
                numberFormatter.groupingSeparator = " "
            }
            numberFormatter.decimalSeparator = decimalSeparator
            numberFormatter.maximumFractionDigits = Int(maxFractionDigits)
            numberFormatter.numberStyle = .decimal
        } else {
            keyboardType = .numberPad
        }
    }
    
    private func configureBottomLine() {
        borderStyle = .none
        
        underlineLayer.frame = CGRect(x: 0, y: self.bounds.height, width: self.bounds.width, height: lineHeightDefault)
        underlineLayer.backgroundColor = lineColorDefault.cgColor
        underlineLayer.cornerRadius = 1
        
        layer.addSublayer(underlineLayer)
    }
    
    private func configureFloatedPlaceholder() {
        borderStyle = .none
        
        floatedLabel.alpha = 1
        floatedLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        floatedLabel.textAlignment = self.textAlignment
        updateFloatedPlaceholderText()
        
        addSubview(floatedLabel)
        bringSubviewToFront(floatedLabel)
    }
    
    private func configureTrailingImage() {
        rightView = nil
        rightViewMode = .never
        
        guard let image = trailingImage else { return }
        
        let originalImage = image.withRenderingMode(trailingImageRenderingMode)
        trailingButton.setImage(originalImage, for: .normal)
        trailingButton.tintColor = trailingTintColor
        
        rightViewMode = .always
        rightView = trailingButton
        updateTrailingButtonInteraction()
    }
    
    private func updateTrailingButtonInteraction() {
        let isTrailingActionAvailable = isEnabled || allowsTrailingActionWhenDisabled
        trailingButton.isEnabled = isTrailingActionAvailable
        trailingButton.isUserInteractionEnabled = isTrailingActionAvailable
        trailingButton.tintAdjustmentMode = (!isEnabled && allowsTrailingActionWhenDisabled) ? .normal : .automatic
    }
    
    private func setupErrorLabel() {
        guard let superview else { return }
        
        errorLabel.removeFromSuperview()
        
        superview.addSubview(errorLabel)
        superview.bringSubviewToFront(errorLabel)
                
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: self.bottomAnchor, constant: errorLabelTopPadding),
            errorLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }
    
    // MARK: - Overridden
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if allowsTrailingActionWhenDisabled, !isEnabled, trailingImage != nil, rightView != nil, !trailingButton.isHidden {
            let pointInButton = trailingButton.convert(point, from: self)
            if trailingButton.point(inside: pointInButton, with: event) {
                return trailingButton
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    open override func layoutSubviews() {
        isLayoutingFloatedPlaceholder = true
        defer { isLayoutingFloatedPlaceholder = false }

        super.layoutSubviews()
        
        if case .line = style {
            underlineLayer.frame = CGRect(x: 0, y: self.bounds.height, width: self.bounds.width, height: underlineLayer.frame.height)
        }
        
        if floatingPlaceholder {
            floatedLabel.frame = floatedLabelRect()
            
            updateFloatedLabelColor(editing: (hasText && isFirstResponder), animated: floatingPlaceholderShowWithAnimation)
            updateFloatedLabel(animated: hasText)
        }
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if superview != nil && showsErrorLabel {
            setupErrorLabel()
        }
    }
    
    open override func removeFromSuperview() {
        errorLabel.removeFromSuperview()
        super.removeFromSuperview()
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard allowsEditingAction(action) else { return false }
        
        return super.canPerformAction(action, withSender: sender)
    }
    
    open override func paste(_ sender: Any?) {
        guard allowsEditingAction(#selector(paste(_:))) else { return }
        
        switch textType {
        case .creditCard, .IBAN:
            guard UIPasteboard.general.hasStrings, let pastedString = UIPasteboard.general.string else {
                return
            }
            _ = textField(self, shouldChangeCharactersIn: selectedUTF16Range(), replacementString: pastedString)
        default:
            super.paste(sender)
        }
    }
    
    open override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        guard trailingImage != nil else {
            return super.rightViewRect(forBounds: bounds)
        }
        
        let buttonSize = bounds.height * 0.6
        let xPosition = bounds.width - buttonSize - trailingPadding - horizontalInset(for: style)
        let yPosition = (bounds.height - buttonSize) / 2
        
        return CGRect(x: xPosition, y: yPosition, width: buttonSize, height: buttonSize)
    }
    
    open override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.clearButtonRect(forBounds: bounds)
        guard case .border = style else { return rect }
        
        return CGRect(
            x: rightAccessoryEdge(forBounds: bounds) - rect.width,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )
    }
    
    open override func editingRect(forBounds bounds: CGRect) -> CGRect {
        paddedTextRect(from: super.editingRect(forBounds: bounds), bounds: bounds)
    }
    
    open override func textRect(forBounds bounds: CGRect) -> CGRect {
        paddedTextRect(from: super.textRect(forBounds: bounds), bounds: bounds)
    }
    
    open override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        textRect(forBounds: bounds)
    }
    
    private func paddedTextRect(from original: CGRect, bounds: CGRect) -> CGRect {
        var rect = original
        let inset = horizontalInset(for: style)

        if textAlignment == .center, inset > 0 {
            let rightEdge = textRightEdge(forBounds: bounds)
            return CGRect(
                x: 0,
                y: original.origin.y,
                width: max(0, rightEdge),
                height: original.size.height
            )
        }
        
        if inset > 0 {
            rect.origin.x += inset
            rect.size.width = max(0, textRightEdge(forBounds: bounds) - rect.origin.x)
            return rect
        }
        
        if trailingImage != nil {
            let buttonSize = bounds.height * 0.6
            rect.size.width = bounds.width - rect.origin.x - buttonSize - trailingPadding
        }
        
        return rect
    }
    
    private func horizontalInset(for style: Style) -> CGFloat {
        if case .border = style {
            return borderTextPadding
        }
        return 0
    }
    
    private func rightAccessoryEdge(forBounds bounds: CGRect) -> CGFloat {
        if trailingImage != nil {
            return rightViewRect(forBounds: bounds).minX
        }
        return bounds.width - horizontalInset(for: style)
    }
    
    private func textRightEdge(forBounds bounds: CGRect) -> CGFloat {
        if isClearButtonVisible {
            return clearButtonRect(forBounds: bounds).minX
        }

        if trailingImage != nil {
            return rightViewRect(forBounds: bounds).minX
        }

        if textAlignment == .center, horizontalInset(for: style) > 0 {
            return bounds.width
        }

        return rightAccessoryEdge(forBounds: bounds)
    }
    
    private var isClearButtonVisible: Bool {
        guard hasText else { return false }
        
        switch clearButtonMode {
        case .always:
            return true
        case .whileEditing:
            return isEditing
        case .unlessEditing:
            return !isEditing
        default:
            return false
        }
    }
    
    // MARK: - Events
    
    @objc func trailingButtonTap(_ sender: UIButton) {
        stActionDelegate?.didTapTrailing(sender, textField: self)
    }
    
    // MARK: - Public API
    
    public func showError(message: String? = nil) {
        if let message {
            self.errorMessage = message
        }
        
        showError(for: errorDisplayDuration)
    }
    
    public func showError(for duration: Double) {
        guard !isShowingError else { return }
        
        errorWorkItem?.cancel()
        
        isShowingError = true
        
        errorLabel.text = errorMessage
        
        animateToErrorState()
        showErrorLabel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideError()
        }
        errorWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + errorDisplayDuration, execute: workItem)
    }
    
    public func hideError() {
        errorWorkItem?.cancel()
        errorWorkItem = nil
        
        isShowingError = false
        
        hideErrorLabel()
        animateToNormalState()
    }
}

// MARK: - Edit menu

private extension StringifyTextField {
    func allowsEditingAction(_ action: Selector) -> Bool {
        switch editingActions {
        case .all:
            guard !isEditingActionsCustomized else { return true }
            guard let editingAction = editingAction(for: action) else { return true }
            return !defaultRestrictedEditingActions.contains(editingAction)
        case .none:
            return false
        case .excluding(let excluded):
            guard let editingAction = editingAction(for: action) else { return true }
            return !excluded.contains(editingAction)
        case .only(let allowed):
            guard let editingAction = editingAction(for: action) else { return false }
            return allowed.contains(editingAction)
        }
    }
    
    var defaultRestrictedEditingActions: EditingAction {
        switch textType {
        case .amount, .expDate:
            return [.cut, .paste]
        default:
            return []
        }
    }
    
    func editingAction(for action: Selector) -> EditingAction? {
        switch action {
        case #selector(cut(_:)):
            return .cut
        case #selector(copy(_:)):
            return .copy
        case #selector(paste(_:)):
            return .paste
        case #selector(select(_:)):
            return .select
        case #selector(selectAll(_:)):
            return .selectAll
        case #selector(delete(_:)):
            return .delete
        default:
            break
        }
        
        guard #available(iOS 15.0, *) else { return nil }
        
        switch action {
        case #selector(pasteAndMatchStyle(_:)):
            return .pasteAndMatchStyle
        case #selector(pasteAndGo(_:)):
            return .pasteAndGo
        case #selector(pasteAndSearch(_:)):
            return .pasteAndSearch
        case #selector(captureTextFromCamera(_:)):
            return .captureTextFromCamera
        default:
            break
        }
        
        guard #available(iOS 18.2, *) else { return nil }
        
        if action == #selector(showWritingTools(_:)) {
            return .showWritingTools
        }
        
        return nil
    }
}

// MARK: - Private extension (.amount format)

private extension StringifyTextField {
    func applySumFormat() {
        if !currencyMark.isEmpty {
            self.text = self.text!.replacingOccurrences(of: currencyMark, with: "").trim()
        }
    }
    
    func sumFormatEnding() {
        let cleanValue = self.text!.ext.clean(minFractionDigits: 0, maxFractionDigits: Int(maxFractionDigits), decimalSeparator: decimalSeparator)
        self.text = "\(cleanValue.ext.applyFormat(.custom(formatter: numberFormatter))) \(currencyMark)".trim()
    }
    
    func cleanValueForSum() -> String {
        var textWithoutCurrency = self.text!.trim()
        
        if !currencyMark.isEmpty {
            textWithoutCurrency = textWithoutCurrency.replacingOccurrences(of: currencyMark, with: "")
        }
        
        if decimal {
            return textWithoutCurrency.ext.clean(minFractionDigits: 0, maxFractionDigits: Int(maxFractionDigits), decimalSeparator: decimalSeparator)
        } else {
            return textWithoutCurrency.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
        }
    }
    
    func shouldChangeSumText(in range: NSRange, with string: String, and text: String) -> Bool {
        let sanitizer = TextSanitizer.Amount(
            allowsDecimal: decimal,
            decimalSeparator: decimalSeparator,
            maxFractionDigits: Int(maxFractionDigits),
            currencyMark: currencyMark
        )
        let normalizer = TextNormalizer.Amount(
            allowsDecimal: decimal,
            decimalSeparator: decimalSeparator,
            maxIntegerDigits: Int(maxIntegerDigits),
            maxFractionDigits: Int(maxFractionDigits),
            groupsDigits: needGroupingSeparator
        )
        return applyMaskedChange(
            text: text,
            range: range,
            replacement: string,
            isContent: normalizer.isContent,
            sanitize: sanitizer.sanitize,
            format: normalizer.format,
            filledCount: nil,
            replacing: .pastedValue
        )
    }
}

// MARK: - Private extension (.creditCard, .IBAN formats)

private extension StringifyTextField {
    func cleanValue() -> String {
        self.text!.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trim()
    }
    
    func shouldChangeCardText(in range: NSRange, with string: String, and text: String) -> Bool {
        let digits = TextSanitizer.DecimalDigits()
        let normalizer = TextNormalizer.Grouped(limit: 16, stride: 4)
        return applyMaskedChange(
            text: text,
            range: range,
            replacement: string,
            isContent: digits.isDigit,
            sanitize: digits.sanitize,
            format: normalizer.format,
            filledCount: 16,
            replacing: .fullValue
        )
    }
    
    func shouldChangeIBANText(in range: NSRange, with string: String, and text: String) -> Bool {
        let sanitizer = TextSanitizer.NonWhitespace()
        let normalizer = TextNormalizer.Grouped(limit: 34, stride: 4)
        return applyMaskedChange(
            text: text,
            range: range,
            replacement: string,
            isContent: sanitizer.isContent,
            sanitize: sanitizer.sanitize,
            format: normalizer.format,
            filledCount: 34,
            replacing: .iban(wholeNumberLength: 15)
        )
    }
}

// MARK: - Private extension (.expDate format)

private extension StringifyTextField {
    func expDateCleanValue() -> String {
        guard let text = self.text else { return "" }
        
        return text.ext.convertDate(from: "MM/yy", to: dateFormat) ?? ""
    }
    
    func shouldChangeExpDate(in range: NSRange, with string: String, and text: String) -> Bool {
        let digits = TextSanitizer.DecimalDigits()
        let normalizer = TextNormalizer.ExpirationDate()
        return applyMaskedChange(
            text: text,
            range: range,
            replacement: string,
            isContent: digits.isDigit,
            sanitize: digits.sanitize,
            format: normalizer.format,
            filledCount: 4
        )
    }
}

// MARK: - Private extension (.cvv format)

private extension StringifyTextField {
    func cvvCleanValue() -> String {
        guard let text = self.text else { return "" }
        
        return text.trim()
    }
    
    func shouldChangeCVV(in range: NSRange, with string: String, and text: String) -> Bool {
        let digits = TextSanitizer.DecimalDigits()
        let normalizer = TextNormalizer.Limited(limit: 3)
        return applyMaskedChange(
            text: text,
            range: range,
            replacement: string,
            isContent: digits.isDigit,
            sanitize: digits.sanitize,
            format: normalizer.format,
            filledCount: 3
        )
    }
}

// MARK: - Private extension (.none format)

private extension StringifyTextField {
    func shouldChangeRawText(in range: NSRange, with string: String, and text: String, with maxLength: Int) -> Bool {
        if string.isEmpty {
            let newText = (text as NSString).replacingCharacters(in: range, with: string)
            self.text = newText
            moveCursor(to: range.location)
            return false
        }
        
        if let pattern, !string.validate(with: pattern) {
            return false
        }
        
        let possibleText = (text as NSString).replacingCharacters(in: range, with: string)
        
        if possibleText.count > maxLength {
            if let selectedTextRange {
                updateCursor(selectedTextRange)
            }
            return false
        }
        
        self.text = possibleText
        moveCursor(to: range.location + (string as NSString).length)
        
        if possibleText.count == maxLength {
            stDelegate?.didFilled?(self)
        }
        
        return false
    }
}

// MARK: - Bottom line animation

private extension StringifyTextField {
    func activateBottomLine() {
        colorAnimation.fromValue = underlineLayer.backgroundColor
        colorAnimation.toValue = lineColorActive.cgColor
        
        frameAnimation.fromValue = underlineLayer.frame.size.height
        frameAnimation.toValue = lineHeightActive
        
        cornerRadiusAnimation.fromValue = underlineLayer.cornerRadius
        cornerRadiusAnimation.toValue = lineHeightActive / 2
        
        groupAnimation.animations = [colorAnimation, frameAnimation, cornerRadiusAnimation]
        groupAnimation.duration = 0.2
        
        underlineLayer.add(groupAnimation, forKey: nil)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        underlineLayer.backgroundColor = lineColorActive.cgColor
        underlineLayer.frame.size.height = lineHeightActive
        underlineLayer.cornerRadius = lineHeightActive / 2
        CATransaction.commit()
    }
    
    func deactivateBottomLine() {
        colorAnimation.fromValue = underlineLayer.backgroundColor
        colorAnimation.toValue = lineColorDefault.cgColor
        
        frameAnimation.fromValue = underlineLayer.frame.size.height
        frameAnimation.toValue = lineHeightDefault
        
        cornerRadiusAnimation.fromValue = underlineLayer.cornerRadius
        cornerRadiusAnimation.toValue = max(lineHeightDefault / 2, 1)
        
        groupAnimation.animations = [colorAnimation, frameAnimation]
        groupAnimation.duration = 0.2
        
        underlineLayer.add(groupAnimation, forKey: nil)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        underlineLayer.backgroundColor = lineColorDefault.cgColor
        underlineLayer.frame.size.height = lineHeightDefault
        underlineLayer.cornerRadius = max(lineHeightDefault / 2, 1)
        CATransaction.commit()
    }
}

// MARK: - Border animation

private extension StringifyTextField {
    func activateBorder() {
        isBorderAnimating = true
        
        borderColorAnimation.fromValue = layer.borderColor
        borderColorAnimation.toValue = borderColorActive.cgColor
        
        borderWidthAnimation.fromValue = layer.borderWidth
        borderWidthAnimation.toValue = borderWidthActive
        
        groupAnimation.animations = [borderColorAnimation, borderWidthAnimation]
        groupAnimation.duration = 0.15
        
        layer.add(groupAnimation, forKey: "borderFadeIn")
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.borderColor = borderColorActive.cgColor
        layer.borderWidth = borderWidthActive
        CATransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isBorderAnimating = false
        }
    }
    
    private func deactivateBorder() {
        guard case .border = style, !isBorderAnimating else { return }
        
        isBorderAnimating = true
        
        borderColorAnimation.fromValue = layer.borderColor
        borderColorAnimation.toValue = borderColorDefault
        
        borderWidthAnimation.fromValue = layer.borderWidth
        borderWidthAnimation.toValue = borderWidthInactive
        
        groupAnimation.animations = [borderColorAnimation, borderWidthAnimation]
        groupAnimation.duration = 0.15
        
        layer.add(groupAnimation, forKey: "borderFadeOut")
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.borderColor = borderColorDefault.cgColor
        layer.borderWidth = borderWidthInactive
        CATransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isBorderAnimating = false
        }
    }
}

// MARK: - Error animation

private extension StringifyTextField {
    func animateToErrorState() {
        switch style {
        case .line:
            colorAnimation.fromValue = underlineLayer.backgroundColor
            colorAnimation.toValue = errorColor.cgColor
            
            if isFirstResponder {
                groupAnimation.animations = [colorAnimation]
            } else {
                frameAnimation.fromValue = underlineLayer.frame.size.height
                frameAnimation.toValue = lineHeightActive
                
                cornerRadiusAnimation.fromValue = underlineLayer.cornerRadius
                cornerRadiusAnimation.toValue = lineHeightActive / 2
                
                groupAnimation.animations = [colorAnimation, frameAnimation, cornerRadiusAnimation]
            }
            
            groupAnimation.duration = 0.2
            
            underlineLayer.add(groupAnimation, forKey: "errorColor")
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if !isFirstResponder {
                underlineLayer.frame.size.height = lineHeightActive
                underlineLayer.cornerRadius = lineHeightActive / 2
            }
            
            underlineLayer.backgroundColor = errorColor.cgColor
            CATransaction.commit()
        case .border:
            borderColorAnimation.fromValue = layer.borderColor
            borderColorAnimation.toValue = errorColor.cgColor
            
            borderWidthAnimation.fromValue = layer.borderWidth
            borderWidthAnimation.toValue = borderWidthActive
            
            groupAnimation.animations = [borderColorAnimation, borderWidthAnimation]
            groupAnimation.duration = 0.15
            
            layer.add(groupAnimation, forKey: "borderColor")
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.borderColor = errorColor.cgColor
            layer.borderWidth = borderWidthActive
            CATransaction.commit()
        default:
            break
        }
    }
    
    func animateToNormalState() {
        switch style {
        case .line:
            let targetColor: CGColor
            let height: CGFloat
            let cornerRadius: CGFloat
            
            if isFirstResponder {
                targetColor = lineColorActive.cgColor
                height = lineHeightActive
                cornerRadius = lineHeightActive / 2
            } else {
                targetColor = lineColorDefault.cgColor
                height = lineHeightDefault
                cornerRadius = max(lineHeightDefault / 2, 1)
            }
            
            colorAnimation.fromValue = underlineLayer.backgroundColor
            colorAnimation.toValue = targetColor
            
            if isFirstResponder {
                groupAnimation.animations = [colorAnimation]
            } else {
                frameAnimation.fromValue = underlineLayer.frame.size.height
                frameAnimation.toValue = height
                
                cornerRadiusAnimation.fromValue = underlineLayer.cornerRadius
                cornerRadiusAnimation.toValue = cornerRadius
                
                groupAnimation.animations = [colorAnimation, frameAnimation, cornerRadiusAnimation]
            }
            
            groupAnimation.duration = 0.2
            
            underlineLayer.add(groupAnimation, forKey: "errorColor")
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            underlineLayer.backgroundColor = targetColor
            underlineLayer.frame.size.height = height
            underlineLayer.cornerRadius = cornerRadius
            CATransaction.commit()
        case .border:
            let targetColor: CGColor
            if isFirstResponder {
                targetColor = borderColorActive.cgColor
            } else {
                targetColor = borderColorDefault.cgColor
            }
            
            borderColorAnimation.fromValue = layer.borderColor
            borderColorAnimation.toValue = targetColor
            borderColorAnimation.duration = 0.15
            
            layer.add(borderColorAnimation, forKey: "borderColor")
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.borderColor = targetColor
            CATransaction.commit()
        default:
            break
        }
    }
    
    private func showErrorLabel() {
        guard showsErrorLabel && !errorMessage.isEmpty else { return }
        
        if errorLabel.superview == nil {
            setupErrorLabel()
        }
        
        errorLabel.isHidden = false
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: {
            self.errorLabel.alpha = 1.0
        }, completion: nil)
    }
    
    private func hideErrorLabel() {
        guard errorLabel.superview != nil else { return }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: {
            self.errorLabel.alpha = 0.0
        }) { _ in
            self.errorLabel.isHidden = true
        }
    }
}

// MARK: - Floating placeholder configuration

private extension StringifyTextField {
    /// Floating label height adjustment.
    /// - Returns: Adjusted height
    func floatedLabelHeight() -> CGFloat {
        let fallbackLineHeight = floatingPlaceholderFont.lineHeight
        guard let attributedText = floatedLabel.attributedText, attributedText.length > 0 else {
            return fallbackLineHeight + 4.0
        }

        return maximumFontLineHeight(in: attributedText, fallback: floatingPlaceholderFont) + 4.0
    }

    func applyAttributedPlaceholder(_ newValue: NSAttributedString?, updatesFloatingText: Bool) {
        if isInsideAttributedPlaceholderSuper { return }

        let incoming = newValue?.copy() as? NSAttributedString
        if updatesFloatingText && shouldKeepFloatingAttributedPlaceholder(insteadOf: incoming) {
            return
        }

        if updatesFloatingText {
            isApplyingFloatingAttributedPlaceholder = true
            floatingAttributedPlaceholder = incoming
            isApplyingFloatingAttributedPlaceholder = false
        }

        isInsideAttributedPlaceholderSuper = true
        super.attributedPlaceholder = incoming
        isInsideAttributedPlaceholderSuper = false

        if updatesFloatingText {
            updateFloatedPlaceholderText()
        }
    }

    func shouldKeepFloatingAttributedPlaceholder(insteadOf incoming: NSAttributedString?) -> Bool {
        guard let current = floatingAttributedPlaceholder, current.length > 0 else { return false }
        guard let incoming, current.string == incoming.string else { return false }
        guard containsFontAttribute(current) else { return false }

        if !containsFontAttribute(incoming) {
            return true
        }

        return isLayoutingFloatedPlaceholder
    }

    func syncFloatedLabelText() {
        let color = floatedLabelColor(isActive: hasText && isFirstResponder)

        if let floatingAttributedPlaceholder, floatingAttributedPlaceholder.length > 0 {
            floatedLabel.attributedText = attributedStringForFloatedLabel(
                floatingAttributedPlaceholder,
                fitting: floatingPlaceholderFont.pointSize,
                fallbackFont: floatingPlaceholderFont,
                color: color
            )
        } else {
            floatedLabel.attributedText = nil
            floatedLabel.font = floatingPlaceholderFont
            floatedLabel.textColor = color
            floatedLabel.text = placeholder
        }
    }

    func floatedLabelColor(isActive: Bool) -> UIColor {
        isActive ? floatingPlaceholderActiveColor : floatingPlaceholderColor
    }

    func applyFloatedLabelColor(_ color: UIColor) {
        setFloatedLabelForegroundColor(color, of: floatedLabel)
    }
    
    func updateFloatedLabel(animated: Bool = false) {
        updateFloatedLabelVisibility(animated: animated)
    }
    
    /// Get the correct frame of the floating label.
    /// - Returns: Frame of the floating label
    func floatedLabelRect() -> CGRect {
        let labelHeight = floatedLabelHeight()
        
        if hasText {
            if case .border = style {
                return CGRect(x: 0, y: -20 - floatingPadding, width: bounds.size.width, height: labelHeight)
            } else {
                return CGRect(x: 0, y: -9 - floatingPadding, width: bounds.size.width, height: labelHeight)
            }
        }
        
        return CGRect(x: 0, y: bounds.origin.y, width: bounds.size.width, height: labelHeight)
    }
    
    /// Update alpha and frame of the floating label.
    /// - Parameter animated: Whether to animate the update.
    func updateFloatedLabelVisibility(animated: Bool) {
        let alpha: CGFloat = hasText ? 1.0 : 0.0
        let frame = floatedLabelRect()
        let animationBlock = { () -> Void in
            self.floatedLabel.frame = frame
            self.floatedLabel.alpha = alpha
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: animationBlock, completion: nil)
        } else {
            animationBlock()
        }
    }
    
    /// Update text color of the floating label.
    /// - Parameter editing: `true` if `UITextField` is being edited
    func updateFloatedLabelColor(editing: Bool, animated: Bool) {
        let color = floatedLabelColor(isActive: editing && hasText)
        let animationBlock = { () -> Void in
            self.applyFloatedLabelColor(color)
        }
        
        if animated {
            UIView.transition(with: floatedLabel, duration: 0.2, options: .transitionCrossDissolve, animations: animationBlock, completion: nil)
        } else {
            animationBlock()
        }
    }
}

// MARK: - Private extension (masked editing)

private extension StringifyTextField {
    func applyMaskedChange(
        text: String,
        range: NSRange,
        replacement: String,
        isContent: @escaping (Character) -> Bool,
        sanitize: @escaping (String) -> String?,
        format: @escaping (String) -> String?,
        filledCount: Int?,
        replacing: MaskedEdit.Replacing = .atCaret
    ) -> Bool {
        let edit = MaskedEdit(
            isContent: isContent,
            sanitize: sanitize,
            format: format,
            filledCount: filledCount,
            replacing: replacing
        )
        guard let outcome = edit.outcome(
            in: text,
            range: range,
            replacement: replacement,
            isForwardDelete: isForwardDelete(range: range)
        ) else {
            return false
        }
        
        self.text = outcome.text
        moveCursor(to: outcome.caretOffset)
        if outcome.isFilled {
            stDelegate?.didFilled?(self)
        }
        return false
    }
    
    func isForwardDelete(range: NSRange) -> Bool {
        guard let selectedTextRange, range.length > 0 else { return false }
        
        let start = offset(from: beginningOfDocument, to: selectedTextRange.start)
        let end = offset(from: beginningOfDocument, to: selectedTextRange.end)
        return start == range.location && end == range.location
    }
}

// MARK: - Private extension (cursor)

private extension StringifyTextField {
    func selectedUTF16Range() -> NSRange {
        guard let selectedTextRange else {
            let length = (text as NSString?)?.length ?? 0
            return NSRange(location: length, length: 0)
        }
        
        let location = offset(from: beginningOfDocument, to: selectedTextRange.start)
        let end = offset(from: beginningOfDocument, to: selectedTextRange.end)
        return NSRange(location: location, length: max(0, end - location))
    }
    
    /// Places the caret at a UTF-16 offset of the current text.
    /// The offset is resolved after the text is updated, so the position stays inside the new document.
    func moveCursor(to offset: Int) {
        let length = (text as NSString?)?.length ?? 0
        let clampedOffset = min(max(offset, 0), length)
        guard let position = position(from: beginningOfDocument, offset: clampedOffset),
              let range = textRange(from: position, to: position) else { return }
        updateCursor(range)
    }

    /// UIKit enables Shift when `selectedTextRange` changes.
    /// The next typed character then becomes uppercase, including after a caret move in the middle of a word.
    /// Autocapitalization is suspended for that assignment unless the caret is at a position that should stay capitalized.
    func updateCursor(_ range: UITextRange) {
        let suppressShift = shouldSuppressAutocapitalization(for: range)
        let autocapitalization = autocapitalizationType

        isAdjustingCursor = true
        if suppressShift {
            autocapitalizationType = .none
        }
        selectedTextRange = range
        if suppressShift {
            autocapitalizationType = autocapitalization
        }
        isAdjustingCursor = false
    }

    func shouldSuppressAutocapitalization(for range: UITextRange) -> Bool {
        switch autocapitalizationType {
        case .sentences, .words:
            guard markedTextRange == nil else { return false }
            let caretOffset = offset(from: beginningOfDocument, to: range.start)
            return !shouldAutocapitalize(at: caretOffset)
        default:
            return false
        }
    }

    func shouldAutocapitalize(at caretOffset: Int) -> Bool {
        guard caretOffset > 0, let text, !text.isEmpty else { return true }

        let nsText = text as NSString
        guard caretOffset <= nsText.length else { return false }

        let prefix = nsText.substring(to: caretOffset)
        guard let last = prefix.last else { return true }

        switch autocapitalizationType {
        case .words:
            return last.isWhitespace || last.isNewline
        case .sentences:
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }

            let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let terminator = trimmed.last else { return true }
            return ".!?…".contains(terminator)
        default:
            return false
        }
    }

    func suppressAutocapitalizationForCurrentCaret() {
        guard !isAdjustingCursor, markedTextRange == nil else { return }
        guard let selectedTextRange, shouldSuppressAutocapitalization(for: selectedTextRange) else { return }

        let autocapitalization = autocapitalizationType
        isAdjustingCursor = true
        autocapitalizationType = .none
        self.selectedTextRange = selectedTextRange
        autocapitalizationType = autocapitalization
        isAdjustingCursor = false
    }
}

// MARK: - UITextFieldDelegate

extension StringifyTextField: UITextFieldDelegate {
    @available(iOS 13.0, *)
    open func textFieldDidChangeSelection(_ textField: UITextField) {
        guard !isAdjustingCursor else { return }
        guard let selectedTextRange, shouldSuppressAutocapitalization(for: selectedTextRange) else { return }

        cursorAdjustmentID += 1
        let adjustmentID = cursorAdjustmentID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.cursorAdjustmentID == adjustmentID else { return }
            self.suppressAutocapitalizationForCurrentCaret()
        }
    }

    open func textFieldDidBeginEditing(_ textField: UITextField) {
        if case .line = style {
            activateBottomLine()
        } else if case .border = style {
            activateBorder()
        }
        
        guard hasText else {
            stDelegate?.didBeginEditing?(self)
            return
        }
        
        switch textType {
        case .amount:
            applySumFormat()
        default:
            break
        }
        
        stDelegate?.didBeginEditing?(self)
    }
    
    open func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return false }
        
        if stDelegate?.shouldChangeCharacters?(self, in: range, with: string) == false {
            return false
        }
        
        stDelegate?.didStartChanging?(self, in: range, with: string)
        defer {
            stDelegate?.didEndChanging?(self)
        }
        
        switch textType {
        case .amount:
            return shouldChangeSumText(in: range, with: string, and: text)
        case .creditCard:
            return shouldChangeCardText(in: range, with: string, and: text)
        case .IBAN:
            return shouldChangeIBANText(in: range, with: string, and: text)
        case .expDate:
            return shouldChangeExpDate(in: range, with: string, and: text)
        case .cvv:
            return shouldChangeCVV(in: range, with: string, and: text)
        case .none:
            return shouldChangeRawText(in: range, with: string, and: text, with: Int(maxSymbols))
        }
    }
    
    open func textFieldDidEndEditing(_ textField: UITextField) {
        if case .line = style {
            deactivateBottomLine()
        } else if case .border = style {
            deactivateBorder()
        }
        
        guard hasText else {
            stDelegate?.didEndEditing?(self)
            return
        }
        
        switch textType {
        case .amount:
            sumFormatEnding()
        default:
            break
        }
        
        stDelegate?.didEndEditing?(self)
    }
    
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return resignFirstResponder()
    }
    
    open func textFieldShouldClear(_ textField: UITextField) -> Bool {
        defer {
            stDelegate?.textFieldCleared?(self)
        }
        return true
    }
}
