import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

class CustomSliverAppBar extends StatelessWidget {
  const CustomSliverAppBar({
    required this.title,
    required this.tagline,
    super.key,
    this.docNumber,
    this.date,
    this.actions,
    this.onBackPressed,
    this.showBackButton = true,
  });

  final String title;
  final String tagline;
  final String? docNumber;
  final String? date;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 56, // Standard app bar height
      collapsedHeight: 56,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            child: Row(
              children: [
                /// Leading Back Button
                if (showBackButton)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onBackPressed ??
                        () {
                          if (canPop) {
                            Navigator.of(context).maybePop();
                          } else {
                            context.go('/');
                          }
                        },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppTheme.white,
                        size: 24,
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 40,
                  ), // Keeps balance when no back button
                /// Centered Title
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fontSize = constraints.maxWidth * 0.06;

                        return Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFamily: 'Poppins',
                                    color: AppTheme.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: fontSize.clamp(16, 22),
                                    height: 1.2,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ),

                /// Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actions != null) ...[
                      ...actions!,
                    ] else
                      const SizedBox(width: 40), // Balance spacing
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
