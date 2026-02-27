#!/usr/bin/env node
/**
 * Xiaohongshu Post Publisher — Playwright Edition
 * Publishes image-text posts via Playwright persistent context (auto-managed Chromium)
 *
 * Usage: node publish.mjs <cover-path> <title> <body-html | @body-file> [--ai-declare] [--headless] [--timeout 30000]
 *
 * First run: Chromium opens, manually log in to creator.xiaohongshu.com.
 * Subsequent runs: session auto-restored from persistent user-data-dir.
 */

import fs from "fs";
import os from "os";
import path from "path";

// Parse args
const args = process.argv.slice(2);
const flags = {};
const positional = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--ai-declare") {
    flags.aiDeclare = true;
  } else if (args[i] === "--headless") {
    flags.headless = true;
  } else if (args[i] === "--timeout") {
    flags.timeout = parseInt(args[++i]);
  } else if (args[i] === "--port") {
    i++; /* ignored, kept for backward compat */
  } else {
    positional.push(args[i]);
  }
}

const [coverPath, title, rawBodyArg] = positional;
const actionTimeout = flags.timeout || 30000;

let finalBodyHtml = rawBodyArg;
if (rawBodyArg && rawBodyArg.startsWith("@")) {
  const filePath = rawBodyArg.substring(1);
  try {
    finalBodyHtml = fs.readFileSync(filePath, "utf8");
  } catch (e) {
    console.error(`Error reading body HTML from file ${filePath}: ${e.message}`);
    process.exit(1);
  }
}

if (!coverPath || !title) {
  console.error(
    "Usage: node publish.mjs <cover-path> <title> <body-html | @body-file> [--ai-declare] [--headless]",
  );
  process.exit(1);
}

if (!fs.existsSync(coverPath)) {
  console.error(`Cover image not found: ${coverPath}`);
  process.exit(1);
}

const USER_DATA_DIR = path.join(os.homedir(), ".openclaw", "browser", "xhs-publisher", "user-data");

async function resolvePlaywright() {
  // Try standard import first (works when run from openclaw repo dir)
  for (const pkg of ["playwright", "playwright-core"]) {
    try {
      return (await import(pkg)).chromium;
    } catch {}
  }
  // Fallback: resolve from openclaw's node_modules (skill scripts live outside the repo)
  const { createRequire } = await import("node:module");
  const openclawDir = path.join(os.homedir(), "Github", "openclaw");
  for (const base of [openclawDir, "/app"]) {
    try {
      const require = createRequire(path.join(base, "package.json"));
      return require("playwright").chromium;
    } catch {}
  }
  return null;
}

