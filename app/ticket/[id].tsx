import { useEffect, useState } from 'react';
import {
  View, Text, Image, StyleSheet, ScrollView, TextInput,
  TouchableOpacity, Dimensions, Modal, SafeAreaView, Alert,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Glass, Spacing, Radius, Typography } from '@/constants/theme';
import { getTicketById, getDB, updateTicket } from '@/lib/database';
import { getPosterUrl } from '@/lib/tmdb';
import { formatDisplayDate, formatPrice } from '@/lib/utils';
import { Ticket } from '@/lib/types';
import GlassCard from '@/components/GlassCard';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

export default function TicketDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [ticket, setTicket] = useState<Ticket | null>(null);
  const [groupTickets, setGroupTickets] = useState<Ticket[]>([]);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenIdx, setFullscreenIdx] = useState(0);
  const [editing, setEditing] = useState(false);

  // Edit fields
  const [editTitle, setEditTitle] = useState('');
  const [editTheater, setEditTheater] = useState('');
  const [editDate, setEditDate] = useState('');
  const [editTime, setEditTime] = useState('');
  const [editSeat, setEditSeat] = useState('');
  const [editPrice, setEditPrice] = useState('');

  const loadTicket = async () => {
    if (!id) return;
    const t = await getTicketById(id);
    setTicket(t);
    if (t) {
      setEditTitle(t.movieTitle);
      setEditTheater(t.theater);
      setEditDate(t.date);
      setEditTime(t.time);
      setEditSeat(t.seat ?? '');
      setEditPrice(t.price ?? '');
      if (t.groupKey) {
        const db = await getDB();
        const rows = await db.getAllAsync<any>(
          'SELECT * FROM tickets WHERE groupKey = ? ORDER BY seat ASC', [t.groupKey]
        );
        setGroupTickets(rows.map((r: any) => ({ ...r, archived: !!r.archived })));
      }
    }
  };

  useEffect(() => { loadTicket(); }, [id]);

  const startEditing = () => setEditing(true);

  const cancelEditing = () => {
    if (!ticket) return;
    setEditTitle(ticket.movieTitle);
    setEditTheater(ticket.theater);
    setEditDate(ticket.date);
    setEditTime(ticket.time);
    setEditSeat(ticket.seat ?? '');
    setEditPrice(ticket.price ?? '');
    setEditing(false);
  };

  const saveEdits = async () => {
    if (!ticket) return;
    if (!editTitle || !editTheater || !editDate || !editTime) {
      Alert.alert('Missing info', 'Title, theater, date, and time are required.');
      return;
    }
    await updateTicket({
      id: ticket.id,
      movieTitle: editTitle.trim(),
      theater: editTheater.trim(),
      date: editDate.trim(),
      time: editTime.trim(),
      seat: editSeat.trim() || undefined,
      price: editPrice.trim() || undefined,
    });
    setEditing(false);
    await loadTicket();
  };

  if (!ticket) {
    return <View style={styles.container}><Text style={styles.loadingText}>Loading...</Text></View>;
  }

  const posterUri = ticket.posterPath ? getPosterUrl(ticket.posterPath, 'w500') : null;
  const allTickets = groupTickets.length > 0 ? groupTickets : [ticket];

  return (
    <>
      <ScrollView style={styles.container} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={{ height: 100 }} />

        {posterUri ? (
          <Image source={{ uri: posterUri }} style={styles.poster} />
        ) : (
          <View style={styles.posterPlaceholder}>
            <Ionicons name="film-outline" size={48} color={Colors.textMuted} />
          </View>
        )}

        {/* Movie info / edit mode */}
        <View style={styles.infoSection}>
          {editing ? (
            <>
              <EditField label="MOVIE" value={editTitle} onChange={setEditTitle} />
              <EditField label="THEATER" value={editTheater} onChange={setEditTheater} />
              <View style={styles.editRow}>
                <EditField label="DATE" value={editDate} onChange={setEditDate} placeholder="YYYY-MM-DD" half />
                <EditField label="TIME" value={editTime} onChange={setEditTime} placeholder="7:30 PM" half />
              </View>
              <View style={styles.editRow}>
                <EditField label="SEAT" value={editSeat} onChange={setEditSeat} placeholder="Optional" half />
                <EditField label="PRICE" value={editPrice} onChange={setEditPrice} placeholder="$16.00" half />
              </View>
              <View style={styles.editActions}>
                <TouchableOpacity style={styles.saveEditBtn} onPress={saveEdits}>
                  <Ionicons name="checkmark" size={18} color={Colors.bg} />
                  <Text style={styles.saveEditText}>Save</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.cancelEditBtn} onPress={cancelEditing}>
                  <Text style={styles.cancelEditText}>Cancel</Text>
                </TouchableOpacity>
              </View>
            </>
          ) : (
            <>
              <View style={styles.titleRow}>
                <Text style={styles.title}>{ticket.movieTitle}</Text>
                <TouchableOpacity onPress={startEditing} style={styles.editBtn}>
                  <Ionicons name="pencil" size={16} color={Colors.amber} />
                </TouchableOpacity>
              </View>
              <Text style={styles.theater}>{ticket.theater}</Text>
              <View style={styles.metaRow}>
                <View style={styles.metaChip}>
                  <Ionicons name="calendar-outline" size={13} color={Colors.amber} />
                  <Text style={styles.metaText}>{formatDisplayDate(ticket.date)}</Text>
                </View>
                <View style={styles.metaChip}>
                  <Ionicons name="time-outline" size={13} color={Colors.amber} />
                  <Text style={styles.metaText}>{ticket.time}</Text>
                </View>
              </View>
            </>
          )}
        </View>

        {/* Details card */}
        {!editing && (
          <GlassCard style={styles.detailsCard}>
            <Text style={styles.detailsTitle}>DETAILS</Text>
            <DetailRow label="Theater" value={ticket.theater} />
            <DetailRow label="Date" value={formatDisplayDate(ticket.date)} />
            <DetailRow label="Time" value={ticket.time} />
            {ticket.seat && <DetailRow label="Seat" value={ticket.seat} />}
            {ticket.price && <DetailRow label="Price" value={formatPrice(ticket.price)} />}
            <DetailRow label="Scanned" value={new Date(ticket.createdAt).toLocaleDateString('en-US', {
              month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
            })} />
            {ticket.archived && (
              <View style={styles.archivedBadge}>
                <Ionicons name="archive-outline" size={12} color={Colors.textSecondary} />
                <Text style={styles.archivedText}>Archived</Text>
              </View>
            )}
          </GlassCard>
        )}

        {/* Tickets */}
        {!editing && (
          <>
            <Text style={styles.sectionLabel}>
              {allTickets.length > 1 ? `TICKETS (${allTickets.length})` : 'TICKET'}
            </Text>
            <Text style={styles.sectionHint}>Tap to show at box office</Text>

            {allTickets.map((t, idx) => (
              <TouchableOpacity key={t.id} activeOpacity={0.85}
                onPress={() => { setFullscreenIdx(idx); setFullscreen(true); }}>
                <GlassCard style={styles.ticketCard}>
                  <Image source={{ uri: t.imageUri }} style={styles.ticketThumb} />
                  <View style={styles.ticketInfo}>
                    {t.seat && <Text style={styles.ticketSeat}>Seat {t.seat}</Text>}
                    {t.price && <Text style={styles.ticketPrice}>{formatPrice(t.price)}</Text>}
                  </View>
                  <Ionicons name="expand-outline" size={20} color={Colors.textMuted} />
                </GlassCard>
              </TouchableOpacity>
            ))}
          </>
        )}
      </ScrollView>

      {/* Fullscreen ticket modal */}
      <Modal visible={fullscreen} animationType="fade" statusBarTranslucent>
        <View style={styles.fullscreenContainer}>
          <Image source={{ uri: allTickets[fullscreenIdx]?.imageUri }}
            style={styles.fullscreenImage} resizeMode="contain" />
          {allTickets.length > 1 && (
            <View style={styles.fullscreenNav}>
              <TouchableOpacity style={styles.navBtn}
                onPress={() => setFullscreenIdx(Math.max(0, fullscreenIdx - 1))}
                disabled={fullscreenIdx === 0}>
                <Ionicons name="chevron-back" size={28} color={fullscreenIdx === 0 ? Colors.textMuted : '#fff'} />
              </TouchableOpacity>
              <Text style={styles.navCounter}>{fullscreenIdx + 1} / {allTickets.length}</Text>
              <TouchableOpacity style={styles.navBtn}
                onPress={() => setFullscreenIdx(Math.min(allTickets.length - 1, fullscreenIdx + 1))}
                disabled={fullscreenIdx === allTickets.length - 1}>
                <Ionicons name="chevron-forward" size={28} color={fullscreenIdx === allTickets.length - 1 ? Colors.textMuted : '#fff'} />
              </TouchableOpacity>
            </View>
          )}
          <SafeAreaView style={styles.fullscreenCloseArea}>
            <TouchableOpacity style={styles.fullscreenClose} onPress={() => setFullscreen(false)}>
              <Ionicons name="close" size={24} color="#fff" />
            </TouchableOpacity>
          </SafeAreaView>
        </View>
      </Modal>
    </>
  );
}

