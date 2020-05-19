Pod::Spec.new do |spec|
  spec.name         = 'DDRouter'
  spec.version      = '0.4.1'
  spec.license      = { :type => 'ISC' }
  spec.homepage     = 'https://github.com/DeloitteDigitalAPAC/ddrouter'
  spec.authors      = { 'Deloitte Digital' => 'wrigney@deloitte.com.au' }
  spec.summary      = 'Deloitte Digital simple networking framework.'
  spec.source       = { :git => 'https://github.com/DeloitteDigitalAPAC/ddrouter', :tag => 'v0.4.1' }
  spec.source_files = 'DDRouter', 'DDRouter/**/*.swift'
  spec.framework    = 'RxSwift'
  spec.platform     = :ios, "11.0"
  spec.swift_version = '5'
  spec.dependency 'RxSwift', '~> 5.1'
  spec.static_framework = true
end
