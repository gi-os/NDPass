import { useEffect, useState, useCallback } from 'react';
import {
  View, Text, Image, StyleSheet, ScrollView, TextInput,
  TouchableOpacity, Dimensions, Modal, SafeAreaView, Alert,
  ActivityIndicator, PanResponder,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Glass, Spacing, Radius, Typography } from '@/constants/theme';
import { getTicketById, getDB, updateTicket } from '@/lib/database';
import { getPosterUrl, searchMovie } from '@/lib/tmdb';
import { formatDisplayDate, formatPrice } from '@/lib/utils';
import { Ticket } from '@/lib/types';
import GlassCard from '@/components/GlassCard';

const { width: SW, height: SH } = Dimensions.get('window');

export default function TicketDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [ticket, setTicket] = useState<Ticket | null>(null);
  const [groupTickets, setGroupTickets] = useState<Ticket[]>([]);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenIdx, setFullscreenIdx] = useState(0);
  const [editing, setEditing] = useState(false);
  const [searchingPoster, setSearchingPoster] = useState(false);
  const [swipeY, setSwipeY] = useState(0);

  const [editTitle, setEditTitle] = useState('');
  const [editTheater, setEditTheater] = useState('');
  const [editDate, setEditDate] = useState('');
  const [editTime, setEditTime] = useState('');
  const [editSeat, setEditSeat] = useState('');
  const [editPrice, setEditPrice] = useState('');

  // Swipe down to dismiss fullscreen
  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_, g) => Math.abs(g.dy) > 10,
    onPanResponderMove: (_, g) => { if (g.dy > 0) setSwipeY(g.dy); },
    onPanResponderRelease: (_, g) => {
      if (g.dy > 120) { setFullscreen(false); }
      setSwipeY(0);
    },
  });

  const loadTicket = useCallback(async () => {
    if (!id) return;
    const t = await getTicketById(id);
    setTicket(t);
    if (t) {
      setEditTitle(t.movieTitle); setEditTheater(t.theater);
      setEditDate(t.date); setEditTime(t.time);
      setEditSeat(t.seat ?? ''); setEditPrice(t.price ?? '');
      if (t.groupKey) {
        const db = await getDB();
        const rows = await db.getAllAsync<any>(
          'SELECT * FROM tickets WHERE groupKey = ? ORDER BY seat ASC', [t.groupKey]
        );
        setGroupTickets(rows.map((r: any) => ({ ...r, archived: !!r.archived })));
      }
    }
  }, [id]);

  useEffect(() => { loadTicket(); }, [loadTicket]);

  const startEditing = () => setEditing(true);
  const cancelEditing = () => {
    if (!ticket) return;
    setEditTitle(ticket.movieTitle); setEditTheater(ticket.theater);
    setEditDate(ticket.date); setEditTime(ticket.time);
    setEditSeat(ticket.seat ?? ''); setEditPrice(ticket.price ?? '');
    setEditing(false);
  };

  const saveEdits = async () => {
    if (!ticket) return;
    if (!editTitle || !editTheater || !editDate || !editTime) {
      Alert.alert('Missing info', 'Title, theater, date, and time are required.'); return;
    }
    const updates: any = {
      id: ticket.id, movieTitle: editTitle.trim(), theater: editTheater.trim(),
      date: editDate.trim(), time: editTime.trim(),
      seat: editSeat.trim() || undefined, price: editPrice.trim() || undefined,
    };
    if (editTitle.trim() !== ticket.movieTitle) {
      setSearchingPoster(true);
      const movie = await searchMovie(editTitle.trim());
      if (movie?.posterPath) {
        updates.posterPath = movie.posterPath;
        updates.backdropPath = movie.backdropPath;
        updates.tmdbId = movie.id;
      }
      setSearchingPoster(false);
    }
    await updateTicket(updates);
    setEditing(false);
    await loadTicket();
  };

  const searchPoster = async () => {
    if (!editTitle.trim() || !ticket) return;
    setSearchingPoster(true);
    const movie = await searchMovie(editTitle.trim());
    setSearchingPoster(false);
    if (movie?.posterPath) {
      await updateTicket({ id: ticket.id, posterPath: movie.posterPath, backdropPath: movie.backdropPath ?? undefined, tmdbId: movie.id });
      await loadTicket();
      Alert.alert('✓ Poster found', movie.title);
    } else {
      Alert.alert('No poster found', 'Try a different title.');
    }
  };

  if (!ticket) return <View style={styles.container}><Text style={styles.loadingText}>Loading...</Text></View>;

  const posterUri = ticket.posterPath ? getPosterUrl(ticket.posterPath, 'w500') : null;
  const backdropUri = ticket.backdropPath ? `https://image.tmdb.org/t/p/w1280${ticket.backdropPath}` : null;
  const allTickets = groupTickets.length > 0 ? groupTickets : [ticket];

  return (
    <>
      <ScrollView style={styles.container} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        {/* Color-matched header from poster/backdrop */}
        {(backdropUri || posterUri) ? (
          <View style={styles.heroContainer}>
            <Image source={{ uri: backdropUri ?? posterUri! }} style={styles.heroBg} blurRadius={20} />
            <LinearGradient colors={['rgba(0,0,0,0.3)', 'transparent', Colors.bg]} locations={[0, 0.4, 1]} style={StyleSheet.absoluteFillObject} />
            <SafeAreaView style={styles.heroContent}>
              {posterUri && <Image source={{ uri: posterUri }} style={styles.poster} />}
            </SafeAreaView>
          </View>
        ) : (
          <View style={styles.heroPlaceholder}>
            <SafeAreaView />
            <View style={styles.posterPlaceholder}>
              <Ionicons name="film-outline" size={48} color={Colors.textMuted} />
            </View>
          </View>
        )}

        {/* Info section */}
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
                <TouchableOpacity style={styles.saveEditBtn} onPress={saveEdits} disabled={searchingPoster}>
                  {searchingPoster
                    ? <><ActivityIndicator size="small" color={Colors.bg} /><Text style={styles.saveEditText}>Searching...</Text></>
                    : <><Ionicons name="checkmark" size={18} color={Colors.bg} /><Text style={styles.saveEditText}>Save</Text></>}
                </TouchableOpacity>
                <TouchableOpacity style={styles.cancelEditBtn} onPress={cancelEditing}>
                  <Text style={styles.cancelEditText}>Cancel</Text>
                </TouchableOpacity>
              </View>
              <TouchableOpacity style={styles.searchPosterBtn} onPress={searchPoster}>
                <Ionicons name="image-outline" size={16} color={Colors.amber} />
                <Text style={styles.searchPosterText}>Search poster</Text>
              </TouchableOpacity>
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

        {/* Details */}
        {!editing && (
          <GlassCard style={styles.detailsCard}>
            <Text style={styles.detailsTitle}>DETAILS</Text>
            <DetailRow label="Theater" value={ticket.theater} />
            <DetailRow label="Date" value={formatDisplayDate(ticket.date)} />
            <DetailRow label="Time" value={ticket.time} />
            {ticket.seat && <DetailRow label="Seat" value={ticket.seat} />}
            {ticket.price && <DetailRow label="Price" value={formatPrice(ticket.price)} />}
            <DetailRow label="Scanned" value={new Date(ticket.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })} />
            {ticket.archived && (
              <View style={styles.archivedBadge}><Ionicons name="archive-outline" size={12} color={Colors.textSecondary} /><Text style={styles.archivedText}>Archived</Text></View>
            )}
          </GlassCard>
        )}

        {/* Overview */}
        {!editing && ticket.overview && (
          <GlassCard style={styles.detailsCard}>
            <Text style={styles.detailsTitle}>ABOUT</Text>
            <Text style={styles.overviewText}>{ticket.overview}</Text>
          </GlassCard>
        )}

        {/* Tickets */}
        {!editing && (
          <>
            <Text style={styles.sectionLabel}>{allTickets.length > 1 ? `TICKETS (${allTickets.length})` : 'TICKET'}</Text>
            <Text style={styles.sectionHint}>Tap to show at box office · swipe down to dismiss</Text>
            {allTickets.map((t, idx) => (
              <TouchableOpacity key={t.id} activeOpacity={0.85} onPress={() => { setFullscreenIdx(idx); setFullscreen(true); }}>
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

      {/* Fullscreen — swipe down to dismiss */}
      <Modal visible={fullscreen} animationType="fade" statusBarTranslucent>
        <View style={styles.fullscreenContainer} {...panResponder.panHandlers}>
          <Image
            source={{ uri: allTickets[fullscreenIdx]?.imageUri }}
            style={[styles.fullscreenImage, { transform: [{ translateY: swipeY }, { scale: Math.max(0.9, 1 - swipeY / 600) }], opacity: Math.max(0.5, 1 - swipeY / 300) }]}
            resizeMode="contain"
          />
          {allTickets.length > 1 && (
            <View style={styles.fullscreenNav}>
              <TouchableOpacity style={styles.navBtn} onPress={() => setFullscreenIdx(Math.max(0, fullscreenIdx - 1))} disabled={fullscreenIdx === 0}>
                <Ionicons name="chevron-back" size={28} color={fullscreenIdx === 0 ? Colors.textMuted : '#fff'} />
              </TouchableOpacity>
              <Text style={styles.navCounter}>{fullscreenIdx + 1} / {allTickets.length}</Text>
              <TouchableOpacity style={styles.navBtn} onPress={() => setFullscreenIdx(Math.min(allTickets.length - 1, fullscreenIdx + 1))} disabled={fullscreenIdx === allTickets.length - 1}>
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
        placeholder={placeholder ?? label} placeholderTextColor={Colors.textMuted} selectionColor={Colors.cream} />
    </View>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return <View style={styles.detailRow}><Text style={styles.detailLabel}>{label}</Text><Text style={styles.detailValue}>{value}</Text></View>;
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { paddingBottom: 120 },
  loadingText: { fontFamily: Typography.mono, color: Colors.textMuted, textAlign: 'center', marginTop: 100 },

  // Hero — color-matched from poster
  heroContainer: { height: SW * 1.4, position: 'relative' },
  heroBg: { ...StyleSheet.absoluteFillObject, resizeMode: 'cover' },
  heroContent: { flex: 1, justifyContent: 'flex-end', alignItems: 'center', paddingBottom: Spacing.lg },
  poster: { width: SW * 0.55, height: SW * 0.55 * 1.5, borderRadius: Radius.xl, resizeMode: 'cover',
    shadowColor: '#000', shadowOffset: { width: 0, height: 16 }, shadowOpacity: 0.6, shadowRadius: 32 },
  heroPlaceholder: { height: 280, justifyContent: 'center', alignItems: 'center' },
  posterPlaceholder: { width: SW * 0.55, height: 200, borderRadius: Radius.xl, justifyContent: 'center', alignItems: 'center', ...Glass.panel },

  // Info
  infoSection: { paddingHorizontal: Spacing.lg, marginBottom: Spacing.lg, marginTop: Spacing.md },
  titleRow: { flexDirection: 'row', alignItems: 'flex-start', gap: Spacing.sm },
  title: { fontFamily: Typography.body, fontSize: 28, fontWeight: '700', color: Colors.cream, letterSpacing: -0.5, flex: 1 },
  editBtn: { padding: 8, marginTop: 4, borderRadius: Radius.pill, ...Glass.subtle },
  theater: { fontFamily: Typography.mono, fontSize: 14, color: Colors.amber, marginTop: 4 },
  metaRow: { flexDirection: 'row', gap: Spacing.sm, marginTop: Spacing.md },
  metaChip: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingHorizontal: 12, paddingVertical: 6, borderRadius: Radius.pill, ...Glass.subtle },
  metaText: { fontFamily: Typography.mono, fontSize: 12, color: Colors.textSecondary },

  // Edit
  editRow: { flexDirection: 'row', gap: Spacing.md },
  editFieldContainer: { marginBottom: Spacing.md },
  editFieldLabel: { fontFamily: Typography.mono, fontSize: 10, fontWeight: '700', color: Colors.textMuted, letterSpacing: 1.5, marginBottom: 4 },
  editFieldInput: { fontFamily: Typography.mono, fontSize: 15, color: Colors.cream, backgroundColor: 'rgba(255,255,255,0.04)', borderRadius: Radius.md, paddingHorizontal: Spacing.md, paddingVertical: Spacing.md, borderWidth: 0.5, borderColor: Colors.glassBorder },
  editActions: { flexDirection: 'row', gap: Spacing.md, marginTop: Spacing.sm },
  saveEditBtn: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, backgroundColor: Colors.cream, paddingVertical: 12, borderRadius: Radius.md },
  saveEditText: { fontFamily: Typography.mono, fontSize: 14, fontWeight: '700', color: Colors.bg },
  cancelEditBtn: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 12, borderRadius: Radius.md, ...Glass.subtle },
  cancelEditText: { fontFamily: Typography.mono, fontSize: 14, color: Colors.textSecondary },
  searchPosterBtn: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: Spacing.md, paddingVertical: 10, paddingHorizontal: Spacing.md, borderRadius: Radius.md, ...Glass.subtle, alignSelf: 'flex-start' },
  searchPosterText: { fontFamily: Typography.mono, fontSize: 12, color: Colors.amber },

  // Details
  detailsCard: { marginHorizontal: Spacing.md, padding: Spacing.lg, marginBottom: Spacing.lg },
  detailsTitle: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, marginBottom: Spacing.md },
  detailRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderBottomWidth: 0.5, borderBottomColor: 'rgba(255,255,255,0.05)' },
  detailLabel: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textMuted },
  detailValue: { fontFamily: Typography.mono, fontSize: 13, color: Colors.cream },
  archivedBadge: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: Spacing.md },
  archivedText: { fontFamily: Typography.mono, fontSize: 11, color: Colors.textSecondary },
  overviewText: { fontFamily: Typography.body, fontSize: 14, color: Colors.textSecondary, lineHeight: 22 },

  sectionLabel: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, paddingHorizontal: Spacing.lg, marginBottom: 2 },
  sectionHint: { fontFamily: Typography.mono, fontSize: 10, color: Colors.textMuted, paddingHorizontal: Spacing.lg, marginBottom: Spacing.md },

  ticketCard: { flexDirection: 'row', alignItems: 'center', marginHorizontal: Spacing.md, marginBottom: Spacing.sm, padding: Spacing.md, gap: Spacing.md },
  ticketThumb: { width: 90, height: 60, borderRadius: Radius.sm, backgroundColor: Colors.glass, resizeMode: 'contain' },
  ticketInfo: { flex: 1 },
  ticketSeat: { fontFamily: Typography.mono, fontSize: 14, fontWeight: '700', color: Colors.cream },
  ticketPrice: { fontFamily: Typography.mono, fontSize: 13, color: Colors.green, marginTop: 2 },

  // Fullscreen
  fullscreenContainer: { flex: 1, backgroundColor: '#000', justifyContent: 'center', alignItems: 'center' },
  fullscreenImage: { width: SW, height: SH * 0.8 },
  fullscreenCloseArea: { position: 'absolute', top: 0, right: 0 },
  fullscreenClose: { padding: 16, margin: 8, backgroundColor: 'rgba(255,255,255,0.15)', borderRadius: 20 },
  fullscreenNav: { position: 'absolute', bottom: 80, flexDirection: 'row', alignItems: 'center', gap: 20 },
  navBtn: { padding: 10 },
  navCounter: { fontFamily: Typography.mono, fontSize: 14, color: '#fff' },
});
