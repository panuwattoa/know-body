export type Lang = "th" | "en";

export const copy = {
  th: {
    nav: { features: "ฟีเจอร์", pet: "โมจิ", pricing: "ราคา", waitlist: "ลงชื่อรอ" },
    tagline: "ฟิตเนสที่ใจดี ในกระเป๋าคุณ",
    heroTitle: "รู้จักร่างกายคุณ\nโดยไม่ต้องหมกมุ่นกับตัวเลข",
    heroSub:
      "ถ่ายรูปมื้ออาหาร ให้ AI คำนวณแคลอรีอาหารไทยให้ ออกกำลังแบบแตะเดียว และเลี้ยงโมจิแมวที่โตขึ้นเมื่อคุณมา",
    ctaPrimary: "ลงชื่อรอเปิดตัว",
    ctaSecondary: "ดูฟีเจอร์",
    featuresTitle: "ทำเพื่อคนที่ไม่ชอบการติดตาม",
    features: [
      { t: "ถ่ายรูป ไม่ต้องคำนวณ", d: "AI อ่านจานอาหารไทยของคุณ ประเมินแคลอรีและสารอาหาร ปรับส่วนผสมได้" },
      { t: "ออกกำลังแบบแตะเดียว", d: "ตั้งแต่ 5 นาทีขึ้นไป ทำไม่จบก็ยังนับสตรีคให้" },
      { t: "โมจิเติบโตไปกับคุณ", d: "แมวที่ได้ XP เลเวลอัพ และมีสตรีคแบบมีวันหยุดพัก" },
      { t: "สแกนร่างกายรายสัปดาห์", d: "ประเมินเป็นช่วง ไม่ตัดสิน รูปเก็บในเครื่องเป็นค่าเริ่มต้น" },
    ],
    pricingTitle: "เริ่มฟรี อัปเกรดเมื่อพร้อม",
    plans: [
      { name: "ฟรี", price: "0", per: "", feats: ["บันทึกอาหารเอง", "วงแหวนแคลอรี", "โมจิ + สตรีค", "ถ่ายรูป AI 3 ครั้ง/เดือน"], cta: "เริ่มเลย", highlight: false },
      { name: "KnowBody Plus", price: "129", per: "/เดือน", feats: ["ถ่ายรูป AI ไม่จำกัด", "โปรแกรมออกกำลัง AI ปรับอัตโนมัติ", "สแกนร่างกายรายสัปดาห์", "ซิงก์นาฬิกา + วิดเจ็ต"], cta: "อัปเกรด", highlight: true },
    ],
    waitlistTitle: "อยากลองก่อนใคร?",
    waitlistSub: "ใส่อีเมล เราจะบอกคุณตอนเปิดตัวในไทย",
    emailPlaceholder: "you@email.com",
    join: "ลงชื่อรอ",
    joined: "ขอบคุณ! เราจะติดต่อกลับ 🎉",
    footer: "ทำด้วยใจเพื่อคนไทย",
  },
  en: {
    nav: { features: "Features", pet: "Mochi", pricing: "Pricing", waitlist: "Waitlist" },
    tagline: "Calm, guided fitness in your pocket",
    heroTitle: "Know your body\nwithout obsessing over numbers",
    heroSub:
      "Snap a meal and let AI count Thai-food calories, do one-tap workouts, and raise Mochi — a cat who grows as you show up.",
    ctaPrimary: "Join the waitlist",
    ctaSecondary: "See features",
    featuresTitle: "Built for people who don't like tracking",
    features: [
      { t: "Photo, not math", d: "AI reads your Thai plate, estimates calories and macros — adjust any ingredient." },
      { t: "One-tap workouts", d: "From 5 minutes up. A part-finished workout still counts toward your streak." },
      { t: "Mochi grows with you", d: "A cat that earns XP, levels up, and keeps a streak with a freeze to spare." },
      { t: "Weekly body scan", d: "Estimates as ranges, never verdicts. Photos stay on device by default." },
    ],
    pricingTitle: "Start free, upgrade when ready",
    plans: [
      { name: "Free", price: "0", per: "", feats: ["Manual logging", "Calorie ring", "Mochi + streak", "3 AI photo logs / mo"], cta: "Get started", highlight: false },
      { name: "KnowBody Plus", price: "129", per: "/mo", feats: ["Unlimited AI photo logging", "AI workouts, auto-adjusted", "Weekly body scans", "Wearable sync + widgets"], cta: "Upgrade", highlight: true },
    ],
    waitlistTitle: "Want early access?",
    waitlistSub: "Drop your email — we'll tell you when we launch in Thailand.",
    emailPlaceholder: "you@email.com",
    join: "Join",
    joined: "Thanks! We'll be in touch 🎉",
    footer: "Made with care for Thailand",
  },
} as const;
