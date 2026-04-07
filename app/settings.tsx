import { useState, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ScrollView,
  Linking,
} from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { getApiKey, setApiKey, deleteSetting } from '@/lib/settings';

export default function SettingsScreen() {
  const [apiKey, setApiKeyState] = useState('');
  const [savedKey, setSavedKey] = useState<string | null>(null);
  const [showKey, setShowKey] = useState(false);

  useFocusEffect(
    useCallback(() => {
      getApiKey().then((key) => {
        setSavedKey(key);
        if (key) setApiKeyState(key);
      });
    }, [])
  );

  const handleSave = async () => {
    const trimmed = apiKey.trim();
    if (!trimmed) {
      Alert.alert('Empty key', 'Paste your Anthropic API key first');
      return;
    }
    if (!trimmed.startsWith('sk-ant-')) {
      Alert.alert(
        'Invalid key',
        'Anthropic API keys start with sk-ant-. Double-check and try again.'
      );
      return;
    }
    await setApiKey(trimmed);
    setSavedKey(trimmed);
    Alert.alert('✓ Saved', 'API key stored locally on your device.');
  };

  const handleDelete = () => {
    Alert.alert('Remove API key?', 'You won\'t be able to scan tickets until you add a new one.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Remove',
        style: 'destructive',
        onPress: async () => {
          await deleteSetting('anthropic_api_key');
          setApiKeyState('');
          setSavedKey(null);
        },
      },
    ]);
  };

  const maskedKey = savedKey
    ? `${savedKey.slice(0, 10)}...${savedKey.slice(-6)}`
    : null;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* API Key Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>ANTHROPIC API KEY</Text>
        <Text style={styles.sectionDesc}>
          Required for ticket scanning. Your key is stored locally on this device only — never sent anywhere except Anthropic's API.
        </Text>

        {savedKey ? (
          <View style={styles.savedKeyContainer}>
            <View style={styles.savedKeyRow}>
              <Ionicons name="checkmark-circle" size={18} color={Colors.green} />
              <Text style={styles.savedKeyText}>
                {showKey ? savedKey : maskedKey}
              </Text>
            </View>
            <View style={styles.savedKeyActions}>
              <TouchableOpacity
                style={styles.smallBtn}
                onPress={() => setShowKey(!showKey)}
              >
                <Ionicons
                  name={showKey ? 'eye-off-outline' : 'eye-outline'}
                  size={16}
                  color={Colors.textSecondary}
                />
              </TouchableOpacity>
              <TouchableOpacity style={styles.smallBtn} onPress={handleDelete}>
                <Ionicons name="trash-outline" size={16} color={Colors.red} />
              </TouchableOpacity>
            </View>
          </View>
        ) : (
          <>
            <TextInput
              style={styles.input}
              value={apiKey}
              onChangeText={setApiKeyState}
              placeholder="sk-ant-api03-..."
              placeholderTextColor={Colors.textMuted}
              selectionColor={Colors.cream}
              autoCapitalize="none"
              autoCorrect={false}
              multiline
            />
            <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
              <Ionicons name="key" size={18} color={Colors.bg} />
              <Text style={styles.saveBtnText}>Save Key</Text>
            </TouchableOpacity>
          </>
        )}

        <TouchableOpacity
          style={styles.linkRow}
          onPress={() => Linking.openURL('https://console.anthropic.com/settings/keys')}
        >
          <Ionicons name="open-outline" size={14} color={Colors.amber} />
          <Text style={styles.linkText}>Get an API key from console.anthropic.com</Text>
        </TouchableOpacity>
      </View>

      {/* About Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>ABOUT</Text>
        <View style={styles.aboutRow}>
          <Text style={styles.aboutLabel}>Version</Text>
          <Text style={styles.aboutValue}>1.0.0</Text>
        </View>
        <View style={styles.aboutRow}>
          <Text style={styles.aboutLabel}>Model</Text>
          <Text style={styles.aboutValue}>Claude Sonnet 4</Text>
        </View>
        <View style={styles.aboutRow}>
          <Text style={styles.aboutLabel}>Cost per scan</Text>
          <Text style={styles.aboutValue}>~$0.003</Text>
        </View>
        <View style={styles.aboutRow}>
          <Text style={styles.aboutLabel}>Storage</Text>
          <Text style={styles.aboutValue}>Local only (SQLite)</Text>
        </View>
      </View>

      {/* Privacy Note */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>PRIVACY</Text>
        <Text style={styles.privacyText}>
          NDPass stores everything locally on your device. Ticket images are sent to Anthropic's API for parsing and are not stored by them. Your API key never leaves your device except to authenticate with Anthropic.
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  content: {
    padding: Spacing.md,
    paddingBottom: 120,
    gap: Spacing.lg,
  },

  // Sections
  section: {
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.card,
    padding: Spacing.lg,
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  sectionTitle: {
    fontFamily: Typography.mono,
    fontSize: 11,
    fontWeight: '700',
    color: Colors.textMuted,
    letterSpacing: 2,
    marginBottom: Spacing.sm,
  },
  sectionDesc: {
    fontFamily: Typography.mono,
    fontSize: 12,
    color: Colors.textSecondary,
    lineHeight: 18,
    marginBottom: Spacing.md,
  },

  // Input
  input: {
    fontFamily: Typography.mono,
    fontSize: 13,
    color: Colors.cream,
    backgroundColor: Colors.bgInput,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  inputActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: Spacing.xs,
  },

  // Saved key display
  savedKeyContainer: {
    backgroundColor: Colors.bgElevated,
    borderRadius: Radius.md,
    padding: Spacing.md,
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  savedKeyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  savedKeyText: {
    fontFamily: Typography.mono,
    fontSize: 12,
    color: Colors.cream,
    flex: 1,
  },
  savedKeyActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: Spacing.md,
    marginTop: Spacing.sm,
  },

  // Buttons
  smallBtn: {
    padding: 6,
  },
  saveBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.cream,
    paddingVertical: Spacing.md,
    borderRadius: Radius.lg,
    marginTop: Spacing.md,
  },
  saveBtnText: {
    fontFamily: Typography.mono,
    fontSize: 14,
    fontWeight: '700',
    color: Colors.bg,
  },

  // Link
  linkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: Spacing.md,
  },
  linkText: {
    fontFamily: Typography.mono,
    fontSize: 11,
    color: Colors.amber,
  },

  // About
  aboutRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 0.5,
    borderBottomColor: Colors.border,
  },
  aboutLabel: {
    fontFamily: Typography.mono,
    fontSize: 13,
    color: Colors.textSecondary,
  },
  aboutValue: {
    fontFamily: Typography.mono,
    fontSize: 13,
    color: Colors.cream,
  },

  // Privacy
  privacyText: {
    fontFamily: Typography.mono,
    fontSize: 12,
    color: Colors.textSecondary,
    lineHeight: 18,
  },
});
