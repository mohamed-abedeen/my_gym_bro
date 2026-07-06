// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'My Gym Bro';

  @override
  String get tabHome => 'Startseite';

  @override
  String get tabWorkout => 'Training';

  @override
  String get tabLog => 'Protokoll';

  @override
  String get tabCommunity => 'Community';

  @override
  String get status => 'Status';

  @override
  String get dailyChallenge => 'Tages-Challenge';

  @override
  String get competeFriends => 'Wetteifere mit deinen Freunden';

  @override
  String get startTrial => '7 Tage kostenlos testen';

  @override
  String get createSchedule => 'Plan erstellen';

  @override
  String get buildYourFlow =>
      'Erstelle deinen Plan oder finde ein Profi-Programm';

  @override
  String scheduleRemaining(int hours) {
    return 'Noch ${hours}h';
  }

  @override
  String get nextSession => 'Nächste Einheit';

  @override
  String get sessionLog => 'Einheiten';

  @override
  String get statusLog => 'Status';

  @override
  String get weeklyProgress => 'Wöchentlicher Fortschritt';

  @override
  String get recovered => 'Erholt';

  @override
  String get recovering => 'Erholt sich';

  @override
  String get undertrained => 'Untrainiert';

  @override
  String get healingTitle => 'Erholung...';

  @override
  String get healingSubtitle => 'Dein Körper braucht Ruhe';

  @override
  String get sets => 'Sätze';

  @override
  String get reps => 'Wdh.';

  @override
  String get weight => 'Gewicht';

  @override
  String get startWorkout => 'Training starten';

  @override
  String get finishWorkout => 'Training beenden';

  @override
  String get restDay => 'Ruhetag';

  @override
  String get calBurned => 'Kalorien verbrannt';

  @override
  String get calBurnedLastWeek => 'Kalorien letzte Woche';

  @override
  String get calBurnedThisWeek => 'Kalorien diese Woche';

  @override
  String get weeklyReports => 'Wochenberichte';

  @override
  String get reports => 'Berichte';

  @override
  String get week => 'Woche';

  @override
  String get weights => 'Gewichte';

  @override
  String get calUnit => 'kcal';

  @override
  String get minUnit => 'Min';

  @override
  String get exercisePrefix => 'Üb';

  @override
  String get reportNoData => 'Kein Training an diesem Tag';

  @override
  String statusKcalProgress(int burned, int goal) {
    return '$burned/$goal KCAL';
  }

  @override
  String statusKcalNoGoal(int burned) {
    return '$burned KCAL';
  }

  @override
  String get shoulders => 'Schultern';

  @override
  String get chest => 'Brust';

  @override
  String get core => 'Rumpf';

  @override
  String get target => 'Ziel';

  @override
  String get achieved => 'Erreicht';

  @override
  String statusLiftedTotal(String amount) {
    return 'Du hast seit Tag eins $amount gestemmt!';
  }

  @override
  String statusVolumeIncrease(int pct) {
    return 'Dein bewegtes Gewicht ist seit Tag eins um $pct% gestiegen!';
  }

  @override
  String statusRepsTotal(String reps) {
    return 'Du hast seit Tag eins $reps Wiederholungen gemacht!';
  }

  @override
  String statusCaloriesBurnedTotal(String kcal) {
    return 'Du hast über $kcal Kalorien verbrannt!';
  }

  @override
  String statusCaloriesBodyFat(String kcal, String pct) {
    return 'Du hast über $kcal Kalorien verbrannt und $pct% Körperfett verloren!';
  }

  @override
  String get calorieGoal => 'Kalorienziel';

  @override
  String get bodyFat => 'Körperfett';

  @override
  String get totalDuration => 'Gesamtdauer';

  @override
  String get avgStrength => 'Durchschn. Kraft';

  @override
  String get records => 'Rekorde';

  @override
  String get volume => 'Volumen';

  @override
  String get totalVolume => 'Gesamtvolumen';

  @override
  String get totalTime => 'Gesamtzeit';

  @override
  String get howTo => 'Anleitung';

  @override
  String get targetMuscles => 'Zielmuskeln';

  @override
  String get secondaryMuscles => 'Nebenmuskeln';

  @override
  String get equipment => 'Ausrüstung';

  @override
  String get instructions => 'Anweisungen';

  @override
  String get searchExercises => 'Übungen suchen...';

  @override
  String get noRecordsYet => 'Noch keine Rekorde';

  @override
  String get yourRecords => 'Deine Rekorde';

  @override
  String bestSet(double weight, int reps) {
    return 'Bestes: ${weight}kg × $reps Wdh.';
  }

  @override
  String get addSet => 'Satz hinzufügen';

  @override
  String get addExercise => 'Übung hinzufügen';

  @override
  String get addDay => 'Tag hinzufügen';

  @override
  String get scheduleName => 'Planname';

  @override
  String get todaySession => 'Heutige Einheit';

  @override
  String get lastWeek => 'Letzte Woche';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get yesterday => 'Gestern';

  @override
  String get cancelAnytime =>
      'Jederzeit kündbar. Keine Gebühren während der Testphase.';

  @override
  String get restoreSubscription => 'Käufe wiederherstellen';

  @override
  String get monthlyPlan => 'Monatlich';

  @override
  String get yearlyPlan => 'Jährlich';

  @override
  String get bestValue => 'Bestes Angebot';

  @override
  String get trialBadge => '7 Tage kostenlos';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signUp => 'Konto erstellen';

  @override
  String get continueWithApple => 'Mit Apple fortfahren';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get emailLabel => 'E-Mail';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get nameLabel => 'Dein Name';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get noAccount => 'Noch kein Konto?';

  @override
  String get alreadyAccount => 'Ich habe bereits ein Konto';

  @override
  String get chooseLanguage => 'Sprache wählen';

  @override
  String get chooseGoal => 'Was ist dein Ziel?';

  @override
  String get buildMuscle => 'Muskelaufbau';

  @override
  String get loseWeight => 'Abnehmen';

  @override
  String get getStronger => 'Stärker werden';

  @override
  String get chooseExperience => 'Dein Level?';

  @override
  String get beginner => 'Anfänger';

  @override
  String get intermediate => 'Fortgeschritten';

  @override
  String get advanced => 'Experte';

  @override
  String get letsGo => 'Los geht\'s';

  @override
  String get trialStarted => 'Deine kostenlose 7-Tage-Testphase beginnt jetzt';

  @override
  String get securityWarningTitle => 'Sicherheitswarnung';

  @override
  String get securityWarningBody =>
      'Dieses Gerät scheint kompromittiert. My Gym Bro kann nicht sicher ausgeführt werden.';

  @override
  String get closeApp => 'App schließen';

  @override
  String get biometricPrompt => 'My Gym Bro entsperren';

  @override
  String get language => 'Sprache';

  @override
  String get weightUnit => 'Gewichtseinheit';

  @override
  String get bodyWeight => 'Körpergewicht';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String get biometricLock => 'Biometrische Sperre';

  @override
  String get manageSubscription => 'Abo verwalten';

  @override
  String get exportData => 'Daten exportieren';

  @override
  String get clearCache => 'Community-Cache leeren';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountConfirm =>
      'Alle deine Daten werden dauerhaft gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get deleteAccountButton => 'Mein Konto löschen';

  @override
  String lastSynced(String time) {
    return 'Synchronisiert $time';
  }

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get rateApp => 'App bewerten';

  @override
  String get contactSupport => 'Support kontaktieren';

  @override
  String get privacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get termsOfService => 'Nutzungsbedingungen';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get pendingSync => 'Sync ausstehend';

  @override
  String get synced => 'Synchronisiert';

  @override
  String get syncError => 'Sync-Fehler';

  @override
  String get loadingExercises => 'Übungen werden geladen...';

  @override
  String get whatOnYourMind => 'Was gibt es Neues?';

  @override
  String get communityEmpty => 'Noch keine Beiträge. Sei der Erste!';

  @override
  String get communityError =>
      'Feed konnte nicht geladen werden. Versuch es erneut.';

  @override
  String get post => 'Posten';

  @override
  String get skip => 'Überspringen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get done => 'Fertig';

  @override
  String get back => 'Zurück';

  @override
  String get share => 'Teilen';

  @override
  String get schedule => 'Trainingsplan';

  @override
  String get noScheduleYet => 'Noch kein Plan';

  @override
  String activeSubscription(String date) {
    return 'Aktiv — verlängert am $date';
  }

  @override
  String trialDaysLeft(int days) {
    return 'Test — noch $days Tage';
  }

  @override
  String get subscriptionExpired => 'Abo abgelaufen';

  @override
  String get restComplete => 'Pause beendet!';

  @override
  String get restCompleteTitleSupportive => 'Pause beendet';

  @override
  String get restCompleteBodySupportive =>
      'Deine Muskeln sind bereit, wann immer du es bist.';

  @override
  String get restCompleteTitleBalanced => 'Pause beendet';

  @override
  String get restCompleteBodyBalanced => 'Zeit für den nächsten Satz.';

  @override
  String get restCompleteTitleBold => 'Pause beendet';

  @override
  String get restCompleteBodyBold => 'Zurück ans Eisen. Nächster Satz.';

  @override
  String get restCompleteTitleSavage => 'PAUSE VORBEI';

  @override
  String get restCompleteBodySavage => 'NÄCHSTER SATZ. JETZT.';

  @override
  String get notificationTone => 'Ton der Benachrichtigungen';

  @override
  String get notificationToneSubtitle => 'Wähle den Ton deiner Erinnerungen';

  @override
  String get toneSupportive => 'Unterstützend';

  @override
  String get toneSupportiveDescription => 'Sanfte, bestärkende Erinnerungen.';

  @override
  String get toneBalanced => 'Ausgewogen';

  @override
  String get toneBalancedDescription => 'Neutrale, sachliche Erinnerungen.';

  @override
  String get toneBold => 'Direkt';

  @override
  String get toneBoldDescription => 'Direkte, selbstbewusste Erinnerungen.';

  @override
  String get toneSavage => 'Knallhart';

  @override
  String get toneSavageDescription =>
      'Alles in Großbuchstaben, keine Ausreden.';

  @override
  String get notificationToneOnboardingTitle => 'Wähle deine Stimme';

  @override
  String get notificationToneOnboardingSubtitle =>
      'Wie sollen wir während des Trainings mit dir sprechen?';

  @override
  String get notificationToneExampleLabel => 'Beispiel';

  @override
  String get restTimer => 'Pause';

  @override
  String get defaultRestTime => 'Standard-Ruhezeit';

  @override
  String get restTimerSound => 'Ruhetimer-Ton';

  @override
  String get trainingReminders => 'Trainings-Erinnerungen';

  @override
  String get communityNotifications => 'Community-Challenges';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get notificationsSection => 'Benachrichtigungen';

  @override
  String get skipRest => 'Überspringen';

  @override
  String addSeconds(int n) {
    return '+${n}s';
  }

  @override
  String subtractSeconds(int n) {
    return '-${n}s';
  }

  @override
  String get settings => 'Einstellungen';

  @override
  String get bodyStatus => 'Körperstatus';

  @override
  String get workoutStatus => 'Trainingsstatus';

  @override
  String get lastMonth => 'Letzter Monat';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get thisMonth => 'Dieser Monat';

  @override
  String get weeklyStreak => 'Wochen-Serie';

  @override
  String get leaderboardEmpty =>
      'Noch keine Platzierungen. Schließe ein Workout ab, um in die Wochenwertung zu kommen.';

  @override
  String setsThisWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sätze diese Woche',
      one: '1 Satz diese Woche',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Trainiere schlauer. Werde stärker.';

  @override
  String get continueButton => 'Weiter';

  @override
  String get passwordStrengthWeak => 'Schwach';

  @override
  String get passwordStrengthMedium => 'Mittel';

  @override
  String get passwordStrengthStrong => 'Stark';

  @override
  String get emailInvalid => 'Bitte gib eine gültige E-Mail ein';

  @override
  String get nameRequired => 'Name ist erforderlich';

  @override
  String get passwordRequirements =>
      'Min. 8 Zeichen, 1 Großbuchstabe, 1 Zahl, 1 Sonderzeichen';

  @override
  String get trialFeature1 => 'Unbegrenztes Workout-Tracking';

  @override
  String get trialFeature2 => 'Übungsbibliothek mit 1300+ Übungen';

  @override
  String get trialFeature3 => 'Individuelle Trainingspläne';

  @override
  String get trialFeature4 => 'Fortschrittsanalyse & Rekorde';

  @override
  String get resetPasswordSent =>
      'E-Mail zum Zurücksetzen des Passworts gesendet';

  @override
  String get orDivider => 'oder';

  @override
  String get signUpError =>
      'Konto konnte nicht erstellt werden. Bitte versuche es erneut.';

  @override
  String get signInError => 'Ungültige E-Mail oder Passwort.';

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
  String get dmMessages => 'Nachrichten';

  @override
  String get dmSearch => 'Suchen';

  @override
  String get dmNoMessagesYet => 'Noch keine Nachrichten';

  @override
  String get dmStartChatting => 'Chatte mit deinen Gym Bros!';

  @override
  String get dmNewConversationUnavailable =>
      'Neue Konversation in v1 nicht verfügbar';

  @override
  String dmStartConversation(String name) {
    return 'Starte deine Unterhaltung\nmit $name';
  }

  @override
  String get dmMessageHint => 'Nachricht...';

  @override
  String get dmSendFailed =>
      'Nachricht konnte nicht gesendet werden. Bitte versuche es erneut.';

  @override
  String get dmSavedToSchedules => 'In deinen Plänen gespeichert!';

  @override
  String get dmCamera => 'Kamera';

  @override
  String get dmGallery => 'Galerie';

  @override
  String get dmSchedule => 'Trainingsplan';

  @override
  String get dmShareSchedule => 'Plan teilen';

  @override
  String get dmNoSchedulesToShare => 'Keine Pläne zum Teilen';

  @override
  String get dmSharedSchedule => 'Geteilter Plan';

  @override
  String get dmInvalidSchedule => 'Ungültige Plandaten';

  @override
  String get dmSaveToMySchedules => 'In meinen Plänen speichern';

  @override
  String get dmUploading => 'Wird hochgeladen...';

  @override
  String get dmSentMessage => 'Nachricht gesendet';

  @override
  String get dmImageTooLarge => 'Bild überschreitet 10 MB Limit.';

  @override
  String dmDaysCount(int count) {
    return '$count Tage';
  }

  @override
  String get dmWorkout => 'Training';

  @override
  String get addDayTitle => 'Tag hinzufügen';

  @override
  String get oneStepCloserBro => 'Einen Schritt näher, Bro';

  @override
  String get newProgram => 'Neues Programm';

  @override
  String nextSessionAfter(int hours) {
    return 'Nächste Einheit in ${hours}h';
  }

  @override
  String get readyToTrain => 'Bereit zu trainieren, Bro!';

  @override
  String get restDaysBetween => 'Ruhetage dazwischen';

  @override
  String get rest => 'Ruhe';

  @override
  String get filterMuscle => 'Muskel';

  @override
  String get filterEquipment => 'Gerät';

  @override
  String get filterDifficulty => 'Schwierigkeit';

  @override
  String readyInHoursMuscle(int hours, String muscle) {
    return 'Bereit in ${hours}h ($muscle erholt sich)';
  }

  @override
  String get noExercisesFound =>
      'Keine Übungen für diese Kombination gefunden, Bro!';

  @override
  String get exercisesOfflineCached =>
      'Offline – deine gespeicherten Übungen werden angezeigt.';

  @override
  String get allMuscles => 'Alle Muskeln';

  @override
  String get allEquipment => 'Alle Geräte';

  @override
  String get allDifficulties => 'Alle Level';

  @override
  String get exerciseSearchHint => 'What are you looking for ?';

  @override
  String get account => 'Account';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String get follow => 'Folgen';

  @override
  String get friends => 'Freunde';

  @override
  String get streak => 'Streak';

  @override
  String get widgetStreakStart => 'Streak starten';

  @override
  String get widgetStreakOneDay => '1-Tage-Streak';

  @override
  String widgetStreakDays(int days) {
    return '$days-Tage-Streak';
  }

  @override
  String get achievement => 'Achievement';

  @override
  String get posts => 'Posts';

  @override
  String get lastSession => 'Last Session';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get leaderboard => 'Rangliste';

  @override
  String get muscleRecovery => 'Muskelregeneration';

  @override
  String get sore => 'Schmerzhaft';

  @override
  String get notTrainedYet => 'Noch nicht trainiert';

  @override
  String get fullyRecovered => 'Vollständig erholt — bereit zu trainieren';

  @override
  String get lessThanOneHourRecovery => 'Weniger als 1 Stunde bis zur Erholung';

  @override
  String hoursRestNeeded(int hours) {
    return 'Noch ${hours}h Erholung nötig';
  }

  @override
  String daysRestNeeded(int days) {
    return 'Noch ${days}T Erholung nötig';
  }

  @override
  String daysHoursRestNeeded(int days, int hours) {
    return 'Noch ${days}T ${hours}h Erholung nötig';
  }

  @override
  String nSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String get clearFilters => 'Filter zurücksetzen';

  @override
  String get failedToLoadExercises => 'Übungen konnten nicht geladen werden';

  @override
  String get sortMostUsed => 'Am häufigsten';

  @override
  String get sortFavorites => 'Favoriten';

  @override
  String get sortAZ => 'A–Z';

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
  String get removeExercise => 'Übung entfernen';

  @override
  String get discardWorkout => 'Dieses Training verwerfen?';

  @override
  String get deleteSet => 'Satz löschen';

  @override
  String get deleteSetConfirm => 'Diesen Satz löschen?';

  @override
  String get setLabel => 'Satz';

  @override
  String get selectSetType => 'Satzart wählen';

  @override
  String get warmUpSet => 'Aufwärmsatz';

  @override
  String get normalSet => 'Normaler Satz';

  @override
  String get failureSet => 'Versagenssatz';

  @override
  String get dropSet => 'Dropsatz';

  @override
  String get removeSet => 'Satz entfernen';

  @override
  String get completeSet => 'Satz abschließen';

  @override
  String get restTime => 'Pausenzeit';

  @override
  String get remaining => 'Verbleibend';

  @override
  String get restAfterSet => 'Du musst nach\ndiesem Satz ruhen';

  @override
  String get unfinishedSets => 'Unvollendete Sätze';

  @override
  String get unfinishedSetsMessage =>
      'Du hast noch unvollendete Sätze. Möchtest du die Einheit wirklich beenden?';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get endSession => 'Einheit beenden';

  @override
  String get previousExercise => 'Zurück';

  @override
  String get nextExercise => 'Weiter';

  @override
  String get noInstructions => 'Keine Anleitung verfügbar';

  @override
  String get deleteWorkout => 'Training löschen';

  @override
  String get deleteWorkoutConfirm => 'Dieses Training löschen?';

  @override
  String get leaderboardTab => 'Rangliste';

  @override
  String get challengesTab => 'Challenges';

  @override
  String get currentLeague => 'AKTUELLE LIGA';

  @override
  String get yourPlace => 'Dein Platz';

  @override
  String placeNumber(int n) {
    return '$n Platz';
  }

  @override
  String get leagueElite => 'Die Elite';

  @override
  String get leagueMaster => 'Der Meister';

  @override
  String get leagueStanding => 'Stabil';

  @override
  String get leagueMovingUp => 'Im Aufstieg';

  @override
  String get leagueWorkHarder => 'Streng dich an';

  @override
  String get scopeRivals => 'Rivalen';

  @override
  String get scopeGlobal => 'Global';

  @override
  String get scopeFriends => 'Freunde';

  @override
  String get volumeLabel => 'Volumen';

  @override
  String percentDone(int percent) {
    return '$percent% erledigt';
  }

  @override
  String rankNumber(int rank) {
    return 'Rang #$rank';
  }

  @override
  String get startChallenge => 'starten';

  @override
  String endInDays(int days) {
    return 'Endet in ${days}T';
  }

  @override
  String get leagueMasterTitle => 'Meister';

  @override
  String get noChallengesYet => 'Keine aktiven Challenges';

  @override
  String get settingsSectionAppearance => 'Darstellung';

  @override
  String get settingsSectionWorkout => 'Training';

  @override
  String get settingsSectionGeneral => 'Allgemein';

  @override
  String get settingsSectionData => 'Daten & Konto';

  @override
  String get skins => 'Skins';

  @override
  String get anatomyModel => 'Anatomie-Modell';

  @override
  String get male => 'Männlich';

  @override
  String get female => 'Weiblich';

  @override
  String get restTimerVibration => 'Pausen-Timer-Vibration';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutConfirm =>
      'Von deinem Konto abmelden? Deine lokalen Daten bleiben auf diesem Gerät.';

  @override
  String get cacheCleared => 'Cache geleert';

  @override
  String get cacheClearFailed => 'Cache konnte nicht geleert werden';

  @override
  String get couldNotOpenLink => 'Link konnte nicht geöffnet werden';

  @override
  String get exportComingSoon => 'Export bald verfügbar';

  @override
  String get deleteAccountFailed =>
      'Konto konnte nicht gelöscht werden. Bitte versuche es erneut.';

  @override
  String get planPremium => 'Premium';

  @override
  String get trainingReminderBody =>
      'Halte deine Serie am Leben. Lass uns trainieren.';

  @override
  String get languageSystem => 'System';

  @override
  String get settingsWorkoutFooter =>
      'Standardwerte für Pausen-Timer, Logging und Kalorienschätzungen.';

  @override
  String get settingsNotificationsFooter =>
      'Trainingserinnerungen schützen deine Serie.';

  @override
  String get settingsDataFooter =>
      'Beim Löschen deines Kontos werden deine Daten dauerhaft von unseren Servern entfernt.';
}
