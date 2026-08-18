import 'package:intl/intl.dart';

String formatFullDate(DateTime date) =>
    DateFormat('M月d日 EEEE', 'zh_CN').format(date);

String formatShortDate(DateTime date) =>
    DateFormat('M月d日', 'zh_CN').format(date);

String formatTime(DateTime date) => DateFormat('HH:mm', 'zh_CN').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('yyyy-MM-dd HH:mm', 'zh_CN').format(date);

String formatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
