import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, Alert } from 'react-native';
import PackDownloader from '../../components/PackDownloader';
import { TAFSIRS } from '../../constants/catalog';
import {
  downloadTafsir,
  deleteTafsir,
  getDownloadedTafsirSlugs,
  cancelDownload,
} from '../../services/LibraryManager';
import { useLibraryStore } from '../../stores/useLibraryStore';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { THEMES } from '../../constants/themes';

export default function TafsirsScreen() {
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];
  const { downloads, setDownloadState, clearDownload, activeTafsirIds, toggleTafsir } =
    useLibraryStore();
  const [downloaded, setDownloaded] = useState<Set<string>>(new Set());

  useEffect(() => {
    getDownloadedTafsirSlugs().then((slugs) => setDownloaded(new Set(slugs)));
  }, []);

  const handleDownload = async (id: string) => {
    const entry = TAFSIRS.find((t) => t.id === id);
    if (!entry) return;

    await downloadTafsir(entry, (state) => {
      setDownloadState(id, state);
      if (state.status === 'complete') {
        setDownloaded((prev) => new Set([...prev, id]));
        toggleTafsir(id);
        clearDownload(id);
      }
      if (state.status === 'error' || state.status === 'cancelled') {
        setTimeout(() => clearDownload(id), 3000);
      }
    });
  };

  const handleDelete = (id: string) => {
    const t = TAFSIRS.find((t) => t.id === id);
    Alert.alert('Delete Tafsir', `Remove "${t?.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await deleteTafsir(id);
          setDownloaded((prev) => {
            const next = new Set(prev);
            next.delete(id);
            return next;
          });
        },
      },
    ]);
  };

  return (
    <ScrollView
      style={{ backgroundColor: colors.background }}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.hint, { color: colors.textSecondary }]}>
        Download tafsir packs to read explanations while offline.
        Long-press any ayah in the reader to open tafsir.
      </Text>

      {TAFSIRS.map((t) => (
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
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: 16, paddingBottom: 60 },
  hint: { fontSize: 13, marginBottom: 20, lineHeight: 20 },
});
