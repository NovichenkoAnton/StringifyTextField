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
	@IBOutlet var decimalSwitcher: UISwitch!
	@IBOutlet var amountTextField: StringifyTextField! {
		didSet {
//            amountTextField.style = .line
            amountTextField.style = .border(cornerRadius: 10)
            amountTextField.textType = .none
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
            amountTextField.floatingPlaceholder = false
            amountTextField.errorDisplayDuration = 1.5
            amountTextField.errorColor = UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1.00)
            amountTextField.errorMessage = "Some error"
            amountTextField.errorLabelTopPadding = 10
            amountTextField.errorLabelFont = UIFont.systemFont(ofSize: 12)
            amountTextField.pattern = .own(pattern: "[A-Za-z0-9]")
		}
	}

	private lazy var manualTextField: BorderedStringifyTextField = {
		let manualTextField = BorderedStringifyTextField(type: .amount)
		manualTextField.stActionDelegate = self
        manualTextField.stDelegate = self
        manualTextField.activeBorderColor = UIColor.blue
        manualTextField.errorBorderColor = UIColor.red
        manualTextField.cornerRadius = 12
        manualTextField.borderWidth = 2
        manualTextField.backgroundColor = UIColor.white
		return manualTextField
	}()

    @IBOutlet var errorButton: UIButton!
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
		case .cvv:
			segmentedControl.selectedSegmentIndex = 4
		default:
			break
		}

		decimalSwitcher.isOn = stringifyTextField.decimal

//        let width = view.frame.width - 40
//        manualTextField.frame = CGRect(x: 20, y: errorButton.frame.origin.y, width: width, height: 40)

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
		} else if sender.selectedSegmentIndex == 4 {
			stringifyTextField.textType = .cvv
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
//        manualTextField.showError()
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

	func didEndEditing(_ textField: StringifyTextField) {
		print("did end editing \(textField.text!)")
	}

	func didFilled(_ textField: StringifyTextField) {
		print("textField filled with text \(textField.text!)")
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

extension ViewController: StringifyTrailingActionDelegate {
	func didTapTrailing(_ sender: UIButton, textField: StringifyTextField) {
		print("tap")
	}
}

