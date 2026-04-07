import { useCallback, useState } from 'react';
import {
  View, Text, FlatList, Image, TouchableOpacity, StyleSheet,
  RefreshControl, Alert, ImageBackground, Dimensions,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Glass, Spacing, Radius, Typography } from '@/constants/theme';
import { getActiveTickets, getArchivedTickets, groupTickets, deleteTicket } from '@/lib/database';
import { getPosterUrl, getBackdropUrl } from '@/lib/tmdb';
import { formatDisplayDate } from '@/lib/utils';
import { TicketGroup } from '@/lib/types';
import GlassCard from '@/components/GlassCard';

const { width: SCREEN_W } = Dimensions.get('window');

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
    Alert.alert('Delete', `Remove ${group.movieTitle}?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => {
        for (const t of group.tickets) await deleteTicket(t.id);
        await load();
      }},
    ]);
  };

  const renderGroup = ({ item }: { item: TicketGroup }) => {
    const posterUri = item.posterPath ? getPosterUrl(item.posterPath, 'w500') : null;
    const backdropUri = item.backdropPath ? getBackdropUrl(item.backdropPath) : null;
    const ticketCount = item.tickets.length;
    const firstTicket = item.tickets[0];

    return (
      <TouchableOpacity
        activeOpacity={0.88}
        onPress={() => router.push(`/ticket/${firstTicket.id}`)}
        onLongPress={() => handleDelete(item)}
      >
        <View style={styles.movieCard}>
          {/* Background — backdrop or poster with gradient overlay */}
          {(backdropUri || posterUri) && (
            <ImageBackground
              source={{ uri: backdropUri ?? posterUri! }}
              style={StyleSheet.absoluteFillObject}
              imageStyle={styles.cardBgImage}
              blurRadius={backdropUri ? 0 : 8}
            />
          )}

          {/* Gradient overlay for readability */}
          <LinearGradient
            colors={['transparent', 'rgba(8,8,16,0.6)', 'rgba(8,8,16,0.95)']}
            locations={[0, 0.5, 1]}
            style={StyleSheet.absoluteFillObject}
          />

          {/* Glass info panel at bottom */}
          <View style={styles.cardContent}>
            {/* Poster thumbnail */}
            <View style={styles.cardRow}>
              {posterUri && (
                <Image source={{ uri: posterUri }} style={styles.posterMini} />
              )}
              <View style={styles.cardInfo}>
                <Text style={styles.cardTitle} numberOfLines={2}>{item.movieTitle}</Text>
                <Text style={styles.cardTheater} numberOfLines={1}>{item.theater}</Text>
                <View style={styles.cardMeta}>
                  <Text style={styles.cardMetaText}>{formatDisplayDate(item.date)}</Text>
                  <View style={styles.dot} />
                  <Text style={styles.cardMetaText}>{item.time}</Text>
                </View>
              </View>
            </View>

            {/* Ticket count badge */}
            {ticketCount > 1 && (
              <View style={styles.badge}>
                <Ionicons name="ticket" size={11} color={Colors.bg} />
                <Text style={styles.badgeText}>{ticketCount}</Text>
              </View>
            )}
          </View>

          {/* Glass border overlay */}
          <View style={styles.cardGlassBorder} />
        </View>
      </TouchableOpacity>
    );
  };

  const data = showArchive ? archivedGroups : activeGroups;

  return (
    <View style={styles.container}>
      {/* Archive toggle */}
      {archivedGroups.length > 0 && (
        <View style={styles.toggleRow}>
          <TouchableOpacity
            style={[styles.toggleBtn, !showArchive && styles.toggleActive]}
            onPress={() => setShowArchive(false)}
          >
            <Text style={[styles.toggleText, !showArchive && styles.toggleTextActive]}>
              Upcoming
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.toggleBtn, showArchive && styles.toggleActive]}
            onPress={() => setShowArchive(true)}
          >
            <Text style={[styles.toggleText, showArchive && styles.toggleTextActive]}>
              Archive
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
            <View style={styles.emptyIcon}>
              <Ionicons name="ticket-outline" size={48} color={Colors.creamDim} />
            </View>
            <Text style={styles.emptyTitle}>{showArchive ? 'No past stubs' : 'No stubs yet'}</Text>
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

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  listContent: { padding: Spacing.md, paddingTop: Spacing.sm, paddingBottom: 120 },
  emptyContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },

  emptyState: { alignItems: 'center', paddingHorizontal: Spacing.xl },
  emptyIcon: {
    width: 96, height: 96, borderRadius: 48,
    ...Glass.panel,
    justifyContent: 'center', alignItems: 'center',
    marginBottom: Spacing.lg,
  },
  emptyTitle: { fontFamily: Typography.body, fontSize: 22, fontWeight: '600', color: Colors.cream },
  emptySubtitle: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textSecondary, textAlign: 'center', marginTop: Spacing.sm },

  // Toggle
  toggleRow: {
    flexDirection: 'row', paddingHorizontal: Spacing.md, paddingTop: Spacing.md,
    paddingBottom: Spacing.sm, gap: Spacing.sm,
  },
  toggleBtn: {
    paddingVertical: 8, paddingHorizontal: Spacing.lg,
    borderRadius: Radius.pill,
    ...Glass.subtle,
  },
  toggleActive: {
    backgroundColor: Colors.glassActive,
    borderColor: Colors.glassBorderLight,
    borderWidth: 1,
  },
  toggleText: { fontFamily: Typography.mono, fontSize: 12, fontWeight: '600', color: Colors.textMuted, letterSpacing: 0.5 },
  toggleTextActive: { color: Colors.cream },

  // Movie card
  movieCard: {
    height: 220,
    borderRadius: Radius.card,
    overflow: 'hidden',
    position: 'relative',
    backgroundColor: Colors.glass,
  },
  cardBgImage: { resizeMode: 'cover', borderRadius: Radius.card },
  cardContent: {
    position: 'absolute', bottom: 0, left: 0, right: 0,
    padding: Spacing.md,
  },
  cardRow: { flexDirection: 'row', gap: Spacing.md },
  posterMini: {
    width: 52, height: 78, borderRadius: Radius.sm,
    borderWidth: 0.5, borderColor: Colors.glassBorder,
  },
  cardInfo: { flex: 1, justifyContent: 'flex-end' },
  cardTitle: { fontFamily: Typography.body, fontSize: 20, fontWeight: '700', color: '#fff', letterSpacing: -0.3 },
  cardTheater: { fontFamily: Typography.mono, fontSize: 12, color: Colors.amber, marginTop: 2, letterSpacing: 0.3 },
  cardMeta: { flexDirection: 'row', alignItems: 'center', marginTop: Spacing.xs },
  cardMetaText: { fontFamily: Typography.mono, fontSize: 11, color: 'rgba(255,255,255,0.6)' },
  dot: { width: 3, height: 3, borderRadius: 1.5, backgroundColor: 'rgba(255,255,255,0.3)', marginHorizontal: 8 },

  badge: {
    position: 'absolute', top: -60, right: 0,
    flexDirection: 'row', alignItems: 'center', gap: 4,
    backgroundColor: Colors.amber, paddingHorizontal: 10, paddingVertical: 4,
    borderRadius: Radius.pill,
  },
  badgeText: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.bg },

  // Glass border overlay
  cardGlassBorder: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: Radius.card,
    borderWidth: 1,
    borderColor: Colors.glassBorder,
    pointerEvents: 'none',
  },
});
