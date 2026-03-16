#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project_dir = File.join(root, 'ProfileSmithQuickLookExtensions')
project_path = File.join(project_dir, 'ProfileSmithQuickLookExtensions.xcodeproj')

FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2630'
project.root_object.attributes['LastUpgradeCheck'] = '2630'

extensions_group = project.main_group
shared_group = extensions_group.new_group('Shared', 'Shared')
preview_group = extensions_group.new_group('Preview', 'Preview')
thumbnail_group = extensions_group.new_group('Thumbnail', 'Thumbnail')

preview_target = project.new_target(:app_extension, 'ProfileSmithQuickLookPreview', :osx, '10.15', project.products_group, :swift)
thumbnail_target = project.new_target(:app_extension, 'ProfileSmithQuickLookThumbnail', :osx, '10.15', project.products_group, :swift)

[preview_target, thumbnail_target].each do |target|
  target.add_system_framework('Quartz')
end
thumbnail_target.add_system_framework('QuickLookThumbnailing')

project.root_object.attributes['TargetAttributes'] = {
  preview_target.uuid => { 'CreatedOnToolsVersion' => '26.3' },
  thumbnail_target.uuid => { 'CreatedOnToolsVersion' => '26.3' },
}

preview_sources = [
  shared_group.new_file('QuickLookInspection.swift'),
  shared_group.new_file('QuickLookInspector.swift'),
  preview_group.new_file('PreviewProvider.swift'),
]

thumbnail_sources = [
  shared_group.files.find { |file| file.path == 'QuickLookInspection.swift' } || shared_group.new_file('QuickLookInspection.swift'),
  shared_group.files.find { |file| file.path == 'QuickLookInspector.swift' } || shared_group.new_file('QuickLookInspector.swift'),
  thumbnail_group.new_file('ThumbnailProvider.swift'),
]

preview_target.add_file_references(preview_sources)
thumbnail_target.add_file_references(thumbnail_sources)

preview_info_plist = preview_group.new_file('Info.plist')
thumbnail_info_plist = thumbnail_group.new_file('Info.plist')

[
  [
    preview_target,
    'Preview/Info.plist',
    'Preview/ProfileSmithQuickLookPreview.entitlements',
    'cn.vanjay.ProfileSmith.QuickLookPreview',
    '10.15',
  ],
  [
    thumbnail_target,
    'Thumbnail/Info.plist',
    'Thumbnail/ProfileSmithQuickLookThumbnail.entitlements',
    'cn.vanjay.ProfileSmith.QuickLookThumbnail',
    '10.15',
  ],
].each do |target, info_plist, entitlements_path, bundle_identifier, deployment_target|
  target.build_configurations.each do |config|
    config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
    config.build_settings['COMBINE_HIDPI_IMAGES'] = 'YES'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
    config.build_settings['DEVELOPMENT_TEAM'] = 'X6B6C6U6QV'
    config.build_settings['ENABLE_APP_SANDBOX'] = 'YES'
    config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
    config.build_settings['ENABLE_USER_SELECTED_FILES'] = 'readonly'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    config.build_settings['INFOPLIST_FILE'] = info_plist
    config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = deployment_target
    config.build_settings['MARKETING_VERSION'] = '1.0'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_identifier
    config.build_settings['PRODUCT_NAME'] = target.name
    config.build_settings['SDKROOT'] = 'macosx'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
    config.build_settings['SWIFT_VERSION'] = '5.0'
  end
end

project.save
