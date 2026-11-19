# sis_registrar_app

The Registrar's web app for the DBTC-Cebu student information system.

## Running it

```sh
flutter run -d chrome --web-port=5173
```

The API it talks to is set in `lib/config/api_config.dart`.

`--web-port` is worth keeping. The server allows any `localhost` / `127.0.0.1`
port (`Cors:AllowLoopback`), but a pinned port also matches the origins listed
in the API's `appsettings.json`, so it keeps working if loopback is ever turned
off for a real deployment.

## Building a release

```sh
flutter clean && flutter pub get && flutter build web --release
```

**Use `flutter clean` for any build you hand to someone else.** Flutter caches a
generated `web_plugin_registrant.dart` under `.dart_tool/flutter_build/`, and that
cache can go stale and leave a plugin unregistered. When that happened to
`printing`, the app built and ran normally but every Print button failed at the
moment it was pressed:

```
MissingPluginException: No implementation found for method printPdf
on channel net.nfet.printing
```

Nothing in `flutter analyze` or `flutter test` catches this, because the widget
tests replace `printPdf` with a fake. After a release build, check that the
plugin is registered:

```sh
grep -r "PrintingPlugin.registerWith" .dart_tool/flutter_build/*/web_plugin_registrant.dart
```

If testers already loaded a broken build, the service worker will keep serving it.
They need a hard reload (Shift-Reload) or an empty-cache reload to pick up the fix.
