import WebSocket from "ws";

async function main() {
  const resp = await fetch("http://127.0.0.1:18800/json");
  const targets = await resp.json();
  const t = targets.find(
    (x) => x.type === "page" && !x.url.includes("worker") && !x.url.includes("sw.js"),
  );
  if (!t) {
    console.log("No Chrome tab found");
    process.exit(1);
  }

  const ws = new WebSocket(t.webSocketDebuggerUrl);
  await new Promise((r) => ws.on("open", r));

  const cdp = (method, params = {}) => {
    const id = Math.floor(Math.random() * 99999);
    return new Promise((resolve, reject) => {
      const handler = (d) => {
        const m = JSON.parse(d.toString());
        if (m.id === id) {
          ws.off("message", handler);
          resolve(m.result);
        }
      };
      ws.on("message", handler);
      ws.send(JSON.stringify({ id, method, params }));
    });
  };

  // Search logic
  const keywords = ["供应链 建议", "采购 经验", "供应链 痛点", "供应链 职场"];
  let allHits = [];

  for (const kw of keywords) {
    console.log(`\nSearching for: ${kw}`);
    await cdp("Page.navigate", {
      url: `https://www.xiaohongshu.com/search_result?keyword=${encodeURIComponent(kw)}&type=1&sort=general`,
    });

    // wait for load
    await new Promise((r) => setTimeout(r, 6000));

    // Scroll a few times to load more hits
    for (let i = 0; i < 3; i++) {
      await cdp("Runtime.evaluate", {
        expression: `window.scrollBy(0, document.body.scrollHeight)`,
      });
      await new Promise((r) => setTimeout(r, 2000));
    }

    // Extract notes
    const r = await cdp("Runtime.evaluate", {
      expression: `
      (() => {
        const cards = document.querySelectorAll('section, .note-item');
        const results = [];
        cards.forEach(card => {
          const title = card.querySelector('.title, .note-title, a.title')?.textContent?.trim();
          const likesStr = card.querySelector('.count, .like, .like-count')?.textContent?.trim();
          // parse k, w etc
          let likes = 0;
          if (likesStr) {
            if (likesStr.includes('w') || likesStr.includes('万')) {
              likes = parseFloat(likesStr) * 10000;
            } else if (likesStr.includes('k')) {
              likes = parseFloat(likesStr) * 1000;
            } else if (likesStr.includes('+')) {
                likes = parseFloat(likesStr.replace('+',''));
            } else {
              likes = parseInt(likesStr) || 0;
            }
          }
          if (title && likes > 200) { // filter only hitting posts with >= 200 likes
              results.push({title, likes, likesStr});
          }
        });
        return JSON.stringify(results);
      })();
    `,
      returnByValue: true,
    });

    const items = JSON.parse(r?.result?.value || "[]");
    allHits = allHits.concat(items);
  }

  // Deduplicate and Sort
  const unique = [];
  const titles = new Set();
  for (const h of allHits) {
    if (!titles.has(h.title)) {
      titles.add(h.title);
      unique.push(h);
    }
  }

  unique.sort((a, b) => b.likes - a.likes);

  console.log("\nTop Hits found:");
  unique.slice(0, 15).forEach((h, i) => console.log(`${i + 1}. [${h.likesStr}赞] ${h.title}`));

  ws.close();
}
main().catch(console.error);
