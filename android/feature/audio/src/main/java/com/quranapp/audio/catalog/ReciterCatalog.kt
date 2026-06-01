package com.quranapp.audio.catalog

import com.quranapp.audio.domain.model.Reciter

object ReciterCatalog {

    val ALL: List<Reciter> = listOf(
        Reciter(
            id = 1,
            name = "Mishary Rashid Alafasy",
            arabicName = "مشاري راشد العفاسي",
            relativePath = "mishaari_raashid_al_3afaasee/",
            hasGaplessAudio = true,
        ),
        Reciter(
            id = 2,
            name = "Abdul Rahman Al-Sudais",
            arabicName = "عبد الرحمن السديس",
            relativePath = "abdurrahmaan_as-sudays/",
            hasGaplessAudio = true,
        ),
        Reciter(
            id = 3,
            name = "Saad Al-Ghamdi",
            arabicName = "سعد الغامدي",
            relativePath = "sa3d_al-ghaamidi/",
            hasGaplessAudio = false,
        ),
        Reciter(
            id = 4,
            name = "Mohamed Al-Minshawi",
            arabicName = "محمد صديق المنشاوي",
            relativePath = "muhammad_siddeeq_al-minshaawee/",
            hasGaplessAudio = false,
        ),
        Reciter(
            id = 5,
            name = "Ahmad Al-Shatri",
            arabicName = "أحمد الشاطري",
            relativePath = "ahmed_ibn_3ali_al-3ajamy/",
            hasGaplessAudio = false,
        ),
        Reciter(
            id = 6,
            name = "Nasser Al-Qatami",
            arabicName = "ناصر القطامي",
            relativePath = "naaser_al-qataami/",
            hasGaplessAudio = true,
        ),
        Reciter(
            id = 7,
            name = "Maher Al-Muaiqly",
            arabicName = "ماهر المعيقلي",
            relativePath = "maahir_al-mu3ayqalee/",
            hasGaplessAudio = true,
        ),
        Reciter(
            id = 8,
            name = "Yasser Al-Dosari",
            arabicName = "ياسر الدوسري",
            relativePath = "yasser_ad-dussary/",
            hasGaplessAudio = false,
        ),
    )

    private const val CDN_BASE = "https://download.quranicaudio.com/quran/"

    /** URL for a full gapless surah MP3 (single file). */
    fun gaplessSurahUrl(reciter: Reciter, surahNumber: Int): String {
        val surah = surahNumber.toString().padStart(3, '0')
        return "$CDN_BASE${reciter.relativePath}$surah.mp3"
    }

    /** URL for a single per-ayah MP3. */
    fun perAyahUrl(reciter: Reciter, surahNumber: Int, ayahNumber: Int): String {
        val surah = surahNumber.toString().padStart(3, '0')
        val ayah = ayahNumber.toString().padStart(3, '0')
        return "$CDN_BASE${reciter.relativePath}$surah/$ayah.mp3"
    }

    fun findById(id: Int): Reciter? = ALL.firstOrNull { it.id == id }

    /** Number of ayahs in each surah (1-indexed, index 0 unused). */
    val SURAH_AYAH_COUNTS = intArrayOf(
        0, // placeholder
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
        123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
        34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
        60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
        28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
        15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
        5, 4, 5, 6,
    )
}
