import { access, readFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../../..");
const marketingRoot = resolve(repoRoot, "marketing/app-store");
const manifestPath = resolve(marketingRoot, "manifest.json");
const templatePath = resolve(marketingRoot, "templates/screenshot.html");

function fileUrl(path) {
  return pathToFileURL(resolve(repoRoot, path)).href;
}

async function main() {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  for (const screen of manifest.screens) {
    await access(resolve(repoRoot, screen.primaryImage));
    if (screen.secondaryImage) await access(resolve(repoRoot, screen.secondaryImage));
  }
  const outputDir = resolve(marketingRoot, "output", manifest.locale, "iphone-6.9");
  await mkdir(outputDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({
      viewport: manifest.canvas,
      deviceScaleFactor: 1,
    });
    await page.goto(pathToFileURL(templatePath).href, { waitUntil: "load" });

    for (const [index, screen] of manifest.screens.entries()) {
      await page.evaluate(
        ({ screen, theme, urls }) => {
          if (!window.renderScreenshot) {
            throw new Error("Screenshot template is not initialized");
          }
          window.renderScreenshot(screen, theme, urls);
        },
        {
          screen,
          theme: manifest.theme,
          urls: {
            primary: fileUrl(screen.primaryImage),
            secondary: screen.secondaryImage ? fileUrl(screen.secondaryImage) : undefined,
          },
        },
      );

      await page.waitForFunction(() =>
        [...document.images].filter((image) => !image.closest("[hidden]")).every((image) => image.complete && image.naturalWidth > 0),
      );
      await page.screenshot({
        path: resolve(outputDir, `${String(index + 1).padStart(2, "0")}-${screen.id}.png`),
        clip: { x: 0, y: 0, width: manifest.canvas.width, height: manifest.canvas.height },
        animations: "disabled",
      });
    }
  } finally {
    await browser.close();
  }

  console.log(`Rendered ${manifest.screens.length} screenshots to ${outputDir}`);
}

await main();
