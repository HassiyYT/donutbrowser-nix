{ lib
, appimageTools
, fetchurl
, bash
, coreutils
, findutils
}:

let
  pname = "donutbrowser";
  version = "0.13.9";

  # Updated automatically by scripts/update-version.sh
  assetName = "Donut_0.13.9_amd64.AppImage";

  src = fetchurl {
    url = "https://github.com/zhom/donutbrowser/releases/download/v${version}/${assetName}";
    hash = "sha256-zVChQfwN16uBeBMeadX9fg03j1hAmQXv8XOLDFv3VO0=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;

    postExtract = ''
      if [ -L "$out/Donut.desktop" ]; then
        rm "$out/Donut.desktop"
      fi
      if [ ! -e "$out/Donut.desktop" ]; then
        if [ -f "$out/usr/share/applications/Donut.desktop" ]; then
          ln -s usr/share/applications/Donut.desktop "$out/Donut.desktop"
        elif [ -f "$out/usr/share/applications/donutbrowser.desktop" ]; then
          ln -s usr/share/applications/donutbrowser.desktop "$out/Donut.desktop"
        fi
      fi

      if [ -L "$out/.DirIcon" ]; then
        rm "$out/.DirIcon"
      fi
      if [ ! -e "$out/.DirIcon" ]; then
        if [ -f "$out/Donut.png" ]; then
          ln -s Donut.png "$out/.DirIcon"
        elif [ -f "$out/usr/share/icons/hicolor/128x128/apps/donutbrowser.png" ]; then
          ln -s usr/share/icons/hicolor/128x128/apps/donutbrowser.png "$out/.DirIcon"
        fi
      fi
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  passthru = {
    inherit src;
  };

  extraInstallCommands = ''
    if [ -f ${appimageContents}/donutbrowser.desktop ]; then
      install -Dm444 ${appimageContents}/donutbrowser.desktop $out/share/applications/donutbrowser.desktop
      sed -i 's#^Exec=.*#Exec=donutbrowser %u#' $out/share/applications/donutbrowser.desktop
      sed -i 's#^Icon=.*#Icon=donutbrowser#' $out/share/applications/donutbrowser.desktop
    elif [ -f ${appimageContents}/usr/share/applications/donutbrowser.desktop ]; then
      install -Dm444 ${appimageContents}/usr/share/applications/donutbrowser.desktop $out/share/applications/donutbrowser.desktop
      sed -i 's#^Exec=.*#Exec=donutbrowser %u#' $out/share/applications/donutbrowser.desktop
      sed -i 's#^Icon=.*#Icon=donutbrowser#' $out/share/applications/donutbrowser.desktop
    fi

    if [ -f ${appimageContents}/donutbrowser.png ]; then
      install -Dm444 ${appimageContents}/donutbrowser.png $out/share/icons/hicolor/512x512/apps/donutbrowser.png
    elif [ -f ${appimageContents}/usr/share/icons/hicolor/512x512/apps/donutbrowser.png ]; then
      install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/donutbrowser.png $out/share/icons/hicolor/512x512/apps/donutbrowser.png
    fi

    # Prevent upstream cleanup bug from deleting downloaded browser binaries on startup.
    # Keep browser root dirs writable (for new downloads) but lock version dirs.
    mv $out/bin/donutbrowser $out/bin/.donutbrowser-wrapped
    cat > $out/bin/donutbrowser <<'EOF'
#!${bash}/bin/bash
set -euo pipefail

if [ "''${DONUTBROWSER_ALLOW_BINARY_CLEANUP:-0}" != "1" ]; then
  data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
  binaries_dir="$data_home/DonutBrowser/binaries"

  if [ -d "$binaries_dir" ]; then
    ${findutils}/bin/find "$binaries_dir" -mindepth 1 -maxdepth 1 -type d \
      -exec ${coreutils}/bin/chmod u+w '{}' + 2>/dev/null || true
    ${findutils}/bin/find "$binaries_dir" -mindepth 2 -maxdepth 2 -type d \
      -exec ${coreutils}/bin/chmod u-w '{}' + 2>/dev/null || true
  fi
fi

script_dir="$(${coreutils}/bin/dirname "$0")"
exec "$script_dir/.donutbrowser-wrapped" "$@"
EOF
    ${coreutils}/bin/chmod 0755 $out/bin/donutbrowser
  '';

  meta = with lib; {
    description = "Powerful anti-detect browser that puts you in control of your browsing experience";
    homepage = "https://github.com/zhom/donutbrowser";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "donutbrowser";
  };
}
