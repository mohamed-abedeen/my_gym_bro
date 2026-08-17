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
  String get tabBros => 'Bros';

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
  String pricePerMonth(String price) {
    return '$price / al mes';
  }

  @override
  String pricePerYear(String price) {
    return '$price / al año';
  }

  @override
  String get saveWithYearly => 'Ahorra casi un 50 % con el plan anual';

  @override
  String get bestValue => 'Mejor oferta';

  @override
  String get trialBadge => '7 días gratis';

  @override
  String get subscribeToContinue => 'Suscríbete para continuar';

  @override
  String get autoRenewDisclosure =>
      'La suscripción se renueva automáticamente al precio y período indicados, salvo que la canceles al menos 24 horas antes del final del período actual. Gestiónala o cancélala cuando quieras en los ajustes de tu cuenta del App Store o Google Play.';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get purchaseFailed => 'Error en la compra. Inténtalo de nuevo.';

  @override
  String get restoreFailed =>
      'No se pudieron restaurar las compras. Inténtalo de nuevo.';

  @override
  String get restoreSuccess => 'Compras restauradas.';

  @override
  String get noOfferingsAvailable =>
      'No hay ofertas disponibles. Inténtalo más tarde.';

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
  String get clearCache => 'Limpiar caché de imágenes';

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
  String get postFailed => 'No se pudo publicar. Inténtalo de nuevo.';

  @override
  String get backAgainToExit => 'Desliza atrás otra vez para salir';

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
  String get communityNotifications => 'Retos';

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
  String get goalTitle => '¿Cuál es tu objetivo principal\nal entrenar?';

  @override
  String get bulking => 'Volumen';

  @override
  String get bulkingDesc => 'Céntrate en ganar masa muscular y tamaño.';

  @override
  String get strength => 'Fuerza';

  @override
  String get strengthDesc => 'Levanta más peso y hazte más fuerte.';

  @override
  String get cutting => 'Definición';

  @override
  String get cuttingDesc => 'Reduce la grasa corporal manteniendo el músculo.';

  @override
  String get maintaining => 'Mantenimiento';

  @override
  String get maintainingDesc => 'Mantén tu músculo y tu forma actuales.';

  @override
  String get dataPrivate => 'Tus datos son privados y seguros.';

  @override
  String get experienceTitle => '¿Cuánta experiencia\nde entrenamiento tienes?';

  @override
  String get base => 'Base';

  @override
  String get baseYears => '0-1 años';

  @override
  String get mid => 'Medio';

  @override
  String get midYears => '1-3 años';

  @override
  String get pro => 'Pro';

  @override
  String get proYears => '3+ años';

  @override
  String get selectGender => 'Selecciona tu género';

  @override
  String get genderSubtitle =>
      'Esto nos ayuda a personalizar\ntu plan de entrenamiento.';

  @override
  String get birthdayTitle => '¿Cuándo es tu cumpleaños?';

  @override
  String get weightTitle => '¿Cuánto pesas?';

  @override
  String get heightTitle => '¿Cuánto mides?';

  @override
  String get targetZonesTitle => '¿Cuáles son tus zonas\nobjetivo?';

  @override
  String get arms => 'Brazos';

  @override
  String get abs => 'Abdominales';

  @override
  String get pecs => 'Pectorales';

  @override
  String get targetBack => 'Espalda';

  @override
  String get legs => 'Piernas';

  @override
  String get all => 'Todo';

  @override
  String get kgs => 'kg';

  @override
  String get lbs => 'lbs';

  @override
  String get cm => 'cm';

  @override
  String get ft => 'ft';

  @override
  String get freeTrial => 'Prueba gratis';

  @override
  String get yearly => 'Anual';

  @override
  String get monthly => 'Mensual';

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
  String get exerciseSearchHint => '¿Qué estás buscando?';

  @override
  String get account => 'Cuenta';

  @override
  String get statBros => 'Bros';

  @override
  String get streak => 'Racha';

  @override
  String get widgetStreakStart => 'Empieza una racha';

  @override
  String get widgetStreakOneDay => 'Racha de 1 día';

  @override
  String widgetStreakDays(int days) {
    return 'Racha de $days días';
  }

  @override
  String get streakSkips => 'Comodines de racha';

  @override
  String streakSkipsExplainer(int count) {
    return '¿Faltaste un día de entrenamiento? Tu racha sobrevive automáticamente. Tienes $count comodines al mes — nunca dos en la misma semana.';
  }

  @override
  String streakSkipsLeftThisMonth(int count, int total) {
    return '$count de $total restantes este mes';
  }

  @override
  String streakSkipsCountLeft(int count) {
    return '$count restantes';
  }

  @override
  String get streakSkipsNoneLeft => 'No quedan comodines este mes';

  @override
  String get posts => 'Publicaciones';

  @override
  String get lastSession => 'Última sesión';

  @override
  String get noSessionsYet => 'Aún no hay sesiones';

  @override
  String get noPostsYet => 'Aún no hay publicaciones';

  @override
  String get retry => 'Reintentar';

  @override
  String get leaderboard => 'Clasificación';

  @override
  String get muscleRecovery => 'Recuperación muscular';

  @override
  String get sore => 'Adolorido';

  @override
  String get tapMuscleToFocus =>
      'Toca un músculo abajo para enfocarlo en el cuerpo';

  @override
  String get anatomyModeRecovery => 'Recuperación';

  @override
  String get trainingVolume => 'Volumen de entrenamiento';

  @override
  String get volumeWindowFourWeeks => '4 semanas';

  @override
  String get volumeTargetHint =>
      'Objetivo: 10–20 series ponderadas por músculo a la semana';

  @override
  String get volumeAboveTarget => 'Por encima del objetivo';

  @override
  String get volumeOnTarget => 'En el objetivo';

  @override
  String get volumeBelowTarget => 'Por debajo del objetivo';

  @override
  String volumeSetsThisWeek(String sets) {
    return '$sets series ponderadas esta semana';
  }

  @override
  String volumeSetsPerWeek(String sets) {
    return '$sets series/semana en las últimas 4 semanas';
  }

  @override
  String get readyNow => 'Listo ahora';

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
  String get tabSummary => 'Resumen';

  @override
  String get tabHistory => 'Historial';

  @override
  String get heaviestWeight => 'Peso máximo';

  @override
  String get oneRepMax => '1RM';

  @override
  String get bestSetVolumeLabel => 'Mejor volumen por serie';

  @override
  String get bestSessionVolumeLabel => 'Mejor volumen por sesión';

  @override
  String get setRecords => 'Récords de series';

  @override
  String get last3Months => 'Últimos 3 meses';

  @override
  String get last6Months => 'Últimos 6 meses';

  @override
  String get allTime => 'Histórico';

  @override
  String get noHistoryYet => 'Aún no hay historial';

  @override
  String get primaryLabel => 'Principal';

  @override
  String get secondaryLabel => 'Secundario';

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
  String get confirmFinishTitle => '¿Terminar entrenamiento?';

  @override
  String get confirmFinishBody => 'Se guardará en tu historial.';

  @override
  String get confirmDiscardTitle => '¿Descartar entrenamiento?';

  @override
  String get confirmDiscardBody => 'Se perderá todo el progreso.';

  @override
  String get confirmDeleteWorkoutBody => 'Se eliminará de tu historial.';

  @override
  String get confirmDeleteScheduleTitle => '¿Eliminar este plan?';

  @override
  String get confirmDeleteScheduleBody => 'Esto no se puede deshacer.';

  @override
  String get confirmSignOutTitle => '¿Cerrar sesión?';

  @override
  String get confirmSignOutBody =>
      'Tus datos locales permanecen en este dispositivo. Tendrás que iniciar sesión de nuevo para sincronizar.';

  @override
  String get confirmDeleteAccountTitle => '¿Eliminar tu cuenta?';

  @override
  String get confirmDeleteAccountBody =>
      'Esto elimina permanentemente todos tus datos — sesiones, PRs, planes. No se puede deshacer.';

  @override
  String get keepGoing => 'Seguir entrenando';

  @override
  String get holdToDelete => 'Mantén pulsado para eliminar';

  @override
  String get holdConfirmed => 'Confirmado';

  @override
  String get tapAgainToConfirm => 'Toca de nuevo para confirmar';

  @override
  String get exercisesLabel => 'Ejercicios';

  @override
  String get newPrLabel => 'Nuevo PR';

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
  String get liftRankCardTitle => 'Rango de fuerza';

  @override
  String liftRankUpSubtitle(String lift, String rank) {
    return '$lift alcanzó $rank';
  }

  @override
  String get shareRanksChip => 'Rangos';

  @override
  String get shareRanksTitle => 'Rangos de hoy';

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
  String get skinPurchaseSuccess => 'Skin desbloqueada. ¡Te queda genial!';

  @override
  String get skinPurchaseFailed =>
      'No se pudo completar la compra. Inténtalo de nuevo.';

  @override
  String get skinRestoreNone => 'No hay compras de skins para restaurar.';

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
  String get settingsSectionPersonal => 'Personal';

  @override
  String get pinkMode => 'Modo Rosa';

  @override
  String get premadeTitle => 'Programas Pro';

  @override
  String get premadeSubtitle =>
      'Planes listos para cada situación, sin configurar nada';

  @override
  String get premadeCategoryAll => 'Todos';

  @override
  String get premadeCategoryQuick => 'Rápido';

  @override
  String get premadeCategoryHome => 'En casa';

  @override
  String get premadeCategoryCalisthenics => 'Calistenia';

  @override
  String get premadeCategoryCore => 'Core';

  @override
  String get premadeLevelBeginner => 'Principiante';

  @override
  String get premadeLevelIntermediate => 'Intermedio';

  @override
  String get premadeLevelAdvanced => 'Avanzado';

  @override
  String premadeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String premadeDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String premadeExercisesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ejercicios',
      one: '1 ejercicio',
    );
    return '$_temp0';
  }

  @override
  String get premadeAdd => 'Añadir a mis programas';

  @override
  String get premadeAdded =>
      '¡Añadido! Lo encontrarás en la pestaña Entrenamiento.';

  @override
  String get premadeDayFullBody => 'Cuerpo completo';

  @override
  String get premadeDayUpper => 'Tren superior';

  @override
  String get premadeDayLower => 'Tren inferior';

  @override
  String get premadeDayPush => 'Push';

  @override
  String get premadeDayPull => 'Pull';

  @override
  String get premadeDayLegsCore => 'Piernas y core';

  @override
  String get premadeDayCore => 'Core';

  @override
  String get premadeDayArms => 'Brazos';

  @override
  String get premadeWakeUpName => 'Despertar en 5 minutos';

  @override
  String get premadeWakeUpTagline => 'Impulso rápido de cuerpo completo';

  @override
  String get premadeCoreBlastName => 'Core exprés en 5 minutos';

  @override
  String get premadeCoreBlastTagline => 'Cuatro ejercicios, core al límite';

  @override
  String get premadeArmPumpName => 'Bombeo de brazos en 5 minutos';

  @override
  String get premadeArmPumpTagline => 'Final rápido de bíceps y tríceps';

  @override
  String get premadeHomeFullBodyName => 'Cuerpo completo en casa';

  @override
  String get premadeHomeFullBodyTagline => 'Tres días sin material';

  @override
  String get premadeHomeDumbbellName => 'Plan con mancuernas en casa';

  @override
  String get premadeHomeDumbbellTagline =>
      'Cuerpo completo con solo dos mancuernas';

  @override
  String get premadeCalisthenicsBasicsName => 'Fundamentos de calistenia';

  @override
  String get premadeCalisthenicsBasicsTagline =>
      'Domina empuje, tracción y sentadilla';

  @override
  String get premadeCalisthenicsStrengthName => 'Fuerza en calistenia';

  @override
  String get premadeCalisthenicsStrengthTagline =>
      'Progresiones más duras con tu peso';

  @override
  String get premadeCoreAbsName => 'Core y abdominales';

  @override
  String get premadeCoreAbsTagline => 'Dos días para un centro más fuerte';

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
  String get exportPreparing => 'Preparando tu exportación…';

  @override
  String get exportNothingYet =>
      'Aún no hay nada que exportar — registra primero un entrenamiento';

  @override
  String get exportFailed => 'Error al exportar. Inténtalo de nuevo.';

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
  String get shareNiceWork => 'Buen trabajo.';

  @override
  String get shareStyleDark => 'Oscuro';

  @override
  String get shareStyleSticker => 'Sticker';

  @override
  String get shareTemplateEditorial => 'Editorial';

  @override
  String get shareTemplateAnatomy => 'Anatomía';

  @override
  String get shareTemplateHype => 'Hype';

  @override
  String shareWorkoutNumber(int count) {
    return 'Entrenamiento n.º $count';
  }

  @override
  String get shareTotalVolumeLifted => 'Volumen total levantado';

  @override
  String get shareOneSession => 'Una sesión';

  @override
  String get shareYou => 'Tú';

  @override
  String shareHeavierThan(String object) {
    return 'Más pesado que $object.';
  }

  @override
  String get shareAnonymous => 'Anónimo';

  @override
  String get shareError => 'No se pudo crear la imagen. Inténtalo de nuevo.';

  @override
  String get shareSaved => 'Guardado en la galería';

  @override
  String get shareSaveError => 'No se pudo guardar en la galería';

  @override
  String get shareExerciseTitle => 'Tu progreso.';

  @override
  String get sharePersonalRecords => 'Récords personales';

  @override
  String get shareVolumeTrend => 'Tendencia de volumen';

  @override
  String shareTrendSessions(int count) {
    return 'Últimas $count sesiones';
  }

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
  String get shareObjectDog => 'Perro';

  @override
  String get shareObjectFridge => 'Nevera';

  @override
  String get shareObjectPiano => 'Piano';

  @override
  String get shareObjectCar => 'Coche';

  @override
  String get shareObjectVan => 'Furgoneta';

  @override
  String get shareObjectElephant => 'Elefante';

  @override
  String get close => 'Cerrar';

  @override
  String get hint => 'Pista';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get markSetComplete => 'Marcar serie como completada';

  @override
  String get markSetIncomplete => 'Marcar serie como no completada';

  @override
  String restTimerRemaining(String time) {
    return 'Temporizador de descanso, quedan $time';
  }

  @override
  String get plateCalculator => 'Calculadora de discos';

  @override
  String get plateCalcTargetWeight => 'Peso objetivo';

  @override
  String get plateCalcBar => 'Barra';

  @override
  String get plateCalcPerSide => 'por lado';

  @override
  String plateCalcUnreachable(String amount) {
    return 'Inalcanzable por $amount';
  }

  @override
  String get getStarted => 'Empezar';

  @override
  String get welcomeTagline => 'Hecho por Gym Bros, para Gym Bros';

  @override
  String get noData => 'Sin datos';

  @override
  String get progressLabel => 'PROGRESO';

  @override
  String get weightsKg => 'peso kg';

  @override
  String get day => 'Día';

  @override
  String dayNumber(int number) {
    return 'Día $number';
  }

  @override
  String get label => 'Etiqueta';

  @override
  String get dayLabel => 'Etiqueta del día';

  @override
  String get dayLabelHint => 'p. ej. Día de pecho';

  @override
  String get weightKg => 'Peso (kg)';

  @override
  String get deleteSchedule => 'Eliminar plan';

  @override
  String get deleteScheduleConfirm =>
      '¿Seguro que quieres eliminar este plan? Esto no se puede deshacer.';

  @override
  String get defaultProgramName => 'Programa 1';

  @override
  String get recentExercises => 'Ejercicios recientes';

  @override
  String get allExercises => 'Todos los ejercicios';

  @override
  String allCategory(String category) {
    return 'Todo: $category';
  }

  @override
  String get other => 'Otros';

  @override
  String get equipmentNone => 'Ninguno';

  @override
  String get barbell => 'Barra';

  @override
  String get dumbbell => 'Mancuerna';

  @override
  String get kettlebell => 'Kettlebell';

  @override
  String get machine => 'Máquina';

  @override
  String get resistanceBand => 'Banda elástica';

  @override
  String get cardio => 'Cardio';

  @override
  String setsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String get splitCurrentPlan => 'Plan actual';

  @override
  String splitTrainingDaysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días de entrenamiento por semana',
      one: '1 día de entrenamiento por semana',
    );
    return '$_temp0';
  }

  @override
  String get splitDescription =>
      'Enfoque en fuerza, desarrollo muscular y desarrollo simétrico.';

  @override
  String get splitStatDuration => 'Duración';

  @override
  String get splitStatSinceStart => 'desde el inicio';

  @override
  String get splitStatDays => 'Días';

  @override
  String get splitStatTrainingDays => 'Días de entreno';

  @override
  String get splitStatSession => 'Sesión';

  @override
  String get splitStatAvgDuration => 'duración media';

  @override
  String get splitStatProgress => 'Progreso';

  @override
  String splitMinutesRange(int min, int max) {
    return '$min–$max min.';
  }

  @override
  String get splitWeeklyPlan => 'Tu plan semanal';

  @override
  String get splitDay => 'Día';

  @override
  String get splitRestSubtitle => 'Regeneración y descanso';

  @override
  String get splitQuickProgress => 'Progreso';

  @override
  String get splitQuickProgressSub => 'Tu evolución';

  @override
  String get splitQuickEditPlan => 'Editar plan';

  @override
  String get splitQuickEditPlanSub => 'Días y ejercicios';

  @override
  String get splitQuickSettings => 'Ajustes';

  @override
  String get splitQuickSettingsSub => 'Preferencias de la app';

  @override
  String get splitQuickDiscover => 'Descubrir';

  @override
  String get splitQuickDiscoverSub => 'Otros planes de entrenamiento';

  @override
  String get dayDetailCurrentPlan => 'Plan actual';

  @override
  String dayDetailDescription(String muscles) {
    return 'Enfoque en $muscles. Ideal para fuerza y desarrollo muscular.';
  }

  @override
  String get dayDetailStatCalories => 'Calorías';

  @override
  String get dayDetailKcalApprox => 'kcal (aprox.)';

  @override
  String get dayDetailWorkoutHeader => 'Tu entrenamiento';

  @override
  String dayDetailRepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reps',
      one: '1 rep',
    );
    return '$_temp0';
  }

  @override
  String get discoverTitle => 'Descubrir';

  @override
  String get discoverProgramsTitle => 'Programas';

  @override
  String get discoverFilter => 'Filtro';

  @override
  String get discoverLevel => 'Nivel';

  @override
  String get discoverGoal => 'Objetivo';

  @override
  String get discoverEquipment => 'Equipamiento';

  @override
  String discoverRoutinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rutinas',
      one: '1 rutina',
    );
    return '$_temp0';
  }

  @override
  String discoverShowAll(int count) {
    return 'Ver los $count programas';
  }

  @override
  String get discoverCoachTitle => 'Tu entrenador personal';

  @override
  String get discoverCoachSubtitle =>
      'Programas según tus necesidades y objetivos.';

  @override
  String get discoverOtherPlansCta => 'Descubre otros planes de entrenamiento';

  @override
  String get addBros => 'Añadir bros';

  @override
  String get myUsernameTitle => 'Mi alias';

  @override
  String get claimUsernameTitle => 'Reclama tu alias';

  @override
  String get claimUsernameExplainer =>
      'Tus bros te encuentran por tu @alias. 3–20 caracteres: minúsculas, números, guion bajo.';

  @override
  String get claimUsernameHint => 'alias';

  @override
  String get claimAction => 'Reclamar';

  @override
  String get usernameTaken => 'Ese alias ya está en uso.';

  @override
  String get usernameInvalid =>
      '3–20 caracteres: minúsculas, números, guion bajo.';

  @override
  String get usernameNeedsOnline =>
      'Para reclamar un alias necesitas conexión.';

  @override
  String get searchByUsername => 'Añadir por @alias';

  @override
  String get searchByUsernameHint => '@alias';

  @override
  String get searchNoMatch => 'Nadie tiene ese alias.';

  @override
  String get searchNeedsOnline => 'La búsqueda necesita conexión.';

  @override
  String get requestsTitle => 'Solicitudes';

  @override
  String get acceptAction => 'Aceptar';

  @override
  String get declineAction => 'Rechazar';

  @override
  String get sentRequestsTitle => 'Enviadas';

  @override
  String get cancelRequestAction => 'Cancelar';

  @override
  String get myBrosTitle => 'Mis bros';

  @override
  String get noBrosYet =>
      'Aún no tienes bros. Invita a tu crew o añádelos por @alias.';

  @override
  String get inviteAction => 'Invitar';

  @override
  String get inviteSheetTitle => 'Invitar a un bro';

  @override
  String get inviteQrHint => 'Que tu bro escanee esto con su cámara';

  @override
  String get inviteShareAction => 'Compartir enlace de invitación';

  @override
  String inviteMessage(String username, String link) {
    return 'Añádeme en MyGymBro — soy @$username. $link';
  }

  @override
  String get inviteNeedsUsername =>
      'Primero reclama un alias — tu invitación lo lleva.';

  @override
  String get removeBroAction => 'Quitar bro';

  @override
  String get removeBroConfirmTitle => '¿Quitar a este bro?';

  @override
  String get removeBroConfirmBody =>
      'Siempre puedes enviar una nueva solicitud más tarde.';

  @override
  String get blockAction => 'Bloquear';

  @override
  String get blockConfirmTitle => '¿Bloquear a este usuario?';

  @override
  String get blockConfirmBody =>
      'Desapareceréis por completo el uno para el otro. Solo tú puedes deshacerlo.';

  @override
  String get unblockAction => 'Desbloquear';

  @override
  String get blockedTitle => 'Bloqueados';

  @override
  String get reportAction => 'Denunciar';

  @override
  String get reportSheetTitle => 'Denunciar a este usuario';

  @override
  String get reportReasonSpam => 'Spam o cuenta falsa';

  @override
  String get reportReasonHarassment => 'Acoso o bullying';

  @override
  String get reportReasonImpersonation => 'Suplantación de identidad';

  @override
  String get reportReasonOther => 'Otra cosa';

  @override
  String get reportSentToast => 'Denuncia enviada. La revisaremos.';

  @override
  String get requestSentToast => 'Solicitud enviada.';

  @override
  String get nowBrosToast => '¡Ya sois bros!';

  @override
  String get requestFailedToast => 'No se pudo enviar la solicitud.';

  @override
  String get addBroAction => 'Añadir bro';

  @override
  String get pendingLabel => 'Pendiente';

  @override
  String get signInToAddBros => 'Inicia sesión para añadir bros.';

  @override
  String get communityChallenges => 'Retos de la comunidad';

  @override
  String endsInShort(Object time) {
    return 'Termina en $time';
  }

  @override
  String get endedLabel => 'Finalizado';

  @override
  String durationShortDays(Object n) {
    return '$n d';
  }

  @override
  String durationShortHours(Object n) {
    return '$n h';
  }

  @override
  String percentDone(Object percent) {
    return '$percent% hecho';
  }

  @override
  String progressOfGoal(Object goal, Object progress) {
    return '$progress / $goal';
  }

  @override
  String get joinChallenge => 'Unirse';

  @override
  String get joinedChallenge => 'Unido';

  @override
  String get leaveChallenge => 'Abandonar el reto';

  @override
  String get challengeCompleted => 'Completado';

  @override
  String plusPoints(Object points) {
    return '+$points pts';
  }

  @override
  String challengePointsChip(Object points) {
    return '$points pts';
  }

  @override
  String get createChallenge => 'Crear reto';

  @override
  String get challengeTitleLabel => 'Título';

  @override
  String get challengeDescriptionLabel => 'Descripción (opcional)';

  @override
  String get challengeGoalLabel => 'Objetivo';

  @override
  String get goalTypeVolume => 'Volumen (kg)';

  @override
  String get goalTypeSessions => 'Entrenamientos';

  @override
  String get goalTypeSets => 'Series';

  @override
  String get goalTypeStreak => 'Días de entreno';

  @override
  String get goalTypeCustom => 'Personalizado (sistema de honor)';

  @override
  String get challengeTargetLabel => 'Meta';

  @override
  String get challengeDurationLabel => 'Duración';

  @override
  String durationDaysOption(Object days) {
    return '$days días';
  }

  @override
  String challengePointsLabel(Object max) {
    return 'Puntos (máx. $max)';
  }

  @override
  String get reportChallenge => 'Denunciar reto';

  @override
  String get deleteChallenge => 'Eliminar reto';

  @override
  String get markComplete => 'Marcar como completado';

  @override
  String get challengeCreatedToast => 'Reto creado';

  @override
  String get challengeInvalidToast =>
      'Revisa los datos del reto e inténtalo de nuevo.';

  @override
  String get challengeReportedToast => 'Gracias — este reto será revisado.';

  @override
  String get signInToJoinChallenges => 'Inicia sesión para unirte a los retos.';

  @override
  String get tplDailyOneSessionTitle => 'Preséntate';

  @override
  String get tplDailyOneSessionDesc =>
      'Completa una sesión de entrenamiento hoy.';

  @override
  String get tplDailyVolume5kTitle => 'Mueve 5.000 kg';

  @override
  String get tplDailyVolume5kDesc =>
      'Levanta un total de 5.000 kg entre todas las series hoy.';

  @override
  String get tplDailyVolume10kTitle => 'Mueve 10.000 kg';

  @override
  String get tplDailyVolume10kDesc =>
      'Levanta un total de 10.000 kg entre todas las series hoy.';

  @override
  String get tplDailySets12Title => '12 series efectivas';

  @override
  String get tplDailySets12Desc =>
      'Completa 12 series efectivas hoy (el calentamiento no cuenta).';

  @override
  String get tplDailySets20Title => '20 series efectivas';

  @override
  String get tplDailySets20Desc =>
      'Completa 20 series efectivas hoy (el calentamiento no cuenta).';

  @override
  String get boardWeekly => 'Semanal';

  @override
  String get boardMonthly => 'Mensual';

  @override
  String get boardAllTime => 'Histórico';

  @override
  String resetsIn(Object time) {
    return 'Se reinicia en $time';
  }

  @override
  String lastWinnerLabel(Object name) {
    return 'Último ganador: $name';
  }
}
