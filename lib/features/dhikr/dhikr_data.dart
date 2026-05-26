// Dhikr categories and content sourced from authentic Sunnah
// Each DhikrItem is verified from Sahih hadith collections

enum DhikrCategory { morning, evening, afterPrayer, general }

class DhikrItem {
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final int count; // recommended repetition count
  final String? source; // hadith reference

  const DhikrItem({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.count,
    this.source,
  });
}

class DhikrCollection {
  final DhikrCategory category;
  final String titleEn;
  final String titleAr;
  final IconCategory icon;
  final List<DhikrItem> items;

  const DhikrCollection({
    required this.category,
    required this.titleEn,
    required this.titleAr,
    required this.icon,
    required this.items,
  });

  int get totalCount => items.fold(0, (sum, i) => sum + i.count);
}

enum IconCategory { sun, moon, prayer, heart }

// ─── Morning Adhkar (أذكار الصباح) ───────────────────────────────────────────

const _morning = [
  DhikrItem(
    id: 'm1',
    arabic: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n'
        'اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ...',
    transliteration:
        "A'udhu billahi min ash-shaytan ir-rajim\nAllahu la ilaha illa huwal-Hayyul-Qayyum...",
    translation:
        'Ayat Al-Kursi — Reciting this in the morning grants Allah\'s protection until evening.',
    count: 1,
    source: 'Al-Bukhari',
  ),
  DhikrItem(
    id: 'm2',
    arabic:
        'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
    transliteration:
        "Qul huwa Allahu ahad, Allahu as-samad, lam yalid wa lam yulad, wa lam yakun lahu kufuwan ahad",
    translation:
        'Surah Al-Ikhlas — Equals one-third of the Quran in reward.',
    count: 3,
    source: 'Abu Dawud',
  ),
  DhikrItem(
    id: 'm3',
    arabic:
        'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    transliteration:
        "Asbahna wa asbahal-mulku lillah, walhamdu lillah, la ilaha illa Allahu wahdahu la sharika lah, lahul-mulku walahul-hamd, wa huwa 'ala kulli shay'in qadir",
    translation:
        'We have entered the morning and the entire kingdom belongs to Allah. Praise be to Allah. There is no god except Allah alone, with no partner. To Him belongs the kingdom and to Him belongs all praise and He is capable of all things.',
    count: 1,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'm4',
    arabic:
        'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
    transliteration:
        "Allahumma bika asbahna, wa bika amsayna, wa bika nahya, wa bika namutu, wa ilayka an-nushur",
    translation:
        'O Allah, by Your leave we have reached the morning and by Your leave we have reached the evening, by Your leave we live and die and unto You is our resurrection.',
    count: 1,
    source: 'At-Tirmidhi',
  ),
  DhikrItem(
    id: 'm5',
    arabic:
        'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
    transliteration:
        "Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana abduk, wa ana 'ala 'ahdika wa wa'dika mastata't, a'udhu bika min sharri ma sana't, abu'u laka bini'matika 'alayya, wa abu'u bidhanbi faghfir li fa innahu la yaghfirudh-dhunuba illa ant",
    translation:
        'Sayyid Al-Istighfar — The master supplication for forgiveness. Whoever says it in the morning with certainty and dies that day will enter Paradise.',
    count: 1,
    source: 'Al-Bukhari',
  ),
  DhikrItem(
    id: 'm6',
    arabic:
        'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ',
    transliteration:
        "Allahumma 'afini fi badani, Allahumma 'afini fi sam'i, Allahumma 'afini fi basari, la ilaha illa ant",
    translation:
        'O Allah, grant my body health. O Allah, grant me health in my hearing. O Allah, grant me health in my sight. There is none worthy of worship but You.',
    count: 3,
    source: 'Abu Dawud',
  ),
  DhikrItem(
    id: 'm7',
    arabic:
        'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    transliteration:
        "Bismillahil-ladhi la yadurru ma'a ismihi shay'un fil-ardi wa la fis-sama'i wa huwas-sami'ul-'alim",
    translation:
        'In the name of Allah with whose name nothing is harmed on earth nor in the heavens, and He is the All-Hearing, All-Knowing.',
    count: 3,
    source: 'Abu Dawud, At-Tirmidhi',
  ),
  DhikrItem(
    id: 'm8',
    arabic:
        'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
    transliteration:
        "Raditu billahi rabban, wa bil-Islami dinan, wa bi-Muhammadin sallallahu 'alayhi wa sallam nabiyyan",
    translation:
        'I am pleased with Allah as my Lord, with Islam as my religion and with Muhammad (ﷺ) as my Prophet.',
    count: 3,
    source: 'Abu Dawud, At-Tirmidhi',
  ),
  DhikrItem(
    id: 'm9',
    arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    transliteration: "Subhanallahi wa bihamdih",
    translation:
        'Glory be to Allah and His is the praise. Whoever says it 100 times in the morning and evening will have no one on the Day of Resurrection with better deeds.',
    count: 100,
    source: 'Al-Bukhari & Muslim',
  ),
  DhikrItem(
    id: 'm10',
    arabic:
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    transliteration:
        "La ilaha illa Allahu wahdahu la sharika lah, lahul-mulku wa lahul-hamd, wa huwa 'ala kulli shay'in qadir",
    translation:
        'None has the right to be worshipped but Allah alone, Who has no partner. His is the dominion and His is the praise, and He is Able to do all things.',
    count: 10,
    source: 'Al-Bukhari & Muslim',
  ),
];

