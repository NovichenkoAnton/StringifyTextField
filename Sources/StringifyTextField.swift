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
    /// Called when editing is begin
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didBeginEditing(_ textField: StringifyTextField)
    
    /// Called when editing is end
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didEndEditing(_ textField: StringifyTextField)
    
    /// Called when text field has max inputed symbols
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didFilled(_ textField: StringifyTextField)
    
    /// Called when was inputed/deleted symbol in text field
    /// - Parameter textField: `StringifyTextField`
    @objc optional func didEndChanging(_ textField: StringifyTextField)
    
    /// Called when text field is changed
    /// - Parameters:
    ///   - textField: `StringifyTextField`
    ///   - range: The range of characters to be changed
    ///   - string: Replacement string
    @objc optional func didStartChanging(_ textField: StringifyTextField, in range: NSRange, with string: String)
    
    /// Called when clear button was tapped
    /// - Parameter textField: `StringifyTextField`
    @objc optional func textFieldCleared(_ textField: StringifyTextField)
}

@objc public protocol StringifyTrailingActionDelegate: AnyObject {
    /// Detect tap on trailing view
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
     
     - **amount**: formatted text with sum type, e.g., "1 200,99"
     - **creditCard**: formatted text compatible with credit cards, e.g., "1234 5678 9012 3456"
     - **IBAN**: formatted text compatible with IBAN, e.g., "BY12 BLBB 1234 5678 0000 1234 5678"
     - **expDate**: expired date of credit cards, e.g., "03/22"
     */
    public enum TextType: UInt {
        case amount = 0, creditCard, IBAN, expDate, cvv, none
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
    /// Default value is `true`
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
    /// Default value is `,`(comma).
    @IBInspectable public var decimalSeparator: String = "," {
        didSet {
            numberFormatter.decimalSeparator = decimalSeparator
        }
    }
    
    /// Date format for getting exp date from `plainValue` property.
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
    
    /// Height of line under the text field for an inactive state.
    /// Default value is `1`.
    @IBInspectable public var lineHeightDefault: CGFloat = 1 {
        didSet {
            underlineLayer.frame.size.height = lineHeightDefault
            underlineLayer.cornerRadius = max(lineHeightDefault / 2, 1)
            setNeedsDisplay()
        }
    }
    
    /// Height of line under the text field for an active state.
    /// Default value is `2`.
    @IBInspectable public var lineHeightActive: CGFloat = 2
    
    /// Color for border in inactive state. Only for `.border` style.
    /// Default value is `UIColor.clear`
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
    /// Default value is empty string.
    @IBInspectable public var errorMessage: String = "" {
        didSet {
            errorLabel.text = errorMessage
        }
    }
    
    /// Whether to show error label.
    /// Default value is `true`.
    @IBInspectable public var showsErrorLabel: Bool = true
    
