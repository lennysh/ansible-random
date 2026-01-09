#!/usr/bin/env bash

# ==============================================================================
# Script Name: reconstruct_collection.sh
# Description: Reconstructs an Ansible galaxy.yml file from an existing
#              MANIFEST.json found in an unpacked collection tarball.
#              It then removes the old build artifacts (MANIFEST.json, FILES.json)
#              to prepare the directory for a clean rebuild.
# Author: Lenny Shirley
# Repository: https://github.com/lennysh/ansible-random
# Dependencies: jq, tar
# Usage: ./reconstruct_collection.sh <target_folder_or_tar.gz>
# ==============================================================================

set -e

# --- 1. Dependency Check ---
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it (e.g., 'apt install jq' or 'brew install jq')."
    exit 1
fi

if ! command -v tar &> /dev/null; then
    echo "Error: 'tar' is not installed. Please install it."
    exit 1
fi

# --- 2. Parameter Validation ---
if [ $# -ne 1 ]; then
    echo "Error: This script requires exactly one parameter (a target folder or tar.gz file)."
    echo "Usage: $0 <target_folder_or_tar.gz>"
    exit 1
fi

INPUT="$1"

# Get absolute paths for comparison
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_ABS="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"

# Check if input is a tar.gz file
if [[ "$INPUT" == *.tar.gz ]] && [ -f "$INPUT" ]; then
    echo "Detected tar.gz file. Extracting..."
    
    # Get the directory where the tar.gz file is located
    TAR_DIR="$(cd "$(dirname "$INPUT")" && pwd)"
    TAR_FILE="$(basename "$INPUT")"
    
    # Extract to a directory next to the tar.gz file (using the tar.gz name without extension)
    EXTRACT_BASE="${TAR_FILE%.tar.gz}"
    EXTRACT_DIR="$TAR_DIR/$EXTRACT_BASE"
    
    # Check if extraction directory already exists
    if [ -d "$EXTRACT_DIR" ]; then
        read -p "Warning: Directory '$EXTRACT_DIR' already exists. Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
        rm -rf "$EXTRACT_DIR"
    fi
    
    # Extract the tar.gz file
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$INPUT" -C "$EXTRACT_DIR"
    
    # Find the extracted directory (usually the first directory in the archive)
    EXTRACTED_DIR=$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        echo "Error: Could not find extracted directory in '$INPUT'."
        rm -rf "$EXTRACT_DIR"
        exit 1
    fi
    
    TARGET_DIR_ABS="$EXTRACTED_DIR"
    echo "Extracted to: $TARGET_DIR_ABS"
    
elif [ -d "$INPUT" ]; then
    # It's a directory
    TARGET_DIR_ABS="$(cd "$INPUT" && pwd)"
    
    # Check that the target directory is not the script's directory
    if [ "$TARGET_DIR_ABS" = "$SCRIPT_DIR" ]; then
        echo "Error: The target folder cannot be the script's directory."
        exit 1
    fi
    
    # Check that the directory contains MANIFEST.json
    if [ ! -f "$TARGET_DIR_ABS/MANIFEST.json" ]; then
        echo "Error: MANIFEST.json not found in '$TARGET_DIR_ABS'."
        echo "Please ensure the target folder contains an unpacked collection with MANIFEST.json."
        exit 1
    fi
    
else
    echo "Error: '$INPUT' is neither a valid directory nor a tar.gz file."
    exit 1
fi

# Change to the target directory
cd "$TARGET_DIR_ABS"

# --- 3. Sanity Checks ---
if [ ! -f "MANIFEST.json" ]; then
    echo "Error: MANIFEST.json not found in '$TARGET_DIR_ABS'."
    echo "Please ensure the target folder or extracted archive contains an unpacked collection with MANIFEST.json."
    exit 1
fi

if [ -f "galaxy.yml" ]; then
    read -p "Warning: A galaxy.yml file already exists. Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo "Reading metadata from MANIFEST.json in '$TARGET_DIR_ABS'..."

# --- 4. Generate galaxy.yml ---
# We use jq to parse the JSON and format it into valid YAML.
# The logic handles arrays (authors, tags, license) and null fields gracefully.

cat > galaxy.yml <<EOF
---
namespace: $(jq -r '.collection_info.namespace // empty' MANIFEST.json)
name: $(jq -r '.collection_info.name // empty' MANIFEST.json)
version: $(jq -r '.collection_info.version // empty' MANIFEST.json)
readme: $(jq -r '.collection_info.readme // empty' MANIFEST.json)
description: $(jq -r '.collection_info.description // empty' MANIFEST.json)

authors:
$(jq -r '.collection_info.authors[]? | "  - " + .' MANIFEST.json)

tags:
$(jq -r '.collection_info.tags[]? | "  - " + .' MANIFEST.json)

license:
$(jq -r '.collection_info.license[]? | "  - " + .' MANIFEST.json)

repository: $(jq -r '.collection_info.repository // empty' MANIFEST.json)
documentation: $(jq -r '.collection_info.documentation // empty' MANIFEST.json)
homepage: $(jq -r '.collection_info.homepage // empty' MANIFEST.json)
issues: $(jq -r '.collection_info.issues // empty' MANIFEST.json)

build_ignore: []

dependencies: $(jq -c '.collection_info.dependencies' MANIFEST.json)
EOF

echo "✔ galaxy.yml successfully reconstructed in '$TARGET_DIR_ABS'."

# --- 5. Cleanup Artifacts ---
# Remove the old manifest files. If these remain, 'ansible-galaxy collection build'
# might include them as static files or fail due to conflicts.

if [ -f "MANIFEST.json" ]; then
    rm MANIFEST.json
    echo "✔ Removed old MANIFEST.json"
fi

if [ -f "FILES.json" ]; then
    rm FILES.json
    echo "✔ Removed old FILES.json"
fi

echo ""
echo "========================================================="
echo "Success! The collection is ready for modification."
echo "Next steps:"
echo "  1. Switch to the target directory: 'cd $TARGET_DIR_ABS'"
echo "  2. Edit 'galaxy.yml' to make changes (if needed)."
echo "  3. Run 'ansible-galaxy collection build'"
echo "========================================================="