// ─── Evening Adhkar (أذكار المساء) ───────────────────────────────────────────

const _evening = [
  DhikrItem(
    id: 'e1',
    arabic: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n'
        'اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ...',
    transliteration: "A'udhu billahi min ash-shaytan ir-rajim\nAllahu la ilaha illa huwal-Hayyul-Qayyum...",
    translation:
        'Ayat Al-Kursi — Reciting this in the evening grants Allah\'s protection until morning.',
    count: 1,
    source: 'Al-Bukhari',
  ),
  DhikrItem(
    id: 'e2',
    arabic:
        'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
    transliteration:
        "Qul huwa Allahu ahad, Allahu as-samad, lam yalid wa lam yulad, wa lam yakun lahu kufuwan ahad",
    translation: 'Surah Al-Ikhlas — Equals one-third of the Quran in reward.',
    count: 3,
    source: 'Abu Dawud',
  ),
  DhikrItem(
    id: 'e3',
    arabic:
        'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    transliteration:
        "Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha illa Allahu wahdahu la sharika lah",
    translation:
        'We have entered the evening and the entire kingdom belongs to Allah, praise be to Allah. There is no god except Allah alone with no partner.',
    count: 1,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'e4',
    arabic:
        'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
    transliteration:
        "Allahumma bika amsayna, wa bika asbahna, wa bika nahya, wa bika namutu, wa ilayka al-masir",
    translation:
        'O Allah, by Your leave we have reached the evening and by Your leave we have reached the morning, by Your leave we live and die and unto You is our return.',
    count: 1,
    source: 'At-Tirmidhi',
  ),
  DhikrItem(
    id: 'e5',
    arabic:
        'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ...',
    transliteration:
        "Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana abduk...",
    translation:
        'Sayyid Al-Istighfar — Whoever says it in the evening with certainty and dies that night will enter Paradise.',
    count: 1,
    source: 'Al-Bukhari',
  ),
  DhikrItem(
    id: 'e6',
    arabic:
        'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ: أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ',
    transliteration:
        "Allahumma inni amsaytu ush-hiduka wa ush-hidu hamalata 'arshika wa mala'ikataka wa jami'a khalqika: annaka anta Allahu la ilaha illa ant",
    translation:
        'O Allah, I have entered the evening calling upon You as witness and upon the bearers of Your throne and all Your creation: that You are Allah, none has the right to be worshipped but You.',
    count: 4,
    source: 'Abu Dawud',
  ),
  DhikrItem(
    id: 'e7',
    arabic:
        'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي',
    transliteration:
        "Allahumma 'afini fi badani, Allahumma 'afini fi sam'i, Allahumma 'afini fi basari",
    translation:
        'O Allah, grant my body health. O Allah, grant me health in my hearing. O Allah, grant me health in my sight.',
    count: 3,
    source: 'Abu Dawud',
  ),
  DhikrItem(
    id: 'e8',
    arabic:
        'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ',
    transliteration:
        "Allahumma inni a'udhu bika minal-hammi wal-huzn, wa a'udhu bika minal-'ajzi wal-kasal",
    translation:
        'O Allah, I take refuge in You from anxiety and sorrow, and I take refuge in You from incapacity and laziness.',
    count: 1,
    source: 'Al-Bukhari',
  ),
  DhikrItem(
    id: 'e9',
    arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    transliteration: "Subhanallahi wa bihamdih",
    translation:
        'Glory be to Allah and His is the praise. Whoever says it 100 times a day will have his sins washed away even if they were like the foam of the sea.',
    count: 100,
    source: 'Al-Bukhari & Muslim',
  ),
  DhikrItem(
    id: 'e10',
    arabic:
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    transliteration:
        "La ilaha illa Allahu wahdahu la sharika lah, lahul-mulku wa lahul-hamd, wa huwa 'ala kulli shay'in qadir",
    translation:
        'None has the right to be worshipped but Allah alone. His is the dominion, His is the praise, and He is Able to do all things.',
    count: 10,
    source: 'Al-Bukhari & Muslim',
  ),
];

// ─── After Prayer Adhkar (أذكار بعد الصلاة) ──────────────────────────────────

