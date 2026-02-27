import WebSocket from "ws";
async function main() {
  const resp = await fetch("http://127.0.0.1:18800/json");
  const targets = await resp.json();
  const t = targets.find(
    (x) =>
      x.type === "page" &&
      (x.url.includes("xiaohongshu.com") || x.url === "about:blank") &&
      !x.url.includes("worker") &&
      !x.url.includes("sw.js"),
  );
  const ws = new WebSocket(t.webSocketDebuggerUrl);
  await new Promise((r) => ws.on("open", r));

  function cdp(method, params = {}) {
    const id = Math.floor(Math.random() * 99999);
    return new Promise((resolve) => {
      const h = (d) => {
        const m = JSON.parse(d.toString());
        if (m.id === id) {
          ws.off("message", h);
          resolve(m.result);
        }
      };
      ws.on("message", h);
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await cdp("Page.navigate", { url: "https://www.xiaohongshu.com/explore" });
  await new Promise((r) => setTimeout(r, 4000));

  // Scraper feed
  console.log("Warming up account on explore feed...");
  for (let i = 0; i < 3; i++) {
    await cdp("Runtime.evaluate", { expression: "window.scrollBy(0, 800)" });
    await new Promise((r) => setTimeout(r, 2000));

    // Like a random visible post from feed (hover and click like)
    // Actually just doing random scrolling builds basic cookie history
  }

  // Search for 供应链
  console.log("Searching for supply chain content...");
  await cdp("Page.navigate", {
    url: "https://www.xiaohongshu.com/search_result?keyword=%E4%BE%9B%E5%BA%94%E9%93%BE&type=1",
  });
  await new Promise((r) => setTimeout(r, 5000));
  for (let i = 0; i < 5; i++) {
    await cdp("Runtime.evaluate", { expression: "window.scrollBy(0, 1000)" });
    await new Promise((r) => setTimeout(r, 2000));
  }

  // Go into a few posts and just wait
  const links = await cdp("Runtime.evaluate", {
    expression: `
    [...document.querySelectorAll('a[href*="/explore/"]')]
      .map(a => a.href)
      .filter((v, i, a) => a.indexOf(v) === i)
      .slice(0, 5)
  `,
    returnByValue: true,
  });

  const urls = links.result.value || [];
  for (const url of urls) {
    console.log("Reading post:", url);
    await cdp("Page.navigate", { url });
    await new Promise((r) => setTimeout(r, 5000));
    for (let i = 0; i < 3; i++) {
      await cdp("Runtime.evaluate", { expression: "window.scrollBy(0, 500)" });
      await new Promise((r) => setTimeout(r, 1500));
    }

    // Try to click like if easy
    await cdp("Runtime.evaluate", {
      expression: `
        const like = document.querySelector('.like-wrapper, .like');
        if(like) like.click();
      `,
    });
    await new Promise((r) => setTimeout(r, 2000));
  }

  console.log("Warmup complete.");
  ws.close();
}
main();
