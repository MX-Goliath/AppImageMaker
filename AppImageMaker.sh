#!/bin/bash

if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "appimagetool not found, downloading..."
    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

read -p "Enter a package name:" PACKAGE_NAME

if command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
elif command -v apt &> /dev/null; then
    PKG_MANAGER="apt"
else
    echo "Neither pacman nor apt is available."
    exit 1
fi

if [ "$PKG_MANAGER" = "pacman" ]; then
    if ! pacman -Qi $PACKAGE_NAME &> /dev/null; then
        echo "Package $PACKAGE_NAME not installed."
        exit 1
    fi
elif [ "$PKG_MANAGER" = "apt" ]; then
    if ! dpkg -l $PACKAGE_NAME &> /dev/null; then
        echo "Package $PACKAGE_NAME not installed."
        exit 1
    fi
fi

APPDIR_ROOT="$PACKAGE_NAME.AppDir"

if [ -d "$APPDIR_ROOT" ]; then
    rm -r "$APPDIR_ROOT"
fi

if [ "$PKG_MANAGER" = "pacman" ]; then
    pacman -Ql $PACKAGE_NAME | while read -r package filepath; do
        if [[ "$filepath" != */ ]]; then
            dest_dir="$APPDIR_ROOT/$(dirname "$filepath" | sed "s|^/||")"
            mkdir -p "$dest_dir"

            cp "$filepath" "$dest_dir/"
        fi
    done
elif [ "$PKG_MANAGER" = "apt" ]; then
    dpkg -L $PACKAGE_NAME | while read filepath; do
        if [[ -f "$filepath" && "$filepath" != */ ]]; then
            dest_dir="$APPDIR_ROOT/$(dirname "$filepath" | sed "s|^/||")"
            mkdir -p "$dest_dir"

            cp "$filepath" "$dest_dir/"
        fi
    done
fi

echo "Copying of files for $PACKAGE_NAME is complete."




executable="/usr/bin/$PACKAGE_NAME"

dest_lib_dir="$APPDIR_ROOT/usr/lib"

mkdir -p "$dest_lib_dir"

ldd "$executable" | grep '=> /' | awk '{print $3}' | while read lib; do
    cp -v "$lib" "$dest_lib_dir"
done


echo "Dependency copying for $PACKAGE_NAME is complete."


dest_qt_dir="$APPDIR_ROOT/usr/plugins/platforms"
mkdir -p "$dest_qt_dir"
cp "/usr/lib/qt/plugins/platforms/libqxcb.so" "$dest_qt_dir"


cat > "$APPDIR_ROOT/AppRun" <<EOF
#!/bin/bash

APPDIR="\$(dirname "\$(readlink -f "\$0")")"

export LD_LIBRARY_PATH="\${APPDIR}/usr/lib:\${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="\${APPDIR}/usr/share:\${XDG_DATA_DIRS}"
export QT_PLUGIN_PATH="\${APPDIR}/usr/plugins"
export ELECTRON_APP_PATH="\${APPDIR}/usr/lib/obsidian"
export QT_QPA_PLATFORM=xcb

cd "\${APPDIR}/usr/bin"

./${PACKAGE_NAME} "\$@"
EOF

chmod +x "$APPDIR_ROOT/AppRun"

cp "$APPDIR_ROOT/usr/share/applications/"* "$APPDIR_ROOT/"

DESKTOP_FILE=$(find $APPDIR_ROOT -maxdepth 1 -type f -name "*.desktop" | head -n 1)

ICON_VALUE=$(grep '^Icon=' "$DESKTOP_FILE" | cut -d'=' -f2)
echo $ICON_VALUE



FOUND_FILES=$(find $APPDIR_ROOT/usr/share -type f \( -name "*.png" -o -name "*.svg" -o -name "*.ico" \) ! -path "*/applications/*")
FILE_TO_COPY=$(echo "$FOUND_FILES" | head -n 1)

if [ -n "$FILE_TO_COPY" ]; then
    cp "$FILE_TO_COPY" "$APPDIR_ROOT/"
    echo "File $FILE_TO_COPY copied to the $APPDIR_ROOT"
else
    echo "No files with the given extensions were found."
fi
if [ -z "$FILE_TO_COPY" ]; then
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

    DEFAULT_ICON_PATH="$SCRIPT_DIR/AppImage.png"

    if [ -f "$DEFAULT_ICON_PATH" ]; then
        FILE_TO_COPY="$DEFAULT_ICON_PATH"
        echo "The default icon is used: $DEFAULT_ICON_PATH"
    else
        echo "Default icon not found in $SCRIPT_DIR"
        exit 1
    fi
fi

if [ -n "$FILE_TO_COPY" ]; then
    cp "$FILE_TO_COPY" "$APPDIR_ROOT/$ICON_VALUE.png"
    echo "Icon $FILE_TO_COPY copied and renamed to $APPDIR_ROOT/$ICON_VALUE.png"
else
    echo "The icon file has not been copied."
fi

PNG_FILE=$(find "$APPDIR_ROOT" -maxdepth 1 -type f -name "*.png" -print -quit)

rm -r "$APPDIR_ROOT/usr/share/metainfo"
mv "$PNG_FILE" "$APPDIR_ROOT/$ICON_VALUE.png"

ARCH=x86_64
./appimagetool-x86_64.AppImage $APPDIR_ROOT
echo "Done!"
