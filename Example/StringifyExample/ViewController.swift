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
	@IBOutlet var stringifyTextField: StringifyTextField!
	@IBOutlet var valueLabel: UILabel!
	@IBOutlet var currencyTextField: UITextField!
	@IBOutlet var dateFormatTextField: UITextField!
	@IBOutlet var segmentedControl: UISegmentedControl!
	@IBOutlet var decimalSwitcher: UISwitch!
	@IBOutlet var amountTextField: StringifyTextField! {
		didSet {
			amountTextField.placeholder = NSLocalizedString("PLACEHOLDER", comment: "")
		}
	}

	private var manualTextField: StringifyTextField!

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()

		configureUI()
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		view.endEditing(true)
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
		default:
			break
		}

		decimalSwitcher.isOn = stringifyTextField.decimal

//		let width = UIScreen.main.bounds.size.width - 40
//		let yPosition = valueLabel.frame.maxY + 40
//
//		manualTextField = StringifyTextField(type: .amount)
//		manualTextField.frame = CGRect(x: 20, y: yPosition, width: width, height: 40)
//		manualTextField.borderStyle = .roundedRect
//		manualTextField.decimal = true
//		manualTextField.maxIntegerDigits = 6
//		view.addSubview(manualTextField)
	}

	// MARK: - Events
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
}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
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
	}

//	func didEndEditing(_ textField: StringifyTextField) {
//		print("did end editing \(textField.text!)")
//	}

	func didFilled(_ textField: StringifyTextField) {
		print("textField filled with text \(textField.text!)")
	}

	func didStartChanging(_ textField: StringifyTextField, in range: NSRange, with string: String) {
		print("textField start changing text: \(textField.text!) in with: \(string)")
	}
}

extension ViewController: StringifyTrailingActionDelegate {
	func didTapTrailing(_ sender: UIButton, textField: StringifyTextField) {
		print("tap")
	}
}

