var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
  get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
}) : x)(function(x) {
  if (typeof require !== "undefined") return require.apply(this, arguments);
  throw Error('Dynamic require of "' + x + '" is not supported');
});
var __commonJS = (cb, mod) => function __require2() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// ../../node_modules/ms/index.js
var require_ms = __commonJS({
  "../../node_modules/ms/index.js"(exports, module) {
    var s = 1e3;
    var m = s * 60;
    var h = m * 60;
    var d = h * 24;
    var w = d * 7;
    var y = d * 365.25;
    module.exports = function(val, options) {
      options = options || {};
      var type = typeof val;
      if (type === "string" && val.length > 0) {
        return parse(val);
      } else if (type === "number" && isFinite(val)) {
        return options.long ? fmtLong(val) : fmtShort(val);
      }
      throw new Error(
        "val is not a non-empty string or a valid number. val=" + JSON.stringify(val)
      );
    };
    function parse(str) {
      str = String(str);
      if (str.length > 100) {
        return;
      }
      var match = /^(-?(?:\d+)?\.?\d+) *(milliseconds?|msecs?|ms|seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|years?|yrs?|y)?$/i.exec(
        str
      );
      if (!match) {
        return;
      }
      var n = parseFloat(match[1]);
      var type = (match[2] || "ms").toLowerCase();
      switch (type) {
        case "years":
        case "year":
        case "yrs":
        case "yr":
        case "y":
          return n * y;
        case "weeks":
        case "week":
        case "w":
          return n * w;
        case "days":
        case "day":
        case "d":
          return n * d;
        case "hours":
        case "hour":
        case "hrs":
        case "hr":
        case "h":
          return n * h;
        case "minutes":
        case "minute":
        case "mins":
        case "min":
        case "m":
          return n * m;
        case "seconds":
        case "second":
        case "secs":
        case "sec":
        case "s":
          return n * s;
        case "milliseconds":
        case "millisecond":
        case "msecs":
        case "msec":
        case "ms":
          return n;
        default:
          return void 0;
      }
    }
    function fmtShort(ms) {
      var msAbs = Math.abs(ms);
      if (msAbs >= d) {
        return Math.round(ms / d) + "d";
      }
      if (msAbs >= h) {
        return Math.round(ms / h) + "h";
      }
      if (msAbs >= m) {
        return Math.round(ms / m) + "m";
      }
      if (msAbs >= s) {
        return Math.round(ms / s) + "s";
      }
      return ms + "ms";
    }
    function fmtLong(ms) {
      var msAbs = Math.abs(ms);
      if (msAbs >= d) {
        return plural(ms, msAbs, d, "day");
      }
      if (msAbs >= h) {
        return plural(ms, msAbs, h, "hour");
      }
      if (msAbs >= m) {
        return plural(ms, msAbs, m, "minute");
      }
      if (msAbs >= s) {
        return plural(ms, msAbs, s, "second");
      }
      return ms + " ms";
    }
    function plural(ms, msAbs, n, name) {
      var isPlural = msAbs >= n * 1.5;
      return Math.round(ms / n) + " " + name + (isPlural ? "s" : "");
    }
  }
});

// ../../node_modules/debug/src/common.js
var require_common = __commonJS({
  "../../node_modules/debug/src/common.js"(exports, module) {
    function setup(env) {
      createDebug2.debug = createDebug2;
      createDebug2.default = createDebug2;
      createDebug2.coerce = coerce;
      createDebug2.disable = disable;
      createDebug2.enable = enable;
      createDebug2.enabled = enabled;
      createDebug2.humanize = require_ms();
      createDebug2.destroy = destroy;
      Object.keys(env).forEach((key) => {
        createDebug2[key] = env[key];
      });
      createDebug2.names = [];
      createDebug2.skips = [];
      createDebug2.formatters = {};
      function selectColor(namespace) {
        let hash = 0;
        for (let i = 0; i < namespace.length; i++) {
          hash = (hash << 5) - hash + namespace.charCodeAt(i);
          hash |= 0;
        }
        return createDebug2.colors[Math.abs(hash) % createDebug2.colors.length];
      }
      createDebug2.selectColor = selectColor;
      function createDebug2(namespace) {
        let prevTime;
        let enableOverride = null;
        let namespacesCache;
        let enabledCache;
        function debug(...args) {
          if (!debug.enabled) {
            return;
          }
          const self = debug;
          const curr = Number(/* @__PURE__ */ new Date());
          const ms = curr - (prevTime || curr);
          self.diff = ms;
          self.prev = prevTime;
          self.curr = curr;
          prevTime = curr;
          args[0] = createDebug2.coerce(args[0]);
          if (typeof args[0] !== "string") {
            args.unshift("%O");
          }
          let index = 0;
          args[0] = args[0].replace(/%([a-zA-Z%])/g, (match, format) => {
            if (match === "%%") {
              return "%";
            }
            index++;
            const formatter = createDebug2.formatters[format];
            if (typeof formatter === "function") {
              const val = args[index];
              match = formatter.call(self, val);
              args.splice(index, 1);
              index--;
            }
            return match;
          });
          createDebug2.formatArgs.call(self, args);
          const logFn = self.log || createDebug2.log;
          logFn.apply(self, args);
        }
        debug.namespace = namespace;
        debug.useColors = createDebug2.useColors();
        debug.color = createDebug2.selectColor(namespace);
        debug.extend = extend;
        debug.destroy = createDebug2.destroy;
        Object.defineProperty(debug, "enabled", {
          enumerable: true,
          configurable: false,
          get: () => {
            if (enableOverride !== null) {
              return enableOverride;
            }
            if (namespacesCache !== createDebug2.namespaces) {
              namespacesCache = createDebug2.namespaces;
              enabledCache = createDebug2.enabled(namespace);
            }
            return enabledCache;
          },
          set: (v) => {
            enableOverride = v;
          }
        });
        if (typeof createDebug2.init === "function") {
          createDebug2.init(debug);
        }
        return debug;
      }
      function extend(namespace, delimiter) {
        const newDebug = createDebug2(this.namespace + (typeof delimiter === "undefined" ? ":" : delimiter) + namespace);
        newDebug.log = this.log;
        return newDebug;
      }
      function enable(namespaces) {
        createDebug2.save(namespaces);
        createDebug2.namespaces = namespaces;
        createDebug2.names = [];
        createDebug2.skips = [];
        let i;
        const split = (typeof namespaces === "string" ? namespaces : "").split(/[\s,]+/);
        const len = split.length;
        for (i = 0; i < len; i++) {
          if (!split[i]) {
            continue;
          }
          namespaces = split[i].replace(/\*/g, ".*?");
          if (namespaces[0] === "-") {
            createDebug2.skips.push(new RegExp("^" + namespaces.slice(1) + "$"));
          } else {
            createDebug2.names.push(new RegExp("^" + namespaces + "$"));
          }
        }
      }
      function disable() {
        const namespaces = [
          ...createDebug2.names.map(toNamespace),
          ...createDebug2.skips.map(toNamespace).map((namespace) => "-" + namespace)
        ].join(",");
        createDebug2.enable("");
        return namespaces;
      }
      function enabled(name) {
        if (name[name.length - 1] === "*") {
          return true;
        }
        let i;
        let len;
        for (i = 0, len = createDebug2.skips.length; i < len; i++) {
          if (createDebug2.skips[i].test(name)) {
            return false;
          }
        }
        for (i = 0, len = createDebug2.names.length; i < len; i++) {
          if (createDebug2.names[i].test(name)) {
            return true;
          }
        }
        return false;
      }
      function toNamespace(regexp) {
        return regexp.toString().substring(2, regexp.toString().length - 2).replace(/\.\*\?$/, "*");
      }
      function coerce(val) {
        if (val instanceof Error) {
          return val.stack || val.message;
        }
        return val;
      }
      function destroy() {
        console.warn("Instance method `debug.destroy()` is deprecated and no longer does anything. It will be removed in the next major version of `debug`.");
      }
      createDebug2.enable(createDebug2.load());
      return createDebug2;
    }
    module.exports = setup;
  }
});

