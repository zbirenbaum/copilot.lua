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
var canvas_exports = {};
__export(canvas_exports, {
  Canvas: () => Canvas,
  CanvasError: () => CanvasError,
  createCanvas: () => createCanvas
});
module.exports = __toCommonJS(canvas_exports);
class CanvasError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
    this.name = "CanvasError";
  }
  code;
  /** Default error when an action is declared but no `handler` is wired. */
  static noHandler() {
    return new CanvasError(
      "canvas_action_no_handler",
      "No handler implemented for this canvas action"
    );
  }
}
class Canvas {
  declaration;
  open;
  onClose;
  /** @internal */
  actionHandlers;
  /** @internal */
  constructor(options) {
    const actionHandlers = /* @__PURE__ */ new Map();
    const wireActions = options.actions?.map(
      ({ handler, ...wire }) => {
        actionHandlers.set(wire.name, handler);
        return wire;
      }
    );
    this.declaration = {
      id: options.id,
      displayName: options.displayName,
      description: options.description,
      inputSchema: options.inputSchema,
      actions: wireActions
    };
    this.open = options.open;
    this.onClose = options.onClose;
    this.actionHandlers = actionHandlers;
  }
}
function createCanvas(options) {
  return new Canvas(options);
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  Canvas,
  CanvasError,
  createCanvas
});
