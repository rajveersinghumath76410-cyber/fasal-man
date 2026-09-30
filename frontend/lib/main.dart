import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


/* ============================================================
   FASTAPI / ONION QUALITY API
   ============================================================ */

const String fasalManApiBaseUrl = 'http://10.48.248.123:8000';

Future<Map<String, dynamic>> assessOnionPhoto(
  XFile photo, {
  double? averageSizeMm,
}) async {
  final uri = Uri.parse('$fasalManApiBaseUrl/api/v1/assess-onion');

  final request = http.MultipartRequest('POST', uri);
  request.files.add(
    await http.MultipartFile.fromPath(
      'file',
      photo.path,
    ),
  );

  if (averageSizeMm != null) {
    request.fields['average_size_mm'] = averageSizeMm.toStringAsFixed(1);
  }

  final response = await request.send().timeout(
    const Duration(seconds: 90),
  );

  final body = await response.stream.bytesToString();

  if (response.statusCode < 200 || response.statusCode >= 300) {
    String message = 'Backend returned HTTP ${response.statusCode}.';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null) {
          message = detail.toString();
        }
      }
    } catch (_) {}

    throw Exception(message);
  }

  final decoded = jsonDecode(body);

  if (decoded is! Map<String, dynamic>) {
    throw Exception('Invalid response received from the backend.');
  }

  // The backend can deliberately reject a non-onion image.
  // Return that response to the UI so it can show a clear user message
  // instead of treating it as a technical/network failure.
  if (decoded['success'] != true) {
    if (decoded['error_type']?.toString() == 'INVALID_IMAGE' ||
        decoded['valid_image'] == false) {
      return decoded;
    }

    throw Exception(
      decoded['message']?.toString() ??
          'The onion quality assessment was not successful.',
    );
  }

  return decoded;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();
  await appState.load();

  runApp(FasalManApp(appState: appState));
}

/* ============================================================
   APP STATE
   ============================================================ */

class AppState extends ChangeNotifier {
  String name = '';
  String location = '';
  String profilePhotoPath = '';

  bool darkMode = false;
  String language = 'English';
  bool profileCompleted = false;
  bool demoMode = true;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    name = _prefs?.getString('name') ?? '';
    location = _prefs?.getString('location') ?? '';
    profilePhotoPath = _prefs?.getString('profilePhotoPath') ?? '';
    darkMode = _prefs?.getBool('darkMode') ?? false;
    language = _prefs?.getString('language') ?? 'English';
    profileCompleted = _prefs?.getBool('profileCompleted') ?? false;
    demoMode = _prefs?.getBool('demoMode') ?? true;

    notifyListeners();
  }

  Future<void> saveProfile({
    required String newName,
    required String newLocation,
    String? newPhotoPath,
  }) async {
    name = newName.trim();
    location = newLocation.trim();

    if (newPhotoPath != null && newPhotoPath.isNotEmpty) {
      profilePhotoPath = newPhotoPath;
    }

    profileCompleted = name.isNotEmpty;

    await _prefs?.setString('name', name);
    await _prefs?.setString('location', location);
    await _prefs?.setString('profilePhotoPath', profilePhotoPath);
    await _prefs?.setBool('profileCompleted', profileCompleted);

    notifyListeners();
  }

  Future<void> setProfilePhoto(String path) async {
    profilePhotoPath = path;

    await _prefs?.setString('profilePhotoPath', path);

    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;

    await _prefs?.setBool('darkMode', value);

    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    language = value;

    await _prefs?.setString('language', value);

    notifyListeners();
  }

  Future<void> setDemoMode(bool value) async {
    demoMode = value;
    await _prefs?.setBool('demoMode', value);
    notifyListeners();
  }

  Future<void> resetProfile() async {
    name = '';
    location = '';
    profilePhotoPath = '';
    profileCompleted = false;

    await _prefs?.remove('name');
    await _prefs?.remove('location');
    await _prefs?.remove('profilePhotoPath');
    await _prefs?.setBool('profileCompleted', false);

    notifyListeners();
  }
}

/* ============================================================
   APP SCOPE
   ============================================================ */

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();

    assert(scope != null, 'AppScope not found');

    return scope!.notifier!;
  }
}

/* ============================================================
   TRANSLATIONS
   ============================================================ */

