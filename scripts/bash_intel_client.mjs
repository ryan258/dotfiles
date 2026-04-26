#!/usr/bin/env node

import { spawn } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import { readdirSync } from "node:fs";
import { basename, dirname, extname, join, resolve } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(process.env.DOTFILES_DIR || join(SCRIPT_DIR, ".."));
const TIMEOUT_MS = Number(process.env.BASH_INTEL_TIMEOUT_MS || "30000");

const SYMBOL_KIND = {
  1: "File",
  2: "Module",
  3: "Namespace",
  4: "Package",
  5: "Class",
  6: "Method",
  7: "Property",
  8: "Field",
  9: "Constructor",
  10: "Enum",
  11: "Interface",
  12: "Function",
  13: "Variable",
  14: "Constant",
  15: "String",
  16: "Number",
  17: "Boolean",
  18: "Array",
  19: "Object",
  20: "Key",
  21: "Null",
  22: "EnumMember",
  23: "Struct",
  24: "Event",
  25: "Operator",
  26: "TypeParameter",
};

function usage() {
  console.error(`Usage: bash_intel_client.mjs <command> [args]

Commands:
  check
  symbols <file>
  workspace-symbols <query>
  definition <symbol>
  references <symbol>`);
}

function which(command) {
  const pathValue = process.env.PATH || "";
  for (const dir of pathValue.split(":")) {
    if (!dir) continue;
    const candidate = join(dir, command);
    try {
      if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
    } catch {
      // keep scanning PATH
    }
  }
  return null;
}

function serverCommand() {
  if (process.env.BASH_LANGUAGE_SERVER_BIN) {
    return { command: process.env.BASH_LANGUAGE_SERVER_BIN, args: ["start"], source: "BASH_LANGUAGE_SERVER_BIN" };
  }

  const installed = which("bash-language-server");
  if (installed) {
    return { command: installed, args: ["start"], source: "PATH" };
  }

  const npx = which("npx");
  if (npx) {
    return { command: npx, args: ["--yes", "bash-language-server", "start"], source: "npx" };
  }

  throw new Error("bash-language-server is not installed and npx is unavailable");
}

function lineRange(range) {
  if (!range) return null;
  return {
    startLine: range.start.line + 1,
    startColumn: range.start.character + 1,
    endLine: range.end.line + 1,
    endColumn: range.end.character + 1,
  };
}

function locationToJson(location) {
  if (!location) return null;
  const uri = location.uri || location.targetUri;
  const range = location.range || location.targetSelectionRange || location.targetRange;
  return {
    file: uri?.startsWith("file:") ? fileURLToPath(uri) : uri,
    uri,
    range: lineRange(range),
  };
}

function symbolToJson(symbol) {
  const location = symbol.location ? locationToJson(symbol.location) : null;
  const range = symbol.range || symbol.selectionRange;
  return {
    name: symbol.name,
    kind: SYMBOL_KIND[symbol.kind] || String(symbol.kind || ""),
    detail: symbol.detail || symbol.containerName || "",
    location,
    range: lineRange(range),
    children: (symbol.children || []).map(symbolToJson),
  };
}

class LspClient {
  constructor(commandSpec) {
    this.commandSpec = commandSpec;
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = Buffer.alloc(0);
    this.stderr = "";
    this.child = null;
  }

  start() {
    this.child = spawn(this.commandSpec.command, this.commandSpec.args, {
      cwd: ROOT,
      stdio: ["pipe", "pipe", "pipe"],
    });

    this.child.stdout.on("data", (chunk) => this.receive(chunk));
    this.child.stderr.on("data", (chunk) => {
      this.stderr += chunk.toString();
    });
    this.child.on("exit", (code, signal) => {
      const message = `bash-language-server exited (${code ?? signal ?? "unknown"})`;
      for (const { reject } of this.pending.values()) reject(new Error(message));
      this.pending.clear();
    });
  }

  receive(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (true) {
      const headerEnd = this.buffer.indexOf("\r\n\r\n");
      if (headerEnd === -1) return;

      const header = this.buffer.slice(0, headerEnd).toString("utf8");
      const match = header.match(/Content-Length:\s*(\d+)/i);
      if (!match) throw new Error(`Invalid LSP header: ${header}`);

      const length = Number(match[1]);
      const messageStart = headerEnd + 4;
      const messageEnd = messageStart + length;
      if (this.buffer.length < messageEnd) return;

      const payload = this.buffer.slice(messageStart, messageEnd).toString("utf8");
      this.buffer = this.buffer.slice(messageEnd);
      this.handleMessage(JSON.parse(payload));
    }
  }

  handleMessage(message) {
    if (message.id === undefined) return;
    const pending = this.pending.get(message.id);
    if (!pending) return;
    this.pending.delete(message.id);
    if (message.error) {
      pending.reject(new Error(message.error.message || JSON.stringify(message.error)));
    } else {
      pending.resolve(message.result);
    }
  }

