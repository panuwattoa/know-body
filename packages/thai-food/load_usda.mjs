#!/usr/bin/env node
// Build a `thai_foods` migration from the USDA FoodData Central SR Legacy CSV
// (public domain). Maps a curated set of common ingredients to USDA's per-100g
// energy/protein/carb/fat, attaching Thai names + aliases so search works Thai-first.
//
//   node packages/thai-food/load_usda.mjs /tmp/usda/FoodData_Central_sr_legacy_food_csv_2018-04 \
//     > api/migrations/0006_usda_foods.sql
import { readFileSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2];
if (!dir) { console.error("usage: load_usda.mjs <sr_legacy_csv_dir> > migration.sql"); process.exit(1); }

// USDA nutrient ids (per 100 g): Energy kcal 1008 (fallback Atwater 2047/2048),
// Protein 1003, Carbohydrate by difference 1005, Total lipid (fat) 1004.
const N_ENERGY = ["1008", "2047", "2048"], N_PROT = "1003", N_CARB = "1005", N_FAT = "1004";

// Curated foods: th name, en name, search aliases, and keywords that must all
// appear in the USDA description (shortest match wins = most generic).
const CURATED = [
  ["ข้าวสวย","Steamed rice",["ข้าว","rice","khao"],["rice","white","cooked"]],
  ["ข้าวเหนียว","Glutinous rice",["sticky rice","khao niao"],["rice","white","glutinous","cooked"]],
  ["ข้าวกล้อง","Brown rice",["brown rice"],["rice","brown","cooked"]],
  ["อกไก่","Chicken breast",["chicken breast","ok gai"],["chicken","breast","meat only","roasted"]],
  ["สะโพกไก่","Chicken thigh",["chicken thigh"],["chicken","thigh","meat only","roasted"]],
  ["ไข่ไก่ดิบ","Egg, raw",["egg","khai"],["egg","whole","raw","fresh"]],
  ["ไข่ต้ม","Boiled egg",["boiled egg","khai tom"],["egg","whole","hard-boiled"]],
  ["ไข่ดาว","Fried egg",["fried egg","khai dao"],["egg","whole","fried"]],
  ["หมูสันใน","Pork loin",["pork","moo"],["pork","fresh","loin","roasted"]],
  ["หมูสับ","Ground pork",["minced pork"],["pork","ground","cooked"]],
  ["เนื้อวัว","Beef",["beef"],["beef","ground","cooked","broiled"]],
  ["กุ้ง","Shrimp",["shrimp","goong"],["shrimp","cooked","moist heat"]],
  ["ปลาทู","Mackerel",["pla too","mackerel"],["mackerel","cooked"]],
  ["ปลานิล","Tilapia",["tilapia"],["tilapia","cooked"]],
  ["ปลาแซลมอน","Salmon",["salmon"],["salmon","atlantic","cooked"]],
  ["ปลาหมึก","Squid",["squid"],["squid","cooked","fried"]],
  ["ทูน่ากระป๋อง","Canned tuna",["tuna"],["tuna","light","canned","water"]],
  ["เต้าหู้","Tofu",["tofu","taohu"],["tofu","raw","firm"]],
  ["ถั่วเหลือง","Soybeans",["soybean"],["soybeans","mature","cooked"]],
  ["น้ำมันพืช","Vegetable oil",["oil"],["oil","soybean","salad or cooking"]],
  ["น้ำมันมะพร้าว","Coconut oil",["coconut oil"],["oil","coconut"]],
  ["กะทิ","Coconut milk",["coconut milk"],["coconut milk","raw"]],
  ["น้ำตาลทราย","Sugar",["sugar","namtan"],["sugars","granulated"]],
  ["น้ำผึ้ง","Honey",["honey"],["honey"]],
  ["เนย","Butter",["butter"],["butter","salted"]],
  ["นมวัว","Milk",["milk","nom"],["milk","whole","3.25"]],
  ["โยเกิร์ต","Yogurt",["yogurt"],["yogurt","plain","whole milk"]],
  ["ชีสเชดดาร์","Cheddar cheese",["cheese"],["cheese","cheddar"]],
  ["ขนมปัง","Bread",["bread"],["bread","white","commercially"]],
  ["สปาเกตตี","Spaghetti",["pasta","spaghetti"],["spaghetti","cooked","enriched"]],
  ["บะหมี่ไข่","Egg noodles",["noodle"],["noodles","egg","cooked","enriched"]],
  ["มันฝรั่ง","Potato",["potato"],["potatoes","flesh and skin","baked"]],
  ["มันเทศ","Sweet potato",["sweet potato"],["sweet potato","cooked","baked"]],
  ["ข้าวโพด","Corn",["corn"],["corn","sweet","yellow","cooked"]],
  ["แครอท","Carrot",["carrot"],["carrots","raw"]],
  ["บรอกโคลี","Broccoli",["broccoli"],["broccoli","raw"]],
  ["กะหล่ำปลี","Cabbage",["cabbage"],["cabbage","raw"]],
  ["แตงกวา","Cucumber",["cucumber"],["cucumber","with peel","raw"]],
  ["มะเขือเทศ","Tomato",["tomato"],["tomatoes","red","ripe","raw","year round"]],
  ["หัวหอม","Onion",["onion"],["onions","raw"]],
  ["กระเทียม","Garlic",["garlic"],["garlic","raw"]],
  ["พริก","Chili pepper",["chili","prik"],["peppers","hot chili","red","raw"]],
  ["เห็ด","Mushroom",["mushroom"],["mushrooms","white","raw"]],
  ["ผักบุ้ง","Water spinach",["morning glory","pak boong"],["spinach","raw"]],
  ["ถั่วงอก","Bean sprouts",["bean sprout"],["mung bean","sprouted","raw"]],
  ["กล้วย","Banana",["banana","kluay"],["bananas","raw"]],
  ["มะม่วง","Mango",["mango","mamuang"],["mangos","raw"]],
  ["มะละกอ","Papaya",["papaya"],["papayas","raw"]],
  ["สับปะรด","Pineapple",["pineapple"],["pineapple","raw"]],
  ["ส้ม","Orange",["orange"],["oranges","raw","all commercial"]],
  ["แอปเปิล","Apple",["apple"],["apples","raw","with skin"]],
  ["แตงโม","Watermelon",["watermelon"],["watermelon","raw"]],
  ["องุ่น","Grapes",["grape"],["grapes","red or green"]],
  ["อะโวคาโด","Avocado",["avocado"],["avocados","raw","all commercial"]],
  ["ถั่วลิสง","Peanuts",["peanut"],["peanuts","all types","raw"]],
  ["เม็ดมะม่วงหิมพานต์","Cashews",["cashew"],["cashew nuts","raw"]],
  ["อัลมอนด์","Almonds",["almond"],["nuts","almonds"]],
  ["ข้าวโอ๊ต","Oats",["oats","oatmeal"],["oats"]],
  ["งา","Sesame seeds",["sesame"],["sesame seeds","whole","dried"]],
  ["น้ำปลา","Fish sauce",["fish sauce","nam pla"],["sauce","fish","ready-to-serve"]],
  ["ซีอิ๊ว","Soy sauce",["soy sauce"],["soy sauce","made from soy and wheat"]],
  ["มายองเนส","Mayonnaise",["mayo"],["mayonnaise"]],
  ["ไส้กรอกหมู","Pork sausage",["sausage"],["sausage","pork","cooked"]],
  ["เบคอน","Bacon",["bacon"],["bacon","cooked"]],
  ["แฮม","Ham",["ham"],["ham","sliced","regular"]],
  ["ป็อปคอร์น","Popcorn",["popcorn"],["popcorn","air-popped"]],
  ["มันฝรั่งทอด","Potato chips",["chips"],["snacks","potato chips","plain","salted"]],
  ["ช็อกโกแลต","Chocolate",["chocolate"],["candies","milk chocolate"]],
  ["ไอศกรีม","Ice cream",["ice cream"],["ice creams","vanilla"]],
  ["กาแฟดำ","Black coffee",["coffee"],["coffee","brewed","prepared with tap water"]],
  ["โค้ก","Cola",["cola","soft drink","coke"],["carbonated","cola","regular"]],
  ["เบียร์","Beer",["beer"],["alcoholic beverage","beer","regular","all"]],
];

