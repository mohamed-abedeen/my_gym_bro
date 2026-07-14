// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'My Gym Bro';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabWorkout => 'Entraînement';

  @override
  String get tabLog => 'Journal';

  @override
  String get tabCommunity => 'Communauté';

  @override
  String get status => 'Statut';

  @override
  String get dailyChallenge => 'Défi du jour';

  @override
  String get competeFriends => 'Défiez vos amis';

  @override
  String get startTrial => 'Essai gratuit de 7 jours';

  @override
  String get createSchedule => 'Créer un programme';

  @override
  String get buildYourFlow => 'Créez votre programme ou trouvez un plan pro';

  @override
  String scheduleRemaining(int hours) {
    return '${hours}h restantes';
  }

  @override
  String get nextSession => 'Prochaine séance';

  @override
  String get sessionLog => 'Séances';

  @override
  String get statusLog => 'Statut';

  @override
  String get weeklyProgress => 'Progrès hebdomadaire';

  @override
  String get recovered => 'Récupéré';

  @override
  String get recovering => 'En récupération';

  @override
  String get undertrained => 'Non entraîné';

  @override
  String get healingTitle => 'Récupération...';

  @override
  String get healingSubtitle => 'Votre corps a besoin de repos';

  @override
  String get sets => 'Séries';

  @override
  String get reps => 'Reps';

  @override
  String get weight => 'Poids';

  @override
  String get startWorkout => 'Commencer';

  @override
  String get finishWorkout => 'Terminer';

  @override
  String get restDay => 'Jour de repos';

  @override
  String get calBurned => 'Calories brûlées';

  @override
  String get calBurnedLastWeek => 'Calories brûlées la semaine dernière';

  @override
  String get calBurnedThisWeek => 'Calories brûlées cette semaine';

  @override
  String get weeklyReports => 'Rapports hebdomadaires';

  @override
  String get reports => 'Rapports';

  @override
  String get week => 'Semaine';

  @override
  String get weights => 'Poids';

  @override
  String get calUnit => 'Cal';

  @override
  String get minUnit => 'Min';

  @override
  String get exercisePrefix => 'Exo';

  @override
  String get reportNoData => 'Pas d\'entraînement ce jour';

  @override
  String statusKcalProgress(int burned, int goal) {
    return '$burned/$goal KCAL';
  }

  @override
  String statusKcalNoGoal(int burned) {
    return '$burned KCAL';
  }

  @override
  String get shoulders => 'Épaules';

  @override
  String get chest => 'Pectoraux';

  @override
  String get core => 'Gainage';

  @override
  String get target => 'Objectif';

  @override
  String get achieved => 'Atteint';

  @override
  String statusLiftedTotal(String amount) {
    return 'Tu as soulevé $amount depuis le premier jour !';
  }

  @override
  String statusVolumeIncrease(int pct) {
    return 'Ton poids soulevé a augmenté de $pct% depuis le premier jour !';
  }

  @override
  String statusRepsTotal(String reps) {
    return 'Tu as fait $reps répétitions depuis le premier jour !';
  }

  @override
  String statusCaloriesBurnedTotal(String kcal) {
    return 'Tu as brûlé plus de $kcal calories !';
  }

  @override
  String statusCaloriesBodyFat(String kcal, String pct) {
    return 'Tu as brûlé plus de $kcal calories et perdu $pct% de masse grasse !';
  }

  @override
  String get calorieGoal => 'Objectif calorique';

  @override
  String get bodyFat => 'Masse grasse';

  @override
  String get totalDuration => 'Durée totale';

  @override
  String get avgStrength => 'Force moyenne';

  @override
  String get records => 'Records';

  @override
  String get volume => 'Volume';

  @override
  String get totalVolume => 'Volume total';

  @override
  String get totalTime => 'Temps total';

  @override
  String get howTo => 'Comment faire';

  @override
  String get targetMuscles => 'Muscles ciblés';

  @override
  String get secondaryMuscles => 'Muscles secondaires';

  @override
  String get equipment => 'Équipement';

  @override
  String get instructions => 'Instructions';

  @override
  String get searchExercises => 'Rechercher des exercices...';

  @override
  String get noRecordsYet => 'Aucun record pour l\'instant';

  @override
  String get yourRecords => 'Vos records';

  @override
  String bestSet(double weight, int reps) {
    return 'Meilleur : ${weight}kg × $reps reps';
  }

  @override
  String get addSet => 'Ajouter une série';

  @override
  String get addExercise => 'Ajouter un exercice';

  @override
  String get editExercises => 'Modifier les exercices';

  @override
  String get addDay => 'Ajouter des jours';

  @override
  String get scheduleName => 'Nom du programme';

  @override
  String get todaySession => 'Séance du jour';

  @override
  String get lastWeek => 'Semaine dernière';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get yesterday => 'Hier';

  @override
  String get cancelAnytime =>
      'Annulez à tout moment. Sans frais pendant l\'essai.';

  @override
  String get restoreSubscription => 'Restaurer les achats';

  @override
  String get monthlyPlan => 'Mensuel';

  @override
  String get yearlyPlan => 'Annuel';

  @override
  String get bestValue => 'Meilleure offre';

  @override
  String get trialBadge => 'Essai gratuit 7 jours';

  @override
  String get subscribeToContinue => 'Abonnez-vous pour continuer';

  @override
  String get autoRenewDisclosure =>
      'L\'abonnement se renouvelle automatiquement au prix et pour la période indiqués, sauf annulation au moins 24 heures avant la fin de la période en cours. Gérez ou annulez à tout moment dans les réglages de votre compte App Store ou Google Play.';

  @override
  String get termsOfUse => 'Conditions d\'utilisation';

  @override
  String get purchaseFailed => 'Échec de l\'achat. Veuillez réessayer.';

  @override
  String get restoreFailed =>
      'Impossible de restaurer les achats. Veuillez réessayer.';

  @override
  String get noOfferingsAvailable =>
      'Aucune offre disponible. Réessayez plus tard.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'Créer un compte';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get nameLabel => 'Votre prénom';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get noAccount => 'Pas encore de compte ?';

  @override
  String get alreadyAccount => 'J\'ai déjà un compte';

  @override
  String get chooseLanguage => 'Choisissez votre langue';

  @override
  String get chooseGoal => 'Quel est votre objectif ?';

  @override
  String get buildMuscle => 'Prise de masse';

  @override
  String get loseWeight => 'Perte de poids';

  @override
  String get getStronger => 'Gagner en force';

  @override
  String get chooseExperience => 'Votre niveau ?';

  @override
  String get beginner => 'Débutant';

  @override
  String get intermediate => 'Intermédiaire';

  @override
  String get advanced => 'Avancé';

  @override
  String get letsGo => 'C\'est parti';

  @override
  String get trialStarted =>
      'Votre essai gratuit de 7 jours commence maintenant';

  @override
  String get securityWarningTitle => 'Avertissement de sécurité';

  @override
  String get securityWarningBody =>
      'Cet appareil semble compromis. My Gym Bro ne peut pas fonctionner en sécurité.';

  @override
  String get closeApp => 'Fermer l\'application';

  @override
  String get biometricPrompt => 'Déverrouiller My Gym Bro';

  @override
  String get language => 'Langue';

  @override
  String get weightUnit => 'Unité de poids';

  @override
  String get bodyWeight => 'Poids corporel';

  @override
  String get notSet => 'Non défini';

  @override
  String get biometricLock => 'Verrouillage biométrique';

  @override
  String get manageSubscription => 'Gérer l\'abonnement';

  @override
  String get exportData => 'Exporter mes données';

  @override
  String get clearCache => 'Vider le cache communauté';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountConfirm =>
      'Cela supprimera définitivement toutes vos données. Action irréversible.';

  @override
  String get deleteAccountButton => 'Supprimer mon compte';

  @override
  String lastSynced(String time) {
    return 'Synchronisé $time';
  }

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get rateApp => 'Noter l\'application';

  @override
  String get contactSupport => 'Contacter le support';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get pendingSync => 'Sync en attente';

  @override
  String get synced => 'Synchronisé';

  @override
  String get syncError => 'Erreur de sync';

  @override
  String get loadingExercises => 'Chargement des exercices...';

  @override
  String get whatOnYourMind => 'Quoi de neuf ?';

  @override
  String get communityEmpty =>
      'Aucune publication pour l\'instant. Sois le premier !';

  @override
  String get communityError =>
      'Impossible de charger le fil. Glisse vers le bas pour réessayer.';

  @override
  String get post => 'Publier';

  @override
  String get skip => 'Passer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get done => 'Terminer';

  @override
  String get back => 'Retour';

  @override
  String get share => 'Partager';

  @override
  String get schedule => 'Programme';

  @override
  String get noScheduleYet => 'Aucun programme';

  @override
  String activeSubscription(String date) {
    return 'Actif — renouvellement le $date';
  }

  @override
  String trialDaysLeft(int days) {
    return 'Essai — $days jours restants';
  }

  @override
  String get subscriptionExpired => 'Abonnement expiré';

  @override
  String get restComplete => 'Récupération terminée !';

  @override
  String get restCompleteTitleSupportive => 'Récupération terminée';

  @override
  String get restCompleteBodySupportive =>
      'Tes muscles sont prêts quand tu l\'es.';

  @override
  String get restCompleteTitleBalanced => 'Récupération terminée';

  @override
  String get restCompleteBodyBalanced =>
      'Il est temps de commencer ta prochaine série.';

  @override
  String get restCompleteTitleBold => 'Récupération terminée';

  @override
  String get restCompleteBodyBold => 'On y retourne. Série suivante.';

  @override
  String get restCompleteTitleSavage => 'PAUSE FINIE';

  @override
  String get restCompleteBodySavage => 'SÉRIE SUIVANTE. MAINTENANT.';

  @override
  String get notificationTone => 'Ton des notifications';

  @override
  String get notificationToneSubtitle => 'Choisis le ton de tes rappels';

  @override
  String get toneSupportive => 'Bienveillant';

  @override
  String get toneSupportiveDescription => 'Rappels doux et encourageants.';

  @override
  String get toneBalanced => 'Équilibré';

  @override
  String get toneBalancedDescription => 'Rappels neutres et factuels.';

  @override
  String get toneBold => 'Direct';

  @override
  String get toneBoldDescription => 'Rappels directs et affirmés.';

  @override
  String get toneSavage => 'Impitoyable';

  @override
  String get toneSavageDescription => 'Rappels en majuscules, sans excuses.';

  @override
  String get notificationToneOnboardingTitle => 'Choisis ta voix';

  @override
  String get notificationToneOnboardingSubtitle =>
      'Comment devons-nous te parler pendant tes entraînements ?';

  @override
  String get notificationToneExampleLabel => 'Exemple';

  @override
  String get restTimer => 'Minuteur de repos';

  @override
  String get off => 'Non';

  @override
  String get reorderExercises => 'Réorganiser les exercices';

  @override
  String get replaceExercise => 'Remplacer l\'exercice';

  @override
  String get defaultRestTime => 'Temps de repos par défaut';

  @override
  String get restTimerSound => 'Son du minuteur de repos';

  @override
  String get trainingReminders => 'Rappels d\'entraînement';

  @override
  String get communityNotifications => 'Défis communautaires';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get skipRest => 'Passer';

  @override
  String addSeconds(int n) {
    return '+${n}s';
  }

  @override
  String subtractSeconds(int n) {
    return '-${n}s';
  }

  @override
  String get settings => 'Paramètres';

  @override
  String get bodyStatus => 'Statut corporel';

  @override
  String get workoutStatus => 'Statut entraînement';

  @override
  String get lastMonth => 'Mois dernier';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get weeklyStreak => 'Série hebdomadaire';

  @override
  String get leaderboardEmpty =>
      'Pas encore de classement. Termine une séance pour entrer dans le tableau de la semaine.';

  @override
  String setsThisWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries cette semaine',
      one: '1 série cette semaine',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Entraînez-vous mieux. Devenez plus fort.';

  @override
  String get continueButton => 'Continuer';

  @override
  String get passwordStrengthWeak => 'Faible';

  @override
  String get passwordStrengthMedium => 'Moyen';

  @override
  String get passwordStrengthStrong => 'Fort';

  @override
  String get emailInvalid => 'Veuillez entrer un e-mail valide';

  @override
  String get nameRequired => 'Le nom est requis';

  @override
  String get passwordRequirements =>
      'Min 8 caractères, 1 majuscule, 1 chiffre, 1 spécial';

  @override
  String get trialFeature1 => 'Suivi d\'entraînement illimité';

  @override
  String get trialFeature2 => 'Bibliothèque de 1300+ exercices';

  @override
  String get trialFeature3 => 'Programmes d\'entraînement personnalisés';

  @override
  String get trialFeature4 => 'Analyses de progression & records';

  @override
  String get resetPasswordSent => 'E-mail de réinitialisation envoyé';

  @override
  String get orDivider => 'ou';

  @override
  String get signUpError =>
      'Impossible de créer le compte. Veuillez réessayer.';

  @override
  String get signInError => 'E-mail ou mot de passe invalide.';

  @override
  String get goalTitle =>
      'Quel est votre objectif principal\nd\'entraînement ?';

  @override
  String get bulking => 'Prise de masse';

  @override
  String get bulkingDesc => 'Priorité à la masse musculaire et au volume.';

  @override
  String get strength => 'Force';

  @override
  String get strengthDesc => 'Soulever plus lourd et devenir plus fort.';

  @override
  String get cutting => 'Sèche';

  @override
  String get cuttingDesc =>
      'Réduire la graisse corporelle en gardant le muscle.';

  @override
  String get maintaining => 'Maintien';

  @override
  String get maintainingDesc =>
      'Conserver votre muscle et votre forme actuels.';

  @override
  String get dataPrivate => 'Vos données sont privées et sécurisées.';

  @override
  String get experienceTitle =>
      'Quelle est votre expérience\nen entraînement ?';

  @override
  String get base => 'Base';

  @override
  String get baseYears => '0-1 an';

  @override
  String get mid => 'Moyen';

  @override
  String get midYears => '1-3 ans';

  @override
  String get pro => 'Pro';

  @override
  String get proYears => '3+ ans';

  @override
  String get selectGender => 'Sélectionnez votre genre';

  @override
  String get genderSubtitle =>
      'Cela nous aide à personnaliser\nvotre plan d\'entraînement.';

  @override
  String get birthdayTitle => 'Quelle est votre date de naissance ?';

  @override
  String get weightTitle => 'Quel est votre poids ?';

  @override
  String get heightTitle => 'Quelle est votre taille ?';

  @override
  String get targetZonesTitle => 'Quelles sont vos zones\ncibles ?';

  @override
  String get arms => 'Bras';

  @override
  String get abs => 'Abdos';

  @override
  String get pecs => 'Pectoraux';

  @override
  String get targetBack => 'Dos';

  @override
  String get legs => 'Jambes';

  @override
  String get all => 'Tout';

  @override
  String get kgs => 'kg';

  @override
  String get lbs => 'lbs';

  @override
  String get cm => 'cm';

  @override
  String get ft => 'ft';

  @override
  String get freeTrial => 'Essai gratuit';

  @override
  String get yearly => 'Annuel';

  @override
  String get monthly => 'Mensuel';

  @override
  String get dmMessages => 'Messages';

  @override
  String get dmSearch => 'Rechercher';

  @override
  String get dmNoMessagesYet => 'Pas encore de messages';

  @override
  String get dmStartChatting => 'Discutez avec vos Gym Bros !';

  @override
  String get dmNewConversationUnavailable =>
      'Nouvelle conversation non disponible en v1';

  @override
  String dmStartConversation(String name) {
    return 'Commencez votre conversation\navec $name';
  }

  @override
  String get dmMessageHint => 'Message...';

  @override
  String get dmSendFailed =>
      'Échec de l\'envoi du message. Veuillez réessayer.';

  @override
  String get dmSavedToSchedules => 'Enregistré dans vos programmes !';

  @override
  String get dmCamera => 'Caméra';

  @override
  String get dmGallery => 'Galerie';

  @override
  String get dmSchedule => 'Programme';

  @override
  String get dmShareSchedule => 'Partager le programme';

  @override
  String get dmNoSchedulesToShare => 'Aucun programme à partager';

  @override
  String get dmSharedSchedule => 'Programme partagé';

  @override
  String get dmInvalidSchedule => 'Données de programme invalides';

  @override
  String get dmSaveToMySchedules => 'Enregistrer dans mes programmes';

  @override
  String get dmUploading => 'Envoi en cours...';

  @override
  String get dmSentMessage => 'Message envoyé';

  @override
  String get dmImageTooLarge => 'L\'image dépasse la limite de 10 Mo.';

  @override
  String dmDaysCount(int count) {
    return '$count jours';
  }

  @override
  String get dmWorkout => 'Entraînement';

  @override
  String get addDayTitle => 'Ajouter un jour';

  @override
  String get oneStepCloserBro => 'Un pas de plus, bro';

  @override
  String get newProgram => 'Nouveau programme';

  @override
  String nextSessionAfter(int hours) {
    return 'Prochaine séance dans ${hours}h';
  }

  @override
  String get readyToTrain => 'Prêt à t\'entraîner, Bro !';

  @override
  String get restDaysBetween => 'Jours de repos entre';

  @override
  String get rest => 'Repos';

  @override
  String get filterMuscle => 'Muscle';

  @override
  String get filterEquipment => 'Équipement';

  @override
  String get filterDifficulty => 'Difficulté';

  @override
  String readyInHoursMuscle(int hours, String muscle) {
    return 'Prêt dans ${hours}h ($muscle en récupération)';
  }

  @override
  String get noExercisesFound =>
      'Aucun exercice trouvé pour cette combinaison, Bro !';

  @override
  String get exercisesOfflineCached =>
      'Hors ligne — affichage de tes exercices enregistrés.';

  @override
  String get allMuscles => 'Tous les muscles';

  @override
  String get allEquipment => 'Tout l\'équipement';

  @override
  String get allDifficulties => 'Tous les niveaux';

  @override
  String get exerciseSearchHint => 'Que cherchez-vous ?';

  @override
  String get account => 'Compte';

  @override
  String get following => 'Abonnements';

  @override
  String get followers => 'Abonnés';

  @override
  String get follow => 'Suivre';

  @override
  String get friends => 'Amis';

  @override
  String get streak => 'Série';

  @override
  String get widgetStreakStart => 'Démarrer une série';

  @override
  String get widgetStreakOneDay => 'Série de 1 jour';

  @override
  String widgetStreakDays(int days) {
    return 'Série de $days jours';
  }

  @override
  String get achievement => 'Succès';

  @override
  String get posts => 'Publications';

  @override
  String get lastSession => 'Dernière séance';

  @override
  String get noSessionsYet => 'Aucune séance pour l\'instant';

  @override
  String get noPostsYet => 'Aucune publication pour l\'instant';

  @override
  String get retry => 'Réessayer';

  @override
  String get leaderboard => 'Classement';

  @override
  String get muscleRecovery => 'Récupération musculaire';

  @override
  String get sore => 'Douloureux';

  @override
  String get tapMuscleToFocus =>
      'Touchez un muscle ci-dessous pour le mettre en évidence sur le corps';

  @override
  String get readyNow => 'Prêt maintenant';

  @override
  String get notTrainedYet => 'Pas encore entraîné';

  @override
  String get fullyRecovered => 'Complètement récupéré — prêt à s\'entraîner';

  @override
  String get lessThanOneHourRecovery =>
      'Moins d\'1 heure avant la récupération';

  @override
  String hoursRestNeeded(int hours) {
    return 'Encore ${hours}h de repos';
  }

  @override
  String daysRestNeeded(int days) {
    return 'Encore ${days}j de repos';
  }

  @override
  String daysHoursRestNeeded(int days, int hours) {
    return 'Encore ${days}j ${hours}h de repos';
  }

  @override
  String nSelected(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get failedToLoadExercises => 'Impossible de charger les exercices';

  @override
  String get tabSummary => 'Résumé';

  @override
  String get tabHistory => 'Historique';

  @override
  String get heaviestWeight => 'Poids le plus lourd';

  @override
  String get oneRepMax => '1RM';

  @override
  String get bestSetVolumeLabel => 'Meilleur volume par série';

  @override
  String get bestSessionVolumeLabel => 'Meilleur volume par séance';

  @override
  String get setRecords => 'Records de séries';

  @override
  String get last3Months => '3 derniers mois';

  @override
  String get last6Months => '6 derniers mois';

  @override
  String get allTime => 'Depuis le début';

  @override
  String get noHistoryYet => 'Aucun historique pour l\'instant';

  @override
  String get primaryLabel => 'Principal';

  @override
  String get secondaryLabel => 'Secondaire';

  @override
  String get removeExercise => 'Supprimer l\'exercice';

  @override
  String get discardWorkout => 'Abandonner cet entraînement ?';

  @override
  String get deleteSet => 'Supprimer la série';

  @override
  String get deleteSetConfirm => 'Supprimer cette série ?';

  @override
  String get setLabel => 'Série';

  @override
  String get selectSetType => 'Type de série';

  @override
  String get warmUpSet => 'Série d\'échauffement';

  @override
  String get normalSet => 'Série normale';

  @override
  String get failureSet => 'Série à l\'échec';

  @override
  String get dropSet => 'Série dégressive';

  @override
  String get removeSet => 'Supprimer la série';

  @override
  String get superSet => 'Superset';

  @override
  String get pressToDelete => 'Appuyer pour supprimer';

  @override
  String get time => 'Temps';

  @override
  String get finish => 'Terminer';

  @override
  String get discard => 'Abandonner';

  @override
  String get discardWorkoutConfirm =>
      'Abandonner cet entraînement ? Toute la progression sera perdue.';

  @override
  String get finishWorkoutConfirm =>
      'Terminer cet entraînement ? Il sera enregistré dans ton historique.';

  @override
  String get completeSet => 'Compléter la série';

  @override
  String get restTime => 'Temps de repos';

  @override
  String get remaining => 'Restant';

  @override
  String get restAfterSet => 'Tu dois te reposer\naprès cette série';

  @override
  String get unfinishedSets => 'Séries inachevées';

  @override
  String get unfinishedSetsMessage =>
      'Tu as des séries inachevées. Es-tu sûr de vouloir terminer cette séance ?';

  @override
  String get confirm => 'Confirmer';

  @override
  String get endSession => 'Terminer la séance';

  @override
  String get previousExercise => 'Précédent';

  @override
  String get nextExercise => 'Suivant';

  @override
  String get noInstructions => 'Aucune instruction disponible';

  @override
  String get deleteWorkout => 'Supprimer l\'entraînement';

  @override
  String get deleteWorkoutConfirm => 'Supprimer cet entraînement ?';

  @override
  String get leaderboardTab => 'Classement';

  @override
  String get challengesTab => 'Défis';

  @override
  String get currentLeague => 'LIGUE ACTUELLE';

  @override
  String get yourPlace => 'Ta place';

  @override
  String placeNumber(int n) {
    return '$n Place';
  }

  @override
  String get leagueElite => 'L\'Élite';

  @override
  String get leagueMaster => 'Le Maître';

  @override
  String get leagueStanding => 'Stable';

  @override
  String get leagueMovingUp => 'En progression';

  @override
  String get leagueWorkHarder => 'Pousse plus fort';

  @override
  String get scopeRivals => 'Rivaux';

  @override
  String get scopeGlobal => 'Global';

  @override
  String get scopeFriends => 'Amis';

  @override
  String get volumeLabel => 'Volume';

  @override
  String percentDone(int percent) {
    return '$percent% fait';
  }

  @override
  String rankNumber(int rank) {
    return 'Rang #$rank';
  }

  @override
  String get startChallenge => 'démarrer';

  @override
  String endInDays(int days) {
    return 'Finit dans ${days}j';
  }

  @override
  String get leagueMasterTitle => 'Maître';

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
  String get rankUnranked => 'Non classé';

  @override
  String get rankUpTitle => 'RANG SUPÉRIEUR !';

  @override
  String get rankUpCta => 'C\'est parti !';

  @override
  String get newPrTitle => 'NOUVEAU RECORD !';

  @override
  String rankNext(String rank) {
    return 'Prochain : $rank';
  }

  @override
  String get rankMax => 'Rang maximum atteint';

  @override
  String get rankShieldTooltip =>
      'Bouclier de relégation — ton rang est protégé pendant que tu remontes.';

  @override
  String get skinPremium => 'Premium';

  @override
  String get skinPremiumSoon => 'Skin premium — achats bientôt disponibles';

  @override
  String skinWorkoutsShort(int count) {
    return '$count séances';
  }

  @override
  String skinLockedProgress(int count) {
    return 'Se débloque à $count séances';
  }

  @override
  String get noChallengesYet => 'Aucun défi actif';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsSectionWorkout => 'Entraînement';

  @override
  String get settingsSectionGeneral => 'Général';

  @override
  String get settingsSectionData => 'Données et compte';

  @override
  String get skins => 'Skins';

  @override
  String get anatomyModel => 'Modèle anatomique';

  @override
  String get male => 'Homme';

  @override
  String get female => 'Femme';

  @override
  String get restTimerVibration => 'Vibration du minuteur de repos';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signOutConfirm =>
      'Se déconnecter de votre compte ? Vos données locales restent sur cet appareil.';

  @override
  String get cacheCleared => 'Cache vidé';

  @override
  String get cacheClearFailed => 'Impossible de vider le cache';

  @override
  String get couldNotOpenLink => 'Impossible d\'ouvrir le lien';

  @override
  String get exportPreparing => 'Préparation de votre export…';

  @override
  String get exportNothingYet =>
      'Rien à exporter pour le moment — enregistrez d\'abord une séance';

  @override
  String get exportFailed => 'Échec de l\'export. Veuillez réessayer.';

  @override
  String get deleteAccountFailed =>
      'Impossible de supprimer le compte. Veuillez réessayer.';

  @override
  String get planPremium => 'Premium';

  @override
  String get trainingReminderBody => 'Garde ta série. On va s\'entraîner.';

  @override
  String get languageSystem => 'Système';

  @override
  String get settingsWorkoutFooter =>
      'Valeurs par défaut pour les minuteurs de repos, le suivi et l\'estimation des calories.';

  @override
  String get settingsNotificationsFooter =>
      'Les rappels d\'entraînement protègent votre série.';

  @override
  String get settingsDataFooter =>
      'La suppression de votre compte efface définitivement vos données de nos serveurs.';

  @override
  String get duration => 'Durée';

  @override
  String get heatmapLess => 'Moins';

  @override
  String get heatmapMore => 'Plus';

  @override
  String get tapDayToJump => 'Touchez un jour pour ouvrir sa séance';

  @override
  String jumpedToDay(String date) {
    return 'Passé au $date';
  }

  @override
  String get shareNiceWork => 'Beau travail.';

  @override
  String get shareStyleDark => 'Sombre';

  @override
  String get shareStyleSticker => 'Sticker';

  @override
  String get shareTemplateEditorial => 'Éditorial';

  @override
  String get shareTemplateAnatomy => 'Anatomie';

  @override
  String get shareTemplateHype => 'Hype';

  @override
  String shareWorkoutNumber(int count) {
    return 'Séance n° $count';
  }

  @override
  String get shareTotalVolumeLifted => 'Volume total soulevé';

  @override
  String get shareOneSession => 'Une séance';

  @override
  String get shareYou => 'Toi';

  @override
  String shareHeavierThan(String object) {
    return 'Plus lourd qu\'$object.';
  }

  @override
  String get shareAnonymous => 'Anonyme';

  @override
  String get shareError => 'Impossible de créer l\'image. Réessaie.';

  @override
  String get shareSaved => 'Enregistré dans la galerie';

  @override
  String get shareSaveError => 'Impossible d\'enregistrer dans la galerie';

  @override
  String get shareVolumeCaption => 'Ça, c\'est de la fonte.';

  @override
  String get shareVolumeDog => 'un gros chien';

  @override
  String get shareVolumeFridge => 'un réfrigérateur';

  @override
  String get shareVolumePiano => 'un piano à queue';

  @override
  String get shareVolumeCar => 'une petite voiture';

  @override
  String get shareVolumeVan => 'une camionnette';

  @override
  String get shareVolumeElephant => 'un éléphant adulte';

  @override
  String get shareObjectDog => 'Chien';

  @override
  String get shareObjectFridge => 'Frigo';

  @override
  String get shareObjectPiano => 'Piano';

  @override
  String get shareObjectCar => 'Voiture';

  @override
  String get shareObjectVan => 'Camionnette';

  @override
  String get shareObjectElephant => 'Éléphant';

  @override
  String get close => 'Fermer';

  @override
  String get hint => 'Astuce';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get markSetComplete => 'Marquer la série comme terminée';

  @override
  String get markSetIncomplete => 'Marquer la série comme non terminée';

  @override
  String restTimerRemaining(String time) {
    return 'Minuteur de repos, $time restant';
  }

  @override
  String get plateCalculator => 'Calculateur de disques';

  @override
  String get plateCalcTargetWeight => 'Poids cible';

  @override
  String get plateCalcBar => 'Barre';

  @override
  String get plateCalcPerSide => 'par côté';

  @override
  String plateCalcUnreachable(String amount) {
    return 'Inatteignable à $amount près';
  }

  @override
  String get getStarted => 'Commencer';

  @override
  String get welcomeTagline => 'Créé par des Gym Bros, pour des Gym Bros';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get progressLabel => 'PROGRESSION';

  @override
  String get weightsKg => 'poids kg';

  @override
  String get day => 'Jour';

  @override
  String dayNumber(int number) {
    return 'Jour $number';
  }

  @override
  String get label => 'Libellé';

  @override
  String get dayLabel => 'Libellé du jour';

  @override
  String get dayLabelHint => 'ex. : Jour pectoraux';

  @override
  String get weightKg => 'Poids (kg)';

  @override
  String get deleteSchedule => 'Supprimer le plan';

  @override
  String get deleteScheduleConfirm =>
      'Voulez-vous vraiment supprimer ce plan ? Cette action est irréversible.';

  @override
  String get defaultProgramName => 'Programme 1';

  @override
  String get recentExercises => 'Exercices récents';

  @override
  String get allExercises => 'Tous les exercices';

  @override
  String allCategory(String category) {
    return 'Tout : $category';
  }

  @override
  String get other => 'Autres';

  @override
  String get equipmentNone => 'Aucun';

  @override
  String get barbell => 'Barre';

  @override
  String get dumbbell => 'Haltère';

  @override
  String get kettlebell => 'Kettlebell';

  @override
  String get machine => 'Machine';

  @override
  String get resistanceBand => 'Bande élastique';

  @override
  String get cardio => 'Cardio';

  @override
  String setsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
    );
    return '$_temp0';
  }
}
