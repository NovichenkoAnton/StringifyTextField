Pod::Spec.new do |spec|
  spec.name             = 'StringifyTextField'
  spec.version          = '1.0.16'
  spec.summary          = 'Custom UITextField is based on Stringify framework functionality.'
  spec.homepage         = "https://github.com/NovichenkoAnton/StringifyTextField"

  spec.license          = {:type => 'MIT', :file => 'LICENSE'}
  spec.author           = { "Anton Novichenko" => "novichenko.anton@gmail.com" }

  spec.platform         = :ios
  spec.ios.deployment_target = '10.0'
  
  spec.swift_version    = '5.0'
  spec.source           = { :git => "https://github.com/NovichenkoAnton/StringifyTextField.git", :tag => "#{spec.version}" }
  spec.source_files     = "Sources/*.swift"
  spec.requires_arc     = true
  
  spec.dependency 'Stringify', '1.0.19'
end
