class AppConfig {
  AppConfig._();

  static const String appName = 'ÜNAL YEDEK PARÇA ERP';
  static const String version = '2.5.31';
  static const String build = '20260821-release';

  // Üretimde --dart-define ile değiştirilebilir. Varsayılan değerler mevcut
  // çalışan Supabase projesini korur; service-role anahtarı uygulamada tutulmaz.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mxbsidoxqmdfmfiaaqvq.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_XTvv3ubYXgNxrJfxvWzBwQ_rIzw8RU6',
  );
}
