import 'package:flutter/material.dart';

/// Единый набор иконок: округлые формы, outline там, где нужна «лёгкость»,
/// без смешения iOS-стрелок и Material sharp.
abstract final class AppIcons {
  AppIcons._();

  // Навигация и хром
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData moreVert = Icons.more_vert_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData refresh = Icons.refresh_rounded;

  // Действия
  static const IconData add = Icons.add_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData logout = Icons.logout_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData reply = Icons.reply_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData deleteForever = Icons.delete_forever_outlined;

  // Сущности
  static const IconData person = Icons.person_outline_rounded;
  static const IconData group = Icons.group_outlined;
  static const IconData chat = Icons.chat_bubble_outline_rounded;
  static const IconData personAdd = Icons.person_add_alt_1_rounded;
  static const IconData personRemove = Icons.person_remove_outlined;

  // Медиа
  static const IconData photo = Icons.photo_outlined;
  static const IconData photoCamera = Icons.photo_camera_outlined;
  static const IconData photoLibrary = Icons.photo_library_outlined;
  static const IconData videoLibrary = Icons.video_library_outlined;
  static const IconData videocam = Icons.videocam_outlined;
  static const IconData videocamOff = Icons.videocam_off_outlined;
  static const IconData call = Icons.call_rounded;
  static const IconData callEnd = Icons.call_end_rounded;
  static const IconData mic = Icons.mic_rounded;
  static const IconData micOff = Icons.mic_off_rounded;
  static const IconData permMedia = Icons.perm_media_outlined;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData record = Icons.fiber_manual_record;

  // Формы / вход
  static const IconData email = Icons.alternate_email_rounded;
  static const IconData mail = Icons.mail_outline_rounded;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData lockReset = Icons.lock_reset_rounded;
  static const IconData visibilityOn = Icons.visibility_outlined;
  static const IconData visibilityOff = Icons.visibility_off_outlined;
  static const IconData verified = Icons.mark_email_read_outlined;

  // Статусы и выбор
  static const IconData done = Icons.done_rounded;
  static const IconData doneAll = Icons.done_all_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData radioOff = Icons.radio_button_unchecked_rounded;
}
