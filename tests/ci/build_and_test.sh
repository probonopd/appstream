#!/bin/sh
set -e

echo "C compiler: $CC"
echo "C++ compiler: $CXX"
set -x

#
# This script is supposed to run inside the AppStream Docker container
# on the CI system.
#

$CC --version

# configure AppStream build with all flags enabled
mkdir build && cd build
meson --prefix /usr \
      -Dmaintainer=false \
      -Ddocs=true \
      -Dqt=true \
      -Dapt-support=true \
      -Dvapi=true \
      ..

# Build, Test & Install
# (the number of Ninja jobs needs to be limited, so Travis doesn't kill us)
ninja -j4
ninja documentation
# ninja test -v # FIXME
DESTDIR=/tmp/install_root/ ninja install

# We need a desktop file
mkdir -p /tmp/install_root/usr/share/applications/
cat > /tmp/install_root/usr/share/applications/appstreamcli.desktop <<\EOF
[Desktop Entry]
Type=Application
Name=appstreamcli
Comment=Handle AppStream metadata and the AppStream index
Exec=appstreamcli
Icon=appstreamcli
Terminal=true
Categories=Development;
EOF

# We need an icon
wget -c "http://blog.tenstral.net/wp-content/uploads/2012/08/softwarecenter-work.png" -O /tmp/install_root/appstreamcli.png

# We do not want to bundle the Qt library and its dependencies
rm /tmp/install_root/usr/lib/x86_64-linux-gnu/libAppStreamQt* || true

# Make and upload a standalone AppImage
find /tmp/install_root/
wget -c -nv https://github.com/$(wget -q https://github.com/probonopd/go-appimage/releases -O - | grep "appimagetool-.*-x86_64.AppImage" | head -n 1 | cut -d '"' -f 2)
chmod +x ./appimagetool-*.AppImage
./appimagetool-*.AppImage deploy /tmp/install_root/usr/share/applications/appstreamcli.desktop --appimage-extract-and-run
find /tmp/appimage_extracted_* || true # For https://github.com/AppImage/AppImageKit/issues/1013
./appimagetool-*.AppImage /tmp/install_root --appimage-extract-and-run
find /tmp/appimage_extracted_* || true # For https://github.com/AppImage/AppImageKit/issues/1013

# Rebuild everything with Sanitizers enabled
# FIXME: Doesn't work properly with Clang at time, so we only run this test with GCC.
cd .. && rm -rf build && mkdir build && cd build

# FIXME: we can not build with sanitizers at the moment, because Meson/g-ir-scanner is buggy
# Add -Db_sanitize=address,undefined to try the full thing.
#meson -Dmaintainer=true \
#      -Dqt=true \
#      -Dapt-support=true \
#      -Dvapi=true \
#      -Db_sanitize=address \
#	..
#if [ "$CC" != "clang" ]; then ninja -j4 && ninja test -v; fi
