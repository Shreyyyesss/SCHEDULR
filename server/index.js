import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import { spawn } from "child_process";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, "../public")));

const PROLOG_PATH = path.join(__dirname, "../prolog/scheduler.pl");
const TEMP_FACTS_PATH = path.join(__dirname, "../prolog/temp_facts.pl");

// ✅ Root route
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "../public/index.html"));
});

// ✅ Add availability — with safe logging + GNU Prolog support
app.post("/schedule", (req, res) => {
  console.log("📩 /schedule route hit:", req.body);

  const { name, start, end } = req.body;
  if (!name || !start || !end)
    return res.status(400).json({ error: "Missing fields" });

  const runner = `
:- initialization(run_main).

run_main :-
  consult('${PROLOG_PATH.replace(/\\/g, "/")}'),
  ( file_exists('${TEMP_FACTS_PATH.replace(/\\/g, "/")}') ->
      consult('${TEMP_FACTS_PATH.replace(/\\/g, "/")}')
  ;   true
  ),
  assertz(availability('${name}', ${start}, ${end})),
  tell('${TEMP_FACTS_PATH.replace(/\\/g, "/")}'),
  listing(availability),
  told,
  writeln('✅ Added ${name} ${start}-${end}'),
  halt.
`;

  const tmpFile = path.join(__dirname, "../prolog/run_add.pl");
  fs.writeFileSync(tmpFile, runner);

  // 🟢 Log the command we are running
  const command = `gprolog --batch --consult "${tmpFile.replace(/\\/g, "/")}"`;
  console.log("🟢 Running:", command);

  const proc = spawn(command, {
    shell: true,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let output = "";
  proc.stdout.on("data", (data) => (output += data.toString()));
  proc.stderr.on("data", (err) =>
    console.error("❌ Prolog stderr (add):", err.toString())
  );
  proc.on("close", () => {
    console.log("🧾 Prolog (add) output:\n", output);
    res.json({
      success: true,
      message: `✅ Availability for ${name} saved successfully!`,
    });
  });
});

// ✅ Clear all availabilities — safe, silent
app.get("/clear", (req, res) => {
  const runner = `
:- initialization(run_main).

run_main :-
  consult('${PROLOG_PATH.replace(/\\/g, "/")}'),
  ( file_exists('${TEMP_FACTS_PATH.replace(/\\/g, "/")}') ->
      consult('${TEMP_FACTS_PATH.replace(/\\/g, "/")}')
  ;   writeln('⚠️ No facts file found, skipping consult.')
  ),
  retractall(availability(_, _, _)),
  tell('${TEMP_FACTS_PATH.replace(/\\/g, "/")}'),
  listing(availability),
  told,
  writeln('✅ All availabilities cleared!'),
  halt.
`;

  const tmpFile = path.join(__dirname, "../prolog/run_clear.pl");
  fs.writeFileSync(tmpFile, runner);

  const command = `gprolog --batch --consult "${tmpFile.replace(/\\/g, "/")}"`;
  console.log("🟢 Running:", command);

  const proc = spawn(command, {
    shell: true,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let output = "";
  proc.stdout.on("data", (data) => (output += data.toString()));
  proc.stderr.on("data", (err) =>
    console.error("❌ Prolog stderr (clear):", err.toString())
  );
  proc.on("close", () => {
    console.log("🧾 Prolog (clear) output:\n", output);
    res.json({ success: true, message: "✅ All availabilities cleared!" });
  });
});

// ✅ Find best slot — silent
app.post("/find-best-slot", (req, res) => {
  const { startWindow = 9.0, endWindow = 18.0 } = req.body;

  const runner = `
:- initialization(run_main).

run_main :-
  consult('${PROLOG_PATH.replace(/\\/g, "/")}'),
  ( file_exists('${TEMP_FACTS_PATH.replace(/\\/g, "/")}') ->
      consult('${TEMP_FACTS_PATH.replace(/\\/g, "/")}')
  ;   writeln('⚠️ No facts file found, skipping consult.')
  ),
  ( best_slots(${startWindow}, ${endWindow}, 0.5, 0.5, BestStart, BestCount, BestPeople) ->
      write('BestStart='), write(BestStart), nl,
      write('Count='), write(BestCount), nl,
      write('People='), write(BestPeople), nl
  ;   writeln('No valid slots found')
  ),
  halt.
`;

  const tmpFile = path.join(__dirname, "../prolog/run_best.pl");
  fs.writeFileSync(tmpFile, runner);

  const command = `gprolog --batch --consult "${tmpFile.replace(/\\/g, "/")}"`;
  console.log("🟢 Running:", command);

  const proc = spawn(command, {
    shell: true,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let output = "";
  proc.stdout.on("data", (data) => (output += data.toString()));
  proc.stderr.on("data", (err) =>
    console.error("❌ Prolog stderr (best):", err.toString())
  );
  proc.on("close", () => {
    console.log("🧾 Prolog (best) output:\n", output);
    const lines = output.split("\n").filter(Boolean);
    const result = {};
    lines.forEach((line) => {
      const [k, v] = line.split("=");
      if (k && v) result[k.trim()] = v.trim();
    });
    res.json({ success: true, message: "✅ Best slot found!", result });
  });
});

// ✅ List all availabilities
app.get("/availabilities", (req, res) => {
  try {
    if (!fs.existsSync(TEMP_FACTS_PATH)) return res.json([]);
    const content = fs.readFileSync(TEMP_FACTS_PATH, "utf8");
    const matches = [
      ...content.matchAll(/availability\('(.+?)',\s*([\d.]+),\s*([\d.]+)\)\./g),
    ];
    const availabilities = matches.map((m) => ({
      name: m[1],
      start: parseFloat(m[2]),
      end: parseFloat(m[3]),
    }));
    res.json(availabilities);
  } catch (err) {
    console.error("⚠️ Read error:", err);
    res.json([]);
  }
});

app.listen(5000, () =>
  console.log("🚀 Smart Scheduler running at http://localhost:5000")
);
