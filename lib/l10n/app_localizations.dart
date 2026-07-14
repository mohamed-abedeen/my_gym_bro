import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'My Gym Bro'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get tabWorkout;

  /// No description provided for @tabLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get tabLog;

  /// No description provided for @tabCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get tabCommunity;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @dailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get dailyChallenge;

  /// No description provided for @competeFriends.
  ///
  /// In en, this message translates to:
  /// **'Compete with your Gym Bros'**
  String get competeFriends;

  /// No description provided for @startTrial.
  ///
  /// In en, this message translates to:
  /// **'Start 7-day free trial'**
  String get startTrial;

  /// No description provided for @createSchedule.
  ///
  /// In en, this message translates to:
  /// **'Create Schedule'**
  String get createSchedule;

  /// No description provided for @buildYourFlow.
  ///
  /// In en, this message translates to:
  /// **'Build your flow or find a pro program'**
  String get buildYourFlow;

  /// No description provided for @scheduleRemaining.
  ///
  /// In en, this message translates to:
  /// **'{hours}h remaining'**
  String scheduleRemaining(int hours);

  /// No description provided for @nextSession.
  ///
  /// In en, this message translates to:
  /// **'Next Session'**
  String get nextSession;

  /// No description provided for @sessionLog.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionLog;

  /// No description provided for @statusLog.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLog;

  /// No description provided for @weeklyProgress.
  ///
  /// In en, this message translates to:
  /// **'Weekly Progress'**
  String get weeklyProgress;

  /// No description provided for @recovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered'**
  String get recovered;

  /// No description provided for @recovering.
  ///
  /// In en, this message translates to:
  /// **'Recovering'**
  String get recovering;

  /// No description provided for @undertrained.
  ///
  /// In en, this message translates to:
  /// **'Undertrained'**
  String get undertrained;

  /// No description provided for @healingTitle.
  ///
  /// In en, this message translates to:
  /// **'Healing...'**
  String get healingTitle;

  /// No description provided for @healingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your body needs some rest'**
  String get healingSubtitle;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkout;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish Workout'**
  String get finishWorkout;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest Day'**
  String get restDay;

  /// No description provided for @calBurned.
  ///
  /// In en, this message translates to:
  /// **'Cal Burned'**
  String get calBurned;

  /// No description provided for @calBurnedLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Cal Burned last week'**
  String get calBurnedLastWeek;

  /// No description provided for @calBurnedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Cal Burned this week'**
  String get calBurnedThisWeek;

  /// No description provided for @weeklyReports.
  ///
  /// In en, this message translates to:
  /// **'Weekly Reports'**
  String get weeklyReports;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @weights.
  ///
  /// In en, this message translates to:
  /// **'Weights'**
  String get weights;

  /// No description provided for @calUnit.
  ///
  /// In en, this message translates to:
  /// **'Cal'**
  String get calUnit;

  /// No description provided for @minUnit.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minUnit;

  /// No description provided for @exercisePrefix.
  ///
  /// In en, this message translates to:
  /// **'Exe'**
  String get exercisePrefix;

  /// No description provided for @reportNoData.
  ///
  /// In en, this message translates to:
  /// **'No workout on this day'**
  String get reportNoData;

  /// No description provided for @statusKcalProgress.
  ///
  /// In en, this message translates to:
  /// **'{burned}/{goal} KCAL'**
  String statusKcalProgress(int burned, int goal);

  /// No description provided for @statusKcalNoGoal.
  ///
  /// In en, this message translates to:
  /// **'{burned} KCAL'**
  String statusKcalNoGoal(int burned);

  /// No description provided for @shoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get shoulders;

  /// No description provided for @chest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @achieved.
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get achieved;

  /// No description provided for @statusLiftedTotal.
  ///
  /// In en, this message translates to:
  /// **'You\'ve lifted {amount} since day one!'**
  String statusLiftedTotal(String amount);

  /// No description provided for @statusVolumeIncrease.
  ///
  /// In en, this message translates to:
  /// **'Your lifted weight increased by {pct}% since day one!'**
  String statusVolumeIncrease(int pct);

  /// No description provided for @statusRepsTotal.
  ///
  /// In en, this message translates to:
  /// **'You\'ve done {reps} reps since day one!'**
  String statusRepsTotal(String reps);

  /// No description provided for @statusCaloriesBurnedTotal.
  ///
  /// In en, this message translates to:
  /// **'You\'ve burned over {kcal} calories!'**
  String statusCaloriesBurnedTotal(String kcal);

  /// No description provided for @statusCaloriesBodyFat.
  ///
  /// In en, this message translates to:
  /// **'You\'ve burned over {kcal} calories and dropped {pct}% body fat!'**
  String statusCaloriesBodyFat(String kcal, String pct);

  /// No description provided for @calorieGoal.
  ///
  /// In en, this message translates to:
  /// **'Calorie Goal'**
  String get calorieGoal;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body Fat'**
  String get bodyFat;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total Duration'**
  String get totalDuration;

  /// No description provided for @avgStrength.
  ///
  /// In en, this message translates to:
  /// **'Avg Strength'**
  String get avgStrength;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @totalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total Volume'**
  String get totalVolume;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get totalTime;

  /// No description provided for @howTo.
  ///
  /// In en, this message translates to:
  /// **'How to'**
  String get howTo;

  /// No description provided for @targetMuscles.
  ///
  /// In en, this message translates to:
  /// **'Target Muscles'**
  String get targetMuscles;

  /// No description provided for @secondaryMuscles.
  ///
  /// In en, this message translates to:
  /// **'Secondary Muscles'**
  String get secondaryMuscles;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @searchExercises.
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercises;

  /// No description provided for @noRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noRecordsYet;

  /// No description provided for @yourRecords.
  ///
  /// In en, this message translates to:
  /// **'Your Records'**
  String get yourRecords;

  /// No description provided for @bestSet.
  ///
  /// In en, this message translates to:
  /// **'Best: {weight}kg × {reps} reps'**
  String bestSet(double weight, int reps);

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get addSet;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add Exercise'**
  String get addExercise;

  /// No description provided for @editExercises.
  ///
  /// In en, this message translates to:
  /// **'Edit Exercises'**
  String get editExercises;

  /// No description provided for @addDay.
  ///
  /// In en, this message translates to:
  /// **'Add Days'**
  String get addDay;

  /// No description provided for @scheduleName.
  ///
  /// In en, this message translates to:
  /// **'Schedule Name'**
  String get scheduleName;

  /// No description provided for @todaySession.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Session'**
  String get todaySession;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get lastWeek;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @cancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime. No charge during 7-day trial.'**
  String get cancelAnytime;

  /// No description provided for @restoreSubscription.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restoreSubscription;

  /// No description provided for @monthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyPlan;

  /// No description provided for @yearlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearlyPlan;

  /// No description provided for @bestValue.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get bestValue;

  /// No description provided for @trialBadge.
  ///
  /// In en, this message translates to:
  /// **'7-day free trial'**
  String get trialBadge;

  /// No description provided for @subscribeToContinue.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to continue'**
  String get subscribeToContinue;

  /// No description provided for @autoRenewDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Subscription auto-renews at the price and period shown unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store or Google Play account settings.'**
  String get autoRenewDisclosure;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get purchaseFailed;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore purchases. Please try again.'**
  String get restoreFailed;

  /// No description provided for @noOfferingsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No offerings available. Try again later.'**
  String get noOfferingsAvailable;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUp;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @alreadyAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get alreadyAccount;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @chooseGoal.
  ///
  /// In en, this message translates to:
  /// **'What\'s your goal?'**
  String get chooseGoal;

  /// No description provided for @buildMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build Muscle'**
  String get buildMuscle;

  /// No description provided for @loseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose Weight'**
  String get loseWeight;

  /// No description provided for @getStronger.
  ///
  /// In en, this message translates to:
  /// **'Get Stronger'**
  String get getStronger;

  /// No description provided for @chooseExperience.
  ///
  /// In en, this message translates to:
  /// **'Your experience level?'**
  String get chooseExperience;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go'**
  String get letsGo;

  /// No description provided for @trialStarted.
  ///
  /// In en, this message translates to:
  /// **'Your 7-day free trial starts now'**
  String get trialStarted;

  /// No description provided for @securityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarningTitle;

  /// No description provided for @securityWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This device appears compromised. My Gym Bro cannot run securely.'**
  String get securityWarningBody;

  /// No description provided for @closeApp.
  ///
  /// In en, this message translates to:
  /// **'Close App'**
  String get closeApp;

  /// No description provided for @biometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock My Gym Bro'**
  String get biometricPrompt;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'Weight Unit'**
  String get weightUnit;

  /// No description provided for @bodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Body Weight'**
  String get bodyWeight;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric Lock'**
  String get biometricLock;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportData;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Community Cache'**
  String get clearCache;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your data. This cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteAccountButton;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String lastSynced(String time);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate the App'**
  String get rateApp;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get syncError;

  /// No description provided for @loadingExercises.
  ///
  /// In en, this message translates to:
  /// **'Loading exercise library...'**
  String get loadingExercises;

  /// No description provided for @whatOnYourMind.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get whatOnYourMind;

  /// No description provided for @communityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Be the first to share!'**
  String get communityEmpty;

  /// No description provided for @communityError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the feed. Pull down to retry.'**
  String get communityError;

  /// No description provided for @postFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t publish your post. Try again.'**
  String get postFailed;

  /// No description provided for @backAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Swipe back again to exit'**
  String get backAgainToExit;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @noScheduleYet.
  ///
  /// In en, this message translates to:
  /// **'No schedule yet'**
  String get noScheduleYet;

  /// No description provided for @activeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Active — renews {date}'**
  String activeSubscription(String date);

  /// No description provided for @trialDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String trialDaysLeft(int days);

  /// No description provided for @subscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'Subscription expired'**
  String get subscriptionExpired;

  /// No description provided for @restComplete.
  ///
  /// In en, this message translates to:
  /// **'Rest complete!'**
  String get restComplete;

  /// No description provided for @restCompleteTitleSupportive.
  ///
  /// In en, this message translates to:
  /// **'Rest complete'**
  String get restCompleteTitleSupportive;

  /// No description provided for @restCompleteBodySupportive.
  ///
  /// In en, this message translates to:
  /// **'Your muscles are ready whenever you are.'**
  String get restCompleteBodySupportive;

  /// No description provided for @restCompleteTitleBalanced.
  ///
  /// In en, this message translates to:
  /// **'Rest complete'**
  String get restCompleteTitleBalanced;

  /// No description provided for @restCompleteBodyBalanced.
  ///
  /// In en, this message translates to:
  /// **'Time to start your next set.'**
  String get restCompleteBodyBalanced;

  /// No description provided for @restCompleteTitleBold.
  ///
  /// In en, this message translates to:
  /// **'Rest complete'**
  String get restCompleteTitleBold;

  /// No description provided for @restCompleteBodyBold.
  ///
  /// In en, this message translates to:
  /// **'Get back in. Next set.'**
  String get restCompleteBodyBold;

  /// No description provided for @restCompleteTitleSavage.
  ///
  /// In en, this message translates to:
  /// **'REST OVER'**
  String get restCompleteTitleSavage;

  /// No description provided for @restCompleteBodySavage.
  ///
  /// In en, this message translates to:
  /// **'NEXT SET. NOW.'**
  String get restCompleteBodySavage;

  /// No description provided for @notificationTone.
  ///
  /// In en, this message translates to:
  /// **'Notification tone'**
  String get notificationTone;

  /// No description provided for @notificationToneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick how your reminders sound'**
  String get notificationToneSubtitle;

  /// No description provided for @toneSupportive.
  ///
  /// In en, this message translates to:
  /// **'Supportive'**
  String get toneSupportive;

  /// No description provided for @toneSupportiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Gentle, permission-giving reminders.'**
  String get toneSupportiveDescription;

  /// No description provided for @toneBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get toneBalanced;

  /// No description provided for @toneBalancedDescription.
  ///
  /// In en, this message translates to:
  /// **'Neutral, factual reminders.'**
  String get toneBalancedDescription;

  /// No description provided for @toneBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get toneBold;

  /// No description provided for @toneBoldDescription.
  ///
  /// In en, this message translates to:
  /// **'Direct, confident reminders.'**
  String get toneBoldDescription;

  /// No description provided for @toneSavage.
  ///
  /// In en, this message translates to:
  /// **'Savage'**
  String get toneSavage;

  /// No description provided for @toneSavageDescription.
  ///
  /// In en, this message translates to:
  /// **'All caps, no-excuses reminders.'**
  String get toneSavageDescription;

  /// No description provided for @notificationToneOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your voice'**
  String get notificationToneOnboardingTitle;

  /// No description provided for @notificationToneOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How should we talk to you during workouts?'**
  String get notificationToneOnboardingSubtitle;

  /// No description provided for @notificationToneExampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get notificationToneExampleLabel;

  /// No description provided for @restTimer.
  ///
  /// In en, this message translates to:
  /// **'Rest Timer'**
  String get restTimer;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @reorderExercises.
  ///
  /// In en, this message translates to:
  /// **'Reorder Exercises'**
  String get reorderExercises;

  /// No description provided for @replaceExercise.
  ///
  /// In en, this message translates to:
  /// **'Replace Exercise'**
  String get replaceExercise;

  /// No description provided for @defaultRestTime.
  ///
  /// In en, this message translates to:
  /// **'Default rest time'**
  String get defaultRestTime;

  /// No description provided for @restTimerSound.
  ///
  /// In en, this message translates to:
  /// **'Rest timer sound'**
  String get restTimerSound;

  /// No description provided for @trainingReminders.
  ///
  /// In en, this message translates to:
  /// **'Training reminders'**
  String get trainingReminders;

  /// No description provided for @communityNotifications.
  ///
  /// In en, this message translates to:
  /// **'Community challenges'**
  String get communityNotifications;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @notificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSection;

  /// No description provided for @skipRest.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipRest;

  /// No description provided for @addSeconds.
  ///
  /// In en, this message translates to:
  /// **'+{n}s'**
  String addSeconds(int n);

  /// No description provided for @subtractSeconds.
  ///
  /// In en, this message translates to:
  /// **'-{n}s'**
  String subtractSeconds(int n);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @bodyStatus.
  ///
  /// In en, this message translates to:
  /// **'Body Status'**
  String get bodyStatus;

  /// No description provided for @workoutStatus.
  ///
  /// In en, this message translates to:
  /// **'Workout Status'**
  String get workoutStatus;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @weeklyStreak.
  ///
  /// In en, this message translates to:
  /// **'Weekly Streak'**
  String get weeklyStreak;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rankings yet. Finish a workout to enter this week\'s board.'**
  String get leaderboardEmpty;

  /// No description provided for @setsThisWeekCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set this week} other{{count} sets this week}}'**
  String setsThisWeekCount(int count);

  /// No description provided for @weeksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String weeksCount(int count);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Train smarter. Get stronger.'**
  String get welcomeTitle;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailInvalid;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Min 8 chars, 1 uppercase, 1 number, 1 special'**
  String get passwordRequirements;

  /// No description provided for @trialFeature1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited workout tracking'**
  String get trialFeature1;

  /// No description provided for @trialFeature2.
  ///
  /// In en, this message translates to:
  /// **'1300+ exercise library'**
  String get trialFeature2;

  /// No description provided for @trialFeature3.
  ///
  /// In en, this message translates to:
  /// **'Custom training schedules'**
  String get trialFeature3;

  /// No description provided for @trialFeature4.
  ///
  /// In en, this message translates to:
  /// **'Progress analytics & records'**
  String get trialFeature4;

  /// No description provided for @resetPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get resetPasswordSent;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @signUpError.
  ///
  /// In en, this message translates to:
  /// **'Could not create account. Please try again.'**
  String get signUpError;

  /// No description provided for @signInError.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get signInError;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your main goal\nfor training ?'**
  String get goalTitle;

  /// No description provided for @bulking.
  ///
  /// In en, this message translates to:
  /// **'Bulking'**
  String get bulking;

  /// No description provided for @bulkingDesc.
  ///
  /// In en, this message translates to:
  /// **'Focus on building muscle mass and size.'**
  String get bulkingDesc;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @strengthDesc.
  ///
  /// In en, this message translates to:
  /// **'To lift heavier load and get stronger.'**
  String get strengthDesc;

  /// No description provided for @cutting.
  ///
  /// In en, this message translates to:
  /// **'Cutting'**
  String get cutting;

  /// No description provided for @cuttingDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce body fat while keeping muscle.'**
  String get cuttingDesc;

  /// No description provided for @maintaining.
  ///
  /// In en, this message translates to:
  /// **'Maintaining'**
  String get maintaining;

  /// No description provided for @maintainingDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep your current muscle and fitness.'**
  String get maintainingDesc;

  /// No description provided for @dataPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your data is private and secure.'**
  String get dataPrivate;

  /// No description provided for @experienceTitle.
  ///
  /// In en, this message translates to:
  /// **'How much training\nexperience do you have ?'**
  String get experienceTitle;

  /// No description provided for @base.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get base;

  /// No description provided for @baseYears.
  ///
  /// In en, this message translates to:
  /// **'0-1 years'**
  String get baseYears;

  /// No description provided for @mid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get mid;

  /// No description provided for @midYears.
  ///
  /// In en, this message translates to:
  /// **'1-3 years'**
  String get midYears;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @proYears.
  ///
  /// In en, this message translates to:
  /// **'3+ years'**
  String get proYears;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select Your Gender'**
  String get selectGender;

  /// No description provided for @genderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us personalize your\ntraining plan.'**
  String get genderSubtitle;

  /// No description provided for @birthdayTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your birthday?'**
  String get birthdayTitle;

  /// No description provided for @weightTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your weight?'**
  String get weightTitle;

  /// No description provided for @heightTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your height?'**
  String get heightTitle;

  /// No description provided for @targetZonesTitle.
  ///
  /// In en, this message translates to:
  /// **'What are your target\nzones?'**
  String get targetZonesTitle;

  /// No description provided for @arms.
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get arms;

  /// No description provided for @abs.
  ///
  /// In en, this message translates to:
  /// **'Abs'**
  String get abs;

  /// No description provided for @pecs.
  ///
  /// In en, this message translates to:
  /// **'Pecs'**
  String get pecs;

  /// No description provided for @targetBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get targetBack;

  /// No description provided for @legs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get legs;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @kgs.
  ///
  /// In en, this message translates to:
  /// **'kgs'**
  String get kgs;

  /// No description provided for @lbs.
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get lbs;

  /// No description provided for @cm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get cm;

  /// No description provided for @ft.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get ft;

  /// No description provided for @freeTrial.
  ///
  /// In en, this message translates to:
  /// **'Free Trial'**
  String get freeTrial;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @dmMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get dmMessages;

  /// No description provided for @dmSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get dmSearch;

  /// No description provided for @dmNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get dmNoMessagesYet;

  /// No description provided for @dmStartChatting.
  ///
  /// In en, this message translates to:
  /// **'Start chatting with your Gym Bros!'**
  String get dmStartChatting;

  /// No description provided for @dmNewConversationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'New conversation not supported in v1'**
  String get dmNewConversationUnavailable;

  /// No description provided for @dmStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start your conversation\nwith {name}'**
  String dmStartConversation(String name);

  /// No description provided for @dmMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get dmMessageHint;

  /// No description provided for @dmSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message failed to send. Please try again.'**
  String get dmSendFailed;

  /// No description provided for @dmSavedToSchedules.
  ///
  /// In en, this message translates to:
  /// **'Saved to your schedules!'**
  String get dmSavedToSchedules;

  /// No description provided for @dmCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get dmCamera;

  /// No description provided for @dmGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get dmGallery;

  /// No description provided for @dmSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get dmSchedule;

  /// No description provided for @dmShareSchedule.
  ///
  /// In en, this message translates to:
  /// **'Share Schedule'**
  String get dmShareSchedule;

  /// No description provided for @dmNoSchedulesToShare.
  ///
  /// In en, this message translates to:
  /// **'No schedules to share'**
  String get dmNoSchedulesToShare;

  /// No description provided for @dmSharedSchedule.
  ///
  /// In en, this message translates to:
  /// **'Shared Schedule'**
  String get dmSharedSchedule;

  /// No description provided for @dmInvalidSchedule.
  ///
  /// In en, this message translates to:
  /// **'Invalid schedule data'**
  String get dmInvalidSchedule;

  /// No description provided for @dmSaveToMySchedules.
  ///
  /// In en, this message translates to:
  /// **'Save to my schedules'**
  String get dmSaveToMySchedules;

  /// No description provided for @dmUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get dmUploading;

  /// No description provided for @dmSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Sent a message'**
  String get dmSentMessage;

  /// No description provided for @dmImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image exceeds 10 MB limit.'**
  String get dmImageTooLarge;

  /// No description provided for @dmDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String dmDaysCount(int count);

  /// No description provided for @dmWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get dmWorkout;

  /// No description provided for @addDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Day'**
  String get addDayTitle;

  /// No description provided for @oneStepCloserBro.
  ///
  /// In en, this message translates to:
  /// **'One step closer bro'**
  String get oneStepCloserBro;

  /// No description provided for @newProgram.
  ///
  /// In en, this message translates to:
  /// **'New Program'**
  String get newProgram;

  /// No description provided for @nextSessionAfter.
  ///
  /// In en, this message translates to:
  /// **'Next session after {hours}h'**
  String nextSessionAfter(int hours);

  /// No description provided for @readyToTrain.
  ///
  /// In en, this message translates to:
  /// **'Ready to train, Bro!'**
  String get readyToTrain;

  /// No description provided for @restDaysBetween.
  ///
  /// In en, this message translates to:
  /// **'Rest Days Between'**
  String get restDaysBetween;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get rest;

  /// No description provided for @filterMuscle.
  ///
  /// In en, this message translates to:
  /// **'Muscle'**
  String get filterMuscle;

  /// No description provided for @filterEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get filterEquipment;

  /// No description provided for @filterDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get filterDifficulty;

  /// No description provided for @readyInHoursMuscle.
  ///
  /// In en, this message translates to:
  /// **'Ready in {hours}h ({muscle} recovering)'**
  String readyInHoursMuscle(int hours, String muscle);

  /// No description provided for @noExercisesFound.
  ///
  /// In en, this message translates to:
  /// **'No exercises found for this combination, Bro!'**
  String get noExercisesFound;

  /// No description provided for @exercisesOfflineCached.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing your saved exercises.'**
  String get exercisesOfflineCached;

  /// No description provided for @allMuscles.
  ///
  /// In en, this message translates to:
  /// **'All Muscles'**
  String get allMuscles;

  /// No description provided for @allEquipment.
  ///
  /// In en, this message translates to:
  /// **'All Equipment'**
  String get allEquipment;

  /// No description provided for @allDifficulties.
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get allDifficulties;

  /// No description provided for @exerciseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for ?'**
  String get exerciseSearchHint;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @widgetStreakStart.
  ///
  /// In en, this message translates to:
  /// **'Start a streak'**
  String get widgetStreakStart;

  /// No description provided for @widgetStreakOneDay.
  ///
  /// In en, this message translates to:
  /// **'1-day streak'**
  String get widgetStreakOneDay;

  /// No description provided for @widgetStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String widgetStreakDays(int days);

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @lastSession.
  ///
  /// In en, this message translates to:
  /// **'Last Session'**
  String get lastSession;

  /// No description provided for @noSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @muscleRecovery.
  ///
  /// In en, this message translates to:
  /// **'Muscle Recovery'**
  String get muscleRecovery;

  /// No description provided for @sore.
  ///
  /// In en, this message translates to:
  /// **'Sore'**
  String get sore;

  /// No description provided for @tapMuscleToFocus.
  ///
  /// In en, this message translates to:
  /// **'Tap a muscle below to focus it on the body'**
  String get tapMuscleToFocus;

  /// No description provided for @readyNow.
  ///
  /// In en, this message translates to:
  /// **'Ready now'**
  String get readyNow;

  /// No description provided for @notTrainedYet.
  ///
  /// In en, this message translates to:
  /// **'Not trained yet'**
  String get notTrainedYet;

  /// No description provided for @fullyRecovered.
  ///
  /// In en, this message translates to:
  /// **'Fully recovered — ready to train'**
  String get fullyRecovered;

  /// No description provided for @lessThanOneHourRecovery.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 hour to full recovery'**
  String get lessThanOneHourRecovery;

  /// No description provided for @hoursRestNeeded.
  ///
  /// In en, this message translates to:
  /// **'{hours}h more rest needed'**
  String hoursRestNeeded(int hours);

  /// No description provided for @daysRestNeeded.
  ///
  /// In en, this message translates to:
  /// **'{days}d more rest needed'**
  String daysRestNeeded(int days);

  /// No description provided for @daysHoursRestNeeded.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h more rest needed'**
  String daysHoursRestNeeded(int days, int hours);

  /// No description provided for @nSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String nSelected(int count);

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @failedToLoadExercises.
  ///
  /// In en, this message translates to:
  /// **'Failed to load exercises'**
  String get failedToLoadExercises;

  /// No description provided for @tabSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get tabSummary;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @heaviestWeight.
  ///
  /// In en, this message translates to:
  /// **'Heaviest Weight'**
  String get heaviestWeight;

  /// No description provided for @oneRepMax.
  ///
  /// In en, this message translates to:
  /// **'One Rep Max'**
  String get oneRepMax;

  /// No description provided for @bestSetVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Best Set Volume'**
  String get bestSetVolumeLabel;

  /// No description provided for @bestSessionVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Best Session Volume'**
  String get bestSessionVolumeLabel;

  /// No description provided for @setRecords.
  ///
  /// In en, this message translates to:
  /// **'Set Records'**
  String get setRecords;

  /// No description provided for @last3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 Months'**
  String get last3Months;

  /// No description provided for @last6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 Months'**
  String get last6Months;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYet;

  /// No description provided for @primaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryLabel;

  /// No description provided for @secondaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get secondaryLabel;

  /// No description provided for @removeExercise.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get removeExercise;

  /// No description provided for @discardWorkout.
  ///
  /// In en, this message translates to:
  /// **'Discard this workout?'**
  String get discardWorkout;

  /// No description provided for @deleteSet.
  ///
  /// In en, this message translates to:
  /// **'Delete Set'**
  String get deleteSet;

  /// No description provided for @deleteSetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this set?'**
  String get deleteSetConfirm;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setLabel;

  /// No description provided for @selectSetType.
  ///
  /// In en, this message translates to:
  /// **'Select Set Type'**
  String get selectSetType;

  /// No description provided for @warmUpSet.
  ///
  /// In en, this message translates to:
  /// **'Warm Up Set'**
  String get warmUpSet;

  /// No description provided for @normalSet.
  ///
  /// In en, this message translates to:
  /// **'Normal Set'**
  String get normalSet;

  /// No description provided for @failureSet.
  ///
  /// In en, this message translates to:
  /// **'Failure Set'**
  String get failureSet;

  /// No description provided for @dropSet.
  ///
  /// In en, this message translates to:
  /// **'Drop Set'**
  String get dropSet;

  /// No description provided for @removeSet.
  ///
  /// In en, this message translates to:
  /// **'Remove Set'**
  String get removeSet;

  /// No description provided for @superSet.
  ///
  /// In en, this message translates to:
  /// **'Super Set'**
  String get superSet;

  /// No description provided for @pressToDelete.
  ///
  /// In en, this message translates to:
  /// **'Press To Delete'**
  String get pressToDelete;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardWorkoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard this workout? All progress will be lost.'**
  String get discardWorkoutConfirm;

  /// No description provided for @finishWorkoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Finish this workout? It\'ll be saved to your history.'**
  String get finishWorkoutConfirm;

  /// No description provided for @completeSet.
  ///
  /// In en, this message translates to:
  /// **'Complete set'**
  String get completeSet;

  /// No description provided for @restTime.
  ///
  /// In en, this message translates to:
  /// **'Rest time'**
  String get restTime;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @restAfterSet.
  ///
  /// In en, this message translates to:
  /// **'You must rest after\nthis set'**
  String get restAfterSet;

  /// No description provided for @unfinishedSets.
  ///
  /// In en, this message translates to:
  /// **'Unfinished Sets'**
  String get unfinishedSets;

  /// No description provided for @unfinishedSetsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unfinished sets. Are you sure you want to end this session?'**
  String get unfinishedSetsMessage;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @endSession.
  ///
  /// In en, this message translates to:
  /// **'End Session'**
  String get endSession;

  /// No description provided for @previousExercise.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousExercise;

  /// No description provided for @nextExercise.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextExercise;

  /// No description provided for @noInstructions.
  ///
  /// In en, this message translates to:
  /// **'No instructions available'**
  String get noInstructions;

  /// No description provided for @deleteWorkout.
  ///
  /// In en, this message translates to:
  /// **'Delete Workout'**
  String get deleteWorkout;

  /// No description provided for @deleteWorkoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this workout?'**
  String get deleteWorkoutConfirm;

  /// No description provided for @leaderboardTab.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTab;

  /// No description provided for @challengesTab.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challengesTab;

  /// No description provided for @currentLeague.
  ///
  /// In en, this message translates to:
  /// **'CURRENT LEAGUE'**
  String get currentLeague;

  /// No description provided for @yourPlace.
  ///
  /// In en, this message translates to:
  /// **'Your place'**
  String get yourPlace;

  /// No description provided for @placeNumber.
  ///
  /// In en, this message translates to:
  /// **'{n} Place'**
  String placeNumber(int n);

  /// No description provided for @leagueElite.
  ///
  /// In en, this message translates to:
  /// **'The Elite'**
  String get leagueElite;

  /// No description provided for @leagueMaster.
  ///
  /// In en, this message translates to:
  /// **'The Master'**
  String get leagueMaster;

  /// No description provided for @leagueStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get leagueStanding;

  /// No description provided for @leagueMovingUp.
  ///
  /// In en, this message translates to:
  /// **'Moving up'**
  String get leagueMovingUp;

  /// No description provided for @leagueWorkHarder.
  ///
  /// In en, this message translates to:
  /// **'Work harder'**
  String get leagueWorkHarder;

  /// No description provided for @scopeRivals.
  ///
  /// In en, this message translates to:
  /// **'Rivals'**
  String get scopeRivals;

  /// No description provided for @scopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get scopeGlobal;

  /// No description provided for @scopeFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get scopeFriends;

  /// No description provided for @volumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volumeLabel;

  /// No description provided for @leagueMasterTitle.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get leagueMasterTitle;

  /// No description provided for @rankBronze.
  ///
  /// In en, this message translates to:
  /// **'Grinder'**
  String get rankBronze;

  /// No description provided for @rankSilver.
  ///
  /// In en, this message translates to:
  /// **'Warrior'**
  String get rankSilver;

  /// No description provided for @rankGold.
  ///
  /// In en, this message translates to:
  /// **'Beast'**
  String get rankGold;

  /// No description provided for @rankPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Titan'**
  String get rankPlatinum;

  /// No description provided for @rankElite.
  ///
  /// In en, this message translates to:
  /// **'Apex'**
  String get rankElite;

  /// No description provided for @rankUnranked.
  ///
  /// In en, this message translates to:
  /// **'Unranked'**
  String get rankUnranked;

  /// No description provided for @rankUpTitle.
  ///
  /// In en, this message translates to:
  /// **'RANK UP!'**
  String get rankUpTitle;

  /// No description provided for @rankUpCta.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get rankUpCta;

  /// No description provided for @newPrTitle.
  ///
  /// In en, this message translates to:
  /// **'NEW PR!'**
  String get newPrTitle;

  /// No description provided for @rankNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {rank}'**
  String rankNext(String rank);

  /// No description provided for @rankMax.
  ///
  /// In en, this message translates to:
  /// **'Max rank reached'**
  String get rankMax;

  /// No description provided for @rankShieldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Demotion shield — your rank is protected while you climb back.'**
  String get rankShieldTooltip;

  /// No description provided for @skinPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get skinPremium;

  /// No description provided for @skinPremiumSoon.
  ///
  /// In en, this message translates to:
  /// **'Premium skin — purchases coming soon'**
  String get skinPremiumSoon;

  /// No description provided for @skinWorkoutsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts'**
  String skinWorkoutsShort(int count);

  /// No description provided for @skinLockedProgress.
  ///
  /// In en, this message translates to:
  /// **'Unlocks at {count} workouts'**
  String skinLockedProgress(int count);

  /// No description provided for @noChallengesYet.
  ///
  /// In en, this message translates to:
  /// **'No active challenges yet'**
  String get noChallengesYet;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get settingsSectionWorkout;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data & Account'**
  String get settingsSectionData;

  /// No description provided for @skins.
  ///
  /// In en, this message translates to:
  /// **'Skins'**
  String get skins;

  /// No description provided for @anatomyModel.
  ///
  /// In en, this message translates to:
  /// **'Anatomy Model'**
  String get anatomyModel;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @restTimerVibration.
  ///
  /// In en, this message translates to:
  /// **'Rest timer vibration'**
  String get restTimerVibration;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of your account? Your local data stays on this device.'**
  String get signOutConfirm;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @cacheClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cache'**
  String get cacheClearFailed;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get couldNotOpenLink;

  /// No description provided for @exportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your export…'**
  String get exportPreparing;

  /// No description provided for @exportNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export yet — log a workout first'**
  String get exportNothingYet;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get exportFailed;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @planPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planPremium;

  /// No description provided for @trainingReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your streak going. Let\'s train.'**
  String get trainingReminderBody;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @settingsWorkoutFooter.
  ///
  /// In en, this message translates to:
  /// **'Defaults for rest timers, logging, and calorie estimates.'**
  String get settingsWorkoutFooter;

  /// No description provided for @settingsNotificationsFooter.
  ///
  /// In en, this message translates to:
  /// **'Training reminders help protect your streak.'**
  String get settingsNotificationsFooter;

  /// No description provided for @settingsDataFooter.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account permanently removes your data from our servers.'**
  String get settingsDataFooter;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @heatmapLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get heatmapLess;

  /// No description provided for @heatmapMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get heatmapMore;

  /// No description provided for @tapDayToJump.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to jump to its session'**
  String get tapDayToJump;

  /// No description provided for @jumpedToDay.
  ///
  /// In en, this message translates to:
  /// **'Jumped to {date}'**
  String jumpedToDay(String date);

  /// No description provided for @shareNiceWork.
  ///
  /// In en, this message translates to:
  /// **'Nice work.'**
  String get shareNiceWork;

  /// No description provided for @shareStyleDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get shareStyleDark;

  /// No description provided for @shareStyleSticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get shareStyleSticker;

  /// No description provided for @shareTemplateEditorial.
  ///
  /// In en, this message translates to:
  /// **'Editorial'**
  String get shareTemplateEditorial;

  /// No description provided for @shareTemplateAnatomy.
  ///
  /// In en, this message translates to:
  /// **'Anatomy'**
  String get shareTemplateAnatomy;

  /// No description provided for @shareTemplateHype.
  ///
  /// In en, this message translates to:
  /// **'Hype'**
  String get shareTemplateHype;

  /// No description provided for @shareWorkoutNumber.
  ///
  /// In en, this message translates to:
  /// **'Workout #{count}'**
  String shareWorkoutNumber(int count);

  /// No description provided for @shareTotalVolumeLifted.
  ///
  /// In en, this message translates to:
  /// **'Total volume lifted'**
  String get shareTotalVolumeLifted;

  /// No description provided for @shareOneSession.
  ///
  /// In en, this message translates to:
  /// **'One session'**
  String get shareOneSession;

  /// No description provided for @shareYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get shareYou;

  /// Hype-card headline; {object} is one of the shareVolume* phrases, e.g. 'a full-grown elephant'.
  ///
  /// In en, this message translates to:
  /// **'Heavier than {object}.'**
  String shareHeavierThan(String object);

  /// No description provided for @shareAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get shareAnonymous;

  /// No description provided for @shareError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the image. Try again.'**
  String get shareError;

  /// No description provided for @shareSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get shareSaved;

  /// No description provided for @shareSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save to gallery'**
  String get shareSaveError;

  /// No description provided for @shareVolumeCaption.
  ///
  /// In en, this message translates to:
  /// **'That\'s some serious iron.'**
  String get shareVolumeCaption;

  /// No description provided for @shareVolumeDog.
  ///
  /// In en, this message translates to:
  /// **'a big friendly dog'**
  String get shareVolumeDog;

  /// No description provided for @shareVolumeFridge.
  ///
  /// In en, this message translates to:
  /// **'a full-size fridge'**
  String get shareVolumeFridge;

  /// No description provided for @shareVolumePiano.
  ///
  /// In en, this message translates to:
  /// **'a grand piano'**
  String get shareVolumePiano;

  /// No description provided for @shareVolumeCar.
  ///
  /// In en, this message translates to:
  /// **'a small car'**
  String get shareVolumeCar;

  /// No description provided for @shareVolumeVan.
  ///
  /// In en, this message translates to:
  /// **'a delivery van'**
  String get shareVolumeVan;

  /// No description provided for @shareVolumeElephant.
  ///
  /// In en, this message translates to:
  /// **'a full-grown elephant'**
  String get shareVolumeElephant;

  /// No description provided for @shareObjectDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get shareObjectDog;

  /// No description provided for @shareObjectFridge.
  ///
  /// In en, this message translates to:
  /// **'Fridge'**
  String get shareObjectFridge;

  /// No description provided for @shareObjectPiano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get shareObjectPiano;

  /// No description provided for @shareObjectCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get shareObjectCar;

  /// No description provided for @shareObjectVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get shareObjectVan;

  /// No description provided for @shareObjectElephant.
  ///
  /// In en, this message translates to:
  /// **'Elephant'**
  String get shareObjectElephant;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @hint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @markSetComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark set complete'**
  String get markSetComplete;

  /// No description provided for @markSetIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark set incomplete'**
  String get markSetIncomplete;

  /// No description provided for @restTimerRemaining.
  ///
  /// In en, this message translates to:
  /// **'Rest timer, {time} remaining'**
  String restTimerRemaining(String time);

  /// No description provided for @plateCalculator.
  ///
  /// In en, this message translates to:
  /// **'Plate calculator'**
  String get plateCalculator;

  /// No description provided for @plateCalcTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight'**
  String get plateCalcTargetWeight;

  /// No description provided for @plateCalcBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get plateCalcBar;

  /// No description provided for @plateCalcPerSide.
  ///
  /// In en, this message translates to:
  /// **'per side'**
  String get plateCalcPerSide;

  /// No description provided for @plateCalcUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable by {amount}'**
  String plateCalcUnreachable(String amount);

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Built by Gym Bros, For Gym Bros'**
  String get welcomeTagline;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @progressLabel.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get progressLabel;

  /// No description provided for @weightsKg.
  ///
  /// In en, this message translates to:
  /// **'weights kg'**
  String get weightsKg;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @dayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {number}'**
  String dayNumber(int number);

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @dayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day Label'**
  String get dayLabel;

  /// No description provided for @dayLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Chest Day'**
  String get dayLabelHint;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @deleteSchedule.
  ///
  /// In en, this message translates to:
  /// **'Delete Schedule'**
  String get deleteSchedule;

  /// No description provided for @deleteScheduleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this schedule? This cannot be undone.'**
  String get deleteScheduleConfirm;

  /// No description provided for @defaultProgramName.
  ///
  /// In en, this message translates to:
  /// **'Program 1'**
  String get defaultProgramName;

  /// No description provided for @recentExercises.
  ///
  /// In en, this message translates to:
  /// **'Recent Exercises'**
  String get recentExercises;

  /// No description provided for @allExercises.
  ///
  /// In en, this message translates to:
  /// **'All Exercises'**
  String get allExercises;

  /// No description provided for @allCategory.
  ///
  /// In en, this message translates to:
  /// **'All {category}'**
  String allCategory(String category);

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @equipmentNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get equipmentNone;

  /// No description provided for @barbell.
  ///
  /// In en, this message translates to:
  /// **'Barbell'**
  String get barbell;

  /// No description provided for @dumbbell.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell'**
  String get dumbbell;

  /// No description provided for @kettlebell.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell'**
  String get kettlebell;

  /// No description provided for @machine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get machine;

  /// No description provided for @resistanceBand.
  ///
  /// In en, this message translates to:
  /// **'Resistance Band'**
  String get resistanceBand;

  /// No description provided for @cardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get cardio;

  /// No description provided for @setsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String setsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
