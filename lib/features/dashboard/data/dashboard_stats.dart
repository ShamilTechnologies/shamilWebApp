/// DashboardStats represents a collection of statistics displayed in the dashboard
class DashboardStats {
  /// Number of active subscriptions
  final int activeSubscriptions;

  /// Number of upcoming reservations
  final int upcomingReservations;

  /// Total revenue for the current period
  final double totalRevenue;

  /// Number of new members this month
  final int newMembersMonth;

  /// Number of check-ins today
  final int checkInsToday;

  /// Total bookings this month
  final int totalBookingsMonth;

  /// Creates a new DashboardStats instance
  const DashboardStats({
    required this.activeSubscriptions,
    required this.upcomingReservations,
    required this.totalRevenue,
    required this.newMembersMonth,
    required this.checkInsToday,
    required this.totalBookingsMonth,
  });

  /// Returns an empty stats object with all values set to zero
  factory DashboardStats.empty() {
    return const DashboardStats(
      activeSubscriptions: 0,
      upcomingReservations: 0,
      totalRevenue: 0.0,
      newMembersMonth: 0,
      checkInsToday: 0,
      totalBookingsMonth: 0,
    );
  }

  /// Creates a copy of this object with specified values replaced
  DashboardStats copyWith({
    int? activeSubscriptions,
    int? upcomingReservations,
    double? totalRevenue,
    int? newMembersMonth,
    int? checkInsToday,
    int? totalBookingsMonth,
  }) {
    return DashboardStats(
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      upcomingReservations: upcomingReservations ?? this.upcomingReservations,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      newMembersMonth: newMembersMonth ?? this.newMembersMonth,
      checkInsToday: checkInsToday ?? this.checkInsToday,
      totalBookingsMonth: totalBookingsMonth ?? this.totalBookingsMonth,
    );
  }

  @override
  String toString() {
    return 'DashboardStats(activeSubscriptions: $activeSubscriptions, '
        'upcomingReservations: $upcomingReservations, '
        'totalRevenue: $totalRevenue, '
        'newMembersMonth: $newMembersMonth, '
        'checkInsToday: $checkInsToday, '
        'totalBookingsMonth: $totalBookingsMonth)';
  }
}