// ../../node_modules/debug/src/browser.js
var require_browser = __commonJS({
  "../../node_modules/debug/src/browser.js"(exports, module) {
    exports.formatArgs = formatArgs;
    exports.save = save;
    exports.load = load;
    exports.useColors = useColors;
    exports.storage = localstorage();
    exports.destroy = /* @__PURE__ */ (() => {
      let warned = false;
      return () => {
        if (!warned) {
          warned = true;
          console.warn("Instance method `debug.destroy()` is deprecated and no longer does anything. It will be removed in the next major version of `debug`.");
        }
      };
    })();
    exports.colors = [
      "#0000CC",
      "#0000FF",
      "#0033CC",
      "#0033FF",
      "#0066CC",
      "#0066FF",
      "#0099CC",
      "#0099FF",
      "#00CC00",
      "#00CC33",
      "#00CC66",
      "#00CC99",
      "#00CCCC",
      "#00CCFF",
      "#3300CC",
      "#3300FF",
      "#3333CC",
      "#3333FF",
      "#3366CC",
      "#3366FF",
      "#3399CC",
      "#3399FF",
      "#33CC00",
      "#33CC33",
      "#33CC66",
      "#33CC99",
      "#33CCCC",
      "#33CCFF",
      "#6600CC",
      "#6600FF",
      "#6633CC",
      "#6633FF",
      "#66CC00",
      "#66CC33",
      "#9900CC",
      "#9900FF",
      "#9933CC",
      "#9933FF",
      "#99CC00",
      "#99CC33",
      "#CC0000",
      "#CC0033",
      "#CC0066",
      "#CC0099",
      "#CC00CC",
      "#CC00FF",
      "#CC3300",
      "#CC3333",
      "#CC3366",
      "#CC3399",
      "#CC33CC",
      "#CC33FF",
      "#CC6600",
      "#CC6633",
      "#CC9900",
      "#CC9933",
      "#CCCC00",
      "#CCCC33",
      "#FF0000",
      "#FF0033",
      "#FF0066",
      "#FF0099",
      "#FF00CC",
      "#FF00FF",
      "#FF3300",
      "#FF3333",
      "#FF3366",
      "#FF3399",
      "#FF33CC",
      "#FF33FF",
      "#FF6600",
      "#FF6633",
      "#FF9900",
      "#FF9933",
      "#FFCC00",
      "#FFCC33"
    ];
    function useColors() {
      if (typeof window !== "undefined" && window.process && (window.process.type === "renderer" || window.process.__nwjs)) {
        return true;
      }
      if (typeof navigator !== "undefined" && navigator.userAgent && navigator.userAgent.toLowerCase().match(/(edge|trident)\/(\d+)/)) {
        return false;
      }
      let m;
      return typeof document !== "undefined" && document.documentElement && document.documentElement.style && document.documentElement.style.WebkitAppearance || // Is firebug? http://stackoverflow.com/a/398120/376773
      typeof window !== "undefined" && window.console && (window.console.firebug || window.console.exception && window.console.table) || // Is firefox >= v31?
      // https://developer.mozilla.org/en-US/docs/Tools/Web_Console#Styling_messages
      typeof navigator !== "undefined" && navigator.userAgent && (m = navigator.userAgent.toLowerCase().match(/firefox\/(\d+)/)) && parseInt(m[1], 10) >= 31 || // Double check webkit in userAgent just in case we are in a worker
      typeof navigator !== "undefined" && navigator.userAgent && navigator.userAgent.toLowerCase().match(/applewebkit\/(\d+)/);
    }
    function formatArgs(args) {
      args[0] = (this.useColors ? "%c" : "") + this.namespace + (this.useColors ? " %c" : " ") + args[0] + (this.useColors ? "%c " : " ") + "+" + module.exports.humanize(this.diff);
      if (!this.useColors) {
        return;
      }
      const c = "color: " + this.color;
      args.splice(1, 0, c, "color: inherit");
      let index = 0;
      let lastC = 0;
      args[0].replace(/%[a-zA-Z%]/g, (match) => {
        if (match === "%%") {
          return;
        }
        index++;
        if (match === "%c") {
          lastC = index;
        }
      });
      args.splice(lastC, 0, c);
    }
    exports.log = console.debug || console.log || (() => {
    });
    function save(namespaces) {
      try {
        if (namespaces) {
          exports.storage.setItem("debug", namespaces);
        } else {
          exports.storage.removeItem("debug");
        }
      } catch (error) {
      }
    }
    function load() {
      let r;
      try {
        r = exports.storage.getItem("debug");
      } catch (error) {
      }
      if (!r && typeof process !== "undefined" && "env" in process) {
        r = process.env.DEBUG;
      }
      return r;
    }
    function localstorage() {
      try {
        return localStorage;
      } catch (error) {
      }
    }
    module.exports = require_common()(exports);
    var { formatters } = module.exports;
    formatters.j = function(v) {
      try {
        return JSON.stringify(v);
      } catch (error) {
        return "[UnexpectedJSONParseError]: " + error.message;
      }
    };
  }
});

// ../../node_modules/has-flag/index.js
var require_has_flag = __commonJS({
  "../../node_modules/has-flag/index.js"(exports, module) {
    "use strict";
    module.exports = (flag, argv = process.argv) => {
      const prefix = flag.startsWith("-") ? "" : flag.length === 1 ? "-" : "--";
      const position = argv.indexOf(prefix + flag);
      const terminatorPosition = argv.indexOf("--");
      return position !== -1 && (terminatorPosition === -1 || position < terminatorPosition);
    };
  }
});

