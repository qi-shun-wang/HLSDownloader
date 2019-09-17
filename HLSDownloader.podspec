#
# Be sure to run `pod lib lint HLSDownloader.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HLSDownloader'
  s.version          = '0.5.0'
  s.swift_version = '5.0'
  s.summary          = 'Download Crypted HLS with server key and play video as local playing in iOS device.'
# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  
"Download Crypted HLS with server key and play video as local playing in iOS device."

                       DESC

  s.homepage         = 'https://github.com/qi-shun-wang/HLSDownloader'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Shun Wang' => 'qi.shun.wang@icloud.com' }
  s.source           = { :git => 'https://github.com/qi-shun-wang/HLSDownloader.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'HLSDownloader/Classes/**/*'
  
  # s.resource_bundles = {
  #   'HLSDownloader' => ['HLSDownloader/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'AVKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
