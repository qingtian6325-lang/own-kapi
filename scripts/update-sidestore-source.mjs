#!/usr/bin/env node
/**
 * Upsert one app version into sidestore/apps.json (newest-first).
 *
 * Usage:
 *   node scripts/update-sidestore-source.mjs \
 *     --version 1.3.10 \
 *     --date 2026-11-14T08:11:13Z \
 *     --download-url https://github.com/.../MimiMoney-iOS-v1.3.10.ipa \
 *     --size 4036782 \
 *     --notes "What's new" \
 *     [--build-version 123] \
 *     [--source sidestore/apps.json]
 */
import fs from "node:fs";
import path from "node:path";

function argValue(flag) {
  const i = process.argv.indexOf(flag);
  if (i === -1 || i + 1 >= process.argv.length) return undefined;
  return process.argv[i + 1];
}

function requireArg(flag) {
  const v = argValue(flag);
  if (!v) {
    console.error(`Missing required ${flag}`);
    process.exit(1);
  }
  return v;
}

const sourcePath = path.resolve(
  process.cwd(),
  argValue("--source") || "sidestore/apps.json"
);
const version = requireArg("--version").replace(/^v/, "");
const date = requireArg("--date");
const downloadURL = requireArg("--download-url");
const size = Number(requireArg("--size"));
const notes = argValue("--notes") || `咪咪记账 iOS v${version}`;
const buildVersion = argValue("--build-version");
const minOSVersion = argValue("--min-os") || "17.0";

if (!Number.isFinite(size) || size <= 0) {
  console.error(`Invalid --size: ${argValue("--size")}`);
  process.exit(1);
}

const raw = fs.readFileSync(sourcePath, "utf8");
const source = JSON.parse(raw);
if (!Array.isArray(source.apps) || source.apps.length === 0) {
  console.error("apps.json has no apps[] entry");
  process.exit(1);
}

const app =
  source.apps.find((a) => a.bundleIdentifier === "com.jinghao.mimimoney") ||
  source.apps[0];
if (!Array.isArray(app.versions)) app.versions = [];

const entry = {
  version,
  date,
  localizedDescription: notes,
  downloadURL,
  size,
  minOSVersion,
};
if (buildVersion) entry.buildVersion = String(buildVersion);

app.versions = app.versions.filter((v) => String(v.version) !== version);
app.versions.unshift(entry);

fs.writeFileSync(sourcePath, `${JSON.stringify(source, null, 2)}\n`);
console.log(
  `Updated ${sourcePath}: v${version} → ${downloadURL} (${size} bytes); ${app.versions.length} versions total`
);