  send(payload) {
    const body = JSON.stringify(payload);
    this.child.stdin.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`);
  }

  request(method, params = {}) {
    const id = this.nextId++;
    this.send({ jsonrpc: "2.0", id, method, params });
    return new Promise((resolvePromise, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        const details = this.stderr.trim();
        const suffix = details ? `: ${details}` : "";
        this.child?.kill();
        reject(new Error(`Timed out waiting for ${method}${suffix}`));
      }, TIMEOUT_MS);
      this.pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer);
          resolvePromise(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      });
    });
  }

  notify(method, params = {}) {
    this.send({ jsonrpc: "2.0", method, params });
  }

  async initialize() {
    this.start();
    await this.request("initialize", {
      processId: process.pid,
      rootUri: pathToFileURL(ROOT).href,
      workspaceFolders: [{ uri: pathToFileURL(ROOT).href, name: basename(ROOT) }],
      capabilities: {
        textDocument: {
          documentSymbol: { hierarchicalDocumentSymbolSupport: true },
          definition: {},
          references: {},
        },
        workspace: { symbol: {} },
      },
    });
    this.notify("initialized", {});
  }

  async openDocument(file) {
    const absolute = resolve(file);
    const text = readFileSync(absolute, "utf8");
    const uri = pathToFileURL(absolute).href;
    this.notify("textDocument/didOpen", {
      textDocument: {
        uri,
        languageId: "shellscript",
        version: 1,
        text,
      },
    });
    return { absolute, uri, text };
  }

  async shutdown() {
    if (!this.child) return;
    try {
      await this.request("shutdown", {});
      this.notify("exit", {});
    } catch {
      this.child.kill();
    }
  }
}

function shellFiles(dir = ROOT, files = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === "node_modules" || entry.name === ".gitnexus") continue;
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      shellFiles(fullPath, files);
    } else if ([".sh", ".bash", ".zsh"].includes(extname(entry.name))) {
      files.push(fullPath);
    }
  }
  return files;
}

function fallbackDefinition(symbol) {
  const pattern = new RegExp(`^[\\t ]*(?:function[\\t ]+)?${symbol.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:[\\t ]*\\(\\))?[\\t ]*\\{`);
  for (const file of shellFiles()) {
    const lines = readFileSync(file, "utf8").split(/\r?\n/);
    const index = lines.findIndex((line) => pattern.test(line));
    if (index !== -1) {
      return {
        file,
        uri: pathToFileURL(file).href,
        range: { startLine: index + 1, startColumn: 1, endLine: index + 1, endColumn: lines[index].length + 1 },
      };
    }
  }
  return null;
}

async function withClient(callback) {
  const client = new LspClient(serverCommand());
  await client.initialize();
  try {
    return await callback(client);
  } finally {
    await client.shutdown();
  }
}

async function symbols(file) {
  return withClient(async (client) => {
    const document = await client.openDocument(file);
    const result = await client.request("textDocument/documentSymbol", {
      textDocument: { uri: document.uri },
    });
    return { command: "symbols", file: document.absolute, symbols: (result || []).map(symbolToJson) };
  });
}

async function workspaceSymbols(query) {
  return withClient(async (client) => {
    const result = await client.request("workspace/symbol", { query });
    return { command: "workspace-symbols", query, symbols: (result || []).map(symbolToJson) };
  });
}

async function definition(symbol) {
  return withClient(async (client) => {
    const result = await client.request("workspace/symbol", { query: symbol });
    const match = (result || []).find((candidate) => candidate.name === symbol) || (result || [])[0];
    const location = match?.location ? locationToJson(match.location) : fallbackDefinition(symbol);
    return { command: "definition", symbol, definitions: location ? [location] : [] };
  });
}

async function references(symbol) {
  return withClient(async (client) => {
    const def = fallbackDefinition(symbol);
    if (!def) return { command: "references", symbol, references: [] };
    await client.openDocument(def.file);
    const result = await client.request("textDocument/references", {
      textDocument: { uri: def.uri },
      position: { line: def.range.startLine - 1, character: def.range.startColumn - 1 },
      context: { includeDeclaration: true },
    });
    return { command: "references", symbol, references: (result || []).map(locationToJson) };
  });
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (!command) {
    usage();
    process.exit(2);
  }

  if (command === "check") {
    console.log(JSON.stringify({ command: "check", root: ROOT, timeoutMs: TIMEOUT_MS, server: serverCommand() }, null, 2));
    return;
  }

  let payload;
  if (command === "symbols") {
    if (args.length !== 1) throw new Error("symbols requires a file");
    payload = await symbols(args[0]);
  } else if (command === "workspace-symbols") {
    if (args.length < 1) throw new Error("workspace-symbols requires a query");
    payload = await workspaceSymbols(args.join(" "));
  } else if (command === "definition") {
    if (args.length < 1) throw new Error("definition requires a symbol");
    payload = await definition(args.join(" "));
  } else if (command === "references") {
    if (args.length < 1) throw new Error("references requires a symbol");
    payload = await references(args.join(" "));
  } else {
    throw new Error(`Unknown command: ${command}`);
  }

  console.log(JSON.stringify(payload, null, 2));
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exit(1);
});
