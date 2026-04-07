import { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  Image,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  Alert,
} from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { getAllTickets, deleteTicket } from '@/lib/database';
import { openLetterboxd } from '@/lib/integrations';
import { formatDisplayDate, formatPrice } from '@/lib/utils';
import { Ticket } from '@/lib/types';

export default function HomeScreen() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  const loadTickets = useCallback(async () => {
    const data = await getAllTickets();
    setTickets(data);
  }, []);

  // Reload when tab is focused
  useFocusEffect(
    useCallback(() => {
      loadTickets();
    }, [loadTickets])
  );

  const onRefresh = async () => {
    setRefreshing(true);
    await loadTickets();
    setRefreshing(false);
  };

  const handleDelete = (ticket: Ticket) => {
    Alert.alert(
      'Delete Stub',
      `Remove ${ticket.movieTitle}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteTicket(ticket.id);
            await loadTickets();
          },
        },
      ]
    );
  };

  const renderTicket = ({ item }: { item: Ticket }) => (
    <View style={styles.ticketCard}>
      {/* Full-width ticket image */}
      <View style={styles.ticketImageContainer}>
        <Image source={{ uri: item.imageUri }} style={styles.ticketImage} />
      </View>

      {/* Info + actions row */}
      <View style={styles.ticketBottom}>
        <View style={styles.ticketInfo}>
          <Text style={styles.movieTitle} numberOfLines={1}>
            {item.movieTitle}
          </Text>
          <Text style={styles.theaterName} numberOfLines={1}>
            {item.theater}
          </Text>

          <View style={styles.ticketMeta}>
            <Text style={styles.metaText}>{formatDisplayDate(item.date)}</Text>
            <Text style={styles.metaDot}>·</Text>
            <Text style={styles.metaText}>{item.time}</Text>
            {item.seat && (
              <>
                <Text style={styles.metaDot}>·</Text>
                <Text style={styles.metaText}>{item.seat}</Text>
              </>
            )}
          </View>

          {item.price && (
            <Text style={styles.priceText}>{formatPrice(item.price)}</Text>
          )}
        </View>

        {/* Actions */}
        <View style={styles.ticketActions}>
          <TouchableOpacity
            onPress={() => openLetterboxd(item.movieTitle)}
            style={styles.actionBtn}
          >
            <Ionicons name="film-outline" size={18} color={Colors.amber} />
          </TouchableOpacity>
          <TouchableOpacity
            onPress={() => handleDelete(item)}
            style={styles.actionBtn}
          >
            <Ionicons name="trash-outline" size={18} color={Colors.textMuted} />
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );

  const renderEmpty = () => (
    <View style={styles.emptyState}>
      <Ionicons name="ticket-outline" size={64} color={Colors.creamDim} />
      <Text style={styles.emptyTitle}>No stubs yet</Text>
      <Text style={styles.emptySubtitle}>
        Scan your first movie ticket to start your collection
      </Text>
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={tickets}
        keyExtractor={(item) => item.id}
        renderItem={renderTicket}
        ListEmptyComponent={renderEmpty}
        contentContainerStyle={tickets.length === 0 ? styles.emptyContainer : styles.listContent}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            tintColor={Colors.cream}
          />
        }
        ItemSeparatorComponent={() => <View style={styles.separator} />}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  listContent: {
    padding: Spacing.md,
    paddingBottom: 120,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyState: {
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
  },
  emptyTitle: {
    fontFamily: Typography.mono,
    fontSize: 20,
    color: Colors.cream,
    marginTop: Spacing.lg,
    fontWeight: '700',
  },
  emptySubtitle: {
    fontFamily: Typography.mono,
    fontSize: 13,
    color: Colors.textSecondary,
    textAlign: 'center',
    marginTop: Spacing.sm,
    lineHeight: 20,
  },
  ticketCard: {
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.card,
    overflow: 'hidden',
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  ticketImageContainer: {
    width: '100%',
    height: 160,
    backgroundColor: Colors.bgElevated,
  },
  ticketImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'contain',
  },
  ticketBottom: {
    flexDirection: 'row',
    padding: Spacing.md,
  },
  ticketInfo: {
    flex: 1,
    justifyContent: 'center',
  },
  movieTitle: {
    fontFamily: Typography.mono,
    fontSize: 16,
    fontWeight: '700',
    color: Colors.cream,
    letterSpacing: 0.3,
  },
  theaterName: {
    fontFamily: Typography.mono,
    fontSize: 12,
    color: Colors.amber,
    marginTop: 2,
    letterSpacing: 0.5,
  },
  ticketMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: Spacing.xs,
  },
  metaText: {
    fontFamily: Typography.mono,
    fontSize: 11,
    color: Colors.textSecondary,
  },
  metaDot: {
    fontFamily: Typography.mono,
    fontSize: 11,
    color: Colors.textMuted,
    marginHorizontal: 4,
  },
  priceText: {
    fontFamily: Typography.mono,
    fontSize: 12,
    color: Colors.green,
    marginTop: 2,
  },
  ticketActions: {
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.md,
    paddingLeft: Spacing.sm,
  },
  actionBtn: {
    padding: 4,
  },
  separator: {
    height: Spacing.sm,
  },
});