// ../../node_modules/supports-color/index.js
var require_supports_color = __commonJS({
  "../../node_modules/supports-color/index.js"(exports, module) {
    "use strict";
    var os2 = __require("os");
    var tty = __require("tty");
    var hasFlag = require_has_flag();
    var { env } = process;
    var forceColor;
    if (hasFlag("no-color") || hasFlag("no-colors") || hasFlag("color=false") || hasFlag("color=never")) {
      forceColor = 0;
    } else if (hasFlag("color") || hasFlag("colors") || hasFlag("color=true") || hasFlag("color=always")) {
      forceColor = 1;
    }
    if ("FORCE_COLOR" in env) {
      if (env.FORCE_COLOR === "true") {
        forceColor = 1;
      } else if (env.FORCE_COLOR === "false") {
        forceColor = 0;
      } else {
        forceColor = env.FORCE_COLOR.length === 0 ? 1 : Math.min(parseInt(env.FORCE_COLOR, 10), 3);
      }
    }
    function translateLevel(level) {
      if (level === 0) {
        return false;
      }
      return {
        level,
        hasBasic: true,
        has256: level >= 2,
        has16m: level >= 3
      };
    }
    function supportsColor(haveStream, streamIsTTY) {
      if (forceColor === 0) {
        return 0;
      }
      if (hasFlag("color=16m") || hasFlag("color=full") || hasFlag("color=truecolor")) {
        return 3;
      }
      if (hasFlag("color=256")) {
        return 2;
      }
      if (haveStream && !streamIsTTY && forceColor === void 0) {
        return 0;
      }
      const min = forceColor || 0;
      if (env.TERM === "dumb") {
        return min;
      }
      if (process.platform === "win32") {
        const osRelease = os2.release().split(".");
        if (Number(osRelease[0]) >= 10 && Number(osRelease[2]) >= 10586) {
          return Number(osRelease[2]) >= 14931 ? 3 : 2;
        }
        return 1;
      }
      if ("CI" in env) {
        if (["TRAVIS", "CIRCLECI", "APPVEYOR", "GITLAB_CI", "GITHUB_ACTIONS", "BUILDKITE"].some((sign) => sign in env) || env.CI_NAME === "codeship") {
          return 1;
        }
        return min;
      }
      if ("TEAMCITY_VERSION" in env) {
        return /^(9\.(0*[1-9]\d*)\.|\d{2,}\.)/.test(env.TEAMCITY_VERSION) ? 1 : 0;
      }
      if (env.COLORTERM === "truecolor") {
        return 3;
      }
      if ("TERM_PROGRAM" in env) {
        const version = parseInt((env.TERM_PROGRAM_VERSION || "").split(".")[0], 10);
        switch (env.TERM_PROGRAM) {
          case "iTerm.app":
            return version >= 3 ? 3 : 2;
          case "Apple_Terminal":
            return 2;
        }
      }
      if (/-256(color)?$/i.test(env.TERM)) {
        return 2;
      }
      if (/^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/i.test(env.TERM)) {
        return 1;
      }
      if ("COLORTERM" in env) {
        return 1;
      }
      return min;
    }
    function getSupportLevel(stream) {
      const level = supportsColor(stream, stream && stream.isTTY);
      return translateLevel(level);
    }
    module.exports = {
      supportsColor: getSupportLevel,
      stdout: translateLevel(supportsColor(true, tty.isatty(1))),
      stderr: translateLevel(supportsColor(true, tty.isatty(2)))
    };
  }
});

// ../../node_modules/debug/src/node.js
var require_node = __commonJS({
  "../../node_modules/debug/src/node.js"(exports, module) {
    var tty = __require("tty");
    var util = __require("util");
    exports.init = init;
    exports.log = log;
    exports.formatArgs = formatArgs;
    exports.save = save;
    exports.load = load;
    exports.useColors = useColors;
    exports.destroy = util.deprecate(
      () => {
      },
      "Instance method `debug.destroy()` is deprecated and no longer does anything. It will be removed in the next major version of `debug`."
    );
    exports.colors = [6, 2, 3, 4, 5, 1];
    try {
      const supportsColor = require_supports_color();
      if (supportsColor && (supportsColor.stderr || supportsColor).level >= 2) {
        exports.colors = [
          20,
          21,
          26,
          27,
          32,
          33,
          38,
          39,
          40,
          41,
          42,
          43,
          44,
          45,
          56,
          57,
          62,
          63,
          68,
          69,
          74,
          75,
          76,
          77,
          78,
          79,
          80,
          81,
          92,
          93,
          98,
          99,
          112,
          113,
          128,
          129,
          134,
          135,
          148,
          149,
          160,
          161,
          162,
          163,
          164,
          165,
          166,
          167,
          168,
          169,
          170,
          171,
          172,
          173,
          178,
          179,
          184,
          185,
          196,
          197,
          198,
          199,
          200,
          201,
          202,
          203,
          204,
          205,
          206,
          207,
          208,
          209,
          214,
          215,
          220,
          221
        ];
      }
    } catch (error) {
    }
    exports.inspectOpts = Object.keys(process.env).filter((key) => {
      return /^debug_/i.test(key);
    }).reduce((obj, key) => {
      const prop = key.substring(6).toLowerCase().replace(/_([a-z])/g, (_, k) => {
        return k.toUpperCase();
      });
      let val = process.env[key];
      if (/^(yes|on|true|enabled)$/i.test(val)) {
        val = true;
      } else if (/^(no|off|false|disabled)$/i.test(val)) {
        val = false;
      } else if (val === "null") {
        val = null;
      } else {
        val = Number(val);
      }
      obj[prop] = val;
      return obj;
    }, {});
    function useColors() {
      return "colors" in exports.inspectOpts ? Boolean(exports.inspectOpts.colors) : tty.isatty(process.stderr.fd);
    }
    function formatArgs(args) {
      const { namespace: name, useColors: useColors2 } = this;
      if (useColors2) {
        const c = this.color;
        const colorCode = "\x1B[3" + (c < 8 ? c : "8;5;" + c);
        const prefix = `  ${colorCode};1m${name} \x1B[0m`;
        args[0] = prefix + args[0].split("\n").join("\n" + prefix);
        args.push(colorCode + "m+" + module.exports.humanize(this.diff) + "\x1B[0m");
      } else {
        args[0] = getDate() + name + " " + args[0];
      }
    }
    function getDate() {
      if (exports.inspectOpts.hideDate) {
        return "";
      }
      return (/* @__PURE__ */ new Date()).toISOString() + " ";
    }
    function log(...args) {
      return process.stderr.write(util.formatWithOptions(exports.inspectOpts, ...args) + "\n");
    }
    function save(namespaces) {
      if (namespaces) {
        process.env.DEBUG = namespaces;
      } else {
        delete process.env.DEBUG;
      }
    }
    function load() {
      return process.env.DEBUG;
    }
    function init(debug) {
      debug.inspectOpts = {};
      const keys = Object.keys(exports.inspectOpts);
      for (let i = 0; i < keys.length; i++) {
        debug.inspectOpts[keys[i]] = exports.inspectOpts[keys[i]];
      }
    }
    module.exports = require_common()(exports);
    var { formatters } = module.exports;
    formatters.o = function(v) {
      this.inspectOpts.colors = this.useColors;
      return util.inspect(v, this.inspectOpts).split("\n").map((str) => str.trim()).join(" ");
    };
    formatters.O = function(v) {
      this.inspectOpts.colors = this.useColors;
      return util.inspect(v, this.inspectOpts);
    };
  }
});

