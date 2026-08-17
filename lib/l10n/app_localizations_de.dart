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
  String get tabBros => 'Bros';

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
  String get editExercises => 'Übungen bearbeiten';

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
  String pricePerMonth(String price) {
    return '$price / Monat';
  }

  @override
  String pricePerYear(String price) {
    return '$price / Jahr';
  }

  @override
  String get saveWithYearly => 'Spare fast 50 % mit dem Jahresabo';

  @override
  String get bestValue => 'Bestes Angebot';

  @override
  String get trialBadge => '7 Tage kostenlos';

  @override
  String get subscribeToContinue => 'Abonnieren, um fortzufahren';

  @override
  String get autoRenewDisclosure =>
      'Das Abo verlängert sich automatisch zum angezeigten Preis und Zeitraum, sofern es nicht mindestens 24 Stunden vor Ende des laufenden Zeitraums gekündigt wird. Verwalte oder kündige es jederzeit in den Kontoeinstellungen von App Store oder Google Play.';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String get purchaseFailed => 'Kauf fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get restoreFailed =>
      'Käufe konnten nicht wiederhergestellt werden. Bitte versuche es erneut.';

  @override
  String get restoreSuccess => 'Käufe wiederhergestellt.';

  @override
  String get noOfferingsAvailable =>
      'Keine Angebote verfügbar. Versuche es später erneut.';

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
  String get clearCache => 'Bild-Cache leeren';

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
  String get postFailed =>
      'Beitrag konnte nicht veröffentlicht werden. Versuch es erneut.';

  @override
  String get backAgainToExit => 'Zum Beenden erneut zurückwischen';

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
  String get restTimer => 'Pausen-Timer';

  @override
  String get off => 'Aus';

  @override
  String get reorderExercises => 'Übungen neu anordnen';

  @override
  String get replaceExercise => 'Übung ersetzen';

  @override
  String get defaultRestTime => 'Standard-Ruhezeit';

  @override
  String get restTimerSound => 'Ruhetimer-Ton';

  @override
  String get trainingReminders => 'Trainings-Erinnerungen';

  @override
  String get communityNotifications => 'Challenges';

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
  String get goalTitle => 'Was ist dein Hauptziel\nbeim Training?';

  @override
  String get bulking => 'Masseaufbau';

  @override
  String get bulkingDesc => 'Fokus auf Muskelmasse und Größe.';

  @override
  String get strength => 'Kraft';

  @override
  String get strengthDesc => 'Schwerer heben und stärker werden.';

  @override
  String get cutting => 'Definition';

  @override
  String get cuttingDesc => 'Körperfett reduzieren, Muskeln erhalten.';

  @override
  String get maintaining => 'Erhalten';

  @override
  String get maintainingDesc =>
      'Halte deine aktuellen Muskeln und deine Fitness.';

  @override
  String get dataPrivate => 'Deine Daten sind privat und sicher.';

  @override
  String get experienceTitle => 'Wie viel Trainingserfahrung\nhast du?';

  @override
  String get base => 'Basis';

  @override
  String get baseYears => '0-1 Jahre';

  @override
  String get mid => 'Mittel';

  @override
  String get midYears => '1-3 Jahre';

  @override
  String get pro => 'Pro';

  @override
  String get proYears => '3+ Jahre';

  @override
  String get selectGender => 'Wähle dein Geschlecht';

  @override
  String get genderSubtitle =>
      'So können wir deinen\nTrainingsplan personalisieren.';

  @override
  String get birthdayTitle => 'Wann hast du Geburtstag?';

  @override
  String get weightTitle => 'Wie viel wiegst du?';

  @override
  String get heightTitle => 'Wie groß bist du?';

  @override
  String get targetZonesTitle => 'Was sind deine\nZielzonen?';

  @override
  String get arms => 'Arme';

  @override
  String get abs => 'Bauch';

  @override
  String get pecs => 'Brust';

  @override
  String get targetBack => 'Rücken';

  @override
  String get legs => 'Beine';

  @override
  String get all => 'Alle';

  @override
  String get kgs => 'kg';

  @override
  String get lbs => 'lbs';

  @override
  String get cm => 'cm';

  @override
  String get ft => 'ft';

  @override
  String get freeTrial => 'Kostenlos testen';

  @override
  String get yearly => 'Jährlich';

  @override
  String get monthly => 'Monatlich';

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
  String get exerciseSearchHint => 'Wonach suchst du?';

  @override
  String get account => 'Konto';

  @override
  String get statBros => 'Bros';

  @override
  String get streak => 'Serie';

  @override
  String get widgetStreakStart => 'Streak starten';

  @override
  String get widgetStreakOneDay => '1-Tage-Streak';

  @override
  String widgetStreakDays(int days) {
    return '$days-Tage-Streak';
  }

  @override
  String get streakSkips => 'Serien-Joker';

  @override
  String streakSkipsExplainer(int count) {
    return 'Trainingstag verpasst? Deine Serie bleibt automatisch bestehen. Du hast $count Joker pro Monat — nie zwei in derselben Woche.';
  }

  @override
  String streakSkipsLeftThisMonth(int count, int total) {
    return '$count von $total diesen Monat übrig';
  }

  @override
  String streakSkipsCountLeft(int count) {
    return '$count übrig';
  }

  @override
  String get streakSkipsNoneLeft => 'Diesen Monat keine Joker mehr übrig';

  @override
  String get posts => 'Beiträge';

  @override
  String get lastSession => 'Letzte Einheit';

  @override
  String get noSessionsYet => 'Noch keine Einheiten';

  @override
  String get noPostsYet => 'Noch keine Beiträge';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get leaderboard => 'Rangliste';

  @override
  String get muscleRecovery => 'Muskelregeneration';

  @override
  String get sore => 'Schmerzhaft';

  @override
  String get tapMuscleToFocus =>
      'Tippe unten auf einen Muskel, um ihn am Körper hervorzuheben';

  @override
  String get anatomyModeRecovery => 'Erholung';

  @override
  String get trainingVolume => 'Trainingsvolumen';

  @override
  String get volumeWindowFourWeeks => '4 Wochen';

  @override
  String get volumeTargetHint =>
      'Ziel: 10–20 gewichtete Sätze pro Muskel und Woche';

  @override
  String get volumeAboveTarget => 'Über dem Ziel';

  @override
  String get volumeOnTarget => 'Im Ziel';

  @override
  String get volumeBelowTarget => 'Unter dem Ziel';

  @override
  String volumeSetsThisWeek(String sets) {
    return '$sets gewichtete Sätze diese Woche';
  }

  @override
  String volumeSetsPerWeek(String sets) {
    return '$sets Sätze/Woche in den letzten 4 Wochen';
  }

  @override
  String get readyNow => 'Jetzt bereit';

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
  String get tabSummary => 'Übersicht';

  @override
  String get tabHistory => 'Verlauf';

  @override
  String get heaviestWeight => 'Höchstes Gewicht';

  @override
  String get oneRepMax => '1RM';

  @override
  String get bestSetVolumeLabel => 'Bestes Satzvolumen';

  @override
  String get bestSessionVolumeLabel => 'Bestes Einheiten-Volumen';

  @override
  String get setRecords => 'Satz-Rekorde';

  @override
  String get last3Months => 'Letzte 3 Monate';

  @override
  String get last6Months => 'Letzte 6 Monate';

  @override
  String get allTime => 'Gesamt';

  @override
  String get noHistoryYet => 'Noch kein Verlauf';

  @override
  String get primaryLabel => 'Primär';

  @override
  String get secondaryLabel => 'Sekundär';

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
  String get superSet => 'Supersatz';

  @override
  String get pressToDelete => 'Zum Löschen drücken';

  @override
  String get time => 'Zeit';

  @override
  String get finish => 'Beenden';

  @override
  String get discard => 'Verwerfen';

  @override
  String get discardWorkoutConfirm =>
      'Dieses Training verwerfen? Der gesamte Fortschritt geht verloren.';

  @override
  String get finishWorkoutConfirm =>
      'Dieses Training beenden? Es wird in deinem Verlauf gespeichert.';

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
  String get confirmFinishTitle => 'Training beenden?';

  @override
  String get confirmFinishBody => 'Es wird in deinem Verlauf gespeichert.';

  @override
  String get confirmDiscardTitle => 'Training verwerfen?';

  @override
  String get confirmDiscardBody => 'Der gesamte Fortschritt geht verloren.';

  @override
  String get confirmDeleteWorkoutBody => 'Es wird aus deinem Verlauf entfernt.';

  @override
  String get confirmDeleteScheduleTitle => 'Diesen Plan löschen?';

  @override
  String get confirmDeleteScheduleBody =>
      'Das kann nicht rückgängig gemacht werden.';

  @override
  String get confirmSignOutTitle => 'Abmelden?';

  @override
  String get confirmSignOutBody =>
      'Deine lokalen Daten bleiben auf diesem Gerät. Zum Synchronisieren musst du dich erneut anmelden.';

  @override
  String get confirmDeleteAccountTitle => 'Konto löschen?';

  @override
  String get confirmDeleteAccountBody =>
      'Alle deine Daten werden dauerhaft gelöscht — Einheiten, PRs, Pläne. Das kann nicht rückgängig gemacht werden.';

  @override
  String get keepGoing => 'Weitermachen';

  @override
  String get holdToDelete => 'Zum Löschen halten';

  @override
  String get holdConfirmed => 'Bestätigt';

  @override
  String get tapAgainToConfirm => 'Zum Bestätigen erneut tippen';

  @override
  String get exercisesLabel => 'Übungen';

  @override
  String get newPrLabel => 'Neuer PR';

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
  String get leagueMasterTitle => 'Meister';

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
  String get rankUnranked => 'Ohne Rang';

  @override
  String get rankUpTitle => 'AUFGESTIEGEN!';

  @override
  String get rankUpCta => 'Los geht\'s!';

  @override
  String get liftRankCardTitle => 'Kraft-Rang';

  @override
  String liftRankUpSubtitle(String lift, String rank) {
    return '$lift hat $rank erreicht';
  }

  @override
  String get shareRanksChip => 'Ränge';

  @override
  String get shareRanksTitle => 'Heutige Ränge';

  @override
  String get newPrTitle => 'NEUER REKORD!';

  @override
  String rankNext(String rank) {
    return 'Als Nächstes: $rank';
  }

  @override
  String get rankMax => 'Höchster Rang erreicht';

  @override
  String get rankShieldTooltip =>
      'Abstiegsschutz — dein Rang ist geschützt, während du dich zurückkämpfst.';

  @override
  String get skinPremium => 'Premium';

  @override
  String get skinPremiumSoon => 'Premium-Skin — Kauf bald verfügbar';

  @override
  String skinWorkoutsShort(int count) {
    return '$count Workouts';
  }

  @override
  String skinLockedProgress(int count) {
    return 'Wird bei $count Workouts freigeschaltet';
  }

  @override
  String get noChallengesYet => 'Keine aktiven Challenges';

  @override
  String get settingsSectionAppearance => 'Darstellung';

  @override
  String get settingsSectionPersonal => 'Persönliches';

  @override
  String get pinkMode => 'Pink-Modus';

  @override
  String get premadeTitle => 'Pro-Programme';

  @override
  String get premadeSubtitle =>
      'Fertige Pläne für jede Situation — ohne Einrichtung';

  @override
  String get premadeCategoryAll => 'Alle';

  @override
  String get premadeCategoryQuick => 'Schnell';

  @override
  String get premadeCategoryHome => 'Zuhause';

  @override
  String get premadeCategoryCalisthenics => 'Calisthenics';

  @override
  String get premadeCategoryCore => 'Core';

  @override
  String get premadeLevelBeginner => 'Anfänger';

  @override
  String get premadeLevelIntermediate => 'Fortgeschritten';

  @override
  String get premadeLevelAdvanced => 'Profi';

  @override
  String premadeMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String premadeDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String premadeExercisesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Übungen',
      one: '1 Übung',
    );
    return '$_temp0';
  }

  @override
  String get premadeAdd => 'Zu meinen Programmen hinzufügen';

  @override
  String get premadeAdded => 'Hinzugefügt! Du findest es im Training-Tab.';

  @override
  String get premadeDayFullBody => 'Ganzkörper';

  @override
  String get premadeDayUpper => 'Oberkörper';

  @override
  String get premadeDayLower => 'Unterkörper';

  @override
  String get premadeDayPush => 'Push';

  @override
  String get premadeDayPull => 'Pull';

  @override
  String get premadeDayLegsCore => 'Beine & Core';

  @override
  String get premadeDayCore => 'Core';

  @override
  String get premadeDayArms => 'Arme';

  @override
  String get premadeWakeUpName => '5-Minuten-Wachmacher';

  @override
  String get premadeWakeUpTagline => 'Schneller Ganzkörper-Boost am Morgen';

  @override
  String get premadeCoreBlastName => '5-Minuten-Core-Blast';

  @override
  String get premadeCoreBlastTagline => 'Vier Übungen, brennender Core';

  @override
  String get premadeArmPumpName => '5-Minuten-Armpump';

  @override
  String get premadeArmPumpTagline => 'Schnelles Finish für Bizeps und Trizeps';

  @override
  String get premadeHomeFullBodyName => 'Ganzkörper zuhause';

  @override
  String get premadeHomeFullBodyTagline => 'Drei Tage ganz ohne Geräte';

  @override
  String get premadeHomeDumbbellName => 'Kurzhantel-Plan zuhause';

  @override
  String get premadeHomeDumbbellTagline =>
      'Ganzkörper mit nur zwei Kurzhanteln';

  @override
  String get premadeCalisthenicsBasicsName => 'Calisthenics-Grundlagen';

  @override
  String get premadeCalisthenicsBasicsTagline =>
      'Meistere Push, Pull und Squat';

  @override
  String get premadeCalisthenicsStrengthName => 'Calisthenics-Kraft';

  @override
  String get premadeCalisthenicsStrengthTagline =>
      'Schwerere Skills mit Körpergewicht';

  @override
  String get premadeCoreAbsName => 'Core & Bauch';

  @override
  String get premadeCoreAbsTagline => 'Zwei Tage für eine starke Mitte';

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
  String get exportPreparing => 'Dein Export wird vorbereitet …';

  @override
  String get exportNothingYet =>
      'Noch nichts zu exportieren — logge zuerst ein Workout';

  @override
  String get exportFailed => 'Export fehlgeschlagen. Bitte versuche es erneut.';

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

  @override
  String get duration => 'Dauer';

  @override
  String get heatmapLess => 'Weniger';

  @override
  String get heatmapMore => 'Mehr';

  @override
  String get tapDayToJump =>
      'Tippe auf einen Tag, um zu seiner Einheit zu springen';

  @override
  String jumpedToDay(String date) {
    return 'Zu $date gesprungen';
  }

  @override
  String get shareNiceWork => 'Gut gemacht.';

  @override
  String get shareStyleDark => 'Dunkel';

  @override
  String get shareStyleSticker => 'Sticker';

  @override
  String get shareTemplateEditorial => 'Editorial';

  @override
  String get shareTemplateAnatomy => 'Anatomie';

  @override
  String get shareTemplateHype => 'Hype';

  @override
  String shareWorkoutNumber(int count) {
    return 'Training #$count';
  }

  @override
  String get shareTotalVolumeLifted => 'Gesamtvolumen gehoben';

  @override
  String get shareOneSession => 'Eine Einheit';

  @override
  String get shareYou => 'Du';

  @override
  String shareHeavierThan(String object) {
    return 'Schwerer als $object.';
  }

  @override
  String get shareAnonymous => 'Anonym';

  @override
  String get shareError =>
      'Bild konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get shareSaved => 'In der Galerie gespeichert';

  @override
  String get shareSaveError => 'Speichern in der Galerie fehlgeschlagen';

  @override
  String get shareExerciseTitle => 'Dein Fortschritt.';

  @override
  String get sharePersonalRecords => 'Persönliche Rekorde';

  @override
  String get shareVolumeTrend => 'Volumen-Trend';

  @override
  String shareTrendSessions(int count) {
    return 'Letzte $count Einheiten';
  }

  @override
  String get shareVolumeCaption => 'Das ist ordentlich Eisen.';

  @override
  String get shareVolumeDog => 'ein großer Hund';

  @override
  String get shareVolumeFridge => 'ein Kühlschrank';

  @override
  String get shareVolumePiano => 'ein Flügel';

  @override
  String get shareVolumeCar => 'ein Kleinwagen';

  @override
  String get shareVolumeVan => 'ein Lieferwagen';

  @override
  String get shareVolumeElephant => 'ein ausgewachsener Elefant';

  @override
  String get shareObjectDog => 'Hund';

  @override
  String get shareObjectFridge => 'Kühlschrank';

  @override
  String get shareObjectPiano => 'Flügel';

  @override
  String get shareObjectCar => 'Auto';

  @override
  String get shareObjectVan => 'Lieferwagen';

  @override
  String get shareObjectElephant => 'Elefant';

  @override
  String get close => 'Schließen';

  @override
  String get hint => 'Hinweis';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get markSetComplete => 'Satz als abgeschlossen markieren';

  @override
  String get markSetIncomplete => 'Satz als nicht abgeschlossen markieren';

  @override
  String restTimerRemaining(String time) {
    return 'Pausen-Timer, noch $time';
  }

  @override
  String get plateCalculator => 'Scheibenrechner';

  @override
  String get plateCalcTargetWeight => 'Zielgewicht';

  @override
  String get plateCalcBar => 'Stange';

  @override
  String get plateCalcPerSide => 'pro Seite';

  @override
  String plateCalcUnreachable(String amount) {
    return 'Um $amount nicht erreichbar';
  }

  @override
  String get getStarted => 'Loslegen';

  @override
  String get welcomeTagline => 'Von Gym Bros für Gym Bros';

  @override
  String get noData => 'Keine Daten';

  @override
  String get progressLabel => 'FORTSCHRITT';

  @override
  String get weightsKg => 'Gewicht kg';

  @override
  String get day => 'Tag';

  @override
  String dayNumber(int number) {
    return 'Tag $number';
  }

  @override
  String get label => 'Label';

  @override
  String get dayLabel => 'Tag-Label';

  @override
  String get dayLabelHint => 'z. B. Brusttag';

  @override
  String get weightKg => 'Gewicht (kg)';

  @override
  String get deleteSchedule => 'Plan löschen';

  @override
  String get deleteScheduleConfirm =>
      'Diesen Plan wirklich löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get defaultProgramName => 'Programm 1';

  @override
  String get recentExercises => 'Zuletzt verwendet';

  @override
  String get allExercises => 'Alle Übungen';

  @override
  String allCategory(String category) {
    return 'Alle $category';
  }

  @override
  String get other => 'Sonstiges';

  @override
  String get equipmentNone => 'Ohne';

  @override
  String get barbell => 'Langhantel';

  @override
  String get dumbbell => 'Kurzhantel';

  @override
  String get kettlebell => 'Kettlebell';

  @override
  String get machine => 'Maschine';

  @override
  String get resistanceBand => 'Widerstandsband';

  @override
  String get cardio => 'Cardio';

  @override
  String setsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sätze',
      one: '1 Satz',
    );
    return '$_temp0';
  }

  @override
  String get splitCurrentPlan => 'Aktueller Plan';

  @override
  String splitTrainingDaysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Trainingstage pro Woche',
      one: '1 Trainingstag pro Woche',
    );
    return '$_temp0';
  }

  @override
  String get splitDescription =>
      'Fokus auf Kraft, Muskelaufbau und symmetrische Entwicklung.';

  @override
  String get splitStatDuration => 'Dauer';

  @override
  String get splitStatSinceStart => 'seit Start';

  @override
  String get splitStatDays => 'Tage';

  @override
  String get splitStatTrainingDays => 'Trainingstage';

  @override
  String get splitStatSession => 'Einheit';

  @override
  String get splitStatAvgDuration => 'Ø Dauer';

  @override
  String get splitStatProgress => 'Fortschritt';

  @override
  String splitMinutesRange(int min, int max) {
    return '$min–$max Min.';
  }

  @override
  String get splitWeeklyPlan => 'Dein Wochenplan';

  @override
  String get splitDay => 'Tag';

  @override
  String get splitRestSubtitle => 'Regeneration & Erholung';

  @override
  String get splitQuickProgress => 'Fortschritt';

  @override
  String get splitQuickProgressSub => 'Deine Entwicklung';

  @override
  String get splitQuickEditPlan => 'Plan bearbeiten';

  @override
  String get splitQuickEditPlanSub => 'Tage & Übungen';

  @override
  String get splitQuickSettings => 'Einstellungen';

  @override
  String get splitQuickSettingsSub => 'App-Einstellungen';

  @override
  String get splitQuickDiscover => 'Entdecken';

  @override
  String get splitQuickDiscoverSub => 'Weitere Trainingspläne';

  @override
  String get dayDetailCurrentPlan => 'Aktueller Plan';

  @override
  String dayDetailDescription(String muscles) {
    return 'Fokus auf $muscles. Ideal für Kraft und Muskelaufbau.';
  }

  @override
  String get dayDetailStatCalories => 'Kalorien';

  @override
  String get dayDetailKcalApprox => 'kcal (ca.)';

  @override
  String get dayDetailWorkoutHeader => 'Dein Workout';

  @override
  String dayDetailRepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wdh.',
      one: '1 Wdh.',
    );
    return '$_temp0';
  }

  @override
  String get discoverTitle => 'Entdecken';

  @override
  String get discoverProgramsTitle => 'Programme';

  @override
  String get discoverFilter => 'Filter';

  @override
  String get discoverLevel => 'Level';

  @override
  String get discoverGoal => 'Ziel';

  @override
  String get discoverEquipment => 'Equipment';

  @override
  String discoverRoutinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Routinen',
      one: '1 Routine',
    );
    return '$_temp0';
  }

  @override
  String discoverShowAll(int count) {
    return 'Alle $count Programme anzeigen';
  }

  @override
  String get discoverCoachTitle => 'Dein persönlicher Coach';

  @override
  String get discoverCoachSubtitle =>
      'Programme basierend auf deinen Zielen und Bedürfnissen.';

  @override
  String get discoverOtherPlansCta => 'Weitere Trainingspläne entdecken';

  @override
  String get addBros => 'Bros hinzufügen';

  @override
  String get myUsernameTitle => 'Mein Handle';

  @override
  String get claimUsernameTitle => 'Sichere dir dein Handle';

  @override
  String get claimUsernameExplainer =>
      'Bros finden dich über dein @Handle. 3–20 Zeichen: Kleinbuchstaben, Zahlen, Unterstrich.';

  @override
  String get claimUsernameHint => 'handle';

  @override
  String get claimAction => 'Sichern';

  @override
  String get usernameTaken => 'Dieses Handle ist schon vergeben.';

  @override
  String get usernameInvalid =>
      '3–20 Zeichen: Kleinbuchstaben, Zahlen, Unterstrich.';

  @override
  String get usernameNeedsOnline =>
      'Zum Sichern eines Handles brauchst du eine Verbindung.';

  @override
  String get searchByUsername => 'Per @Handle hinzufügen';

  @override
  String get searchByUsernameHint => '@handle';

  @override
  String get searchNoMatch => 'Niemand hat dieses Handle.';

  @override
  String get searchNeedsOnline => 'Die Suche braucht eine Verbindung.';

  @override
  String get requestsTitle => 'Anfragen';

  @override
  String get acceptAction => 'Annehmen';

  @override
  String get declineAction => 'Ablehnen';

  @override
  String get sentRequestsTitle => 'Gesendet';

  @override
  String get cancelRequestAction => 'Abbrechen';

  @override
  String get myBrosTitle => 'Meine Bros';

  @override
  String get noBrosYet =>
      'Noch keine Bros. Lade deine Crew ein oder füge sie per @Handle hinzu.';

  @override
  String get inviteAction => 'Einladen';

  @override
  String get inviteSheetTitle => 'Einen Bro einladen';

  @override
  String get inviteQrHint => 'Lass deinen Bro das mit der Kamera scannen';

  @override
  String get inviteShareAction => 'Einladungslink teilen';

  @override
  String inviteMessage(String username, String link) {
    return 'Füg mich auf MyGymBro hinzu — ich bin @$username. $link';
  }

  @override
  String get inviteNeedsUsername =>
      'Sichere dir zuerst ein Handle — deine Einladung enthält es.';

  @override
  String get removeBroAction => 'Bro entfernen';

  @override
  String get removeBroConfirmTitle => 'Diesen Bro entfernen?';

  @override
  String get removeBroConfirmBody =>
      'Du kannst später jederzeit eine neue Anfrage senden.';

  @override
  String get blockAction => 'Blockieren';

  @override
  String get blockConfirmTitle => 'Diese Person blockieren?';

  @override
  String get blockConfirmBody =>
      'Ihr verschwindet komplett voneinander. Nur du kannst das rückgängig machen.';

  @override
  String get unblockAction => 'Blockierung aufheben';

  @override
  String get blockedTitle => 'Blockiert';

  @override
  String get reportAction => 'Melden';

  @override
  String get reportSheetTitle => 'Diese Person melden';

  @override
  String get reportReasonSpam => 'Spam oder Fake-Konto';

  @override
  String get reportReasonHarassment => 'Belästigung oder Mobbing';

  @override
  String get reportReasonImpersonation => 'Identitätsdiebstahl';

  @override
  String get reportReasonOther => 'Etwas anderes';

  @override
  String get reportSentToast => 'Meldung gesendet. Wir prüfen sie.';

  @override
  String get requestSentToast => 'Anfrage gesendet.';

  @override
  String get nowBrosToast => 'Ihr seid jetzt Bros!';

  @override
  String get requestFailedToast => 'Anfrage konnte nicht gesendet werden.';

  @override
  String get addBroAction => 'Bro hinzufügen';

  @override
  String get pendingLabel => 'Ausstehend';

  @override
  String get signInToAddBros => 'Melde dich an, um Bros hinzuzufügen.';

  @override
  String get communityChallenges => 'Community-Challenges';

  @override
  String endsInShort(Object time) {
    return 'Endet in $time';
  }

  @override
  String get endedLabel => 'Beendet';

  @override
  String durationShortDays(Object n) {
    return '$n T';
  }

  @override
  String durationShortHours(Object n) {
    return '$n Std.';
  }

  @override
  String percentDone(Object percent) {
    return '$percent% geschafft';
  }

  @override
  String progressOfGoal(Object goal, Object progress) {
    return '$progress / $goal';
  }

  @override
  String get joinChallenge => 'Mitmachen';

  @override
  String get joinedChallenge => 'Dabei';

  @override
  String get leaveChallenge => 'Challenge verlassen';

  @override
  String get challengeCompleted => 'Geschafft';

  @override
  String plusPoints(Object points) {
    return '+$points Pkt.';
  }

  @override
  String challengePointsChip(Object points) {
    return '$points Pkt.';
  }

  @override
  String get createChallenge => 'Challenge erstellen';

  @override
  String get challengeTitleLabel => 'Titel';

  @override
  String get challengeDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get challengeGoalLabel => 'Ziel';

  @override
  String get goalTypeVolume => 'Volumen (kg)';

  @override
  String get goalTypeSessions => 'Workouts';

  @override
  String get goalTypeSets => 'Sätze';

  @override
  String get goalTypeStreak => 'Trainingstage';

  @override
  String get goalTypeCustom => 'Eigenes Ziel (Vertrauensbasis)';

  @override
  String get challengeTargetLabel => 'Zielwert';

  @override
  String get challengeDurationLabel => 'Dauer';

  @override
  String durationDaysOption(Object days) {
    return '$days Tage';
  }

  @override
  String challengePointsLabel(Object max) {
    return 'Punkte (max. $max)';
  }

  @override
  String get reportChallenge => 'Challenge melden';

  @override
  String get deleteChallenge => 'Challenge löschen';

  @override
  String get markComplete => 'Als geschafft markieren';

  @override
  String get challengeCreatedToast => 'Challenge erstellt';

  @override
  String get challengeInvalidToast =>
      'Bitte prüfe die Angaben und versuch es erneut.';

  @override
  String get challengeReportedToast => 'Danke — diese Challenge wird geprüft.';

  @override
  String get signInToJoinChallenges =>
      'Melde dich an, um bei Challenges mitzumachen.';

  @override
  String get tplDailyOneSessionTitle => 'Zeig dich';

  @override
  String get tplDailyOneSessionDesc => 'Schließe heute ein Training ab.';

  @override
  String get tplDailyVolume5kTitle => 'Beweg 5.000 kg';

  @override
  String get tplDailyVolume5kDesc =>
      'Hebe heute insgesamt 5.000 kg über alle Sätze.';

  @override
  String get tplDailyVolume10kTitle => 'Beweg 10.000 kg';

  @override
  String get tplDailyVolume10kDesc =>
      'Hebe heute insgesamt 10.000 kg über alle Sätze.';

  @override
  String get tplDailySets12Title => '12 Arbeitssätze';

  @override
  String get tplDailySets12Desc =>
      'Schaffe heute 12 Arbeitssätze (Aufwärmsätze zählen nicht).';

  @override
  String get tplDailySets20Title => '20 Arbeitssätze';

  @override
  String get tplDailySets20Desc =>
      'Schaffe heute 20 Arbeitssätze (Aufwärmsätze zählen nicht).';

  @override
  String get boardWeekly => 'Woche';

  @override
  String get boardMonthly => 'Monat';

  @override
  String get boardAllTime => 'Gesamt';

  @override
  String resetsIn(Object time) {
    return 'Reset in $time';
  }

  @override
  String lastWinnerLabel(Object name) {
    return 'Letzter Sieg: $name';
  }
}
