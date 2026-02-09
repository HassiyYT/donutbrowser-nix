{ lib
, appimageTools
, fetchurl
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
