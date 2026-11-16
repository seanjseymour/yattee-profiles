# Generate a disposable UI-test project; never edit the production Xcode project.
require 'xcodeproj'
require 'fileutils'
root, source = ARGV
FileUtils.mkdir_p(root)
project = Xcodeproj::Project.new(File.join(root, 'FocusRemote.xcodeproj'))
target = project.new_target(:ui_test_bundle, 'FocusRemote', :tvos, '18.0')
file = project.main_group.new_file(File.expand_path(source))
target.source_build_phase.add_file_reference(file)
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.seanjseymour.yatteeprofiles.focusuitests',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '3',
    'CODE_SIGNING_ALLOWED' => 'NO',
    'CODE_SIGNING_REQUIRED' => 'NO',
    'SDKROOT' => 'appletvos',
    'SUPPORTED_PLATFORMS' => 'appletvsimulator',
    'TVOS_DEPLOYMENT_TARGET' => '18.0'
  })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.test_action.build_configuration = 'Debug'
scheme.save_as(project.path, 'FocusRemote', true)
