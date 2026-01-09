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

# Check if input exists
if [ ! -e "$INPUT" ]; then
    echo "Error: '$INPUT' does not exist."
    exit 1
fi

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
    
    # MANIFEST.json will always be directly in EXTRACT_DIR after extraction
    TARGET_DIR_ABS="$EXTRACT_DIR"
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
        echo "Error: MANIFEST.json not found in directory '$TARGET_DIR_ABS'."
        echo "Please ensure the target folder contains an unpacked collection with MANIFEST.json."
        exit 1
    fi
    
else
    if [ -f "$INPUT" ]; then
        echo "Error: '$INPUT' is a file but not a tar.gz file."
        echo "This script only accepts tar.gz files or directories containing MANIFEST.json."
    else
        echo "Error: '$INPUT' is neither a valid directory nor a tar.gz file."
    fi
    exit 1
fi

# Change to the target directory
cd "$TARGET_DIR_ABS"

# --- 3. Sanity Checks ---
if [ ! -f "MANIFEST.json" ]; then
    echo "Error: MANIFEST.json not found in target directory '$TARGET_DIR_ABS'."
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
### REQUIRED
# The namespace of the collection. This can be a company/brand/organization or product namespace under which all
# content lives. May only contain alphanumeric lowercase characters and underscores. Namespaces cannot start with
# underscores or numbers and cannot contain consecutive underscores
namespace: $(jq -r '.collection_info.namespace // empty' MANIFEST.json)

# The name of the collection. Has the same character restrictions as 'namespace'
name: $(jq -r '.collection_info.name // empty' MANIFEST.json)

# The version of the collection. Must be compatible with semantic versioning
version: $(jq -r '.collection_info.version // empty' MANIFEST.json)

# The path to the Markdown (.md) readme file. This path is relative to the root of the collection
readme: $(jq -r '.collection_info.readme // empty' MANIFEST.json)

# A list of the collection's content authors. Can be just the name or in the format 'Full Name <email> (url)
# @nicks:irc/im.site#channel'
authors:
$(jq -r '.collection_info.authors[]? | "  - " + .' MANIFEST.json)

### OPTIONAL but strongly recommended
# A short summary description of the collection
description: $(jq -r '.collection_info.description // empty' MANIFEST.json)1

# Either a single license or a list of licenses for content inside of a collection. Ansible Galaxy currently only
# accepts L(SPDX,https://spdx.org/licenses/) licenses. This key is mutually exclusive with 'license_file'
license:
$(jq -r '.collection_info.license[]? | "  - " + .' MANIFEST.json)

# The path to the license file for the collection. This path is relative to the root of the collection. This key is
# mutually exclusive with 'license'
license_file: $(V=$(jq -r '.collection_info.license_file // ""' MANIFEST.json); [ -z "$V" ] && echo "''" || echo "$V")

# A list of tags you want to associate with the collection for indexing/searching. A tag name has the same character
# requirements as 'namespace' and 'name'
tags:
$(jq -r '.collection_info.tags[]? | "  - " + .' MANIFEST.json)

# Collections that this collection requires to be installed for it to be usable. The key of the dict is the
# collection label 'namespace.name'. The value is a version range
# L(specifiers,https://python-semanticversion.readthedocs.io/en/latest/#requirement-specification). Multiple version
# range specifiers can be set and are separated by ','
dependencies: $(jq -c '.collection_info.dependencies' MANIFEST.json)

# The URL of the originating SCM repository
repository: $(jq -r '.collection_info.repository // empty' MANIFEST.json)

# The URL to any online docs
documentation: $(jq -r '.collection_info.documentation // empty' MANIFEST.json)

# The URL to the homepage of the collection/project
homepage: $(jq -r '.collection_info.homepage // empty' MANIFEST.json)

# The URL to the collection issue tracker
issues: $(jq -r '.collection_info.issues // empty' MANIFEST.json)

# A list of file glob-like patterns used to filter any files or directories that should not be included in the build
# artifact. A pattern is matched from the relative path of the file or directory of the collection directory. This
# uses 'fnmatch' to match the files or directories. Some directories and files like 'galaxy.yml', '*.pyc', '*.retry',
# and '.git' are always filtered. Mutually exclusive with 'manifest'
build_ignore: []

# A dict controlling use of manifest directives used in building the collection artifact. The key 'directives' is a
# list of MANIFEST.in style
# L(directives,https://packaging.python.org/en/latest/guides/using-manifest-in/#manifest-in-commands). The key
# 'omit_default_directives' is a boolean that controls whether the default directives are used. Mutually exclusive
# with 'build_ignore'
# manifest: null
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

