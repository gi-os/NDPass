import { useCallback, useState, useMemo } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet, ScrollView, Dimensions,
} from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Glass, Spacing, Radius, Typography } from '@/constants/theme';
import { getAllTickets } from '@/lib/database';
import { Ticket } from '@/lib/types';
import GlassCard from '@/components/GlassCard';

const { width: SCREEN_W } = Dimensions.get('window');
const DAY_SIZE = Math.floor((SCREEN_W - Spacing.md * 2 - 6 * 4) / 7);
const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

export default function CalendarScreen() {
  const router = useRouter();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [year, setYear] = useState(new Date().getFullYear());
  const [month, setMonth] = useState(new Date().getMonth());

  useFocusEffect(useCallback(() => {
    getAllTickets().then(setTickets);
  }, []));

  // Map date strings to tickets
  const ticketsByDate = useMemo(() => {
    const map = new Map<string, Ticket[]>();
    for (const t of tickets) {
      const existing = map.get(t.date) ?? [];
      existing.push(t);
      map.set(t.date, existing);
    }
    return map;
  }, [tickets]);

  // Calendar grid
  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const today = new Date();
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  const cells: (number | null)[] = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  while (cells.length % 7 !== 0) cells.push(null);

  const prevMonth = () => {
    if (month === 0) { setMonth(11); setYear(y => y - 1); }
    else setMonth(m => m - 1);
  };
  const nextMonth = () => {
    if (month === 11) { setMonth(0); setYear(y => y + 1); }
    else setMonth(m => m + 1);
  };

  // Selected day
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const selectedTickets = selectedDate ? ticketsByDate.get(selectedDate) ?? [] : [];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Month navigation */}
      <View style={styles.monthNav}>
        <TouchableOpacity onPress={prevMonth} style={styles.navArrow}>
          <Ionicons name="chevron-back" size={22} color={Colors.textSecondary} />
        </TouchableOpacity>
        <Text style={styles.monthLabel}>
          {MONTH_NAMES[month]} {year}
        </Text>
        <TouchableOpacity onPress={nextMonth} style={styles.navArrow}>
          <Ionicons name="chevron-forward" size={22} color={Colors.textSecondary} />
        </TouchableOpacity>
      </View>

      {/* Weekday headers */}
      <View style={styles.weekRow}>
        {WEEKDAYS.map((d, i) => (
          <Text key={i} style={styles.weekLabel}>{d}</Text>
        ))}
      </View>

      {/* Calendar grid */}
      <GlassCard style={styles.calendarGrid}>
        {Array.from({ length: cells.length / 7 }, (_, row) => (
          <View key={row} style={styles.weekRow}>
            {cells.slice(row * 7, row * 7 + 7).map((day, col) => {
              if (day === null) return <View key={col} style={styles.dayCell} />;

              const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
              const dayTickets = ticketsByDate.get(dateStr);
              const isToday = dateStr === todayStr;
              const isSelected = dateStr === selectedDate;
              const hasTickets = !!dayTickets && dayTickets.length > 0;

              return (
                <TouchableOpacity
                  key={col}
                  style={[
                    styles.dayCell,
                    isToday && styles.dayCellToday,
                    isSelected && styles.dayCellSelected,
                    hasTickets && styles.dayCellHasTicket,
                  ]}
                  onPress={() => setSelectedDate(dateStr)}
                  activeOpacity={0.7}
                >
                  <Text style={[
                    styles.dayText,
                    isToday && styles.dayTextToday,
                    isSelected && styles.dayTextSelected,
                  ]}>
                    {day}
                  </Text>
                  {hasTickets && (
                    <View style={styles.ticketDot}>
                      {dayTickets.length > 1 && (
                        <Text style={styles.ticketDotCount}>{dayTickets.length}</Text>
                      )}
                    </View>
                  )}
                </TouchableOpacity>
              );
            })}
          </View>
        ))}
      </GlassCard>

      {/* Selected day detail */}
      {selectedDate && selectedTickets.length > 0 && (
        <View style={styles.detailSection}>
          <Text style={styles.detailLabel}>
            {new Date(selectedDate + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
          </Text>
          {selectedTickets.map(t => (
            <TouchableOpacity
              key={t.id}
              onPress={() => router.push(`/ticket/${t.id}`)}
            >
              <GlassCard style={styles.detailCard}>
                <View style={styles.detailRow}>
                  <View style={styles.detailTime}>
                    <Text style={styles.detailTimeText}>{t.time}</Text>
                  </View>
                  <View style={styles.detailInfo}>
                    <Text style={styles.detailTitle}>{t.movieTitle}</Text>
                    <Text style={styles.detailTheater}>{t.theater}</Text>
                    {t.seat && <Text style={styles.detailSeat}>Seat {t.seat}</Text>}
                  </View>
                </View>
              </GlassCard>
            </TouchableOpacity>
          ))}
        </View>
      )}

      {selectedDate && selectedTickets.length === 0 && (
        <Text style={styles.noShowings}>No showings this day</Text>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  content: { padding: Spacing.md, paddingBottom: 120 },

  // Month nav
  monthNav: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: Spacing.lg },
  monthLabel: { fontFamily: Typography.body, fontSize: 20, fontWeight: '600', color: Colors.cream, letterSpacing: -0.3 },
  navArrow: { padding: 8, borderRadius: Radius.pill, ...Glass.subtle },

  // Weekday headers
  weekRow: { flexDirection: 'row', justifyContent: 'space-around' },
  weekLabel: { fontFamily: Typography.mono, fontSize: 11, color: Colors.textMuted, width: DAY_SIZE, textAlign: 'center', marginBottom: Spacing.sm, letterSpacing: 1 },

  // Calendar grid
  calendarGrid: { padding: Spacing.sm },

  // Day cells
  dayCell: {
    width: DAY_SIZE, height: DAY_SIZE,
    justifyContent: 'center', alignItems: 'center',
    borderRadius: Radius.md,
    position: 'relative',
  },
  dayCellToday: {
    borderWidth: 1,
    borderColor: Colors.glassBorderLight,
  },
  dayCellSelected: {
    backgroundColor: Colors.glassActive,
    borderWidth: 1,
    borderColor: Colors.amber,
  },
  dayCellHasTicket: {
    backgroundColor: Colors.amberGlow,
  },
  dayText: { fontFamily: Typography.mono, fontSize: 14, color: Colors.textSecondary },
  dayTextToday: { color: Colors.cream, fontWeight: '700' },
  dayTextSelected: { color: Colors.amber, fontWeight: '700' },

  // Ticket dot
  ticketDot: {
    position: 'absolute', bottom: 4,
    backgroundColor: Colors.amber,
    minWidth: 6, height: 6, borderRadius: 3,
    paddingHorizontal: 2,
    justifyContent: 'center', alignItems: 'center',
  },
  ticketDotCount: { fontFamily: Typography.mono, fontSize: 8, color: Colors.bg, fontWeight: '700' },

  // Detail section
  detailSection: { marginTop: Spacing.lg },
  detailLabel: { fontFamily: Typography.body, fontSize: 16, fontWeight: '600', color: Colors.cream, marginBottom: Spacing.md },
  detailCard: { padding: Spacing.md, marginBottom: Spacing.sm },
  detailRow: { flexDirection: 'row', gap: Spacing.md },
  detailTime: {
    backgroundColor: Colors.amberGlow,
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm,
    borderRadius: Radius.md,
    justifyContent: 'center',
  },
  detailTimeText: { fontFamily: Typography.mono, fontSize: 13, fontWeight: '700', color: Colors.amber },
  detailInfo: { flex: 1, justifyContent: 'center' },
  detailTitle: { fontFamily: Typography.body, fontSize: 16, fontWeight: '600', color: Colors.cream },
  detailTheater: { fontFamily: Typography.mono, fontSize: 12, color: Colors.textSecondary, marginTop: 2 },
  detailSeat: { fontFamily: Typography.mono, fontSize: 11, color: Colors.textMuted, marginTop: 2 },

  noShowings: { fontFamily: Typography.mono, fontSize: 13, color: Colors.textMuted, textAlign: 'center', marginTop: Spacing.xl },
});
