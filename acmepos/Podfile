platform :ios, '10.0'
inhibit_all_warnings!
use_frameworks!

source 'https://github.com/CocoaPods/Specs.git'

def import_pods
    pod 'SPIClient-iOS'
    pod 'PMAlertController',  :git => 'https://github.com/mokten/PMAlertController.git', :branch => 'develop'  
end

target 'AcmePos' do
    import_pods
end

target :'AcmePosTests' do
    inherit! :search_paths
    import_pods
end
