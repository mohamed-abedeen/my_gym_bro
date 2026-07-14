// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'My Gym Bro';

  @override
  String get tabHome => 'Home';

  @override
  String get tabWorkout => 'Workout';

  @override
  String get tabLog => 'Log';

  @override
  String get tabCommunity => 'Community';

  @override
  String get status => 'Status';

  @override
  String get dailyChallenge => 'Daily Challenge';

  @override
  String get competeFriends => 'Compete with your Gym Bros';

  @override
  String get startTrial => 'Start 7-day free trial';

  @override
  String get createSchedule => 'Create Schedule';

  @override
  String get buildYourFlow => 'Build your flow or find a pro program';

  @override
  String scheduleRemaining(int hours) {
    return '${hours}h remaining';
  }

  @override
  String get nextSession => 'Next Session';

  @override
  String get sessionLog => 'Sessions';

  @override
  String get statusLog => 'Status';

  @override
  String get weeklyProgress => 'Weekly Progress';

  @override
  String get recovered => 'Recovered';

  @override
  String get recovering => 'Recovering';

  @override
  String get undertrained => 'Undertrained';

  @override
  String get healingTitle => 'Healing...';

  @override
  String get healingSubtitle => 'Your body needs some rest';

  @override
  String get sets => 'Sets';

  @override
  String get reps => 'Reps';

  @override
  String get weight => 'Weight';

  @override
  String get startWorkout => 'Start Workout';

  @override
  String get finishWorkout => 'Finish Workout';

  @override
  String get restDay => 'Rest Day';

  @override
  String get calBurned => 'Cal Burned';

  @override
  String get calBurnedLastWeek => 'Cal Burned last week';

  @override
  String get calBurnedThisWeek => 'Cal Burned this week';

  @override
  String get weeklyReports => 'Weekly Reports';

  @override
  String get reports => 'Reports';

  @override
  String get week => 'Week';

  @override
  String get weights => 'Weights';

  @override
  String get calUnit => 'Cal';

  @override
  String get minUnit => 'Min';

  @override
  String get exercisePrefix => 'Exe';

  @override
  String get reportNoData => 'No workout on this day';

  @override
  String statusKcalProgress(int burned, int goal) {
    return '$burned/$goal KCAL';
  }

  @override
  String statusKcalNoGoal(int burned) {
    return '$burned KCAL';
  }

  @override
  String get shoulders => 'Shoulders';

  @override
  String get chest => 'Chest';

  @override
  String get core => 'Core';

  @override
  String get target => 'Target';

  @override
  String get achieved => 'Achieved';

  @override
  String statusLiftedTotal(String amount) {
    return 'You\'ve lifted $amount since day one!';
  }

  @override
  String statusVolumeIncrease(int pct) {
    return 'Your lifted weight increased by $pct% since day one!';
  }

  @override
  String statusRepsTotal(String reps) {
    return 'You\'ve done $reps reps since day one!';
  }

  @override
  String statusCaloriesBurnedTotal(String kcal) {
    return 'You\'ve burned over $kcal calories!';
  }

  @override
  String statusCaloriesBodyFat(String kcal, String pct) {
    return 'You\'ve burned over $kcal calories and dropped $pct% body fat!';
  }

  @override
  String get calorieGoal => 'Calorie Goal';

  @override
  String get bodyFat => 'Body Fat';

  @override
  String get totalDuration => 'Total Duration';

  @override
  String get avgStrength => 'Avg Strength';

  @override
  String get records => 'Records';

  @override
  String get volume => 'Volume';

  @override
  String get totalVolume => 'Total Volume';

  @override
  String get totalTime => 'Total Time';

  @override
  String get howTo => 'How to';

  @override
  String get targetMuscles => 'Target Muscles';

  @override
  String get secondaryMuscles => 'Secondary Muscles';

  @override
  String get equipment => 'Equipment';

  @override
  String get instructions => 'Instructions';

  @override
  String get searchExercises => 'Search exercises...';

  @override
  String get noRecordsYet => 'No records yet';

  @override
  String get yourRecords => 'Your Records';

  @override
  String bestSet(double weight, int reps) {
    return 'Best: ${weight}kg × $reps reps';
  }

  @override
  String get addSet => 'Add set';

  @override
  String get addExercise => 'Add Exercise';

  @override
  String get editExercises => 'Edit Exercises';

  @override
  String get addDay => 'Add Days';

  @override
  String get scheduleName => 'Schedule Name';

  @override
  String get todaySession => 'Today\'s Session';

  @override
  String get lastWeek => 'Last Week';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get cancelAnytime => 'Cancel anytime. No charge during 7-day trial.';

  @override
  String get restoreSubscription => 'Restore purchases';

  @override
  String get monthlyPlan => 'Monthly';

  @override
  String get yearlyPlan => 'Yearly';

  @override
  String get bestValue => 'Best Value';

  @override
  String get trialBadge => '7-day free trial';

  @override
  String get subscribeToContinue => 'Subscribe to continue';

  @override
  String get autoRenewDisclosure =>
      'Subscription auto-renews at the price and period shown unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store or Google Play account settings.';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get purchaseFailed => 'Purchase failed. Please try again.';

  @override
  String get restoreFailed => 'Could not restore purchases. Please try again.';

  @override
  String get noOfferingsAvailable => 'No offerings available. Try again later.';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Create Account';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get nameLabel => 'Your name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get alreadyAccount => 'I already have an account';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseGoal => 'What\'s your goal?';

  @override
  String get buildMuscle => 'Build Muscle';

  @override
  String get loseWeight => 'Lose Weight';

  @override
  String get getStronger => 'Get Stronger';

  @override
  String get chooseExperience => 'Your experience level?';

  @override
  String get beginner => 'Beginner';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get advanced => 'Advanced';

  @override
  String get letsGo => 'Let\'s Go';

  @override
  String get trialStarted => 'Your 7-day free trial starts now';

  @override
  String get securityWarningTitle => 'Security Warning';

  @override
  String get securityWarningBody =>
      'This device appears compromised. My Gym Bro cannot run securely.';

  @override
  String get closeApp => 'Close App';

  @override
  String get biometricPrompt => 'Unlock My Gym Bro';

  @override
  String get language => 'Language';

  @override
  String get weightUnit => 'Weight Unit';

  @override
  String get bodyWeight => 'Body Weight';

  @override
  String get notSet => 'Not set';

  @override
  String get biometricLock => 'Biometric Lock';

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get exportData => 'Export My Data';

  @override
  String get clearCache => 'Clear Community Cache';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'This will permanently delete all your data. This cannot be undone.';

  @override
  String get deleteAccountButton => 'Delete My Account';

  @override
  String lastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String get syncNow => 'Sync Now';

  @override
  String get rateApp => 'Rate the App';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get synced => 'Synced';

  @override
  String get syncError => 'Sync error';

  @override
  String get loadingExercises => 'Loading exercise library...';

  @override
  String get whatOnYourMind => 'What\'s on your mind?';

  @override
  String get communityEmpty => 'No posts yet. Be the first to share!';

  @override
  String get communityError => 'Couldn\'t load the feed. Pull down to retry.';

  @override
  String get postFailed => 'Couldn\'t publish your post. Try again.';

  @override
  String get post => 'Post';

  @override
  String get skip => 'Skip';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get back => 'Back';

  @override
  String get share => 'Share';

  @override
  String get schedule => 'Schedule';

  @override
  String get noScheduleYet => 'No schedule yet';

  @override
  String activeSubscription(String date) {
    return 'Active — renews $date';
  }

  @override
  String trialDaysLeft(int days) {
    return '$days days left';
  }

  @override
  String get subscriptionExpired => 'Subscription expired';

  @override
  String get restComplete => 'Rest complete!';

  @override
  String get restCompleteTitleSupportive => 'Rest complete';

  @override
  String get restCompleteBodySupportive =>
      'Your muscles are ready whenever you are.';

  @override
  String get restCompleteTitleBalanced => 'Rest complete';

  @override
  String get restCompleteBodyBalanced => 'Time to start your next set.';

  @override
  String get restCompleteTitleBold => 'Rest complete';

  @override
  String get restCompleteBodyBold => 'Get back in. Next set.';

  @override
  String get restCompleteTitleSavage => 'REST OVER';

  @override
  String get restCompleteBodySavage => 'NEXT SET. NOW.';

  @override
  String get notificationTone => 'Notification tone';

  @override
  String get notificationToneSubtitle => 'Pick how your reminders sound';

  @override
  String get toneSupportive => 'Supportive';

  @override
  String get toneSupportiveDescription =>
      'Gentle, permission-giving reminders.';

  @override
  String get toneBalanced => 'Balanced';

  @override
  String get toneBalancedDescription => 'Neutral, factual reminders.';

  @override
  String get toneBold => 'Bold';

  @override
  String get toneBoldDescription => 'Direct, confident reminders.';

  @override
  String get toneSavage => 'Savage';

  @override
  String get toneSavageDescription => 'All caps, no-excuses reminders.';

  @override
  String get notificationToneOnboardingTitle => 'Pick your voice';

  @override
  String get notificationToneOnboardingSubtitle =>
      'How should we talk to you during workouts?';

  @override
  String get notificationToneExampleLabel => 'Example';

  @override
  String get restTimer => 'Rest Timer';

  @override
  String get off => 'Off';

  @override
  String get reorderExercises => 'Reorder Exercises';

  @override
  String get replaceExercise => 'Replace Exercise';

  @override
  String get defaultRestTime => 'Default rest time';

  @override
  String get restTimerSound => 'Rest timer sound';

  @override
  String get trainingReminders => 'Training reminders';

  @override
  String get communityNotifications => 'Community challenges';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get skipRest => 'Skip';

  @override
  String addSeconds(int n) {
    return '+${n}s';
  }

  @override
  String subtractSeconds(int n) {
    return '-${n}s';
  }

  @override
  String get settings => 'Settings';

  @override
  String get bodyStatus => 'Body Status';

  @override
  String get workoutStatus => 'Workout Status';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get weeklyStreak => 'Weekly Streak';

  @override
  String get leaderboardEmpty =>
      'No rankings yet. Finish a workout to enter this week\'s board.';

  @override
  String setsThisWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets this week',
      one: '1 set this week',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Train smarter. Get stronger.';

  @override
  String get continueButton => 'Continue';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthMedium => 'Medium';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get emailInvalid => 'Please enter a valid email';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get passwordRequirements =>
      'Min 8 chars, 1 uppercase, 1 number, 1 special';

  @override
  String get trialFeature1 => 'Unlimited workout tracking';

  @override
  String get trialFeature2 => '1300+ exercise library';

  @override
  String get trialFeature3 => 'Custom training schedules';

  @override
  String get trialFeature4 => 'Progress analytics & records';

  @override
  String get resetPasswordSent => 'Password reset email sent';

  @override
  String get orDivider => 'or';

  @override
  String get signUpError => 'Could not create account. Please try again.';

  @override
  String get signInError => 'Invalid email or password.';

  @override
  String get goalTitle => 'What\'s your main goal\nfor training ?';

  @override
  String get bulking => 'Bulking';

  @override
  String get bulkingDesc => 'Focus on building muscle mass and size.';

  @override
  String get strength => 'Strength';

  @override
  String get strengthDesc => 'To lift heavier load and get stronger.';

  @override
  String get cutting => 'Cutting';

  @override
  String get cuttingDesc => 'Reduce body fat while keeping muscle.';

  @override
  String get maintaining => 'Maintaining';

  @override
  String get maintainingDesc => 'Keep your current muscle and fitness.';

  @override
  String get dataPrivate => 'Your data is private and secure.';

  @override
  String get experienceTitle => 'How much training\nexperience do you have ?';

  @override
  String get base => 'Base';

  @override
  String get baseYears => '0-1 years';

  @override
  String get mid => 'Mid';

  @override
  String get midYears => '1-3 years';

  @override
  String get pro => 'Pro';

  @override
  String get proYears => '3+ years';

  @override
  String get selectGender => 'Select Your Gender';

  @override
  String get genderSubtitle => 'This helps us personalize your\ntraining plan.';

  @override
  String get birthdayTitle => 'What\'s your birthday?';

  @override
  String get weightTitle => 'What is your weight?';

  @override
  String get heightTitle => 'What is your height?';

  @override
  String get targetZonesTitle => 'What are your target\nzones?';

  @override
  String get arms => 'Arms';

  @override
  String get abs => 'Abs';

  @override
  String get pecs => 'Pecs';

  @override
  String get targetBack => 'Back';

  @override
  String get legs => 'Legs';

  @override
  String get all => 'All';

  @override
  String get kgs => 'kgs';

  @override
  String get lbs => 'lbs';

  @override
  String get cm => 'cm';

  @override
  String get ft => 'ft';

  @override
  String get freeTrial => 'Free Trial';

  @override
  String get yearly => 'Yearly';

  @override
  String get monthly => 'Monthly';

  @override
  String get dmMessages => 'Messages';

  @override
  String get dmSearch => 'Search';

  @override
  String get dmNoMessagesYet => 'No messages yet';

  @override
  String get dmStartChatting => 'Start chatting with your Gym Bros!';

  @override
  String get dmNewConversationUnavailable =>
      'New conversation not supported in v1';

  @override
  String dmStartConversation(String name) {
    return 'Start your conversation\nwith $name';
  }

  @override
  String get dmMessageHint => 'Message...';

  @override
  String get dmSendFailed => 'Message failed to send. Please try again.';

  @override
  String get dmSavedToSchedules => 'Saved to your schedules!';

  @override
  String get dmCamera => 'Camera';

  @override
  String get dmGallery => 'Gallery';

  @override
  String get dmSchedule => 'Schedule';

  @override
  String get dmShareSchedule => 'Share Schedule';

  @override
  String get dmNoSchedulesToShare => 'No schedules to share';

  @override
  String get dmSharedSchedule => 'Shared Schedule';

  @override
  String get dmInvalidSchedule => 'Invalid schedule data';

  @override
  String get dmSaveToMySchedules => 'Save to my schedules';

  @override
  String get dmUploading => 'Uploading...';

  @override
  String get dmSentMessage => 'Sent a message';

  @override
  String get dmImageTooLarge => 'Image exceeds 10 MB limit.';

  @override
  String dmDaysCount(int count) {
    return '$count days';
  }

  @override
  String get dmWorkout => 'Workout';

  @override
  String get addDayTitle => 'Add Day';

  @override
  String get oneStepCloserBro => 'One step closer bro';

  @override
  String get newProgram => 'New Program';

  @override
  String nextSessionAfter(int hours) {
    return 'Next session after ${hours}h';
  }

  @override
  String get readyToTrain => 'Ready to train, Bro!';

  @override
  String get restDaysBetween => 'Rest Days Between';

  @override
  String get rest => 'Rest';

  @override
  String get filterMuscle => 'Muscle';

  @override
  String get filterEquipment => 'Equipment';

  @override
  String get filterDifficulty => 'Difficulty';

  @override
  String readyInHoursMuscle(int hours, String muscle) {
    return 'Ready in ${hours}h ($muscle recovering)';
  }

  @override
  String get noExercisesFound =>
      'No exercises found for this combination, Bro!';

  @override
  String get exercisesOfflineCached =>
      'Offline — showing your saved exercises.';

  @override
  String get allMuscles => 'All Muscles';

  @override
  String get allEquipment => 'All Equipment';

  @override
  String get allDifficulties => 'All Levels';

  @override
  String get exerciseSearchHint => 'What are you looking for ?';

  @override
  String get account => 'Account';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String get follow => 'Follow';

  @override
  String get friends => 'Friends';

  @override
  String get streak => 'Streak';

  @override
  String get widgetStreakStart => 'Start a streak';

  @override
  String get widgetStreakOneDay => '1-day streak';

  @override
  String widgetStreakDays(int days) {
    return '$days-day streak';
  }

  @override
  String get posts => 'Posts';

  @override
  String get lastSession => 'Last Session';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get retry => 'Retry';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get muscleRecovery => 'Muscle Recovery';

  @override
  String get sore => 'Sore';

  @override
  String get tapMuscleToFocus => 'Tap a muscle below to focus it on the body';

  @override
  String get readyNow => 'Ready now';

  @override
  String get notTrainedYet => 'Not trained yet';

  @override
  String get fullyRecovered => 'Fully recovered — ready to train';

  @override
  String get lessThanOneHourRecovery => 'Less than 1 hour to full recovery';

  @override
  String hoursRestNeeded(int hours) {
    return '${hours}h more rest needed';
  }

  @override
  String daysRestNeeded(int days) {
    return '${days}d more rest needed';
  }

  @override
  String daysHoursRestNeeded(int days, int hours) {
    return '${days}d ${hours}h more rest needed';
  }

  @override
  String nSelected(int count) {
    return '$count selected';
  }

  @override
  String get clearFilters => 'Clear Filters';

  @override
  String get failedToLoadExercises => 'Failed to load exercises';

  @override
  String get tabSummary => 'Summary';

  @override
  String get tabHistory => 'History';

  @override
  String get heaviestWeight => 'Heaviest Weight';

  @override
  String get oneRepMax => 'One Rep Max';

  @override
  String get bestSetVolumeLabel => 'Best Set Volume';

  @override
  String get bestSessionVolumeLabel => 'Best Session Volume';

  @override
  String get setRecords => 'Set Records';

  @override
  String get last3Months => 'Last 3 Months';

  @override
  String get last6Months => 'Last 6 Months';

  @override
  String get allTime => 'All Time';

  @override
  String get noHistoryYet => 'No history yet';

  @override
  String get primaryLabel => 'Primary';

  @override
  String get secondaryLabel => 'Secondary';

  @override
  String get removeExercise => 'Remove exercise';

  @override
  String get discardWorkout => 'Discard this workout?';

  @override
  String get deleteSet => 'Delete Set';

  @override
  String get deleteSetConfirm => 'Delete this set?';

  @override
  String get setLabel => 'Set';

  @override
  String get selectSetType => 'Select Set Type';

  @override
  String get warmUpSet => 'Warm Up Set';

  @override
  String get normalSet => 'Normal Set';

  @override
  String get failureSet => 'Failure Set';

  @override
  String get dropSet => 'Drop Set';

  @override
  String get removeSet => 'Remove Set';

  @override
  String get superSet => 'Super Set';

  @override
  String get pressToDelete => 'Press To Delete';

  @override
  String get time => 'Time';

  @override
  String get finish => 'Finish';

  @override
  String get discard => 'Discard';

  @override
  String get discardWorkoutConfirm =>
      'Discard this workout? All progress will be lost.';

  @override
  String get finishWorkoutConfirm =>
      'Finish this workout? It\'ll be saved to your history.';

  @override
  String get completeSet => 'Complete set';

  @override
  String get restTime => 'Rest time';

  @override
  String get remaining => 'Remaining';

  @override
  String get restAfterSet => 'You must rest after\nthis set';

  @override
  String get unfinishedSets => 'Unfinished Sets';

  @override
  String get unfinishedSetsMessage =>
      'You have unfinished sets. Are you sure you want to end this session?';

  @override
  String get confirm => 'Confirm';

  @override
  String get endSession => 'End Session';

  @override
  String get previousExercise => 'Previous';

  @override
  String get nextExercise => 'Next';

  @override
  String get noInstructions => 'No instructions available';

  @override
  String get deleteWorkout => 'Delete Workout';

  @override
  String get deleteWorkoutConfirm => 'Delete this workout?';

  @override
  String get leaderboardTab => 'Leaderboard';

  @override
  String get challengesTab => 'Challenges';

  @override
  String get currentLeague => 'CURRENT LEAGUE';

  @override
  String get yourPlace => 'Your place';

  @override
  String placeNumber(int n) {
    return '$n Place';
  }

  @override
  String get leagueElite => 'The Elite';

  @override
  String get leagueMaster => 'The Master';

  @override
  String get leagueStanding => 'Standing';

  @override
  String get leagueMovingUp => 'Moving up';

  @override
  String get leagueWorkHarder => 'Work harder';

  @override
  String get scopeRivals => 'Rivals';

  @override
  String get scopeGlobal => 'Global';

  @override
  String get scopeFriends => 'Friends';

  @override
  String get volumeLabel => 'Volume';

  @override
  String get leagueMasterTitle => 'Master';

  @override
  String get rankBronze => 'Grinder';

  @override
  String get rankSilver => 'Warrior';

  @override
  String get rankGold => 'Beast';

  @override
  String get rankPlatinum => 'Titan';

  @override
  String get rankElite => 'Apex';

  @override
  String get rankUnranked => 'Unranked';

  @override
  String get rankUpTitle => 'RANK UP!';

  @override
  String get rankUpCta => 'Let\'s go!';

  @override
  String get newPrTitle => 'NEW PR!';

  @override
  String rankNext(String rank) {
    return 'Next: $rank';
  }

  @override
  String get rankMax => 'Max rank reached';

  @override
  String get rankShieldTooltip =>
      'Demotion shield — your rank is protected while you climb back.';

  @override
  String get skinPremium => 'Premium';

  @override
  String get skinPremiumSoon => 'Premium skin — purchases coming soon';

  @override
  String skinWorkoutsShort(int count) {
    return '$count workouts';
  }

  @override
  String skinLockedProgress(int count) {
    return 'Unlocks at $count workouts';
  }

  @override
  String get noChallengesYet => 'No active challenges yet';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionWorkout => 'Workout';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionData => 'Data & Account';

  @override
  String get skins => 'Skins';

  @override
  String get anatomyModel => 'Anatomy Model';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get restTimerVibration => 'Rest timer vibration';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirm =>
      'Sign out of your account? Your local data stays on this device.';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get cacheClearFailed => 'Failed to clear cache';

  @override
  String get couldNotOpenLink => 'Could not open link';

  @override
  String get exportPreparing => 'Preparing your export…';

  @override
  String get exportNothingYet => 'Nothing to export yet — log a workout first';

  @override
  String get exportFailed => 'Export failed. Please try again.';

  @override
  String get deleteAccountFailed =>
      'Could not delete account. Please try again.';

  @override
  String get planPremium => 'Premium';

  @override
  String get trainingReminderBody => 'Keep your streak going. Let\'s train.';

  @override
  String get languageSystem => 'System';

  @override
  String get settingsWorkoutFooter =>
      'Defaults for rest timers, logging, and calorie estimates.';

  @override
  String get settingsNotificationsFooter =>
      'Training reminders help protect your streak.';

  @override
  String get settingsDataFooter =>
      'Deleting your account permanently removes your data from our servers.';

  @override
  String get duration => 'Duration';

  @override
  String get heatmapLess => 'Less';

  @override
  String get heatmapMore => 'More';

  @override
  String get tapDayToJump => 'Tap a day to jump to its session';

  @override
  String jumpedToDay(String date) {
    return 'Jumped to $date';
  }

  @override
  String get shareNiceWork => 'Nice work.';

  @override
  String get shareStyleDark => 'Dark';

  @override
  String get shareStyleSticker => 'Sticker';

  @override
  String get shareTemplateEditorial => 'Editorial';

  @override
  String get shareTemplateAnatomy => 'Anatomy';

  @override
  String get shareTemplateHype => 'Hype';

  @override
  String shareWorkoutNumber(int count) {
    return 'Workout #$count';
  }

  @override
  String get shareTotalVolumeLifted => 'Total volume lifted';

  @override
  String get shareOneSession => 'One session';

  @override
  String get shareYou => 'You';

  @override
  String shareHeavierThan(String object) {
    return 'Heavier than $object.';
  }

  @override
  String get shareAnonymous => 'Anonymous';

  @override
  String get shareError => 'Couldn\'t create the image. Try again.';

  @override
  String get shareSaved => 'Saved to gallery';

  @override
  String get shareSaveError => 'Couldn\'t save to gallery';

  @override
  String get shareVolumeCaption => 'That\'s some serious iron.';

  @override
  String get shareVolumeDog => 'a big friendly dog';

  @override
  String get shareVolumeFridge => 'a full-size fridge';

  @override
  String get shareVolumePiano => 'a grand piano';

  @override
  String get shareVolumeCar => 'a small car';

  @override
  String get shareVolumeVan => 'a delivery van';

  @override
  String get shareVolumeElephant => 'a full-grown elephant';

  @override
  String get shareObjectDog => 'Dog';

  @override
  String get shareObjectFridge => 'Fridge';

  @override
  String get shareObjectPiano => 'Piano';

  @override
  String get shareObjectCar => 'Car';

  @override
  String get shareObjectVan => 'Van';

  @override
  String get shareObjectElephant => 'Elephant';

  @override
  String get close => 'Close';

  @override
  String get hint => 'Hint';

  @override
  String get moreOptions => 'More options';

  @override
  String get markSetComplete => 'Mark set complete';

  @override
  String get markSetIncomplete => 'Mark set incomplete';

  @override
  String restTimerRemaining(String time) {
    return 'Rest timer, $time remaining';
  }

  @override
  String get plateCalculator => 'Plate calculator';

  @override
  String get plateCalcTargetWeight => 'Target weight';

  @override
  String get plateCalcBar => 'Bar';

  @override
  String get plateCalcPerSide => 'per side';

  @override
  String plateCalcUnreachable(String amount) {
    return 'Unreachable by $amount';
  }

  @override
  String get getStarted => 'Get Started';

  @override
  String get welcomeTagline => 'Built by Gym Bros, For Gym Bros';

  @override
  String get noData => 'No data';

  @override
  String get progressLabel => 'PROGRESS';

  @override
  String get weightsKg => 'weights kg';

  @override
  String get day => 'Day';

  @override
  String dayNumber(int number) {
    return 'Day $number';
  }

  @override
  String get label => 'Label';

  @override
  String get dayLabel => 'Day Label';

  @override
  String get dayLabelHint => 'e.g. Chest Day';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get deleteSchedule => 'Delete Schedule';

  @override
  String get deleteScheduleConfirm =>
      'Are you sure you want to delete this schedule? This cannot be undone.';

  @override
  String get defaultProgramName => 'Program 1';

  @override
  String get recentExercises => 'Recent Exercises';

  @override
  String get allExercises => 'All Exercises';

  @override
  String allCategory(String category) {
    return 'All $category';
  }

  @override
  String get other => 'Other';

  @override
  String get equipmentNone => 'None';

  @override
  String get barbell => 'Barbell';

  @override
  String get dumbbell => 'Dumbbell';

  @override
  String get kettlebell => 'Kettlebell';

  @override
  String get machine => 'Machine';

  @override
  String get resistanceBand => 'Resistance Band';

  @override
  String get cardio => 'Cardio';

  @override
  String setsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }
}