// ../../node_modules/debug/src/index.js
var require_src = __commonJS({
  "../../node_modules/debug/src/index.js"(exports, module) {
    if (typeof process === "undefined" || process.type === "renderer" || process.browser === true || process.__nwjs) {
      module.exports = require_browser();
    } else {
      module.exports = require_node();
    }
  }
});

// src/main.ts
import { Command } from "commander";
import inquirer5 from "inquirer";

// src/commands/nsec.ts
import fs from "fs/promises";
import path from "path";
import os from "os";
function getNutsackPath() {
  const homeDir = os.homedir();
  return path.join(homeDir, ".nutsack");
}
async function readNsecFromFile() {
  try {
    const nsecPath = getNutsackPath();
    const nsec = await fs.readFile(nsecPath, "utf-8");
    return nsec.trim();
  } catch (error) {
    return null;
  }
}
async function handleNsecCommand(nsec) {
  try {
    const filePath = getNutsackPath();
    await fs.writeFile(filePath, nsec, "utf-8");
    console.log(`NSEC successfully written to ${filePath}`);
  } catch (error) {
    console.error("Error writing NSEC:", error);
  }
}

// src/utils/url.ts
function normalizeRelayUrl(url) {
  if (!url.startsWith("ws://") && !url.startsWith("wss://")) {
    if (url.startsWith("localhost") || url.startsWith("127.0.0.1")) {
      return `ws://${url}`;
    }
    return `wss://${url}`;
  }
  return url;
}

// src/lib/ndk.ts
var import_debug = __toESM(require_src(), 1);
import NDK, { getRelayListForUser, NDKPrivateKeySigner } from "@nostr-dev-kit/ndk";
import chalk from "chalk";
var ndk;
async function initNdk(relays2, payload) {
  let signer;
  if (payload.startsWith("nsec")) {
    signer = new NDKPrivateKeySigner(payload);
  }
  const relaysProvided = relays2.length > 0;
  if (relays2.length === 0) {
    relays2 = ["wss://relay.primal.net", "wss://relay.damus.io"];
  }
  const netDebug = (0, import_debug.default)("net");
  ndk = new NDK({
    explicitRelayUrls: relays2,
    signer,
    autoConnectUserRelays: true,
    netDebug: (msg, relay, direction) => {
      const hostname = chalk.white(new URL(relay.url).hostname);
      if (direction === "send") {
        netDebug(hostname, chalk.green(msg));
      } else if (direction === "recv") {
        netDebug(hostname, chalk.red(msg));
      } else {
        netDebug(hostname, chalk.grey(msg));
      }
    }
  });
  await ndk.connect(5e3);
  if (!relaysProvided) {
    getRelayListForUser(ndk.activeUser.pubkey, ndk).then((relayList) => {
      if (!relayList || relayList.relays.length === 0) {
        console.log(chalk.red("No relays provided and this pubkey doesn't have any relays!"));
      }
    });
  }
}

// src/lib/wallet.ts
import { NDKCashuWallet, NDKNutzapMonitor } from "@nostr-dev-kit/ndk-wallet";
import { NDKCashuMintList, NDKKind } from "@nostr-dev-kit/ndk";
import inquirer from "inquirer";
var activeWallet2 = null;
var allWallets = [];
var setActiveWallet = (wallet) => activeWallet2 = wallet;
var monitor;
async function askForWallet(mintList, walletEvents) {
  const wallets = Array.from(walletEvents.values());
  const wallet = await inquirer.prompt([
    {
      type: "list",
      name: "wallet",
      message: "Which wallet do you want to use?",
      choices: allWallets.map((w) => `${w.event.encode()} (${w.name})`)
    }
  ]);
  return wallets.find((w) => w.event.encode() === wallet.wallet);
}
async function initWallet() {
  const events = await ndk.fetchEvents([
    { kinds: [NDKKind.CashuMintList, NDKKind.CashuWallet], authors: [ndk.activeUser.pubkey] }
  ]);
  const eventsArray = Array.from(events);
  const list = eventsArray.find((e) => e.kind === NDKKind.CashuMintList);
  const mintList = list ? NDKCashuMintList.from(list) : void 0;
  const walletEvents = eventsArray.filter((e) => e.kind === NDKKind.CashuWallet);
  allWallets = (await Promise.all(walletEvents.map(NDKCashuWallet.from))).filter((w) => !!w);
  allWallets.forEach((w) => w.start());
  if (walletEvents.length > 1) {
    activeWallet2 = await askForWallet(mintList, allWallets);
  } else if (walletEvents.length === 1) {
    activeWallet2 = allWallets[0];
  } else {
    console.error("No wallets found");
  }
  monitor = new NDKNutzapMonitor(ndk, ndk.activeUser);
  allWallets.forEach((w) => monitor.addWallet(w));
  monitor.start();
}

// src/commands/wallet/create.ts
import inquirer2 from "inquirer";
import { NDKPrivateKeySigner as NDKPrivateKeySigner2 } from "@nostr-dev-kit/ndk";
import { NDKCashuWallet as NDKCashuWallet2 } from "@nostr-dev-kit/ndk-wallet";
async function fetchMintList() {
  const list = await ndk.fetchEvents({
    kinds: [38172]
  });
  return Array.from(list);
}
async function createWallet(name, mints, unit) {
  let walletName = name;
  let selectedMints = mints;
  let walletUnit = unit;
  if (!walletName) {
    const { inputWalletName } = await inquirer2.prompt([
      {
        type: "input",
        name: "inputWalletName",
        message: "Enter a name for your wallet:"
      }
    ]);
    walletName = inputWalletName;
  }
  if (!selectedMints || selectedMints.length === 0) {
    const mintList = await fetchMintList();
    const mintUrls = mintList.map((event) => event.tagValue("u")).filter((url) => url !== void 0);
    mintUrls.unshift("https://testnut.cashu.space/");
    console.log("Available Mint URLs:", mintUrls);
    const { userSelectedMints } = await inquirer2.prompt([
      {
        type: "checkbox",
        name: "userSelectedMints",
        message: "Select one or more mint URLs:",
        choices: mintUrls,
        validate: (answer) => {
          if (answer.length < 1) {
            return "You must choose at least one mint URL.";
          }
          return true;
        }
      }
    ]);
    selectedMints = userSelectedMints;
  }
  if (!walletUnit) {
    const { inputUnit } = await inquirer2.prompt([
      {
        type: "input",
        name: "inputUnit",
        message: "Enter the unit for your wallet:",
        default: "sat"
      }
    ]);
    walletUnit = inputUnit;
  }
  const key = NDKPrivateKeySigner2.generate();
  const wallet = new NDKCashuWallet2(ndk);
  wallet.name = walletName;
  wallet.mints = selectedMints;
  wallet.relays = ndk.pool.connectedRelays().map((relay) => relay.url);
  wallet.unit = walletUnit;
  wallet.privkey = key.privateKey;
  await wallet.getP2pk();
  await wallet.publish();
  setActiveWallet(wallet);
  allWallets.push(wallet);
  console.log("Wallet created:", wallet.event.encode());
  return wallet;
}

