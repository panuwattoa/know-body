import 'package:flutter/widgets.dart';

/// Minimal, dependency-free localization for KnowBody (Thai default, English switch).
/// Kept hand-written so it compiles without `flutter gen-l10n`; can migrate to ARB later.
class KbStrings {
  KbStrings(this.locale);
  final Locale locale;

  static KbStrings of(BuildContext c) => Localizations.of<KbStrings>(c, KbStrings)!;
  static const delegate = _KbStringsDelegate();
  static const supported = [Locale('th'), Locale('en')];

  bool get isThai => locale.languageCode == 'th';
  String _(String th, String en) => isThai ? th : en;

  String get appName => 'KnowBody';
  String get tagline => _('ฟิตเนสที่ใจดี ในกระเป๋าคุณ', 'Calm, guided fitness in your pocket');
  String get email => _('อีเมล', 'Email');
  String get password => _('รหัสผ่าน', 'Password');
  String get signIn => _('เข้าสู่ระบบ', 'Sign in');
  String get signUp => _('สมัครสมาชิก', 'Create account');
  String get noAccount => _('ยังไม่มีบัญชี? สมัครเลย', "No account? Sign up");
  String get haveAccount => _('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ', 'Have an account? Sign in');
  String get signOut => _('ออกจากระบบ', 'Sign out');
  String get orDivider => _('หรือ', 'or');
  String get continueGoogle => _('เข้าสู่ระบบด้วย Google', 'Continue with Google');
  String get continueApple => _('เข้าสู่ระบบด้วย Apple', 'Continue with Apple');
  String get continueGuest => _('ใช้งานแบบผู้เยี่ยมชม', 'Continue as guest');
  String greeting(String name) => _('สวัสดีตอนบ่าย, $name', 'Good afternoon, $name');
  String get kcalLeft => _('กินได้อีก', 'KCAL LEFT');
  String get eatenToday => _('วันนี้กินไปแล้ว', 'Eaten today');
  String get ofWord => _('จาก', 'of');
  String burned(int n) => _('เบิร์นไป $n', '$n burned');
  String get snapMeal => _('ถ่ายรูปมื้อนี้เลย', 'Snap your meal');
  String get quickAdd => _('เพิ่มเอง', 'Quick add');
  String get todaysMeals => _('มื้อของวันนี้', "Today's meals");
  String get addDinner => _('+ เพิ่มอาหาร', '+ Add food');
  String get protein => _('โปรตีน', 'Protein');
  String get carbs => _('คาร์บ', 'Carbs');
  String get fat => _('ไขมัน', 'Fat');
  String streakDays(int n) => _('ต่อเนื่อง $n วัน', '$n-day streak');
  String get home => _('หน้าหลัก', 'Home');
  String get food => _('อาหาร', 'Food');
  String get move => _('ขยับ', 'Move');
  String get trend => _('กราฟ', 'Trend');
  String petLevel(int lv) => _('เลเวล $lv', 'Level $lv');
  String get feed => _('ให้อาหาร', 'Feed');
  String get play => _('เล่นด้วย', 'Play');
  String get buddy => _('เพื่อนซี้', 'Buddy');
  // Home summaries + share + calendar
  String get yesterday => _('เมื่อวาน', 'Yesterday');
  String get todaySuggestion => _('แนะนำวันนี้', "Today's suggestion");
  String get onTargetYest => _('เข้าเป้าเป๊ะ เก่งมาก!', 'Right on target — nice!');
  String get overYest => _('เกินเป้านิดหน่อย วันนี้เอาใหม่', 'A bit over — fresh start today');
  String get underYest => _('กินน้อยไปหน่อยเมื่อวาน', 'A little under yesterday');
  String get noDataYest => _('เมื่อวานยังไม่ได้บันทึกอะไร', 'Nothing logged yesterday');
  String get didWorkout => _('ออกกำลังด้วย 💪', 'Worked out too 💪');
  String get startSuggested => _('เริ่มเลย', 'Start');
  String get share => _('แชร์', 'Share');
  String get shareProgress => _('แชร์ความคืบหน้า', 'Share progress');
  String get streaksTitle => _('สตรีคของคุณ', 'Your streak');
  String get streakDaysBig => _('วันต่อเนื่อง', 'Streak days');
  String get streakBlurb => _('มาต่อเนื่องทุกวัน อย่าให้ไฟดับนะ 🔥', "Keep showing up — don't let the fire go out. 🔥");
  String get itemsScrollHint => _('เลื่อนดูรายการทั้งหมด', 'Scroll to see all items');
  String thMonth(int m) {
    const th = ['', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    const en = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return isThai ? th[m] : en[m];
  }
  List<String> get weekdayShort => isThai ? const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'] : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String petGrowsHint(String name) => _(
      'แค่แวะมา — บันทึกมื้ออาหารหรือขยับตัวสักหน่อย แล้ว$nameก็จะโตขึ้น',
      'Show up — log a meal or finish a move — and $name grows.');

