import 'package:material_ui/material_ui.dart';

class AppSnackBar extends SnackBar {
  AppSnackBar({
    super.key,
    required BuildContext context,
    required Widget content,
    Color? backgroundColor,
    double? elevation,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
    SnackBarBehavior? behavior,
    Duration? duration,
    DismissDirection? dismissDirection,
    double? width,
  }) : super(
         content: _buildContent(context, content, backgroundColor),
         backgroundColor: Theme.of(context).colorScheme.inverseSurface,
         elevation: 6,
         margin: MediaQuery.sizeOf(context).width >= 600
             ? null
             : const EdgeInsets.fromLTRB(16, 0, 16, 16),
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(14),
           side: BorderSide(
             color: Theme.of(context).colorScheme.outlineVariant
                 .withValues(alpha: 0.45),
           ),
         ),
         behavior: SnackBarBehavior.floating,
         duration: duration ?? const Duration(milliseconds: 1600),
         dismissDirection: dismissDirection ?? DismissDirection.horizontal,
         width: MediaQuery.sizeOf(context).width >= 600 ? 360 : null,
       );

  static Widget _buildContent(
    BuildContext context,
    Widget content,
    Color? originalBackground,
  ) {
    final colors = Theme.of(context).colorScheme;
    final message = content is Text ? content.data?.trim().toLowerCase() : null;
    final isError =
        originalBackground == colors.error ||
        originalBackground == colors.errorContainer ||
        (message != null &&
            (message.startsWith('unable') ||
                message.startsWith('failed') ||
                message.startsWith('error') ||
                message.startsWith('could not') ||
                message.startsWith('invalid') ||
                message.startsWith('no ') ||
                message.contains('failed') ||
                message.contains('error') ||
                message.contains('exception')));

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isError ? colors.errorContainer : colors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isError ? Icons.error_outline_rounded : Icons.check_rounded,
            color: isError
                ? colors.onErrorContainer
                : colors.onPrimaryContainer,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle(
            style: TextStyle(
              color: colors.onInverseSurface,
              fontWeight: FontWeight.w600,
            ),
            child: content,
          ),
        ),
      ],
    );
  }
}

enum AppNotificationType { success, error, info }

class AppNotification {
  static void show(
    BuildContext context, {
    required String message,
    AppNotificationType type = AppNotificationType.success,
  }) {
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.inverseSurface,
          elevation: 6,
          width: MediaQuery.sizeOf(context).width >= 600 ? 360 : null,
          margin: MediaQuery.sizeOf(context).width >= 600
              ? null
              : const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          duration: const Duration(milliseconds: 1600),
          dismissDirection: DismissDirection.horizontal,
          content: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: switch (type) {
                    AppNotificationType.error => colors.errorContainer,
                    AppNotificationType.info => colors.secondaryContainer,
                    AppNotificationType.success => colors.primaryContainer,
                  },
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  switch (type) {
                    AppNotificationType.error => Icons.error_outline_rounded,
                    AppNotificationType.info => Icons.info_outline_rounded,
                    AppNotificationType.success => Icons.check_rounded,
                  },
                  color: switch (type) {
                    AppNotificationType.error => colors.onErrorContainer,
                    AppNotificationType.info => colors.onSecondaryContainer,
                    AppNotificationType.success => colors.onPrimaryContainer,
                  },
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
