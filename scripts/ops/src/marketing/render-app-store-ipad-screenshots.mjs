import { access, readFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../../..");
const marketingRoot = resolve(repoRoot, "marketing/app-store");
const manifestPath = resolve(marketingRoot, "manifest-ipad.json");
const templatePath = resolve(marketingRoot, "templates/screenshot.html");
const iPadStylesPath = resolve(marketingRoot, "templates/screenshot-ipad.css");

function fileUrl(path) {
  return pathToFileURL(resolve(repoRoot, path)).href;
}

async function main() {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  for (const screen of manifest.screens) {
    await access(resolve(repoRoot, screen.primaryImage));
    if (screen.secondaryImage) await access(resolve(repoRoot, screen.secondaryImage));
  }
  const outputDir = resolve(
    marketingRoot,
    "output",
    manifest.locale,
    manifest.outputDirectory,
  );
  await mkdir(outputDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({
      viewport: manifest.canvas,
      deviceScaleFactor: 1,
    });
    await page.goto(pathToFileURL(templatePath).href, { waitUntil: "load" });
    await page.addStyleTag({ path: iPadStylesPath });

    for (const [index, screen] of manifest.screens.entries()) {
      await page.evaluate(
        ({ screen, theme, primary }) => {
          if (!window.renderScreenshot) {
            throw new Error("Screenshot template is not initialized");
          }
          window.renderScreenshot(screen, theme, { primary });
        },
        {
          screen,
          theme: manifest.theme,
          primary: fileUrl(screen.primaryImage),
        },
      );

      await page.waitForFunction(() =>
        [...document.images]
          .filter((image) => !image.closest("[hidden]"))
          .every((image) => image.complete && image.naturalWidth > 0),
      );

      const sourceSize = await page.locator("#primary-image").evaluate((image) => ({
        width: image.naturalWidth,
        height: image.naturalHeight,
      }));
      if (
        sourceSize.width !== manifest.source.width ||
        sourceSize.height !== manifest.source.height
      ) {
        throw new Error(
          `${screen.id}: invalid source size ${sourceSize.width}x${sourceSize.height}`,
        );
      }

      await page.screenshot({
        path: resolve(outputDir, `${String(index + 1).padStart(2, "0")}-${screen.id}.png`),
        clip: { x: 0, y: 0, width: manifest.canvas.width, height: manifest.canvas.height },
        animations: "disabled",
      });
    }
  } finally {
    await browser.close();
  }

  console.log(`Rendered ${manifest.screens.length} iPad screenshots to ${outputDir}`);
}

await main();
