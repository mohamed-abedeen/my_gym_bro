// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'My Gym Bro';

  @override
  String get tabHome => 'Inicio';

  @override
  String get tabWorkout => 'Entrenamiento';

  @override
  String get tabLog => 'Registro';

  @override
  String get tabCommunity => 'Comunidad';

  @override
  String get status => 'Estado';

  @override
  String get dailyChallenge => 'Reto diario';

  @override
  String get competeFriends => 'Compite con tus amigos';

  @override
  String get startTrial => 'Prueba gratis 7 días';

  @override
  String get createSchedule => 'Crear programa';

  @override
  String get buildYourFlow => 'Crea tu rutina o encuentra un programa pro';

  @override
  String scheduleRemaining(int hours) {
    return '${hours}h restantes';
  }

  @override
  String get nextSession => 'Próxima sesión';

  @override
  String get sessionLog => 'Sesiones';

  @override
  String get statusLog => 'Estado';

  @override
  String get weeklyProgress => 'Progreso semanal';

  @override
  String get recovered => 'Recuperado';

  @override
  String get recovering => 'Recuperándose';

  @override
  String get undertrained => 'Sin entrenar';

  @override
  String get healingTitle => 'Recuperación...';

  @override
  String get healingSubtitle => 'Tu cuerpo necesita descanso';

  @override
  String get sets => 'Series';

  @override
  String get reps => 'Reps';

  @override
  String get weight => 'Peso';

  @override
  String get startWorkout => 'Iniciar entrenamiento';

  @override
  String get finishWorkout => 'Terminar entrenamiento';

  @override
  String get restDay => 'Día de descanso';

  @override
  String get calBurned => 'Calorías quemadas';

  @override
  String get calBurnedLastWeek => 'Calorías quemadas la semana pasada';

  @override
  String get calBurnedThisWeek => 'Calorías quemadas esta semana';

  @override
  String get weeklyReports => 'Informes semanales';

  @override
  String get reports => 'Informes';

  @override
  String get week => 'Semana';

  @override
  String get weights => 'Pesos';

  @override
  String get calUnit => 'Cal';

  @override
  String get minUnit => 'Min';

  @override
  String get exercisePrefix => 'Ej';

  @override
  String get reportNoData => 'Sin entrenamiento este día';

  @override
  String statusKcalProgress(int burned, int goal) {
    return '$burned/$goal KCAL';
  }

  @override
  String statusKcalNoGoal(int burned) {
    return '$burned KCAL';
  }

  @override
  String get shoulders => 'Hombros';

  @override
  String get chest => 'Pecho';

  @override
  String get core => 'Core';

  @override
  String get target => 'Objetivo';

  @override
  String get achieved => 'Logrado';

  @override
  String statusLiftedTotal(String amount) {
    return '¡Has levantado $amount desde el primer día!';
  }

  @override
  String statusVolumeIncrease(int pct) {
    return '¡Tu peso levantado aumentó un $pct% desde el primer día!';
  }

  @override
  String statusRepsTotal(String reps) {
    return '¡Has hecho $reps repeticiones desde el primer día!';
  }

  @override
  String statusCaloriesBurnedTotal(String kcal) {
    return '¡Has quemado más de $kcal calorías!';
  }

  @override
  String statusCaloriesBodyFat(String kcal, String pct) {
    return '¡Has quemado más de $kcal calorías y perdido un $pct% de grasa corporal!';
  }

  @override
  String get calorieGoal => 'Objetivo de calorías';

  @override
  String get bodyFat => 'Grasa corporal';

  @override
  String get totalDuration => 'Duración total';

  @override
  String get avgStrength => 'Fuerza promedio';

  @override
  String get records => 'Récords';

  @override
  String get volume => 'Volumen';

  @override
  String get totalVolume => 'Volumen total';

  @override
  String get totalTime => 'Tiempo total';

  @override
  String get howTo => 'Cómo hacerlo';

  @override
  String get targetMuscles => 'Músculos objetivo';

  @override
  String get secondaryMuscles => 'Músculos secundarios';

  @override
  String get equipment => 'Equipamiento';

  @override
  String get instructions => 'Instrucciones';

  @override
  String get searchExercises => 'Buscar ejercicios...';

  @override
  String get noRecordsYet => 'Sin récords todavía';

  @override
  String get yourRecords => 'Tus récords';

  @override
  String bestSet(double weight, int reps) {
    return 'Mejor: ${weight}kg × $reps reps';
  }

  @override
  String get addSet => 'Añadir serie';

  @override
  String get addExercise => 'Añadir ejercicio';

  @override
  String get editExercises => 'Editar ejercicios';

  @override
  String get addDay => 'Añadir días';

  @override
  String get scheduleName => 'Nombre del programa';

  @override
  String get todaySession => 'Sesión de hoy';

  @override
  String get lastWeek => 'Semana pasada';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get yesterday => 'Ayer';

  @override
  String get cancelAnytime =>
      'Cancela cuando quieras. Sin cargos durante la prueba.';

  @override
  String get restoreSubscription => 'Restaurar compras';

  @override
  String get monthlyPlan => 'Mensual';

  @override
  String get yearlyPlan => 'Anual';

  @override
  String get bestValue => 'Mejor oferta';

  @override
  String get trialBadge => '7 días gratis';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Crear cuenta';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get nameLabel => 'Tu nombre';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get noAccount => '¿No tienes cuenta?';

  @override
  String get alreadyAccount => 'Ya tengo una cuenta';

  @override
  String get chooseLanguage => 'Elige tu idioma';

  @override
  String get chooseGoal => '¿Cuál es tu objetivo?';

  @override
  String get buildMuscle => 'Ganar músculo';

  @override
  String get loseWeight => 'Perder peso';

  @override
  String get getStronger => 'Ganar fuerza';

  @override
  String get chooseExperience => '¿Tu nivel?';

  @override
  String get beginner => 'Principiante';

  @override
  String get intermediate => 'Intermedio';

  @override
  String get advanced => 'Avanzado';

  @override
  String get letsGo => '¡Vamos!';

  @override
  String get trialStarted => 'Tu prueba gratuita de 7 días comienza ahora';

  @override
  String get securityWarningTitle => 'Advertencia de seguridad';

  @override
  String get securityWarningBody =>
      'Este dispositivo parece comprometido. My Gym Bro no puede ejecutarse de forma segura.';

  @override
  String get closeApp => 'Cerrar aplicación';

  @override
  String get biometricPrompt => 'Desbloquear My Gym Bro';

  @override
  String get language => 'Idioma';

  @override
  String get weightUnit => 'Unidad de peso';

  @override
  String get bodyWeight => 'Peso corporal';

  @override
  String get notSet => 'Sin definir';

  @override
  String get biometricLock => 'Bloqueo biométrico';

  @override
  String get manageSubscription => 'Gestionar suscripción';

  @override
  String get exportData => 'Exportar mis datos';

  @override
  String get clearCache => 'Limpiar caché comunidad';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountConfirm =>
      'Esto eliminará permanentemente todos tus datos. No se puede deshacer.';

  @override
  String get deleteAccountButton => 'Eliminar mi cuenta';

  @override
  String lastSynced(String time) {
    return 'Sincronizado $time';
  }

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get rateApp => 'Valorar la app';

  @override
  String get contactSupport => 'Contactar soporte';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String appVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get pendingSync => 'Sync pendiente';

  @override
  String get synced => 'Sincronizado';

  @override
  String get syncError => 'Error de sync';

  @override
  String get loadingExercises => 'Cargando ejercicios...';

  @override
  String get whatOnYourMind => '¿Qué hay de nuevo?';

  @override
  String get communityEmpty => 'Aún no hay publicaciones. ¡Sé el primero!';

  @override
  String get communityError => 'No se pudo cargar el feed. Inténtalo de nuevo.';

  @override
  String get post => 'Publicar';

  @override
  String get skip => 'Omitir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get done => 'Listo';

  @override
  String get back => 'Atrás';

  @override
  String get share => 'Compartir';

  @override
  String get schedule => 'Programa';

  @override
  String get noScheduleYet => 'Sin programa todavía';

  @override
  String activeSubscription(String date) {
    return 'Activo — se renueva el $date';
  }

  @override
  String trialDaysLeft(int days) {
    return 'Prueba — $days días restantes';
  }

  @override
  String get subscriptionExpired => 'Suscripción expirada';

  @override
  String get restComplete => '¡Descanso completado!';

  @override
  String get restCompleteTitleSupportive => 'Descanso completado';

  @override
  String get restCompleteBodySupportive =>
      'Tus músculos están listos cuando tú lo estés.';

  @override
  String get restCompleteTitleBalanced => 'Descanso completado';

  @override
  String get restCompleteBodyBalanced => 'Hora de empezar tu siguiente serie.';

  @override
  String get restCompleteTitleBold => 'Descanso completado';

  @override
  String get restCompleteBodyBold => 'Vuelve a entrar. Siguiente serie.';

  @override
  String get restCompleteTitleSavage => 'DESCANSO TERMINADO';

  @override
  String get restCompleteBodySavage => 'SIGUIENTE SERIE. AHORA.';

  @override
  String get notificationTone => 'Tono de las notificaciones';

  @override
  String get notificationToneSubtitle => 'Elige el tono de tus recordatorios';

  @override
  String get toneSupportive => 'Comprensivo';

  @override
  String get toneSupportiveDescription => 'Recordatorios suaves y alentadores.';

  @override
  String get toneBalanced => 'Equilibrado';

  @override
  String get toneBalancedDescription => 'Recordatorios neutros y objetivos.';

  @override
  String get toneBold => 'Directo';

  @override
  String get toneBoldDescription => 'Recordatorios directos y firmes.';

  @override
  String get toneSavage => 'Implacable';

  @override
  String get toneSavageDescription => 'Todo en mayúsculas, sin excusas.';

  @override
  String get notificationToneOnboardingTitle => 'Elige tu voz';

  @override
  String get notificationToneOnboardingSubtitle =>
      '¿Cómo deberíamos hablarte durante el entrenamiento?';

  @override
  String get notificationToneExampleLabel => 'Ejemplo';

  @override
  String get restTimer => 'Temporizador de descanso';

  @override
  String get off => 'No';

  @override
  String get reorderExercises => 'Reordenar ejercicios';

  @override
  String get replaceExercise => 'Reemplazar ejercicio';

  @override
  String get defaultRestTime => 'Tiempo de descanso predeterminado';

  @override
  String get restTimerSound => 'Sonido del temporizador';

  @override
  String get trainingReminders => 'Recordatorios de entrenamiento';

  @override
  String get communityNotifications => 'Retos de comunidad';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get notificationsSection => 'Notificaciones';

  @override
  String get skipRest => 'Omitir';

  @override
  String addSeconds(int n) {
    return '+${n}s';
  }

  @override
  String subtractSeconds(int n) {
    return '-${n}s';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get bodyStatus => 'Estado corporal';

  @override
  String get workoutStatus => 'Estado entrenamiento';

  @override
  String get lastMonth => 'Mes pasado';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get weeklyStreak => 'Racha semanal';

  @override
  String get leaderboardEmpty =>
      'Aún no hay clasificación. Termina un entrenamiento para entrar en la tabla de esta semana.';

  @override
  String setsThisWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series esta semana',
      one: '1 serie esta semana',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas',
      one: '1 semana',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Entrena mejor. Hazte más fuerte.';

  @override
  String get continueButton => 'Continuar';

  @override
  String get passwordStrengthWeak => 'Débil';

  @override
  String get passwordStrengthMedium => 'Media';

  @override
  String get passwordStrengthStrong => 'Fuerte';

  @override
  String get emailInvalid => 'Introduce un correo válido';

  @override
  String get nameRequired => 'El nombre es obligatorio';

  @override
  String get passwordRequirements =>
      'Mín 8 caracteres, 1 mayúscula, 1 número, 1 especial';

  @override
  String get trialFeature1 => 'Seguimiento ilimitado de entrenamientos';

  @override
  String get trialFeature2 => 'Biblioteca de 1300+ ejercicios';

  @override
  String get trialFeature3 => 'Programas de entrenamiento personalizados';

  @override
  String get trialFeature4 => 'Analíticas de progreso y récords';

  @override
  String get resetPasswordSent => 'Correo de restablecimiento enviado';

  @override
  String get orDivider => 'o';

  @override
  String get signUpError => 'No se pudo crear la cuenta. Inténtalo de nuevo.';

  @override
  String get signInError => 'Correo o contraseña incorrectos.';

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
  String get dmMessages => 'Mensajes';

  @override
  String get dmSearch => 'Buscar';

  @override
  String get dmNoMessagesYet => 'Aún no hay mensajes';

  @override
  String get dmStartChatting => '¡Chatea con tus Gym Bros!';

  @override
  String get dmNewConversationUnavailable =>
      'Nueva conversación no disponible en v1';

  @override
  String dmStartConversation(String name) {
    return 'Empieza tu conversación\ncon $name';
  }

  @override
  String get dmMessageHint => 'Mensaje...';

  @override
  String get dmSendFailed =>
      'No se pudo enviar el mensaje. Inténtalo de nuevo.';

  @override
  String get dmSavedToSchedules => '¡Guardado en tus programas!';

  @override
  String get dmCamera => 'Cámara';

  @override
  String get dmGallery => 'Galería';

  @override
  String get dmSchedule => 'Programa';

  @override
  String get dmShareSchedule => 'Compartir programa';

  @override
  String get dmNoSchedulesToShare => 'No hay programas para compartir';

  @override
  String get dmSharedSchedule => 'Programa compartido';

  @override
  String get dmInvalidSchedule => 'Datos de programa no válidos';

  @override
  String get dmSaveToMySchedules => 'Guardar en mis programas';

  @override
  String get dmUploading => 'Subiendo...';

  @override
  String get dmSentMessage => 'Mensaje enviado';

  @override
  String get dmImageTooLarge => 'La imagen supera el límite de 10 MB.';

  @override
  String dmDaysCount(int count) {
    return '$count días';
  }

  @override
  String get dmWorkout => 'Entrenamiento';

  @override
  String get addDayTitle => 'Añadir día';

  @override
  String get oneStepCloserBro => 'Un paso más cerca, bro';

  @override
  String get newProgram => 'Nuevo programa';

  @override
  String nextSessionAfter(int hours) {
    return 'Próxima sesión en ${hours}h';
  }

  @override
  String get readyToTrain => '¡Listo para entrenar, Bro!';

  @override
  String get restDaysBetween => 'Días de descanso entre';

  @override
  String get rest => 'Descanso';

  @override
  String get filterMuscle => 'Músculo';

  @override
  String get filterEquipment => 'Equipo';

  @override
  String get filterDifficulty => 'Dificultad';

  @override
  String readyInHoursMuscle(int hours, String muscle) {
    return 'Listo en ${hours}h ($muscle recuperándose)';
  }

  @override
  String get noExercisesFound =>
      'No se encontraron ejercicios para esta combinación, Bro!';

  @override
  String get exercisesOfflineCached =>
      'Sin conexión: mostrando tus ejercicios guardados.';

  @override
  String get allMuscles => 'Todos los músculos';

  @override
  String get allEquipment => 'Todo el equipo';

  @override
  String get allDifficulties => 'Todos los niveles';

  @override
  String get exerciseSearchHint => 'What are you looking for ?';

  @override
  String get account => 'Account';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String get follow => 'Seguir';

  @override
  String get friends => 'Amigos';

  @override
  String get streak => 'Streak';

  @override
  String get widgetStreakStart => 'Empieza una racha';

  @override
  String get widgetStreakOneDay => 'Racha de 1 día';

  @override
  String widgetStreakDays(int days) {
    return 'Racha de $days días';
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
  String get retry => 'Reintentar';

  @override
  String get leaderboard => 'Clasificación';

  @override
  String get muscleRecovery => 'Recuperación muscular';

  @override
  String get sore => 'Adolorido';

  @override
  String get notTrainedYet => 'Aún no entrenado';

  @override
  String get fullyRecovered => 'Totalmente recuperado — listo para entrenar';

  @override
  String get lessThanOneHourRecovery => 'Menos de 1 hora para recuperarse';

  @override
  String hoursRestNeeded(int hours) {
    return '${hours}h más de descanso';
  }

  @override
  String daysRestNeeded(int days) {
    return '${days}d más de descanso';
  }

  @override
  String daysHoursRestNeeded(int days, int hours) {
    return '${days}d ${hours}h más de descanso';
  }

  @override
  String nSelected(int count) {
    return '$count seleccionado(s)';
  }

  @override
  String get clearFilters => 'Borrar filtros';

  @override
  String get failedToLoadExercises => 'No se pudieron cargar los ejercicios';

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
  String get removeExercise => 'Eliminar ejercicio';

  @override
  String get discardWorkout => '¿Descartar este entrenamiento?';

  @override
  String get deleteSet => 'Eliminar serie';

  @override
  String get deleteSetConfirm => '¿Eliminar esta serie?';

  @override
  String get setLabel => 'Serie';

  @override
  String get selectSetType => 'Seleccionar tipo de serie';

  @override
  String get warmUpSet => 'Serie de calentamiento';

  @override
  String get normalSet => 'Serie normal';

  @override
  String get failureSet => 'Serie al fallo';

  @override
  String get dropSet => 'Serie descendente';

  @override
  String get removeSet => 'Eliminar serie';

  @override
  String get superSet => 'Superserie';

  @override
  String get pressToDelete => 'Pulsa para eliminar';

  @override
  String get time => 'Tiempo';

  @override
  String get finish => 'Terminar';

  @override
  String get discard => 'Descartar';

  @override
  String get discardWorkoutConfirm =>
      '¿Descartar este entrenamiento? Se perderá todo el progreso.';

  @override
  String get finishWorkoutConfirm =>
      '¿Terminar este entrenamiento? Se guardará en tu historial.';

  @override
  String get completeSet => 'Completar serie';

  @override
  String get restTime => 'Tiempo de descanso';

  @override
  String get remaining => 'Restante';

  @override
  String get restAfterSet => 'Debes descansar\ntras esta serie';

  @override
  String get unfinishedSets => 'Series incompletas';

  @override
  String get unfinishedSetsMessage =>
      'Tienes series incompletas. ¿Estás seguro de que quieres terminar esta sesión?';

  @override
  String get confirm => 'Confirmar';

  @override
  String get endSession => 'Terminar sesión';

  @override
  String get previousExercise => 'Anterior';

  @override
  String get nextExercise => 'Siguiente';

  @override
  String get noInstructions => 'Sin instrucciones disponibles';

  @override
  String get deleteWorkout => 'Eliminar entrenamiento';

  @override
  String get deleteWorkoutConfirm => '¿Eliminar este entrenamiento?';

  @override
  String get leaderboardTab => 'Clasificación';

  @override
  String get challengesTab => 'Retos';

  @override
  String get currentLeague => 'LIGA ACTUAL';

  @override
  String get yourPlace => 'Tu lugar';

  @override
  String placeNumber(int n) {
    return '$n Lugar';
  }

  @override
  String get leagueElite => 'La Élite';

  @override
  String get leagueMaster => 'El Maestro';

  @override
  String get leagueStanding => 'Estable';

  @override
  String get leagueMovingUp => 'Subiendo';

  @override
  String get leagueWorkHarder => 'Trabaja más';

  @override
  String get scopeRivals => 'Rivales';

  @override
  String get scopeGlobal => 'Global';

  @override
  String get scopeFriends => 'Amigos';

  @override
  String get volumeLabel => 'Volumen';

  @override
  String percentDone(int percent) {
    return '$percent% hecho';
  }

  @override
  String rankNumber(int rank) {
    return 'Rango #$rank';
  }

  @override
  String get startChallenge => 'iniciar';

  @override
  String endInDays(int days) {
    return 'Termina en ${days}d';
  }

  @override
  String get leagueMasterTitle => 'Maestro';

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
  String get rankUnranked => 'Sin clasificar';

  @override
  String get rankUpTitle => '¡SUBISTE DE RANGO!';

  @override
  String get rankUpCta => '¡Vamos!';

  @override
  String get newPrTitle => '¡NUEVO RÉCORD!';

  @override
  String rankNext(String rank) {
    return 'Siguiente: $rank';
  }

  @override
  String get rankMax => 'Rango máximo alcanzado';

  @override
  String get rankShieldTooltip =>
      'Escudo de descenso: tu rango está protegido mientras te recuperas.';

  @override
  String get skinPremium => 'Premium';

  @override
  String get skinPremiumSoon => 'Skin premium — compras disponibles pronto';

  @override
  String skinWorkoutsShort(int count) {
    return '$count entrenos';
  }

  @override
  String skinLockedProgress(int count) {
    return 'Se desbloquea a los $count entrenamientos';
  }

  @override
  String get noChallengesYet => 'No hay retos activos';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsSectionWorkout => 'Entrenamiento';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionData => 'Datos y cuenta';

  @override
  String get skins => 'Skins';

  @override
  String get anatomyModel => 'Modelo anatómico';

  @override
  String get male => 'Hombre';

  @override
  String get female => 'Mujer';

  @override
  String get restTimerVibration => 'Vibración del temporizador';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutConfirm =>
      '¿Cerrar sesión en tu cuenta? Tus datos locales permanecen en este dispositivo.';

  @override
  String get cacheCleared => 'Caché borrada';

  @override
  String get cacheClearFailed => 'No se pudo borrar la caché';

  @override
  String get couldNotOpenLink => 'No se pudo abrir el enlace';

  @override
  String get exportComingSoon => 'Exportación disponible pronto';

  @override
  String get deleteAccountFailed =>
      'No se pudo eliminar la cuenta. Inténtalo de nuevo.';

  @override
  String get planPremium => 'Premium';

  @override
  String get trainingReminderBody => 'Mantén tu racha. A entrenar.';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get settingsWorkoutFooter =>
      'Valores predeterminados para temporizadores de descanso, registro y estimación de calorías.';

  @override
  String get settingsNotificationsFooter =>
      'Los recordatorios de entrenamiento protegen tu racha.';

  @override
  String get settingsDataFooter =>
      'Eliminar tu cuenta borra permanentemente tus datos de nuestros servidores.';

  @override
  String get duration => 'Duración';

  @override
  String get heatmapLess => 'Menos';

  @override
  String get heatmapMore => 'Más';

  @override
  String get tapDayToJump => 'Toca un día para ir a su sesión';

  @override
  String jumpedToDay(String date) {
    return 'Saltado a $date';
  }

  @override
  String get shareNiceWork => '¡Buen trabajo!';

  @override
  String get shareStyleNormal => 'Normal';

  @override
  String get shareStyleTransparent => 'Transparente';

  @override
  String shareWorkoutNumber(int count) {
    return 'Entrenamiento n.º $count';
  }

  @override
  String get shareLiftedTotal => 'Levantaste un total de';

  @override
  String get shareYourProgress => 'Comparte tu progreso';

  @override
  String get shareAnonymous => 'Anónimo';

  @override
  String get shareError => 'No se pudo crear la imagen. Inténtalo de nuevo.';

  @override
  String get shareSaved => 'Guardado en la galería';

  @override
  String get shareSaveError => 'No se pudo guardar en la galería';

  @override
  String get shareVolumeCaption => 'Eso es hierro de verdad.';

  @override
  String get shareVolumeDog => 'un perro grande';

  @override
  String get shareVolumeFridge => 'un frigorífico';

  @override
  String get shareVolumePiano => 'un piano de cola';

  @override
  String get shareVolumeCar => 'un coche pequeño';

  @override
  String get shareVolumeVan => 'una furgoneta';

  @override
  String get shareVolumeElephant => 'un elefante adulto';

  @override
  String get shareThisWeek => 'Esta semana';
}
