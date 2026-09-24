#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { prepareFrontScratch, startFrontWorker } from "./front-harness.mjs";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function reset(worker) {
  await fetch(worker.baseUrl + "/__reset");
}

async function appRequests(worker) {
  return await (await fetch(worker.baseUrl + "/__requests")).json();
}

export async function verifyFrontShell() {
  const publicWork = prepareFrontScratch("verify", "public");
  let publicWorker;
  let adminWorker;
  try {
    publicWorker = await startFrontWorker(publicWork, 8797);

    await reset(publicWorker);
    const traceResponse = await fetch(
      publicWorker.baseUrl + "/article/42?widget=summary&term=trace",
      { headers: { cookie: "subject" } },
    );
    const traceHtml = await traceResponse.text();
    const traceRequests = await appRequests(publicWorker);
    const traceLines = traceRequests.map(
      (request) => request.method + " " + request.path,
    );
    fs.writeFileSync(
      path.join(publicWork, "requests.txt"),
      traceLines.join("\n") + "\n",
    );
    assert(traceResponse.status === 200, "public trace status: " + traceResponse.status);
    assert(
      JSON.stringify(traceLines) ===
        JSON.stringify([
          "GET /api/session",
          "GET /api/widgets?widget=summary&slug=42",
          "GET /api/articles/42",
          "GET /api/articles",
        ]),
      "public request order: " + JSON.stringify(traceLines),
    );
    assert(
      traceRequests[0].cookie === "subject",
      "cookie was not forwarded unchanged to /api/session",
    );
    assert(traceHtml.includes('data-slug="42"'), "Path Var is missing from the view");
    assert(traceHtml.includes('data-term="trace"'), "Query Var is missing from the view");
    assert(
      traceHtml.includes('data-subject="reader-handle"'),
      "Session Var is missing from the view",
    );
    assert(
      traceHtml.includes('data-www-origin="https://public.example"'),
      "Origin Var is missing from the view",
    );
    assert(
      traceHtml.includes('data-auth-origin="https://identity.example"'),
      "AuthOrigin Var is missing from the view",
    );
    assert(
      !traceHtml.includes("must-not-render"),
      "the shell read a session field other than subject.handle / subject.id",
    );
    console.log("SSR REQUESTS: PASS (" + JSON.stringify(traceLines) + ")");
    console.log("PATH / QUERY / SESSION / ORIGIN / AUTH ORIGIN: PASS");

    for (const cookie of ["", "no-subject", "missing-handle"]) {
      await reset(publicWorker);
      const options = cookie === "" ? {} : { headers: { cookie } };
      const response = await fetch(publicWorker.baseUrl + "/article/42", options);
      const html = await response.text();
      const requests = await appRequests(publicWorker);
      const subjectAttribute = html.match(/\bdata-subject(?:="([^"]*)")?/);
      assert(response.status === 200, cookie + " public status: " + response.status);
      assert(
        subjectAttribute && (subjectAttribute[1] ?? "") === "",
        cookie + " public Session Var did not render None",
      );
      assert(
        requests.filter((request) => request.path === "/api/session").length === 1,
        cookie + " public Page did not read session exactly once",
      );
    }
    console.log("PUBLIC SESSION: PASS (anonymous, subject absent, and handle absent render None)");

    await reset(publicWorker);
    const noSession = await fetch(publicWorker.baseUrl + "/status");
    const noSessionRequests = await appRequests(publicWorker);
    assert(noSession.status === 200, "no-session Page status: " + noSession.status);
    assert(
      noSessionRequests.filter((request) => request.path === "/api/session").length === 0,
      "Page without Session Var called /api/session",
    );
    console.log("NO SESSION VAR: PASS (0 /api/session requests)");

    for (const [cookie, envName] of [
      ["missing-public-origin", "PUBLIC_PUBLIC_ORIGIN"],
      ["missing-idp-origin", "PUBLIC_IDP_ORIGIN"],
    ]) {
      const response = await fetch(publicWorker.baseUrl + "/article/42", {
        headers: { cookie },
      });
      const body = await response.text();
      assert(response.status === 500, cookie + " status: " + response.status);
      assert(body.includes(envName), cookie + " response did not name " + envName);
    }
    console.log("MISSING ORIGIN: PASS (500 body names the missing env)");
  } finally {
    if (publicWorker) await publicWorker.stop();
  }

  const adminWork = prepareFrontScratch("verify-admin", "admin");
  try {
    adminWorker = await startFrontWorker(adminWork, 8798, "/home", 401);
    for (const cookie of ["", "no-subject", "missing-handle"]) {
      await reset(adminWorker);
      const options = cookie === "" ? {} : { headers: { cookie } };
      const response = await fetch(adminWorker.baseUrl + "/home", options);
      const body = await response.text();
      const requests = await appRequests(adminWorker);
      assert(response.status === 401, cookie + " admin status: " + response.status);
      assert(body.includes("unauthorized"), cookie + " admin response body is wrong");
      assert(
        response.headers.get("location") === null,
        cookie + " admin response redirected",
      );
      assert(
        requests.filter((request) => request.path === "/api/session").length === 1,
        cookie + " admin Page did not read session exactly once",
      );
    }

    await reset(adminWorker);
    const signedIn = await fetch(adminWorker.baseUrl + "/home", {
      headers: { cookie: "subject" },
    });
    const signedInBody = await signedIn.text();
    const signedInRequests = await appRequests(adminWorker);
    fs.writeFileSync(
      path.join(adminWork, "requests.txt"),
      signedInRequests
        .map((request) => request.method + " " + request.path)
        .join("\n") + "\n",
    );
    assert(signedIn.status === 200, "signed-in admin status: " + signedIn.status);
    assert(
      signedInBody.includes("Signed-in subject: reader-handle"),
      "admin Session Var is missing from the view",
    );
    assert(
      signedInRequests.filter((request) => request.path === "/api/session").length === 1,
      "admin Page read session more than once",
    );
    console.log("ADMIN SESSION: PASS (anonymous and absent fields return 401; signed-in returns 200)");
  } finally {
    if (adminWorker) await adminWorker.stop();
  }
}
