import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../../..");
const marketingRoot = resolve(repoRoot, "marketing/app-store");
const manifest = JSON.parse(
  await readFile(resolve(marketingRoot, "manifest-ipad.json"), "utf8"),
);
const outputDir = resolve(
  marketingRoot,
  "output",
  manifest.locale,
  manifest.outputDirectory,
);
const pngSignature = "89504e470d0a1a0a";

for (const [index, screen] of manifest.screens.entries()) {
  const fileName = `${String(index + 1).padStart(2, "0")}-${screen.id}.png`;
  const buffer = await readFile(resolve(outputDir, fileName));

  if (buffer.subarray(0, 8).toString("hex") !== pngSignature) {
    throw new Error(`${fileName}: PNGではありません`);
  }

  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);
  const colorType = buffer.readUInt8(25);
  if (width !== manifest.canvas.width || height !== manifest.canvas.height) {
    throw new Error(
      `${fileName}: ${width}x${height}（期待値 ${manifest.canvas.width}x${manifest.canvas.height}）`,
    );
  }
  if (colorType === 4 || colorType === 6) {
    throw new Error(`${fileName}: アルファチャンネルを含んでいます`);
  }

  const hash = createHash("sha256").update(buffer).digest("hex").slice(0, 12);
  console.log(`OK ${fileName} ${width}x${height} RGB sha256:${hash}`);
}
