import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const researchDirectory = path.resolve(scriptDirectory, "..");
const partsDirectory = path.join(researchDirectory, "data", "parts");
const outputDirectory = path.join(researchDirectory, "data");

const partFiles = [
  "existing_12.jsonl",
  "journaling.jsonl",
  "planners.jsonl",
  "study_records.jsonl",
  "creator_responses.jsonl",
];

const requiredFields = [
  "quote_url",
  "quote_account",
  "quoted_account",
  "quote_date",
  "source_date",
  "short_excerpt",
  "likes",
  "reposts",
  "bookmarks",
  "replies",
  "views",
  "source_format",
  "relationship",
  "primary_function",
  "added_value",
  "evidence_type",
  "cta",
  "media_role",
  "conversationality_1_5",
  "assertion_1_5",
  "promo_1_5",
  "mental_health_risk",
  "hinaka_fit",
  "rationale",
  "quote_length_class",
  "source_format_group",
  "relationship_group",
];

const numericFields = ["likes", "reposts", "bookmarks", "replies", "views"];
const scoreFields = ["conversationality_1_5", "assertion_1_5", "promo_1_5"];
const allowedFits = new Set(["adopt", "adapt", "reject"]);
const allowedFunctions = new Set([
  "short_reaction",
  "specific_observation",
  "practical_addition",
  "question_answer",
  "self_followup",
  "creator_response",
  "audience_translation",
  "experience_endorsement",
  "strong_reframe",
  "resource_bridge",
]);
const allowedLengthClasses = new Set(["short", "medium", "long"]);
const allowedSourceFormatGroups = new Set([
  "text",
  "article",
  "image",
  "video",
  "question",
  "use_report",
  "release_update",
  "other",
]);
const allowedRelationshipGroups = new Set([
  "self",
  "third_party",
  "creator_user",
  "publisher_user",
  "peer",
  "other",
]);

function readJsonLines(filePath) {
  if (!fs.existsSync(filePath)) {
    return [];
  }

  return fs
    .readFileSync(filePath, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch (error) {
        throw new Error(`${filePath}:${index + 1}: JSONを解析できません。${error.message}`);
      }
    });
}

function statusId(url) {
  return String(url).match(/\/status\/(\d+)/)?.[1] ?? null;
}

function validateCase(item, sourceFile, sourceLine) {
  const errors = [];

  for (const field of requiredFields) {
    if (!(field in item)) {
      errors.push(`${field}がありません`);
    }
  }

  if (!statusId(item.quote_url)) {
    errors.push("quote_urlからステータスIDを取得できません");
  }

  for (const field of numericFields) {
    if (item[field] !== null && (!Number.isInteger(item[field]) || item[field] < 0)) {
      errors.push(`${field}は0以上の整数かnullにしてください`);
    }
  }

  for (const field of scoreFields) {
    if (!Number.isInteger(item[field]) || item[field] < 1 || item[field] > 5) {
      errors.push(`${field}は1から5の整数にしてください`);
    }
  }

  if (!allowedFits.has(item.hinaka_fit)) {
    errors.push("hinaka_fitはadopt、adapt、rejectのいずれかにしてください");
  }

  if (!allowedFunctions.has(item.primary_function)) {
    errors.push("primary_functionが分類語に含まれていません");
  }

  if (!allowedLengthClasses.has(item.quote_length_class)) {
    errors.push("quote_length_classが分類語に含まれていません");
  }

  if (!allowedSourceFormatGroups.has(item.source_format_group)) {
    errors.push("source_format_groupが分類語に含まれていません");
  }

  if (!allowedRelationshipGroups.has(item.relationship_group)) {
    errors.push("relationship_groupが分類語に含まれていません");
  }

  if (typeof item.mental_health_risk !== "boolean") {
    errors.push("mental_health_riskは真偽値にしてください");
  }

  if ([...String(item.short_excerpt)].length > 80) {
    errors.push("short_excerptは80文字以内にしてください");
  }

  return errors.map((message) => `${sourceFile}:${sourceLine}: ${message}`);
}

function median(values) {
  const numbers = values.filter((value) => Number.isFinite(value)).sort((a, b) => a - b);
  if (numbers.length === 0) return null;
  const middle = Math.floor(numbers.length / 2);
  return numbers.length % 2 === 0
    ? (numbers[middle - 1] + numbers[middle]) / 2
    : numbers[middle];
}

function round(value, digits = 4) {
  if (!Number.isFinite(value)) return null;
  return Number(value.toFixed(digits));
}

function groupSummary(items, key) {
  const groups = new Map();
  for (const item of items) {
    const value = item[key] ?? "未分類";
    if (!groups.has(value)) groups.set(value, []);
    groups.get(value).push(item);
  }

  return [...groups.entries()]
    .map(([value, group]) => ({
      value,
      count: group.length,
      median_likes: median(group.map((item) => item.likes)),
      median_reposts: median(group.map((item) => item.reposts)),
      median_bookmarks: median(group.map((item) => item.bookmarks)),
      median_views: median(group.map((item) => item.views)),
      median_like_rate: round(median(group.map((item) => item.views > 0 ? item.likes / item.views : null))),
      median_repost_rate: round(median(group.map((item) => item.views > 0 ? item.reposts / item.views : null))),
      median_bookmark_rate: round(median(group.map((item) => item.views > 0 ? item.bookmarks / item.views : null))),
      median_bookmarks_per_like: round(median(group.map((item) => item.likes > 0 ? item.bookmarks / item.likes : null))),
    }))
    .sort((a, b) => b.count - a.count || String(a.value).localeCompare(String(b.value), "ja"));
}

