import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import type { DownloadState } from '../types/quran';
import type { ThemeColors } from '../constants/themes';

interface PackDownloaderProps {
  name: string;
  language: string;
  downloadState?: DownloadState;
  isDownloaded: boolean;
  colors: ThemeColors;
  onDownload: () => void;
  onDelete: () => void;
  onCancel: () => void;
}

export default function PackDownloader({
  name,
  language,
  downloadState,
  isDownloaded,
  colors,
  onDownload,
  onDelete,
  onCancel,
}: PackDownloaderProps) {
  const isDownloading = downloadState?.status === 'downloading';
  const progress = downloadState ? Math.round((downloadState.progress / downloadState.total) * 100) : 0;

  return (
    <View style={[styles.container, { borderColor: colors.border, backgroundColor: colors.surface }]}>
      <View style={styles.info}>
        <Text style={[styles.name, { color: colors.text }]}>{name}</Text>
        <Text style={[styles.lang, { color: colors.textSecondary }]}>{language.toUpperCase()}</Text>
      </View>

      <View style={styles.actions}>
        {isDownloading ? (
          <>
            <View style={styles.progressBar}>
              <View
                style={[
                  styles.progressFill,
                  { backgroundColor: colors.primary, width: `${progress}%` },
                ]}
              />
            </View>
            <Text style={[styles.progressText, { color: colors.textSecondary }]}>
              {progress}%
            </Text>
            <TouchableOpacity onPress={onCancel} style={styles.actionBtn}>
              <MaterialIcons name="close" size={20} color={colors.textSecondary} />
            </TouchableOpacity>
          </>
        ) : isDownloaded ? (
          <TouchableOpacity onPress={onDelete} style={[styles.deleteBtn, { borderColor: colors.border }]}>
            <MaterialIcons name="delete-outline" size={18} color={colors.textSecondary} />
            <Text style={[styles.deleteBtnText, { color: colors.textSecondary }]}>Remove</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            onPress={onDownload}
            style={[styles.downloadBtn, { backgroundColor: colors.primary }]}
          >
            <MaterialIcons name="download" size={18} color={colors.onPrimary} />
            <Text style={[styles.downloadBtnText, { color: colors.onPrimary }]}>Download</Text>
          </TouchableOpacity>
        )}
      </View>

      {downloadState?.status === 'error' && (
        <Text style={[styles.errorText, { color: '#ef4444' }]}>
          {downloadState.error ?? 'Download failed'}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    marginBottom: 10,
  },
  info: {
    flex: 1,
    marginRight: 12,
  },
  name: {
    fontSize: 15,
    fontWeight: '500',
  },
  lang: {
    fontSize: 12,
    marginTop: 2,
  },
  actions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  progressBar: {
    width: 80,
    height: 4,
    backgroundColor: '#e5e7eb',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  progressText: {
    fontSize: 12,
    minWidth: 32,
  },
  actionBtn: {
    padding: 4,
  },
  downloadBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 20,
    gap: 4,
  },
  downloadBtnText: {
    fontSize: 13,
    fontWeight: '600',
  },
  deleteBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 20,
    borderWidth: 1,
    gap: 4,
  },
  deleteBtnText: {
    fontSize: 13,
  },
  errorText: {
    position: 'absolute',
    bottom: 4,
    left: 14,
    fontSize: 11,
  },
});