// src/commands/wallet/set-nutzap-wallet.ts
import { NDKCashuMintList as NDKCashuMintList2 } from "@nostr-dev-kit/ndk";
import { NDKCashuWallet as NDKCashuWallet3 } from "@nostr-dev-kit/ndk-wallet";
async function setNutzapWallet(walletId) {
  const walletEvent = await ndk.fetchEvent(walletId);
  if (!walletEvent) {
    console.error("Wallet not found");
    return;
  }
  const wallet = await NDKCashuWallet3.from(walletEvent);
  if (!wallet) {
    console.error("Wallet invalid", walletEvent.rawEvent());
    return;
  }
  const mintList = new NDKCashuMintList2(ndk);
  mintList.mints = wallet.mints;
  mintList.relays = wallet.relays;
  if (wallet.p2pk) mintList.p2pk = wallet.p2pk;
  await mintList.publishReplaceable();
  monitor.start(mintList);
  console.log("Nutzap wallet set: https://njump.me/" + mintList.encode());
}

// src/commands/wallet/list.ts
import { NDKCashuWallet as NDKCashuWallet4 } from "@nostr-dev-kit/ndk-wallet";
import chalk2 from "chalk";
async function listWallets(all = false) {
  var _a;
  for (const wallet of allWallets) {
    if (wallet instanceof NDKCashuWallet4) {
      console.log(chalk2.white.bold(wallet.name ?? "Unnamed"));
      if (all) {
        console.log(`Type: ${chalk2.yellow(wallet.type)}`);
        if (wallet.event) console.log(`Wallet ID: ${chalk2.cyan((_a = wallet.event) == null ? void 0 : _a.encode())}`);
        if (wallet.p2pk) console.log(`P2PK: ${chalk2.cyan(wallet.p2pk)}`);
        console.log(`Mints:`);
        for (const mint of wallet.mints) {
          console.log(`  Mint: ${chalk2.cyan(mint)}`);
        }
      }
      const balance = await wallet.balance();
      if (balance) {
        for (const b of balance) {
          console.log(`  Balance: ${chalk2.cyan(`${b.amount} ${b.unit}`)}`);
        }
      }
      console.log();
    }
  }
}

// src/commands/wallet/deposit.ts
import inquirer3 from "inquirer";
import { NDKCashuWallet as NDKCashuWallet5 } from "@nostr-dev-kit/ndk-wallet";
import qrcode from "qrcode-terminal";
async function depositToWallet(mintUrl, amount, unit) {
  const wallets = allWallets;
  let wallet;
  if (wallets.length === 1) {
    wallet = wallets[0];
  } else if (wallets.length > 1) {
    const { selection } = await inquirer3.prompt([
      {
        type: "list",
        name: "selection",
        message: "Select a wallet to deposit to:",
        choices: wallets.filter((w) => w instanceof NDKCashuWallet5).map((w) => `${w.name ?? "Unnamed"} (${w.event.encode()})`),
        validate: (input) => {
          if (!input) {
            return "You must select a wallet.";
          }
          return true;
        }
      }
    ]);
    console.log({ selection });
    wallet = wallets.find((w) => w instanceof NDKCashuWallet5 && selection.includes(w.event.encode()));
  }
  if (!wallet) {
    console.log("No wallet selected.");
    return;
  }
  let mint;
  if (mintUrl) {
    mint = mintUrl;
  } else {
    const { selectedMint } = await inquirer3.prompt([
      {
        type: "list",
        name: "selectedMint",
        choices: wallet.mints,
        message: "Select the mint to deposit to:"
      }
    ]);
    mint = selectedMint;
  }
  if (!amount || !unit) {
    const answers = await inquirer3.prompt([
      {
        type: "input",
        name: "amount",
        message: "Enter the amount to deposit:",
        when: !amount
      },
      {
        type: "input",
        name: "unit",
        message: "Enter the unit for the amount:",
        default: wallet.unit,
        when: !unit
      }
    ]);
    amount = amount || answers.amount;
    unit = unit || answers.unit;
  }
  if (unit === "sats") unit = "sat";
  const deposit = await wallet.deposit(amount, mint, unit);
  const pr = await deposit.start();
  console.log(`Payment Request from ${mint}:`);
  console.log(`\x1B[1;37m${pr}\x1B[0m`);
  qrcode.generate(pr, { small: true }, (qrcode2) => {
    console.log(qrcode2);
  });
  await new Promise((resolve) => {
    deposit.on("success", (token) => {
      console.log(`Deposit successful: ${token.id}`);
      resolve(token);
    });
    deposit.on("error", (error) => {
      console.error(`Deposit failed: ${error}`);
      resolve(error);
    });
  });
}

// src/commands/wallet/tokens.ts
import { NDKCashuWallet as NDKCashuWallet6 } from "@nostr-dev-kit/ndk-wallet";
import chalk3 from "chalk";
async function listTokens(verbose = false) {
  for (const wallet of allWallets) {
    if (!(wallet instanceof NDKCashuWallet6)) continue;
    console.log(chalk3.white(wallet.name));
    for (const token of wallet.tokens) {
      const { amount, mint, proofs } = token;
      console.log(
        "  " + chalk3.green(amount),
        chalk3.gray(`(${mint})`) + chalk3.yellow(` (${proofs.length} proofs)`)
      );
      if (verbose) {
        for (const proof of proofs) {
          console.log(
            chalk3.gray(`    ${proof.secret}`),
            chalk3.white(`    (${proof.amount})`)
          );
        }
      }
    }
  }
}

