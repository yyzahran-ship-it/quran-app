import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import { useSearch } from '../../hooks/useSearch';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { useLibraryStore } from '../../stores/useLibraryStore';
import { THEMES } from '../../constants/themes';
import type { SearchResult } from '../../types/quran';

export default function SearchScreen() {
  const router = useRouter();
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];
  const activeTranslations = useLibraryStore((s) => s.activeTranslationIds);
  const { results, loading, query, search, clear } = useSearch();
  const [localQuery, setLocalQuery] = useState('');

  const handleChange = (text: string) => {
    setLocalQuery(text);
    if (!text.trim()) { clear(); return; }
    search({ query: text, editionSlug: activeTranslations[0] });
  };

  const renderResult = ({ item }: { item: SearchResult }) => (
    <TouchableOpacity
      style={[styles.result, { backgroundColor: colors.surface, borderColor: colors.border }]}
      onPress={() =>
        router.push({ pathname: '/(reader)/[surah]', params: { surah: String(item.surah_id) } })
      }
    >
      <View style={styles.resultHeader}>
        <Text style={[styles.refText, { color: colors.primary }]}>
          {item.surah_name} · {item.surah_id}:{item.ayah_number}
        </Text>
        <MaterialIcons name="chevron-right" size={18} color={colors.textSecondary} />
      </View>
      {item.arabic_snippet ? (
        <Text style={[styles.arabicSnippet, { color: colors.arabicText }]} numberOfLines={2}>
          {item.arabic_snippet}
        </Text>
      ) : null}
      {item.translation_snippet ? (
        <Text style={[styles.translationSnippet, { color: colors.textSecondary }]} numberOfLines={3}>
          {item.translation_snippet}
        </Text>
      ) : null}
    </TouchableOpacity>
  );

  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      <View style={[styles.searchBar, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        <MaterialIcons name="search" size={20} color={colors.textSecondary} />
        <TextInput
          value={localQuery}
          onChangeText={handleChange}
          placeholder="Search Arabic or translation…"
          placeholderTextColor={colors.textSecondary}
          style={[styles.searchInput, { color: colors.text }]}
          autoFocus
          returnKeyType="search"
        />
        {localQuery.length > 0 && (
          <TouchableOpacity onPress={() => { setLocalQuery(''); clear(); }}>
            <MaterialIcons name="close" size={18} color={colors.textSecondary} />
          </TouchableOpacity>
        )}
      </View>

      {loading && (
        <ActivityIndicator color={colors.primary} style={{ marginTop: 20 }} />
      )}

      <FlatList
        data={results}
        keyExtractor={(r) => `${r.ayah_id}-${r.edition_slug}`}
        renderItem={renderResult}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          !loading && localQuery.length > 0 ? (
            <Text style={[styles.empty, { color: colors.textSecondary }]}>
              No results for "{localQuery}"
            </Text>
          ) : !localQuery.length ? (
            <View style={styles.hint}>
              <MaterialIcons name="search" size={64} color={colors.textSecondary} style={{ opacity: 0.3 }} />
              <Text style={[styles.hintText, { color: colors.textSecondary }]}>
                Search in Arabic or English
              </Text>
            </View>
          ) : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    margin: 12,
    paddingHorizontal: 12,
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    gap: 8,
    height: 44,
  },
  searchInput: { flex: 1, fontSize: 15 },
  list: { padding: 12, paddingBottom: 80, gap: 10 },
  result: {
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 14,
  },
  resultHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 },
  refText: { fontSize: 13, fontWeight: '700' },
  arabicSnippet: { fontSize: 18, textAlign: 'right', writingDirection: 'rtl', marginBottom: 6, lineHeight: 28 },
  translationSnippet: { fontSize: 14, lineHeight: 20 },
  empty: { textAlign: 'center', marginTop: 40, fontSize: 15 },
  hint: { alignItems: 'center', marginTop: 80, gap: 16 },
  hintText: { fontSize: 15 },
});
