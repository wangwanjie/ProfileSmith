platform :osx, '11.0'

project 'ProfileSmith.xcodeproj'

install! 'cocoapods', :warn_for_unused_master_specs_repo => false

inhibit_all_warnings!

target 'ProfileSmith' do
  use_frameworks! :linkage => :static

  # pod 'ViewScopeServer', :path => '/Users/VanJay/Documents/Work/Private/ViewScope'
  pod 'ViewScopeServer', :git => 'https://github.com/wangwanjie/ViewScope.git', :branch => 'main', :configurations => ['Debug']

  target 'ProfileSmithTests' do
    inherit! :search_paths
  end

  target 'ProfileSmithUITests' do
    inherit! :search_paths
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'

      next unless target.name == 'Pods-ProfileSmithUITests'

      other_ldflags = Array(config.build_settings['OTHER_LDFLAGS'])
      unless other_ldflags.include?('-framework') && other_ldflags.each_cons(2).any? { |flag, value| flag == '-framework' && value == 'ViewScopeServer' }
        other_ldflags += ['-framework', 'ViewScopeServer']
      end
      config.build_settings['OTHER_LDFLAGS'] = other_ldflags
    end
  end
end