// src/commands/wallet/pay.ts
import { NDKEvent as NDKEvent4, NDKUser, NDKZapper } from "@nostr-dev-kit/ndk";
import chalk4 from "chalk";
async function pay(payload, amount) {
  try {
    if (!isValidPayload(payload)) {
      throw new Error("Invalid payload. Please provide a valid BOLT11 invoice or NIP-05 identifier.");
    }
    if (isBolt11(payload)) {
      await handleBolt11Payment(payload);
    } else if (isNip05(payload)) {
      await handleNip05Payment(payload, amount);
    } else if (isNpub(payload)) {
      await handleNpubPayment(payload, amount);
    }
  } catch (error) {
    console.error("Error making payment:", error.message);
  }
}
function isValidPayload(payload) {
  return isBolt11(payload) || isNip05(payload) || isNpub(payload);
}
function isBolt11(payload) {
  return payload.toLowerCase().startsWith("lnbc");
}
function isNip05(payload) {
  return payload.includes("@");
}
function isNpub(payload) {
  return payload.startsWith("npub1");
}
async function handleBolt11Payment(bolt11) {
  if (!activeWallet2) {
    console.log(chalk4.red("No active wallet found"));
    return;
  }
  const res = await activeWallet2.lnPay({ pr: bolt11 });
  console.log(res);
}
async function handleNip05Payment(nip05, amount) {
  const user = await NDKUser.fromNip05(nip05, ndk);
  if (!user) {
    console.log(
      chalk4.red("User not found")
    );
    return;
  }
  return payUser(user, amount);
}
async function handleNpubPayment(npub, amount) {
  const user = ndk.getUser({ npub });
  return payUser(user, amount);
}
async function payUser(user, amount) {
  if (!activeWallet2) {
    console.log(chalk4.red("No active wallet found"));
    return;
  }
  const zapper = new NDKZapper(user, amount * 1e3, "msat", {
    comment: "zap from nutsack-cli",
    lnPay: activeWallet2.lnPay.bind(activeWallet2),
    cashuPay: activeWallet2.cashuPay.bind(activeWallet2)
  });
  const res = await zapper.zap();
  res.forEach((r) => {
    if (r instanceof NDKEvent4) {
      console.log(r.encode());
    } else {
      console.log(r);
    }
  });
  return res;
}

// src/commands/condom/index.ts
import { NDKEvent as NDKEvent5, NDKPrivateKeySigner as NDKPrivateKeySigner3, NDKRelaySet } from "@nostr-dev-kit/ndk";
import chalk5 from "chalk";
import inquirer4 from "inquirer";
async function getCondoms() {
  const condoms = await ndk.fetchEvents({
    kinds: [26969]
  });
  const uniqueCondoms = /* @__PURE__ */ new Map();
  condoms.forEach((condom2) => {
    if (!uniqueCondoms.has(condom2.pubkey)) {
      uniqueCondoms.set(condom2.pubkey, condom2);
    }
  });
  return Array.from(uniqueCondoms.values());
}
function mapCondomToChoices(condom2) {
  const relays2 = condom2.getMatchingTags("relay").map((r) => r[1]);
  const fee = condom2.getMatchingTags("fee")[0];
  let name = `${condom2.author.npub.slice(0, 10)}} (Relays: ${relays2.join(", ")})`;
  if (fee) {
    name += chalk5.white(` (Fee: ${fee[1]} ${fee[2] ?? "sat"})`);
  }
  return {
    name,
    value: { pubkey: condom2.pubkey, relays: relays2, fee: fee ? parseInt(fee[1]) : void 0 }
  };
}
async function selectCondoms(condoms) {
  const { condoms: selectedCondoms } = await inquirer4.prompt([
    {
      type: "checkbox",
      name: "condoms",
      message: "Select condoms",
      choices: await Promise.all(condoms.map(mapCondomToChoices).filter((c) => c !== void 0))
    }
  ]);
  return selectedCondoms;
}
async function condom(content) {
  const condoms = await getCondoms();
  const selectedCondoms = await selectCondoms(condoms);
  return new Promise((resolve, reject) => {
    constructMessage(content, selectedCondoms, resolve);
  });
}
async function getProofs(condoms) {
  const fees = [];
  for (const condom2 of condoms) {
    fees.push(condom2.fee ?? 0);
  }
  if (!activeWallet2) {
    console.error("No wallet found. Please create a wallet first.");
    process.exit(1);
  }
  const nutsToMint = fees.filter((f) => f > 0);
  if (nutsToMint.length === 0) {
    return [];
  }
  const nuts = await activeWallet2.mintNuts(nutsToMint, "sat");
  if (nuts && nuts.length > 0) {
    console.log(chalk5.blue("Minted", nuts.length, "nuts"));
  }
  if (!nuts) {
    console.error("Failed to mint nuts");
    process.exit(1);
  }
  const ret = [];
  for (let i = 0; i < condoms.length; i++) {
    if (fees[i] === 0) {
      ret.push(void 0);
    } else {
      ret.push(nuts.shift());
    }
  }
  return ret;
}
async function constructMessage(content, condoms, resolve) {
  const targetMessage = new NDKEvent5(ndk, { kind: 1, content });
  await targetMessage.sign();
  const hops = [];
  let relaySet;
  let outerWrapEvent = targetMessage;
  const proofs = await getProofs(condoms);
  for (let i = condoms.length - 1; i >= 0; i--) {
    const condom2 = condoms[i];
    condom2.proof = proofs[i];
    let nextHop = condoms[i + 1];
    if (!nextHop) {
      nextHop = {
        relays: ndk.explicitRelayUrls
      };
    }
    console.log({ condom: condom2, nextHop, i });
    outerWrapEvent = await createWrap(
      condom2,
      nextHop,
      JSON.stringify(outerWrapEvent.rawEvent())
    );
    hops.push({ eventId: outerWrapEvent.id, relays: condom2.relays });
  }
  let startTime = Date.now();
  hops.push({ eventId: targetMessage.id, relays: ndk.explicitRelayUrls });
  for (let index = 0; index < hops.length; index++) {
    const hop = hops[index];
    relaySet = NDKRelaySet.fromRelayUrls(hop.relays, ndk);
    const sub = ndk.subscribe({ ids: [hop.eventId] }, { groupable: false, skipOptimisticPublishEvent: true }, relaySet);
    sub.on("event", (event, relay) => {
      const t = Date.now();
      const time = t - startTime;
      startTime = t;
      let relayUrl = relay == null ? void 0 : relay.url;
      relayUrl ??= condoms[index].relays[0];
      const fixedLengthUrl = relayUrl.substring(0, 30).padEnd(30, " ");
      console.log(`${chalk5.bgGray(event.id.substring(0, 6))} ${chalk5.green(fixedLengthUrl)} ${chalk5.yellow(time + "ms")}`);
      if (event.id === targetMessage.id) {
        console.log(chalk5.bgMagenta("Onion-routed message published!"));
        console.log(chalk5.white("https://nostr.at/" + targetMessage.encode()));
        resolve();
      }
    });
  }
  relaySet = NDKRelaySet.fromRelayUrls(condoms[0].relays, ndk);
  startTime = Date.now();
  const r = await outerWrapEvent.publish(relaySet);
}
async function createWrap(hop, nextHop, payload) {
  const nextHopPayload = {
    relays: nextHop.relays,
    payload
  };
  if (nextHop.pubkey) {
    nextHopPayload.pubkey = nextHop.pubkey;
  }
  if (hop.proof) {
    nextHopPayload.proof = hop.proof;
    nextHopPayload.mint = "https://mint.coinos.io";
    nextHopPayload.unit = "sat";
  }
  const signer = NDKPrivateKeySigner3.generate();
  const event = new NDKEvent5(ndk, {
    kind: 20690,
    content: JSON.stringify(nextHopPayload),
    tags: [
      ["p", hop.pubkey]
    ]
  });
  const hopUser = await ndk.getUser({ pubkey: hop.pubkey });
  await event.encrypt(hopUser, signer, "nip44");
  await event.sign(signer);
  return event;
}

