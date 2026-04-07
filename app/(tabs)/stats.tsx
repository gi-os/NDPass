import { useCallback, useState } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { getStats } from '@/lib/database';
import { formatDisplayDate } from '@/lib/utils';
import GlassCard from '@/components/GlassCard';

type Stats = Awaited<ReturnType<typeof getStats>>;

export default function StatsScreen() {
  const [stats, setStats] = useState<Stats | null>(null);
  useFocusEffect(useCallback(() => { getStats().then(setStats); }, []));
  if (!stats) return <View style={styles.container} />;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Hero */}
      <GlassCard style={styles.heroCard} elevated>
        <Text style={styles.heroNumber}>{stats.totalTickets}</Text>
        <Text style={styles.heroLabel}>STUBS COLLECTED</Text>
      </GlassCard>

      {/* Primary grid */}
      <View style={styles.grid}>
        <GlassCard style={styles.statCard}>
          <Ionicons name="calendar-outline" size={18} color={Colors.amber} />
          <Text style={styles.statValue}>{stats.thisMonth}</Text>
          <Text style={styles.statLabel}>THIS MONTH</Text>
        </GlassCard>
        <GlassCard style={styles.statCard}>
          <Ionicons name="film-outline" size={18} color={Colors.amber} />
          <Text style={styles.statValue}>{stats.thisYear}</Text>
          <Text style={styles.statLabel}>THIS YEAR</Text>
        </GlassCard>
      </View>

      {/* Secondary grid */}
      <View style={styles.grid}>
        <GlassCard style={styles.statCard}>
          <Ionicons name="cash-outline" size={18} color={Colors.green} />
          <Text style={styles.statValue}>${stats.totalSpent.toFixed(0)}</Text>
          <Text style={styles.statLabel}>TOTAL SPENT</Text>
        </GlassCard>
        <GlassCard style={styles.statCard}>
          <Ionicons name="trending-up-outline" size={18} color={Colors.green} />
          <Text style={styles.statValue}>{stats.avgPerMonth}</Text>
          <Text style={styles.statLabel}>AVG / MONTH</Text>
        </GlassCard>
      </View>

      {/* Tertiary grid */}
      <View style={styles.grid}>
        <GlassCard style={styles.statCard}>
          <Ionicons name="videocam-outline" size={18} color={Colors.cream} />
          <Text style={styles.statValue}>{stats.uniqueMovies}</Text>
          <Text style={styles.statLabel}>UNIQUE FILMS</Text>
        </GlassCard>
        <GlassCard style={styles.statCard}>
          <Ionicons name="business-outline" size={18} color={Colors.cream} />
          <Text style={styles.statValue}>{stats.uniqueTheaters}</Text>
          <Text style={styles.statLabel}>THEATERS</Text>
        </GlassCard>
      </View>

      {/* Top theaters */}
      {stats.topTheaters.length > 0 && (
        <GlassCard style={styles.listCard}>
          <Text style={styles.listTitle}>TOP THEATERS</Text>
          {stats.topTheaters.map((t, i) => (
            <View key={t.theater} style={styles.listRow}>
              <Text style={styles.listRank}>{i + 1}</Text>
              <Text style={styles.listName} numberOfLines={1}>{t.theater}</Text>
              <Text style={styles.listCount}>{t.count}</Text>
            </View>
          ))}
        </GlassCard>
      )}

      {/* Recent movies */}
      {stats.recentMovies.length > 0 && (
        <GlassCard style={styles.listCard}>
          <Text style={styles.listTitle}>RECENT</Text>
          {stats.recentMovies.map((m, i) => (
            <View key={`${m.movieTitle}-${i}`} style={styles.listRow}>
              <Ionicons name="film" size={14} color={Colors.textMuted} />
              <Text style={styles.listName} numberOfLines={1}>{m.movieTitle}</Text>
              <Text style={styles.listDate}>{formatDisplayDate(m.date)}</Text>
            </View>
          ))}
        </GlassCard>
      )}

      {/* Favorite */}
      {stats.favoriteTheater && (
        <GlassCard style={styles.favoriteCard}>
          <Ionicons name="heart" size={18} color={Colors.red} />
          <View style={styles.favoriteInfo}>
            <Text style={styles.favoriteLabel}>FAVORITE THEATER</Text>
            <Text style={styles.favoriteName}>{stats.favoriteTheater}</Text>
          </View>
        </GlassCard>
      )}

      {stats.totalTickets === 0 && (
        <Text style={styles.emptyText}>Scan your first ticket to see stats</Text>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { padding: Spacing.md, gap: Spacing.md, paddingBottom: 120 },

  heroCard: { padding: Spacing.xxl, alignItems: 'center' },
  heroNumber: { fontFamily: Typography.body, fontSize: 72, fontWeight: '200', color: Colors.cream, letterSpacing: -4 },
  heroLabel: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 3, marginTop: Spacing.xs },

  grid: { flexDirection: 'row', gap: Spacing.md },
  statCard: { flex: 1, padding: Spacing.lg, alignItems: 'center', gap: Spacing.sm },
  statValue: { fontFamily: Typography.body, fontSize: 28, fontWeight: '300', color: Colors.cream },
  statLabel: { fontFamily: Typography.mono, fontSize: 8, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2 },

  // Lists
  listCard: { padding: Spacing.lg },
  listTitle: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2, marginBottom: Spacing.md },
  listRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, paddingVertical: 8, borderBottomWidth: 0.5, borderBottomColor: 'rgba(255,255,255,0.05)' },
  listRank: { fontFamily: Typography.mono, fontSize: 14, fontWeight: '700', color: Colors.amber, width: 24, textAlign: 'center' },
  listName: { fontFamily: Typography.mono, fontSize: 13, color: Colors.cream, flex: 1 },
  listCount: { fontFamily: Typography.mono, fontSize: 13, fontWeight: '700', color: Colors.textSecondary },
  listDate: { fontFamily: Typography.mono, fontSize: 10, color: Colors.textMuted },

  favoriteCard: { flexDirection: 'row', alignItems: 'center', padding: Spacing.lg, gap: Spacing.md },
  favoriteInfo: { flex: 1 },
  favoriteLabel: { fontFamily: Typography.mono, fontSize: 9, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2 },
  favoriteName: { fontFamily: Typography.body, fontSize: 17, fontWeight: '600', color: Colors.cream, marginTop: 2 },

  emptyText: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textMuted, textAlign: 'center', paddingVertical: Spacing.xxl },
});
