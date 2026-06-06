import { chromium, type Browser, type BrowserContext, type Page } from "playwright";
import { existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import "dotenv/config";

const __dirname = dirname(fileURLToPath(import.meta.url));
export const OPS_ROOT = resolve(__dirname, "../..");
export const AUTH_DIR = resolve(OPS_ROOT, ".auth");
export const ASC_STORAGE_STATE = resolve(AUTH_DIR, "asc.json");

if (!existsSync(AUTH_DIR)) {
  mkdirSync(AUTH_DIR, { recursive: true });
}

export interface LaunchOptions {
  storageState?: string;
  headless?: boolean;
}

export async function launch(opts: LaunchOptions = {}): Promise<{
  browser: Browser;
  context: BrowserContext;
  page: Page;
}> {
  const headless = opts.headless ?? process.env.HEADLESS === "true";
  const slowMo = Number(process.env.SLOW_MO ?? 0);
  const browser = await chromium.launch({ headless, slowMo });
  const context = await browser.newContext(
    opts.storageState && existsSync(opts.storageState)
      ? { storageState: opts.storageState }
      : {},
  );
  const page = await context.newPage();
  return { browser, context, page };
}

export async function saveState(context: BrowserContext, path: string): Promise<void> {
  await context.storageState({ path });
}
