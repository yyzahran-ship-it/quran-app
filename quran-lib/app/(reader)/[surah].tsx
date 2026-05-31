import React, { useState, useRef, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Share,
  Alert,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { FlashList } from '@shopify/flash-list';
import { MaterialIcons } from '@expo/vector-icons';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';

import AyahRow from '../../components/AyahRow';
import TafsirSheet from '../../components/TafsirSheet';
import WordPopup from '../../components/WordPopup';
import { useAyahs, useSurah, useWords } from '../../hooks/useAyahs';
import { useReaderStore } from '../../stores/useReaderStore';
import { useLibraryStore } from '../../stores/useLibraryStore';
import { useBookmarkStore } from '../../stores/useBookmarkStore';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { THEMES } from '../../constants/themes';
import type { AyahWithTranslations, Word } from '../../types/quran';

export default function ReaderScreen() {
  const { surah: surahParam } = useLocalSearchParams<{ surah: string }>();
  const surahId = parseInt(surahParam ?? '1', 10);
  const router = useRouter();

  const { fontSize, translationSize, showTranslation, showTransliteration, displayMode, setCurrentSurah, setCurrentAyah } = useReaderStore();
  const activeTranslations = useLibraryStore((s) => s.activeTranslationIds);
  const activeTafsirs = useLibraryStore((s) => s.activeTafsirIds);
  const { addBookmark, getBookmarkForAyah, updateLastRead } = useBookmarkStore();
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];

  const surah = useSurah(surahId);
  const { ayahs, loading } = useAyahs(surahId, activeTranslations);

  const [tafsirAyah, setTafsirAyah] = useState<AyahWithTranslations | null>(null);
  const [selectedWord, setSelectedWord] = useState<Word | null>(null);
  const [highlightedAyahId, setHighlightedAyahId] = useState<number | null>(null);
  const listRef = useRef<FlashList<AyahWithTranslations>>(null);

  useEffect(() => {
    setCurrentSurah(surahId);
  }, [surahId]);

  const handleViewableItemsChanged = useCallback(
    ({ viewableItems }: { viewableItems: Array<{ item: AyahWithTranslations }> }) => {
      const first = viewableItems[0]?.item;
      if (first) {
        setCurrentAyah(first.ayah_number);
        updateLastRead(surahId, first.id);
      }
    },
    [surahId]
  );

  const handleLongPress = useCallback((ayah: AyahWithTranslations) => {
    setTafsirAyah(ayah);
  }, []);

  const handleBookmark = useCallback(
    (ayah: AyahWithTranslations) => {
      const existing = getBookmarkForAyah(ayah.id);
      if (existing) {
        Alert.alert('Already bookmarked', 'This ayah is already in your bookmarks.');
      } else {
        addBookmark(ayah.id);
      }
    },
    [getBookmarkForAyah, addBookmark]
  );

  const handleShare = useCallback(async (ayah: AyahWithTranslations) => {
    const translation = ayah.translations[0]?.text ?? '';
    await Share.share({
      message: `${ayah.text_uthmani}\n\n${translation}\n\n— ${surah?.name_english ?? ''} ${surahId}:${ayah.ayah_number}`,
    });
  }, [surah, surahId]);

  const renderAyah = useCallback(
    ({ item }: { item: AyahWithTranslations }) => (
      <AyahRow
        ayah={item}
        colors={colors}
        arabicFontSize={fontSize}
        translationFontSize={translationSize}
        showTranslation={showTranslation}
        showTransliteration={showTransliteration}
        isHighlighted={item.id === highlightedAyahId}
        onLongPress={() => handleLongPress(item)}
        onBookmark={() => handleBookmark(item)}
        onShare={() => handleShare(item)}
        onPlayAudio={() => {}}
      />
    ),
    [colors, fontSize, translationSize, showTranslation, showTransliteration, highlightedAyahId]
  );

  if (!surah && !loading) {
    return (
      <View style={[styles.centered, { backgroundColor: colors.background }]}>
        <Text style={{ color: colors.textSecondary }}>Surah not found</Text>
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={[styles.screen, { backgroundColor: colors.background }]}>
      <SafeAreaView style={{ flex: 1 }}>
        {/* Header */}
        <View style={[styles.header, { backgroundColor: colors.surface, borderBottomColor: colors.border }]}>
          <TouchableOpacity onPress={() => router.back()} style={styles.headerBtn}>
            <MaterialIcons name="arrow-back" size={24} color={colors.text} />
          </TouchableOpacity>

          <View style={styles.headerCenter}>
            <Text style={[styles.headerTitle, { color: colors.text }]}>
              {surah?.name_english ?? '…'}
            </Text>
            <Text style={[styles.headerSub, { color: colors.textSecondary }]}>
              {surah?.name_transliteration} · {surah?.ayah_count} ayahs
            </Text>
          </View>

          <View style={styles.headerActions}>
            <TouchableOpacity
              style={styles.headerBtn}
              onPress={() => router.push('/settings/translations')}
            >
              <MaterialIcons name="translate" size={22} color={colors.text} />
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.headerBtn}
              onPress={() => router.push('/settings/appearance')}
            >
              <MaterialIcons name="text-fields" size={22} color={colors.text} />
            </TouchableOpacity>
          </View>
        </View>

        {/* Bismillah */}
        {surahId !== 1 && surahId !== 9 && (
          <View style={[styles.bismillah, { borderBottomColor: colors.border }]}>
            <Text style={[styles.bismillahText, { color: colors.arabicText, fontSize: fontSize }]}>
              بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ
            </Text>
          </View>
        )}

        {/* Ayah list */}
        <FlashList
          ref={listRef}
          data={ayahs}
          renderItem={renderAyah}
          estimatedItemSize={200}
          keyExtractor={(item) => String(item.id)}
          onViewableItemsChanged={handleViewableItemsChanged}
          viewabilityConfig={{ minimumViewTime: 500, itemVisiblePercentThreshold: 50 }}
          contentContainerStyle={{ paddingBottom: 100 }}
          ListEmptyComponent={
            loading ? (
              <View style={styles.centered}>
                <Text style={{ color: colors.textSecondary }}>Loading…</Text>
              </View>
            ) : null
          }
        />

        {/* Tafsir bottom sheet */}
        {tafsirAyah && (
          <TafsirSheet
            ayahId={tafsirAyah.id}
            surahName={surah?.name_english ?? ''}
            ayahNumber={tafsirAyah.ayah_number}
            colors={colors}
            onClose={() => setTafsirAyah(null)}
          />
        )}

        {/* Word detail popup */}
        <WordPopup
          word={selectedWord}
          colors={colors}
          onClose={() => setSelectedWord(null)}
        />

        {/* Bottom navigation bar */}
        <View style={[styles.bottomNav, { backgroundColor: colors.surface, borderTopColor: colors.border }]}>
          <TouchableOpacity
            style={styles.navBtn}
            disabled={surahId <= 1}
            onPress={() => router.replace({ pathname: '/(reader)/[surah]', params: { surah: String(surahId - 1) } })}
          >
            <MaterialIcons
              name="chevron-left"
              size={28}
              color={surahId <= 1 ? colors.border : colors.text}
            />
            <Text style={[styles.navLabel, { color: surahId <= 1 ? colors.border : colors.textSecondary }]}>
              Prev
            </Text>
          </TouchableOpacity>

          <Text style={[styles.surahNum, { color: colors.textSecondary }]}>
            Surah {surahId} of 114
          </Text>

          <TouchableOpacity
            style={styles.navBtn}
            disabled={surahId >= 114}
            onPress={() => router.replace({ pathname: '/(reader)/[surah]', params: { surah: String(surahId + 1) } })}
          >
            <Text style={[styles.navLabel, { color: surahId >= 114 ? colors.border : colors.textSecondary }]}>
              Next
            </Text>
            <MaterialIcons
              name="chevron-right"
              size={28}
              color={surahId >= 114 ? colors.border : colors.text}
            />
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 40 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 4,
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerBtn: { padding: 10 },
  headerCenter: { flex: 1, alignItems: 'center' },
  headerTitle: { fontSize: 16, fontWeight: '700' },
  headerSub: { fontSize: 11, marginTop: 1 },
  headerActions: { flexDirection: 'row' },
  bismillah: {
    paddingVertical: 20,
    paddingHorizontal: 16,
    alignItems: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  bismillahText: {
    textAlign: 'center',
    lineHeight: 48,
    writingDirection: 'rtl',
  },
  bottomNav: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  navBtn: { flexDirection: 'row', alignItems: 'center', padding: 8 },
  navLabel: { fontSize: 12 },
  surahNum: { fontSize: 13 },
});
