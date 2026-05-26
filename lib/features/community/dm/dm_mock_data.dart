// TEMPORARY: Mock DM data for UI development.
// Flip kUseMockDm = false in dm_inbox_screen.dart + dm_chat_screen.dart before shipping.

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/community/dm/dm_models.dart';

const _conv = 'mock-conv-1';
const _me = 'mock-user-me';
const _them = 'mock-user-them';

// ── Mock conversations (inbox list) ────────────────────────────────────────

final mockDmConversations = <DmConversation>[
  DmConversation(
    id: _conv,
    otherUserId: _them,
    otherUserName: 'Alex Carter',
    lastMessageText: 'Also check my latest post in the community tab 📸',
    lastMessageAt: DateTime.now(),
    unreadCount: 0,
  ),
  DmConversation(
    id: 'mock-conv-2',
    otherUserId: 'mock-user-2',
    otherUserName: 'Jordan Lee',
    lastMessageText: 'Bro your bench press form tip worked 🙌',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
    unreadCount: 3,
  ),
  DmConversation(
    id: 'mock-conv-3',
    otherUserId: 'mock-user-3',
    otherUserName: 'Sam Rivera',
    lastMessageText: 'What protein powder do you use?',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    unreadCount: 0,
  ),
  DmConversation(
    id: 'mock-conv-4',
    otherUserId: 'mock-user-4',
    otherUserName: 'Morgan Wu',
    lastMessageText: 'See you at the gym tomorrow 💪',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 3)),
    unreadCount: 1,
  ),
];

// Two schedules — one sent, one received — to test both bubble variants.
final _sentScheduleJson = SharedSchedule(
  name: 'Push / Pull / Legs',
  days: [
    SharedScheduleDay(dayIndex: 0, label: 'Push — Chest & Tris', isRestDay: false),
    SharedScheduleDay(dayIndex: 1, label: 'Pull — Back & Bis',   isRestDay: false),
    SharedScheduleDay(dayIndex: 2, label: 'Legs & Glutes',        isRestDay: false),
    SharedScheduleDay(dayIndex: 3,                                 isRestDay: true),
    SharedScheduleDay(dayIndex: 4, label: 'Push — Chest & Tris', isRestDay: false),
    SharedScheduleDay(dayIndex: 5, label: 'Pull — Back & Bis',   isRestDay: false),
    SharedScheduleDay(dayIndex: 6,                                 isRestDay: true),
  ],
).toJsonString();

final _receivedScheduleJson = SharedSchedule(
  name: 'Upper / Lower Split',
  days: [
    SharedScheduleDay(dayIndex: 0, label: 'Upper Body', isRestDay: false),
    SharedScheduleDay(dayIndex: 1, label: 'Lower Body', isRestDay: false),
    SharedScheduleDay(dayIndex: 2,                       isRestDay: true),
    SharedScheduleDay(dayIndex: 3, label: 'Upper Body', isRestDay: false),
    SharedScheduleDay(dayIndex: 4, label: 'Lower Body', isRestDay: false),
    SharedScheduleDay(dayIndex: 5,                       isRestDay: true),
    SharedScheduleDay(dayIndex: 6,                       isRestDay: true),
  ],
).toJsonString();

