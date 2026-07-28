import React, { useCallback, useMemo, useRef, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator, ScrollView } from 'react-native';
import BottomSheet, { BottomSheetScrollView } from '@gorhom/bottom-sheet';
import { MaterialIcons } from '@expo/vector-icons';
import { useTafsir, useAvailableTafsirSources } from '../hooks/useTafsir';
import type { ThemeColors } from '../constants/themes';

interface TafsirSheetProps {
  ayahId: number | null;
  surahName: string;
  ayahNumber: number;
  colors: ThemeColors;
  onClose: () => void;
}

export default function TafsirSheet({
  ayahId,
  surahName,
  ayahNumber,
  colors,
  onClose,
}: TafsirSheetProps) {
  const bottomSheetRef = useRef<BottomSheet>(null);
  const snapPoints = useMemo(() => ['40%', '75%', '95%'], []);

  const availableSources = useAvailableTafsirSources();
  const [activeSlug, setActiveSlug] = useState<string | null>(
    availableSources[0]?.slug ?? null
  );
  const { tafsir, loading } = useTafsir(ayahId, activeSlug);

  const handleClose = useCallback(() => {
    bottomSheetRef.current?.close();
    onClose();
  }, [onClose]);

  return (
    <BottomSheet
      ref={bottomSheetRef}
      index={1}
      snapPoints={snapPoints}
      backgroundStyle={{ backgroundColor: colors.bottomSheet }}
      handleIndicatorStyle={{ backgroundColor: colors.textSecondary }}
    >
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <View>
          <Text style={[styles.headerTitle, { color: colors.text }]}>Tafsir</Text>
          <Text style={[styles.headerSub, { color: colors.textSecondary }]}>
            {surahName} · Verse {ayahNumber}
          </Text>
        </View>
        <TouchableOpacity onPress={handleClose} style={styles.closeBtn}>
          <MaterialIcons name="close" size={24} color={colors.textSecondary} />
        </TouchableOpacity>
      </View>

      {/* Source selector */}
      {availableSources.length > 1 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.sourceList}
        >
          {availableSources.map((source) => (
            <TouchableOpacity
              key={source.slug}
              onPress={() => setActiveSlug(source.slug)}
              style={[
                styles.sourceChip,
                {
                  backgroundColor:
                    activeSlug === source.slug ? colors.primary : colors.surfaceVariant,
                  borderColor: colors.border,
                },
              ]}
            >
              <Text
                style={[
                  styles.sourceChipText,
                  {
                    color:
                      activeSlug === source.slug ? colors.onPrimary : colors.text,
                  },
                ]}
              >
                {source.name}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      )}

      {/* Content */}
      <BottomSheetScrollView contentContainerStyle={styles.content}>
        {loading ? (
          <ActivityIndicator color={colors.primary} style={{ marginTop: 40 }} />
        ) : tafsir ? (
          <Text style={[styles.tafsirText, { color: colors.text }]}>
            {tafsir.text}
          </Text>
        ) : (
          <View style={styles.emptyState}>
            <MaterialIcons name="menu-book" size={48} color={colors.textSecondary} />
            <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
              {availableSources.length === 0
                ? 'No tafsir downloaded. Visit Library → Tafsirs to download one.'
                : 'No tafsir available for this verse.'}
            </Text>
          </View>
        )}
      </BottomSheetScrollView>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
  },
  headerSub: {
    fontSize: 13,
    marginTop: 2,
  },
  closeBtn: {
    padding: 4,
  },
  sourceList: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    gap: 8,
    flexDirection: 'row',
  },
  sourceChip: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: 1,
    marginRight: 8,
  },
  sourceChipText: {
    fontSize: 13,
    fontWeight: '500',
  },
  content: {
    padding: 16,
    paddingBottom: 60,
  },
  tafsirText: {
    fontSize: 15,
    lineHeight: 26,
  },
  emptyState: {
    alignItems: 'center',
    paddingTop: 48,
    gap: 16,
  },
  emptyText: {
    fontSize: 14,
    textAlign: 'center',
    lineHeight: 22,
    maxWidth: 280,
  },
});
