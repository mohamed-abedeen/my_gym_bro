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
  String get sessionLog => 'Journal des séances';

  @override
  String get statusLog => 'Journal de statut';

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
  String get restTimer => 'Repos';

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
  String get allMuscles => 'Tous les muscles';

  @override
  String get allEquipment => 'Tout l\'équipement';

  @override
  String get allDifficulties => 'Tous les niveaux';
}