/// Sorted oldest → newest (matches DAO order). The ListView renders reverse=true
/// so index 0 shows at the bottom.
///
/// Timestamp spread intentionally triggers every divider format:
///   "DD Mon HH:MM"  — messages older than yesterday
///   "Yesterday HH:MM" — yesterday's messages
///   "Today HH:MM"   — messages from today with >5 min gap
final mockDmMessages = <DmMessage>[
  // ── 4 days ago — tests "DD Mon" divider ────────────────────────────────────
  DmMessage(
    id: 'mock-01',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: 'Bro are you going to the gym today?',
    createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
    isMine: false,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-02',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'Yeah, evening session. Chest day 🏋️',
    createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 1, minutes: 55)),
    isMine: true,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-03',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: '👍',
    createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 1, minutes: 50)),
    isMine: false,
    isOptimistic: false,
  ),

  // ── Yesterday — tests "Yesterday" divider ──────────────────────────────────
  DmMessage(
    id: 'mock-04',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: 'Hey! Are you still doing that PPL split?',
    createdAt: DateTime.now().subtract(const Duration(hours: 26)),
    isMine: false,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-05',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'Yeah, 6 days a week. Loving the frequency — strength is up across the board.',
    createdAt: DateTime.now().subtract(const Duration(hours: 25, minutes: 58)),
    isMine: true,
    isOptimistic: false,
  ),
  // Sent schedule — tests isMine=true schedule bubble (no "Save" button shown)
  DmMessage(
    id: 'mock-06',
    conversationId: _conv,
    senderId: _me,
    type: 'schedule',
    body: _sentScheduleJson,
    createdAt: DateTime.now().subtract(const Duration(hours: 25, minutes: 50)),
    isMine: true,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-07',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: 'This looks exactly like what I needed, thanks!',
    createdAt: DateTime.now().subtract(const Duration(hours: 25, minutes: 40)),
    isMine: false,
    isOptimistic: false,
  ),
  // Received schedule — tests isMine=false schedule bubble ("Save to My Schedules" button visible)
  DmMessage(
    id: 'mock-08',
    conversationId: _conv,
    senderId: _them,
    type: 'schedule',
    body: _receivedScheduleJson,
    createdAt: DateTime.now().subtract(const Duration(hours: 25, minutes: 30)),
    isMine: false,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-09',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'Nice, give it a shot. I ran this for 10 weeks and my squat went up 15 kg.',
    createdAt: DateTime.now().subtract(const Duration(hours: 25, minutes: 20)),
    isMine: true,
    isOptimistic: false,
  ),

  // ── Today — first cluster, >5 min from next → new "Today" divider ──────────
  DmMessage(
    id: 'mock-10',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: 'Quick question — do you track macros or just eat at a surplus?',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    isMine: false,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-11',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'I track protein strictly (~2 g/kg) and keep calories roughly 200 kcal over maintenance. Everything else is flexible.',
    createdAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 59)),
    isMine: true,
    isOptimistic: false,
  ),

  // ── Today — second cluster (>5 min gap triggers second "Today" divider) ────
  DmMessage(
    id: 'mock-12',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: 'Makes sense. Do you deload or just push through?',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    isMine: false,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-13',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'Deload every 6 weeks — drop volume ~40% but keep intensity the same. Way better than a full rest week.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 29)),
    isMine: true,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-14',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: '🔥🔥🔥',
    createdAt: DateTime.now().subtract(const Duration(minutes: 28)),
    isMine: false,
    isOptimistic: false,
  ),
  // Long received message — tests bubble max-width wrapping
  DmMessage(
    id: 'mock-15',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: "I've been stuck on the same weight for bench for like 2 months. Tried everything — more volume, less volume, more frequency. Nothing's clicking. Any idea what I might be missing? My form feels solid and sleep is fine.",
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    isMine: false,
    isOptimistic: false,
  ),
  // Long sent message — tests isMine=true wrapping
  DmMessage(
    id: 'mock-16',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: "Sounds like you might be undereating. Bench is super sensitive to caloric deficit. Try bumping food by 200 kcal for 2 weeks and see if the weight moves. Also, are you doing any accessory work — dips, cable flyes, close-grip press? Those made a huge difference for me when I plateaued last year.",
    createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
    isMine: true,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-17',
    conversationId: _conv,
    senderId: _them,
    type: 'text',
    body: 'No way, that simple?',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    isMine: false,
    isOptimistic: false,
  ),
  DmMessage(
    id: 'mock-18',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'Try it for 2 weeks and report back 👊',
    createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
    isMine: true,
    isOptimistic: false,
  ),

  // ── Very recent — optimistic (clock icon shown) ────────────────────────────
  DmMessage(
    id: 'mock-optimistic',
    conversationId: _conv,
    senderId: _me,
    type: 'text',
    body: 'Also check my latest post in the community tab 📸',
    createdAt: DateTime.now(),
    isMine: true,
    isOptimistic: true,
  ),
];

