// ─────────────────────────────────────────────────────────────────────────────
// OcIcons — Custom SVG icon registry
//
// Drop-in replacement workflow:
//   1. Replace any SVG file in assets/icons/ with your custom vector.
//   2. Keep the exact same filename.
//   3. Hot-restart the app — done.
//
// Usage:
//   OcIcon(OcIcons.like)
//   OcIcon(OcIcons.share, size: 20, color: Colors.red)
// ─────────────────────────────────────────────────────────────────────────────

abstract final class OcIcons {
  // ── Social / Community ──────────────────────────────────────────────────────
  static const String like = 'assets/icons/like.svg';
  static const String comment = 'assets/icons/comment.svg';
  static const String share = 'assets/icons/share.svg';
  static const String send = 'assets/icons/send.svg';
  static const String bookmark = 'assets/icons/bookmark.svg';

  // ── Actions ─────────────────────────────────────────────────────────────────
  static const String done = 'assets/icons/done.svg';
  static const String add = 'assets/icons/add.svg';
  static const String close = 'assets/icons/close.svg';
  static const String delete = 'assets/icons/delete.svg';
  static const String save = 'assets/icons/save.svg';
  static const String edit = 'assets/icons/edit.svg';
  static const String filter = 'assets/icons/filter.svg';
  static const String search = 'assets/icons/search.svg';

  // ── Navigation ──────────────────────────────────────────────────────────────
  static const String home = 'assets/icons/home.svg';
  static const String back = 'assets/icons/back.svg';
  static const String forward = 'assets/icons/forward.svg';
  static const String menu = 'assets/icons/menu.svg';

  // ── Fitness / App-specific ───────────────────────────────────────────────
  static const String fire = 'assets/icons/fire.svg';
  static const String timer = 'assets/icons/timer.svg';
  static const String calendar = 'assets/icons/calendar.svg';

  // ── Profile / Settings ──────────────────────────────────────────────────────
  static const String person = 'assets/icons/person.svg';
  static const String notification = 'assets/icons/notification.svg';
  static const String settings = 'assets/icons/settings.svg';
}
