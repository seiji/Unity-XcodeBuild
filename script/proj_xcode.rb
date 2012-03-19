#!/usr/bin/env ruby 
require 'rubygems'
require 'xcodeproj'
require "find"
require "fileutils"

ADD_FRAMEWORKS = %w{
AddressBook
AVFoundation
GameKit
libxml2.dylib
MessageUI
MobileCoreServices
Security
StoreKit
CoreTelephony
}


module Xcodeproj
  class Project
    def get_group(name) 
      self.groups.each do |g|
      end
      self.groups.find { |g| (g.name == name or g.attributes['path'] == name) } || self.groups.new({ 'name' => name, 'path' => name })
    end

    def add_system_framework(fname)
      name, path = nil, nil;
      if (fname =~ /^lib/)
        name, path = fname, "usr/lib/#{fname}"
      else
        name, path = "#{fname}.framework", "System/Library/Frameworks/#{fname}.framework"
      end
      self.files.new({ 
                       'name' => name,
                       'path' => path,
                       'sourceTree' => 'SDKROOT',
                     })
    end
    def arrange_frameworks
      group = get_group('Frameworks')
      frameworks_build_phases_list = [] 
      self.targets.each do |target|
        target.frameworks_build_phases.each do |phase|
          frameworks_build_phases_list.push(phase)
        end
      end

      self.files.sort{|a,b| a.name <=> b.name }.each do |file|
        path = file.path
        if (path =~ /^System\/Library\/Frameworks/ or path =~ /^usr\/lib/)
          file.group = group
        end
      end
      ADD_FRAMEWORKS.each do |fname|
        if (group.files.find {|f|
              cname = (f.name =~ /framework$/) ? "#{fname}.framework" :  fname
              f.name == cname
            })
        else
          framework = add_system_framework(fname)
          framework.group = group
          frameworks_build_phases_list.each do |buildPhase|
            buildPhase.files << framework.buildFiles.new
          end
        end
      end
    end
    COMMON_BUILD_SETTINGS = {
      :common => {
        'HEADER_SEARCH_PATHS'        => ['${SDKROOT}/usr/include/libxml2'],
        'GCC_ENABLE_OBJC_EXCEPTIONS' => 'YES',
        'SKIP_INSTALL'               => 'NO'
      },
      :debug => {
        'OTHER_LDFLAGS' => [],
      },
      :release => {
        'OTHER_LDFLAGS' => ['-Wl,-S,-x'],
      },
    }
    def build_settings(scheme)
      COMMON_BUILD_SETTINGS[:common].merge(COMMON_BUILD_SETTINGS[scheme])
    end

    def arrange_targets()
      self.targets.each do |target|
        target.buildConfigurations .each do |conf|
          buildSettings = conf.buildSettings
          if (conf.name == 'Release')
            buildSettings.merge!(build_settings(:release))
          elsif (conf.name == 'Debug')
            buildSettings.merge!(build_settings(:debug))
          end
        end
      end
    end

    def self.arrange_project(path)
      xcodeproj_path = nil
      Dir.glob("#{path}/*.xcodeproj").each do |file|
        xcodeproj_path = file
      end
      return if !xcodeproj_path

      project = Xcodeproj::Project.new(xcodeproj_path)

      project.arrange_frameworks()
      project.arrange_targets()
      project.save_as(xcodeproj_path)      
      project
    end
  end
end

if $0 == __FILE__
  if ARGV[0].nil? then
    puts "usage: proj_xcode.rb <PROJECT_PATH>"
  else
    Xcodeproj::Project.arrange_project(ARGV[0])
  end
end