const Map<String, Map<String, String>> translations = {
  'English': {
    'app_name': 'Fasal Man',
    'hello': 'Hello',
    'home_subtitle': 'Your smart farming companion',
    'detect': 'Assess Onion Quality',
    'detect_subtitle': 'Capture onion photos and assess visual quality',
    'soil': 'Soil Advisor',
    'soil_subtitle': 'Get soil-based recommendations',
    'chat': 'AI Chatbot',
    'chat_subtitle': 'Ask anything about your crop',
    'alerts': 'Alerts',
    'recent': 'Recent Activity',
    'early_blight': 'Onion Quality Assessment',
    'tomato': 'Visual quality assessment',
    'confidence': 'Backend confidence result',
    'view_treatment': 'View Quality Result',
    'scan_again': 'Assess Again',
    'treatment': 'Treatment Plan',
    'immediate': 'Immediate Actions',
    'prevention': 'Prevention',
    'remove_leaves': 'Remove infected leaves',
    'spacing': 'Improve plant spacing',
    'water_soil': 'Water at soil level',
    'keep_clean': 'Keep field clean',
    'sunlight': 'Ensure enough sunlight',
    'monitor': 'Monitor regularly',
    'safety': 'Use crop protection products according to the product label and local guidance.',
    'scan_another': 'Assess Another Onion Batch',
    'soil_title': 'Soil Advisor',
    'soil_help': 'Enter your soil values to get a recommendation.',
    'ph': 'Soil pH',
    'nitrogen': 'Nitrogen',
    'phosphorus': 'Phosphorus',
    'potassium': 'Potassium',
    'recommendation': 'Recommendation',
    'chat_title': 'Crop Assistant',
    'chat_welcome': 'Hello! I am Fasal Man. How can I help with your crop today?',
    'chat_hint': 'Ask about your crop...',
    'send': 'Send',
    'alerts_title': 'Farm Alerts',
    'no_alerts': 'No new alerts',
    'settings': 'Settings',
    'dark_mode': 'Dark Mode',
    'language': 'Language',
    'profile': 'Profile',
    'edit_profile': 'Edit Profile',
    'name': 'Name',
    'location': 'Location',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'save': 'Save',
    'cancel': 'Cancel',
    'reset': 'Reset Profile',
    'profile_setup': 'Set up your profile',
    'continue': 'Continue',
    'choose_photo': 'Choose Profile Photo',
    'add_photo': 'Add Photo',
    'crop_photos': 'Onion Photos',
    'add_crop': 'Add Onion Photo',
    'analyze': 'Analyze Onion Quality',
    'review': 'Review Onion Photos',
    'max_photos': 'You can add up to 4 onion photos.',
  },
  'Hindi': {
    'app_name': 'फसल मैन',
    'hello': 'नमस्ते',
    'home_subtitle': 'आपका स्मार्ट खेती सहायक',
    'detect': 'रोग पहचानें',
    'detect_subtitle': 'फसल स्कैन करके समस्या पहचानें',
    'soil': 'मृदा सलाहकार',
    'soil_subtitle': 'मिट्टी के आधार पर सलाह लें',
    'chat': 'AI चैटबॉट',
    'chat_subtitle': 'फसल के बारे में पूछें',
    'alerts': 'अलर्ट',
    'recent': 'हाल की गतिविधि',
    'early_blight': 'अर्ली ब्लाइट की संभावना',
    'tomato': 'टमाटर की पत्ती',
    'confidence': '91% भरोसा',
    'view_treatment': 'उपचार योजना देखें',
    'scan_again': 'फिर स्कैन करें',
    'treatment': 'उपचार योजना',
    'immediate': 'तुरंत करें',
    'prevention': 'बचाव',
    'remove_leaves': 'संक्रमित पत्तियां हटाएं',
    'spacing': 'पौधों के बीच दूरी रखें',
    'water_soil': 'मिट्टी के स्तर पर पानी दें',
    'keep_clean': 'खेत साफ रखें',
    'sunlight': 'पर्याप्त धूप सुनिश्चित करें',
    'monitor': 'नियमित निगरानी करें',
    'safety': 'फसल सुरक्षा उत्पादों का उपयोग लेबल और स्थानीय सलाह के अनुसार करें।',
    'scan_another': 'दूसरी फसल स्कैन करें',
    'soil_title': 'मृदा सलाहकार',
    'soil_help': 'सलाह पाने के लिए मिट्टी के मान दर्ज करें।',
    'ph': 'मिट्टी का pH',
    'nitrogen': 'नाइट्रोजन',
    'phosphorus': 'फॉस्फोरस',
    'potassium': 'पोटैशियम',
    'recommendation': 'सलाह',
    'chat_title': 'फसल सहायक',
    'chat_welcome': 'नमस्ते! मैं फसल मैन हूं। मैं आपकी फसल में कैसे मदद कर सकता हूं?',
    'chat_hint': 'फसल के बारे में पूछें...',
    'send': 'भेजें',
    'alerts_title': 'खेत अलर्ट',
    'no_alerts': 'कोई नया अलर्ट नहीं',
    'settings': 'सेटिंग्स',
    'dark_mode': 'डार्क मोड',
    'language': 'भाषा',
    'profile': 'प्रोफाइल',
    'edit_profile': 'प्रोफाइल संपादित करें',
    'name': 'नाम',
    'location': 'स्थान',
    'camera': 'कैमरा',
    'gallery': 'गैलरी',
    'save': 'सहेजें',
    'cancel': 'रद्द करें',
    'reset': 'प्रोफाइल रीसेट करें',
    'profile_setup': 'अपना प्रोफाइल बनाएं',
    'continue': 'जारी रखें',
    'choose_photo': 'प्रोफाइल फोटो चुनें',
    'add_photo': 'फोटो जोड़ें',
    'crop_photos': 'फसल फोटो',
    'add_crop': 'फसल फोटो जोड़ें',
    'analyze': 'फसल का विश्लेषण करें',
    'review': 'फसल फोटो देखें',
    'max_photos': 'आप अधिकतम 4 फोटो जोड़ सकते हैं।',
  },
  'Hinglish': {
    'app_name': 'Fasal Man',
    'hello': 'Namaste',
    'home_subtitle': 'Aapka smart farming companion',
    'detect': 'Disease Detect Karein',
    'detect_subtitle': 'Crop scan karke problem identify karein',
    'soil': 'Soil Advisor',
    'soil_subtitle': 'Soil ke basis par recommendation',
    'chat': 'AI Chatbot',
    'chat_subtitle': 'Apni crop ke baare mein poochhein',
    'alerts': 'Alerts',
    'recent': 'Recent Activity',
    'early_blight': 'Possible Early Blight',
    'tomato': 'Tomato Leaf',
    'confidence': '91% confidence',
    'view_treatment': 'Treatment Plan',
    'scan_again': 'Scan Again',
    'treatment': 'Treatment Plan',
    'immediate': 'Immediate Actions',
    'prevention': 'Prevention',
    'remove_leaves': 'Infected leaves remove karein',
    'spacing': 'Plants ke beech spacing rakhein',
    'water_soil': 'Soil level par paani dein',
    'keep_clean': 'Field clean rakhein',
    'sunlight': 'Enough sunlight dein',
    'monitor': 'Regularly monitor karein',
    'safety': 'Crop protection products label aur local guidance ke according use karein.',
    'scan_another': 'Another Crop Scan Karein',
    'soil_title': 'Soil Advisor',
    'soil_help': 'Recommendation ke liye soil values enter karein.',
    'ph': 'Soil pH',
    'nitrogen': 'Nitrogen',
    'phosphorus': 'Phosphorus',
    'potassium': 'Potassium',
    'recommendation': 'Recommendation',
    'chat_title': 'Crop Assistant',
    'chat_welcome': 'Hello! Main Fasal Man hoon. Aapki crop mein kaise help kar sakta hoon?',
    'chat_hint': 'Crop ke baare mein poochhein...',
    'send': 'Send',
    'alerts_title': 'Farm Alerts',
    'no_alerts': 'No new alerts',
    'settings': 'Settings',
    'dark_mode': 'Dark Mode',
    'language': 'Language',
    'profile': 'Profile',
    'edit_profile': 'Edit Profile',
    'name': 'Name',
    'location': 'Location',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'save': 'Save',
    'cancel': 'Cancel',
    'reset': 'Reset Profile',
    'profile_setup': 'Profile Setup',
    'continue': 'Continue',
    'choose_photo': 'Choose Profile Photo',
    'add_photo': 'Add Photo',
    'crop_photos': 'Crop Photos',
    'add_crop': 'Add Crop Photo',
    'analyze': 'Analyze Crop',
    'review': 'Review Crop Photos',
    'max_photos': 'Maximum 4 photos allowed.',
  },
  'Marathi': {
    'app_name': 'फसल मॅन',
    'hello': 'नमस्कार',
    'home_subtitle': 'तुमचा स्मार्ट शेती सहाय्यक',
    'detect': 'रोग ओळखा',
    'detect_subtitle': 'पीक स्कॅन करून समस्या ओळखा',
    'soil': 'माती सल्लागार',
    'soil_subtitle': 'मातीवर आधारित सल्ला',
    'chat': 'AI चॅटबॉट',
    'chat_subtitle': 'पिकाबद्दल विचारा',
    'alerts': 'सूचना',
    'recent': 'अलीकडील क्रिया',
    'early_blight': 'अर्ली ब्लाइटची शक्यता',
    'tomato': 'टोमॅटोचे पान',
    'confidence': '91% विश्वास',
    'view_treatment': 'उपचार योजना',
    'scan_again': 'पुन्हा स्कॅन करा',
    'treatment': 'उपचार योजना',
    'immediate': 'त्वरित कृती',
    'prevention': 'प्रतिबंध',
    'remove_leaves': 'संक्रमित पाने काढा',
    'spacing': 'झाडांमध्ये योग्य अंतर ठेवा',
    'water_soil': 'मातीच्या पातळीवर पाणी द्या',
    'keep_clean': 'शेत स्वच्छ ठेवा',
    'sunlight': 'पुरेसा सूर्यप्रकाश द्या',
    'monitor': 'नियमित निरीक्षण करा',
    'safety': 'उत्पादनाच्या लेबल आणि स्थानिक मार्गदर्शनानुसार वापरा.',
    'scan_another': 'दुसरे पीक स्कॅन करा',
    'soil_title': 'माती सल्लागार',
    'soil_help': 'सल्ल्यासाठी मातीची मूल्ये भरा.',
    'ph': 'मातीचा pH',
    'nitrogen': 'नायट्रोजन',
    'phosphorus': 'फॉस्फरस',
    'potassium': 'पोटॅशियम',
    'recommendation': 'सल्ला',
    'chat_title': 'पीक सहाय्यक',
    'chat_welcome': 'नमस्कार! मी फसल मॅन आहे. मी तुमच्या पिकासाठी कशी मदत करू?',
    'chat_hint': 'पिकाबद्दल विचारा...',
    'send': 'पाठवा',
    'alerts_title': 'शेत सूचना',
    'no_alerts': 'नवीन सूचना नाहीत',
    'settings': 'सेटिंग्ज',
    'dark_mode': 'डार्क मोड',
    'language': 'भाषा',
    'profile': 'प्रोफाइल',
    'edit_profile': 'प्रोफाइल संपादित करा',
    'name': 'नाव',
    'location': 'स्थान',
    'camera': 'कॅमेरा',
    'gallery': 'गॅलरी',
    'save': 'सेव्ह',
    'cancel': 'रद्द',
    'reset': 'प्रोफाइल रीसेट',
    'profile_setup': 'प्रोफाइल तयार करा',
    'continue': 'पुढे',
    'choose_photo': 'प्रोफाइल फोटो निवडा',
    'add_photo': 'फोटो जोडा',
    'crop_photos': 'पीक फोटो',
    'add_crop': 'पीक फोटो जोडा',
    'analyze': 'पीक तपासा',
    'review': 'पीक फोटो तपासा',
    'max_photos': 'जास्तीत जास्त 4 फोटो.',
  },
  'Punjabi': {
    'app_name': 'ਫਸਲ ਮੈਨ',
    'hello': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
    'home_subtitle': 'ਤੁਹਾਡਾ ਸਮਾਰਟ ਖੇਤੀ ਸਹਾਇਕ',
    'detect': 'ਬਿਮਾਰੀ ਪਛਾਣੋ',
    'detect_subtitle': 'ਫਸਲ ਸਕੈਨ ਕਰਕੇ ਸਮੱਸਿਆ ਪਛਾਣੋ',
    'soil': 'ਮਿੱਟੀ ਸਲਾਹਕਾਰ',
    'soil_subtitle': 'ਮਿੱਟੀ ਦੇ ਆਧਾਰ ਤੇ ਸਲਾਹ',
    'chat': 'AI ਚੈਟਬੋਟ',
    'chat_subtitle': 'ਫਸਲ ਬਾਰੇ ਪੁੱਛੋ',
    'alerts': 'ਅਲਰਟ',
    'recent': 'ਹਾਲੀਆ ਗਤੀਵਿਧੀ',
    'early_blight': 'ਅਰਲੀ ਬਲਾਈਟ ਦੀ ਸੰਭਾਵਨਾ',
    'tomato': 'ਟਮਾਟਰ ਦਾ ਪੱਤਾ',
    'confidence': '91% ਭਰੋਸਾ',
    'view_treatment': 'ਇਲਾਜ ਯੋਜਨਾ',
    'scan_again': 'ਦੁਬਾਰਾ ਸਕੈਨ',
    'treatment': 'ਇਲਾਜ ਯੋਜਨਾ',
    'immediate': 'ਤੁਰੰਤ ਕਾਰਵਾਈ',
    'prevention': 'ਬਚਾਅ',
    'remove_leaves': 'ਸੰਕਰਮਿਤ ਪੱਤੇ ਹਟਾਓ',
    'spacing': 'ਪੌਦਿਆਂ ਵਿਚਕਾਰ ਦੂਰੀ ਰੱਖੋ',
    'water_soil': 'ਮਿੱਟੀ ਦੇ ਪੱਧਰ ਤੇ ਪਾਣੀ ਦਿਓ',
    'keep_clean': 'ਖੇਤ ਸਾਫ ਰੱਖੋ',
    'sunlight': 'ਪੂਰੀ ਧੁੱਪ ਯਕੀਨੀ ਬਣਾਓ',
    'monitor': 'ਨਿਯਮਿਤ ਨਿਗਰਾਨੀ ਕਰੋ',
    'safety': 'ਉਤਪਾਦ ਦੇ ਲੇਬਲ ਅਤੇ ਸਥਾਨਕ ਸਲਾਹ ਅਨੁਸਾਰ ਵਰਤੋਂ ਕਰੋ।',
    'scan_another': 'ਹੋਰ ਫਸਲ ਸਕੈਨ ਕਰੋ',
    'soil_title': 'ਮਿੱਟੀ ਸਲਾਹਕਾਰ',
    'soil_help': 'ਸਲਾਹ ਲਈ ਮਿੱਟੀ ਦੀਆਂ ਕੀਮਤਾਂ ਭਰੋ।',
    'ph': 'ਮਿੱਟੀ pH',
    'nitrogen': 'ਨਾਈਟ੍ਰੋਜਨ',
    'phosphorus': 'ਫਾਸਫੋਰਸ',
    'potassium': 'ਪੋਟਾਸ਼ੀਅਮ',
    'recommendation': 'ਸਲਾਹ',
    'chat_title': 'ਫਸਲ ਸਹਾਇਕ',
    'chat_welcome': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਫਸਲ ਮੈਨ ਹਾਂ। ਮੈਂ ਤੁਹਾਡੀ ਫਸਲ ਲਈ ਕਿਵੇਂ ਮਦਦ ਕਰ ਸਕਦਾ ਹਾਂ?',
    'chat_hint': 'ਫਸਲ ਬਾਰੇ ਪੁੱਛੋ...',
    'send': 'ਭੇਜੋ',
    'alerts_title': 'ਖੇਤ ਅਲਰਟ',
    'no_alerts': 'ਕੋਈ ਨਵਾਂ ਅਲਰਟ ਨਹੀਂ',
    'settings': 'ਸੈਟਿੰਗਜ਼',
    'dark_mode': 'ਡਾਰਕ ਮੋਡ',
    'language': 'ਭਾਸ਼ਾ',
    'profile': 'ਪ੍ਰੋਫਾਈਲ',
    'edit_profile': 'ਪ੍ਰੋਫਾਈਲ ਸੋਧੋ',
    'name': 'ਨਾਮ',
    'location': 'ਸਥਾਨ',
    'camera': 'ਕੈਮਰਾ',
    'gallery': 'ਗੈਲਰੀ',
    'save': 'ਸੇਵ',
    'cancel': 'ਰੱਦ',
    'reset': 'ਪ੍ਰੋਫਾਈਲ ਰੀਸੈਟ',
    'profile_setup': 'ਪ੍ਰੋਫਾਈਲ ਬਣਾਓ',
    'continue': 'ਜਾਰੀ ਰੱਖੋ',
    'choose_photo': 'ਪ੍ਰੋਫਾਈਲ ਫੋਟੋ ਚੁਣੋ',
    'add_photo': 'ਫੋਟੋ ਜੋੜੋ',
    'crop_photos': 'ਫਸਲ ਫੋਟੋ',
    'add_crop': 'ਫਸਲ ਫੋਟੋ ਜੋੜੋ',
    'analyze': 'ਫਸਲ ਵਿਸ਼ਲੇਸ਼ਣ',
    'review': 'ਫਸਲ ਫੋਟੋ ਵੇਖੋ',
    'max_photos': 'ਵੱਧ ਤੋਂ ਵੱਧ 4 ਫੋਟੋਆਂ।',
  },
  'Bengali': {
    'app_name': 'ফসল ম্যান',
    'hello': 'নমস্কার',
    'home_subtitle': 'আপনার স্মার্ট কৃষি সহায়ক',
    'detect': 'রোগ শনাক্ত করুন',
    'detect_subtitle': 'ফসল স্ক্যান করে সমস্যা শনাক্ত করুন',
    'soil': 'মাটি পরামর্শ',
    'soil_subtitle': 'মাটির ভিত্তিতে পরামর্শ',
    'chat': 'AI চ্যাটবট',
    'chat_subtitle': 'ফসল সম্পর্কে প্রশ্ন করুন',
    'alerts': 'সতর্কতা',
    'recent': 'সাম্প্রতিক কার্যকলাপ',
    'early_blight': 'আর্লি ব্লাইটের সম্ভাবনা',
    'tomato': 'টমেটো পাতা',
    'confidence': '৯১% আত্মবিশ্বাস',
    'view_treatment': 'চিকিৎসা পরিকল্পনা',
    'scan_again': 'আবার স্ক্যান',
    'treatment': 'চিকিৎসা পরিকল্পনা',
    'immediate': 'তাৎক্ষণিক পদক্ষেপ',
    'prevention': 'প্রতিরোধ',
    'remove_leaves': 'আক্রান্ত পাতা সরান',
    'spacing': 'গাছের মধ্যে দূরত্ব রাখুন',
    'water_soil': 'মাটির স্তরে পানি দিন',
    'keep_clean': 'ক্ষেত পরিষ্কার রাখুন',
    'sunlight': 'পর্যাপ্ত সূর্যালোক নিশ্চিত করুন',
    'monitor': 'নিয়মিত পর্যবেক্ষণ করুন',
    'safety': 'লেবেল এবং স্থানীয় নির্দেশনা অনুযায়ী ব্যবহার করুন।',
    'scan_another': 'অন্য ফসল স্ক্যান করুন',
    'soil_title': 'মাটি পরামর্শ',
    'soil_help': 'পরামর্শ পেতে মাটির মান লিখুন।',
    'ph': 'মাটির pH',
    'nitrogen': 'নাইট্রোজেন',
    'phosphorus': 'ফসফরাস',
    'potassium': 'পটাশিয়াম',
    'recommendation': 'পরামর্শ',
    'chat_title': 'ফসল সহায়ক',
    'chat_welcome': 'নমস্কার! আমি ফসল ম্যান। আপনার ফসলের জন্য কীভাবে সাহায্য করতে পারি?',
    'chat_hint': 'ফসল সম্পর্কে প্রশ্ন করুন...',
    'send': 'পাঠান',
    'alerts_title': 'খেত সতর্কতা',
    'no_alerts': 'নতুন সতর্কতা নেই',
    'settings': 'সেটিংস',
    'dark_mode': 'ডার্ক মোড',
    'language': 'ভাষা',
    'profile': 'প্রোফাইল',
    'edit_profile': 'প্রোফাইল সম্পাদনা',
    'name': 'নাম',
    'location': 'স্থান',
    'camera': 'ক্যামেরা',
    'gallery': 'গ্যালারি',
    'save': 'সেভ',
    'cancel': 'বাতিল',
    'reset': 'প্রোফাইল রিসেট',
    'profile_setup': 'প্রোফাইল তৈরি করুন',
    'continue': 'চালিয়ে যান',
    'choose_photo': 'প্রোফাইল ছবি বেছে নিন',
    'add_photo': 'ছবি যোগ করুন',
    'crop_photos': 'ফসলের ছবি',
    'add_crop': 'ফসলের ছবি যোগ করুন',
    'analyze': 'ফসল বিশ্লেষণ',
    'review': 'ফসলের ছবি দেখুন',
    'max_photos': 'সর্বোচ্চ ৪টি ছবি।',
  },
};

