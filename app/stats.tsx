import { useCallback, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Spacing, Radius, Typography } from '@/constants/theme';
import { getStats } from '@/lib/database';

interface Stats {
  totalTickets: number;
  totalSpent: number;
  favoriteTheater: string | null;
  thisMonth: number;
}

export default function StatsScreen() {
  const [stats, setStats] = useState<Stats | null>(null);

  useFocusEffect(
    useCallback(() => {
      getStats().then(setStats);
    }, [])
  );

  if (!stats) return <View style={styles.container} />;

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        {/* Hero stat */}
        <View style={styles.heroCard}>
          <Text style={styles.heroNumber}>{stats.totalTickets}</Text>
          <Text style={styles.heroLabel}>STUBS COLLECTED</Text>
        </View>

        {/* Grid */}
        <View style={styles.grid}>
          <StatCard
            icon="calendar-outline"
            value={stats.thisMonth.toString()}
            label="THIS MONTH"
          />
          <StatCard
            icon="cash-outline"
            value={`$${stats.totalSpent.toFixed(0)}`}
            label="TOTAL SPENT"
          />
        </View>

        {stats.favoriteTheater && (
          <View style={styles.favoriteCard}>
            <Ionicons name="heart" size={16} color={Colors.red} />
            <View style={styles.favoriteInfo}>
              <Text style={styles.favoriteLabel}>FAVORITE THEATER</Text>
              <Text style={styles.favoriteName}>{stats.favoriteTheater}</Text>
            </View>
          </View>
        )}

        {stats.totalTickets === 0 && (
          <View style={styles.emptyPrompt}>
            <Text style={styles.emptyText}>
              Scan your first ticket to see stats here
            </Text>
          </View>
        )}
      </View>
    </View>
  );
}

function StatCard({
  icon,
  value,
  label,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  value: string;
  label: string;
}) {
  return (
    <View style={styles.statCard}>
      <Ionicons name={icon} size={20} color={Colors.creamMuted} />
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  content: {
    padding: Spacing.md,
    gap: Spacing.md,
  },

  // Hero
  heroCard: {
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.xl,
    padding: Spacing.xxl,
    alignItems: 'center',
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  heroNumber: {
    fontFamily: Typography.mono,
    fontSize: 72,
    fontWeight: '700',
    color: Colors.cream,
    letterSpacing: -2,
  },
  heroLabel: {
    fontFamily: Typography.mono,
    fontSize: 11,
    fontWeight: '700',
    color: Colors.textMuted,
    letterSpacing: 3,
    marginTop: Spacing.xs,
  },

  // Grid
  grid: {
    flexDirection: 'row',
    gap: Spacing.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.card,
    padding: Spacing.lg,
    alignItems: 'center',
    gap: Spacing.sm,
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  statValue: {
    fontFamily: Typography.mono,
    fontSize: 28,
    fontWeight: '700',
    color: Colors.cream,
  },
  statLabel: {
    fontFamily: Typography.mono,
    fontSize: 9,
    fontWeight: '700',
    color: Colors.textMuted,
    letterSpacing: 2,
  },

  // Favorite
  favoriteCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.bgCard,
    borderRadius: Radius.card,
    padding: Spacing.lg,
    gap: Spacing.md,
    borderWidth: 0.5,
    borderColor: Colors.border,
  },
  favoriteInfo: {
    flex: 1,
  },
  favoriteLabel: {
    fontFamily: Typography.mono,
    fontSize: 9,
    fontWeight: '700',
    color: Colors.textMuted,
    letterSpacing: 2,
  },
  favoriteName: {
    fontFamily: Typography.mono,
    fontSize: 16,
    fontWeight: '700',
    color: Colors.cream,
    marginTop: 2,
  },

  // Empty
  emptyPrompt: {
    alignItems: 'center',
    paddingVertical: Spacing.xxl,
  },
  emptyText: {
    fontFamily: Typography.mono,
    fontSize: 13,
    color: Colors.textMuted,
    textAlign: 'center',
  },
});
