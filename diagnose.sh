#!/bin/bash

# NitNab Diagnostic Script
echo "🔧 NitNab Diagnostic Tool"
echo "========================"
echo ""

DB_PATH=~/Library/Application\ Support/NitNab/nitnab.db
ICLOUD_PATH=~/Library/Mobile\ Documents/com~apple~CloudDocs/NitNab

# Check database
if [ -f "$DB_PATH" ]; then
    echo "✅ Database found"
    echo "📍 Path: $DB_PATH"
    echo ""
    
    echo "📊 DATABASE CONTENTS:"
    echo "==================="
    sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM transcriptions;" | while read count; do
        echo "Total entries: $count"
    done
    echo ""
    
    echo "Entries:"
    sqlite3 "$DB_PATH" "SELECT id, audio_filename, status, file_checksum, created_at FROM transcriptions ORDER BY created_at DESC;" | while IFS='|' read id filename status checksum created; do
        echo "  • $filename"
        echo "    Status: $status"
        echo "    Checksum: ${checksum:-none}"
        echo "    ID: $id"
        echo ""
    done
else
    echo "❌ Database not found at: $DB_PATH"
    echo ""
fi

# Check iCloud folders
if [ -d "$ICLOUD_PATH" ]; then
    echo "📁 ICLOUD FOLDERS:"
    echo "================="
    
    folder_count=$(find "$ICLOUD_PATH" -maxdepth 1 -type d ! -name "NitNab" | wc -l | tr -d ' ')
    echo "Total folders: $folder_count"
    echo ""
    
    find "$ICLOUD_PATH" -maxdepth 1 -type d ! -name "NitNab" | while read folder; do
        basename "$folder"
    done
    echo ""
else
    echo "❌ iCloud folder not found at: $ICLOUD_PATH"
    echo ""
fi

# Cleanup option
if [ "$1" == "--nuke" ]; then
    echo "🔥 NUCLEAR CLEANUP MODE"
    echo "======================"
    echo ""
    echo "⚠️  This will DELETE:"
    echo "   • All database entries"
    echo "   • All iCloud folders"
    echo "   • Cannot be undone!"
    echo ""
    read -p "Type 'YES' to confirm: " confirm
    
    if [ "$confirm" == "YES" ]; then
        echo ""
        echo "🔥 Nuking everything..."
        
        # Delete database
        if [ -f "$DB_PATH" ]; then
            rm "$DB_PATH"
            echo "✅ Deleted database"
        fi
        
        # Delete folders
        find "$ICLOUD_PATH" -maxdepth 1 -type d ! -name "NitNab" -exec rm -rf {} + 2>/dev/null
        echo "✅ Deleted all folders"
        
        echo ""
        echo "🎉 Everything nuked! App is now clean slate."
    else
        echo ""
        echo "❌ Cleanup cancelled"
    fi
fi

echo ""
echo "✅ Done!"
echo ""
echo "Usage:"
echo "  ./diagnose.sh          # Show diagnostics"
echo "  ./diagnose.sh --nuke   # Delete everything and start fresh"
