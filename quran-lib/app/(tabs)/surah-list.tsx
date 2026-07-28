import React, { useState, useMemo } from 'react';
import { View, Text, StyleSheet, TextInput, FlatList, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import { useSurahs } from '../../hooks/useAyahs';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { THEMES } from '../../constants/themes';
import type { Surah } from '../../types/quran';

type FilterType = 'all' | 'Meccan' | 'Medinan';

export default function SurahListScreen() {
  const router = useRouter();
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];
  const { surahs, loading } = useSurahs();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<FilterType>('all');

  const filtered = useMemo(() => {
    let list = surahs;
    if (filter !== 'all') list = list.filter((s) => s.revelation_type === filter);
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter(
        (s) =>
          s.name_english.toLowerCase().includes(q) ||
          s.name_transliteration.toLowerCase().includes(q) ||
          s.name_arabic.includes(q) ||
          String(s.id).includes(q)
      );
    }
    return list;
  }, [surahs, query, filter]);

  const renderItem = ({ item }: { item: Surah }) => (
    <TouchableOpacity
      style={[styles.item, { borderColor: colors.border }]}
      onPress={() =>
        router.push({ pathname: '/(reader)/[surah]', params: { surah: String(item.id) } })
      }
    >
      <View style={[styles.badge, { backgroundColor: colors.primary + '22' }]}>
        <Text style={[styles.badgeNum, { color: colors.primary }]}>{item.id}</Text>
      </View>
      <View style={styles.info}>
        <Text style={[styles.nameEn, { color: colors.text }]}>{item.name_english}</Text>
        <Text style={[styles.nameSub, { color: colors.textSecondary }]}>
          {item.name_transliteration} · {item.ayah_count} ayahs · {item.revelation_type}
        </Text>
      </View>
      <Text style={[styles.nameAr, { color: colors.arabicText }]}>{item.name_arabic}</Text>
    </TouchableOpacity>
  );

  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      {/* Search bar */}
      <View style={[styles.searchBar, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        <MaterialIcons name="search" size={20} color={colors.textSecondary} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder="Search surahs…"
          placeholderTextColor={colors.textSecondary}
          style={[styles.searchInput, { color: colors.text }]}
        />
        {query.length > 0 && (
          <TouchableOpacity onPress={() => setQuery('')}>
            <MaterialIcons name="close" size={18} color={colors.textSecondary} />
          </TouchableOpacity>
        )}
      </View>

      {/* Filter chips */}
      <View style={styles.filters}>
        {(['all', 'Meccan', 'Medinan'] as FilterType[]).map((f) => (
          <TouchableOpacity
            key={f}
            onPress={() => setFilter(f)}
            style={[
              styles.chip,
              {
                backgroundColor: filter === f ? colors.primary : colors.surfaceVariant,
                borderColor: colors.border,
              },
            ]}
          >
            <Text
              style={[styles.chipText, { color: filter === f ? colors.onPrimary : colors.text }]}
            >
              {f === 'all' ? 'All' : f}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={filtered}
        keyExtractor={(s) => String(s.id)}
        renderItem={renderItem}
        contentContainerStyle={styles.list}
        ItemSeparatorComponent={() => (
          <View style={[styles.separator, { backgroundColor: colors.border }]} />
        )}
        ListEmptyComponent={
          loading ? null : (
            <Text style={[styles.empty, { color: colors.textSecondary }]}>No surahs found</Text>
          )
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
  filters: { flexDirection: 'row', gap: 8, paddingHorizontal: 12, marginBottom: 8 },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
  },
  chipText: { fontSize: 13, fontWeight: '500' },
  list: { paddingBottom: 80 },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  badge: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
  },
  badgeNum: { fontSize: 15, fontWeight: '700' },
  info: { flex: 1 },
  nameEn: { fontSize: 16, fontWeight: '600' },
  nameSub: { fontSize: 12, marginTop: 2 },
  nameAr: { fontSize: 20, writingDirection: 'rtl' },
  separator: { height: StyleSheet.hairlineWidth, marginLeft: 74 },
  empty: { textAlign: 'center', marginTop: 60, fontSize: 15 },
});
