import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { Stack } from 'expo-router';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { StatusBar } from 'expo-status-bar';
import { needsSeeding, runSeed, SeedProgress } from '../services/SeedService';
import { useSettingsStore } from '../stores/useSettingsStore';
import { THEMES } from '../constants/themes';

export default function RootLayout() {
  const [seeding, setSeeding] = useState<boolean | null>(null);
  const [progress, setProgress] = useState<SeedProgress | null>(null);
  const theme = useSettingsStore((s) => s.theme);
  const colors = THEMES[theme];

  useEffect(() => {
    needsSeeding().then((needs) => {
      if (!needs) {
        setSeeding(false);
        return;
      }
      setSeeding(true);
      runSeed((p) => setProgress(p))
        .catch((e) => console.error('Seed failed:', e))
        .finally(() => setSeeding(false));
    });
  }, []);

  if (seeding === null || seeding === true) {
    return (
      <View style={[styles.splash, { backgroundColor: colors.background }]}>
        <Text style={[styles.appName, { color: colors.primary }]}>QuranLib</Text>
        <Text style={[styles.arabicTitle, { color: colors.arabicText }]}>مكتبة القرآن الكريم</Text>
        <ActivityIndicator color={colors.primary} size="large" style={styles.spinner} />
        {progress && (
          <>
            <Text style={[styles.stageText, { color: colors.textSecondary }]}>
              {progress.stage}
            </Text>
            {progress.total > 1 && (
              <>
                <View style={[styles.progressBar, { backgroundColor: colors.surfaceVariant }]}>
                  <View
                    style={[
                      styles.progressFill,
                      {
                        backgroundColor: colors.primary,
                        width: `${Math.round((progress.done / progress.total) * 100)}%`,
                      },
                    ]}
                  />
                </View>
                <Text style={[styles.progressCount, { color: colors.textSecondary }]}>
                  {progress.done.toLocaleString()} / {progress.total.toLocaleString()}
                </Text>
              </>
            )}
          </>
        )}
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <StatusBar style={colors.statusBar} />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.surface },
          headerTintColor: colors.text,
          headerShadowVisible: false,
          contentStyle: { backgroundColor: colors.background },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="(reader)/[surah]"
          options={{
            title: '',
            headerTransparent: true,
          }}
        />
        <Stack.Screen name="settings/translations" options={{ title: 'Translations' }} />
        <Stack.Screen name="settings/tafsirs" options={{ title: 'Tafsirs' }} />
        <Stack.Screen name="settings/appearance" options={{ title: 'Appearance' }} />
      </Stack>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  },
  appName: {
    fontSize: 32,
    fontWeight: '700',
    letterSpacing: 1,
  },
  arabicTitle: {
    fontSize: 22,
    marginTop: 8,
    writingDirection: 'rtl',
  },
  spinner: {
    marginTop: 40,
  },
  stageText: {
    marginTop: 16,
    fontSize: 14,
    textAlign: 'center',
  },
  progressBar: {
    width: 260,
    height: 4,
    borderRadius: 2,
    overflow: 'hidden',
    marginTop: 12,
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  progressCount: {
    marginTop: 6,
    fontSize: 12,
  },
});