    /// Set up floated placeholder for `UITextField`
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
                floatedLabel.textColor = floatingPlaceholderColor
                setNeedsDisplay()
            }
        }
    }
    
    /// Color for active state of floating placeholder.
    /// Default value is `UIColor.black`.
    @IBInspectable public var floatingPlaceholderActiveColor: UIColor = UIColor.black
    
    /// Padding between text rect and floating label
    /// Default value is 0
    @IBInspectable public var floatingPadding: CGFloat = 0
    
    /// Image on the right side of `LineTextField`.
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
    
    // MARK: - Public properties
    
    /// Specific `TextType` for formatting text in textfield.
    /// Default value is `.amount`.
    public var textType: TextType = .amount {
        didSet {
            configure()
        }
    }
    
    /// Specific `Style` for the text field.
    /// Default value us `.native(borderStyle: .roundedRect)`.
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
    
    // MARK: - Public properties
    
    ///Computed property for getting clean value (without inner whitespaces)
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
    
    /// Set animation when floating placeholder is redrawn.
    /// Default value is `true`.
    public var floatingPlaceholderShowWithAnimation: Bool = true
    
    /// Regular expression for `.none` text type to validate.
    public var pattern: String.RegExpPattern?
    
    // MARK: - Overridden properties
    
    open override var placeholder: String? {
        didSet {
            floatedLabel.text = placeholder
        }
    }
    
    open override var attributedPlaceholder: NSAttributedString? {
        didSet {
            floatedLabel.text = attributedPlaceholder?.string
        }
    }
    
    open override var textAlignment: NSTextAlignment {
        didSet {
            if floatingPlaceholder {
                floatedLabel.textAlignment = textAlignment
            }
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
        floatedLabel.textColor = UIColor.black
        floatedLabel.font = labelFont()
        if let attributedPlaceholder = self.attributedPlaceholder {
            floatedLabel.text = attributedPlaceholder.string
        } else {
            floatedLabel.text = self.placeholder
        }
        floatedLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        floatedLabel.textAlignment = self.textAlignment
        
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
    
    open override func layoutSubviews() {
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
    
    open override func closestPosition(to point: CGPoint) -> UITextPosition? {
        switch textType {
        case .amount:
            return position(from: beginningOfDocument, offset: self.text?.count ?? 0)
        default:
            return super.closestPosition(to: point)
        }
    }
    
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch textType {
        case .amount, .expDate:
            if action == #selector(paste(_:)) || action == #selector(cut(_:)) {
                return false
            }
            return super.canPerformAction(action, withSender: sender)
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    open override func paste(_ sender: Any?) {
        guard UIPasteboard.general.hasStrings, var pastedString = UIPasteboard.general.string else {
            return
        }
        
        pastedString = pastedString
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        
        switch textType {
        case .creditCard:
            if pastedString.hasOnlyDigits(), pastedString.count <= 16 {
                self.text = pastedString.separate(every: 4, with: " ")
                
                if pastedString.count == 16 {
                    stDelegate?.didFilled?(self)
                }
            }
        case .IBAN:
            if pastedString.count <= 34 {
                self.text = pastedString.separate(every: 4, with: " ")
                
                if pastedString.count == 34 {
                    stDelegate?.didFilled?(self)
                }
            }
        default:
            super.paste(sender)
        }
    }
    
    open override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        guard trailingImage != nil else {
            return super.rightViewRect(forBounds: bounds)
        }
        
        let buttonSize = bounds.height * 0.6
        
        let xPosition: CGFloat
        if case .border = style {
            xPosition = bounds.width - buttonSize - trailingPadding - borderTextPadding
        } else {
            xPosition = bounds.width - buttonSize - trailingPadding
        }
        
        let yPosition = (bounds.height - buttonSize) / 2
        
        return CGRect(x: xPosition, y: yPosition, width: buttonSize, height: buttonSize)
    }
    
    open override func editingRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.editingRect(forBounds: bounds)
        
        if case .border = style {
            rect.origin.x += borderTextPadding
            rect.size.width -= borderTextPadding * 2
        }
        
        if trailingImage != nil {
            let buttonSize = bounds.height * 0.6
            let trailingViewWidth = buttonSize + trailingPadding
            
            rect.size.width = bounds.width - rect.origin.x - trailingViewWidth
            
            if case .border = style {
                rect.size.width -= borderTextPadding * 2
            }
        }
        
        return rect
    }
    
    open override func textRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.textRect(forBounds: bounds)
        
        if case .border = style {
            rect.origin.x += borderTextPadding
            rect.size.width -= borderTextPadding * 2
        }
        
        if trailingImage != nil {
            let buttonSize = bounds.height * 0.6
            let trailingViewWidth = buttonSize + trailingPadding
            
            rect.size.width = bounds.width - rect.origin.x - trailingViewWidth
            
            if case .border = style {
                rect.size.width -= borderTextPadding * 2
            }
        }
        
        return rect
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

// MARK: - Private extension (.amount format)

private extension StringifyTextField {
    enum InputedCharacter {
        case number
        case separator
    }
    
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
        //Removing characters
        if string.isEmpty {
            if text.count > 1 {
                let possibleText = String(text.dropLast())
                
                if let lastCharacter = possibleText.last, String(lastCharacter) == decimalSeparator {
                    self.text = possibleText
                } else {
                    if possibleText.toDouble() == .zero {
                        self.text = possibleText
                    } else {
                        self.text = possibleText.ext.applyFormat(.custom(formatter: numberFormatter))
                    }
                }
            } else {
                self.text = (text as NSString).replacingCharacters(in: range, with: string)
            }
            
            return false
        }
        
        
        //Format inputed characters
        let adjustedInputedCharacter: InputedCharacter
        
        if string.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
            adjustedInputedCharacter = .number
        } else {
            adjustedInputedCharacter = .separator
        }
        
        if adjustedInputedCharacter == .separator && !text.contains(decimalSeparator) {
            self.text = text + decimalSeparator
        } else if adjustedInputedCharacter == .number {
            let possibleText = text + string
            
            let amountParts = possibleText.components(separatedBy: decimalSeparator)
            
            if amountParts.count == 2 {
                if let fraction = amountParts.last, fraction.count > maxFractionDigits {
                    self.text = text
                } else {
                    self.text = (text as NSString).replacingCharacters(in: range, with: string)
                }
            } else {
                let inputedText = possibleText.replacingOccurrences(of: " ", with: "")
                
                guard inputedText.count <= maxIntegerDigits else { return false }
                
                self.text = inputedText.ext.applyFormat(.custom(formatter: numberFormatter))
            }
        }
        
        return false
    }
}

