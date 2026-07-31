"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
var toolSet_exports = {};
__export(toolSet_exports, {
  BuiltInTools: () => BuiltInTools,
  ToolSet: () => ToolSet
});
module.exports = __toCommonJS(toolSet_exports);
const VALID_TOOL_NAME = /^[a-zA-Z0-9_-]+$/;
function validateName(kind, name) {
  if (name === "*") {
    return;
  }
  if (!VALID_TOOL_NAME.test(name)) {
    throw new Error(
      `Invalid ${kind} tool name '${name}': tool names must match /^[a-zA-Z0-9_-]+$/ or be the wildcard '*'.`
    );
  }
}
class ToolSet {
  items = [];
  addBuiltIn(nameOrNames) {
    const names = typeof nameOrNames === "string" ? [nameOrNames] : nameOrNames;
    for (const name of names) {
      validateName("builtin", name);
      this.items.push(`builtin:${name}`);
    }
    return this;
  }
  /**
   * Adds a custom tool pattern. Matches tools registered via the SDK's
   * `tools` option or via custom agents.
   *
   * @param name A specific custom tool name or `"*"` to match all custom tools.
   */
  addCustom(name) {
    validateName("custom", name);
    this.items.push(`custom:${name}`);
    return this;
  }
  /**
   * Adds an MCP tool pattern. Matches tools advertised by any configured
   * MCP server.
   *
   * @param toolName The runtime's canonical wire name for the MCP tool
   *   (e.g. `"github-list_issues"`), or `"*"` to match all MCP tools from
   *   any server.
   */
  addMcp(toolName) {
    validateName("mcp", toolName);
    this.items.push(`mcp:${toolName}`);
    return this;
  }
  /**
   * Returns a defensive copy of the accumulated filter strings, suitable for
   * passing as {@link SessionConfigBase.availableTools}.
   */
  toArray() {
    return [...this.items];
  }
}
const BuiltInTools = {
  /**
   * Built-in tools that operate only within the bounds of a single session —
   * no host filesystem access outside the session, no cross-session state,
   * no host environment access, no network. Safe to enable in `Mode = "empty"`
   * scenarios (e.g. multi-tenant servers) without leaking host capabilities.
   *
   * **Contract:** tools in this set MUST NOT be extended (even behind options
   * or args) to read or write state outside the session boundary. Adding
   * cross-session or host-state behavior to one of these tools is a
   * breaking change that requires removing it from this set.
   */
  Isolated: [
    "ask_user",
    "task_complete",
    "exit_plan_mode",
    "task",
    "read_agent",
    "write_agent",
    "list_agents",
    "send_inbox",
    "context_board",
    "skill"
  ]
};
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  BuiltInTools,
  ToolSet
});
