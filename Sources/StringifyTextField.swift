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

	/// Called when text field is changed
	/// - Parameters:
	///   - textField: `StringifyTextField`
	///   - range: The range of characters to be changed
	///   - string: Replacement string
	@objc optional func didStartChanging(_ textField: StringifyTextField, in range: NSRange, with string: String)
}

@objc public protocol StringifyTrailingActionDelegate: AnyObject {
	/// Detect tap on trailing view
	/// - Parameter sender: `UIButton`
	func didTapTrailing(_ sender: UIButton, textField: StringifyTextField)
}

public class StringifyTextField: UITextField {
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

	/// Date format for getting exp date from `associatedValue` property.
	/// Default value is "MMyy".
	@IBInspectable public var dateFormat: String = "MMyy"

	/// Add underline for `UITextField`
	/// Default valie is `false`
	@IBInspectable public var lineVisible: Bool = false {
		didSet {
			if lineVisible {
				configureBottomLine()
				setNeedsDisplay()
			}
		}
	}

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

	@IBOutlet public weak var stDelegate: StringifyTextFieldDelegate?
	@IBOutlet public weak var stActionDelegate: StringifyTrailingActionDelegate?

	// MARK: - Private properties

	private lazy var numberFormatter = NumberFormatter()

	private lazy var floatedLabel: UILabel = UILabel(frame: .zero)

	private lazy var trailingButton: UIButton = {
		let trailingButton = UIButton(type: .system)
		trailingButton.tintColor = trailingTintColor
		trailingButton.addTarget(self, action: #selector(trailingButtonTap(_:)), for: .touchUpInside)
		return trailingButton
	}()

	private lazy var underlineLayer = CALayer()

	private let colorAnimation = CABasicAnimation(keyPath: "backgroundColor")
	private let frameAnimation = CABasicAnimation(keyPath: "frame.size.height")
	private let groupAnimation = CAAnimationGroup()

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
		default:
			return text!
		}
	}

	// MARK: - Overridden properties

	public override var placeholder: String? {
		didSet {
			floatedLabel.text = placeholder
		}
	}

	public override var textAlignment: NSTextAlignment {
		didSet {
			if floatingPlaceholder {
				floatedLabel.textAlignment = textAlignment
			}
		}
	}

	// MARK: - Inits

	public init(type inputType: TextType) {
		self.textType = inputType

		super.init(frame: .zero)

		configure()

		if lineVisible {
			configureBottomLine()
		}

		if floatingPlaceholder {
			configureFloatedPlaceholder()
		}
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		configure()

		if lineVisible {
			configureBottomLine()
		}

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

		underlineLayer.frame = CGRect(x: 0, y: self.bounds.height, width: self.bounds.width, height: 1)
		underlineLayer.backgroundColor = lineColorDefault.cgColor
		underlineLayer.cornerRadius = 1

		layer.addSublayer(underlineLayer)
	}

	private func configureFloatedPlaceholder() {
		borderStyle = .none

		floatedLabel.alpha = 1
		floatedLabel.textColor = UIColor.black
		floatedLabel.font = labelFont()
		floatedLabel.text = self.placeholder
		floatedLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		floatedLabel.textAlignment = self.textAlignment

		addSubview(floatedLabel)
		bringSubviewToFront(floatedLabel)
	}

	private func configureTrailingImage() {
		rightView = nil
		rightViewMode = .never

		guard let image = trailingImage else { return }

		let originalImage = image.withRenderingMode(.alwaysTemplate)
		trailingButton.setImage(originalImage, for: .normal)
		trailingButton.tintColor = trailingTintColor

		rightViewMode = .always
		rightView = trailingButton
	}

	// MARK: - Overridden

	public override func layoutSubviews() {
		super.layoutSubviews()

		if lineVisible {
			underlineLayer.frame = CGRect(x: 0, y: self.bounds.height, width: self.bounds.width, height: underlineLayer.frame.height)
		}

		if floatingPlaceholder {
			floatedLabel.frame = floatedLabelRect()

			updateFloatedLabelColor(editing: (hasText && isFirstResponder))
			updateFloatedLabel(animated: hasText)
		}

		if trailingImage != nil {
			trailingButton.frame = CGRect(x: bounds.width - (bounds.height * 0.8 + trailingPadding), y: (bounds.height - bounds.height * 0.8)/2, width: bounds.height * 0.8, height: bounds.height * 0.8)
		}
	}

	public override func closestPosition(to point: CGPoint) -> UITextPosition? {
		switch textType {
		case .amount:
			return position(from: beginningOfDocument, offset: self.text?.count ?? 0)
		default:
			return super.closestPosition(to: point)
		}
	}

	public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
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

	public override func paste(_ sender: Any?) {
		guard UIPasteboard.general.hasStrings, var pastedString = UIPasteboard.general.string else {
			return
		}

		pastedString = pastedString.replacingOccurrences(of: " ", with: "")

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

	public override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
		var rect = super.rightViewRect(forBounds: bounds)
		rect.origin.x -= trailingPadding
		return rect
	}

	public override func editingRect(forBounds bounds: CGRect) -> CGRect {
		var rect = super.editingRect(forBounds: bounds)
		if trailingImage != nil {
			rect.size.width -= (bounds.height * 0.8 - trailingPadding)
		}

		return rect
	}

	public override func textRect(forBounds bounds: CGRect) -> CGRect {
		var rect = super.textRect(forBounds: bounds)
		if trailingImage != nil {
			rect.size.width -= (bounds.height * 0.8 - trailingPadding)
		}
		return rect
	}

	// MARK: - Events

	@objc func trailingButtonTap(_ sender: UIButton) {
		stActionDelegate?.didTapTrailing(sender, textField: self)
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
			return textWithoutCurrency.replacingOccurrences(of: " ", with: "")
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

				return false
			} else {
				return true
			}
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
					return true
				}
			} else {
				let inputedText = possibleText.replacingOccurrences(of: " ", with: "")
				guard inputedText.count <= maxIntegerDigits else {
					return false
				}

				self.text = inputedText.ext.applyFormat(.custom(formatter: numberFormatter))
			}
		}

		return false
	}
}

