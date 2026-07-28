import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { ThemeColors } from '../constants/themes';

interface TranslationBadgeProps {
  slug: string;
  colors: ThemeColors;
}

const SLUG_LABELS: Record<string, string> = {
  'en.sahih':    'Sahih Int\'l',
  'en.pickthall': 'Pickthall',
  'en.yusufali': 'Yusuf Ali',
  'en.asad':     'Asad',
  'ar.muyassar': 'الميسر',
  'ar.jalalayn': 'الجلالين',
  'ur.jalandhry': 'جالندھری',
  'fr.hamidullah': 'Hamidullah',
};

export default function TranslationBadge({ slug, colors }: TranslationBadgeProps) {
  const label = SLUG_LABELS[slug] ?? slug;
  return (
    <View style={[styles.badge, { backgroundColor: colors.surfaceVariant }]}>
      <Text style={[styles.text, { color: colors.textSecondary }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
    alignSelf: 'flex-start',
    marginBottom: 4,
  },
  text: {
    fontSize: 10,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
});
