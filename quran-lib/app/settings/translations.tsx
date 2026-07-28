import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Alert } from 'react-native';
import PackDownloader from '../../components/PackDownloader';
import { TRANSLATIONS } from '../../constants/catalog';
import {
  downloadTranslation,
  deleteTranslation,
  getDownloadedTranslationSlugs,
  cancelDownload,
} from '../../services/LibraryManager';
import { useLibraryStore } from '../../stores/useLibraryStore';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { THEMES } from '../../constants/themes';

export default function TranslationsScreen() {
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];
  const { downloads, setDownloadState, clearDownload, activeTranslationIds, toggleTranslation } =
    useLibraryStore();
  const [downloaded, setDownloaded] = useState<Set<string>>(new Set());

  useEffect(() => {
    getDownloadedTranslationSlugs().then((slugs) => setDownloaded(new Set(slugs)));
  }, []);

  const handleDownload = async (id: string) => {
    const entry = TRANSLATIONS.find((t) => t.id === id);
    if (!entry) return;

    await downloadTranslation(entry, (state) => {
      setDownloadState(id, state);
      if (state.status === 'complete') {
        setDownloaded((prev) => new Set([...prev, id]));
        toggleTranslation(id);
        clearDownload(id);
      }
      if (state.status === 'error' || state.status === 'cancelled') {
        setTimeout(() => clearDownload(id), 3000);
      }
    });
  };

  const handleDelete = (id: string) => {
    Alert.alert('Delete Translation', `Remove "${TRANSLATIONS.find((t) => t.id === id)?.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await deleteTranslation(id);
          setDownloaded((prev) => {
            const next = new Set(prev);
            next.delete(id);
            return next;
          });
        },
      },
    ]);
  };

  const grouped = TRANSLATIONS.reduce<Record<string, typeof TRANSLATIONS>>((acc, t) => {
    const lang = t.language.toUpperCase();
    if (!acc[lang]) acc[lang] = [];
    acc[lang].push(t);
    return acc;
  }, {});

  return (
    <ScrollView
      style={{ backgroundColor: colors.background }}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.hint, { color: colors.textSecondary }]}>
        Download translations to use offline. Tap to activate after downloading.
      </Text>

      {Object.entries(grouped).map(([lang, entries]) => (
        <View key={lang} style={styles.group}>
          <Text style={[styles.groupLabel, { color: colors.textSecondary }]}>{lang}</Text>
          {entries.map((t) => (
            <PackDownloader
              key={t.id}
              name={t.name}
              language={t.language}
              downloadState={downloads[t.id]}
              isDownloaded={downloaded.has(t.id)}
              colors={colors}
              onDownload={() => handleDownload(t.id)}
              onDelete={() => handleDelete(t.id)}
              onCancel={() => cancelDownload(t.id)}
            />
          ))}
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: 16, paddingBottom: 60 },
  hint: { fontSize: 13, marginBottom: 20, lineHeight: 20 },
  group: { marginBottom: 24 },
  groupLabel: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 10 },
});
