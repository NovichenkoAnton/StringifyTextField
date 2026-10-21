//
//  ViewController.swift
//  StringifyExample
//
//  Created by Anton Novichenko on 3/22/20.
//  Copyright © 2020 Anton Novichenko. All rights reserved.
//

import UIKit
import StringifyTextField

final class ViewController: UIViewController {
	// MARK: - Outlets

    @IBOutlet var stringifyTextField: StringifyTextField! {
        didSet {
            stringifyTextField.style = .native(borderStyle: .roundedRect)
        }
    }
	@IBOutlet var valueLabel: UILabel!
	@IBOutlet var currencyTextField: UITextField!
	@IBOutlet var dateFormatTextField: UITextField!
	@IBOutlet var segmentedControl: UISegmentedControl!
	@IBOutlet var editingActionsControl: UISegmentedControl!
	@IBOutlet var decimalSwitcher: UISwitch!
	@IBOutlet var amountTextField: StringifyTextField! {
		didSet {
//            amountTextField.style = .line
            amountTextField.style = .border(cornerRadius: 10)
            amountTextField.textType = .none
            amountTextField.maxSymbols = 5
            amountTextField.attributedPlaceholder = NSAttributedString(
                string: NSLocalizedString("PLACEHOLDER", comment: ""),
                attributes: [
                    .foregroundColor: UIColor(red: 0.60, green: 0.64, blue: 0.73, alpha: 1.00),
                    .font: UIFont.systemFont(ofSize: 18)
                ]
            )
            amountTextField.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            amountTextField.borderColorActive = UIColor(red: 0.01, green: 0.50, blue: 1.00, alpha: 1.00)
            amountTextField.borderWidthActive = 2
            amountTextField.floatingPlaceholder = true
            amountTextField.errorDisplayDuration = 1.5
            amountTextField.errorColor = UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1.00)
            amountTextField.errorMessage = "Some error"
            amountTextField.errorLabelTopPadding = 10
            amountTextField.errorLabelFont = UIFont.systemFont(ofSize: 12)
            amountTextField.pattern = .own(pattern: "[A-Za-z0-9]")
            amountTextField.trailingImage = UIImage(named: "image")
            amountTextField.tintAdjustmentMode = .automatic
            amountTextField.clearButtonMode = .whileEditing
            amountTextField.isEnabled = false
            amountTextField.allowsTrailingActionWhenDisabled = true
		}
	}

    private lazy var innerFloatedTextField: InnerFloatedStringifyTextField = {
        let innerFloatedTextField = InnerFloatedStringifyTextField(type: .amount, cornerRadius: 10)
        innerFloatedTextField.contentInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        innerFloatedTextField.stDelegate = self
        let placeholder = NSMutableAttributedString(
            string: "Amount ",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .regular)]
        )
        placeholder.append(NSAttributedString(
            string: "USD",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .bold)]
        ))
        innerFloatedTextField.attributedPlaceholder = placeholder
        innerFloatedTextField.floatedPlaceholderDisplay = .onInput
        innerFloatedTextField.trailingImage = UIImage(named: "image")
        innerFloatedTextField.font = UIFont.systemFont(ofSize: 17)
        innerFloatedTextField.textColor = UIColor.black
        innerFloatedTextField.tintColor = UIColor(red: 0.25, green: 0.55, blue: 1.00, alpha: 1)
        innerFloatedTextField.floatingPlaceholderFont = UIFont.systemFont(ofSize: 14)
        innerFloatedTextField.floatingPlaceholderColor = UIColor(red: 0.60, green: 0.64, blue: 0.73, alpha: 1)
        innerFloatedTextField.floatingPlaceholderActiveColor = UIColor.blue
        innerFloatedTextField.borderColorDefault = UIColor.clear
        innerFloatedTextField.borderColorActive = UIColor(red: 0.25, green: 0.55, blue: 1.00, alpha: 1)
        innerFloatedTextField.borderWidthInactive = 1
        innerFloatedTextField.borderWidthActive = 2
        innerFloatedTextField.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        innerFloatedTextField.keyboardAppearance = .dark
        innerFloatedTextField.translatesAutoresizingMaskIntoConstraints = false
        return innerFloatedTextField
    }()

    @IBOutlet var errorButton: UIButton!
	@IBOutlet var scrollView: UIScrollView!
	@IBOutlet var contentView: UIView!

	private var keyboardOverlap: CGFloat = 0
	private var keyboardFrameObserver: NSObjectProtocol?

    // MARK: - Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()

		configureKeyboardAvoidance()
		configureUI()
	}

	deinit {
		if let keyboardFrameObserver {
			NotificationCenter.default.removeObserver(keyboardFrameObserver)
		}
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		view.endEditing(true)
	}

	private func configureKeyboardAvoidance() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
		tap.cancelsTouchesInView = false
		tap.delegate = self
		scrollView.addGestureRecognizer(tap)

		keyboardFrameObserver = NotificationCenter.default.addObserver(
			forName: UIResponder.keyboardWillChangeFrameNotification,
			object: nil,
			queue: .main
		) { [weak self] notification in
			self?.adjustScrollView(for: notification)
		}
	}

	@objc private func dismissKeyboard() {
		view.endEditing(true)
	}

	private func adjustScrollView(for notification: Notification) {
		guard
			let userInfo = notification.userInfo,
			let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
			let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
			let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
		else { return }

		let keyboardInView = view.convert(endFrame, from: nil)
		let overlap = max(0, scrollView.frame.maxY - keyboardInView.minY)
		let previousOverlap = keyboardOverlap
		keyboardOverlap = overlap

		let options = UIView.AnimationOptions(rawValue: curveValue << 16).union(.beginFromCurrentState)
		UIView.animate(withDuration: duration, delay: 0, options: options) {
			var inset = self.scrollView.contentInset
			inset.bottom = overlap
			self.scrollView.contentInset = inset
			self.scrollView.verticalScrollIndicatorInsets.bottom = overlap

			if overlap > previousOverlap {
				self.scrollActiveTextFieldAboveKeyboard(animated: false)
			}
		}
	}

	private func scrollActiveTextFieldAboveKeyboard(animated: Bool) {
		guard keyboardOverlap > 0, let textField = activeTextField() else { return }

		let padding: CGFloat = 16
		let field = textField.convert(textField.bounds, to: scrollView).insetBy(dx: 0, dy: -padding)
		let visibleHeight = scrollView.bounds.height - keyboardOverlap
		guard visibleHeight > 0 else { return }

		var offsetY = scrollView.contentOffset.y
		let visibleTop = offsetY
		let visibleBottom = offsetY + visibleHeight

		if field.maxY > visibleBottom {
			offsetY += field.maxY - visibleBottom
		} else if field.minY < visibleTop {
			offsetY -= visibleTop - field.minY
		} else {
			return
		}

		let minOffset = -scrollView.adjustedContentInset.top
		let maxOffset = max(minOffset, scrollView.contentSize.height + keyboardOverlap - scrollView.bounds.height)
		offsetY = min(max(offsetY, minOffset), maxOffset)

		let offset = CGPoint(x: scrollView.contentOffset.x, y: offsetY)
		if animated {
			scrollView.setContentOffset(offset, animated: true)
		} else {
			scrollView.contentOffset = offset
		}
	}

	private func activeTextField() -> UIView? {
		func search(_ view: UIView) -> UIView? {
			if view.isFirstResponder { return view }
			for subview in view.subviews {
				if let match = search(subview) { return match }
			}
			return nil
		}

		return search(view)
	}

	private func configureUI() {
		switch stringifyTextField.textType {
		case .amount:
			segmentedControl.selectedSegmentIndex = 0
		case .creditCard:
			segmentedControl.selectedSegmentIndex = 1
		case .IBAN:
			segmentedControl.selectedSegmentIndex = 2
		case .expDate:
			segmentedControl.selectedSegmentIndex = 3
		case .cvv:
			segmentedControl.selectedSegmentIndex = 4
        case .none:
            segmentedControl.selectedSegmentIndex = 5
		}

		decimalSwitcher.isOn = stringifyTextField.decimal
		applyEditingActions()

        contentView.addSubview(innerFloatedTextField)
        NSLayoutConstraint.activate([
            innerFloatedTextField.topAnchor.constraint(equalTo: errorButton.bottomAnchor, constant: 24),
            innerFloatedTextField.leadingAnchor.constraint(equalTo: amountTextField.leadingAnchor),
            innerFloatedTextField.trailingAnchor.constraint(equalTo: amountTextField.trailingAnchor),
            innerFloatedTextField.heightAnchor.constraint(equalToConstant: 55),
            innerFloatedTextField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
	}

	// MARK: - Events
	@IBAction func didChangeEditingActions(_ sender: UISegmentedControl) {
		applyEditingActions()
	}

	@IBAction func didChangeSegment(_ sender: UISegmentedControl) {
		stringifyTextField.text = ""
		stringifyTextField.resignFirstResponder()

		if sender.selectedSegmentIndex == 0 {
			stringifyTextField.textType = .amount
		} else if sender.selectedSegmentIndex == 1 {
			stringifyTextField.textType = .creditCard
		} else if sender.selectedSegmentIndex == 2 {
			stringifyTextField.textType = .IBAN
		} else if sender.selectedSegmentIndex == 3 {
			stringifyTextField.textType = .expDate
		} else if sender.selectedSegmentIndex == 4 {
			stringifyTextField.textType = .cvv
        } else if sender.selectedSegmentIndex == 5 {
            stringifyTextField.textType = .none
        }
	}

	@IBAction func getTextFieldValue(_ sender: Any) {
		valueLabel.text = "Textfield value is:\n\(stringifyTextField.plainValue)"
	}

	@IBAction func copyCardNumber(_ sender: Any) {
		UIPasteboard.general.string = "1234567890123456"
	}

	@IBAction func changeDecimal(_ sender: UISwitch) {
		stringifyTextField.decimal = sender.isOn
	}
    
    @IBAction func showError(_ sender: Any) {
        amountTextField.showError()
        innerFloatedTextField.showError(message: "Error 2")
    }

	private func applyEditingActions() {
		let actions: StringifyTextField.EditingActions

		switch editingActionsControl.selectedSegmentIndex {
		case 1:
			actions = .excluding([.cut, .paste])
		case 2:
			actions = .only([.copy, .select, .selectAll])
		case 3:
			actions = .none
		default:
			actions = .all
		}

		stringifyTextField.editingActions = actions
		innerFloatedTextField.editingActions = actions
	}
}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
	func textFieldDidBeginEditing(_ textField: UITextField) {
		scrollActiveTextFieldAboveKeyboard(animated: true)
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		if textField == currencyTextField {
			stringifyTextField.currencyMark = textField.text!.trim()
		} else if textField == dateFormatTextField {
			stringifyTextField.dateFormat = textField.text!.trim()
		}
	}
}

