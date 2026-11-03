import { readFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../../../..");
const marketingRoot = resolve(repoRoot, "marketing/app-store");
const proposalRoot = resolve(marketingRoot, "proposals");
const manifestPath = resolve(proposalRoot, "manifest.json");
const variantsCssPath = resolve(proposalRoot, "variants.css");
const screenshotTemplatePath = resolve(marketingRoot, "templates/screenshot.html");
const boardTemplatePath = resolve(marketingRoot, "templates/proposal-board.html");

function fileUrl(path) {
  return pathToFileURL(resolve(repoRoot, path)).href;
}

function outputFileName(index, screen) {
  return `${String(index + 1).padStart(2, "0")}-${screen.id}.png`;
}

async function waitForImages(page) {
  await page.waitForFunction(() =>
    [...document.images]
      .filter((image) => !image.closest("[hidden]"))
      .every((image) => image.complete && image.naturalWidth > 0),
  );
}

async function verifySourceGeometry(page, expectedSourceSize) {
  await page.evaluate((expected) => {
    const canvasRect = document.querySelector("#canvas").getBoundingClientRect();
    const images = [...document.images].filter((image) => !image.closest("[hidden]"));
    for (const image of images) {
      const imageRect = image.getBoundingClientRect();
      const screenRect = image.closest(".screen-main").getBoundingClientRect();
      const phoneRect = image.closest(".phone").getBoundingClientRect();
      const sourceRatio = image.naturalWidth / image.naturalHeight;
      const renderedRatio = imageRect.width / imageRect.height;

      if (image.naturalWidth !== expected.width || image.naturalHeight !== expected.height) {
        throw new Error(
          `Unexpected source size: ${image.naturalWidth}x${image.naturalHeight}; expected ${expected.width}x${expected.height}`,
        );
      }
      if (Math.abs(sourceRatio - renderedRatio) > 1e-4) {
        throw new Error(`Source image aspect ratio changed: ${sourceRatio} → ${renderedRatio}`);
      }
      if (getComputedStyle(image).transform !== "none") {
        throw new Error("Source image transform must remain none");
      }
      if (Math.abs(imageRect.width - screenRect.width) > 1 || Math.abs(imageRect.height - screenRect.height) > 1) {
        throw new Error("Source image and screen container dimensions diverged");
      }
      if (
        phoneRect.left < canvasRect.left ||
        phoneRect.top < canvasRect.top ||
        phoneRect.right > canvasRect.right ||
        phoneRect.bottom > canvasRect.bottom
      ) {
        throw new Error("Phone frame is outside the App Store canvas");
      }
    }
  }, expectedSourceSize);
}

async function main() {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  const outputDir = resolve(proposalRoot, "output");
  await mkdir(outputDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  try {
    const screenshotPage = await browser.newPage({
      viewport: manifest.canvas,
      deviceScaleFactor: 1,
    });
    await screenshotPage.goto(pathToFileURL(screenshotTemplatePath).href, { waitUntil: "load" });
    await screenshotPage.addStyleTag({ path: variantsCssPath });

    for (const plan of manifest.plans) {
      const planDir = resolve(outputDir, plan.id);
      await mkdir(planDir, { recursive: true });
      const planImagePaths = [];

      for (const [index, screen] of plan.screens.entries()) {
        await screenshotPage.evaluate(
          ({ screen, theme, urls, planStyle, step }) => {
            if (!window.renderScreenshot) {
              throw new Error("Screenshot template is not initialized");
            }
            window.renderScreenshot(screen, theme, urls);
            document.querySelector("#canvas").classList.add(`proposal-${planStyle}`, `proposal-step-${step}`);
          },
          {
            screen,
            theme: manifest.theme,
            urls: {
              primary: fileUrl(screen.primaryImage),
              secondary: screen.secondaryImage ? fileUrl(screen.secondaryImage) : undefined,
            },
            planStyle: plan.style,
            step: index + 1,
          },
        );
        await waitForImages(screenshotPage);
        await verifySourceGeometry(screenshotPage, { width: 1206, height: 2622 });

        const imagePath = resolve(planDir, outputFileName(index, screen));
        await screenshotPage.screenshot({
          path: imagePath,
          clip: { x: 0, y: 0, width: manifest.canvas.width, height: manifest.canvas.height },
          animations: "disabled",
        });
        planImagePaths.push(imagePath);
      }

      const boardPage = await browser.newPage({
        viewport: manifest.board,
        deviceScaleFactor: 1,
      });
      await boardPage.goto(pathToFileURL(boardTemplatePath).href, { waitUntil: "load" });
      await boardPage.evaluate(
        ({ plan, imageUrls }) => {
          if (!window.renderProposalBoard) {
            throw new Error("Proposal board template is not initialized");
          }
          window.renderProposalBoard(plan, imageUrls);
        },
        {
          plan,
          imageUrls: planImagePaths.map((path) => pathToFileURL(path).href),
        },
      );
      await waitForImages(boardPage);
      await boardPage.screenshot({
        path: resolve(outputDir, `${plan.id}-overview.png`),
        clip: { x: 0, y: 0, width: manifest.board.width, height: manifest.board.height },
        animations: "disabled",
      });
      await boardPage.close();
    }
  } finally {
    await browser.close();
  }

  console.log(`Rendered ${manifest.plans.length} proposal sets to ${outputDir}`);
}

await main();