function csvCell(value) {
  if (value === null || value === undefined) return "";
  const text = String(value);
  return /[",\n\r]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

const errors = [];
const allCases = [];

for (const partFile of partFiles) {
  const fullPath = path.join(partsDirectory, partFile);
  const items = readJsonLines(fullPath);
  items.forEach((item, index) => {
    errors.push(...validateCase(item, partFile, index + 1));
    allCases.push({ ...item, collection_bucket: path.basename(partFile, ".jsonl") });
  });
}

if (errors.length > 0) {
  console.error(errors.join("\n"));
  process.exit(1);
}

const seenIds = new Set();
const uniqueCases = [];
const duplicates = [];

for (const item of allCases) {
  const id = statusId(item.quote_url);
  if (seenIds.has(id)) {
    duplicates.push(item.quote_url);
    continue;
  }
  seenIds.add(id);
  uniqueCases.push(item);
}

const selected = [];
const selectedIds = new Set();

function addCase(item) {
  const id = statusId(item.quote_url);
  if (selectedIds.has(id) || selected.length >= 100) return;
  selected.push(item);
  selectedIds.add(id);
}

uniqueCases
  .filter((item) => item.collection_bucket === "existing_12")
  .sort((a, b) => b.likes - a.likes)
  .forEach(addCase);

for (const bucket of ["journaling", "planners", "study_records", "creator_responses"]) {
  uniqueCases
    .filter((item) => item.collection_bucket === bucket)
    .sort((a, b) => b.likes - a.likes)
    .slice(0, 22)
    .forEach(addCase);
}

uniqueCases
  .filter((item) => !selectedIds.has(statusId(item.quote_url)))
  .sort((a, b) => b.likes - a.likes)
  .forEach(addCase);

if (selected.length < 100) {
  console.error(`重複を除くと${selected.length}件です。100件以上の候補が必要です。`);
  process.exit(1);
}

const numberedCases = selected.map((item, index) => ({
  case_id: `QR${String(index + 1).padStart(3, "0")}`,
  schema_version: "1.0.0",
  observed_at: "2026-09-13",
  excerpt_length: [...String(item.short_excerpt)].length,
  like_rate: item.views > 0 ? round(item.likes / item.views) : null,
  repost_rate: item.views > 0 ? round(item.reposts / item.views) : null,
  bookmark_rate: item.views > 0 ? round(item.bookmarks / item.views) : null,
  bookmarks_per_like: item.likes > 0 ? round(item.bookmarks / item.likes) : null,
  ...item,
}));

const jsonlPath = path.join(outputDirectory, "2026-09-13-quote-reposts-100.jsonl");
const csvPath = path.join(outputDirectory, "2026-09-13-quote-reposts-100.csv");
const analysisPath = path.join(outputDirectory, "2026-09-13-quote-reposts-analysis.json");

fs.writeFileSync(jsonlPath, `${numberedCases.map((item) => JSON.stringify(item)).join("\n")}\n`);

const columns = [...new Set(numberedCases.flatMap((item) => Object.keys(item)))];
const csv = [
  columns.map(csvCell).join(","),
  ...numberedCases.map((item) => columns.map((column) => csvCell(item[column])).join(",")),
].join("\n");
fs.writeFileSync(csvPath, `${csv}\n`);

const analysis = {
  generated_at: new Date().toISOString(),
  selected_count: numberedCases.length,
  candidate_count: allCases.length,
  unique_candidate_count: uniqueCases.length,
  duplicate_count: duplicates.length,
  duplicate_urls: duplicates,
  overall: {
    median_likes: median(numberedCases.map((item) => item.likes)),
    median_reposts: median(numberedCases.map((item) => item.reposts)),
    median_bookmarks: median(numberedCases.map((item) => item.bookmarks)),
    median_views: median(numberedCases.map((item) => item.views)),
    median_like_rate: round(median(numberedCases.map((item) => item.like_rate))),
    median_repost_rate: round(median(numberedCases.map((item) => item.repost_rate))),
    median_bookmark_rate: round(median(numberedCases.map((item) => item.bookmark_rate))),
    median_bookmarks_per_like: round(median(numberedCases.map((item) => item.bookmarks_per_like))),
  },
  by_collection_bucket: groupSummary(numberedCases, "collection_bucket"),
  by_primary_function: groupSummary(numberedCases, "primary_function"),
  by_source_format_group: groupSummary(numberedCases, "source_format_group"),
  by_relationship_group: groupSummary(numberedCases, "relationship_group"),
  by_quote_length_class: groupSummary(numberedCases, "quote_length_class"),
  by_conversationality: groupSummary(numberedCases, "conversationality_1_5"),
  by_assertion: groupSummary(numberedCases, "assertion_1_5"),
  by_promo: groupSummary(numberedCases, "promo_1_5"),
  by_mental_health_risk: groupSummary(numberedCases, "mental_health_risk"),
  by_hinaka_fit: groupSummary(numberedCases, "hinaka_fit"),
};

fs.writeFileSync(analysisPath, `${JSON.stringify(analysis, null, 2)}\n`);

console.log(`候補: ${allCases.length}件`);
console.log(`重複除外後: ${uniqueCases.length}件`);
console.log(`分析対象: ${numberedCases.length}件`);
console.log(`JSON Lines: ${jsonlPath}`);
console.log(`CSV: ${csvPath}`);
console.log(`集計: ${analysisPath}`);