// MARK: - StringifyTextFieldDelegate
extension ViewController: StringifyTextFieldDelegate {
	func didBeginEditing(_ textField: StringifyTextField) {
		print("did begin editing \(textField.text!)")
		scrollActiveTextFieldAboveKeyboard(animated: true)
	}

	func didEndEditing(_ textField: StringifyTextField) {
		print("did end editing \(textField.text!)")
	}

	func didFilled(_ textField: StringifyTextField) {
		print("textField filled with text \(textField.text!)")
	}

	func shouldChangeCharacters(_ textField: StringifyTextField, in range: NSRange, with string: String) -> Bool {
		print("should change characters in \(textField.text!) with: \(string)")
		return true
	}

	func didStartChanging(_ textField: StringifyTextField, in range: NSRange, with string: String) {
		print("textField start changing text: \(textField.text!) in with: \(string)")
	}
    
    func didEndChanging(_ textField: StringifyTextField) {
        print("textField has a text after input/delete: \(textField.text!)")
    }
    
    func textFieldCleared(_ textField: StringifyTextField) {
        print("textField was cleared")
    }
}

extension ViewController: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		var touchedView = touch.view
		while let view = touchedView {
			if view is UIControl { return false }
			touchedView = view.superview
		}
		return true
	}
}

extension ViewController: StringifyTrailingActionDelegate {
	func didTapTrailing(_ sender: UIButton, textField: StringifyTextField) {
		print("tap")
	}
}