async function main() {
  const chromium = await resolvePlaywright();
  if (!chromium) {
    console.error("Playwright not found. Install with: npm install playwright");
    process.exit(1);
  }

  fs.mkdirSync(USER_DATA_DIR, { recursive: true });

  console.log(`Launching Chromium (persistent context)...`);
  console.log(`  User data: ${USER_DATA_DIR}`);
  console.log(`  Headless: ${!!flags.headless}`);

  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    headless: !!flags.headless,
    viewport: { width: 1280, height: 900 },
    locale: "zh-CN",
    args: ["--disable-blink-features=AutomationControlled"],
  });

  const page = context.pages()[0] || (await context.newPage());
  page.setDefaultTimeout(actionTimeout);

  try {
    // Step 1: Navigate to publish page
    console.log("[1/8] Navigating to publish page...");
    await page.goto("https://creator.xiaohongshu.com/publish/publish?source=official", {
      waitUntil: "networkidle",
      timeout: 30000,
    });

    // Wait for any client-side redirects to settle
    await page.waitForTimeout(2000);

    // Check if redirected to login (XHS does client-side redirect after page load)
    const currentUrl = page.url();
    const needsLogin =
      currentUrl.includes("login") ||
      currentUrl.includes("accounts.xiaohongshu") ||
      currentUrl.includes("redirectReason");

    if (needsLogin) {
      console.log("NOT LOGGED IN: Please log in manually in the opened browser window.");
      console.log("Waiting up to 120 seconds for manual login...");
      // Wait for URL to change away from login page
      await page.waitForURL(
        (url) => {
          const s = url.toString();
          return (
            s.includes("creator.xiaohongshu.com") &&
            !s.includes("login") &&
            !s.includes("accounts.xiaohongshu")
          );
        },
        { timeout: 120000 },
      );
      console.log("Login detected! Navigating to publish page...");
      await page.goto("https://creator.xiaohongshu.com/publish/publish?source=official", {
        waitUntil: "networkidle",
        timeout: 30000,
      });
    }

    await page.waitForTimeout(2000);

    // Step 2: Click "上传图文" tab (defaults to "上传视频")
    console.log("[2/8] Switching to image-text tab...");
    // The tabs are: "上传视频" | "上传图文" | "写长文"
    // Need to click the actual tab element, not just any text match
    // XHS tabs can be outside Playwright's viewport; click via JS
    const tabClicked = await page.evaluate(() => {
      const tabs = document.querySelectorAll("div, span, a");
      for (const tab of tabs) {
        if (tab.textContent.trim() === "上传图文") {
          tab.click();
          return true;
        }
      }
      return false;
    });
    if (!tabClicked) throw new Error("Could not find 上传图文 tab");
    await page.waitForTimeout(2000);

    // Step 3: Upload cover image
    console.log("[3/8] Uploading cover image...");
    const fileInput = page.locator('input[type="file"]').first();
    await fileInput.setInputFiles(path.resolve(coverPath));
    console.log("    Image uploaded, waiting for processing...");
    await page.waitForTimeout(5000);

    const hasPreview = await page
      .locator(
        'img[src*="blob"], img[src*="http"], [class*="coverImg"], [class*="image-item"], [class*="upload-preview"]',
      )
      .first()
      .isVisible()
      .catch(() => false);
    console.log(`    Image preview visible: ${hasPreview}`);

    // Step 4: Fill title
    console.log("[4/8] Filling title...");
    const titleInput = page
      .locator(
        'input[placeholder*="填写标题"], input[placeholder*="标题"], textarea[placeholder*="标题"], #post-textarea, [class*="title"] input, [class*="title"] textarea',
      )
      .first();
    await titleInput.waitFor({ state: "visible", timeout: 10000 });
    await titleInput.fill(title);
    const filledTitle = await titleInput.inputValue().catch(() => title);
    console.log(`    Title: "${filledTitle}"`);
    await page.waitForTimeout(1000);

    // Step 5: Fill body (sets rich text content in TipTap/ProseMirror editor)
    console.log("[5/8] Filling body...");
    if (finalBodyHtml) {
      const bodyEditor = page.locator('.tiptap.ProseMirror, [contenteditable="true"]').first();
      const editorVisible = await bodyEditor.isVisible().catch(() => false);
      if (editorVisible) {
        // TipTap editor requires direct DOM manipulation for rich text content
        await bodyEditor.evaluate((el, html) => {
          el.focus();
          el.textContent = "";
          const template = document.createElement("template");
          template.innerHTML = html;
          el.appendChild(template.content);
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }, finalBodyHtml);
        console.log("    Body filled");
      } else {
        console.warn("    WARNING: Could not find body editor");
      }
    }
    await page.waitForTimeout(1000);

    // Step 6: AI declaration (optional)
    if (flags.aiDeclare) {
      console.log("[6/8] Setting AI declaration...");
      await page.evaluate(() => {
        const containers = document.querySelectorAll(
          '[class*="scroll"], [class*="content"], [style*="overflow"]',
        );
        for (const c of containers) {
          c.scrollTop = c.scrollHeight;
        }
        window.scrollTo(0, document.body.scrollHeight);
      });
      await page.waitForTimeout(1000);

      try {
        const declareBtn = page
          .locator("span, div, p, label")
          .filter({
            hasText: /声明.*内容类型|添加内容类型声明/,
          })
          .first();
        await declareBtn.click({ timeout: 3000 });
        await page.waitForTimeout(1500);
      } catch (e) {
        console.log(`    Declaration expand: ${e.message}`);
      }

      const aiResult = await page.evaluate(() => {
        const cbs = document.querySelectorAll('input[type="checkbox"]');
        for (const cb of cbs) {
          const parent = cb.closest("label, div, span");
          if (
            parent &&
            ((parent.textContent || "").includes("AI") ||
              (parent.textContent || "").includes("合成"))
          ) {
            if (!cb.checked) cb.click();
            return "checkbox";
          }
        }
        const items = document.querySelectorAll(
          '[class*="grid-item"], [class*="tag"], [class*="option"]',
        );
        for (const item of items) {
          if (item.textContent.includes("AI")) {
            item.click();
            return "grid-item";
          }
        }
        return "not-found";
      });
      console.log(`    AI declaration: ${aiResult}`);
    } else {
      console.log("[6/8] AI declaration skipped (use --ai-declare to enable)");
    }
    await page.waitForTimeout(1000);

    // Step 7: Pre-publish verification
    console.log("[7/8] Pre-publish check...");
    const titleValue = await page
      .locator('input[placeholder*="填写标题"], input[placeholder*="标题"], #post-textarea')
      .first()
      .inputValue()
      .catch(() => "EMPTY");
    const bodyLen = await page
      .locator('.tiptap.ProseMirror, [contenteditable="true"]')
      .first()
      .evaluate((el) => (el.innerText || "").length)
      .catch(() => 0);
    const hasImage = await page
      .locator('img[src*="blob"], [class*="coverImg"]')
      .first()
      .isVisible()
      .catch(() => false);
    console.log(`    Title: "${titleValue}" | Body: ${bodyLen} chars | Image: ${hasImage}`);
    if (titleValue === "EMPTY" || !titleValue) throw new Error("Title is empty — cannot publish");

    // Step 8: Publish
    console.log("[8/8] Publishing...");
    const publishBtn = page.getByRole("button", { name: /^发布$|^发布笔记$/ });
    try {
      await publishBtn.click({ timeout: 5000 });
    } catch {
      await page.evaluate(() => {
        const btns = document.querySelectorAll("button");
        for (const btn of btns) {
          const text = btn.textContent.trim();
          if (text === "发布" || text === "发布笔记") {
            btn.click();
            break;
          }
        }
      });
    }

    await page.waitForTimeout(5000);
    const finalUrl = page.url();

    if (finalUrl.includes("publish/publish")) {
      const errors = await page.evaluate(() => {
        return (
          [
            ...document.querySelectorAll(
              '[class*="toast"], [class*="error"], [class*="message"], [class*="dialog"]',
            ),
          ]
            .map((e) => e.textContent.trim())
            .filter(Boolean)
            .join("; ") || "none"
        );
      });
      console.error(`FAILED: Still on publish page. Errors: ${errors}`);
      process.exit(1);
    }

    console.log(`SUCCESS: Post published! Redirected to: ${finalUrl}`);
  } finally {
    await context.close();
  }
}

main().catch((err) => {
  console.error(`FATAL: ${err.message}`);
  process.exit(1);
});
