import React from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, Pressable } from 'react-native';
import type { Word } from '../types/quran';
import type { ThemeColors } from '../constants/themes';

interface WordPopupProps {
  word: Word | null;
  colors: ThemeColors;
  onClose: () => void;
}

export default function WordPopup({ word, colors, onClose }: WordPopupProps) {
  if (!word) return null;

  return (
    <Modal transparent animationType="fade" visible={!!word} onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose}>
        <Pressable
          style={[
            styles.card,
            { backgroundColor: colors.surface, borderColor: colors.border },
          ]}
        >
          {/* Arabic word */}
          <Text style={[styles.arabic, { color: colors.arabicText }]}>
            {word.text_arabic}
          </Text>

          {/* Transliteration */}
          {word.transliteration && (
            <Text style={[styles.transliteration, { color: colors.textSecondary }]}>
              {word.transliteration}
            </Text>
          )}

          <View style={[styles.divider, { backgroundColor: colors.border }]} />

          {/* Root */}
          {word.root && (
            <Row label="Root" value={word.root} colors={colors} arabic />
          )}

          {/* Lemma */}
          {word.lemma && (
            <Row label="Lemma" value={word.lemma} colors={colors} arabic />
          )}

          {/* Morphology */}
          {word.morphology_tag && (
            <Row label="Grammar" value={word.morphology_tag} colors={colors} />
          )}

          <TouchableOpacity onPress={onClose} style={[styles.closeBtn, { backgroundColor: colors.surfaceVariant }]}>
            <Text style={[styles.closeBtnText, { color: colors.text }]}>Dismiss</Text>
          </TouchableOpacity>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

function Row({
  label,
  value,
  colors,
  arabic,
}: {
  label: string;
  value: string;
  colors: ThemeColors;
  arabic?: boolean;
}) {
  return (
    <View style={styles.row}>
      <Text style={[styles.label, { color: colors.textSecondary }]}>{label}</Text>
      <Text
        style={[
          styles.value,
          { color: colors.text },
          arabic && { fontWeight: '700', fontSize: 16, writingDirection: 'rtl' },
        ]}
      >
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    width: 280,
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 20,
    alignItems: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
  },
  arabic: {
    fontSize: 32,
    lineHeight: 48,
    textAlign: 'center',
  },
  transliteration: {
    fontSize: 14,
    marginTop: 4,
    fontStyle: 'italic',
  },
  divider: {
    width: '80%',
    height: StyleSheet.hairlineWidth,
    marginVertical: 16,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    width: '100%',
    marginBottom: 10,
  },
  label: {
    fontSize: 13,
    fontWeight: '500',
  },
  value: {
    fontSize: 14,
    maxWidth: '65%',
    textAlign: 'right',
  },
  closeBtn: {
    marginTop: 12,
    paddingHorizontal: 24,
    paddingVertical: 10,
    borderRadius: 20,
  },
  closeBtnText: {
    fontSize: 14,
    fontWeight: '600',
  },
});
