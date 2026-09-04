# StringifyTextField
Custom `UITextField` based on `Extendy` framework functionality.

[![Version](https://img.shields.io/cocoapods/v/StringifyTextField)](https://cocoapods.org/pods/StringifyTextField)
[![License](https://img.shields.io/cocoapods/l/StringifyTextField)](https://raw.githubusercontent.com/NovichenkoAnton/StringifyTextField/master/LICENSE)
[![Platform](https://img.shields.io/cocoapods/p/StringifyTextField)](https://cocoapods.org/pods/StringifyTextField)

## Requirements

- iOS 12.0+

## Installation

### CocoaPods

StringifyTextField is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'StringifyTextField', '~> 1.3'
```

## Usage

```swift
import StringifyTextField

// Connect IBOutlet
@IBOutlet var stringifyTextField: StringifyTextField!

// Create programmatically
let manualTextField = StringifyTextField(type: .amount)
manualTextField.frame = CGRect(x: 20, y: 100, width: 200, height: 40)
```

`StringifyTextField` is a text field that can format an entered string with 6 available formats.

Available formats:
```swift
public enum TextType: UInt {
  case amount = 0
  case creditCard = 1
  case IBAN = 2
  case expDate = 3
  case cvv = 4
  case none = 5
}
```

### Amount format

You can specify a currency mark for `.amount` text type.

![currency mark](https://user-images.githubusercontent.com/8337067/77302043-bc505e80-6d01-11ea-95c0-1e3af86a8cc0.gif)

Set up maximum integer digits (if your amount contains integer and fraction parts).

```swift
stringifyTextField.maxIntegerDigits = 6
```

If your amount doesn't contain a fraction part, you can disable `decimal` through Interface Builder or programmatically.

```swift
stringifyTextField.decimal = false
```

### Credit card format

![credit card format](https://user-images.githubusercontent.com/8337067/77302097-d7bb6980-6d01-11ea-87ef-6c64f2f75abe.gif)

### Exp date format

![exp date format](https://user-images.githubusercontent.com/8337067/77651967-9a174480-6f7e-11ea-947c-de74b8a40804.gif)

You can specify a date format to get the required "clean" value.

```swift
stringifyTextField.dateFormat = "MM.yyyy"
```

### Plain value

You can get the plain value from `StringifyTextField`. For example, for `.expDate` format it will be the value with the specified date format applied.

```swift
let expDate = stringifyTextField.plainValue
```

### Styles & floating placeholder

`StringifyTextField` supports three different styles:

```swift
public enum Style {
    case line
    case border(cornerRadius: CGFloat = 0)
    case native(borderStyle: UITextField.BorderStyle)
}
```

You can display a bottom line in `StringifyTextField` with `.line` style:

```swift
stringifyTextField.style = .line
stringifyTextField.lineColorDefault = UIColor.black
stringifyTextField.lineColorActive = UIColor.blue
```

or use bordered style:

```swift
stringifyTextField.style = .border(cornerRadius: 8)
stringifyTextField.borderColorDefault = UIColor.lightGray
stringifyTextField.borderColorActive = UIColor.blue
```

and enable a floating placeholder:

```swift
stringifyTextField.floatingPlaceholder = true
stringifyTextField.floatingPlaceholderColor = UIColor.black
stringifyTextField.floatingPlaceholderActiveColor = UIColor.blue
```

![bottom line and floating label](https://user-images.githubusercontent.com/8337067/78424011-3faf6f80-7673-11ea-993d-3c449fa4420c.gif)

### Error handling

Display an error state with a temporary highlight:

```swift
// Show error for default duration (1 second)
stringifyTextField.showError()

// Show error for custom duration
stringifyTextField.showError(for: 5.0)

// Hide error manually
stringifyTextField.hideError()
```

## Demo
You can see other features in the example project.

## License

StringifyTextField is available under the MIT license. See the LICENSE file for more info.
