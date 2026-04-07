import { useState, useCallback } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  Alert, ScrollView, Linking,
} from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Glass, Spacing, Radius, Typography } from '@/constants/theme';
import { getApiKey, setApiKey, getSetting, setSetting, deleteSetting } from '@/lib/settings';
import GlassCard from '@/components/GlassCard';

export default function SettingsScreen() {
  const [anthropicKey, setAnthropicKey] = useState('');
  const [savedAnthropicKey, setSavedAnthropicKey] = useState<string | null>(null);
  const [tmdbKey, setTmdbKey] = useState('');
  const [savedTmdbKey, setSavedTmdbKey] = useState<string | null>(null);

  useFocusEffect(useCallback(() => {
    getApiKey().then(k => { setSavedAnthropicKey(k); if (k) setAnthropicKey(k); });
    getSetting('tmdb_api_key').then(k => { setSavedTmdbKey(k); if (k) setTmdbKey(k); });
  }, []));

  const saveAnthropicKey = async () => {
    const trimmed = anthropicKey.trim();
    if (!trimmed) { Alert.alert('Empty', 'Paste your Anthropic API key'); return; }
    if (!trimmed.startsWith('sk-ant-')) { Alert.alert('Invalid', 'Should start with sk-ant-'); return; }
    await setApiKey(trimmed);
    setSavedAnthropicKey(trimmed);
    Alert.alert('✓ Saved');
  };

  const saveTmdbKey = async () => {
    const trimmed = tmdbKey.trim();
    if (!trimmed) { Alert.alert('Empty', 'Paste your TMDb API key'); return; }
    await setSetting('tmdb_api_key', trimmed);
    setSavedTmdbKey(trimmed);
    Alert.alert('✓ Saved', 'Posters will appear on new scans.');
  };

  const deleteKey = (type: 'anthropic' | 'tmdb') => {
    Alert.alert('Remove key?', '', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Remove', style: 'destructive', onPress: async () => {
        if (type === 'anthropic') {
          await deleteSetting('anthropic_api_key');
          setAnthropicKey(''); setSavedAnthropicKey(null);
        } else {
          await deleteSetting('tmdb_api_key');
          setTmdbKey(''); setSavedTmdbKey(null);
        }
      }},
    ]);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Anthropic Key */}
      <GlassCard style={styles.section}>
        <Text style={styles.sectionTitle}>ANTHROPIC API KEY</Text>
        <Text style={styles.sectionDesc}>Required for ticket scanning.</Text>
        <KeyField
          value={anthropicKey}
          savedValue={savedAnthropicKey}
          onChange={setAnthropicKey}
          onSave={saveAnthropicKey}
          onDelete={() => deleteKey('anthropic')}
          placeholder="sk-ant-api03-..."
        />
        <TouchableOpacity style={styles.linkRow}
          onPress={() => Linking.openURL('https://console.anthropic.com/settings/keys')}>
          <Ionicons name="open-outline" size={14} color={Colors.amber} />
          <Text style={styles.linkText}>Get key from console.anthropic.com</Text>
        </TouchableOpacity>
      </GlassCard>

      {/* TMDb Key */}
      <GlassCard style={styles.section}>
        <Text style={styles.sectionTitle}>TMDB API KEY</Text>
        <Text style={styles.sectionDesc}>Optional — enables movie posters and descriptions on your tickets.</Text>
        <KeyField
          value={tmdbKey}
          savedValue={savedTmdbKey}
          onChange={setTmdbKey}
          onSave={saveTmdbKey}
          onDelete={() => deleteKey('tmdb')}
          placeholder="your tmdb api key..."
        />
        <TouchableOpacity style={styles.linkRow}
          onPress={() => Linking.openURL('https://www.themoviedb.org/settings/api')}>
          <Ionicons name="open-outline" size={14} color={Colors.amber} />
          <Text style={styles.linkText}>Get free key from themoviedb.org</Text>
        </TouchableOpacity>
      </GlassCard>

      {/* About */}
      <GlassCard style={styles.section}>
        <Text style={styles.sectionTitle}>ABOUT</Text>
        <AboutRow label="Version" value="1.0.0" />
        <AboutRow label="Model" value="Claude Sonnet 4" />
        <AboutRow label="Cost per scan" value="~$0.003" />
        <AboutRow label="Storage" value="Local (SQLite)" />
      </GlassCard>

      {/* Privacy */}
      <GlassCard style={styles.section}>
        <Text style={styles.sectionTitle}>PRIVACY</Text>
        <Text style={styles.privacyText}>
          Everything stored locally. Ticket images sent to Anthropic for parsing only. TMDb receives movie title text for poster lookup. API keys never leave your device except to authenticate.
        </Text>
      </GlassCard>
    </ScrollView>
  );
}

