import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TafsirInfo {
  const TafsirInfo({
    required this.id,
    required this.name,
    required this.language,
    required this.author,
    required this.langCode,
  });

  final int id;
  final String name;      // display name in native script
  final String language;  // human-readable language label
  final String author;    // author / translator
  final String langCode;  // lowercase English key for grouping
}

// Language display order in the library screen.
const kTafsirLangOrder = [
  'arabic', 'english', 'urdu', 'bengali', 'indonesian', 'turkish',
  'russian', 'french', 'persian', 'spanish', 'chinese', 'japanese',
  'bosnian', 'italian', 'hindi', 'tamil', 'kurdish', 'albanian',
  'uzbek', 'vietnamese', 'tagalog', 'malayalam', 'assamese', 'thai',
];

const kTafsirs = [
  // ── Arabic ──────────────────────────────────────────────────────────────────
  TafsirInfo(id: 14,   name: 'تفسير ابن كثير',        language: 'عربي',      author: 'الحافظ ابن كثير',         langCode: 'arabic'),
  TafsirInfo(id: 15,   name: 'تفسير الطبري',           language: 'عربي',      author: 'ابن جرير الطبري',          langCode: 'arabic'),
  TafsirInfo(id: 16,   name: 'التفسير الميسّر',        language: 'عربي',      author: 'نخبة من العلماء',          langCode: 'arabic'),
  TafsirInfo(id: 90,   name: 'تفسير القرطبي',          language: 'عربي',      author: 'القرطبي',                  langCode: 'arabic'),
  TafsirInfo(id: 91,   name: 'تفسير السعدي',           language: 'عربي',      author: 'عبد الرحمن السعدي',        langCode: 'arabic'),
  TafsirInfo(id: 92,   name: 'التحرير والتنوير',       language: 'عربي',      author: 'ابن عاشور',                langCode: 'arabic'),
  TafsirInfo(id: 93,   name: 'التفسير الوسيط',         language: 'عربي',      author: 'طنطاوي',                   langCode: 'arabic'),
  TafsirInfo(id: 94,   name: 'تفسير البغوي',           language: 'عربي',      author: 'البغوي',                   langCode: 'arabic'),
  TafsirInfo(id: 905,  name: 'المختصر في التفسير',     language: 'عربي',      author: 'مركز تفسير',               langCode: 'arabic'),
  TafsirInfo(id: 1485, name: 'تفسير ابن عثيمين',       language: 'عربي',      author: 'ابن عثيمين',               langCode: 'arabic'),
  TafsirInfo(id: 1486, name: 'تفسير الجلالين',         language: 'عربي',      author: 'السيوطي والمحلي',          langCode: 'arabic'),
  TafsirInfo(id: 1487, name: 'تفسير البيضاوي',         language: 'عربي',      author: 'البيضاوي',                 langCode: 'arabic'),
  TafsirInfo(id: 1496, name: 'فتح القدير',             language: 'عربي',      author: 'الشوكاني',                 langCode: 'arabic'),
  TafsirInfo(id: 1498, name: 'روح المعاني',            language: 'عربي',      author: 'الآلوسي',                  langCode: 'arabic'),
  TafsirInfo(id: 1499, name: 'مفاتيح الغيب',           language: 'عربي',      author: 'الفخر الرازي',             langCode: 'arabic'),
  // ── English ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 169,  name: 'Ibn Kathir (Abridged)',   language: 'English',   author: 'Hafiz Ibn Kathir',        langCode: 'english'),
  TafsirInfo(id: 171,  name: 'Al-Mukhtasar',            language: 'English',   author: 'Tafsir Center',           langCode: 'english'),
  TafsirInfo(id: 817,  name: 'Tazkirul Quran',          language: 'English',   author: 'Maulana Wahiduddin Khan', langCode: 'english'),
  TafsirInfo(id: 1579, name: "Asbab-us-Nuzul",          language: 'English',   author: 'Al-Wahidi',               langCode: 'english'),
  // ── Urdu ────────────────────────────────────────────────────────────────────
  TafsirInfo(id: 160,  name: 'تفسیر ابن کثیر',         language: 'اردو',      author: 'حافظ ابن کثیر',           langCode: 'urdu'),
  TafsirInfo(id: 159,  name: 'بیان القرآن',             language: 'اردو',      author: 'ڈاکٹر اسرار احمد',        langCode: 'urdu'),
  TafsirInfo(id: 157,  name: 'فی ظلال القرآن',         language: 'اردو',      author: 'سید قطب',                 langCode: 'urdu'),
  TafsirInfo(id: 906,  name: 'تفسیر السعدی',           language: 'اردو',      author: 'عبدالرحمن السعدی',        langCode: 'urdu'),
  // ── Bengali ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 164,  name: 'তাফসীর ইবনে কাসীর',     language: 'বাংলা',    author: 'Tawheed Publication',     langCode: 'bengali'),
  TafsirInfo(id: 165,  name: 'তাফসীর আহসানুল বায়ান',  language: 'বাংলা',    author: 'Bayaan Foundation',       langCode: 'bengali'),
  TafsirInfo(id: 166,  name: 'তাফসীর আবু বকর যাকারিয়া', language: 'বাংলা', author: 'King Fahd Complex',        langCode: 'bengali'),
  TafsirInfo(id: 180,  name: 'আল-মুখতাসার',            language: 'বাংলা',    author: 'Tafsir Center',           langCode: 'bengali'),
  // ── Indonesian ──────────────────────────────────────────────────────────────
  TafsirInfo(id: 174,  name: 'Al-Mukhtasar',            language: 'Indonesia', author: 'Markaz Tafsir',           langCode: 'indonesian'),
  TafsirInfo(id: 816,  name: 'Tafsir Jalalain',         language: 'Indonesia', author: 'King Fahd Complex',       langCode: 'indonesian'),
  TafsirInfo(id: 910,  name: 'Tafsir As-Saadi',         language: 'Indonesia', author: 'As-Saadi',                langCode: 'indonesian'),
  // ── Turkish ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 172,  name: 'Al-Muhtasar',             language: 'Türkçe',    author: 'Tefsir Merkezi',          langCode: 'turkish'),
  TafsirInfo(id: 907,  name: 'Es-Saadi Tefsiri',        language: 'Türkçe',    author: 'Es-Saadi',                langCode: 'turkish'),
  TafsirInfo(id: 914,  name: 'İbn Kesir Tefsiri',       language: 'Türkçe',    author: 'İbn Kesir',               langCode: 'turkish'),
  // ── Russian ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 170,  name: 'Тафсир ас-Саади',         language: 'Русский',   author: 'ас-Саади',                langCode: 'russian'),
  TafsirInfo(id: 913,  name: 'Тафсир Ибн Касир',        language: 'Русский',   author: 'Ибн Касир',               langCode: 'russian'),
  TafsirInfo(id: 178,  name: 'Краткое толкование',       language: 'Русский',   author: 'Tafsir Center',           langCode: 'russian'),
  // ── French ──────────────────────────────────────────────────────────────────
  TafsirInfo(id: 173,  name: 'Explication Abrégée',     language: 'Français',  author: 'Centre de Tafsir',        langCode: 'french'),
  // ── Persian ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 181,  name: 'المختصر',                 language: 'فارسی',     author: 'مرکز تفسیر',              langCode: 'persian'),
  TafsirInfo(id: 909,  name: 'تفسیر سعدی',              language: 'فارسی',     author: 'سعدی',                    langCode: 'persian'),
  // ── Spanish ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 776,  name: 'Explicación Abreviada',   language: 'Español',   author: 'Centro de Tafsir',        langCode: 'spanish'),
  // ── Chinese ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 182,  name: '简明古兰经注',             language: '中文',      author: '古兰经研究中心',           langCode: 'chinese'),
  // ── Japanese ────────────────────────────────────────────────────────────────
  TafsirInfo(id: 183,  name: 'クルアーン解説',           language: '日本語',    author: 'タフスィールセンター',     langCode: 'japanese'),
  // ── Bosnian ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 175,  name: 'Skraćeno tumačenje',      language: 'Bosanski',  author: 'Tafsir Centar',           langCode: 'bosnian'),
  // ── Italian ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 176,  name: 'Spiegazione Abbreviata',  language: 'Italiano',  author: 'Centro di Tafsir',        langCode: 'italian'),
  // ── Hindi ───────────────────────────────────────────────────────────────────
  TafsirInfo(id: 1273, name: 'संक्षिप्त तफ्सीर',       language: 'हिन्दी',   author: 'तफ्सीर केंद्र',           langCode: 'hindi'),
  // ── Tamil ───────────────────────────────────────────────────────────────────
  TafsirInfo(id: 1279, name: 'சுருக்கமான விளக்கம்',    language: 'தமிழ்',    author: 'Tafsir Center',            langCode: 'tamil'),
  // ── Kurdish ─────────────────────────────────────────────────────────────────
  TafsirInfo(id: 804,  name: 'Tefsîra Kurdî',           language: 'Kurdî',     author: 'Rebar',                   langCode: 'kurdish'),
  // ── Albanian ────────────────────────────────────────────────────────────────
  TafsirInfo(id: 915,  name: 'Tefsiri Saadij',          language: 'Shqip',     author: 'es-Saadi',                langCode: 'albanian'),
  // ── Uzbek ───────────────────────────────────────────────────────────────────
  TafsirInfo(id: 1283, name: 'Qisqacha tafsir',         language: 'Oʻzbek',    author: 'Tafsir markazi',          langCode: 'uzbek'),
  // ── Vietnamese ──────────────────────────────────────────────────────────────
  TafsirInfo(id: 177,  name: 'Giải thích tóm tắt',      language: 'Tiếng Việt', author: 'Trung tâm Tafsir',      langCode: 'vietnamese'),
  // ── Filipino ────────────────────────────────────────────────────────────────
  TafsirInfo(id: 179,  name: 'Maikling Paliwanag',       language: 'Filipino',  author: 'Tafsir Center',           langCode: 'tagalog'),
  // ── Malayalam ───────────────────────────────────────────────────────────────
  TafsirInfo(id: 791,  name: 'ഖുർആൻ വ്യാഖ്യാനം',     language: 'മലയാളം',  author: 'Tafsir Center',             langCode: 'malayalam'),
  // ── Assamese ────────────────────────────────────────────────────────────────
  TafsirInfo(id: 790,  name: 'কোৰআনৰ চমু ব্যাখ্যা',   language: 'অসমীয়া',  author: 'Tafsir Center',            langCode: 'assamese'),
  // ── Thai ────────────────────────────────────────────────────────────────────
  TafsirInfo(id: 1281, name: 'คำอธิบายย่อ',             language: 'ภาษาไทย',  author: 'ศูนย์ตัฟสีร',             langCode: 'thai'),
];