  // Onboarding
  String get onbTitle => _('แบบไหนที่ทำแล้ว\nรู้สึกดีกับตัวเอง?', 'What would feel\nlike a win?');
  String get onbSubtitle => _(
      'เลือกสักอย่างก่อนก็ได้ เปลี่ยนใจทีหลังได้เสมอ ไม่ใช่สัญญาอะไรกันสักหน่อย',
      'Pick one. You can change it any time — nothing here is a contract.');
  String get goalEat => _('อยากกินดีขึ้นอีกนิด', 'Eat a bit better');
  String get goalEatSub => _('แค่ถ่ายรูป ไม่ต้องมานั่งนับเอง', 'Log food with a photo, no math');
  String get goalMove => _('อยากขยับตัวบ่อยขึ้น', 'Move more often');
  String get goalMoveSub => _('เริ่มจากแค่ 5 นาทีก็ยังดี', 'Workouts from 5 minutes up');
  String get goalPet => _('อยากเลี้ยงเจ้าเหมียวให้สดใส', 'Keep your buddy happy');
  String get goalPetSub => _('เจ้าเหมียวจะโตขึ้นทุกครั้งที่คุณกลับมา', 'Your cat grows as you show up');
  String get cont => _('ไปต่อ', 'Continue');

  // Naming the pet
  String get namePetTitle => _('ตั้งชื่อเพื่อนซี้\nตัวน้อยหน่อยสิ', 'Give your little\nbuddy a name');
  String get namePetSub => _(
      'เจ้าเหมียวตัวนี้จะอยู่เป็นเพื่อนคุณไปอีกนาน ตั้งชื่อที่คุณชอบได้เลย',
      "This cat's with you for the long run. Pick a name you love.");
  String get namePetHint => _('ชื่อเพื่อนของคุณ', "Your buddy's name");
  String get save => _('บันทึก', 'Save');
  String get rename => _('เปลี่ยนชื่อ', 'Rename');
  String get cancel => _('ยกเลิก', 'Cancel');