// MARK: - Private extension (.creditCard, .IBAN formats)

private extension StringifyTextField {
	func cleanValue() -> String {
		self.text!.replacingOccurrences(of: " ", with: "").trim()
	}

	func shouldChangeText(in range: NSRange, with string: String, and text: String, with maxLength: Int) -> Bool {
		if string.isEmpty {
			return true
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
			return true
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
			return true
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

// MARK: - Bottom line animation

private extension StringifyTextField {
	func activateBottomLine() {
		colorAnimation.fromValue = underlineLayer.backgroundColor
		colorAnimation.toValue = lineColorActive.cgColor

		frameAnimation.fromValue = underlineLayer.frame.size.height
		frameAnimation.toValue = underlineLayer.frame.size.height + 1

		groupAnimation.animations = [colorAnimation, frameAnimation]
		groupAnimation.duration = 0.2

		underlineLayer.removeAllAnimations()
		underlineLayer.add(groupAnimation, forKey: nil)

		underlineLayer.backgroundColor = lineColorActive.cgColor
		underlineLayer.frame.size.height += 1
	}

	func deactivateBottomLine() {
		colorAnimation.fromValue = underlineLayer.backgroundColor
		colorAnimation.toValue = lineColorDefault.cgColor

		frameAnimation.fromValue = underlineLayer.frame.size.height
		frameAnimation.toValue = underlineLayer.frame.size.height - 1

		groupAnimation.animations = [colorAnimation, frameAnimation]
		groupAnimation.duration = 0.2

		underlineLayer.removeAllAnimations()
		underlineLayer.add(groupAnimation, forKey: nil)

		underlineLayer.backgroundColor = lineColorDefault.cgColor
		underlineLayer.frame.size.height -= 1
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
			return CGRect(x: 0, y: -9 - floatingPadding, width: bounds.size.width, height: labelHeight)
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
			UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: animationBlock, completion: nil)
		} else {
			animationBlock()
		}
	}

	/// Update text color of floated label
	/// - Parameter editing: `true` if `UITextField` is editing now
	func updateFloatedLabelColor(editing: Bool, animated: Bool = true) {
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
	public func textFieldDidBeginEditing(_ textField: UITextField) {
		if lineVisible {
			activateBottomLine()
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

	public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		guard let text = textField.text else { return false }

		stDelegate?.didStartChanging?(self, in: range, with: string)

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
		default:
			return true
		}
	}

	public func textFieldDidEndEditing(_ textField: UITextField) {
		if lineVisible {
			deactivateBottomLine()
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

	public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		return resignFirstResponder()
	}
}