// MARK: - Private extension (.creditCard, .IBAN formats)

private extension StringifyTextField {
    func cleanValue() -> String {
        self.text!.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trim()
    }
    
    func shouldChangeText(in range: NSRange, with string: String, and text: String, with maxLength: Int) -> Bool {
        if string.isEmpty {
            self.text = (text as NSString).replacingCharacters(in: range, with: string)
            return false
        }
        
        let cursorLocation = position(from: beginningOfDocument, offset: (range.location + NSString(string: string).length))
        
        let possibleText = (text as NSString).replacingCharacters(in: range, with: string)
        
        if possibleText.count <= maxLength {
            self.text = possibleText.replacingOccurrences(of: " ", with: "").separate(every: 4, with: " ")
        }
        
        if let location = cursorLocation {
            selectedTextRange = textRange(from: location, to: location)
        }
        
        if possibleText.count == maxLength {
            stDelegate?.didFilled?(self)
        }
        
        return false
    }
}

// MARK: - Private extension (.expDate format)

private extension StringifyTextField {
    func expDateCleanValue() -> String {
        guard let text = self.text else { return "" }
        
        return text.ext.convertDate(from: "MM/yy", to: dateFormat) ?? ""
    }
    
    func shouldChangeExpDate(in range: NSRange, with string: String, and text: String) -> Bool {
        if string.isEmpty {
            self.text = (text as NSString).replacingCharacters(in: range, with: string)
            return false
        }
        
        let cursorLocation = position(from: beginningOfDocument, offset: (range.location + NSString(string: string).length))
        
        let possibleText = (text as NSString).replacingCharacters(in: range, with: string)
        
        if possibleText.count == 2 {
            self.text = possibleText + "/"
        } else if possibleText.count <= 5 {
            self.text = possibleText.replacingOccurrences(of: "/", with: "").separate(every: 2, with: "/")
        }
        
        if let location = cursorLocation {
            selectedTextRange = textRange(from: location, to: location)
        }
        
        if possibleText.count == 5 {
            stDelegate?.didFilled?(self)
        }
        
        return false
    }
}

// MARK: - Private extension (.cvv format)

