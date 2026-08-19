#!/usr/bin/env node
// Convert a Thai food CSV export (e.g. a licensed INMU Thai FCD export) into a
// SQL migration that seeds the `thai_foods` table.
//
//   node packages/thai-food/load_food_csv.mjs input.csv > api/migrations/0006_thai_fcd.sql
//
// Expected columns (rename in COLS below if your export differs), per 100 g:
//   name_th, name_en, aliases (| separated, optional),
//   kcal_100g, protein_100g, carbs_100g, fat_100g
import { readFileSync } from "node:fs";

// Map your CSV's header names → our fields. Adjust the right-hand side to match the export.
const COLS = {
  name_th: "name_th",
  name_en: "name_en",
  aliases: "aliases",
  kcal_100g: "kcal_100g",
  protein_100g: "protein_100g",
  carbs_100g: "carbs_100g",
  fat_100g: "fat_100g",
};

const path = process.argv[2];
if (!path) {
  console.error("usage: node load_food_csv.mjs <input.csv> > migration.sql");
  process.exit(1);
}

// Minimal CSV parser (handles quoted fields with commas/newlines).
function parseCsv(text) {
  const rows = [];
  let row = [], field = "", inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQuotes = false;
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; }
    else if (c === "\r") { /* skip */ }
    else field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows;
}

const q = (s) => "'" + String(s ?? "").replace(/'/g, "''").trim() + "'";
const num = (s) => {
  const n = parseFloat(String(s ?? "").replace(/[^0-9.\-]/g, ""));
  return Number.isFinite(n) ? n : 0;
};
const arr = (s) => {
  const parts = String(s ?? "").split("|").map((x) => x.trim()).filter(Boolean);
  return "ARRAY[" + parts.map(q).join(",") + "]::text[]";
};

const rows = parseCsv(readFileSync(path, "utf8")).filter((r) => r.some((c) => c.trim()));
if (rows.length < 2) { console.error("no data rows"); process.exit(1); }

const header = rows[0].map((h) => h.trim());
const idx = Object.fromEntries(Object.entries(COLS).map(([k, name]) => [k, header.indexOf(name)]));
for (const [k, i] of Object.entries(idx)) {
  if (i < 0 && k !== "aliases") { console.error(`missing column for ${k} (looked for "${COLS[k]}")`); process.exit(1); }
}

const values = [];
for (const r of rows.slice(1)) {
  const nameTh = (r[idx.name_th] || "").trim();
  const nameEn = (r[idx.name_en] || "").trim();
  if (!nameTh && !nameEn) continue;
  values.push(
    `(${q(nameTh)}, ${q(nameEn)}, ${idx.aliases >= 0 ? arr(r[idx.aliases]) : "'{}'::text[]"}, ` +
    `${num(r[idx.kcal_100g])}, ${num(r[idx.protein_100g])}, ${num(r[idx.carbs_100g])}, ${num(r[idx.fat_100g])})`
  );
}

console.log(`-- Generated from ${path} — Thai food nutrition (per 100 g).`);
console.log(`-- Source: INMU Thai FCD (attribution required). ${values.length} rows.`);
console.log(`INSERT INTO thai_foods (name_th, name_en, aliases, kcal_100g, protein_100g, carbs_100g, fat_100g) VALUES`);
console.log(values.join(",\n") + ";");
console.error(`✓ ${values.length} foods → stdout`);
