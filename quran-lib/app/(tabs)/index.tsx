import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Pressable,
} from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { useBookmarkStore } from '../../stores/useBookmarkStore';
import { useSurahs } from '../../hooks/useAyahs';
import { THEMES } from '../../constants/themes';

const DAILY_AYAHS = [
  { surahId: 2, ayahNumber: 255, arabic: 'آيةُ الكُرسِيّ', label: 'Ayat Al-Kursi' },
  { surahId: 1, ayahNumber: 1,   arabic: 'الفاتحة',         label: 'Al-Fatiha' },
  { surahId: 112, ayahNumber: 1, arabic: 'الإخلاص',         label: 'Al-Ikhlas' },
];

export default function HomeScreen() {
  const router = useRouter();
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];
  const { lastReads, loadBookmarks } = useBookmarkStore();
  const { surahs } = useSurahs();

  useEffect(() => { loadBookmarks(); }, []);

  const dailyAyah = DAILY_AYAHS[new Date().getDate() % DAILY_AYAHS.length];

  return (
    <ScrollView
      style={{ backgroundColor: colors.background }}
      contentContainerStyle={styles.content}
    >
      {/* Greeting */}
      <Text style={[styles.greeting, { color: colors.textSecondary }]}>
        {getGreeting()}
      </Text>
      <Text style={[styles.title, { color: colors.text }]}>QuranLib</Text>
      <Text style={[styles.arabic, { color: colors.arabicText }]}>مكتبة القرآن الكريم</Text>

      {/* Daily Ayah card */}
      <Pressable
        style={[styles.card, { backgroundColor: colors.surface, borderColor: colors.border }]}
        onPress={() =>
          router.push({ pathname: '/(reader)/[surah]', params: { surah: String(dailyAyah.surahId) } })
        }
      >
        <View style={styles.cardHeader}>
          <MaterialIcons name="auto-awesome" size={16} color={colors.primary} />
          <Text style={[styles.cardLabel, { color: colors.primary }]}>Daily Verse</Text>
        </View>
        <Text style={[styles.dailyArabic, { color: colors.arabicText }]}>
          {dailyAyah.arabic}
        </Text>
        <Text style={[styles.dailyLabel, { color: colors.textSecondary }]}>
          {dailyAyah.label}
        </Text>
      </Pressable>

      {/* Continue reading */}
      {lastReads.length > 0 && (
        <Section title="Continue Reading" colors={colors}>
          {lastReads.slice(0, 3).map((lr) => {
            const surah = surahs.find((s) => s.id === lr.surah_id);
            return (
              <TouchableOpacity
                key={lr.id}
                style={[styles.lastReadItem, { backgroundColor: colors.surface, borderColor: colors.border }]}
                onPress={() =>
                  router.push({ pathname: '/(reader)/[surah]', params: { surah: String(lr.surah_id) } })
                }
              >
                <View style={[styles.surahNumberBadge, { backgroundColor: colors.primary + '22' }]}>
                  <Text style={[styles.surahNumber, { color: colors.primary }]}>{lr.surah_id}</Text>
                </View>
                <View style={styles.lastReadInfo}>
                  <Text style={[styles.lastReadName, { color: colors.text }]}>
                    {surah?.name_english ?? `Surah ${lr.surah_id}`}
                  </Text>
                  <Text style={[styles.lastReadSub, { color: colors.textSecondary }]}>
                    {surah?.name_transliteration} · Ayah {lr.ayah_id}
                  </Text>
                </View>
                <MaterialIcons name="chevron-right" size={20} color={colors.textSecondary} />
              </TouchableOpacity>
            );
          })}
        </Section>
      )}

      {/* Quick navigation */}
      <Section title="Quick Navigation" colors={colors}>
        <View style={styles.quickNav}>
          {[
            { icon: 'book', label: 'Surah 1', onPress: () => router.push({ pathname: '/(reader)/[surah]', params: { surah: '1' } }) },
            { icon: 'search', label: 'Search', onPress: () => router.push('/(tabs)/search') },
            { icon: 'bookmark', label: 'Bookmarks', onPress: () => router.push('/(tabs)/library') },
            { icon: 'settings', label: 'Settings', onPress: () => router.push('/settings/appearance') },
          ].map((item) => (
            <TouchableOpacity
              key={item.label}
              style={[styles.quickNavBtn, { backgroundColor: colors.surface, borderColor: colors.border }]}
              onPress={item.onPress}
            >
              <MaterialIcons name={item.icon as any} size={24} color={colors.primary} />
              <Text style={[styles.quickNavLabel, { color: colors.text }]}>{item.label}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </Section>
    </ScrollView>
  );
}

function Section({
  title,
  children,
  colors,
}: {
  title: string;
  children: React.ReactNode;
  colors: import('../../constants/themes').ThemeColors;
}) {
  return (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>{title.toUpperCase()}</Text>
      {children}
    </View>
  );
}

function getGreeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

const styles = StyleSheet.create({
  content: { padding: 20, paddingBottom: 40 },
  greeting: { fontSize: 14, marginBottom: 2 },
  title: { fontSize: 28, fontWeight: '700', marginBottom: 4 },
  arabic: { fontSize: 20, marginBottom: 24, writingDirection: 'rtl' },
  card: {
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 20,
    marginBottom: 28,
  },
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 12 },
  cardLabel: { fontSize: 13, fontWeight: '600' },
  dailyArabic: { fontSize: 22, textAlign: 'center', writingDirection: 'rtl', marginBottom: 8 },
  dailyLabel: { fontSize: 14, textAlign: 'center' },
  section: { marginBottom: 24 },
  sectionTitle: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 12 },
  lastReadItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    marginBottom: 8,
  },
  surahNumberBadge: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  surahNumber: { fontSize: 16, fontWeight: '700' },
  lastReadInfo: { flex: 1 },
  lastReadName: { fontSize: 15, fontWeight: '600' },
  lastReadSub: { fontSize: 13, marginTop: 2 },
  quickNav: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  quickNavBtn: {
    width: '47%',
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 16,
    alignItems: 'center',
    gap: 8,
  },
  quickNavLabel: { fontSize: 13, fontWeight: '500' },
});
