#!/usr/bin/env node
/**
 * Xiaohongshu Interaction Bot
 * Opens posts, likes, and leaves thoughtful comments
 * Usage: node interact.mjs <keyword> [--count 10] [--port 18800]
 */
import WebSocket from "ws";

const args = process.argv.slice(2);
const flags = {};
const positional = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--count") flags.count = parseInt(args[++i]);
  else if (args[i] === "--port") flags.port = parseInt(args[++i]);
  else positional.push(args[i]);
}

const keyword = positional[0] || "供应链 AI";
const count = flags.count || 10;
const port = flags.port || 18800;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function createCDP(ws) {
  return (method, params = {}) => {
    const id = Math.floor(Math.random() * 99999);
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error(`Timeout: ${method}`)), 20000);
      const handler = (data) => {
        const msg = JSON.parse(data.toString());
        if (msg.id === id) {
          clearTimeout(timeout);
          ws.off("message", handler);
          msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
        }
      };
      ws.on("message", handler);
      ws.send(JSON.stringify({ id, method, params }));
    });
  };
}

async function evalJS(cdp, expr) {
  const r = await cdp("Runtime.evaluate", {
    expression: expr,
    returnByValue: true,
    awaitPromise: false,
  });
  return r.result?.value;
}

// Comments pool - authentic, value-adding comments from 紫涵's perspective
const commentPool = [
  "写得很实在！我在给客户做供应链咨询的时候也有类似的感受，AI确实在改变这个行业的底层逻辑",
  "作为供应链顾问深有同感，我们最近帮客户上了AI预测系统，效果确实肉眼可见",
  "说到点子上了！我在鹿特丹读供应链硕士的时候还觉得这些是未来，没想到才三年就already落地了",
  "太赞了这个总结！补充一个我的观察：现在不光是大厂，很多中小制造业也开始用AI做库存优化了",
  "同行握手！我做供应链规划的，客户最近都在问AI能不能帮他们降库存成本",
  "分析得很专业！想请教一下你觉得AI在采购环节的应用成熟度怎么样？我最近在研究这个方向",
  "写得好清晰，已收藏！我之前也整理过类似的内容，发现AI+S&OP是目前最容易出效果的场景",
  "这个角度很新！我接触的客户里确实越来越多在考虑这个方向，但落地的时候坑还是挺多的",
  "干货满满！我是做供应链咨询的，你说的这些痛点我在项目里天天遇到，期待后续更新",
  "终于有人把这个讲明白了，转发给我team了，我们正好在做相关的项目方案",
  "很有参考价值！我们公司最近也在评估AI供应链解决方案，你提到的几个点正好是我们关注的",
  "资深供应链人看了表示认同！尤其是你说的那个关于数据质量的部分，这确实是最大的坎",
];

