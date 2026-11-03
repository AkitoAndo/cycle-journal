import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../../..");
const proposalRoot = resolve(repoRoot, "marketing/app-store/proposals");
const manifest = JSON.parse(await readFile(resolve(proposalRoot, "manifest.json"), "utf8"));
const outputDir = resolve(proposalRoot, "output");
const pngSignature = "89504e470d0a1a0a";

function outputFileName(index, screen) {
  return `${String(index + 1).padStart(2, "0")}-${screen.id}.png`;
}

async function verifyPng(path, expected, label) {
  const buffer = await readFile(path);
  if (buffer.subarray(0, 8).toString("hex") !== pngSignature) {
    throw new Error(`${label}: PNGではありません`);
  }

  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);
  const colorType = buffer.readUInt8(25);
  if (width !== expected.width || height !== expected.height) {
    throw new Error(`${label}: ${width}x${height}（期待値 ${expected.width}x${expected.height}）`);
  }
  if (colorType === 4 || colorType === 6) {
    throw new Error(`${label}: アルファチャンネルを含んでいます`);
  }

  console.log(`OK ${label} ${width}x${height} RGB`);
}

for (const plan of manifest.plans) {
  for (const [index, screen] of plan.screens.entries()) {
    const fileName = outputFileName(index, screen);
    await verifyPng(resolve(outputDir, plan.id, fileName), manifest.canvas, `${plan.id}/${fileName}`);
  }
  await verifyPng(
    resolve(outputDir, `${plan.id}-overview.png`),
    manifest.board,
    `${plan.id}-overview.png`,
  );
}
