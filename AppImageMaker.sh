#!/bin/bash

if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "appimagetool не найден, скачивание..."
    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

read -p "Введите название пакета: " PACKAGE_NAME

if ! pacman -Qi $PACKAGE_NAME &> /dev/null; then
    echo "Пакет $PACKAGE_NAME не установлен."
    read -p "Введите название пакета: " PACKAGE_NAME
fi

APPDIR_ROOT="$PACKAGE_NAME.AppDir"

if [ -d "$APPDIR_ROOT" ]; then
    rm -r "$APPDIR_ROOT"
fi

pacman -Ql $PACKAGE_NAME | while read -r package filepath; do
    if [[ "$filepath" != */ ]]; then
        dest_dir="$APPDIR_ROOT/$(dirname "$filepath" | sed "s|^/||")"
        mkdir -p "$dest_dir"

        cp "$filepath" "$dest_dir/"
    fi
done

if pacman -Qi qt6-base &> /dev/null; then
    pacman -Ql qt6-base | while read -r package filepath; do
        if [[ "$filepath" != */ ]]; then
            dest_dir="$APPDIR_ROOT/$(dirname "$filepath" | sed "s|^/||")"
            mkdir -p "$dest_dir"

            cp "$filepath" "$dest_dir/"
        fi
    done
fi

echo "Копирование файлов для $PACKAGE_NAME завершено."




executable="/usr/bin/$PACKAGE_NAME"

dest_lib_dir="$APPDIR_ROOT/usr/lib"

mkdir -p "$dest_lib_dir"

ldd "$executable" | grep '=> /' | awk '{print $3}' | while read lib; do
    cp -v "$lib" "$dest_lib_dir"
done


echo "Копирование зависимостей для $PACKAGE_NAME завершено."


dest_qt_dir="$APPDIR_ROOT/usr/plugins/platforms"
mkdir -p "$dest_qt_dir"
cp "/usr/lib/qt/plugins/platforms/libqxcb.so" "$dest_qt_dir"


cat > "$APPDIR_ROOT/AppRun" <<EOF
#!/bin/bash

# Определяем путь к корню AppDir
APPDIR="\$(dirname "\$(readlink -f "\$0")")"

# Устанавливаем необходимые переменные окружения для поиска библиотек и ресурсов
export LD_LIBRARY_PATH="\${APPDIR}/usr/lib:\${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="\${APPDIR}/usr/share:\${XDG_DATA_DIRS}"
export QT_PLUGIN_PATH="\${APPDIR}/usr/plugins"
export ELECTRON_APP_PATH="\${APPDIR}/usr/lib/obsidian"
export QT_QPA_PLATFORM=xcb

# Переходим в каталог bin внутри AppDir
cd "\${APPDIR}/usr/bin"

# Запускаем приложение, заданное в переменной PACKAGE_NAME, передавая все аргументы командной строки
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
    echo "Файл $FILE_TO_COPY скопирован в $APPDIR_ROOT"
else
    echo "Файлы с заданными расширениями не найдены."
fi
if [ -z "$FILE_TO_COPY" ]; then
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

    DEFAULT_ICON_PATH="$SCRIPT_DIR/AppImage.png"

    if [ -f "$DEFAULT_ICON_PATH" ]; then
        FILE_TO_COPY="$DEFAULT_ICON_PATH"
        echo "Используется иконка по умолчанию: $DEFAULT_ICON_PATH"
    else
        echo "Иконка по умолчанию не найдена в $SCRIPT_DIR"
        exit 1
    fi
fi

if [ -n "$FILE_TO_COPY" ]; then
    cp "$FILE_TO_COPY" "$APPDIR_ROOT/$ICON_VALUE.png"
    echo "Иконка $FILE_TO_COPY скопирована и переименована в $APPDIR_ROOT/$ICON_VALUE.png"
else
    echo "Файл иконки не был скопирован."
fi

PNG_FILE=$(find "$APPDIR_ROOT" -maxdepth 1 -type f -name "*.png" -print -quit)

rm -r "$APPDIR_ROOT/usr/share/metainfo"
mv "$PNG_FILE" "$APPDIR_ROOT/$ICON_VALUE.png"

ARCH=x86_64
./appimagetool-x86_64.AppImage $APPDIR_ROOT
echo "Done!"