String tr(BuildContext context, String key) {
  final state = AppScope.of(context);
  return translations[state.language]?[key] ??
      translations['English']![key] ??
      key;
}

/* ============================================================
   APP
   ============================================================ */

class FasalManApp extends StatelessWidget {
  final AppState appState;

  const FasalManApp({
    super.key,
    required this.appState,
  });

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F8F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8F5),
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101510),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF66BB6A),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101510),
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B221B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1B221B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: appState,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Fasal Man',
            theme: _lightTheme(),
            darkTheme: _darkTheme(),
            themeMode:
                appState.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashPage(),
          );
        },
      ),
    );
  }
}

/* ============================================================
   COMMON WIDGETS
   ============================================================ */

class ProfileAvatar extends StatelessWidget {
  final double radius;

  const ProfileAvatar({
    super.key,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    if (state.profilePhotoPath.isNotEmpty) {
      final file = File(state.profilePhotoPath);

      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(file),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: radius,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

/* ============================================================
   SPLASH
   ============================================================ */

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;

      final state = AppScope.of(context);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => state.profileCompleted
              ? const HomePage()
              : const ProfileSetupPage(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: color.primary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.agriculture,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Fasal Man',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color.primary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Smart farming companion',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: color.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   PROFILE SETUP
   ============================================================ */

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedPhoto;
  bool _saving = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1000,
    );

    if (picked == null || !mounted) return;

    final savedPath = await _saveProfileImage(picked);

    if (!mounted) return;

    setState(() {
      _selectedPhoto = savedPath;
    });
  }

  Future<String> _saveProfileImage(XFile picked) async {
    final directory = await getApplicationDocumentsDirectory();

    final extension = picked.path.contains('.')
        ? picked.path.split('.').last
        : 'jpg';

    final target = File(
      '${directory.path}/fasal_profile_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    await File(picked.path).copy(target.path);

    return target.path;
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final state = AppScope.of(context);

    await state.saveProfile(
      newName: _nameController.text,
      newLocation: _locationController.text,
      newPhotoPath: _selectedPhoto,
    );

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(tr(context, 'camera')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(tr(context, 'gallery')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(tr(context, 'cancel')),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                tr(context, 'profile_setup'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a little about yourself to personalize Fasal Man.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 35),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 58,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      backgroundImage: _selectedPhoto != null
                          ? FileImage(File(_selectedPhoto!))
                          : null,
                      child: _selectedPhoto == null
                          ? Icon(
                              Icons.person,
                              size: 58,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _showPhotoOptions,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(11),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr(context, 'name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: tr(context, 'location'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          tr(context, 'continue'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   HOME
   ============================================================ */

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  void _onNavigation(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PreviewPage(),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AlertsPage(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfilePage(),
        ),
      );
      return;
    }

    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name =
        state.name.isEmpty ? 'Farmer' : state.name.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Row(
              children: [
                ProfileAvatar(radius: 25),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr(context, 'hello')}, $name 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(context, 'home_subtitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hero card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assess onion quality.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Take onion photos and let Fasal Man assess visible quality.',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PreviewPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(
                                tr(context, 'detect'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          flex: 1,
                          child: Icon(
                            Icons.eco,
                            color: Colors.white,
                            size: 72,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 25),
            SectionTitle('Quick Actions'),

            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.straighten_outlined,
                    title: 'Onion Size',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PreviewPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.chat_bubble_outline,
                    title: tr(context, 'chat'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.notifications_none,
                    title: tr(context, 'alerts'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AlertsPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),
            SectionTitle(tr(context, 'recent')),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'early_blight'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(tr(context, 'tomato')),
                          const SizedBox(height: 3),
                          Text(
                            tr(context, 'confidence'),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onNavigation,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Detect',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 17,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   PROFILE
   ============================================================ */

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ProfileAvatar(radius: 58),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              state.name.isEmpty ? 'Farmer' : state.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          if (state.location.isNotEmpty) ...[
            const SizedBox(height: 5),
            Center(
              child: Text(
                state.location,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          const SizedBox(height: 30),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(tr(context, 'edit_profile')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(tr(context, 'settings')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   EDIT PROFILE
   ============================================================ */

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;

  String _photoPath = '';
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // IMPORTANT:
    // Do not call AppScope.of(context) here.
    // Inherited widgets must be accessed after initState.
    _nameController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // This is the correct place to read AppScope.
    if (!_initialized) {
      final state = AppScope.of(context);

      _nameController.text = state.name;
      _locationController.text = state.location;
      _photoPath = state.profilePhotoPath;

      _initialized = true;
    }
  }

  Future<String> _saveProfileImage(XFile picked) async {
    final directory = await getApplicationDocumentsDirectory();

    final extension = picked.path.contains('.')
        ? picked.path.split('.').last
        : 'jpg';

    final target = File(
      '${directory.path}/fasal_profile_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    await File(picked.path).copy(target.path);

    return target.path;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1000,
    );

    if (picked == null) return;

    final savedPath = await _saveProfileImage(picked);

    if (!mounted) return;

    final state = AppScope.of(context);

    // Update the central state immediately.
    await state.setProfilePhoto(savedPath);

    if (!mounted) return;

    setState(() {
      _photoPath = savedPath;
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(tr(context, 'camera')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(tr(context, 'gallery')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(tr(context, 'cancel')),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final state = AppScope.of(context);

    await state.saveProfile(
      newName: _nameController.text,
      newLocation: _locationController.text,
      newPhotoPath: _photoPath.isEmpty ? null : _photoPath,
    );

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        _photoPath.isNotEmpty && File(_photoPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'edit_profile')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 62,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage:
                        hasPhoto ? FileImage(File(_photoPath)) : null,
                    child: hasPhoto
                        ? null
                        : Icon(
                            Icons.person,
                            size: 62,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _showPhotoOptions,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: tr(context, 'name'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: tr(context, 'location'),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        tr(context, 'save'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   SETTINGS
   ============================================================ */

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showLanguageDialog(BuildContext context) {
    final state = AppScope.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, 'language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: translations.keys.map((language) {
              return RadioListTile<String>(
                value: language,
                groupValue: state.language,
                title: Text(language),
                onChanged: (value) async {
                  if (value == null) return;

                  await state.setLanguage(value);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _resetProfile(BuildContext context) async {
    final state = AppScope.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr(context, 'reset')),
          content: const Text(
            'This will remove your saved profile information. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(context, 'reset')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await state.resetProfile();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: SwitchListTile(
              secondary: Icon(
                state.darkMode
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              title: Text(tr(context, 'dark_mode')),
              subtitle: Text(
                state.darkMode ? 'Enabled' : 'Disabled',
              ),
              value: state.darkMode,
              onChanged: (value) {
                // This immediately rebuilds MaterialApp and changes theme.
                state.setDarkMode(value);
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.science_outlined),
              title: const Text('Prototype Demo Mode'),
              subtitle: Text(
                state.demoMode
                    ? 'Local results — backend not required'
                    : 'Uses FastAPI backend for analysis',
              ),
              value: state.demoMode,
              onChanged: (value) => state.setDemoMode(value),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(tr(context, 'language')),
              subtitle: Text(state.language),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(tr(context, 'edit_profile')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfilePage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.restart_alt,
                color: Colors.orange,
              ),
              title: Text(tr(context, 'reset')),
              onTap: () => _resetProfile(context),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   LOCAL PROTOTYPE DEMO RESULT
   ============================================================ */

Map<String, dynamic> buildDemoOnionResult({
  double? averageSizeMm,
  int index = 0,
}) {
  final size = averageSizeMm ?? 60.0;
  final category = size < 10
      ? 'Below A'
      : size <= 20
          ? 'A'
          : size <= 40
              ? 'B'
              : size <= 70
                  ? 'C'
                  : 'D';

  return {
    'success': true,
    'valid_image': true,
    'assessment_id': 'FM-DEMO-${(index + 1).toString().padLeft(2, '0')}',
    'assessment': {
      'grade': 'Class I',
      'quality_score': 83.9,
      'confidence': 0.81,
      'summary': 'Prototype local onion quality assessment for demonstration.',
      'parameters': {
        'visible_onions': {'count': 1},
        'shape': {'average_circularity': 0.776},
        'colour_uniformity': {'score': 59.1},
        'visible_defects': {'dark_area_percent': 0.15},
        'sprouting': {'green_area_percent': 0.0},
        'firmness': {'status': 'Not assessable from photo'},
        'internal_defects': {'status': 'Not assessable from photo'},
        'size': {
          'provided': true,
          'average_diameter_mm': size,
          'size_category': category,
        },
      },
      'limitations': [
        'Prototype demo result generated locally in the APK.',
        'Firmness cannot be reliably confirmed from an external photo.',
        'Internal defects cannot be reliably confirmed from an external photo.',
        'Physical size is user-provided and reported separately from the visual quality grade.',
        'This prototype result is not an official grading certification.',
      ],
    },
  };
}

/* ============================================================
   CROP PREVIEW / IMAGE PICKER
   ============================================================ */

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final ImagePicker _picker = ImagePicker();

  final List<XFile> _photos = [];
  bool _analyzing = false;
  int _currentPhoto = 0;
  final TextEditingController _averageSizeController = TextEditingController();

  @override
  void dispose() {
    _averageSizeController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= 4) {
      _showMaxPhotos();
      return;
    }

    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1400,
    );

    if (photo == null || !mounted) return;

    setState(() {
      _photos.add(photo);
    });
  }

  Future<void> _pickGallery() async {
    if (_photos.length >= 4) {
      _showMaxPhotos();
      return;
    }

    final remaining = 4 - _photos.length;

    final selected = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1400,
      limit: remaining,
    );

    if (!mounted) return;

    setState(() {
      _photos.addAll(selected.take(remaining));
    });
  }

  void _showMaxPhotos() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'max_photos')),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _analyze() async {
    if (_photos.isEmpty || _analyzing) {
      if (_photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one onion photo.'),
          ),
        );
      }
      return;
    }

    // Validate the optional size before starting the loading state.
    final sizeText = _averageSizeController.text.trim();
    final averageSizeMm = sizeText.isEmpty ? null : double.tryParse(sizeText);

    if (sizeText.isNotEmpty &&
        (averageSizeMm == null || averageSizeMm <= 0 || averageSizeMm > 300)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid average onion diameter between 1 and 300 mm.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _analyzing = true;
      _currentPhoto = 0;
    });

    final results = <Map<String, dynamic>>[];
    final demoMode = AppScope.of(context).demoMode;

    try {
      if (demoMode) {
        // Fully offline prototype path. No HTTP request is made.
        debugPrint('FASAL_MAN_DEMO: local analysis started');
        for (int i = 0; i < _photos.length; i++) {
          if (!mounted) return;
          setState(() => _currentPhoto = i + 1);
          await Future<void>.delayed(const Duration(milliseconds: 250));
          results.add(buildDemoOnionResult(
            averageSizeMm: averageSizeMm,
            index: i,
          ));
        }
      } else {
      // The FastAPI endpoint accepts one image per request.
      // The optional average bulb diameter is sent with every photo.
      for (int i = 0; i < _photos.length; i++) {
        if (!mounted) return;

        setState(() {
          _currentPhoto = i + 1;
        });

        final result = await assessOnionPhoto(
          _photos[i],
          averageSizeMm: averageSizeMm,
        );

        debugPrint(
          'FASAL_MAN_ANALYZE: response received, checking validity',
        );
        debugPrint(
          'FASAL_MAN_ANALYZE: result success=${result['success']} '
          'valid_image=${result['valid_image']} '
          'error_type=${result['error_type']}',
        );

        // Stop immediately if the backend says this is not an onion image.
        if (result['valid_image'] == false ||
            result['error_type']?.toString() == 'INVALID_IMAGE') {
          if (!mounted) return;

          setState(() {
            _analyzing = false;
          });

          final message = result['message']?.toString() ??
              'This image does not appear to contain an onion.';

          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error_outline),
                    SizedBox(width: 10),
                    Expanded(child: Text('Invalid Image')),
                  ],
                ),
                content: Text(
                  'Photo ${i + 1} cannot be used for onion assessment.\n\n'
                  '$message\n\n'
                  'Please upload a clear photo of the onion batch.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );

          return;
        }

        debugPrint('FASAL_MAN_ANALYZE: adding result to results list');
        results.add(result);
        debugPrint(
          'FASAL_MAN_ANALYZE: result added, results.length=${results.length}',
        );
      }
      }

      debugPrint(
        'FASAL_MAN_ANALYZE: all photos processed, results.length=${results.length}',
      );

      if (!mounted) {
        debugPrint(
          'FASAL_MAN_ANALYZE: widget is no longer mounted; stopping before navigation',
        );
        return;
      }

      setState(() {
        _analyzing = false;
      });

      debugPrint('FASAL_MAN_ANALYZE: analyzing set to false');
      debugPrint('FASAL_MAN_ANALYZE: about to navigate to result page');

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnionQualityResultPage(
              photos: List<XFile>.from(_photos),
              results: results,
            ),
          ),
        );

        debugPrint('FASAL_MAN_ANALYZE: Navigator.push completed');
      } catch (navigationError, navigationStack) {
        debugPrint(
          'FASAL_MAN_ANALYZE: NAVIGATION ERROR: $navigationError',
        );
        debugPrint(
          'FASAL_MAN_ANALYZE: NAVIGATION STACK: $navigationStack',
        );
        rethrow;
      }
    } catch (e, stackTrace) {
      debugPrint('FASAL_MAN_ANALYZE: ERROR: $e');
      debugPrint('FASAL_MAN_ANALYZE: STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _analyzing = false;
      });

      debugPrint('FASAL_MAN_ANALYZE: analyzing reset after error');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assessment failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assess Onion Quality'),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onion Photos',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${_photos.length}/4 photos added',
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Use clear photos with the onions fully visible.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.straighten_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Optional average onion size',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'If you know the average bulb diameter, enter it. Fasal Man will include the size in the assessment and report.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _averageSizeController,
                          enabled: !_analyzing,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Average bulb diameter (mm)',
                            hintText: 'Example: 55',
                            suffixText: 'mm',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Leave blank if the size is not known.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                if (_photos.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 45,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 65,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Add clear photos of the onion batch.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_photos[index].path),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: () => _removePhoto(index),
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _photos.length >= 4 || _analyzing
                            ? null
                            : _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(tr(context, 'camera')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _photos.length >= 4 || _analyzing
                            ? null
                            : _pickGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(tr(context, 'gallery')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _photos.isEmpty || _analyzing
                        ? null
                        : _analyze,
                    icon: const Icon(Icons.analytics_outlined),
                    label: Text(
                      _photos.isEmpty
                          ? 'Analyze Onion Quality'
                          : 'Analyze ${_photos.length} ${_photos.length == 1 ? 'Photo' : 'Photos'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_analyzing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 26,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 18),
                          Text(
                            'Analyzing onion quality...',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Photo $_currentPhoto of ${_photos.length}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Please keep the app open.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ============================================================
   ONION QUALITY RESULT
   ============================================================ */

class OnionQualityResultPage extends StatelessWidget {
  final List<XFile> photos;
  final List<Map<String, dynamic>> results;

  const OnionQualityResultPage({
    super.key,
    required this.photos,
    required this.results,
  });

  Map<String, dynamic> _assessment(Map<String, dynamic> result) {
    final assessment = result['assessment'];
    if (assessment is Map<String, dynamic>) {
      return assessment;
    }
    return <String, dynamic>{};
  }

  String _grade(Map<String, dynamic> result) {
    return _assessment(result)['grade']?.toString() ?? 'Not available';
  }

  double _number(
    Map<String, dynamic> result,
    String key,
  ) {
    final value = _assessment(result)[key];
    if (value is num) return value.toDouble();
    return 0;
  }

  String _parameter(
    Map<String, dynamic> result,
    String group,
    String key,
  ) {
    final assessment = _assessment(result);
    final parameters = assessment['parameters'];

    if (parameters is Map<String, dynamic>) {
      final item = parameters[group];
      if (item is Map<String, dynamic>) {
        return item[key]?.toString() ?? '—';
      }
    }

    return '—';
  }

  List<String> _limitations(Map<String, dynamic> result) {
    final value = _assessment(result)['limitations'];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  String _assessmentId(Map<String, dynamic> result) {
    return result['assessment_id']?.toString() ?? '—';
  }

  String _reportText(
    BuildContext context,
    double averageScore,
    double averageConfidence,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('Fasal Man - Onion Quality Assessment');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Photos analyzed: ${results.length}');
    buffer.writeln(
      'Average visual quality score: ${averageScore.toStringAsFixed(1)}/100',
    );
    buffer.writeln(
      'Average image-analysis confidence: '
      '${(averageConfidence * 100).toStringAsFixed(0)}%',
    );
    buffer.writeln();

    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('Photo ${i + 1}: ${_grade(result)}');
      buffer.writeln(
        '  Quality score: '
        '${_number(result, 'quality_score').toStringAsFixed(1)}/100',
      );
      buffer.writeln(
        '  Confidence: '
        '${(_number(result, 'confidence') * 100).toStringAsFixed(0)}%',
      );
      buffer.writeln(
        '  Visible onions: '
        '${_parameter(result, 'visible_onions', 'count')}',
      );
      buffer.writeln(
        '  Average size: '
        '${_parameter(result, 'size', 'average_diameter_mm')} mm',
      );
      buffer.writeln(
        '  Size category: '
        '${_parameter(result, 'size', 'size_category')}',
      );
      buffer.writeln(
        '  Circularity: '
        '${_parameter(result, 'shape', 'average_circularity')}',
      );
      buffer.writeln(
        '  Colour uniformity: '
        '${_parameter(result, 'colour_uniformity', 'score')}/100',
      );
      buffer.writeln(
        '  Visible dark area: '
        '${_parameter(result, 'visible_defects', 'dark_area_percent')}%',
      );
      buffer.writeln(
        '  Sprouting indicator: '
        '${_parameter(result, 'sprouting', 'green_area_percent')}%',
      );
      buffer.writeln(
        '  Firmness: '
        '${_parameter(result, 'firmness', 'status')}',
      );
      buffer.writeln(
        '  Internal defects: '
        '${_parameter(result, 'internal_defects', 'status')}',
      );
      buffer.writeln('  Assessment ID: ${_assessmentId(result)}');
      buffer.writeln();
    }

    buffer.writeln('Important limitations:');
    for (final item in results.isEmpty ? const <String>[] : _limitations(results.first)) {
      buffer.writeln('• $item');
    }

    return buffer.toString().trim();
  }

  Color _gradeColor(BuildContext context, String grade) {
    final scheme = Theme.of(context).colorScheme;

    if (grade == 'Extra Class') {
      return scheme.primary;
    }
    if (grade == 'Class I') {
      return scheme.tertiary;
    }
    if (grade == 'Class II') {
      return scheme.secondary;
    }
    return scheme.outline;
  }

  String _gradeDescription(String grade) {
    switch (grade) {
      case 'Extra Class':
        return 'Highest visual grade in this indicative assessment.';
      case 'Class I':
        return 'Good visual quality based on the analysed image.';
      case 'Class II':
        return 'Visual quality indicators require closer inspection.';
      default:
        return 'The image could not be assigned a visual grade.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scores = results
        .map((r) => _number(r, 'quality_score'))
        .where((v) => v >= 0)
        .toList();

    final confidences = results
        .map((r) => _number(r, 'confidence'))
        .where((v) => v >= 0)
        .toList();

    final averageScore = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;

    final averageConfidence = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / confidences.length;

    final singleGrade = results.length == 1
        ? _grade(results.first)
        : 'Photo-wise results';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onion Quality Result'),
        actions: [
          IconButton(
            tooltip: 'Copy report',
            onPressed: results.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: _reportText(
                          context,
                          averageScore,
                          averageConfidence,
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Quality report copied to clipboard.'),
                      ),
                    );
                  },
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _HeroResultCard(
              photoCount: results.length,
              grade: singleGrade,
              averageScore: averageScore,
              averageConfidence: averageConfidence,
              gradeColor: _gradeColor(context, singleGrade),
              gradeDescription: results.length == 1
                  ? _gradeDescription(singleGrade)
                  : 'Each photo has been assessed separately.',
            ),
            const SizedBox(height: 16),
            const SectionTitle('Assessment overview'),
            _OverviewCard(
              score: averageScore,
              confidence: averageConfidence,
              photoCount: results.length,
            ),
            const SizedBox(height: 16),
            SectionTitle(
              results.length == 1
                  ? 'Visual quality parameters'
                  : 'Photo-wise visual assessment',
            ),
            ...List.generate(results.length, (index) {
              return _PhotoAssessmentCard(
                context: context,
                index: index,
                photo: photos[index],
                result: results[index],
                assessment: _assessment(results[index]),
                grade: _grade(results[index]),
                score: _number(results[index], 'quality_score'),
                confidence: _number(results[index], 'confidence'),
                parameter: _parameter,
                gradeColor: _gradeColor(
                  context,
                  _grade(results[index]),
                ),
              );
            }),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionTitle('What the image can assess'),
              const _CapabilityCard(
                icon: Icons.visibility_outlined,
                title: 'Visible characteristics',
                text:
                    'Shape, visible colour uniformity, visible dark regions, '
                    'sprouting indicators and image-detectable onion objects '
                    'are assessed from the photograph.',
              ),
              const SizedBox(height: 10),
              const _CapabilityCard(
                icon: Icons.touch_app_outlined,
                title: 'Not confirmed by photo',
                text:
                    'Firmness and internal defects such as internal rot '
                    'cannot be reliably confirmed from an external image.',
              ),
              const SizedBox(height: 16),
              const SectionTitle('Important limitations'),
              ..._limitations(results.first).map(
                (item) => _LimitationItem(text: item),
              ),
            ],
            const SizedBox(height: 16),
            _ReportCard(
              assessmentId: results.length == 1
                  ? _assessmentId(results.first)
                  : 'Multiple assessment IDs',
              onCopy: results.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: _reportText(
                            context,
                            averageScore,
                            averageConfidence,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quality report copied to clipboard.'),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PreviewPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text(
                  'Assess Another Onion Batch',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroResultCard extends StatelessWidget {
  final int photoCount;
  final String grade;
  final double averageScore;
  final double averageConfidence;
  final Color gradeColor;
  final String gradeDescription;

  const _HeroResultCard({
    required this.photoCount,
    required this.grade,
    required this.averageScore,
    required this.averageConfidence,
    required this.gradeColor,
    required this.gradeDescription,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: 34,
                color: gradeColor,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Visual Assessment Complete',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$photoCount photo${photoCount == 1 ? '' : 's'} analysed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (photoCount == 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: gradeColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    color: gradeColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gradeDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                Expanded(
                  child: _LargeMetric(
                    label: 'Quality score',
                    value: '${averageScore.toStringAsFixed(1)}/100',
                    icon: Icons.analytics_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LargeMetric(
                    label: 'Confidence',
                    value:
                        '${(averageConfidence * 100).toStringAsFixed(0)}%',
                    icon: Icons.insights_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _LargeMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final double score;
  final double confidence;
  final int photoCount;

  const _OverviewCard({
    required this.score,
    required this.confidence,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final double scoreFraction = (score / 100).clamp(0.0, 1.0).toDouble();
    final double confidenceFraction = confidence.clamp(0.0, 1.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _ProgressMetric(
              label: 'Visual quality score',
              value: '${score.toStringAsFixed(1)}/100',
              fraction: scoreFraction,
              color: scheme.primary,
            ),
            const SizedBox(height: 18),
            _ProgressMetric(
              label: 'Image-analysis confidence',
              value: '${(confidence * 100).toStringAsFixed(0)}%',
              fraction: confidenceFraction,
              color: scheme.tertiary,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 9),
                Text(
                  '$photoCount image${photoCount == 1 ? '' : 's'} included',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;

  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 9,
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _PhotoAssessmentCard extends StatelessWidget {
  final BuildContext context;
  final int index;
  final XFile photo;
  final Map<String, dynamic> result;
  final Map<String, dynamic> assessment;
  final String grade;
  final double score;
  final double confidence;
  final String Function(
    Map<String, dynamic>,
    String,
    String,
  ) parameter;
  final Color gradeColor;

  const _PhotoAssessmentCard({
    required this.context,
    required this.index,
    required this.photo,
    required this.result,
    required this.assessment,
    required this.grade,
    required this.score,
    required this.confidence,
    required this.parameter,
    required this.gradeColor,
  });

  @override
  Widget build(BuildContext _) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(photo.path),
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo ${index + 1}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        grade,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: gradeColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Image-based indicative result',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Quality score',
                    value: '${score.toStringAsFixed(1)}/100',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Confidence',
                    value: '${(confidence * 100).toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text(
              'Visual parameters',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _ResultRow(
              label: 'Visible onions',
              value: parameter(result, 'visible_onions', 'count'),
            ),
            _ResultRow(
              label: 'Circularity',
              value: parameter(result, 'shape', 'average_circularity'),
            ),
            _ResultRow(
              label: 'Colour uniformity',
              value:
                  '${parameter(result, 'colour_uniformity', 'score')}/100',
            ),
            _ResultRow(
              label: 'Visible dark area',
              value:
                  '${parameter(result, 'visible_defects', 'dark_area_percent')}%',
            ),
            _ResultRow(
              label: 'Sprouting indicator',
              value:
                  '${parameter(result, 'sprouting', 'green_area_percent')}%',
            ),
            const SizedBox(height: 8),
            _StatusTile(
              icon: Icons.pan_tool_outlined,
              title: 'Firmness',
              value: parameter(result, 'firmness', 'status'),
              isLimited: true,
            ),
            const SizedBox(height: 8),
            _StatusTile(
              icon: Icons.search_off_outlined,
              title: 'Internal defects',
              value: parameter(result, 'internal_defects', 'status'),
              isLimited: true,
            ),
            if (assessment['summary'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  assessment['summary'].toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isLimited;

  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isLimited,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isLimited ? scheme.outline : scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String assessmentId;
  final VoidCallback? onCopy;

  const _ReportCard({
    required this.assessmentId,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: scheme.primary),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Quality report',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'Assessment ID: $assessmentId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text(
                  'Copy Assessment Report',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitationItem extends StatelessWidget {
  final String text;

  const _LimitationItem({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   TREATMENT
   ============================================================ */

class TreatmentPage extends StatelessWidget {
  const TreatmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'treatment')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.eco,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tomato',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Early Blight'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SectionTitle(tr(context, 'immediate')),
            _TreatmentItem(
              number: '1',
              text: tr(context, 'remove_leaves'),
            ),
            _TreatmentItem(
              number: '2',
              text: tr(context, 'spacing'),
            ),
            _TreatmentItem(
              number: '3',
              text: tr(context, 'water_soil'),
            ),
            const SizedBox(height: 20),
            SectionTitle(tr(context, 'prevention')),
            _Bullet(text: tr(context, 'keep_clean')),
            _Bullet(text: tr(context, 'sunlight')),
            _Bullet(text: tr(context, 'monitor')),
            const SizedBox(height: 18),
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.65),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(context, 'safety'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PreviewPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  tr(context, 'scan_another'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreatmentItem extends StatelessWidget {
  final String number;
  final String text;

  const _TreatmentItem({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/* ============================================================
   SOIL ADVISOR
   ============================================================ */

/* ============================================================
   CHAT
   ============================================================ */

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({
    required this.text,
    required this.isUser,
  });
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _welcomeAdded = false;
  bool _typing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Safe place to use tr(context,...).
    if (!_welcomeAdded) {
      _messages.add(
        _ChatMessage(
          text: tr(context, 'chat_welcome'),
          isUser: false,
        ),
      );

      _welcomeAdded = true;
    }
  }

  void _send() {
    final text = _controller.text.trim();

    if (text.isEmpty || _typing) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _controller.clear();
      _typing = true;
    });

    _scrollToBottom();

    Future.delayed(
      const Duration(milliseconds: 800),
      () {
        if (!mounted) return;

        setState(() {
          _typing = false;
          _messages.add(
            _ChatMessage(
              text:
                  'Based on your question, please check the affected crop carefully. For the demo, you can also use Detect Disease to scan a crop image.',
              isUser: false,
            ),
          );
        });

        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'chat_title')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_typing && index == _messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Card(
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          child: SizedBox(
                            width: 38,
                            child: LinearProgressIndicator(),
                          ),
                        ),
                      ),
                    );
                  }

                  final message = _messages[index];

                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.78,
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.isUser
                              ? Colors.white
                              : null,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: tr(context, 'chat_hint'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _typing ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   ALERTS
   ============================================================ */

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'alerts_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_outlined,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weather Watch',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Keep monitoring field conditions and avoid unnecessary leaf wetness.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.eco_outlined,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crop Monitoring',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Regularly inspect leaves for spots, discoloration and other changes.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