// ─── Persisted single-tafsir selection (used by TafsirSheet bottom-sheet) ─────

class TafsirIdNotifier extends Notifier<int> {
  static const _key = 'tafsir_id';
  static const _default = 16;

  @override
  int build() {
    _load();
    return _default;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? _default;
  }

  Future<void> set(int id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, id);
  }
}

final tafsirIdProvider =
    NotifierProvider<TafsirIdNotifier, int>(TafsirIdNotifier.new);

// ─── Tafsir fetcher with persistent cache ─────────────────────────────────────

class TafsirRepository {
  TafsirRepository(this._dio);

  final Dio _dio;

  // In-memory layer prevents repeat fetches within the same session.
  final Map<String, String> _memCache = {};

  String _cacheKey(int tafsirId, String verseKey) =>
      'tafsir_${tafsirId}_$verseKey';

  Future<String> fetchTafsir(
      {required int tafsirId, required String verseKey}) async {
    final key = _cacheKey(tafsirId, verseKey);

    // 1 — memory hit
    final mem = _memCache[key];
    if (mem != null) return mem;

    // 2 — SharedPreferences hit (survives app restarts)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      _memCache[key] = cached;
      return cached;
    }

    // 3 — network fetch; on failure re-throw (no stale to serve)
    final url =
        'https://api.quran.com/api/v4/tafsirs/$tafsirId/by_ayah/$verseKey';
    final response = await _dio.get<Map<String, dynamic>>(url);
    final tafsirMap = response.data?['tafsir'] as Map<String, dynamic>?;
    final rawOrNull = tafsirMap?['text'] as String?;
    if (rawOrNull == null || rawOrNull.isEmpty) {
      throw Exception('لا يوجد نص متاح لهذه الآية');
    }
    final text = _stripHtml(rawOrNull);

    _memCache[key] = text;
    // Fire-and-forget: don't block the caller on prefs write.
    prefs.setString(key, text);

    return text;
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

final _dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 20),
)));

final tafsirRepositoryProvider = Provider<TafsirRepository>(
    (ref) => TafsirRepository(ref.read(_dioProvider)));

// ─── Auto-dispose fetch provider ──────────────────────────────────────────────

typedef TafsirKey = ({int tafsirId, String verseKey});

final tafsirTextProvider =
    FutureProvider.autoDispose.family<String, TafsirKey>((ref, key) {
  return ref.read(tafsirRepositoryProvider).fetchTafsir(
        tafsirId: key.tafsirId,
        verseKey: key.verseKey,
      );
});