  // Body metrics + calorie suggestion
  String get bmTitle => _('เล่าเรื่องตัวคุณ\nให้เราฟังหน่อย', 'Tell us a bit\nabout you');
  String get bmSub => _('เราจะใช้คำนวณแคลอรีที่พอดีกับคุณ ข้อมูลนี้เป็นความลับ', "We'll use this to set a calorie target that fits you. It stays private.");
  String get sexM => _('ชาย', 'Male');
  String get sexF => _('หญิง', 'Female');
  String get age => _('อายุ (ปี)', 'Age (years)');
  String get height => _('ส่วนสูง (ซม.)', 'Height (cm)');
  String get weight => _('น้ำหนัก (กก.)', 'Weight (kg)');
  String get activity => _('ระดับกิจกรรม', 'Activity level');
  String get actSedentary => _('นั่งเป็นส่วนใหญ่', 'Mostly sitting');
  String get actLight => _('เบา ๆ', 'Light');
  String get actModerate => _('ปานกลาง', 'Moderate');
  String get actActive => _('กระฉับกระเฉง', 'Active');
  String get actVery => _('หนักมาก', 'Very active');
  String get targetDateLabel => _('อยากถึงเป้าเมื่อไหร่?', 'Target date');
  String get targetDateSub => _('เราจะวางโปรแกรมออกกำลังให้ทันวันนั้น', "We'll build a program that gets you there.");
  String get pickDate => _('เลือกวันที่', 'Pick a date');
  String weeksToGo(int w) => _('อีก $w สัปดาห์', '$w weeks to go');
  String get goalDirLabel => _('เป้าหมายน้ำหนัก', 'Weight goal');
  String get dirLose => _('ลดน้ำหนัก', 'Lose');
  String get dirMaintain => _('คงที่', 'Maintain');
  String get dirGain => _('เพิ่มกล้าม', 'Gain');
  String get calcTitle => _('นี่คือเป้าหมายของคุณ', "Here's your target");
  String get calcSub => _('ปรับได้ทีหลังเสมอ ไม่ต้องเป๊ะทุกวัน', 'You can adjust anytime — no need to be perfect.');
  String get perDay => _('ต่อวัน', 'per day');
  String get maintenanceIs => _('ค่าคงที่ของคุณ', 'Your maintenance is');

  // Food page + add meal
  String get noMealsYet => _('ยังไม่มีมื้ออาหารวันนี้', 'No meals logged today');
  String get noMealsSub => _('แตะปุ่มด้านล่างเพื่อเพิ่มมื้อแรกของวัน', 'Tap below to add your first meal');
  String get addMeal => _('เพิ่มมื้ออาหาร', 'Add a meal');
  String get editMeal => _('แก้ไขมื้ออาหาร', 'Edit meal');
  String get byPhoto => _('ถ่ายรูป', 'Photo');
  String get bySearch => _('ค้นหา', 'Search');
  String get byManual => _('เพิ่มเอง', 'Manual');
  String get searchFoodHint => _('ค้นหาอาหารไทย เช่น ข้าวผัด, ส้มตำ', 'Search Thai food, e.g. fried rice');
  String get grams => _('กรัม', 'grams');
  String get add => _('เพิ่ม', 'Add');
  String get itemsInMeal => _('รายการในมื้อนี้', 'Items in this meal');
  String get saveMeal => _('บันทึกมื้อนี้', 'Save meal');
  String get manualName => _('ชื่ออาหาร', 'Food name');
  String get slotBreakfast => _('มื้อเช้า', 'Breakfast');
  String get slotLunch => _('มื้อกลางวัน', 'Lunch');
  String get slotDinner => _('มื้อเย็น', 'Dinner');
  String get slotSnack => _('ของว่าง', 'Snack');
  String get delete => _('ลบ', 'Delete');
  String get deleteMealQ => _('ลบมื้อนี้?', 'Delete this meal?');
  String get emptyDraft => _('ยังไม่ได้เพิ่มรายการอาหาร', 'No items added yet');
  String mealSaved(int xp) => _('บันทึกแล้ว +$xp XP', 'Saved · +$xp XP');

  // Trend
  String get trendTitle => _('น้ำหนักของคุณ', 'Your weight');
  String get trendSub => _('ดูที่แนวโน้ม ไม่ใช่ตัวเลขวันเดียว', 'Watch the trend, not one day.');
  String get logWeight => _('บันทึกน้ำหนัก', 'Log weight');
  String get noWeightYet => _('ยังไม่มีข้อมูลน้ำหนัก บันทึกครั้งแรกเลย', 'No weigh-ins yet. Log your first.');
  String get today => _('วันนี้', 'today');
  String get muscle => _('กล้ามเนื้อ', 'Muscle');
  String get muscleKgOpt => _('กล้ามเนื้อ (กก.) — ไม่บังคับ', 'Muscle (kg) — optional');
  String get editWeighIn => _('แก้ไขน้ำหนัก', 'Edit weigh-in');
  String get deleteWeighInQ => _('ลบรายการนี้?', 'Delete this entry?');