// ── parse CSVs ──
function parseCsv(text) {
  const rows = []; let row = [], f = "", q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"' && text[i+1] === '"') { f += '"'; i++; } else if (c === '"') q = false; else f += c; }
    else if (c === '"') q = true;
    else if (c === ",") { row.push(f); f = ""; }
    else if (c === "\n") { row.push(f); rows.push(row); row = []; f = ""; }
    else if (c !== "\r") f += c;
  }
  if (f.length || row.length) { row.push(f); rows.push(row); }
  return rows;
}

// food.csv: fdc_id, data_type, description, ...
const foods = parseCsv(readFileSync(join(dir, "food.csv"), "utf8")).slice(1)
  .map((r) => ({ id: r[0], desc: (r[2] || "").toLowerCase() }))
  .filter((f) => f.id && f.desc);

// Match each curated entry to a food (all keywords present; shortest desc wins).
const wanted = new Map(); // fdc_id -> curated entry
for (const entry of CURATED) {
  const kws = entry[3];
  let best = null;
  for (const f of foods) {
    if (kws.every((k) => f.desc.includes(k))) {
      if (!best || f.desc.length < best.desc.length) best = f;
    }
  }
  if (best) wanted.set(best.id, entry);
  else console.error(`✗ no match: ${entry[1]} [${kws.join(", ")}]`);
}