function EditField({ label, value, onChange, placeholder, half }: {
  label: string; value: string; onChange: (s: string) => void; placeholder?: string; half?: boolean;
}) {
  return (
    <View style={[styles.editFieldContainer, half && { flex: 1 }]}>
      <Text style={styles.editFieldLabel}>{label}</Text>
      <TextInput style={styles.editFieldInput} value={value} onChangeText={onChange}
        placeholder={placeholder ?? label} placeholderTextColor={Colors.textMuted}
        selectionColor={Colors.cream} />
    </View>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { paddingBottom: 120 },
  loadingText: { fontFamily: Typography.mono, color: Colors.textMuted, textAlign: 'center', marginTop: 100 },

  poster: { width: SCREEN_WIDTH - 32, height: (SCREEN_WIDTH - 32) * 1.3, resizeMode: 'cover', borderRadius: Radius.xl, alignSelf: 'center', marginBottom: Spacing.lg },
  posterPlaceholder: { width: SCREEN_WIDTH - 32, height: 200, borderRadius: Radius.xl, alignSelf: 'center', marginBottom: Spacing.lg, justifyContent: 'center', alignItems: 'center', ...Glass.panel },

  // Info
  infoSection: { paddingHorizontal: Spacing.lg, marginBottom: Spacing.lg },
  titleRow: { flexDirection: 'row', alignItems: 'flex-start', gap: Spacing.sm },
  title: { fontFamily: Typography.body, fontSize: 28, fontWeight: '700', color: Colors.cream, letterSpacing: -0.5, flex: 1 },
  editBtn: { padding: 8, marginTop: 4, borderRadius: Radius.pill, ...Glass.subtle },
  theater: { fontFamily: Typography.mono, fontSize: 14, color: Colors.amber, marginTop: 4, letterSpacing: 0.3 },
  metaRow: { flexDirection: 'row', gap: Spacing.sm, marginTop: Spacing.md },
  metaChip: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingHorizontal: 12, paddingVertical: 6, borderRadius: Radius.pill, ...Glass.subtle },
  metaText: { fontFamily: Typography.mono, fontSize: 12, color: Colors.textSecondary },

  // Edit mode
  editRow: { flexDirection: 'row', gap: Spacing.md },
  editFieldContainer: { marginBottom: Spacing.md },
  editFieldLabel: { fontFamily: Typography.mono, fontSize: 10, fontWeight: '700', color: Colors.textMuted, letterSpacing: 1.5, marginBottom: 4 },
  editFieldInput: { fontFamily: Typography.mono, fontSize: 15, color: Colors.cream, backgroundColor: 'rgba(255,255,255,0.04)', borderRadius: Radius.md, paddingHorizontal: Spacing.md, paddingVertical: Spacing.md, borderWidth: 0.5, borderColor: Colors.glassBorder },
  editActions: { flexDirection: 'row', gap: Spacing.md, marginTop: Spacing.sm },
  saveEditBtn: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, backgroundColor: Colors.cream, paddingVertical: 12, borderRadius: Radius.md },
  saveEditText: { fontFamily: Typography.mono, fontSize: 14, fontWeight: '700', color: Colors.bg },
  cancelEditBtn: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 12, borderRadius: Radius.md, ...Glass.subtle },
  cancelEditText: { fontFamily: Typography.mono, fontSize: 14, color: Colors.textSecondary },

  // Details card
  detailsCard: { marginHorizontal: Spacing.md, padding: Spacing.lg, marginBottom: Spacing.lg },
  detailsTitle: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, marginBottom: Spacing.md },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderBottomWidth: 0.5, borderBottomColor: 'rgba(255,255,255,0.05)' },
  detailLabel: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textMuted },
  detailValue: { fontFamily: Typography.mono, fontSize: 13, color: Colors.cream },
  archivedBadge: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: Spacing.md },
  archivedText: { fontFamily: Typography.mono, fontSize: 11, color: Colors.textSecondary },

  // Section
  sectionLabel: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, paddingHorizontal: Spacing.lg, marginBottom: 2 },
  sectionHint: { fontFamily: Typography.mono, fontSize: 10, color: Colors.textMuted, paddingHorizontal: Spacing.lg, marginBottom: Spacing.md },

  // Ticket card
  ticketCard: { flexDirection: 'row', alignItems: 'center', marginHorizontal: Spacing.md, marginBottom: Spacing.sm, padding: Spacing.md, gap: Spacing.md },
  ticketThumb: { width: 90, height: 60, borderRadius: Radius.sm, backgroundColor: Colors.glass, resizeMode: 'contain' },
  ticketInfo: { flex: 1 },
  ticketSeat: { fontFamily: Typography.mono, fontSize: 14, fontWeight: '700', color: Colors.cream },
  ticketPrice: { fontFamily: Typography.mono, fontSize: 13, color: Colors.green, marginTop: 2 },

  // Fullscreen
  fullscreenContainer: { flex: 1, backgroundColor: '#000', justifyContent: 'center', alignItems: 'center' },
  fullscreenImage: { width: SCREEN_WIDTH, height: SCREEN_HEIGHT * 0.8 },
  fullscreenCloseArea: { position: 'absolute', top: 0, right: 0 },
  fullscreenClose: { padding: 16, margin: 8, backgroundColor: 'rgba(255,255,255,0.15)', borderRadius: 20 },
  fullscreenNav: { position: 'absolute', bottom: 80, flexDirection: 'row', alignItems: 'center', gap: 20 },
  navBtn: { padding: 10 },
  navCounter: { fontFamily: Typography.mono, fontSize: 14, color: '#fff' },
});
