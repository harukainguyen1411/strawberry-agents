const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3847;
const DATA_DIR = process.env.DATA_DIR || "/data";
const TASKS_FILE = path.join(DATA_DIR, "tasklist.json");
const HTML_FILE = path.join(__dirname, "tasklist.html");

// Ensure data directory and file exist
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(TASKS_FILE)) fs.writeFileSync(TASKS_FILE, "[]");

const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, PUT, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.url === "/" || req.url === "/index.html") {
    fs.readFile(HTML_FILE, (err, data) => {
      if (err) { res.writeHead(500); res.end("Error reading HTML"); return; }
      res.writeHead(200, { "Content-Type": "text/html" });
      res.end(data);
    });
    return;
  }

  if (req.url === "/api/tasks" && req.method === "GET") {
    fs.readFile(TASKS_FILE, "utf8", (err, data) => {
      if (err) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end("[]");
        return;
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(data);
    });
    return;
  }

  if (req.url === "/api/tasks" && req.method === "PUT") {
    let body = "";
    req.on("data", chunk => { body += chunk; });
    req.on("end", () => {
      try {
        JSON.parse(body);
        fs.writeFile(TASKS_FILE, body, err => {
          if (err) { res.writeHead(500); res.end("Write failed"); return; }
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end('{"ok":true}');
        });
      } catch (e) {
        res.writeHead(400);
        res.end("Invalid JSON");
      }
    });
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

server.listen(PORT, () => {
  console.log("Task list server running on port " + PORT);
});
