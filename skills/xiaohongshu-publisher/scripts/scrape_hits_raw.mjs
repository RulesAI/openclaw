import WebSocket from "ws";

async function main() {
  const resp = await fetch("http://127.0.0.1:18800/json");
  const targets = await resp.json();
  const t = targets.find((x) => x.type === "page" && !x.url.includes("worker"));
  if (!t) process.exit(1);

  const ws = new WebSocket(t.webSocketDebuggerUrl);
  await new Promise((r) => ws.on("open", r));

  const cdp = (method, params = {}) => {
    const id = Math.floor(Math.random() * 99999);
    return new Promise((resolve) => {
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

  await cdp("Page.navigate", {
    url: `https://www.xiaohongshu.com/search_result?keyword=${encodeURIComponent("供应链 认知")}&type=1&sort=popularity_desc`,
  }); // Sort by popularity!
  await new Promise((r) => setTimeout(r, 6000));

  for (let i = 0; i < 2; i++) {
    await cdp("Runtime.evaluate", { expression: `window.scrollBy(0, 1000)` });
    await new Promise((r) => setTimeout(r, 2000));
  }

  const r = await cdp("Runtime.evaluate", {
    expression: `
    (() => {
      const links = document.querySelectorAll('a[href*="/explore/"]');
      const results = [];
      links.forEach(a => {
         const t = a.innerText.trim();
         if(t && t.length > 5 && !t.includes('探索')) {
             results.push(t.replace(/\\n/g, ' | '));
         }
      });
      return JSON.stringify(results.slice(0,25));
    })();
  `,
    returnByValue: true,
  });

  console.log(r.result.value);
  ws.close();
}
main();
