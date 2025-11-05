#!/bin/bash
# Make this script executable with: chmod +x rename.sh

# iOS Template Rename Script
# This script renames the iOS template project to your custom app name and bundle identifier.

# Check if the script has the necessary arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \"New App Name\" com.company.newappname"
    echo "Example: $0 \"My Awesome App\" com.mycompany.awesomeapp"
    exit 1
fi

# Define variables
NEW_APP_NAME=$1
NEW_BUNDLE_ID=$2
ORIGINAL_APP_NAME="Template App"
ORIGINAL_BUNDLE_ID="com.yourcompany.templateapp"
ORIGINAL_APP_NAME_NO_SPACES="Template_App"
NEW_APP_NAME_NO_SPACES=$(echo "$NEW_APP_NAME" | tr ' ' '_')

# Confirmation
echo "This script will rename the iOS template project to:"
echo "App Name: $NEW_APP_NAME"
echo "Bundle Identifier: $NEW_BUNDLE_ID"
echo ""
echo "Please ensure you have a backup of your project before proceeding."
echo ""
read -p "Do you want to continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Function to rename files
rename_files() {
    find . -name "*$ORIGINAL_APP_NAME*" -not -path "*/\.*" -not -path "*/Pods/*" | while read FILE; do
        NEW_FILE=$(echo "$FILE" | sed "s/$ORIGINAL_APP_NAME/$NEW_APP_NAME/g")
        mkdir -p "$(dirname "$NEW_FILE")"
        if [ "$FILE" != "$NEW_FILE" ]; then
            echo "Moving $FILE to $NEW_FILE"
            mv "$FILE" "$NEW_FILE"
        fi
    done
    
    find . -name "*$ORIGINAL_APP_NAME_NO_SPACES*" -not -path "*/\.*" -not -path "*/Pods/*" | while read FILE; do
        NEW_FILE=$(echo "$FILE" | sed "s/$ORIGINAL_APP_NAME_NO_SPACES/$NEW_APP_NAME_NO_SPACES/g")
        mkdir -p "$(dirname "$NEW_FILE")"
        if [ "$FILE" != "$NEW_FILE" ]; then
            echo "Moving $FILE to $NEW_FILE"
            mv "$FILE" "$NEW_FILE"
        fi
    done
}

# Function to replace content in files
replace_content() {
    echo "Replacing content in files..."
    
    # Replace in all files (excluding git, Pods, and invisible files)
    find . -type f -not -path "*/\.*" -not -path "*/Pods/*" -not -path "*/rename.sh" -not -name "*.png" -not -name "*.jpg" -not -name "*.pdf" | while read FILE; do
        if [ -f "$FILE" ]; then
            sed -i '' "s/$ORIGINAL_APP_NAME/$NEW_APP_NAME/g" "$FILE"
            sed -i '' "s/$ORIGINAL_APP_NAME_NO_SPACES/$NEW_APP_NAME_NO_SPACES/g" "$FILE"
            sed -i '' "s/$ORIGINAL_BUNDLE_ID/$NEW_BUNDLE_ID/g" "$FILE"
        fi
    done
    
    # Special handling for Info.plist files
    find . -name "Info.plist" -not -path "*/Pods/*" | while read FILE; do
        if [ -f "$FILE" ]; then
            echo "Updating bundle identifier in $FILE"
            plutil -replace CFBundleIdentifier -string "$NEW_BUNDLE_ID" "$FILE"
        fi
    done
}

# Function to update Xcode project settings
update_xcode_project() {
    echo "Updating Xcode project settings..."
    
    # Rename xcodeproj directory
    if [ -d "$ORIGINAL_APP_NAME.xcodeproj" ]; then
        echo "Renaming $ORIGINAL_APP_NAME.xcodeproj to $NEW_APP_NAME.xcodeproj"
        mv "$ORIGINAL_APP_NAME.xcodeproj" "$NEW_APP_NAME.xcodeproj"
    fi
    
    # Rename xcworkspace directory
    if [ -d "$ORIGINAL_APP_NAME.xcworkspace" ]; then
        echo "Renaming $ORIGINAL_APP_NAME.xcworkspace to $NEW_APP_NAME.xcworkspace"
        mv "$ORIGINAL_APP_NAME.xcworkspace" "$NEW_APP_NAME.xcworkspace"
    fi
    
    # Update Fastfile
    if [ -f "fastlane/Fastfile" ]; then
        echo "Updating fastlane/Fastfile"
        sed -i '' "s/$ORIGINAL_APP_NAME/$NEW_APP_NAME/g" "fastlane/Fastfile"
    fi
    
    # Update GitHub workflows
    find .github/workflows -type f -name "*.yml" | while read FILE; do
        if [ -f "$FILE" ]; then
            echo "Updating GitHub workflow: $FILE"
            sed -i '' "s/$ORIGINAL_APP_NAME/$NEW_APP_NAME/g" "$FILE"
        fi
    done
}

# Main execution
echo "Starting project rename process..."
echo ""

echo "Step 1: Renaming files..."
rename_files
echo "Files renamed."
echo ""

echo "Step 2: Replacing content in files..."
replace_content
echo "Content replaced."
echo ""

echo "Step 3: Updating Xcode project settings..."
update_xcode_project
echo "Xcode project settings updated."
echo ""

echo "Rename process completed successfully!"
echo ""
echo "Please open $NEW_APP_NAME.xcodeproj or $NEW_APP_NAME.xcworkspace to verify the changes."
echo "If you encounter any issues, please report them on the GitHub repository."
echo ""
echo "Happy coding! 🚀"

exit 0
