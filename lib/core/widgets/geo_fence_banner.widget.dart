// lib/core/widgets/geo_fence_banner.widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poultryos_farmer_app/core/services/geo_fence_provider.dart';
import 'package:poultryos_farmer_app/core/services/geo_fence_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';

/// A persistent top-of-screen banner that shows the current geo-fence status
/// and provides a manual re-check button.
class GeoFenceBanner extends ConsumerWidget {
  const GeoFenceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geoState = ref.watch(geoFenceProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _BannerContent(
        key: ValueKey(geoState.result.status),
        result: geoState.result,
        isLoading: geoState.isLoading,
        onReCheck: () => ref.read(geoFenceProvider.notifier).reCheck(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _BannerContent extends StatelessWidget {
  final GeoFenceResult result;
  final bool isLoading;
  final VoidCallback onReCheck;

  const _BannerContent({
    super.key,
    required this.result,
    required this.isLoading,
    required this.onReCheck,
  });

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(result.status);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing10,
      ),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: config.borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: config.borderColor.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status indicator ────────────────────────────────────────────
          if (isLoading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(config.iconColor),
              ),
            )
          else
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: config.iconColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: config.iconColor.withOpacity(0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(config.icon, color: Colors.white, size: 13),
            ),

          const SizedBox(width: 10),

          // ── Text block ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize13,
                    fontWeight: FontWeight.w700,
                    color: config.textColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLoading ? 'Verifying your location…' : result.message,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize12,
                    color: config.textColor.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
                if (!isLoading &&
                    result.distanceMeters != null &&
                    result.status != GeoFenceStatus.inside)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '≈ ${result.distanceMeters!.toStringAsFixed(0)} m from permitted zone',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize11,
                        color: config.textColor.withOpacity(0.65),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // ── Re-check button ─────────────────────────────────────────────
          _ReCheckButton(
            isLoading: isLoading,
            iconColor: config.iconColor,
            onTap: onReCheck,
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(GeoFenceStatus status) {
    switch (status) {
      case GeoFenceStatus.inside:
        return _StatusConfig(
          bgColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFF4CAF50),
          iconColor: const Color(0xFF2E7D32),
          textColor: const Color(0xFF1B5E20),
          icon: Icons.check_circle_rounded,
          title: '🟢 Location Verified – Access Granted',
        );
      case GeoFenceStatus.outside:
        return _StatusConfig(
          bgColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFF44336),
          iconColor: const Color(0xFFC62828),
          textColor: const Color(0xFFB71C1C),
          icon: Icons.location_off_rounded,
          title: '🔴 Access Restricted',
        );
      case GeoFenceStatus.permissionDenied:
        return _StatusConfig(
          bgColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFEF9A9A),
          iconColor: const Color(0xFFE53935),
          textColor: const Color(0xFFB71C1C),
          icon: Icons.block_rounded,
          title: '🔴 Location Permission Denied',
        );
      case GeoFenceStatus.gpsUnavailable:
        return _StatusConfig(
          bgColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFB300),
          iconColor: const Color(0xFFF57F17),
          textColor: const Color(0xFFE65100),
          icon: Icons.gps_off_rounded,
          title: '🟡 GPS Unavailable',
        );
      case GeoFenceStatus.apiError:
        return _StatusConfig(
          bgColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFB300),
          iconColor: const Color(0xFFF57F17),
          textColor: const Color(0xFFE65100),
          icon: Icons.cloud_off_rounded,
          title: '🟡 Cannot Verify Location',
        );
      case GeoFenceStatus.unknown:
        return _StatusConfig(
          bgColor: const Color(0xFFF3F4F6),
          borderColor: const Color(0xFFBDBDBD),
          iconColor: const Color(0xFF757575),
          textColor: const Color(0xFF424242),
          icon: Icons.location_searching_rounded,
          title: '🟡 Location Not Verified',
        );
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ReCheckButton extends StatefulWidget {
  final bool isLoading;
  final Color iconColor;
  final VoidCallback onTap;

  const _ReCheckButton({
    required this.isLoading,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_ReCheckButton> createState() => _ReCheckButtonState();
}

class _ReCheckButtonState extends State<_ReCheckButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(_ReCheckButton old) {
    super.didUpdateWidget(old);
    if (widget.isLoading) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verify Location',
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: widget.isLoading
                  ? widget.iconColor.withOpacity(0.4)
                  : widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

class _StatusConfig {
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
  final String title;

  const _StatusConfig({
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
    required this.title,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Blocked State Widget
// ──────────────────────────────────────────────────────────────────────────────

/// Full-screen overlay shown when the user is definitively blocked.
/// Displayed instead of the module content.
class GeoFenceBlockedWidget extends ConsumerWidget {
  const GeoFenceBlockedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geoState = ref.watch(geoFenceProvider);
    final result = geoState.result;
    final isLoading = geoState.isLoading;

    Color accentColor;
    IconData icon;

    switch (result.status) {
      case GeoFenceStatus.permissionDenied:
        accentColor = const Color(0xFFE53935);
        icon = Icons.location_disabled_rounded;
      case GeoFenceStatus.outside:
        accentColor = const Color(0xFFE53935);
        icon = Icons.fence_rounded;
      case GeoFenceStatus.apiError:
        accentColor = const Color(0xFFF57F17);
        icon = Icons.cloud_off_rounded;
      default:
        accentColor = const Color(0xFF757575);
        icon = Icons.location_searching_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──────────────────────────────────────────────────────
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: accentColor),
            ),
            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────────────────
            Text(
              _title(result.status),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSize18,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 10),

            // ── Message ───────────────────────────────────────────────────
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSize13,
                color: AppTheme.grey600,
                height: 1.55,
              ),
            ),

            if (result.distanceMeters != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'You are ≈${result.distanceMeters!.toStringAsFixed(0)} m away from the permitted zone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSize12,
                    color: AppTheme.grey500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // ── Re-check button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref.read(geoFenceProvider.notifier).reCheck(),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(isLoading ? 'Verifying…' : 'Re-check Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
              ),
            ),

            if (result.status == GeoFenceStatus.permissionDenied) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                  if (context.mounted) {
                    ref.read(geoFenceProvider.notifier).reCheck();
                  }
                },
                child: const Text('Open App Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _title(GeoFenceStatus status) {
    switch (status) {
      case GeoFenceStatus.outside:
        return 'Outside Permitted Area';
      case GeoFenceStatus.permissionDenied:
        return 'Location Permission Required';
      case GeoFenceStatus.apiError:
        return 'Cannot Verify Location';
      default:
        return 'Access Restricted';
    }
  }
}

Future<void> openAppSettings() async {
  await Geolocator.openAppSettings();
}
