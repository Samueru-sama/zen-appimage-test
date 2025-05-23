#!/bin/sh

set -eux

export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1

ZEN_URL=$(wget -q --retry-connrefused --tries=30 \
	https://api.github.com/repos/zen-browser/desktop/releases -O - \
	| sed 's/[()",{} ]/\n/g' | grep -oi "https.*linux-$ARCH.tar.xz$" | head -1)
export VERSION="$(echo "$ZEN_URL" | awk -F'-|/' 'NR==1 {print $(NF-2)}')"
echo "$VERSION" > ~/version

UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
SHARUN="https://github.com/VHSgunzo/sharun/releases/latest/download/sharun-$ARCH-aio"
URUNTIME="https://github.com/VHSgunzo/uruntime/releases/latest/download/uruntime-appimage-dwarfs-$ARCH"
SYSLIBS="/usr/lib/$ARCH-linux-gnu"

# Prepare AppDir
mkdir -p ./AppDir
cd ./AppDir

wget --retry-connrefused --tries=30 "$ZEN_URL"
tar xvf ./*.tar.*
rm -f ./*.tar.*
mv ./zen ./bin

# DEPLOY ALL LIBS
wget --retry-connrefused --tries=30 "$SHARUN" -O ./sharun-aio
chmod +x ./sharun-aio
./sharun-aio l -p -v -s -k            \
	./bin/zen*                          \
	./bin/glxtest                       \
	./bin/vaapitest                     \
	./bin/pingsender                    \
	./bin/lib*                          \
	"$SYSLIBS"/lib*GL*                  \
	"$SYSLIBS"/dri/*                    \
	"$SYSLIBS"/libpci.so*               \
	"$SYSLIBS"/libxcb-*                 \
	"$SYSLIBS"/libXcursor.so*           \
	"$SYSLIBS"/libXinerama*             \
	"$SYSLIBS"/libwayland*              \
	"$SYSLIBS"/libnss*                  \
	"$SYSLIBS"/libsoftokn3.so           \
	"$SYSLIBS"/libfreeblpriv3.so        \
	"$SYSLIBS"/libgtk*                  \
	"$SYSLIBS"/libgdk*                  \
	"$SYSLIBS"/libcanberra*             \
	"$SYSLIBS"/gdk-pixbuf-*/*/loaders/* \
	"$SYSLIBS"/libcloudproviders*       \
	"$SYSLIBS"/gconv/*                  \
	"$SYSLIBS"/pkcs11/*                 \
	"$SYSLIBS"/gvfs/*                   \
	"$SYSLIBS"/libcanberra*/*           \
	"$SYSLIBS"/gio/modules/*            \
	"$SYSLIBS"/pulseaudio/*             \
	"$SYSLIBS"/alsa-lib/*
rm -f ./sharun-aio

# Prepare sharun
echo "Preparing sharun..."
echo '#!/bin/sh
CURRENTDIR="$(dirname "$(readlink -f "$0")")"
export PATH="${CURRENTDIR}:${PATH}"
export MOZ_LEGACY_PROFILES=1          # Prevent per installation profiles
export MOZ_APP_LAUNCHER="${APPIMAGE}" # Allows setting as default browser
exec "${CURRENTDIR}/bin/zen" "$@"' > ./AppRun
chmod +x ./AppRun
./sharun -g

# DESKTOP AND ICON
cp -v ./bin/browser/chrome/icons/default/default128.png ./zen.png
cp -v ./bin/browser/chrome/icons/default/default128.png ./.DirIcon

echo '[Desktop Entry]
Version=1.0
Encoding=UTF-8
Name=Zen Browser
Exec=chrome %U
Terminal=false
Icon=zen
StartupWMClass=zen
Type=Application
Categories=Application;Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml_xml;' > ./zen.desktop

# MAKE APPIMAGE WITH URUNTIME
cd ..
wget -q "$URUNTIME" -O ./uruntime
chmod +x ./uruntime

# Keep the mount point (speeds up launch time)
sed -i 's|URUNTIME_MOUNT=[0-9]|URUNTIME_MOUNT=0|' ./uruntime

#Add udpate info to runtime
echo "Adding update information \"$UPINFO\" to runtime..."
sleep 0.5
./uruntime --appimage-addupdinfo "$UPINFO"

echo "Generating AppImage..."
./uruntime --appimage-mkdwarfs -f \
	--set-owner 0 --set-group 0 \
	--no-history --no-create-timestamp \
	--compression zstd:level=22 -S26 -B8 \
	--header uruntime \
	-i ./AppDir -o Zen-"$VERSION"-anylinux-"$ARCH".AppImage

echo "Generating zsync file..."
zsyncmake ./*.AppImage -u ./*.AppImage

echo "All Done!"
