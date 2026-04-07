import { useCallback, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Glass, Spacing, Radius, Typography } from '@/constants/theme';
import { getStats } from '@/lib/database';
import GlassCard from '@/components/GlassCard';

interface Stats { totalTickets: number; totalSpent: number; favoriteTheater: string | null; thisMonth: number; }

export default function StatsScreen() {
  const [stats, setStats] = useState<Stats | null>(null);
  useFocusEffect(useCallback(() => { getStats().then(setStats); }, []));
  if (!stats) return <View style={styles.container} />;

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <GlassCard style={styles.heroCard} elevated>
          <Text style={styles.heroNumber}>{stats.totalTickets}</Text>
          <Text style={styles.heroLabel}>STUBS COLLECTED</Text>
        </GlassCard>

        <View style={styles.grid}>
          <GlassCard style={styles.statCard}>
            <Ionicons name="calendar-outline" size={20} color={Colors.amber} />
            <Text style={styles.statValue}>{stats.thisMonth}</Text>
            <Text style={styles.statLabel}>THIS MONTH</Text>
          </GlassCard>
          <GlassCard style={styles.statCard}>
            <Ionicons name="cash-outline" size={20} color={Colors.green} />
            <Text style={styles.statValue}>${stats.totalSpent.toFixed(0)}</Text>
            <Text style={styles.statLabel}>TOTAL SPENT</Text>
          </GlassCard>
        </View>

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
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { padding: Spacing.md, gap: Spacing.md },
  heroCard: { padding: Spacing.xxl, alignItems: 'center' },
  heroNumber: { fontFamily: Typography.body, fontSize: 72, fontWeight: '200', color: Colors.cream, letterSpacing: -4 },
  heroLabel: { fontFamily: Typography.mono, fontSize: 11, fontWeight: '700', color: Colors.textMuted, letterSpacing: 3, marginTop: Spacing.xs },
  grid: { flexDirection: 'row', gap: Spacing.md },
  statCard: { flex: 1, padding: Spacing.lg, alignItems: 'center', gap: Spacing.sm },
  statValue: { fontFamily: Typography.body, fontSize: 28, fontWeight: '300', color: Colors.cream },
  statLabel: { fontFamily: Typography.mono, fontSize: 9, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2 },
  favoriteCard: { flexDirection: 'row', alignItems: 'center', padding: Spacing.lg, gap: Spacing.md },
  favoriteInfo: { flex: 1 },
  favoriteLabel: { fontFamily: Typography.mono, fontSize: 9, fontWeight: '700', color: Colors.textMuted, letterSpacing: 2 },
  favoriteName: { fontFamily: Typography.body, fontSize: 17, fontWeight: '600', color: Colors.cream, marginTop: 2 },
  emptyText: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textMuted, textAlign: 'center', paddingVertical: Spacing.xxl },
});
