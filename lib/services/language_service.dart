import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_name': 'Browser App',
      'home': 'Home',
      'news': 'News',
      'search': 'Search',
      'bookmarks': 'Bookmarks',
      'settings': 'Settings',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'sign_out': 'Sign Out',
      'admin_panel': 'Admin Panel',
      'welcome_back': 'Welcome Back!',
      'create_account': 'Create Account',
      'email': 'Email',
      'password': 'Password',
      'google_signin': 'Continue with Google',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'notifications': 'Notifications',
      'privacy_security': 'Privacy & Security',
      'clear_data': 'Clear Data',
      'about': 'About',
      'help_support': 'Help & Support',
      'desktop_mode': 'Desktop Mode',
      'new_tab': 'New Tab',
      'history': 'History',
      'clear_history': 'Clear History',
      'translate_page': 'Translate Page',
      'voice_search': 'Voice Search',
    },
    'es': {
      'app_name': 'Aplicación del Navegador',
      'home': 'Inicio',
      'news': 'Noticias',
      'search': 'Buscar',
      'bookmarks': 'Marcadores',
      'settings': 'Configuración',
      'sign_in': 'Iniciar Sesión',
      'sign_up': 'Registrarse',
      'sign_out': 'Cerrar Sesión',
      'admin_panel': 'Panel de Administrador',
      'welcome_back': '¡Bienvenido de nuevo!',
      'create_account': 'Crear Cuenta',
      'email': 'Correo Electrónico',
      'password': 'Contraseña',
      'google_signin': 'Continuar con Google',
      'language': 'Idioma',
      'dark_mode': 'Modo Oscuro',
      'notifications': 'Notificaciones',
      'privacy_security': 'Privacidad y Seguridad',
      'clear_data': 'Borrar Datos',
      'about': 'Acerca de',
      'help_support': 'Ayuda y Soporte',
      'desktop_mode': 'Modo Escritorio',
      'new_tab': 'Nueva Pestaña',
      'history': 'Historial',
      'clear_history': 'Borrar Historial',
      'translate_page': 'Traducir Página',
      'voice_search': 'Búsqueda por Voz',
    },
    'fr': {
      'app_name': 'Application Navigateur',
      'home': 'Accueil',
      'news': 'Actualités',
      'search': 'Rechercher',
      'bookmarks': 'Favoris',
      'settings': 'Paramètres',
      'sign_in': 'Se Connecter',
      'sign_up': 'S\'inscrire',
      'sign_out': 'Se Déconnecter',
      'admin_panel': 'Panneau d\'Administration',
      'welcome_back': 'Content de vous revoir!',
      'create_account': 'Créer un Compte',
      'email': 'Email',
      'password': 'Mot de Passe',
      'google_signin': 'Continuer avec Google',
      'language': 'Langue',
      'dark_mode': 'Mode Sombre',
      'notifications': 'Notifications',
      'privacy_security': 'Confidentialité et Sécurité',
      'clear_data': 'Effacer les Données',
      'about': 'À Propos',
      'help_support': 'Aide et Support',
      'desktop_mode': 'Mode Bureau',
      'new_tab': 'Nouvel Onglet',
      'history': 'Historique',
      'clear_history': 'Effacer l\'Historique',
      'translate_page': 'Traduire la Page',
      'voice_search': 'Recherche Vocale',
    },
    'ar': {
      'app_name': 'تطبيق المتصفح',
      'home': 'الرئيسية',
      'news': 'الأخبار',
      'search': 'البحث',
      'bookmarks': 'العلامات',
      'settings': 'الإعدادات',
      'sign_in': 'تسجيل الدخول',
      'sign_up': 'إنشاء حساب',
      'sign_out': 'تسجيل الخروج',
      'admin_panel': 'لوحة الإدارة',
      'welcome_back': 'أهلاً بعودتك!',
      'create_account': 'إنشاء حساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'google_signin': 'المتابعة مع جوجل',
      'language': 'اللغة',
      'dark_mode': 'الوضع المظلم',
      'notifications': 'الإشعارات',
      'privacy_security': 'الخصوصية والأمان',
      'clear_data': 'مسح البيانات',
      'about': 'حول',
      'help_support': 'المساعدة والدعم',
      'desktop_mode': 'وضع سطح المكتب',
      'new_tab': 'علامة تبويب جديدة',
      'history': 'التاريخ',
      'clear_history': 'مسح التاريخ',
      'translate_page': 'ترجمة الصفحة',
      'voice_search': 'البحث الصوتي',
    },
    'hi': {
      'app_name': 'ब्राउज़र ऐप',
      'home': 'होम',
      'news': 'समाचार',
      'search': 'खोजें',
      'bookmarks': 'बुकमार्क',
      'settings': 'सेटिंग्स',
      'sign_in': 'साइन इन',
      'sign_up': 'साइन अप',
      'sign_out': 'साइन आउट',
      'admin_panel': 'एडमिन पैनल',
      'welcome_back': 'वापसी पर स्वागत है!',
      'create_account': 'खाता बनाएं',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'google_signin': 'Google के साथ जारी रखें',
      'language': 'भाषा',
      'dark_mode': 'डार्क मोड',
      'notifications': 'सूचनाएं',
      'privacy_security': 'गोपनीयता और सुरक्षा',
      'clear_data': 'डेटा साफ़ करें',
      'about': 'के बारे में',
      'help_support': 'सहायता और समर्थन',
      'desktop_mode': 'डेस्कटॉप मोड',
      'new_tab': 'नया टैब',
      'history': 'इतिहास',
      'clear_history': 'इतिहास साफ़ करें',
      'translate_page': 'पृष्ठ का अनुवाद करें',
      'voice_search': 'आवाज़ खोज',
    },
  };

  static final Map<String, String> _languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'ar': 'العربية',
    'hi': 'हिन्दी',
  };
  
  static String _currentLanguage = 'en';
  
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'en';
  }
  
  static Future<void> setLanguage(String languageCode) async {
    if (_translations.containsKey(languageCode)) {
      _currentLanguage = languageCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    }
  }
  
  static String get currentLanguage => _currentLanguage;
  
  static String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }
  
  static Map<String, String> get supportedLanguages => _languageNames;
  
  static bool get isRtl => _currentLanguage == 'ar';
  
  static TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;
}