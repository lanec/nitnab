#!/bin/bash

# Create a proper Xcode project for NitNab using xcodegen or manual setup

cd "$(dirname "$0")"

# Create project.yml for xcodegen
cat > project.yml << 'EOF'
name: NitNab
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    macOS: "26.0"
targets:
  NitNab:
    type: application
    platform: macOS
    sources:
      - path: .
        excludes:
          - "*.xcodeproj"
          - "*.xcworkspace"
          - "DerivedData"
          - "create_project.sh"
          - "project.yml"
    settings:
      base:
        PRODUCT_NAME: NitNab
        PRODUCT_BUNDLE_IDENTIFIER: com.example.nitnab
        INFOPLIST_FILE: Info.plist
        CODE_SIGN_ENTITLEMENTS: NitNab.entitlements
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ""
        MACOSX_DEPLOYMENT_TARGET: "26.0"
        SWIFT_VERSION: "6.0"
        ENABLE_HARDENED_RUNTIME: YES
        COMBINE_HIDPI_IMAGES: YES
    scheme:
      testTargets: []
      gatherCoverageData: false
EOF

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "Using xcodegen to create project..."
    xcodegen generate
else
    echo "xcodegen not found. Please install it with: brew install xcodegen"
    echo "Or create the project manually in Xcode."
    exit 1
fi

echo "Project created successfully!"
