import React, { memo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  TouchableHighlight,
  Pressable,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import type { AyahWithTranslations } from '../types/quran';
import type { ThemeColors } from '../constants/themes';
import { useBookmarkStore } from '../stores/useBookmarkStore';

interface AyahRowProps {
  ayah: AyahWithTranslations;
  colors: ThemeColors;
  arabicFontSize: number;
  translationFontSize: number;
  showTranslation: boolean;
  showTransliteration: boolean;
  isHighlighted?: boolean;
  onLongPress?: () => void;       // opens tafsir
  onWordPress?: (wordIndex: number) => void;
  onBookmark?: () => void;
  onShare?: () => void;
  onPlayAudio?: () => void;
}

const AyahRow = memo(function AyahRow({
  ayah,
  colors,
  arabicFontSize,
  translationFontSize,
  showTranslation,
  showTransliteration,
  isHighlighted,
  onLongPress,
  onWordPress,
  onBookmark,
  onShare,
  onPlayAudio,
}: AyahRowProps) {
  const [toolbarVisible, setToolbarVisible] = useState(false);
  const bookmark = useBookmarkStore((s) => s.getBookmarkForAyah(ayah.id));
  const isBookmarked = !!bookmark;

  const bgColor = isHighlighted ? colors.highlight : 'transparent';

  return (
    <Pressable
      onPress={() => setToolbarVisible((v) => !v)}
      onLongPress={onLongPress}
      style={[styles.container, { backgroundColor: bgColor }]}
    >
      {/* Ayah number badge */}
      <View style={[styles.numberBadge, { borderColor: colors.primary }]}>
        <Text style={[styles.numberText, { color: colors.primary }]}>
          {ayah.ayah_number}
        </Text>
      </View>

      {/* Arabic text — right-to-left */}
      <Text
        style={[
          styles.arabicText,
          {
            fontSize: arabicFontSize,
            color: colors.arabicText,
            // fontFamily: 'KFGQPC-Uthmanic',  // uncomment when font is loaded
          },
        ]}
      >
        {ayah.text_uthmani}
      </Text>

      {/* Translation(s) */}
      {showTranslation && ayah.translations.map((t) => (
        <View key={t.edition_slug} style={[styles.translationBlock, { borderLeftColor: colors.primary }]}>
          <Text style={[styles.editionLabel, { color: colors.textSecondary }]}>
            {t.edition_slug}
          </Text>
          <Text style={[styles.translationText, { fontSize: translationFontSize, color: colors.text }]}>
            {t.text}
          </Text>
        </View>
      ))}

      {/* Separator */}
      <View style={[styles.separator, { backgroundColor: colors.border }]} />

      {/* Inline toolbar */}
      {toolbarVisible && (
        <View style={[styles.toolbar, { backgroundColor: colors.surfaceVariant, borderColor: colors.border }]}>
          <ToolbarButton icon="bookmark" active={isBookmarked} color={colors} onPress={onBookmark} />
          <ToolbarButton icon="content-copy" color={colors} onPress={() => {}} />
          <ToolbarButton icon="share" color={colors} onPress={onShare} />
          <ToolbarButton icon="menu-book" color={colors} onPress={onLongPress} />
          <ToolbarButton icon="play-circle-outline" color={colors} onPress={onPlayAudio} />
        </View>
      )}
    </Pressable>
  );
});

function ToolbarButton({
  icon,
  active,
  color,
  onPress,
}: {
  icon: string;
  active?: boolean;
  color: ThemeColors;
  onPress?: () => void;
}) {
  return (
    <TouchableOpacity onPress={onPress} style={styles.toolbarBtn}>
      <MaterialIcons
        name={icon as any}
        size={22}
        color={active ? color.primary : color.textSecondary}
      />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  numberBadge: {
    alignSelf: 'flex-end',
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  numberText: {
    fontSize: 12,
    fontWeight: '600',
  },
  arabicText: {
    textAlign: 'right',
    lineHeight: 52,
    fontWeight: '400',
    writingDirection: 'rtl',
  },
  translationBlock: {
    marginTop: 8,
    paddingLeft: 10,
    borderLeftWidth: 2,
  },
  editionLabel: {
    fontSize: 10,
    marginBottom: 2,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  translationText: {
    lineHeight: 22,
  },
  separator: {
    height: 1,
    marginTop: 12,
    opacity: 0.3,
  },
  toolbar: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
    marginTop: 8,
    borderRadius: 8,
    borderWidth: 1,
    paddingVertical: 6,
  },
  toolbarBtn: {
    padding: 6,
  },
});

export default AyahRow;
