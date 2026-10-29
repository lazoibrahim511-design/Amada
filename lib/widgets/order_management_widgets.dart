import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/order_model.dart';

/// Custom Painter to draw a circular work time ring gauge with
/// a solid progress arc and dotted remaining track.
class WorkTimeGaugePainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color dottedColor;

  WorkTimeGaugePainter({
    required this.progress,
    required this.progressColor,
    required this.dottedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 4.5;
    const startAngle = -math.pi / 2;

    // Draw active solid arc
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );

    // Draw remaining track as subtle dots if not full
    if (progress < 0.98) {
      final remainingAngle = 2 * math.pi * (1.0 - progress);
      const dotCount = 18;
      final dotsToDraw = (dotCount * (1.0 - progress)).round();

      final dotPaint = Paint()
        ..color = dottedColor
        ..style = PaintingStyle.fill;

      for (int i = 1; i <= dotsToDraw; i++) {
        final angle = startAngle + sweepAngle + (remainingAngle * (i / (dotsToDraw + 1)));
        final dx = center.dx + radius * math.cos(angle);
        final dy = center.dy + radius * math.sin(angle);
        canvas.drawCircle(Offset(dx, dy), 1.6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WorkTimeGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.dottedColor != dottedColor;
  }
}

/// Circular Work Time Gauge widget showing elapsed time and status
class WorkTimeGauge extends StatelessWidget {
  final String workTime;
  final double progress;
  final OrderStatus status;

  const WorkTimeGauge({
    super.key,
    required this.workTime,
    required this.progress,
    required this.status,
  });

  Color _getGaugeColor() {
    switch (status) {
      case OrderStatus.preparing:
        return const Color(0xFFFBBF24); // Amber
      case OrderStatus.ready:
        return const Color(0xFF22C55E); // Green
      case OrderStatus.pending:
        return const Color(0xFFF97316); // Orange
      case OrderStatus.completed:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaugeColor = _getGaugeColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(76, 76),
            painter: WorkTimeGaugePainter(
              progress: progress,
              progressColor: gaugeColor,
              dottedColor: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                workTime,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Work time',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top Metric Card (Pending, Preparing, Ready to serve)
class OrderMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const OrderMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : const Color(0xFF8E95A5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today Order Complete Card with multi-segment progress bar
class OrderCompletionCard extends StatelessWidget {
  final String title;
  final int completedCount;
  final int totalCount;

  const OrderCompletionCard({
    super.key,
    this.title = 'Today Order Complete',
    this.completedCount = 70,
    this.totalCount = 136,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row: Title & Fraction
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$completedCount',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: '/$totalCount',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Percentage Tick Row
          Row(
            children: [
              Expanded(
                flex: 33,
                child: Row(
                  children: [
                    Text(
                      '33%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF8E95A5),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 27,
                child: Row(
                  children: [
                    Container(
                      width: 1.5,
                      height: 10,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '60%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF8E95A5),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 40,
                child: Row(
                  children: [
                    Container(
                      width: 1.5,
                      height: 10,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '100%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF8E95A5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Segmented Progress Bar Track
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  // 33% Yellow
                  Expanded(
                    flex: 33,
                    child: Container(
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // 27% Yellow gradient
                  Expanded(
                    flex: 27,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFBBF24),
                            Color(0xFFFDE68A),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // 40% Light Gray track
                  Expanded(
                    flex: 40,
                    child: Container(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Active Order Card widget matching the design screenshot
class ActiveOrderCard extends StatelessWidget {
  final RestaurantOrder order;
  final VoidCallback onPrimaryAction;
  final VoidCallback onViewDetails;

  const ActiveOrderCard({
    super.key,
    required this.order,
    required this.onPrimaryAction,
    required this.onViewDetails,
  });

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg;
    Color textColor;

    switch (status) {
      case OrderStatus.preparing:
        bg = const Color(0xFFFFF0EA);
        textColor = const Color(0xFFF97316);
        break;
      case OrderStatus.ready:
        bg = const Color(0xFFE6F9EE);
        textColor = const Color(0xFF16A34A);
        break;
      case OrderStatus.pending:
        bg = const Color(0xFFFFF0EA);
        textColor = const Color(0xFFF97316);
        break;
      case OrderStatus.completed:
        bg = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.status.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    String? boldValue,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                if (boldValue != null)
                  TextSpan(
                    text: boldValue,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Primary button setup
    String primaryText;
    Color primaryBg;
    Color primaryTextColor;

    switch (order.status) {
      case OrderStatus.preparing:
        primaryText = 'Mark Ready';
        primaryBg = const Color(0xFFFBBF24);
        primaryTextColor = const Color(0xFF1E293B);
        break;
      case OrderStatus.ready:
        primaryText = 'Mark Complete';
        primaryBg = const Color(0xFF0F172A);
        primaryTextColor = Colors.white;
        break;
      case OrderStatus.pending:
        primaryText = 'Accept';
        primaryBg = const Color(0xFFFA5E38);
        primaryTextColor = Colors.white;
        break;
      case OrderStatus.completed:
        primaryText = 'Completed';
        primaryBg = const Color(0xFF94A3B8);
        primaryTextColor = Colors.white;
        break;
    }

    // Determine leading icons
    IconData locationIcon = Icons.meeting_room_outlined;
    if (order.locationLabel.toLowerCase().contains('table')) {
      locationIcon = Icons.wine_bar_outlined;
    } else if (order.locationLabel.toLowerCase().contains('take')) {
      locationIcon = Icons.takeout_dining_outlined;
    }

    IconData typeIcon = Icons.people_outline;
    if (order.typeLabel.toLowerCase().contains('online')) {
      typeIcon = Icons.language_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFECEEF1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Order ID + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.id,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: Metadata & Work Time Gauge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Metadata 2x2 grid
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            icon: locationIcon,
                            label: order.locationLabel,
                            boldValue: order.locationValue,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRow(
                            icon: typeIcon,
                            label: order.typeLabel,
                            boldValue: order.typeValue,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            icon: Icons.access_time,
                            label: 'Time',
                            boldValue: order.time,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRow(
                            icon: Icons.person_outline,
                            label: order.serverName,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Work Time Gauge
              WorkTimeGauge(
                workTime: order.workTime,
                progress: order.workTimeProgress,
                status: order.status,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Table Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Item',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : const Color(0xFF8E95A5),
                ),
              ),
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : const Color(0xFF8E95A5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Items List
          ...order.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (idx > 0)
                  Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    height: 18,
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty ${item.quantity}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 18),

          // Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Text(
                '\$${order.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onPrimaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBg,
                      foregroundColor: primaryTextColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      primaryText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onViewDetails,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog for viewing full order details
class OrderDetailsDialog extends StatelessWidget {
  final RestaurantOrder order;

  const OrderDetailsDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.id,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Location', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text('${order.locationLabel} ${order.locationValue ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Type', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text('${order.typeLabel} ${order.typeValue ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Server', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text(order.serverName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Items Ordered',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.quantity}x  ${item.name}', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('\$${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFA5E38)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for creating a new order
class AddNewOrderDialog extends StatefulWidget {
  final Function(RestaurantOrder) onOrderCreated;

  const AddNewOrderDialog({super.key, required this.onOrderCreated});

  @override
  State<AddNewOrderDialog> createState() => _AddNewOrderDialogState();
}

class _AddNewOrderDialogState extends State<AddNewOrderDialog> {
  final _idController = TextEditingController(text: 'Order 004');
  final _locationController = TextEditingController(text: 'Table');
  final _locationValController = TextEditingController(text: '04');
  final _guestsController = TextEditingController(text: '04');
  final _serverController = TextEditingController(text: 'John doe');

  @override
  void dispose() {
    _idController.disposeWidget();
    _locationController.dispose();
    _locationValController.dispose();
    _guestsController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New Order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Order Number / ID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Type (Table/Room)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _locationValController,
                      decoration: const InputDecoration(labelText: 'Number (e.g. 04)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _guestsController,
                      decoration: const InputDecoration(labelText: 'Guests Count', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _serverController,
                      decoration: const InputDecoration(labelText: 'Assigned Server', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final newOrder = RestaurantOrder(
                      id: _idController.text.trim(),
                      status: OrderStatus.pending,
                      locationLabel: _locationController.text.trim(),
                      locationValue: _locationValController.text.trim(),
                      typeLabel: 'Guests',
                      typeValue: _guestsController.text.trim(),
                      time: '0:01',
                      serverName: _serverController.text.trim(),
                      workTime: '01:00',
                      workTimeProgress: 0.1,
                      items: const [
                        OrderItem(name: 'Signature Burger', quantity: 2, price: 24.00),
                        OrderItem(name: 'Fresh Lemonade', quantity: 2, price: 12.00),
                      ],
                      totalAmount: 72.00,
                    );
                    widget.onOrderCreated(newOrder);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA5E38),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Create Order', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on TextEditingController {
  void disposeWidget() {
    dispose();
  }
}
