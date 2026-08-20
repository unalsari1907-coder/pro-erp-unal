{{flutter_js}}
{{flutter_build_config}}

// GitHub Pages ve tarayıcı önbelleğinde eski uygulama kodunun kalmasını önler.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath === 'main.dart.js') {
    build.mainJsPath = 'main.dart.js?v=20260815-2';
  }
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