  // Move (quick workouts)
  String get moveTitle => _('ขยับสักหน่อยไหม?', 'Move a little?');
  String get moveSub => _('เริ่มจากสั้น ๆ ก็ได้ ทำไม่จบก็ยังนับให้', 'Start short. Even unfinished still counts.');
  String get quickEasy => _('วอร์มเบา ๆ', 'Easy warm-up');
  String get quickBrisk => _('ออกกำลังกระฉับกระเฉง', 'Brisk workout');
  String get quickStrong => _('จัดเต็มหน่อย', 'Push a bit');
  String minutes(int m) => _('$m นาที', '$m min');
  String workoutDone(int xp) => _('เยี่ยมไปเลย! +$xp XP', 'Nice work! +$xp XP');
  String get startNow => _('เริ่มเลย', 'Start');
  String get again => _('เอาอีกรอบ', 'Go again');

  // Workout runner + custom
  String get elapsed => _('เวลาที่ใช้', 'Elapsed');
  String get setDone => _('เซ็ตนี้เสร็จ', 'Set done');
  String get nextMove => _('ท่าต่อไป', 'Next move');
  String get finishWorkout => _('จบการออกกำลัง', 'Finish');
  String moveOf(int a, int b) => _('ท่า $a จาก $b', 'Move $a of $b');
  String setsDoneOf(int a, int b) => _('$a จาก $b เซ็ต', '$a of $b sets');
  String get workoutRunning => _('กำลังออกกำลังกาย', 'Workout running');
  String get pause => _('พัก', 'Pause');
  String get resume => _('ไปต่อ', 'Resume');
  String get paused => _('พักอยู่', 'Paused');
  String get stopAnytime => _('หยุดเมื่อไหร่ก็ได้ ทำไม่จบก็ยังนับให้', 'Stop anytime — unfinished still counts.');
  String get customWorkout => _('สร้างเวิร์คเอาต์เอง', 'Build your own');
  String get newWorkout => _('เวิร์คเอาต์ใหม่', 'New workout');
  String get workoutName => _('ชื่อเวิร์คเอาต์', 'Workout name');
  String get addExercise => _('เพิ่มท่า', 'Add exercise');
  String get exerciseName => _('ชื่อท่า', 'Exercise name');
  String get sets => _('เซ็ต', 'Sets');
  String get reps => _('ครั้ง', 'Reps');
  String get startWorkout => _('เริ่มออกกำลัง', 'Start workout');
  String get noExercisesYet => _('ยังไม่มีท่า เพิ่มท่าแรกเลย', 'No exercises yet. Add the first.');
  String get yourProgram => _('โปรแกรมของคุณ', 'Your program');
  String get aiTrainer => _('เทรนเนอร์ AI จัดให้', 'AI trainer');
  String get regenerate => _('สร้างใหม่', 'Regenerate');
  String get generating => _('กำลังจัดโปรแกรมให้...', 'Building your program…');
  String get generatingSub => _('AI กำลังออกแบบโปรแกรมเฉพาะคุณ ใช้เวลาสักครู่นะ', 'Your AI trainer is designing a plan — this takes a few seconds.');
  String get analyzingPhoto => _('กำลังวิเคราะห์อาหารจากรูป...', 'Reading your meal…');
  String get analyzingSub => _('AI กำลังดูรูปและประเมินแคลอรี ใช้เวลาสักครู่', 'AI is estimating calories from the photo — a few seconds.');
  String get setLabel => _('เซ็ต', 'Sets');
  String get repLabel => _('จำนวนครั้งต่อเซ็ต', 'Reps per set');
  String get exNameLabel => _('ชื่อท่าออกกำลัง', 'Exercise name');
  String get quickPick => _('เลือกด่วน', 'Quick pick');
}

class _KbStringsDelegate extends LocalizationsDelegate<KbStrings> {
  const _KbStringsDelegate();
  @override
  bool isSupported(Locale l) => ['th', 'en'].contains(l.languageCode);
  @override
  Future<KbStrings> load(Locale l) async => KbStrings(l);
  @override
  bool shouldReload(_KbStringsDelegate old) => false;
}
