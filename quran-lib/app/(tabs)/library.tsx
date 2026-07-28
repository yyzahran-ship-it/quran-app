import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  Alert,
  Share,
} from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialIcons } from '@expo/vector-icons';
import { useBookmarkStore } from '../../stores/useBookmarkStore';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { useSurahs } from '../../hooks/useAyahs';
import { THEMES } from '../../constants/themes';
import type { Bookmark } from '../../types/quran';

type Tab = 'bookmarks' | 'plans';

export default function LibraryScreen() {
  const router = useRouter();
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];
  const { bookmarks, collections, loadBookmarks, removeBookmark } = useBookmarkStore();
  const { surahs } = useSurahs();
  const [activeTab, setActiveTab] = useState<Tab>('bookmarks');
  const [activeCollection, setActiveCollection] = useState('Favourites');

  useEffect(() => { loadBookmarks(); }, []);

  const filtered = bookmarks.filter((b) => b.collection_name === activeCollection);

  const handleDelete = (b: Bookmark) => {
    Alert.alert('Remove Bookmark', 'Remove this bookmark?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Remove', style: 'destructive', onPress: () => removeBookmark(b.id) },
    ]);
  };

  const handleExport = async () => {
    const lines = filtered.map((b) => {
      const surah = surahs.find((s) => {
        // ayah_id is global ayah id — approximate surah lookup
        return true;
      });
      return `Ayah ${b.ayah_id}${b.note ? `\nNote: ${b.note}` : ''}`;
    });
    await Share.share({ message: `My Quran Bookmarks — ${activeCollection}\n\n${lines.join('\n\n')}` });
  };

  const renderBookmark = ({ item }: { item: Bookmark }) => (
    <TouchableOpacity
      style={[styles.bItem, { backgroundColor: colors.surface, borderColor: colors.border }]}
      onPress={() => {
        // Navigate to ayah — we'd need to resolve surah from ayah_id
        router.push({ pathname: '/(reader)/[surah]', params: { surah: '1' } });
      }}
      onLongPress={() => handleDelete(item)}
    >
      <View style={styles.bInfo}>
        <Text style={[styles.bRef, { color: colors.primary }]}>
          Ayah {item.ayah_id}
        </Text>
        {item.note && (
          <Text style={[styles.bNote, { color: colors.textSecondary }]} numberOfLines={2}>
            {item.note}
          </Text>
        )}
        <Text style={[styles.bDate, { color: colors.textSecondary }]}>
          {new Date(item.created_at).toLocaleDateString()}
        </Text>
      </View>
      <MaterialIcons name="bookmark" size={20} color={colors.primary} />
    </TouchableOpacity>
  );

  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      {/* Tab bar */}
      <View style={[styles.tabBar, { borderBottomColor: colors.border }]}>
        {(['bookmarks', 'plans'] as Tab[]).map((t) => (
          <TouchableOpacity
            key={t}
            onPress={() => setActiveTab(t)}
            style={[styles.tab, activeTab === t && { borderBottomColor: colors.primary, borderBottomWidth: 2 }]}
          >
            <Text style={[styles.tabText, { color: activeTab === t ? colors.primary : colors.textSecondary }]}>
              {t === 'bookmarks' ? 'Bookmarks' : 'Reading Plans'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {activeTab === 'bookmarks' && (
        <>
          {/* Collection chips */}
          <View style={styles.collections}>
            {collections.map((c) => (
              <TouchableOpacity
                key={c}
                onPress={() => setActiveCollection(c)}
                style={[
                  styles.collChip,
                  {
                    backgroundColor: activeCollection === c ? colors.primary : colors.surfaceVariant,
                    borderColor: colors.border,
                  },
                ]}
              >
                <Text style={[styles.collText, { color: activeCollection === c ? colors.onPrimary : colors.text }]}>
                  {c}
                </Text>
              </TouchableOpacity>
            ))}

            {filtered.length > 0 && (
              <TouchableOpacity onPress={handleExport} style={styles.exportBtn}>
                <MaterialIcons name="share" size={16} color={colors.textSecondary} />
              </TouchableOpacity>
            )}
          </View>

          <FlatList
            data={filtered}
            keyExtractor={(b) => String(b.id)}
            renderItem={renderBookmark}
            contentContainerStyle={styles.list}
            ListEmptyComponent={
              <View style={styles.emptyState}>
                <MaterialIcons name="bookmark-border" size={64} color={colors.textSecondary} style={{ opacity: 0.3 }} />
                <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
                  No bookmarks yet.{'\n'}Long-press any ayah while reading.
                </Text>
              </View>
            }
          />
        </>
      )}

      {activeTab === 'plans' && (
        <View style={styles.emptyState}>
          <MaterialIcons name="calendar-today" size={64} color={colors.textSecondary} style={{ opacity: 0.3 }} />
          <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
            Reading plans coming soon.
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  tabBar: { flexDirection: 'row', borderBottomWidth: StyleSheet.hairlineWidth },
  tab: { flex: 1, paddingVertical: 14, alignItems: 'center' },
  tabText: { fontSize: 14, fontWeight: '600' },
  collections: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, padding: 12, alignItems: 'center' },
  collChip: { paddingHorizontal: 14, paddingVertical: 6, borderRadius: 20, borderWidth: StyleSheet.hairlineWidth },
  collText: { fontSize: 13, fontWeight: '500' },
  exportBtn: { padding: 6 },
  list: { padding: 12, gap: 10, paddingBottom: 80 },
  bItem: { flexDirection: 'row', alignItems: 'center', padding: 14, borderRadius: 12, borderWidth: StyleSheet.hairlineWidth },
  bInfo: { flex: 1, marginRight: 8 },
  bRef: { fontSize: 14, fontWeight: '700' },
  bNote: { fontSize: 13, marginTop: 4, lineHeight: 18 },
  bDate: { fontSize: 11, marginTop: 4 },
  emptyState: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 16, paddingTop: 80 },
  emptyText: { fontSize: 15, textAlign: 'center', lineHeight: 24, maxWidth: 260 },
});