function KeyField({ value, savedValue, onChange, onSave, onDelete, placeholder }: {
  value: string; savedValue: string | null; onChange: (s: string) => void;
  onSave: () => void; onDelete: () => void; placeholder: string;
}) {
  if (savedValue) {
    const masked = `${savedValue.slice(0, 8)}...${savedValue.slice(-4)}`;
    return (
      <View style={styles.savedRow}>
        <Ionicons name="checkmark-circle" size={16} color={Colors.green} />
        <Text style={styles.savedText} numberOfLines={1}>{masked}</Text>
        <TouchableOpacity onPress={onDelete}><Ionicons name="trash-outline" size={16} color={Colors.red} /></TouchableOpacity>
      </View>
    );
  }
  return (
    <View>
      <TextInput style={styles.input} value={value} onChangeText={onChange}
        placeholder={placeholder} placeholderTextColor={Colors.textMuted}
        selectionColor={Colors.cream} autoCapitalize="none" autoCorrect={false} multiline />
      <TouchableOpacity style={styles.saveBtn} onPress={onSave}>
        <Text style={styles.saveBtnText}>Save</Text>
      </TouchableOpacity>
    </View>
  );
}

function AboutRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.aboutRow}>
      <Text style={styles.aboutLabel}>{label}</Text>
      <Text style={styles.aboutValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { padding: Spacing.md, paddingBottom: 120, gap: Spacing.md },
  section: { padding: Spacing.lg },
  sectionTitle: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, marginBottom: Spacing.xs },
  sectionDesc: { fontFamily: Typography.mono, fontSize: 12, color: Colors.textSecondary, lineHeight: 18, marginBottom: Spacing.md },
  input: { fontFamily: Typography.mono, fontSize: 13, color: Colors.cream, backgroundColor: 'rgba(255,255,255,0.04)', borderRadius: Radius.md, paddingHorizontal: Spacing.md, paddingVertical: Spacing.md, borderWidth: 0.5, borderColor: Colors.glassBorder },
  saveBtn: { alignItems: 'center', backgroundColor: Colors.cream, paddingVertical: 10, borderRadius: Radius.md, marginTop: Spacing.sm },
  saveBtnText: { fontFamily: Typography.mono, fontSize: 13, fontWeight: '700', color: Colors.bg },
  savedRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, backgroundColor: 'rgba(255,255,255,0.04)', padding: Spacing.md, borderRadius: Radius.md },
  savedText: { fontFamily: Typography.mono, fontSize: 12, color: Colors.cream, flex: 1 },
  linkRow: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: Spacing.md },
  linkText: { fontFamily: Typography.mono, fontSize: 11, color: Colors.amber },
  aboutRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderBottomWidth: 0.5, borderBottomColor: Colors.glassBorder },
  aboutLabel: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textSecondary },
  aboutValue: { fontFamily: Typography.mono, fontSize: 13, color: Colors.cream },
  privacyText: { fontFamily: Typography.mono, fontSize: 12, color: Colors.textSecondary, lineHeight: 18 },
});
