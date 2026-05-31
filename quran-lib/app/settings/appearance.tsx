import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useReaderStore } from '../../stores/useReaderStore';
import { useSettingsStore } from '../../stores/useSettingsStore';
import { THEMES } from '../../constants/themes';
import type { Theme } from '../../types/quran';

export default function AppearanceScreen() {
  const theme = useSettingsStore((s) => s.theme);
  const setTheme = useSettingsStore((s) => s.setTheme);
  const colors = THEMES[theme];

  const { fontSize, setFontSize, translationSize, setTranslationSize, toggleTranslation, showTranslation, toggleTransliteration, showTransliteration } =
    useReaderStore();

  const THEMES_LIST: { key: Theme; label: string }[] = [
    { key: 'dark',  label: 'Dark' },
    { key: 'light', label: 'Light' },
    { key: 'sepia', label: 'Sepia' },
  ];

  return (
    <ScrollView
      style={{ backgroundColor: colors.background }}
      contentContainerStyle={styles.content}
    >
      {/* Theme */}
      <Section title="Theme" colors={colors}>
        <View style={styles.themeRow}>
          {THEMES_LIST.map(({ key, label }) => (
            <TouchableOpacity
              key={key}
              onPress={() => setTheme(key)}
              style={[
                styles.themeBtn,
                { backgroundColor: THEMES[key].surface, borderColor: key === theme ? colors.primary : colors.border },
              ]}
            >
              <View style={[styles.themePreview, { backgroundColor: THEMES[key].background }]}>
                <Text style={[styles.themePreviewText, { color: THEMES[key].arabicText }]}>ب</Text>
              </View>
              <Text style={[styles.themeBtnLabel, { color: key === theme ? colors.primary : colors.text }]}>
                {label}
              </Text>
              {key === theme && (
                <MaterialIcons name="check" size={16} color={colors.primary} style={styles.themeCheck} />
              )}
            </TouchableOpacity>
          ))}
        </View>
      </Section>

      {/* Arabic font size */}
      <Section title={`Arabic Font Size: ${fontSize}px`} colors={colors}>
        <View style={styles.sizeRow}>
          <TouchableOpacity
            style={[styles.sizeBtn, { backgroundColor: colors.surfaceVariant }]}
            onPress={() => setFontSize(fontSize - 2)}
          >
            <Text style={[styles.sizeBtnText, { color: colors.text }]}>A−</Text>
          </TouchableOpacity>
          <View style={[styles.sizeBar, { backgroundColor: colors.surfaceVariant }]}>
            <View
              style={[
                styles.sizeFill,
                { backgroundColor: colors.primary, width: `${((fontSize - 18) / 18) * 100}%` },
              ]}
            />
          </View>
          <TouchableOpacity
            style={[styles.sizeBtn, { backgroundColor: colors.surfaceVariant }]}
            onPress={() => setFontSize(fontSize + 2)}
          >
            <Text style={[styles.sizeBtnText, { color: colors.text }]}>A+</Text>
          </TouchableOpacity>
        </View>
        <Text style={[styles.preview, { color: colors.arabicText, fontSize }]}>
          بِسْمِ اللَّهِ
        </Text>
      </Section>

      {/* Translation font size */}
      <Section title={`Translation Size: ${translationSize}px`} colors={colors}>
        <View style={styles.sizeRow}>
          <TouchableOpacity
            style={[styles.sizeBtn, { backgroundColor: colors.surfaceVariant }]}
            onPress={() => setTranslationSize(translationSize - 1)}
          >
            <Text style={[styles.sizeBtnText, { color: colors.text }]}>T−</Text>
          </TouchableOpacity>
          <View style={[styles.sizeBar, { backgroundColor: colors.surfaceVariant }]}>
            <View
              style={[
                styles.sizeFill,
                { backgroundColor: colors.primary, width: `${((translationSize - 13) / 7) * 100}%` },
              ]}
            />
          </View>
          <TouchableOpacity
            style={[styles.sizeBtn, { backgroundColor: colors.surfaceVariant }]}
            onPress={() => setTranslationSize(translationSize + 1)}
          >
            <Text style={[styles.sizeBtnText, { color: colors.text }]}>T+</Text>
          </TouchableOpacity>
        </View>
        <Text style={[styles.preview, { color: colors.text, fontSize: translationSize }]}>
          In the name of Allah, the Entirely Merciful, the Especially Merciful.
        </Text>
      </Section>

      {/* Toggles */}
      <Section title="Display Options" colors={colors}>
        <ToggleRow label="Show Translation" value={showTranslation} onToggle={toggleTranslation} colors={colors} />
        <ToggleRow label="Show Transliteration" value={showTransliteration} onToggle={toggleTransliteration} colors={colors} />
      </Section>
    </ScrollView>
  );
}

function Section({ title, children, colors }: { title: string; children: React.ReactNode; colors: import('../../constants/themes').ThemeColors }) {
  return (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: colors.textSecondary }]}>{title.toUpperCase()}</Text>
      <View style={[styles.sectionCard, { backgroundColor: colors.surface, borderColor: colors.border }]}>
        {children}
      </View>
    </View>
  );
}

function ToggleRow({ label, value, onToggle, colors }: { label: string; value: boolean; onToggle: () => void; colors: import('../../constants/themes').ThemeColors }) {
  return (
    <TouchableOpacity
      onPress={onToggle}
      style={[styles.toggleRow, { borderTopColor: colors.border }]}
    >
      <Text style={[styles.toggleLabel, { color: colors.text }]}>{label}</Text>
      <View style={[styles.toggle, { backgroundColor: value ? colors.primary : colors.surfaceVariant }]}>
        <View style={[styles.toggleThumb, { transform: [{ translateX: value ? 20 : 2 }] }]} />
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  content: { padding: 16, paddingBottom: 60 },
  section: { marginBottom: 24 },
  sectionTitle: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 10 },
  sectionCard: { borderRadius: 12, borderWidth: StyleSheet.hairlineWidth, overflow: 'hidden', padding: 16 },
  themeRow: { flexDirection: 'row', gap: 10 },
  themeBtn: {
    flex: 1,
    alignItems: 'center',
    borderRadius: 10,
    borderWidth: 2,
    padding: 10,
    gap: 6,
  },
  themePreview: { width: 48, height: 48, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  themePreviewText: { fontSize: 20 },
  themeBtnLabel: { fontSize: 13, fontWeight: '600' },
  themeCheck: { position: 'absolute', top: 6, right: 6 },
  sizeRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 12 },
  sizeBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  sizeBtnText: { fontSize: 14, fontWeight: '700' },
  sizeBar: { flex: 1, height: 4, borderRadius: 2, overflow: 'hidden' },
  sizeFill: { height: '100%', borderRadius: 2 },
  preview: { lineHeight: 36, textAlign: 'center', writingDirection: 'rtl' },
  toggleRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 14, borderTopWidth: StyleSheet.hairlineWidth },
  toggleLabel: { fontSize: 15 },
  toggle: { width: 44, height: 24, borderRadius: 12 },
  toggleThumb: { width: 20, height: 20, backgroundColor: '#fff', borderRadius: 10, position: 'absolute', top: 2, shadowColor: '#000', shadowOpacity: 0.15, shadowRadius: 2, shadowOffset: { width: 0, height: 1 } },
});