async function main() {
  const resp = await fetch(`http://127.0.0.1:${port}/json`);
  const targets = await resp.json();
  const target = targets.find(
    (t) =>
      t.url?.includes("xiaohongshu.com") &&
      !t.url.includes("worker") &&
      !t.url.includes("sw.js") &&
      !t.url.includes("blob:") &&
      !t.url.includes("creator"),
  );
  if (!target) throw new Error("No xiaohongshu tab found");

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.on("open", resolve);
    ws.on("error", reject);
  });
  const cdp = createCDP(ws);

  // Search for keyword
  console.log(`🔍 Searching: ${keyword}`);
  const searchUrl = `https://www.xiaohongshu.com/search_result?keyword=${encodeURIComponent(keyword)}&type=1&sort=general`;
  await cdp("Page.navigate", { url: searchUrl });
  await sleep(3000);

  // Get post links
  const linksJson = await evalJS(
    cdp,
    `
    JSON.stringify(
      [...document.querySelectorAll('a[href*="/explore/"]')].slice(0, ${count + 5}).map(a => a.href)
    )
  `,
  );
  const links = JSON.parse(linksJson || "[]");
  console.log(`📋 Found ${links.length} posts`);

  let interacted = 0;
  for (let i = 0; i < Math.min(links.length, count); i++) {
    const url = links[i];
    console.log(`\n--- Post ${i + 1}/${count} ---`);
    console.log(`🔗 ${url}`);

    try {
      // Open post
      await cdp("Page.navigate", { url });
      await sleep(3000);

      // Get post title and content
      const postInfo = await evalJS(
        cdp,
        `JSON.stringify({
        title: document.querySelector('#detail-title')?.textContent?.trim() || document.querySelector('[class*="title"]')?.textContent?.trim() || '',
        content: (document.querySelector('#detail-desc')?.textContent || document.querySelector('[class*="desc"]')?.textContent || '').substring(0, 200),
        author: document.querySelector('[class*="author"] [class*="name"], .username')?.textContent?.trim() || '',
        likes: document.querySelector('[class*="like-count"], [class*="count"]')?.textContent?.trim() || ''
      })`,
      );
      const info = JSON.parse(postInfo || "{}");
      console.log(`📝 "${info.title}" by ${info.author}`);

      // Like the post
      const liked = await evalJS(
        cdp,
        `
        (function(){
          var likeBtn = document.querySelector('[class*="like-wrapper"] [class*="like"], .like-icon, [data-type="like"]');
          if (!likeBtn) {
            var spans = document.querySelectorAll('span, div');
            for (var s of spans) {
              if (s.className && s.className.includes && s.className.includes('like') && !s.className.includes('liked')) {
                s.click(); return 'clicked-class';
              }
            }
          }
          if (likeBtn) { likeBtn.click(); return 'clicked'; }
          return 'not-found';
        })()
      `,
      );
      console.log(`❤️ Like: ${liked}`);
      await sleep(1500);

      // Collect/save the post
      const collected = await evalJS(
        cdp,
        `
        (function(){
          var spans = document.querySelectorAll('span, div, button');
          for (var s of spans) {
            if (s.className && s.className.includes && s.className.includes('collect') && !s.className.includes('collected') && !s.className.includes('active')) {
              s.click(); return 'clicked';
            }
          }
          return 'not-found';
        })()
      `,
      );
      console.log(`⭐ Collect: ${collected}`);
      await sleep(1500);

      // Comment
      const comment = commentPool[i % commentPool.length];

      // Find and click comment input
      const commented = await evalJS(
        cdp,
        `
        (function(){
          // Try to find comment input area
          var input = document.querySelector('[class*="comment"] input, [class*="comment"] textarea, [placeholder*="评论"], [placeholder*="说点什么"]');
          if (input) {
            input.click();
            input.focus();
            return 'found-input';
          }
          // Try clicking "说点什么" area
          var els = document.querySelectorAll('div, span, input');
          for (var el of els) {
            var ph = el.placeholder || el.textContent;
            if (ph && (ph.includes('说点什么') || ph.includes('评论'))) {
              el.click();
              return 'found-placeholder: ' + ph.substring(0, 30);
            }
          }
          return 'not-found';
        })()
      `,
      );
      console.log(`💬 Comment area: ${commented}`);
      await sleep(1000);

      if (commented && commented !== "not-found") {
        // Type comment
        await evalJS(
          cdp,
          `
          (function(){
            var input = document.querySelector('[class*="comment"] input, [class*="comment"] textarea, [placeholder*="评论"], [placeholder*="说点什么"], [contenteditable="true"]');
            if (input) {
              if (input.tagName === 'INPUT' || input.tagName === 'TEXTAREA') {
                var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set ||
                             Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set;
                setter.call(input, ${JSON.stringify(comment)});
                input.dispatchEvent(new Event('input', {bubbles:true}));
              } else {
                input.textContent = ${JSON.stringify(comment)};
                input.dispatchEvent(new Event('input', {bubbles:true}));
              }
              return true;
            }
            return false;
          })()
        `,
        );
        await sleep(500);

        // Click send/submit button
        const sent = await evalJS(
          cdp,
          `
          (function(){
            var btns = document.querySelectorAll('button, [class*="submit"], [class*="send"]');
            for (var b of btns) {
              var t = b.textContent.trim();
              if (t === '发送' || t === '提交' || t === '发布评论') {
                b.click(); return 'sent: ' + t;
              }
            }
            return 'no-send-btn';
          })()
        `,
        );
        console.log(`💬 Comment sent: ${sent}`);
      }

      interacted++;
      await sleep(2000 + Math.random() * 3000); // Random delay to look human
    } catch (e) {
      console.log(`⚠️ Error on post ${i + 1}: ${e.message}`);
    }
  }

  console.log(`\n✅ Done! Interacted with ${interacted}/${count} posts`);
  ws.close();
}

main().catch((err) => {
  console.error(`FATAL: ${err.message}`);
  process.exit(1);
});