// Scan food_nutrient.csv (large) for our fdc_ids + the 4 nutrients.
const nut = new Map(); // fdc_id -> {kcal, prot, carb, fat}
const fnText = readFileSync(join(dir, "food_nutrient.csv"), "utf8");
for (const line of fnText.split("\n").slice(1)) {
  if (!line) continue;
  // columns: id, fdc_id, nutrient_id, amount, ...  (all numeric, safe to split)
  const p = line.split(",");
  const fdc = (p[1] || "").replace(/"/g, "");
  if (!wanted.has(fdc)) continue;
  const nid = (p[2] || "").replace(/"/g, "");
  const amt = parseFloat((p[3] || "").replace(/"/g, ""));
  if (!Number.isFinite(amt)) continue;
  const o = nut.get(fdc) || {};
  if (N_ENERGY.includes(nid) && o.kcal == null) o.kcal = amt;
  else if (nid === N_PROT) o.prot = amt;
  else if (nid === N_CARB) o.carb = amt;
  else if (nid === N_FAT) o.fat = amt;
  nut.set(fdc, o);
}

const qs = (s) => "'" + String(s).replace(/'/g, "''") + "'";
const arr = (a) => "ARRAY[" + a.map(qs).join(",") + "]::text[]";
const rows = [];
for (const [fdc, entry] of wanted) {
  const n = nut.get(fdc);
  if (!n || n.kcal == null) { console.error(`✗ no nutrients: ${entry[1]}`); continue; }
  rows.push(`(${qs(entry[0])}, ${qs(entry[1])}, ${arr(entry[2])}, ${n.kcal ?? 0}, ${n.prot ?? 0}, ${n.carb ?? 0}, ${n.fat ?? 0})`);
}

console.log(`-- USDA FoodData Central SR Legacy (public domain). ${rows.length} curated foods, per 100 g.`);
console.log(`-- Source: U.S. Department of Agriculture, FoodData Central. https://fdc.nal.usda.gov/`);
console.log(`INSERT INTO thai_foods (name_th, name_en, aliases, kcal_100g, protein_100g, carbs_100g, fat_100g) VALUES`);
console.log(rows.join(",\n") + "\nON CONFLICT DO NOTHING;");
console.error(`✓ ${rows.length}/${CURATED.length} foods emitted`);
