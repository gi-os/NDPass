import { useEffect, useState } from 'react';
import {
  View, Text, Image, StyleSheet, ScrollView,
  TouchableOpacity, Dimensions, Modal,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { getTicketById, getDB } from '@/lib/database';
import { getPosterUrl } from '@/lib/tmdb';
import { formatDisplayDate, formatPrice } from '@/lib/utils';
import { Ticket } from '@/lib/types';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

export default function TicketDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [ticket, setTicket] = useState<Ticket | null>(null);
  const [groupTickets, setGroupTickets] = useState<Ticket[]>([]);
  const [fullscreen, setFullscreen] = useState(false);
  const [fullscreenIdx, setFullscreenIdx] = useState(0);

  useEffect(() => {
    if (!id) return;
    (async () => {
      const t = await getTicketById(id);
      setTicket(t);
      if (t?.groupKey) {
        const db = await getDB();
        const rows = await db.getAllAsync<any>(
          'SELECT * FROM tickets WHERE groupKey = ? ORDER BY seat ASC', [t.groupKey]
        );
        setGroupTickets(rows.map((r: any) => ({ ...r, archived: !!r.archived })));
      }
    })();
  }, [id]);

  if (!ticket) {
    return <View style={styles.container}><Text style={styles.loadingText}>Loading...</Text></View>;
  }

  const posterUri = ticket.posterPath ? getPosterUrl(ticket.posterPath, 'w500') : null;
  const allTickets = groupTickets.length > 0 ? groupTickets : [ticket];

  return (
    <>
      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        {/* Poster header */}
        {posterUri && (
          <Image source={{ uri: posterUri }} style={styles.poster} />
        )}

        {/* Movie info */}
        <View style={styles.infoSection}>
          <Text style={styles.title}>{ticket.movieTitle}</Text>
          <Text style={styles.theater}>{ticket.theater}</Text>
          <View style={styles.metaRow}>
            <Ionicons name="calendar-outline" size={14} color={Colors.textSecondary} />
            <Text style={styles.metaText}>{formatDisplayDate(ticket.date)}</Text>
            <Ionicons name="time-outline" size={14} color={Colors.textSecondary} />
            <Text style={styles.metaText}>{ticket.time}</Text>
          </View>
        </View>

        {/* Tickets in this group */}
        <Text style={styles.sectionLabel}>
          {allTickets.length > 1 ? `TICKETS (${allTickets.length})` : 'TICKET'}
        </Text>

        {allTickets.map((t, idx) => (
          <TouchableOpacity
            key={t.id}
            style={styles.ticketCard}
            activeOpacity={0.85}
            onPress={() => { setFullscreenIdx(idx); setFullscreen(true); }}
          >
            <Image source={{ uri: t.imageUri }} style={styles.ticketThumb} />
            <View style={styles.ticketInfo}>
              {t.seat && <Text style={styles.ticketSeat}>Seat {t.seat}</Text>}
              {t.price && <Text style={styles.ticketPrice}>{formatPrice(t.price)}</Text>}
              <Text style={styles.tapHint}>Tap to show at box office</Text>
            </View>
            <Ionicons name="expand-outline" size={20} color={Colors.textMuted} />
          </TouchableOpacity>
        ))}
      </ScrollView>

      {/* Fullscreen ticket modal — show to box office */}
      <Modal visible={fullscreen} animationType="fade" statusBarTranslucent>
        <View style={styles.fullscreenContainer}>
          <Image
            source={{ uri: allTickets[fullscreenIdx]?.imageUri }}
            style={styles.fullscreenImage}
            resizeMode="contain"
          />

          {/* Navigation for multiple tickets */}
          {allTickets.length > 1 && (
            <View style={styles.fullscreenNav}>
              <TouchableOpacity
                style={styles.navBtn}
                onPress={() => setFullscreenIdx(Math.max(0, fullscreenIdx - 1))}
                disabled={fullscreenIdx === 0}
              >
                <Ionicons name="chevron-back" size={28} color={fullscreenIdx === 0 ? Colors.textMuted : '#fff'} />
              </TouchableOpacity>
              <Text style={styles.navCounter}>
                {fullscreenIdx + 1} / {allTickets.length}
              </Text>
              <TouchableOpacity
                style={styles.navBtn}
                onPress={() => setFullscreenIdx(Math.min(allTickets.length - 1, fullscreenIdx + 1))}
                disabled={fullscreenIdx === allTickets.length - 1}
              >
                <Ionicons name="chevron-forward" size={28} color={fullscreenIdx === allTickets.length - 1 ? Colors.textMuted : '#fff'} />
              </TouchableOpacity>
            </View>
          )}

          <TouchableOpacity
            style={styles.fullscreenClose}
            onPress={() => setFullscreen(false)}
          >
            <Ionicons name="close" size={28} color="#fff" />
          </TouchableOpacity>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { paddingBottom: 120 },
  loadingText: { fontFamily: Typography.mono, color: Colors.textMuted, textAlign: 'center', marginTop: 100 },

  // Poster
  poster: { width: SCREEN_WIDTH, height: SCREEN_WIDTH * 1.2, resizeMode: 'cover' },

  // Info
  infoSection: { padding: Spacing.lg },
  title: { fontFamily: Typography.mono, fontSize: 26, fontWeight: '700', color: Colors.cream },
  theater: { fontFamily: Typography.mono, fontSize: 15, color: Colors.amber, marginTop: 4 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: Spacing.md },
  metaText: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textSecondary, marginRight: Spacing.md },

  // Section
  sectionLabel: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, paddingHorizontal: Spacing.lg, marginTop: Spacing.md, marginBottom: Spacing.sm },

  // Ticket card
  ticketCard: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: Colors.bgCard, marginHorizontal: Spacing.md,
    marginBottom: Spacing.sm, borderRadius: Radius.card,
    padding: Spacing.md, borderWidth: 0.5, borderColor: Colors.border,
    gap: Spacing.md,
  },
  ticketThumb: { width: 80, height: 56, borderRadius: Radius.sm, backgroundColor: Colors.bgElevated, resizeMode: 'contain' },
  ticketInfo: { flex: 1 },
  ticketSeat: { fontFamily: Typography.mono, fontSize: 14, fontWeight: '700', color: Colors.cream },
  ticketPrice: { fontFamily: Typography.mono, fontSize: 13, color: Colors.green, marginTop: 2 },
  tapHint: { fontFamily: Typography.mono, fontSize: 10, color: Colors.textMuted, marginTop: 4 },

  // Fullscreen
  fullscreenContainer: { flex: 1, backgroundColor: '#000', justifyContent: 'center', alignItems: 'center' },
  fullscreenImage: { width: SCREEN_WIDTH, height: SCREEN_HEIGHT * 0.8 },
  fullscreenClose: { position: 'absolute', top: 60, right: 20, padding: 8, backgroundColor: 'rgba(255,255,255,0.15)', borderRadius: 20 },
  fullscreenNav: { position: 'absolute', bottom: 60, flexDirection: 'row', alignItems: 'center', gap: 20 },
  navBtn: { padding: 10 },
  navCounter: { fontFamily: Typography.mono, fontSize: 14, color: '#fff' },
});
