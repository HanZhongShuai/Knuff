platform :macos, '10.13'
use_frameworks!

target "Knuff" do
  pod 'Mantle'
  pod 'KVOController'
  pod 'pop'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.13'
    end
  end
end
