// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_shown_name
import 'dart:ui_web' as ui;

void registerWebViewFactory(String viewType, String src) {
  ui.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = "microphone; camera; clipboard-read; clipboard-write";
      return iframe;
    },
  );
}