private extension StringifyTextField {
    func cvvCleanValue() -> String {
        guard let text = self.text else { return "" }
        
        return text.trim()
    }
    
    func shouldChangeCVV(in range: NSRange, with string: String, and text: String) -> Bool {
        if string.isEmpty {
            self.text = (text as NSString).replacingCharacters(in: range, with: string)
            return false
        }
        
        let cursorLocation = position(from: beginningOfDocument, offset: (range.location + NSString(string: string).length))
        
        let possibleText = (text as NSString).replacingCharacters(in: range, with: string)
        
        if possibleText.count <= 3 {
            self.text = possibleText
        }
        
        if let location = cursorLocation {
            selectedTextRange = textRange(from: location, to: location)
        }
        
        if possibleText.count == 3 {
            stDelegate?.didFilled?(self)
        }
        
        return false
    }
}

// MARK: - Private extension (.none format)

private extension StringifyTextField {
    func shouldChangeRawText(in range: NSRange, with string: String, and text: String, with maxLength: Int) -> Bool {
        if string.isEmpty {
            let newText = (text as NSString).replacingCharacters(in: range, with: string)
            self.text = newText
            
            let newCursorPosition = range.location
            if let newPosition = self.position(from: self.beginningOfDocument, offset: newCursorPosition) {
                self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
            }
            
            return false
        }
        
        if let pattern, !string.validate(with: pattern) {
            return false
        }
        
        let cursorLocation = position(from: beginningOfDocument, offset: (range.location + NSString(string: string).length))
        let possibleText = (text as NSString).replacingCharacters(in: range, with: string)
        
        if possibleText.count <= maxLength {
            self.text = possibleText
        }
        
        if let location = cursorLocation {
            selectedTextRange = textRange(from: location, to: location)
        }
        
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

// MARK: - Floated placeholder configure

private extension StringifyTextField {
    /// Get font `UIFont` font for floated label
    /// - Returns: Correct `UIFont`
    func labelFont() -> UIFont {
        var currentFont = UIFont.systemFont(ofSize: 17.0)
        
        if let attributedText = self.attributedText, attributedText.length > 0 {
            currentFont = attributedText.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
        }
        
        if let font = self.font {
            currentFont = font
        }
        
        return currentFont.withSize((currentFont.pointSize * 0.7).rounded())
    }
    
    /// Floated label height adjustemnt
    /// - Returns: Adjustment height
    func floatedLabelHeight() -> CGFloat {
        labelFont().lineHeight + 4.0
    }
    
    func updateFloatedLabel(animated: Bool = false) {
        updateFloatedLabelVisibility(animated: animated)
    }
    
    /// Get correct frame of floated label
    /// - Returns: Frame of floated label
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
    
    /// Update alpha and frame of floated label
    /// - Parameter animated: with animation or not
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
    
    /// Update text color of floated label
    /// - Parameter editing: `true` if `UITextField` is editing now
    func updateFloatedLabelColor(editing: Bool, animated: Bool) {
        let animationBlock = { () -> Void in
            if editing && self.hasText {
                self.floatedLabel.textColor = self.floatingPlaceholderActiveColor
            } else {
                self.floatedLabel.textColor = self.floatingPlaceholderColor
            }
        }
        
        if animated {
            UIView.transition(with: floatedLabel, duration: 0.2, options: .transitionCrossDissolve, animations: animationBlock, completion: nil)
        } else {
            animationBlock()
        }
    }
}

// MARK: - UITextFieldDelegate

extension StringifyTextField: UITextFieldDelegate {
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
        
        stDelegate?.didStartChanging?(self, in: range, with: string)
        defer {
            stDelegate?.didEndChanging?(self)
        }
        
        switch textType {
        case .amount:
            return shouldChangeSumText(in: range, with: string, and: text)
        case .creditCard:
            return shouldChangeText(in: range, with: string, and: text, with: 19)
        case .IBAN:
            return shouldChangeText(in: range, with: string, and: text, with: 42)
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
