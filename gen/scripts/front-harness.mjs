import fs from "node:fs";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const genDir = path.resolve(here, "..");
const repoRoot = path.resolve(genDir, "..");
const templateDir = path.join(here, "front-scratch");

function run(command, args, cwd, logPath) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
  });
  fs.writeFileSync(logPath, `${result.stdout ?? ""}${result.stderr ?? ""}`);
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed; see ${logPath}`);
  }
}

function copyDirectoryContents(source, destination) {
  fs.mkdirSync(destination, { recursive: true });
  for (const name of fs.readdirSync(source)) {
    fs.cpSync(path.join(source, name), path.join(destination, name), {
      recursive: true,
    });
  }
}

export function prepareFrontScratch(label) {
  const work = path.join(genDir, "_out", label);
  fs.mkdirSync(work, { recursive: true });
  copyDirectoryContents(templateDir, work);
  copyDirectoryContents(
    path.join(genDir, "fixtures/article/www/src"),
    path.join(work, "src"),
  );
  fs.mkdirSync(path.join(work, "public"), { recursive: true });

  const tomlPath = path.join(work, "gleam.toml");
  fs.writeFileSync(
    tomlPath,
    fs.readFileSync(tomlPath, "utf8").replaceAll("__REPO_PATH__", repoRoot),
  );

  run(
    "gleam",
    ["build", "--target", "javascript"],
    work,
    path.join(work, "gleam-build.txt"),
  );
  run(
    "npx",
    ["--yes", "esbuild", "web/browser_entry.mjs", "--bundle", "--format=esm", "--outfile=public/client.mjs"],
    work,
    path.join(work, "esbuild.txt"),
  );
  return work;
}

export async function startFrontWorker(work, port) {
  const child = spawn(
    "npx",
    ["--yes", "wrangler", "dev", "--local", "--port", String(port), "--config", "wrangler.jsonc"],
    {
      cwd: work,
      env: { ...process.env, NO_COLOR: "1" },
      stdio: ["ignore", "pipe", "pipe"],
      detached: true,
    },
  );

  let workerOutput = "";
  child.stdout.on("data", (chunk) => {
    workerOutput += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    workerOutput += chunk.toString();
  });

  const baseUrl = `http://127.0.0.1:${port}`;
  const closed = new Promise((resolve) => child.once("close", resolve));
  let readyResponse;
  for (let attempt = 0; attempt < 80; attempt += 1) {
    if (child.exitCode !== null) {
      throw new Error(`wrangler exited before ready\n${workerOutput}`);
    }
    try {
      readyResponse = await fetch(`${baseUrl}/article/42`, {
        signal: AbortSignal.timeout(1000),
      });
      if (readyResponse.status === 200) {
        await readyResponse.arrayBuffer();
        break;
      }
    } catch (_error) {
      // Wrangler is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  if (!readyResponse || readyResponse.status !== 200) {
    throw new Error(`wrangler did not become ready\n${workerOutput}`);
  }

  return {
    baseUrl,
    async stop() {
      const signalGroup = (signal) => {
        if (child.exitCode !== null) return;
        try {
          process.kill(-child.pid, signal);
        } catch (_error) {
          // The process group may already have exited.
        }
      };
      signalGroup("SIGTERM");
      await Promise.race([
        closed,
        new Promise((resolve) => setTimeout(resolve, 2000)),
      ]);
      signalGroup("SIGKILL");
      fs.writeFileSync(path.join(work, "wrangler.txt"), workerOutput);
    },
  };
}

export { repoRoot };