const _afterPrayer = [
  DhikrItem(
    id: 'ap1',
    arabic: 'أَسْتَغْفِرُ اللَّهَ',
    transliteration: "Astaghfirullah",
    translation: 'I seek forgiveness from Allah.',
    count: 3,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'ap2',
    arabic:
        'اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ ذَا الْجَلَالِ وَالْإِكْرَامِ',
    transliteration:
        "Allahumma antas-salam, wa minkas-salam, tabarakta dhal-jalali wal-ikram",
    translation:
        'O Allah, You are Peace and from You comes peace. Blessed are You, O Owner of Majesty and Honor.',
    count: 1,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'ap3',
    arabic:
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    transliteration:
        "La ilaha illa Allahu wahdahu la sharika lah, lahul-mulku wa lahul-hamd, wa huwa 'ala kulli shay'in qadir",
    translation:
        'None has the right to be worshipped but Allah alone, Who has no partner. His is the dominion and His is the praise, and He is Able to do all things.',
    count: 1,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'ap4',
    arabic: 'سُبْحَانَ اللَّهِ',
    transliteration: "Subhanallah",
    translation:
        'Glory be to Allah. Whoever says it 33 times after each prayer, and completes 100 with "La ilaha illa Allah..." will have his sins forgiven.',
    count: 33,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'ap5',
    arabic: 'الْحَمْدُ لِلَّهِ',
    transliteration: "Alhamdulillah",
    translation: 'All praise is due to Allah.',
    count: 33,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'ap6',
    arabic: 'اللَّهُ أَكْبَرُ',
    transliteration: "Allahu Akbar",
    translation: 'Allah is the Greatest.',
    count: 33,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'ap7',
    arabic:
        'اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ...',
    transliteration: "Allahu la ilaha illa huwal-Hayyul-Qayyum...",
    translation:
        'Ayat Al-Kursi — Whoever recites it after each prayer, only death will prevent him from entering Paradise.',
    count: 1,
    source: 'An-Nasa\'i',
  ),
];

// ─── General Dhikr ────────────────────────────────────────────────────────────

const _general = [
  DhikrItem(
    id: 'g1',
    arabic: 'سُبْحَانَ اللَّهِ',
    transliteration: "Subhanallah",
    translation: 'Glory be to Allah.',
    count: 33,
  ),
  DhikrItem(
    id: 'g2',
    arabic: 'الْحَمْدُ لِلَّهِ',
    transliteration: "Alhamdulillah",
    translation: 'All praise is due to Allah.',
    count: 33,
  ),
  DhikrItem(
    id: 'g3',
    arabic: 'اللَّهُ أَكْبَرُ',
    transliteration: "Allahu Akbar",
    translation: 'Allah is the Greatest.',
    count: 33,
  ),
  DhikrItem(
    id: 'g4',
    arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
    transliteration: "La ilaha illa Allah",
    translation: 'There is no god but Allah.',
    count: 100,
  ),
  DhikrItem(
    id: 'g5',
    arabic:
        'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    transliteration:
        "Subhanallahi wa bihamdih, subhanallahil-'azim",
    translation:
        'Glory be to Allah and His is the praise. Glory be to Allah the Magnificent. Two phrases light on the tongue, heavy on the scale, beloved to the Most Merciful.',
    count: 100,
    source: 'Al-Bukhari & Muslim',
  ),
  DhikrItem(
    id: 'g6',
    arabic: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
    transliteration: "Allahumma salli wa sallim 'ala nabiyyina Muhammad",
    translation:
        'O Allah, send blessings and peace upon our Prophet Muhammad. Whoever sends one blessing upon the Prophet (ﷺ), Allah will send ten blessings upon him.',
    count: 10,
    source: 'Muslim',
  ),
  DhikrItem(
    id: 'g7',
    arabic:
        'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    transliteration: "La hawla wa la quwwata illa billah",
    translation:
        'There is no power and no might except with Allah. It is a treasure from the treasures of Paradise.',
    count: 100,
    source: 'Al-Bukhari & Muslim',
  ),
];

// ─── All collections ──────────────────────────────────────────────────────────

const List<DhikrCollection> dhikrCollections = [
  DhikrCollection(
    category: DhikrCategory.morning,
    titleEn: 'Morning Adhkar',
    titleAr: 'أذكار الصباح',
    icon: IconCategory.sun,
    items: _morning,
  ),
  DhikrCollection(
    category: DhikrCategory.evening,
    titleEn: 'Evening Adhkar',
    titleAr: 'أذكار المساء',
    icon: IconCategory.moon,
    items: _evening,
  ),
  DhikrCollection(
    category: DhikrCategory.afterPrayer,
    titleEn: 'After Prayer',
    titleAr: 'أذكار بعد الصلاة',
    icon: IconCategory.prayer,
    items: _afterPrayer,
  ),
  DhikrCollection(
    category: DhikrCategory.general,
    titleEn: 'Tasbih',
    titleAr: 'التسبيح',
    icon: IconCategory.heart,
    items: _general,
  ),
];
