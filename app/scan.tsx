import { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  Image,
  TextInput,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { parseTicketImage } from '@/lib/ai';
import { insertTicket } from '@/lib/database';
import { scheduleReminder } from '@/lib/notifications';
import { openLetterboxd } from '@/lib/integrations';
import { generateId } from '@/lib/utils';
import { ParsedTicketData } from '@/lib/types';

type ScanState = 'idle' | 'loading' | 'review' | 'saving';

export default function ScanScreen() {
  const router = useRouter();
  const [state, setState] = useState<ScanState>('idle');
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [parsed, setParsed] = useState<ParsedTicketData | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const logScrollRef = useRef<ScrollView>(null);

  // Editable fields
  const [movieTitle, setMovieTitle] = useState('');
  const [theater, setTheater] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [seat, setSeat] = useState('');
  const [price, setPrice] = useState('');

  const addLog = (msg: string) => {
    const ts = new Date().toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
    setLogs(prev => [...prev, `${ts} ${msg}`]);
  };

  // Auto-scroll log
  useEffect(() => {
    logScrollRef.current?.scrollToEnd({ animated: true });
  }, [logs]);

  const pickImage = async (useCamera: boolean) => {
    const permission = useCamera
      ? await ImagePicker.requestCameraPermissionsAsync()
      : await ImagePicker.requestMediaLibraryPermissionsAsync();

    if (!permission.granted) {
      Alert.alert('Permission needed', 'Grant camera/photo access in Settings');
      return;
    }

    const result = useCamera
      ? await ImagePicker.launchCameraAsync({ quality: 0.8 })
      : await ImagePicker.launchImageLibraryAsync({
          quality: 0.8,
          mediaTypes: ['images'],
        });

    if (result.canceled) return;

    const uri = result.assets[0].uri;
    setImageUri(uri);
    setState('loading');
    setLogs([]);
    addLog('Image selected');

    try {
      const data = await parseTicketImage(uri, addLog);
      setParsed(data);
      setMovieTitle(data.movieTitle);
      setTheater(data.theater);
      setDate(data.date);
      setTime(data.time);
      setSeat(data.seat ?? '');
      setPrice(data.price ?? '');
      addLog(`✓ Parsed: ${data.movieTitle} @ ${data.theater}`);
      setState('review');
    } catch (err: any) {
      addLog(`✗ Error: ${err.message}`);
      Alert.alert('Parse Error', err.message ?? 'Failed to read ticket');
      setState('idle');
    }
  };

  const saveTicket = async () => {
    if (!movieTitle || !theater || !date || !time || !imageUri) {
      Alert.alert('Missing info', 'Fill in at least the title, theater, date, and time');
      return;
    }

    setState('saving');
    addLog('Saving stub...');

    try {
      const notificationId = await scheduleReminder(movieTitle, theater, date, time);
      addLog(notificationId ? 'Reminder scheduled (1hr before)' : 'No reminder (showtime passed)');

      const ticket = {
        id: generateId(),
        movieTitle,
        theater,
        date,
        time,
        seat: seat || undefined,
        price: price || undefined,
        imageUri,
        createdAt: new Date().toISOString(),
        notificationId: notificationId ?? undefined,
      };

      await insertTicket(ticket);
      addLog('✓ Saved to collection');

      Alert.alert(
        '🎬 Stub saved!',
        notificationId
          ? 'Reminder set for 1hr before showtime.'
          : 'Showtime already passed — no reminder set.',
        [
          {
            text: 'Log on Letterboxd',
            onPress: () => openLetterboxd(movieTitle),
          },
          {
            text: 'Done',
            onPress: () => {
              resetForm();
              router.navigate('/');
            },
          },
        ]
      );
    } catch (err: any) {
      addLog(`✗ Save error: ${err.message}`);
      Alert.alert('Save Error', err.message);
      setState('review');
    }
  };

  const resetForm = () => {
    setState('idle');
    setImageUri(null);
    setParsed(null);
    setMovieTitle('');
    setTheater('');
    setDate('');
    setTime('');
    setSeat('');
    setPrice('');
    setLogs([]);
  };

  // ── Debug Terminal Component ──────────────────────────────
  const DebugTerminal = () => {
    if (logs.length === 0) return null;
    return (
      <View style={styles.terminal}>
        <View style={styles.terminalHeader}>
          <View style={styles.terminalDot} />
          <Text style={styles.terminalTitle}>ndpass — debug</Text>
        </View>
        <ScrollView
          ref={logScrollRef}
          style={styles.terminalBody}
          contentContainerStyle={styles.terminalContent}
        >
          {logs.map((log, i) => (
            <Text key={i} style={[
              styles.terminalLine,
              log.includes('✗') && styles.terminalError,
              log.includes('✓') && styles.terminalSuccess,
            ]}>
              {log}
            </Text>
          ))}
        </ScrollView>
      </View>
    );
  };

  // ── IDLE: pick photo ──────────────────────────────────────
  if (state === 'idle') {
    return (
      <View style={styles.container}>
        <View style={styles.idleContent}>
          <Ionicons name="scan-outline" size={48} color={Colors.creamDim} />
          <Text style={styles.idleTitle}>Scan a ticket</Text>
          <Text style={styles.idleSubtitle}>
            Take a photo or choose from your library
          </Text>

          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={styles.pickButton}
              onPress={() => pickImage(true)}
            >
              <Ionicons name="camera" size={22} color={Colors.bg} />
              <Text style={styles.pickButtonText}>Camera</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.pickButton, styles.pickButtonOutline]}
              onPress={() => pickImage(false)}
            >
              <Ionicons name="images" size={22} color={Colors.cream} />
              <Text style={[styles.pickButtonText, styles.pickButtonTextOutline]}>
                Library
              </Text>
            </TouchableOpacity>
          </View>

          <DebugTerminal />
        </View>
      </View>
    );
  }

  // ── LOADING: parsing ──────────────────────────────────────
  if (state === 'loading') {
    return (
      <View style={styles.container}>
        <ScrollView contentContainerStyle={styles.loadingContent}>
          {imageUri && (
            <Image source={{ uri: imageUri }} style={styles.previewImage} />
          )}
          <ActivityIndicator size="large" color={Colors.cream} style={{ marginTop: Spacing.lg }} />
          <Text style={styles.loadingText}>Reading your ticket...</Text>
          <DebugTerminal />
        </ScrollView>
      </View>
    );
  }

  // ── REVIEW: edit parsed data ──────────────────────────────
  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.reviewContent}
        keyboardShouldPersistTaps="handled"
      >
        {/* Ticket image — large preview */}
        {imageUri && (
          <View style={styles.ticketPreviewContainer}>
            <Image source={{ uri: imageUri }} style={styles.ticketPreview} />
            <View style={styles.ticketPreviewOverlay}>
              <Ionicons name="ticket" size={16} color={Colors.cream} />
              <Text style={styles.ticketPreviewLabel}>SCANNED STUB</Text>
            </View>
          </View>
        )}

        {parsed && parsed.confidence < 0.7 && (
          <View style={styles.warningBanner}>
            <Ionicons name="warning" size={16} color={Colors.amber} />
            <Text style={styles.warningText}>
              Low confidence ({Math.round(parsed.confidence * 100)}%) — double-check the fields
            </Text>
          </View>
        )}

        <View style={styles.formSection}>
          <FieldInput label="MOVIE" value={movieTitle} onChangeText={setMovieTitle} />
          <FieldInput label="THEATER" value={theater} onChangeText={setTheater} />
          <View style={styles.fieldRow}>
            <FieldInput label="DATE" value={date} onChangeText={setDate} placeholder="YYYY-MM-DD" half />
            <FieldInput label="TIME" value={time} onChangeText={setTime} placeholder="7:30 PM" half />
          </View>
          <View style={styles.fieldRow}>
            <FieldInput label="SEAT" value={seat} onChangeText={setSeat} placeholder="Optional" half />
            <FieldInput label="PRICE" value={price} onChangeText={setPrice} placeholder="$16.00" half />
          </View>
        </View>

        <View style={styles.reviewActions}>
          <TouchableOpacity
            style={styles.saveButton}
            onPress={saveTicket}
            disabled={state === 'saving'}
          >
            {state === 'saving' ? (
              <ActivityIndicator color={Colors.bg} />
            ) : (
              <>
                <Ionicons name="checkmark-circle" size={20} color={Colors.bg} />
                <Text style={styles.saveButtonText}>Save Stub</Text>
              </>
            )}
          </TouchableOpacity>

          <TouchableOpacity style={styles.cancelButton} onPress={resetForm}>
            <Text style={styles.cancelButtonText}>Start Over</Text>
          </TouchableOpacity>
        </View>

        <DebugTerminal />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

