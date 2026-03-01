#!/usr/bin/env ruby
# Script to add new files to Xcode project

require 'xcodeproj'

project_path = File.expand_path('NitNab/NitNab.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Define files to add
files_to_add = [
  { path: 'Models/Memory.swift', group: 'Models' },
  { path: 'Services/MemoryService.swift', group: 'Services' },
  { path: 'Services/DuplicateDetectionService.swift', group: 'Services' },
  { path: 'Views/MemoriesSettingsView.swift', group: 'Views' },
  { path: 'Views/StandardView.swift', group: 'Views' },
  { path: 'Views/AdvancedView.swift', group: 'Views' },
  { path: 'Views/SearchBarView.swift', group: 'Views' },
  { path: 'Views/TagCloudView.swift', group: 'Views' },
  { path: 'Views/CompanyPickerSheet.swift', group: 'Views' }
]

# Find or create groups
def find_or_create_group(project, group_name)
  group = project.main_group.groups.find { |g| g.display_name == group_name }
  unless group
    puts "Creating group: #{group_name}"
    group = project.main_group.new_group(group_name, group_name)
  end
  group
end

# Add each file
files_to_add.each do |file_info|
  file_path = File.join(File.dirname(project_path), file_info[:path])
  
  if File.exist?(file_path)
    # Find the group
    group = find_or_create_group(project, file_info[:group])
    
    # Check if file already exists in project
    existing_file = group.files.find { |f| f.path == File.basename(file_info[:path]) }
    
    if existing_file
      puts "File already in project: #{file_info[:path]}"
    else
      # Add file reference
      file_ref = group.new_file(file_path)
      
      # Add to build phase
      target.add_file_references([file_ref])
      
      puts "Added: #{file_info[:path]}"
    end
  else
    puts "File not found: #{file_path}"
  end
end

# Save the project
project.save

puts "\n✅ Project updated successfully!"
puts "Now run: xcodebuild build -scheme NitNab"
