import { useCallback, useState } from 'react';
import {
  View, Text, FlatList, Image, TouchableOpacity, StyleSheet,
  RefreshControl, Alert, ImageBackground,
} from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { getActiveTickets, getArchivedTickets, groupTickets, deleteTicket } from '@/lib/database';
import { getPosterUrl } from '@/lib/tmdb';
import { formatDisplayDate } from '@/lib/utils';
import { TicketGroup } from '@/lib/types';

export default function HomeScreen() {
  const router = useRouter();
  const [activeGroups, setActiveGroups] = useState<TicketGroup[]>([]);
  const [archivedGroups, setArchivedGroups] = useState<TicketGroup[]>([]);
  const [showArchive, setShowArchive] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const active = await getActiveTickets();
    const archived = await getArchivedTickets();
    setActiveGroups(groupTickets(active));
    setArchivedGroups(groupTickets(archived));
  }, []);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const onRefresh = async () => { setRefreshing(true); await load(); setRefreshing(false); };

  const handleDelete = (group: TicketGroup) => {
    Alert.alert('Delete', `Remove ${group.tickets.length > 1 ? `${group.tickets.length} tickets for` : ''} ${group.movieTitle}?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          for (const t of group.tickets) await deleteTicket(t.id);
          await load();
        },
      },
    ]);
  };

  const renderGroup = ({ item }: { item: TicketGroup }) => {
    const posterUri = item.posterPath ? getPosterUrl(item.posterPath, 'w342') : null;
    const ticketCount = item.tickets.length;
    const firstTicket = item.tickets[0];

    return (
      <TouchableOpacity
        style={styles.card}
        activeOpacity={0.85}
        onPress={() => router.push(`/ticket/${firstTicket.id}`)}
        onLongPress={() => handleDelete(item)}
      >
        {/* Background — poster or fallback */}
        {posterUri ? (
          <ImageBackground
            source={{ uri: posterUri }}
            style={styles.cardBg}
            imageStyle={styles.cardBgImage}
          >
            <View style={styles.cardOverlay}>
              <CardContent group={item} ticketCount={ticketCount} />
            </View>
          </ImageBackground>
        ) : (
          <View style={[styles.cardBg, styles.cardFallbackBg]}>
            <CardContent group={item} ticketCount={ticketCount} />
          </View>
        )}
      </TouchableOpacity>
    );
  };

  const data = showArchive ? archivedGroups : activeGroups;

  return (
    <View style={styles.container}>
      {/* Toggle */}
      {archivedGroups.length > 0 && (
        <View style={styles.toggleRow}>
          <TouchableOpacity
            style={[styles.toggleBtn, !showArchive && styles.toggleActive]}
            onPress={() => setShowArchive(false)}
          >
            <Text style={[styles.toggleText, !showArchive && styles.toggleTextActive]}>
              UPCOMING ({activeGroups.length})
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.toggleBtn, showArchive && styles.toggleActive]}
            onPress={() => setShowArchive(true)}
          >
            <Text style={[styles.toggleText, showArchive && styles.toggleTextActive]}>
              ARCHIVE ({archivedGroups.length})
            </Text>
          </TouchableOpacity>
        </View>
      )}

      <FlatList
        data={data}
        keyExtractor={(item) => item.groupKey}
        renderItem={renderGroup}
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Ionicons name="ticket-outline" size={64} color={Colors.creamDim} />
            <Text style={styles.emptyTitle}>
              {showArchive ? 'No archived stubs' : 'No stubs yet'}
            </Text>
            <Text style={styles.emptySubtitle}>
              {showArchive ? 'Past showings appear here' : 'Scan your first movie ticket'}
            </Text>
          </View>
        }
        contentContainerStyle={data.length === 0 ? styles.emptyContainer : styles.listContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.cream} />}
        ItemSeparatorComponent={() => <View style={{ height: Spacing.md }} />}
      />
    </View>
  );
}

function CardContent({ group, ticketCount }: { group: TicketGroup; ticketCount: number }) {
  return (
    <View style={styles.cardContent}>
      <View style={styles.cardTop}>
        {ticketCount > 1 && (
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{ticketCount} tickets</Text>
          </View>
        )}
      </View>
      <View style={styles.cardBottom}>
        <Text style={styles.cardTitle} numberOfLines={2}>{group.movieTitle}</Text>
        <Text style={styles.cardTheater} numberOfLines={1}>{group.theater}</Text>
        <View style={styles.cardMeta}>
          <Text style={styles.cardMetaText}>{formatDisplayDate(group.date)}</Text>
          <Text style={styles.cardDot}>·</Text>
          <Text style={styles.cardMetaText}>{group.time}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  listContent: { padding: Spacing.md, paddingBottom: 120 },
  emptyContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  emptyState: { alignItems: 'center', paddingHorizontal: Spacing.xl },
  emptyTitle: { fontFamily: Typography.mono, fontSize: 20, color: Colors.cream, marginTop: Spacing.lg, fontWeight: '700' },
  emptySubtitle: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.sm },

  // Toggle
  toggleRow: { flexDirection: 'row', paddingHorizontal: Spacing.md, paddingTop: Spacing.sm, gap: Spacing.sm },
  toggleBtn: { paddingVertical: 8, paddingHorizontal: Spacing.md, borderRadius: 20, backgroundColor: Colors.bgCard, borderWidth: 0.5, borderColor: Colors.border },
  toggleActive: { backgroundColor: Colors.cream, borderColor: Colors.cream },
  toggleText: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 1 },
  toggleTextActive: { color: Colors.bg },

  // Card
  card: { borderRadius: Radius.xl, overflow: 'hidden', height: 200, borderWidth: 0.5, borderColor: Colors.border },
  cardBg: { flex: 1 },
  cardBgImage: { resizeMode: 'cover' },
  cardFallbackBg: { backgroundColor: Colors.bgCard, justifyContent: 'flex-end', padding: Spacing.lg },
  cardOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.55)' },
  cardContent: { flex: 1, justifyContent: 'space-between', padding: Spacing.lg },
  cardTop: { flexDirection: 'row', justifyContent: 'flex-end' },
  badge: { backgroundColor: Colors.amber, paddingHorizontal: 10, paddingVertical: 3, borderRadius: 12 },
  badgeText: { fontFamily: Typography.mono, fontSize: 10, fontWeight: '700', color: Colors.bg },
  cardBottom: {},
  cardTitle: { fontFamily: Typography.mono, fontSize: 22, fontWeight: '700', color: '#fff', letterSpacing: 0.3 },
  cardTheater: { fontFamily: Typography.mono, fontSize: 13, color: Colors.cream, marginTop: 2 },
  cardMeta: { flexDirection: 'row', alignItems: 'center', marginTop: Spacing.xs },
  cardMetaText: { fontFamily: Typography.mono, fontSize: 12, color: 'rgba(255,255,255,0.7)' },
  cardDot: { fontFamily: Typography.mono, fontSize: 12, color: 'rgba(255,255,255,0.4)', marginHorizontal: 6 },
});