// src/commands/route-messages.ts
import chalk6 from "chalk";
import { NDKEvent as NDKEvent6, NDKRelaySet as NDKRelaySet2 } from "@nostr-dev-kit/ndk";
import { CashuMint, CashuWallet } from "@cashu/cashu-ts";
import readline from "readline";
async function announceMyself(relays2, fee) {
  const event = new NDKEvent6(ndk);
  event.kind = 26969;
  event.tags = relays2.map((r2) => ["relay", r2]);
  if (fee) {
    event.tags.push(["fee", fee.toString(), "sat"]);
  }
  const r = await event.publish();
  console.log(chalk6.white("Announced in", r.size, "relays that I route events in", relays2.join(", ")));
  setTimeout(() => {
    announceMyself(relays2, fee);
  }, 25e4);
}
async function routeMessages({ onionRelay, fee }) {
  var _a;
  const relays2 = onionRelay;
  console.log(chalk6.green("Starting condom daemon... Press Enter to stop."));
  let relaySet;
  if (relays2.length > 0) {
    relaySet = new NDKRelaySet2(/* @__PURE__ */ new Set(), ndk);
    for (const relay of relays2) {
      const r = ndk.pool.getRelay(relay);
      relaySet.addRelay(r);
    }
  }
  const myPubkey = (_a = ndk.activeUser) == null ? void 0 : _a.pubkey;
  if (!myPubkey) {
    console.log(chalk6.red("No active user found"));
    return;
  }
  const sub = ndk.subscribe({
    kinds: [20690],
    "#p": [myPubkey],
    limit: 0
  }, void 0, relaySet);
  sub.on("event", processEvent);
  announceMyself(relays2, fee);
  console.log(chalk6.green("Listening for messages on", relays2.join(", "), "for", myPubkey));
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    rl.on("line", () => {
      console.log(chalk6.yellow("Stopping the daemon..."));
      sub.stop();
      rl.close();
      resolve();
    });
  });
}
async function processEvent(event) {
  await event.decrypt(void 0, void 0, "nip44");
  const content = JSON.parse(event.content);
  const relays2 = content.relays;
  const proof = content.proof;
  const mint = content.mint;
  const unit = content.unit;
  const payload = content.payload;
  console.log({ relays: relays2 });
  console.log(chalk6.bgBlue("Received an event: ", event.id, "will publish to", relays2.join(", ")));
  const relaySet = NDKRelaySet2.fromRelayUrls(relays2, ndk);
  const publishEvent = new NDKEvent6(ndk, JSON.parse(payload));
  if (proof) {
    console.log(chalk6.green("\u{1F95C} We found a nice little nut, worth", proof.amount, "sat"));
    const wallet = activeWallet;
    if (!wallet) {
      console.log(chalk6.red("No wallet found"));
      return;
    }
    const cashuWallet = new CashuWallet(new CashuMint(mint));
    try {
      const proofs = await cashuWallet.receiveTokenEntry({
        proofs: [proof],
        mint
      });
      await wallet.saveProofs(proofs, mint);
    } catch (e) {
      console.log(chalk6.red("Error receiving proofs:", e));
    }
  }
  const r = await publishEvent.publish(relaySet);
  const pTag = publishEvent.tagValue("p");
  console.log(chalk6.bgMagenta("Published", publishEvent.id, " to ", Array.from(r).map((r2) => r2.url).join(", ")), "for", pTag);
}

// src/main.ts
import chalk7 from "chalk";
import { NDKEvent as NDKEvent8 } from "@nostr-dev-kit/ndk";

// src/commands/sweep-nutzaps.ts
async function sweepNutzaps() {
  console.log("Sweeping nutzaps...");
}

// src/commands/destroy-all.ts
import { NDKEvent as NDKEvent7, NDKKind as NDKKind2 } from "@nostr-dev-kit/ndk";
async function destroyAllProofs() {
  var _a;
  if (!activeWallet2) {
    console.error("No active wallet");
    return;
  }
  const deleteEvent = new NDKEvent7(ndk, {
    kind: 5,
    tags: [["k", NDKKind2.CashuToken.toString()]]
  });
  activeWallet2.tokens.forEach(async (token) => {
    deleteEvent.tags.push(["e", token.id]);
  });
  await deleteEvent.publish((_a = activeWallet2) == null ? void 0 : _a.relaySet);
}

