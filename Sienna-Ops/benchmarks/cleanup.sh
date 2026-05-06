#!/bin/bash
### remove generated files and directories if they exist

# Remove directories if they exist
if [ -d "RTS-store" ]; then
	echo "Removing RTS-store"
	rm -rf "RTS-store"
fi

if [ -d "RTS-plots" ]; then
	echo "Removing RTS-plots"
	rm -rf "RTS-plots"
fi

# # Remove project files if they exist
# if [ -f "Manifest.toml" ]; then
# 	echo "Removing Manifest.toml"
# 	rm -f "Manifest.toml"
# fi

# if [ -f "Project.toml" ]; then
# 	echo "Removing Project.toml"
# 	rm -f "Project.toml"
# fi

# # If TMP is set and exists, remove it
# if [ -n "$TMP" ] && [ -e "$TMP" ]; then
# 	echo "Removing TMP depot: $TMP"
# 	rm -rf "$TMP"
# fi



