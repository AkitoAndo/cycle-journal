import "dotenv/config";
import { ASC_STORAGE_STATE, launch } from "../lib/browser.js";

async function main() {
  const { browser, page } = await launch({ storageState: ASC_STORAGE_STATE });
  await page.goto("https://appstoreconnect.apple.com/access/integrations/api", {
    waitUntil: "domcontentloaded",
  });
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
  await page.waitForTimeout(2000);

  // 「アクティブ」見出しを探し、その近くの clickable要素を全部出す
  const targetSelector = "h2, h3, h4";
  const result = await page.evaluate(() => {
    const out: string[] = [];
    const headings = Array.from(document.querySelectorAll("h2, h3, h4")).filter((h) =>
      (h.textContent || "").includes("アクティブ"),
    );
    for (const h of headings) {
      const parent = h.parentElement;
      if (!parent) continue;
      const html = parent.outerHTML.slice(0, 2000);
      out.push("---heading---\n" + (h.textContent || "") + "\n---parent outerHTML---\n" + html);
    }
    return out;
  });
  result.forEach((s) => console.log(s));
  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