// src/main.ts
var program = new Command();
var loginPayload = null;
var relays = [];
program.version("1.0.0").description("Your application description").option("--bunker <bunker-uri>", "Provide a bunker URI", (uri) => {
  loginPayload = uri;
}).option("--nsec <nsec>", "Provide an NSEC key", (nsec) => {
  loginPayload = nsec;
}).option("-r, --relay <url>", "Add a relay URL", (url, urls) => {
  urls.push(normalizeRelayUrl(url));
  return urls;
}, []);
program.command("deposit").description("Deposit funds to a wallet").option("--wallet <wallet-id>", "Specify the wallet ID").option("--mint <mint-url>", "Specify the mint URL").option("--amount <amount>", "Specify the amount to deposit").option("--unit <unit>", "Specify the unit of the deposit").action(async (options) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await depositToWallet(options.mint, options.amount, options.unit);
});
program.command("create-wallet").description("Create a new wallet with specified options").option("--name <name>", "Specify the wallet name").option("--mint <url>", "Add a mint URL (can be used multiple times)", (url, urls) => {
  urls.push(normalizeRelayUrl(url));
  return urls;
}, []).option("--unit <unit>", "Specify the default unit for the wallet").action(async (options) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await createWallet(options.name, options.mint, options.unit);
});
program.command("sweep-nutzaps").description("Sweep all nutzaps").action(async () => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await sweepNutzaps();
});
program.command("pay <payload>").description("Make a payment from your wallet (BOLT11 invoice or NIP-05)").option("--amount <amount>", "Specify the amount to pay").action(async (payload, options) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await pay(payload, options.amount);
});
program.command("cli").description("Start the interactive CLI mode").action(startInteractiveMode);
program.command("ls").description("List wallets").option("-l", "Show all details").action(async (options) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await listWallets(options.l);
  let events = /* @__PURE__ */ new Set();
  let events2 = /* @__PURE__ */ new Set();
  let sub2;
  let countAfterEose = -1;
  ndk.debug.enabled = true;
  for (let i = 0; i < 50; i++) {
    console.log(i);
    ndk.subscribe([{ kinds: [999], limit: i + 1 }], { groupable: true }, void 0, true);
  }
});
program.command("ls-tokens").description("List all tokens in the wallet").option("-v, --verbose", "Show verbose output").action(async (options) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await listTokens(options.verbose);
  process.exit(0);
});
program.command("publish <message>").description("Publish a message").action(async (message) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  const event = new NDKEvent8(ndk, {
    kind: 1,
    content: message
  });
  await event.sign();
  await event.publish();
  console.log("published https://njump.me/" + event.encode());
});
program.command("route").description("Route messages").option("--onion-relay <url>", "Relay where to listen for incoming onion-routed messages", (url, urls) => {
  urls.push(url);
  return urls;
}, []).option("--fee <amount>", "Fee in sats for the relay to relay the message").action(async (opts) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  routeMessages(opts);
});
program.command("validate").description("Validate all proofs").action(async () => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await new Promise((resolve) => setTimeout(resolve, 1e3));
  if (!activeWallet2) {
    console.error("No wallet found. Please create a wallet first.");
    process.exit(1);
  }
  const res = await activeWallet2.checkProofs();
  console.log(res);
});
program.command("token <amount> <unit>").description("Create a new token").action(async (amount, unit) => {
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  if (!activeWallet2) {
    console.error("No wallet found. Please create a wallet first.");
    process.exit(1);
  }
  const mintTokens = activeWallet2.mintTokens;
  for (const [mint, tokens] of Object.entries(mintTokens)) {
    console.log(mint);
    for (const token of tokens) {
      console.log(token.proofs.map((p) => p.amount));
    }
  }
  const proofs = await activeWallet2.mintNuts([1, 1], "sat");
  console.log("minted proofs", proofs);
});
async function promptForNsec() {
  const { nsec } = await inquirer5.prompt([
    {
      type: "password",
      name: "nsec",
      message: "Enter your NSEC key:",
      validate: (input) => input.length > 0 || "NSEC key cannot be empty"
    }
  ]);
  return nsec;
}
async function ensureNsec() {
  if (!loginPayload) {
    loginPayload = await readNsecFromFile();
    if (!loginPayload) {
      loginPayload = await promptForNsec();
      await handleNsecCommand(loginPayload);
    }
  }
}
async function promptForCommand() {
  var _a;
  const user = (_a = ndk.activeUser) == null ? void 0 : _a.npub;
  const { command } = await inquirer5.prompt([
    {
      type: "input",
      name: "command",
      message: `${chalk7.bgGray("[" + (user == null ? void 0 : user.substring(0, 10)) + "]")} \u{1F95C} >`
    }
  ]);
  if (command.toLowerCase() === "help") {
    console.log("Available commands:");
    console.log("  help                - Show this help message");
    console.log("  create              - Create a new wallet");
    console.log("  publish [message]   - Publish a new note with an onion-routed message");
    console.log("  set-nutzap-wallet [naddr...]   - Set the NIP-60 wallet that should receive nutzaps");
    console.log("  ls [-l]             - List wallets (use -l to show all details)");
    console.log("  deposit             - Deposit funds to a wallet");
    console.log("  destroy-all-proofs  - Destroy all tokens in the wallet");
    console.log("  sweep-nutzaps       - Sweep all nutzaps");
    console.log("  exit                - Quit the application");
    console.log("  create-wallet       - Create a new wallet with specified options");
    console.log("  ls-tokens [-v]      - List all tokens in the wallet (use -v for verbose output)");
    console.log("  pay <payload>       - Make a payment (BOLT11 invoice or NIP-05)");
  } else if (command.toLowerCase() === "deposit") {
    await depositToWallet();
  } else if (command.toLowerCase().startsWith("publish ")) {
    const message = command.replace(/^publish /, "").trim();
    await condom(message);
    await new Promise((resolve) => setTimeout(resolve, 1e3));
  } else if (command.toLowerCase() === "destroy-all-proofs") {
    await destroyAllProofs();
  } else if (command.toLowerCase() === "sweep-nutzaps") {
    await sweepNutzaps();
  } else if (command.toLowerCase().startsWith("route")) {
    const args = command.split(" ");
    const opts = {
      onionRelay: [],
      fee: 0
    };
    for (let i = 1; i < args.length; i++) {
      if (args[i].startsWith("--fee")) {
        opts.fee = parseInt(args[i + 1]);
        args.splice(i, 2);
        break;
      } else {
        opts.onionRelay.push(args[i]);
      }
    }
    await routeMessages(opts);
  } else if (command.toLowerCase().startsWith("deposit ")) {
    const args = command.split(" ");
    if (args.length > 4) {
      console.log("Usage: deposit [mint-url] [amount] [unit]");
    } else {
      const [, mintUrl, amount, unit] = args;
      await depositToWallet(mintUrl, amount, unit);
    }
  } else if (command.toLowerCase().startsWith("create")) {
    const createdWallet = await createWallet();
    if (createdWallet) {
      const { setAsNutzap } = await inquirer5.prompt([
        {
          type: "confirm",
          name: "setAsNutzap",
          message: "Do you want to set this wallet as the Nutzap wallet?",
          default: false
        }
      ]);
      if (setAsNutzap) {
        await setNutzapWallet(createdWallet.event.encode());
      }
    }
  } else if (command.toLowerCase().startsWith("set-nutzap-wallet")) {
    const naddr = command.split(" ")[1];
    await setNutzapWallet(naddr);
  } else if (/^ls(\s|$)/.test(command.toLowerCase())) {
    const args = command.split(" ");
    const showAll = args.includes("-l");
    await listWallets(showAll);
  } else if (command.toLowerCase().startsWith("ls-tokens")) {
    const args = command.split(" ");
    const verbose = args.includes("-v");
    await listTokens(verbose);
  } else if (command.toLowerCase().startsWith("pay ")) {
    const payload = command.split(" ")[1];
    const { amount } = await inquirer5.prompt([
      {
        type: "input",
        name: "amount",
        message: "Enter the amount to pay (optional):"
      }
    ]);
    await pay(payload, parseInt(amount));
  } else {
    try {
      await program.parseAsync(command.split(" "), { from: "user" });
    } catch (error) {
      console.error("Error:", error.message);
    }
  }
  await promptForCommand();
}
async function startInteractiveMode() {
  console.log('Welcome to the interactive CLI. Type "help" for available commands or "exit" to quit.');
  await ensureNsec();
  await initNdk(relays, loginPayload);
  await initWallet();
  await promptForCommand();
}
async function main() {
  program.parse(process.argv);
  const options = program.opts();
  if (options.nsec) loginPayload = options.nsec;
  if (options.bunker) loginPayload = options.bunker;
  if (options.relay) {
    relays = options.relay;
  }
  const command = program.args[0];
}
main().catch(console.error);