// ── Field Input Component ───────────────────────────────────
function FieldInput({
  label,
  value,
  onChangeText,
  placeholder,
  half,
}: {
  label: string;
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  half?: boolean;
}) {
  return (
    <View style={[styles.fieldContainer, half && styles.fieldHalf]}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        style={styles.fieldInput}
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder ?? label}
        placeholderTextColor={Colors.textMuted}
        selectionColor={Colors.cream}
      />
    </View>
  );
}

// ── Styles ──────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },

  // Idle
  idleContent: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
  },
  idleTitle: {
    fontFamily: Typography.mono,
    fontSize: 22,
    fontWeight: '700',
    color: Colors.cream,
    marginTop: Spacing.lg,
  },
  idleSubtitle: {
    fontFamily: Typography.mono,
    fontSize: 13,
    color: Colors.textSecondary,
    marginTop: Spacing.sm,
    textAlign: 'center',
  },
  buttonRow: {
    flexDirection: 'row',
    gap: Spacing.md,
    marginTop: Spacing.xl,
  },
  pickButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.cream,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: Radius.lg,
  },
  pickButtonOutline: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: Colors.cream,
  },
  pickButtonText: {
    fontFamily: Typography.mono,
    fontSize: 14,
    fontWeight: '700',
    color: Colors.bg,
  },
  pickButtonTextOutline: {
    color: Colors.cream,
  },

  // Loading
  loadingContent: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
    paddingBottom: Spacing.xxl,
  },
  previewImage: {
    width: 240,
    height: 160,
    borderRadius: Radius.lg,
    backgroundColor: Colors.bgElevated,
    resizeMode: 'contain',
  },
  loadingText: {
    fontFamily: Typography.mono,
    fontSize: 14,
    color: Colors.textSecondary,
    marginTop: Spacing.md,
  },

  // Ticket preview (review screen)
  ticketPreviewContainer: {
    position: 'relative',
    marginBottom: Spacing.md,
    borderRadius: Radius.lg,
    overflow: 'hidden',
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  ticketPreview: {
    width: '100%',
    height: 220,
    resizeMode: 'contain',
    backgroundColor: Colors.bgCard,
  },
  ticketPreviewOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    backgroundColor: 'rgba(10, 10, 10, 0.85)',
  },
  ticketPreviewLabel: {
    fontFamily: Typography.mono,
    fontSize: 10,
    fontWeight: '700',
    color: Colors.cream,
    letterSpacing: 2,
  },

  // Review
  reviewContent: {
    padding: Spacing.md,
    paddingBottom: 120,
  },
  warningBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.bgElevated,
    padding: Spacing.md,
    borderRadius: Radius.md,
    marginBottom: Spacing.md,
    borderWidth: 0.5,
    borderColor: Colors.amber,
  },
  warningText: {
    fontFamily: Typography.mono,
    fontSize: 12,
    color: Colors.amber,
    flex: 1,
  },

  // Form
  formSection: {
    gap: Spacing.md,
  },
  fieldRow: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  fieldContainer: {
    flex: 1,
  },
  fieldHalf: {
    flex: 0.5,
  },
  fieldLabel: {
    fontFamily: Typography.mono,
    fontSize: 10,
    fontWeight: '700',
    color: Colors.textMuted,
    letterSpacing: 1.5,
    marginBottom: 4,
  },
  fieldInput: {
    fontFamily: Typography.mono,
    fontSize: 15,
    color: Colors.cream,
    backgroundColor: Colors.bgInput,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    borderWidth: 0.5,
    borderColor: Colors.border,
  },

  // Actions
  reviewActions: {
    marginTop: Spacing.xl,
    gap: Spacing.md,
  },
  saveButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.cream,
    paddingVertical: Spacing.md,
    borderRadius: Radius.lg,
  },
  saveButtonText: {
    fontFamily: Typography.mono,
    fontSize: 16,
    fontWeight: '700',
    color: Colors.bg,
  },
  cancelButton: {
    alignItems: 'center',
    paddingVertical: Spacing.md,
  },
  cancelButtonText: {
    fontFamily: Typography.mono,
    fontSize: 14,
    color: Colors.textSecondary,
  },

  // Debug Terminal
  terminal: {
    marginTop: Spacing.lg,
    borderRadius: Radius.md,
    overflow: 'hidden',
    borderWidth: 0.5,
    borderColor: Colors.borderLight,
    width: '100%',
  },
  terminalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: Colors.bgElevated,
    paddingHorizontal: Spacing.md,
    paddingVertical: 8,
    borderBottomWidth: 0.5,
    borderBottomColor: Colors.border,
  },
  terminalDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.green,
  },
  terminalTitle: {
    fontFamily: Typography.mono,
    fontSize: 10,
    color: Colors.textMuted,
    letterSpacing: 1,
  },
  terminalBody: {
    backgroundColor: '#0C0C0C',
    maxHeight: 160,
  },
  terminalContent: {
    padding: Spacing.sm,
  },
  terminalLine: {
    fontFamily: Typography.mono,
    fontSize: 11,
    color: Colors.textSecondary,
    lineHeight: 18,
  },
  terminalError: {
    color: Colors.red,
  },
  terminalSuccess: {
    color: Colors.green,
  },
});
