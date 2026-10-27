import 'package:flutter/widgets.dart';

import 'web_glue_stub.dart' if (dart.library.js_interop) 'web_glue_web.dart' as platform;

/// The page's own edges (status bar, home indicator) as the browser reports them.
EdgeInsets browserSafeArea() => platform.safeArea();

/// Fades out the loading screen of web/index.html.
void hideSplash() => platform.hideSplash();

/// Hands a text file to the share sheet, or downloads it.
void saveFile(String name, String text) => platform.saveFile(name, text);

/// Reloads onto a waiting service worker.
void applyUpdate() => platform.applyUpdate();
