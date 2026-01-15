import { c as createComponent, b as createAstro, i as addAttribute, l as renderScript, a as renderTemplate, r as renderComponent, n as renderHead, o as renderSlot, u as unescapeHTML, p as Fragment } from './astro/server_CUMT7Dv3.mjs';
import 'piccolore';
/* empty css                          */
import 'clsx';
import { s as supabase, d as dataService } from './dataService_Bp0vcODm.mjs';
import { b as requireReact, a as reactExports, R as React } from './_@astro-renderers_8ZcaT4W7.mjs';
import { s as slugify } from './helpers_xme2WEyl.mjs';
import { X, AlertCircle, Mail, Lock, EyeOff, Eye, Loader2, ArrowRight } from 'lucide-react';

const $$Astro$1 = createAstro();
const $$ClientRouter = createComponent(($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro$1, $$props, $$slots);
  Astro2.self = $$ClientRouter;
  const { fallback = "animate" } = Astro2.props;
  return renderTemplate`<meta name="astro-view-transitions-enabled" content="true"><meta name="astro-view-transitions-fallback"${addAttribute(fallback, "content")}>${renderScript($$result, "/Users/pateez/Desktop/pateeznews/node_modules/astro/components/ClientRouter.astro?astro&type=script&index=0&lang.ts")}`;
}, "/Users/pateez/Desktop/pateeznews/node_modules/astro/components/ClientRouter.astro", void 0);

var jsxRuntime = {exports: {}};

var reactJsxRuntime_production = {};

/**
 * @license React
 * react-jsx-runtime.production.js
 *
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

var hasRequiredReactJsxRuntime_production;

function requireReactJsxRuntime_production () {
	if (hasRequiredReactJsxRuntime_production) return reactJsxRuntime_production;
	hasRequiredReactJsxRuntime_production = 1;
	var REACT_ELEMENT_TYPE = Symbol.for("react.transitional.element"),
	  REACT_FRAGMENT_TYPE = Symbol.for("react.fragment");
	function jsxProd(type, config, maybeKey) {
	  var key = null;
	  void 0 !== maybeKey && (key = "" + maybeKey);
	  void 0 !== config.key && (key = "" + config.key);
	  if ("key" in config) {
	    maybeKey = {};
	    for (var propName in config)
	      "key" !== propName && (maybeKey[propName] = config[propName]);
	  } else maybeKey = config;
	  config = maybeKey.ref;
	  return {
	    $$typeof: REACT_ELEMENT_TYPE,
	    type: type,
	    key: key,
	    ref: void 0 !== config ? config : null,
	    props: maybeKey
	  };
	}
	reactJsxRuntime_production.Fragment = REACT_FRAGMENT_TYPE;
	reactJsxRuntime_production.jsx = jsxProd;
	reactJsxRuntime_production.jsxs = jsxProd;
	return reactJsxRuntime_production;
}

var reactJsxRuntime_development = {};

/**
 * @license React
 * react-jsx-runtime.development.js
 *
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

var hasRequiredReactJsxRuntime_development;

function requireReactJsxRuntime_development () {
	if (hasRequiredReactJsxRuntime_development) return reactJsxRuntime_development;
	hasRequiredReactJsxRuntime_development = 1;
	"production" !== process.env.NODE_ENV &&
	  (function () {
	    function getComponentNameFromType(type) {
	      if (null == type) return null;
	      if ("function" === typeof type)
	        return type.$$typeof === REACT_CLIENT_REFERENCE
	          ? null
	          : type.displayName || type.name || null;
	      if ("string" === typeof type) return type;
	      switch (type) {
	        case REACT_FRAGMENT_TYPE:
	          return "Fragment";
	        case REACT_PROFILER_TYPE:
	          return "Profiler";
	        case REACT_STRICT_MODE_TYPE:
	          return "StrictMode";
	        case REACT_SUSPENSE_TYPE:
	          return "Suspense";
	        case REACT_SUSPENSE_LIST_TYPE:
	          return "SuspenseList";
	        case REACT_ACTIVITY_TYPE:
	          return "Activity";
	      }
	      if ("object" === typeof type)
	        switch (
	          ("number" === typeof type.tag &&
	            console.error(
	              "Received an unexpected object in getComponentNameFromType(). This is likely a bug in React. Please file an issue."
	            ),
	          type.$$typeof)
	        ) {
	          case REACT_PORTAL_TYPE:
	            return "Portal";
	          case REACT_CONTEXT_TYPE:
	            return type.displayName || "Context";
	          case REACT_CONSUMER_TYPE:
	            return (type._context.displayName || "Context") + ".Consumer";
	          case REACT_FORWARD_REF_TYPE:
	            var innerType = type.render;
	            type = type.displayName;
	            type ||
	              ((type = innerType.displayName || innerType.name || ""),
	              (type = "" !== type ? "ForwardRef(" + type + ")" : "ForwardRef"));
	            return type;
	          case REACT_MEMO_TYPE:
	            return (
	              (innerType = type.displayName || null),
	              null !== innerType
	                ? innerType
	                : getComponentNameFromType(type.type) || "Memo"
	            );
	          case REACT_LAZY_TYPE:
	            innerType = type._payload;
	            type = type._init;
	            try {
	              return getComponentNameFromType(type(innerType));
	            } catch (x) {}
	        }
	      return null;
	    }
	    function testStringCoercion(value) {
	      return "" + value;
	    }
	    function checkKeyStringCoercion(value) {
	      try {
	        testStringCoercion(value);
	        var JSCompiler_inline_result = !1;
	      } catch (e) {
	        JSCompiler_inline_result = true;
	      }
	      if (JSCompiler_inline_result) {
	        JSCompiler_inline_result = console;
	        var JSCompiler_temp_const = JSCompiler_inline_result.error;
	        var JSCompiler_inline_result$jscomp$0 =
	          ("function" === typeof Symbol &&
	            Symbol.toStringTag &&
	            value[Symbol.toStringTag]) ||
	          value.constructor.name ||
	          "Object";
	        JSCompiler_temp_const.call(
	          JSCompiler_inline_result,
	          "The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",
	          JSCompiler_inline_result$jscomp$0
	        );
	        return testStringCoercion(value);
	      }
	    }
	    function getTaskName(type) {
	      if (type === REACT_FRAGMENT_TYPE) return "<>";
	      if (
	        "object" === typeof type &&
	        null !== type &&
	        type.$$typeof === REACT_LAZY_TYPE
	      )
	        return "<...>";
	      try {
	        var name = getComponentNameFromType(type);
	        return name ? "<" + name + ">" : "<...>";
	      } catch (x) {
	        return "<...>";
	      }
	    }
	    function getOwner() {
	      var dispatcher = ReactSharedInternals.A;
	      return null === dispatcher ? null : dispatcher.getOwner();
	    }
	    function UnknownOwner() {
	      return Error("react-stack-top-frame");
	    }
	    function hasValidKey(config) {
	      if (hasOwnProperty.call(config, "key")) {
	        var getter = Object.getOwnPropertyDescriptor(config, "key").get;
	        if (getter && getter.isReactWarning) return false;
	      }
	      return void 0 !== config.key;
	    }
	    function defineKeyPropWarningGetter(props, displayName) {
	      function warnAboutAccessingKey() {
	        specialPropKeyWarningShown ||
	          ((specialPropKeyWarningShown = true),
	          console.error(
	            "%s: `key` is not a prop. Trying to access it will result in `undefined` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://react.dev/link/special-props)",
	            displayName
	          ));
	      }
	      warnAboutAccessingKey.isReactWarning = true;
	      Object.defineProperty(props, "key", {
	        get: warnAboutAccessingKey,
	        configurable: true
	      });
	    }
	    function elementRefGetterWithDeprecationWarning() {
	      var componentName = getComponentNameFromType(this.type);
	      didWarnAboutElementRef[componentName] ||
	        ((didWarnAboutElementRef[componentName] = true),
	        console.error(
	          "Accessing element.ref was removed in React 19. ref is now a regular prop. It will be removed from the JSX Element type in a future release."
	        ));
	      componentName = this.props.ref;
	      return void 0 !== componentName ? componentName : null;
	    }
	    function ReactElement(type, key, props, owner, debugStack, debugTask) {
	      var refProp = props.ref;
	      type = {
	        $$typeof: REACT_ELEMENT_TYPE,
	        type: type,
	        key: key,
	        props: props,
	        _owner: owner
	      };
	      null !== (void 0 !== refProp ? refProp : null)
	        ? Object.defineProperty(type, "ref", {
	            enumerable: false,
	            get: elementRefGetterWithDeprecationWarning
	          })
	        : Object.defineProperty(type, "ref", { enumerable: false, value: null });
	      type._store = {};
	      Object.defineProperty(type._store, "validated", {
	        configurable: false,
	        enumerable: false,
	        writable: true,
	        value: 0
	      });
	      Object.defineProperty(type, "_debugInfo", {
	        configurable: false,
	        enumerable: false,
	        writable: true,
	        value: null
	      });
	      Object.defineProperty(type, "_debugStack", {
	        configurable: false,
	        enumerable: false,
	        writable: true,
	        value: debugStack
	      });
	      Object.defineProperty(type, "_debugTask", {
	        configurable: false,
	        enumerable: false,
	        writable: true,
	        value: debugTask
	      });
	      Object.freeze && (Object.freeze(type.props), Object.freeze(type));
	      return type;
	    }
	    function jsxDEVImpl(
	      type,
	      config,
	      maybeKey,
	      isStaticChildren,
	      debugStack,
	      debugTask
	    ) {
	      var children = config.children;
	      if (void 0 !== children)
	        if (isStaticChildren)
	          if (isArrayImpl(children)) {
	            for (
	              isStaticChildren = 0;
	              isStaticChildren < children.length;
	              isStaticChildren++
	            )
	              validateChildKeys(children[isStaticChildren]);
	            Object.freeze && Object.freeze(children);
	          } else
	            console.error(
	              "React.jsx: Static children should always be an array. You are likely explicitly calling React.jsxs or React.jsxDEV. Use the Babel transform instead."
	            );
	        else validateChildKeys(children);
	      if (hasOwnProperty.call(config, "key")) {
	        children = getComponentNameFromType(type);
	        var keys = Object.keys(config).filter(function (k) {
	          return "key" !== k;
	        });
	        isStaticChildren =
	          0 < keys.length
	            ? "{key: someKey, " + keys.join(": ..., ") + ": ...}"
	            : "{key: someKey}";
	        didWarnAboutKeySpread[children + isStaticChildren] ||
	          ((keys =
	            0 < keys.length ? "{" + keys.join(": ..., ") + ": ...}" : "{}"),
	          console.error(
	            'A props object containing a "key" prop is being spread into JSX:\n  let props = %s;\n  <%s {...props} />\nReact keys must be passed directly to JSX without using spread:\n  let props = %s;\n  <%s key={someKey} {...props} />',
	            isStaticChildren,
	            children,
	            keys,
	            children
	          ),
	          (didWarnAboutKeySpread[children + isStaticChildren] = true));
	      }
	      children = null;
	      void 0 !== maybeKey &&
	        (checkKeyStringCoercion(maybeKey), (children = "" + maybeKey));
	      hasValidKey(config) &&
	        (checkKeyStringCoercion(config.key), (children = "" + config.key));
	      if ("key" in config) {
	        maybeKey = {};
	        for (var propName in config)
	          "key" !== propName && (maybeKey[propName] = config[propName]);
	      } else maybeKey = config;
	      children &&
	        defineKeyPropWarningGetter(
	          maybeKey,
	          "function" === typeof type
	            ? type.displayName || type.name || "Unknown"
	            : type
	        );
	      return ReactElement(
	        type,
	        children,
	        maybeKey,
	        getOwner(),
	        debugStack,
	        debugTask
	      );
	    }
	    function validateChildKeys(node) {
	      isValidElement(node)
	        ? node._store && (node._store.validated = 1)
	        : "object" === typeof node &&
	          null !== node &&
	          node.$$typeof === REACT_LAZY_TYPE &&
	          ("fulfilled" === node._payload.status
	            ? isValidElement(node._payload.value) &&
	              node._payload.value._store &&
	              (node._payload.value._store.validated = 1)
	            : node._store && (node._store.validated = 1));
	    }
	    function isValidElement(object) {
	      return (
	        "object" === typeof object &&
	        null !== object &&
	        object.$$typeof === REACT_ELEMENT_TYPE
	      );
	    }
	    var React = requireReact(),
	      REACT_ELEMENT_TYPE = Symbol.for("react.transitional.element"),
	      REACT_PORTAL_TYPE = Symbol.for("react.portal"),
	      REACT_FRAGMENT_TYPE = Symbol.for("react.fragment"),
	      REACT_STRICT_MODE_TYPE = Symbol.for("react.strict_mode"),
	      REACT_PROFILER_TYPE = Symbol.for("react.profiler"),
	      REACT_CONSUMER_TYPE = Symbol.for("react.consumer"),
	      REACT_CONTEXT_TYPE = Symbol.for("react.context"),
	      REACT_FORWARD_REF_TYPE = Symbol.for("react.forward_ref"),
	      REACT_SUSPENSE_TYPE = Symbol.for("react.suspense"),
	      REACT_SUSPENSE_LIST_TYPE = Symbol.for("react.suspense_list"),
	      REACT_MEMO_TYPE = Symbol.for("react.memo"),
	      REACT_LAZY_TYPE = Symbol.for("react.lazy"),
	      REACT_ACTIVITY_TYPE = Symbol.for("react.activity"),
	      REACT_CLIENT_REFERENCE = Symbol.for("react.client.reference"),
	      ReactSharedInternals =
	        React.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE,
	      hasOwnProperty = Object.prototype.hasOwnProperty,
	      isArrayImpl = Array.isArray,
	      createTask = console.createTask
	        ? console.createTask
	        : function () {
	            return null;
	          };
	    React = {
	      react_stack_bottom_frame: function (callStackForError) {
	        return callStackForError();
	      }
	    };
	    var specialPropKeyWarningShown;
	    var didWarnAboutElementRef = {};
	    var unknownOwnerDebugStack = React.react_stack_bottom_frame.bind(
	      React,
	      UnknownOwner
	    )();
	    var unknownOwnerDebugTask = createTask(getTaskName(UnknownOwner));
	    var didWarnAboutKeySpread = {};
	    reactJsxRuntime_development.Fragment = REACT_FRAGMENT_TYPE;
	    reactJsxRuntime_development.jsx = function (type, config, maybeKey) {
	      var trackActualOwner =
	        1e4 > ReactSharedInternals.recentlyCreatedOwnerStacks++;
	      return jsxDEVImpl(
	        type,
	        config,
	        maybeKey,
	        false,
	        trackActualOwner
	          ? Error("react-stack-top-frame")
	          : unknownOwnerDebugStack,
	        trackActualOwner ? createTask(getTaskName(type)) : unknownOwnerDebugTask
	      );
	    };
	    reactJsxRuntime_development.jsxs = function (type, config, maybeKey) {
	      var trackActualOwner =
	        1e4 > ReactSharedInternals.recentlyCreatedOwnerStacks++;
	      return jsxDEVImpl(
	        type,
	        config,
	        maybeKey,
	        true,
	        trackActualOwner
	          ? Error("react-stack-top-frame")
	          : unknownOwnerDebugStack,
	        trackActualOwner ? createTask(getTaskName(type)) : unknownOwnerDebugTask
	      );
	    };
	  })();
	return reactJsxRuntime_development;
}

var hasRequiredJsxRuntime;

function requireJsxRuntime () {
	if (hasRequiredJsxRuntime) return jsxRuntime.exports;
	hasRequiredJsxRuntime = 1;

	if (process.env.NODE_ENV === 'production') {
	  jsxRuntime.exports = requireReactJsxRuntime_production();
	} else {
	  jsxRuntime.exports = requireReactJsxRuntime_development();
	}
	return jsxRuntime.exports;
}

var jsxRuntimeExports = requireJsxRuntime();

const internalFetchHeaders = {};

let navigateOnServerWarned = false;
async function navigate(href, options) {
  {
    if (!navigateOnServerWarned) {
      const warning = new Error(
        "The view transitions client API was called during a server side render. This may be unintentional as the navigate() function is expected to be called in response to user interactions. Please make sure that your usage is correct."
      );
      warning.name = "Warning";
      console.warn(warning);
      navigateOnServerWarned = true;
    }
    return;
  }
}

const prefetchedUrls = /* @__PURE__ */ new Set();
function prefetch(url, opts) {
  url = url.replace(/#.*/, "");
  if (!canPrefetchUrl(url)) return;
  prefetchedUrls.add(url);
  if (document.createElement("link").relList?.supports?.("prefetch") && opts?.with !== "fetch") {
    const link = document.createElement("link");
    link.rel = "prefetch";
    link.setAttribute("href", url);
    document.head.append(link);
  } else {
    const headers = new Headers();
    for (const [key, value] of Object.entries(internalFetchHeaders)) {
      headers.set(key, value);
    }
    fetch(url, { priority: "low", headers });
  }
}
function canPrefetchUrl(url, ignoreSlowConnection) {
  if (!navigator.onLine) return false;
  if (isSlowConnection()) return false;
  try {
    const urlObj = new URL(url, location.href);
    return location.origin === urlObj.origin && (location.pathname !== urlObj.pathname || location.search !== urlObj.search) && !prefetchedUrls.has(url);
  } catch {
  }
  return false;
}
function isSlowConnection() {
  if ("connection" in navigator) {
    const conn = navigator.connection;
    return conn.saveData || /2g/.test(conn.effectiveType);
  }
  return false;
}

const flattenTranslations = (input, prefix = "", out = {}) => {
  if (!input || typeof input !== "object") return out;
  for (const [key, value] of Object.entries(input)) {
    const nextKey = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === "object" && !Array.isArray(value)) {
      flattenTranslations(value, nextKey, out);
      continue;
    }
    if (typeof value === "string") out[nextKey] = value;
    else if (typeof value === "number" || typeof value === "boolean") out[nextKey] = String(value);
    else if (value == null) out[nextKey] = "";
    else out[nextKey] = Array.isArray(value) ? JSON.stringify(value) : String(value);
  }
  return out;
};
const translationCache = {};
const loadLocaleData = async (langCode) => {
  if (translationCache[langCode]) return translationCache[langCode];
  try {
    const baseLang = "tr";
    if (typeof window !== "undefined") {
      const storedTranslation = localStorage.getItem(`pateez_locale_${langCode}`);
      if (storedTranslation) {
        try {
          const parsed = JSON.parse(storedTranslation);
          if (parsed && Object.keys(parsed).length > 0) {
            const userFlat = flattenTranslations(parsed);
            if (langCode === baseLang) {
              translationCache[langCode] = userFlat;
              return userFlat;
            }
            const fallback = await import('./tr_DZJAFh45.mjs');
            const fallbackFlat = flattenTranslations(fallback.default || fallback);
            const merged2 = { ...fallbackFlat, ...userFlat };
            translationCache[langCode] = merged2;
            return merged2;
          }
        } catch (e) {
          console.error("Local storage parse error", e);
        }
      }
    }
    let data;
    const loadTarget = async () => {
      switch (langCode) {
        case "tr":
          return import('./tr_DZJAFh45.mjs').then((m) => m.default || m);
        case "en":
          return import('./en_1eHjp7wk.mjs').then((m) => m.default || m);
        case "ar":
          return import('./ar_Bd1oRJnI.mjs').then((m) => m.default || m);
        default:
          return import('./tr_DZJAFh45.mjs').then((m) => m.default || m);
      }
    };
    if (langCode === baseLang) {
      data = await loadTarget();
      const flat2 = flattenTranslations(data);
      translationCache[langCode] = flat2;
      return flat2;
    }
    const [targetData, baseData] = await Promise.all([
      loadTarget(),
      import('./tr_DZJAFh45.mjs').then((m) => m.default || m)
    ]);
    const flat = flattenTranslations(targetData);
    const baseFlat = flattenTranslations(baseData);
    const merged = { ...baseFlat, ...flat };
    translationCache[langCode] = merged;
    return merged;
  } catch (error) {
    console.error(`Critical: Language load failed for ${langCode}`, error);
    return { "nav.home": "AKIŞ" };
  }
};

const LanguageContext = reactExports.createContext(void 0);
const DEFAULT_LANG = {
  code: "tr",
  name: "Türkçe",
  direction: "ltr",
  status: "active",
  flag_code: "tr",
  is_default: true
};
const STATIC_TR = {
  "nav.home": "Ana Sayfa",
  "nav.agenda": "Gündem",
  "nav.pateezvideotv": "Video",
  "nav.special": "Eğlence",
  "nav.search": "Haber ara...",
  "nav.login": "Giriş Yap",
  "sidebar.publishers": "Yayıncılar",
  "sidebar.categories": "Kategoriler",
  "feed.title_prefix": "Sizin İçin",
  "feed.title_suffix": "Seçtiklerimiz",
  "feed.latest": "En Yeni",
  "feed.popular": "Popüler"
};
const LanguageProvider = ({ children, initialLang, initialTranslations }) => {
  const [currentLang, setCurrentLang] = reactExports.useState(initialLang || DEFAULT_LANG);
  const [availableLanguages, setAvailableLanguages] = reactExports.useState([initialLang || DEFAULT_LANG]);
  const [translations, setTranslations] = reactExports.useState(initialTranslations || STATIC_TR);
  const [loading, setLoading] = reactExports.useState(!initialTranslations);
  const getInitialLangCode = reactExports.useCallback(() => {
    const saved = localStorage.getItem("pateez_lang");
    if (saved) return saved;
    const browserLang = navigator.language.split("-")[0];
    return browserLang || DEFAULT_LANG.code;
  }, []);
  const writeLangCookie = reactExports.useCallback((code) => {
    try {
      document.cookie = `pateez_lang=${encodeURIComponent(code)}; path=/; max-age=31536000; SameSite=Lax`;
    } catch {
    }
  }, []);
  const loadTranslations = reactExports.useCallback(async (lang) => {
    try {
      const data = await loadLocaleData(lang.code);
      if (data && Object.keys(data).length > 0) {
        setTranslations(data);
        document.documentElement.dir = lang.direction;
        document.documentElement.lang = lang.code;
        setCurrentLang(lang);
      }
    } catch (err) {
      console.error("Translation load error:", err);
      setTranslations({});
    }
  }, []);
  reactExports.useEffect(() => {
    let isMounted = true;
    const init = async () => {
      const matchLang = (code, langs) => {
        const normalizedCode = String(code || "").trim();
        if (!normalizedCode) return null;
        const lower = normalizedCode.toLowerCase();
        const direct = langs.find((l) => String(l.code || "").trim().toLowerCase() === lower);
        if (direct) return direct;
        const base = lower.split(/[-_]/)[0];
        if (base && base !== lower) {
          return langs.find((l) => String(l.code || "").trim().toLowerCase() === base) || null;
        }
        return null;
      };
      const hasUserLocale = (code) => {
        try {
          return !!localStorage.getItem(`pateez_locale_${code}`);
        } catch {
          return false;
        }
      };
      if (initialTranslations && Object.keys(initialTranslations).length > 0) {
        try {
          document.documentElement.dir = initialLang?.direction || DEFAULT_LANG.direction;
          document.documentElement.lang = initialLang?.code || DEFAULT_LANG.code;
        } catch {
        }
        if (isMounted) setLoading(false);
      } else {
        const initialCode = getInitialLangCode();
        const initialLangObj = { ...DEFAULT_LANG, code: initialCode };
        await loadTranslations(initialLangObj);
        if (isMounted) setLoading(false);
      }
      try {
        const { data: dbLangs } = await supabase.from("languages").select("*").eq("status", "active");
        if (isMounted && dbLangs && dbLangs.length > 0) {
          const normalized = dbLangs.map((l) => ({
            ...l,
            direction: String(l?.direction || "").trim() === "rtl" ? "rtl" : "ltr",
            flag_code: String(l?.flag_code || "").trim() || String(l?.code || "").trim()
          }));
          setAvailableLanguages(normalized);
          const defaultFromDb = normalized.find((l) => l.is_default)?.code || normalized[0]?.code || DEFAULT_LANG.code;
          const desiredCode = getInitialLangCode() || initialLang?.code || defaultFromDb;
          const resolvedLang = matchLang(desiredCode, normalized) || matchLang(defaultFromDb, normalized);
          if (resolvedLang) {
            try {
              localStorage.setItem("pateez_lang", resolvedLang.code);
              writeLangCookie(resolvedLang.code);
              document.documentElement.dir = resolvedLang.direction;
              document.documentElement.lang = resolvedLang.code;
            } catch {
            }
            const shouldLoadUserPack = hasUserLocale(resolvedLang.code);
            const shouldSyncLang = resolvedLang.code !== (initialLang?.code || DEFAULT_LANG.code);
            if (shouldLoadUserPack || shouldSyncLang) {
              await loadTranslations(resolvedLang);
            } else {
              setCurrentLang(resolvedLang);
            }
          }
        }
      } catch (e) {
        console.warn("DB Language list fallback used");
      }
    };
    init();
    return () => {
      isMounted = false;
    };
  }, [getInitialLangCode, loadTranslations, initialLang, initialTranslations, writeLangCookie]);
  const setLanguage = async (code) => {
    const lang = availableLanguages.find((l) => l.code === code) || { ...DEFAULT_LANG, code };
    setLoading(true);
    localStorage.setItem("pateez_lang", code);
    writeLangCookie(code);
    try {
      await loadTranslations(lang);
    } finally {
      setLoading(false);
    }
  };
  const t = reactExports.useCallback((key) => {
    if (!translations) return STATIC_TR[key] || key;
    return translations[key] || STATIC_TR[key] || key;
  }, [translations]);
  const contextValue = reactExports.useMemo(() => ({
    currentLang,
    availableLanguages,
    setLanguage,
    t,
    loading: loading && !initialTranslations
  }), [currentLang, availableLanguages, setLanguage, t, loading, initialTranslations]);
  return /* @__PURE__ */ jsxRuntimeExports.jsx(LanguageContext.Provider, { value: contextValue, children });
};
const useLanguage = () => {
  const context = reactExports.useContext(LanguageContext);
  if (context === void 0) {
    throw new Error("useLanguage must be used within a LanguageProvider");
  }
  return context;
};

const Navbar = ({
  onHomeClick,
  onProfileClick,
  onAdminClick,
  onProfileViewClick,
  onEditProfileClick,
  onLogout,
  isLoggedIn,
  navItems = [],
  siteSettings,
  user,
  authLoading
}) => {
  const { currentLang, availableLanguages, setLanguage, t } = useLanguage();
  const [showLangMenu, setShowLangMenu] = reactExports.useState(false);
  const [showUserMenu, setShowUserMenu] = reactExports.useState(false);
  const [isSearchOpen, setIsSearchOpen] = reactExports.useState(false);
  const langMenuRef = reactExports.useRef(null);
  const userMenuRef = reactExports.useRef(null);
  const headerItems = React.useMemo(
    () => navItems.filter((item) => item.type === "header"),
    [navItems]
  );
  const goHome = () => {
    if (onHomeClick) return onHomeClick();
    void navigate();
  };
  const navigateHeaderItem = (item) => {
    const raw = (item.value || item.label || "").trim();
    if (!raw) return;
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      window.location.href = raw;
      return;
    }
    if (raw.startsWith("/")) {
      void navigate();
      return;
    }
    void navigate(`/kategori/${slugify(raw)}`);
  };
  const prefetchHeaderItem = (item) => {
    const raw = (item.value || item.label || "").trim();
    if (!raw) return;
    if (raw.startsWith("http://") || raw.startsWith("https://")) return;
    if (raw.startsWith("/")) {
      prefetch(raw);
      return;
    }
    prefetch(`/kategori/${slugify(raw)}`);
  };
  reactExports.useEffect(() => {
    const handleClickOutside = (event) => {
      if (langMenuRef.current && !langMenuRef.current.contains(event.target)) {
        setShowLangMenu(false);
      }
      if (userMenuRef.current && !userMenuRef.current.contains(event.target)) {
        setShowUserMenu(false);
      }
    };
    if (showLangMenu || showUserMenu) document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [showLangMenu, showUserMenu]);
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("header", { className: "fixed top-0 left-0 w-full z-[250]", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "h-[64px] bg-white/80 backdrop-blur-2xl border-b border-palette-beige/20 shadow-sm relative z-[251]", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "max-w-[1280px] mx-auto h-full flex items-center px-4", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs(
        "div",
        {
          onClick: goHome,
          onMouseEnter: () => prefetch("/"),
          className: "flex items-center gap-3 cursor-pointer group select-none z-20 flex-shrink-0 lg:w-[260px] pl-5",
          children: [
            siteSettings?.logo_url ? /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "h-[42px] transition-opacity duration-200 group-hover:opacity-95", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
              "img",
              {
                src: siteSettings.logo_url,
                alt: siteSettings?.site_name || "Site Logo",
                className: "h-full w-auto object-contain select-none"
              }
            ) }) : /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "w-[42px] h-[42px] bg-palette-red rounded-[5px] flex items-center justify-center shadow-lg shadow-palette-red/10 group-hover:scale-105 transition-all duration-150", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-white", style: { fontSize: "26px", fontVariationSettings: "'FILL' 1, 'wght' 600" }, children: "bolt" }) }),
            !siteSettings?.logo_url && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex flex-col justify-center", children: /* @__PURE__ */ jsxRuntimeExports.jsx("h1", { className: "text-xl font-bold tracking-tight text-gray-900 leading-none font-display", children: siteSettings?.site_name ? /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
              siteSettings.site_name.split(" ")[0].toUpperCase(),
              siteSettings.site_name.split(" ").slice(1).length > 0 && /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-palette-tan font-medium", children: siteSettings.site_name.split(" ").slice(1).join(" ").toUpperCase() })
            ] }) : /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
              "PATEEZ",
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-palette-tan font-medium", children: t("brand.news") })
            ] }) }) })
          ]
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("nav", { className: "hidden lg:flex items-center gap-8 h-full px-10 flex-1", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs(
          "button",
          {
            onClick: goHome,
            onMouseEnter: () => prefetch("/"),
            className: "relative h-full flex items-center gap-2.5 px-1 text-[12px] font-bold tracking-widest transition-all group text-palette-red",
            children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(
                "span",
                {
                  className: "material-symbols-rounded transition-all duration-150 scale-110",
                  style: { fontSize: "22px", fontVariationSettings: "'FILL' 1, 'wght' 500" },
                  children: "home"
                }
              ),
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { children: t("nav.home") })
            ]
          }
        ),
        headerItems.map((item) => /* @__PURE__ */ jsxRuntimeExports.jsxs(
          "button",
          {
            onClick: () => navigateHeaderItem(item),
            onMouseEnter: () => prefetchHeaderItem(item),
            className: "relative h-full flex items-center gap-2.5 px-1 text-[12px] font-bold tracking-widest transition-all group text-palette-tan/60 hover:text-palette-red",
            children: [
              item.icon && /* @__PURE__ */ jsxRuntimeExports.jsx(
                "span",
                {
                  className: "material-symbols-rounded transition-all duration-100 group-hover:-translate-y-0.5 opacity-60 group-hover:opacity-100",
                  style: { fontSize: "22px", fontVariationSettings: "'FILL' 0, 'wght' 400" },
                  children: item.icon.toLowerCase()
                }
              ),
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { children: t(item.label) })
            ]
          },
          item.id
        ))
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-1 ml-auto z-20", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(
          "button",
          {
            onClick: () => setIsSearchOpen(!isSearchOpen),
            className: `w-10 h-10 flex items-center justify-center rounded-[5px] transition-colors duration-100 ${isSearchOpen ? "bg-gray-900 text-white shadow-md" : "text-palette-tan hover:bg-palette-beige/10"}`,
            children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "22px", fontVariationSettings: isSearchOpen ? "'FILL' 1" : "'FILL' 0" }, children: isSearchOpen ? "close" : "search" })
          }
        ),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative", ref: langMenuRef, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("button", { onClick: () => setShowLangMenu(!showLangMenu), className: "h-10 flex items-center gap-0.5 px-2 rounded-[5px] text-palette-tan hover:bg-palette-beige/10 transition-colors font-bold text-[10px] uppercase", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "20px" }, children: "public" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: `material-symbols-rounded transition-transform duration-200 ${showLangMenu ? "rotate-180" : ""}`, style: { fontSize: "16px" }, children: "expand_more" })
          ] }),
          showLangMenu && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "absolute top-full right-0 mt-2 w-40 bg-white rounded-[5px] shadow-2xl border border-palette-beige/10 py-1 overflow-hidden animate-in", children: availableLanguages.map((lang) => /* @__PURE__ */ jsxRuntimeExports.jsxs(
            "button",
            {
              onClick: () => {
                setLanguage(lang.code);
                setShowLangMenu(false);
              },
              className: `w-full flex items-center gap-3 px-4 py-2.5 text-[11px] font-bold transition-all ${currentLang.code === lang.code ? "bg-palette-beige/10 text-palette-red" : "text-palette-tan hover:bg-palette-beige/5"}`,
              children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "uppercase", children: lang.code }),
                /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "opacity-60", children: lang.name })
              ]
            },
            lang.code
          )) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative", ref: userMenuRef, children: [
          authLoading ? (
            /* AUTH LOADING (STABILIZED) - No pulse, no jump */
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex items-center justify-center w-10 h-10", children: /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "w-7 h-7 rounded-[5px] bg-palette-beige/20 border border-palette-beige/10" }) })
          ) : /* @__PURE__ */ jsxRuntimeExports.jsx(
            "button",
            {
              onClick: () => {
                if (isLoggedIn) {
                  setShowUserMenu(!showUserMenu);
                } else {
                  onProfileClick?.();
                }
              },
              className: `flex items-center justify-center w-10 h-10 rounded-[5px] transition-all duration-200 group/profile active:scale-95 ${isLoggedIn ? "bg-palette-beige/5 border border-palette-beige/20 hover:border-palette-tan/30" : "hover:bg-palette-beige/10"}`,
              children: /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: `flex items-center justify-center transition-all duration-150 ${isLoggedIn ? "w-7 h-7 rounded-[5px] border border-palette-tan/20 overflow-hidden shadow-sm" : "w-7 h-7"}`, children: isLoggedIn ? (() => {
                const profileAvatar = user?.profile?.avatar_url;
                const metadataAvatar = user?.user_metadata?.avatar_url;
                const rawUrl = profileAvatar || metadataAvatar;
                if (!rawUrl) return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "w-full h-full flex items-center justify-center bg-palette-beige text-palette-tan/20", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "18px" }, children: "person" }) });
                const url = String(rawUrl).trim();
                let finalUrl = url;
                if (!url.startsWith("http") && !url.startsWith("data:") && !url.startsWith("/")) {
                  finalUrl = url;
                }
                return /* @__PURE__ */ jsxRuntimeExports.jsx(
                  "img",
                  {
                    src: finalUrl,
                    className: "w-full h-full object-cover",
                    alt: t("navbar.profile_alt"),
                    onError: (e) => {
                      e.target.style.display = "none";
                      e.target.parentElement.classList.add("bg-palette-beige");
                      const parent = e.target.parentElement;
                      if (parent) {
                        const icon = document.createElement("span");
                        icon.className = "material-symbols-rounded text-palette-tan/20";
                        icon.style.fontSize = "18px";
                        icon.innerText = "person";
                        parent.appendChild(icon);
                      }
                    }
                  }
                );
              })() : /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-palette-red", style: { fontSize: "24px", fontVariationSettings: "'FILL' 0, 'wght' 500" }, children: "person" }) })
            }
          ),
          isLoggedIn && showUserMenu && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "absolute top-full right-0 mt-2 w-56 bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_20px_50px_rgba(0,0,0,0.15)] border border-palette-beige/20 py-2.5 z-[300] animate-in fade-in slide-in-from-top-1 duration-75", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "px-4 py-2 mb-2 border-b border-palette-beige/10", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] font-black text-gray-900 truncate", children: user?.user_metadata?.full_name || user?.email?.split("@")[0] }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[9px] font-bold text-palette-tan/60 truncate uppercase tracking-tighter", children: user?.email })
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "px-1.5 space-y-0.5", children: [
              onAdminClick && /* @__PURE__ */ jsxRuntimeExports.jsxs(
                "button",
                {
                  onClick: () => {
                    onAdminClick();
                    setShowUserMenu(false);
                  },
                  className: "w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group",
                  children: [
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100", style: { fontVariationSettings: "'FILL' 0" }, children: "dashboard" }),
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[12px] font-bold tracking-tight", children: t("nav.panel") })
                  ]
                }
              ),
              onProfileViewClick && /* @__PURE__ */ jsxRuntimeExports.jsxs(
                "button",
                {
                  onClick: () => {
                    onProfileViewClick();
                    setShowUserMenu(false);
                  },
                  className: "w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group",
                  children: [
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100", style: { fontVariationSettings: "'FILL' 0" }, children: "person" }),
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[12px] font-bold tracking-tight", children: t("navbar.my_profile") })
                  ]
                }
              ),
              onEditProfileClick && /* @__PURE__ */ jsxRuntimeExports.jsxs(
                "button",
                {
                  onClick: () => {
                    onEditProfileClick();
                    setShowUserMenu(false);
                  },
                  className: "w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group",
                  children: [
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100", style: { fontVariationSettings: "'FILL' 0" }, children: "edit" }),
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[12px] font-bold tracking-tight", children: t("navbar.edit_profile") })
                  ]
                }
              ),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "h-px bg-palette-beige/10 my-1.5 mx-2" }),
              onLogout && /* @__PURE__ */ jsxRuntimeExports.jsxs(
                "button",
                {
                  onClick: () => {
                    onLogout();
                    setShowUserMenu(false);
                  },
                  className: "w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-palette-red hover:bg-palette-red/5 transition-all group",
                  children: [
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100", style: { fontVariationSettings: "'FILL' 0" }, children: "logout" }),
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-[12px] font-[900] tracking-tight truncate", children: t("common.logout") })
                  ]
                }
              )
            ] })
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("button", { className: "lg:hidden w-10 h-10 flex items-center justify-center rounded-[5px] bg-palette-beige/10 text-gray-900 ml-1", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "22px" }, children: "menu" }) })
      ] })
    ] }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsx(
      "div",
      {
        className: `absolute top-[64px] left-0 w-full bg-white border-b border-palette-beige shadow-2xl transition-all duration-75 ease-linear overflow-hidden z-[250] ${isSearchOpen ? "max-h-[80px] opacity-100 py-3.5" : "max-h-0 opacity-0 py-0"}`,
        children: /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "max-w-[1280px] mx-auto px-4", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative flex items-center", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "absolute left-4 flex items-center justify-center z-10", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-palette-tan/30", style: { fontSize: "22px" }, children: "search" }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(
            "input",
            {
              type: "text",
              autoFocus: isSearchOpen,
              placeholder: t("nav.search"),
              className: "w-full h-11 bg-palette-beige/10 rounded-[5px] border border-palette-beige focus:border-palette-tan/30 text-sm font-bold text-gray-900 placeholder:text-palette-tan/20 outline-none pl-11 pr-11 transition-none"
            }
          ),
          /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "absolute right-3.5 flex items-center gap-2 z-10", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
            "button",
            {
              onClick: () => setIsSearchOpen(false),
              className: "p-1 text-palette-tan/30 hover:text-palette-red",
              children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "18px" }, children: "close" })
            }
          ) })
        ] }) })
      }
    ),
    isSearchOpen && /* @__PURE__ */ jsxRuntimeExports.jsx(
      "div",
      {
        onClick: () => setIsSearchOpen(false),
        className: "fixed inset-0 bg-gray-900/5 backdrop-blur-[1px] z-[249]"
      }
    )
  ] });
};

const Login = ({ onSuccess, onClose }) => {
  const { t } = useLanguage();
  const [isSignUp, setIsSignUp] = reactExports.useState(false);
  const [email, setEmail] = reactExports.useState("demo.user@gmail.com");
  const [password, setPassword] = reactExports.useState("123456");
  const [loading, setLoading] = reactExports.useState(false);
  const [error, setError] = reactExports.useState(null);
  const [showPassword, setShowPassword] = reactExports.useState(false);
  const handleKeyDown = reactExports.useCallback((e) => {
    if (e.key === "Escape" && onClose) {
      onClose();
    }
  }, [onClose]);
  reactExports.useEffect(() => {
    window.addEventListener("keydown", handleKeyDown);
    const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth;
    const navbar = document.querySelector("header");
    document.body.style.overflow = "hidden";
    if (scrollbarWidth > 0) {
      document.body.style.paddingRight = `${scrollbarWidth}px`;
      if (navbar) {
        navbar.style.paddingRight = `${scrollbarWidth}px`;
      }
    }
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = "";
      document.body.style.paddingRight = "";
      if (navbar) {
        navbar.style.paddingRight = "";
      }
    };
  }, [handleKeyDown]);
  const handleAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      if (isSignUp) {
        const { data, error: error2 } = await supabase.auth.signUp({ email, password });
        if (error2) throw error2;
        if (data.user) onSuccess();
      } else {
        const { data, error: error2 } = await supabase.auth.signInWithPassword({ email, password });
        if (error2) throw error2;
        if (data.user) onSuccess();
      }
    } catch (err) {
      setError(err.message === "Invalid login credentials" ? t("auth.invalid_credentials") : err.message);
    } finally {
      setLoading(false);
    }
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "fixed inset-0 z-[9999] flex items-center justify-center p-4", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx(
      "div",
      {
        className: "absolute inset-0 bg-palette-tan/95 backdrop-blur-[2px] animate-backdrop-entry cursor-pointer",
        onClick: onClose
      }
    ),
    /* @__PURE__ */ jsxRuntimeExports.jsxs(
      "div",
      {
        className: "relative w-full max-w-[380px] bg-white rounded-[3px] shadow-2xl overflow-hidden animate-modal-entry flex flex-col transform-gpu ring-1 ring-white/10",
        style: { willChange: "transform, opacity" },
        children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(
            "button",
            {
              onClick: onClose,
              className: "absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-[3px] text-gray-400 hover:bg-gray-100 hover:text-gray-900 transition-all z-20",
              children: /* @__PURE__ */ jsxRuntimeExports.jsx(X, { size: 18 })
            }
          ),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "p-8 pb-10", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex flex-col items-center mb-8", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "w-14 h-14 bg-palette-red rounded-[3px] flex items-center justify-center shadow-xl shadow-palette-red/20 mb-4 transform -rotate-3", children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded text-white text-[32px]", style: { fontVariationSettings: "'FILL' 1" }, children: "bolt" }) }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("h2", { className: "text-2xl font-[900] text-gray-900 tracking-tighter font-display uppercase", children: [
                "Pateez",
                /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-palette-tan font-medium", children: t("common.panel") })
              ] }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[11px] font-bold text-gray-400 uppercase tracking-widest mt-1", children: isSignUp ? t("auth.create_account") : t("auth.secure_login") })
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex p-1.5 bg-gray-50 border border-gray-100 rounded-[3px] mb-8", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(
                "button",
                {
                  onClick: () => setIsSignUp(false),
                  className: `flex-1 py-2.5 text-[10px] font-black uppercase tracking-wider rounded-[3px] transition-all duration-200 ${!isSignUp ? "bg-white text-gray-900 shadow-[0_2px_10px_rgba(0,0,0,0.05)]" : "text-gray-400 hover:text-gray-600"}`,
                  children: t("nav.login")
                }
              ),
              /* @__PURE__ */ jsxRuntimeExports.jsx(
                "button",
                {
                  onClick: () => setIsSignUp(true),
                  className: `flex-1 py-2.5 text-[10px] font-black uppercase tracking-wider rounded-[3px] transition-all duration-200 ${isSignUp ? "bg-white text-palette-red shadow-[0_2px_10px_rgba(0,0,0,0.05)]" : "text-gray-400 hover:text-gray-600"}`,
                  children: t("auth.sign_up")
                }
              )
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("form", { onSubmit: handleAuth, className: "space-y-4", children: [
              error && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "p-3 bg-red-50 border border-red-100 text-red-600 text-[10px] font-bold flex items-center gap-2 rounded-[3px] animate-in slide-in-from-top-1 fade-in duration-200", children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx(AlertCircle, { size: 14 }),
                error
              ] }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "space-y-1.5", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative group", children: [
                /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-gray-900 transition-colors", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Mail, { size: 18 }) }),
                /* @__PURE__ */ jsxRuntimeExports.jsx(
                  "input",
                  {
                    type: "email",
                    value: email,
                    onChange: (e) => setEmail(e.target.value),
                    className: "w-full h-12 pl-11 pr-4 bg-gray-50 border-2 border-transparent rounded-[3px] text-sm font-bold text-gray-900 focus:bg-white focus:border-palette-tan/20 outline-none transition-all placeholder:text-gray-400",
                    placeholder: t("auth.email_placeholder"),
                    required: true
                  }
                )
              ] }) }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-1.5", children: [
                /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "relative group", children: [
                  /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-gray-900 transition-colors", children: /* @__PURE__ */ jsxRuntimeExports.jsx(Lock, { size: 18 }) }),
                  /* @__PURE__ */ jsxRuntimeExports.jsx(
                    "input",
                    {
                      type: showPassword ? "text" : "password",
                      value: password,
                      onChange: (e) => setPassword(e.target.value),
                      className: "w-full h-12 pl-11 pr-11 bg-gray-50 border-2 border-transparent rounded-[3px] text-sm font-bold text-gray-900 focus:bg-white focus:border-palette-tan/20 outline-none transition-all placeholder:text-gray-400",
                      placeholder: t("users.password"),
                      required: true,
                      minLength: 6
                    }
                  ),
                  /* @__PURE__ */ jsxRuntimeExports.jsx(
                    "button",
                    {
                      type: "button",
                      onClick: () => setShowPassword(!showPassword),
                      className: "absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600",
                      children: showPassword ? /* @__PURE__ */ jsxRuntimeExports.jsx(EyeOff, { size: 18 }) : /* @__PURE__ */ jsxRuntimeExports.jsx(Eye, { size: 18 })
                    }
                  )
                ] }),
                !isSignUp && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "flex justify-end", children: /* @__PURE__ */ jsxRuntimeExports.jsx("button", { type: "button", className: "text-[10px] font-bold text-gray-400 hover:text-palette-red transition-colors", children: t("auth.forgot_password") }) })
              ] }),
              /* @__PURE__ */ jsxRuntimeExports.jsx(
                "button",
                {
                  type: "submit",
                  disabled: loading,
                  className: "w-full h-14 mt-4 bg-gray-900 text-white rounded-[3px] font-black text-xs uppercase tracking-[0.15em] hover:bg-black active:scale-[0.98] transition-all flex items-center justify-center gap-3 shadow-lg shadow-gray-900/20",
                  children: loading ? /* @__PURE__ */ jsxRuntimeExports.jsx(Loader2, { size: 20, className: "animate-spin" }) : /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
                    /* @__PURE__ */ jsxRuntimeExports.jsx("span", { children: isSignUp ? t("auth.create_account") : t("nav.login") }),
                    !loading && /* @__PURE__ */ jsxRuntimeExports.jsx(ArrowRight, { size: 16, strokeWidth: 3 })
                  ] })
                }
              )
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-8 text-center", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("p", { className: "text-[10px] text-gray-400 font-medium leading-relaxed px-4", children: [
              t("auth.terms_prefix"),
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "text-gray-900 font-bold cursor-pointer hover:underline", children: t("auth.terms_link") }),
              t("auth.terms_suffix")
            ] }) })
          ] })
        ]
      }
    )
  ] });
};

function useSupabaseSession() {
  const [session, setSession] = reactExports.useState(null);
  const [profile, setProfile] = reactExports.useState(null);
  const [loading, setLoading] = reactExports.useState(true);
  reactExports.useEffect(() => {
    let isMounted = true;
    const hasAuthToken = () => {
      try {
        return Object.keys(localStorage).some(
          (key) => key.startsWith("sb-") && key.endsWith("-auth-token")
        );
      } catch {
        return false;
      }
    };
    const hydrateProfileCache = () => {
      try {
        const cached = localStorage.getItem("pateez_profile_cache");
        if (!cached) return null;
        return JSON.parse(cached);
      } catch {
        return null;
      }
    };
    async function fetchProfile(userId) {
      const { data, error } = await supabase.from("profiles").select("*").eq("id", userId).single();
      if (isMounted && data && !error) {
        setProfile(data);
        try {
          localStorage.setItem("pateez_profile_cache", JSON.stringify(data));
        } catch {
        }
      }
    }
    const tokenExists = hasAuthToken();
    const cachedProfile = tokenExists ? hydrateProfileCache() : null;
    if (cachedProfile && isMounted) {
      setProfile(cachedProfile);
    }
    if (!tokenExists) {
      setLoading(false);
    }
    supabase.auth.getSession().then(({ data: { session: currentSession } }) => {
      if (!isMounted) return;
      if (currentSession) {
        setSession(currentSession);
        fetchProfile(currentSession.user.id);
      } else {
        setSession(null);
        setProfile(null);
        try {
          localStorage.removeItem("pateez_profile_cache");
        } catch {
        }
      }
      setLoading(false);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (isMounted) {
        setSession(nextSession);
        if (nextSession) {
          fetchProfile(nextSession.user.id);
        } else {
          setProfile(null);
          try {
            localStorage.removeItem("pateez_profile_cache");
          } catch {
          }
        }
        setLoading(false);
      }
    });
    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, []);
  return { session, user: session?.user ?? null, profile, loading };
}

const Toast = ({ message, type = "success", onClose }) => {
  const { t } = useLanguage();
  const [isVisible, setIsVisible] = reactExports.useState(false);
  reactExports.useEffect(() => {
    setIsVisible(true);
    const timer = setTimeout(() => {
      setIsVisible(false);
      setTimeout(onClose, 500);
    }, 3500);
    return () => clearTimeout(timer);
  }, [onClose]);
  const getIcon = () => {
    switch (type) {
      case "success":
        return "check_circle";
      case "error":
        return "error";
      case "warning":
        return "warning";
      default:
        return "info";
    }
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: `fixed bottom-12 left-1/2 -translate-x-1/2 z-[999999] transition-all duration-700 ease-[cubic-bezier(0.23,1,0.32,1)] ${isVisible ? "opacity-100 translate-y-0 scale-100" : "opacity-0 translate-y-8 scale-90"}`, children: /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: `flex items-center gap-5 px-8 py-5 rounded-[5px] border border-palette-tan/20 bg-white/90 backdrop-blur-xl shadow-[0_20px_50px_rgba(24,37,64,0.15)] min-w-[360px] max-w-md overflow-hidden relative group`, children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: `absolute left-0 top-0 bottom-0 w-1.5 ${type === "success" ? "bg-emerald-500" : type === "error" ? "bg-palette-red" : type === "warning" ? "bg-amber-500" : "bg-blue-500"}` }),
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: `w-12 h-12 rounded-[5px] flex items-center justify-center bg-palette-beige/20 shadow-inner ${type === "success" ? "text-emerald-500" : type === "error" ? "text-palette-red" : type === "warning" ? "text-amber-500" : "text-blue-500"}`, children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "28px", fontVariationSettings: "'FILL' 1" }, children: getIcon() }) }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex-1 space-y-0.5", children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[10px] font-black uppercase tracking-[0.2em] opacity-40 leading-none", children: t(`toast.${type}`) }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-[15px] font-bold text-palette-maroon tracking-tight leading-snug", children: message })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsx(
      "button",
      {
        onClick: () => {
          setIsVisible(false);
          setTimeout(onClose, 500);
        },
        className: "w-10 h-10 flex items-center justify-center rounded-[5px] hover:bg-palette-red/5 text-palette-tan/40 hover:text-palette-red transition-all active:scale-90",
        children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "material-symbols-rounded", style: { fontSize: "22px" }, children: "close" })
      }
    ),
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "absolute bottom-0 left-0 h-[3px] w-full bg-palette-beige/10", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
      "div",
      {
        className: `h-full transition-all duration-[3000ms] ease-linear rounded-r-full ${type === "success" ? "bg-emerald-500" : type === "error" ? "bg-palette-red" : type === "warning" ? "bg-amber-500" : "bg-blue-500"}`,
        style: { width: isVisible ? "100%" : "0%" }
      }
    ) })
  ] }) });
};

const ToastContext = reactExports.createContext(void 0);
const ToastProvider = ({ children }) => {
  const [toast, setToast] = reactExports.useState(null);
  const showToast = reactExports.useCallback((message, type = "success") => {
    setToast({ message, type });
    setTimeout(() => {
      setToast(null);
    }, 3e3);
  }, []);
  const hideToast = reactExports.useCallback(() => {
    setToast(null);
  }, []);
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(ToastContext.Provider, { value: { showToast }, children: [
    children,
    toast && /* @__PURE__ */ jsxRuntimeExports.jsx(
      Toast,
      {
        message: toast.message,
        type: toast.type,
        onClose: hideToast
      }
    )
  ] });
};
const useToast = () => {
  const context = reactExports.useContext(ToastContext);
  if (!context) {
    throw new Error("useToast must be used within a ToastProvider");
  }
  return context;
};

const GlobalNavigation = ({
  initialLang,
  initialTranslations,
  siteSettings,
  navigationItems
}) => {
  const { user, profile, loading } = useSupabaseSession();
  const [isLoginOpen, setIsLoginOpen] = reactExports.useState(false);
  const handleHomeClick = () => {
    void navigate();
  };
  const handleAdminClick = () => {
    void navigate();
  };
  const handleLogout = async () => {
    document.cookie = "pateez_active_cat=; path=/; expires=Thu, 01 Jan 1970 00:00:00 UTC";
    await supabase.auth.signOut();
    await navigate();
  };
  return /* @__PURE__ */ jsxRuntimeExports.jsx(LanguageProvider, { initialLang, initialTranslations, children: /* @__PURE__ */ jsxRuntimeExports.jsxs(ToastProvider, { children: [
    /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "fixed top-0 left-0 w-full z-[999]", children: /* @__PURE__ */ jsxRuntimeExports.jsx(
      Navbar,
      {
        siteSettings,
        navItems: navigationItems,
        onHomeClick: handleHomeClick,
        onProfileClick: () => setIsLoginOpen(true),
        onAdminClick: handleAdminClick,
        onProfileViewClick: () => {
          void navigate();
        },
        onEditProfileClick: () => {
          void navigate();
        },
        onLogout: handleLogout,
        isLoggedIn: !!user || !!profile,
        user: profile ? user ? { ...user, profile } : { profile } : user,
        authLoading: loading && !profile
      }
    ) }),
    isLoginOpen && /* @__PURE__ */ jsxRuntimeExports.jsx(
      Login,
      {
        onSuccess: () => setIsLoginOpen(false),
        onClose: () => setIsLoginOpen(false)
      }
    )
  ] }) });
};

var __freeze = Object.freeze;
var __defProp = Object.defineProperty;
var __template = (cooked, raw) => __freeze(__defProp(cooked, "raw", { value: __freeze(raw || cooked.slice()) }));
var _a, _b, _c, _d, _e;
const $$Astro = createAstro();
const $$Layout = createComponent(async ($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$Layout;
  const {
    title = "",
    description = "",
    keywords = "",
    ogType = "",
    ogImage = "",
    canonical = "",
    jsonLd,
    lang = "tr",
    dir = "ltr",
    favicon = "",
    siteSettings,
    navigationItems = [],
    initialTranslations = {},
    initialLang = { code: "tr", name: "Türkçe", direction: "ltr", status: "active", flag_code: "tr", is_default: true }
  } = Astro2.props;
  const defaultFavicon = "data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>📰</text></svg>";
  const pathname = Astro2.url.pathname;
  const normalizedPathname = pathname.replace(/\/$/, "");
  const isAdminRoute = normalizedPathname.startsWith("/admin");
  const isPrivateRoute = normalizedPathname === "/profil" || normalizedPathname === "/profil-duzenle";
  const shouldNoIndex = isAdminRoute || isPrivateRoute;
  const normalizeBase = (value) => String(value || "").trim().replace(/\/$/, "");
  const canonicalBase = normalizeBase(siteSettings?.canonical_url || "");
  const baseForUrls = canonicalBase || Astro2.url.origin;
  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || "tr";
  const alternateBases = seoAlternates.map((entry) => normalizeBase(entry.canonicalUrl) || baseForUrls);
  const shouldUseLangParam = new Set(alternateBases).size <= 1;
  const resolvedCanonicalUrl = (() => {
    const initial = canonical || new URL(pathname, baseForUrls).toString();
    const url = new URL(initial);
    if (shouldUseLangParam && lang && lang !== defaultLangCode) {
      url.searchParams.set("lang", lang);
    } else {
      url.searchParams.delete("lang");
    }
    return url.toString();
  })();
  const hreflangLinks = seoAlternates.map((entry) => {
    const base = normalizeBase(entry.canonicalUrl) || baseForUrls;
    const url = new URL(pathname, base);
    if (shouldUseLangParam && entry.code && entry.code !== defaultLangCode) {
      url.searchParams.set("lang", entry.code);
    } else {
      url.searchParams.delete("lang");
    }
    return { code: entry.code, href: url.toString(), isDefault: entry.isDefault };
  }).filter((entry) => !!entry.code);
  const xDefaultHref = hreflangLinks.find((entry) => entry.isDefault)?.href || new URL(pathname, baseForUrls).toString();
  const resolvedTitle = title || siteSettings?.site_name || "Pateez News";
  const resolvedDescription = description || siteSettings?.meta_description || "";
  const resolvedKeywords = keywords || siteSettings?.meta_keywords || "";
  const resolvedOgType = ogType || "website";
  const toAbsoluteUrl = (value) => {
    const raw = String(value || "").trim();
    if (!raw) return "";
    if (raw.startsWith("http://") || raw.startsWith("https://") || raw.startsWith("data:")) return raw;
    try {
      return new URL(raw, canonicalBase || Astro2.url).toString();
    } catch {
      return raw;
    }
  };
  const resolvedOgImage = toAbsoluteUrl(ogImage || siteSettings?.og_image_url);
  const resolvedFavicon = favicon || siteSettings?.favicon_url || defaultFavicon;
  const themeColor = "#fcfcfb";
  const twitterHandleRaw = String(siteSettings?.twitter_username || "").trim();
  const twitterSite = twitterHandleRaw ? twitterHandleRaw.startsWith("@") ? twitterHandleRaw : `@${twitterHandleRaw}` : "";
  const ogLocale = (() => {
    switch (lang) {
      case "tr":
        return "tr_TR";
      case "en":
        return "en_US";
      case "ar":
        return "ar_AR";
      default:
        return lang;
    }
  })();
  const safeJsonLd = (value) => JSON.stringify(value).replace(/</g, "\\u003c");
  const orgName = (siteSettings?.organization_legal_name || siteSettings?.site_name || "").trim();
  const orgUrl = baseForUrls;
  const orgLogo = toAbsoluteUrl(siteSettings?.logo_url || siteSettings?.favicon_url);
  const organizationLd = orgName ? {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: orgName,
    url: orgUrl,
    ...orgLogo ? { logo: orgLogo } : {},
    ...siteSettings?.organization_phone ? { telephone: siteSettings.organization_phone } : {},
    ...siteSettings?.organization_address ? {
      address: {
        "@type": "PostalAddress",
        streetAddress: siteSettings.organization_address
      }
    } : {}
  } : null;
  const websiteLd = siteSettings?.site_name || orgName ? {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: siteSettings?.site_name || orgName,
    url: orgUrl,
    inLanguage: lang
  } : null;
  const googleVerificationRaw = String(siteSettings?.google_search_console_code || "").trim();
  const bingVerificationRaw = String(siteSettings?.bing_verification_code || "").trim();
  const headerCustomCodes = String(siteSettings?.header_custom_codes || "").trim();
  const footerCustomCodes = String(siteSettings?.footer_custom_codes || "").trim();
  const preconnectOrigins = (() => {
    const origins = /* @__PURE__ */ new Set();
    const addOrigin = (value) => {
      const raw = String(value || "").trim();
      if (!raw || raw.startsWith("data:")) return;
      try {
        const url = new URL(raw, canonicalBase || Astro2.url);
        if (url.origin) origins.add(url.origin);
      } catch {
      }
    };
    addOrigin("https://glrvuonvwmiclusrrjtj.supabase.co");
    addOrigin(resolvedOgImage);
    addOrigin(resolvedFavicon);
    addOrigin(orgLogo);
    addOrigin(siteSettings?.logo_url);
    addOrigin(siteSettings?.footer_logo_url);
    addOrigin(siteSettings?.dark_logo_url);
    addOrigin(siteSettings?.email_logo_url);
    if (siteSettings?.google_analytics_id) origins.add("https://www.googletagmanager.com");
    return Array.from(origins).filter((origin) => origin && origin !== Astro2.url.origin);
  })();
  const buildLangAwareAssetHref = (pathname2) => {
    const url = new URL(pathname2, Astro2.url.origin);
    if (shouldUseLangParam && lang && lang !== defaultLangCode) {
      url.searchParams.set("lang", lang);
    } else {
      url.searchParams.delete("lang");
    }
    return `${url.pathname}${url.search}`;
  };
  const manifestHref = buildLangAwareAssetHref("/manifest.webmanifest");
  const rssHref = buildLangAwareAssetHref("/rss.xml");
  const rssTitle = `${siteSettings?.site_name || "Pateez News"} RSS`;
  return renderTemplate`<html${addAttribute(lang, "lang")}${addAttribute(dir, "dir")} class="scroll-smooth"> <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"><meta name="theme-color"${addAttribute(themeColor, "content")}><link rel="icon"${addAttribute(resolvedFavicon, "href")}><link rel="apple-touch-icon"${addAttribute(orgLogo || resolvedFavicon, "href")}><link rel="manifest"${addAttribute(manifestHref, "href")}><meta name="generator"${addAttribute(Astro2.generator, "content")}>${renderComponent($$result, "ViewTransitions", $$ClientRouter, {})}${preconnectOrigins.map((origin) => renderTemplate`${renderComponent($$result, "Fragment", Fragment, {}, { "default": async ($$result2) => renderTemplate`<link rel="preconnect"${addAttribute(origin, "href")} crossorigin><link rel="dns-prefetch"${addAttribute(origin, "href")}>` })}`)}<title>${resolvedTitle}</title><meta name="description"${addAttribute(resolvedDescription, "content")}><meta name="keywords"${addAttribute(resolvedKeywords, "content")}><meta name="robots"${addAttribute(
    shouldNoIndex ? "noindex,nofollow" : "index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1",
    "content"
  )}><meta property="og:site_name"${addAttribute(siteSettings?.site_name || resolvedTitle, "content")}><meta property="og:locale"${addAttribute(ogLocale, "content")}>${siteSettings?.fb_app_id && renderTemplate`<meta property="fb:app_id"${addAttribute(siteSettings.fb_app_id, "content")}>`}${twitterSite && renderTemplate`<meta name="twitter:site"${addAttribute(twitterSite, "content")}>`}${hreflangLinks.map((entry) => renderTemplate`<link rel="alternate"${addAttribute(entry.code, "hreflang")}${addAttribute(entry.href, "href")}>`)}${!shouldNoIndex && renderTemplate`<link rel="alternate" hreflang="x-default"${addAttribute(xDefaultHref, "href")}>`}<link rel="preload" href="/fonts/inter-latin.woff2" as="font" type="font/woff2" crossorigin>${isAdminRoute && renderTemplate`<link rel="preload" href="/fonts/roboto-latin.woff2" as="font" type="font/woff2" crossorigin>`}<link rel="preload" href="/fonts/material-symbols-rounded.woff2" as="font" type="font/woff2" crossorigin><!-- Open Graph / Facebook --><meta property="og:type"${addAttribute(resolvedOgType, "content")}><meta property="og:url"${addAttribute(resolvedCanonicalUrl, "content")}><meta property="og:title"${addAttribute(resolvedTitle, "content")}><meta property="og:description"${addAttribute(resolvedDescription, "content")}><meta property="og:image"${addAttribute(resolvedOgImage, "content")}><!-- Twitter --><meta property="twitter:card" content="summary_large_image"><meta property="twitter:url"${addAttribute(resolvedCanonicalUrl, "content")}><meta property="twitter:title"${addAttribute(resolvedTitle, "content")}><meta property="twitter:description"${addAttribute(resolvedDescription, "content")}><meta property="twitter:image"${addAttribute(resolvedOgImage, "content")}><link rel="canonical"${addAttribute(resolvedCanonicalUrl, "href")}><link rel="alternate" type="application/rss+xml"${addAttribute(rssTitle, "title")}${addAttribute(rssHref, "href")}>${googleVerificationRaw && (googleVerificationRaw.includes("<") ? renderTemplate`${renderComponent($$result, "Fragment", Fragment, {}, { "default": async ($$result2) => renderTemplate`${unescapeHTML(googleVerificationRaw)}` })}` : renderTemplate`<meta name="google-site-verification"${addAttribute(googleVerificationRaw, "content")}>`)}${bingVerificationRaw && (bingVerificationRaw.includes("<") ? renderTemplate`${renderComponent($$result, "Fragment", Fragment, {}, { "default": async ($$result2) => renderTemplate`${unescapeHTML(bingVerificationRaw)}` })}` : renderTemplate`<meta name="msvalidate.01"${addAttribute(bingVerificationRaw, "content")}>`)}${siteSettings?.google_analytics_id && renderTemplate`${renderComponent($$result, "Fragment", Fragment, {}, { "default": async ($$result2) => renderTemplate(_a || (_a = __template(["<script async", "></script><script>{`\n					window.dataLayer = window.dataLayer || [];\n					function gtag(){dataLayer.push(arguments);}\n					gtag('js', new Date());\n					gtag('config', '${siteSettings.google_analytics_id}');\n				`}</script>"], ["<script async", "></script><script>{\\`\n					window.dataLayer = window.dataLayer || [];\n					function gtag(){dataLayer.push(arguments);}\n					gtag('js', new Date());\n					gtag('config', '\\${siteSettings.google_analytics_id}');\n				\\`}</script>"])), addAttribute(`https://www.googletagmanager.com/gtag/js?id=${siteSettings.google_analytics_id}`, "src")) })}`}${headerCustomCodes && renderTemplate`${renderComponent($$result, "Fragment", Fragment, {}, { "default": async ($$result2) => renderTemplate`${unescapeHTML(headerCustomCodes)}` })}`}${organizationLd && renderTemplate(_b || (_b = __template(['<script type="application/ld+json">', "</script>"])), unescapeHTML(safeJsonLd(organizationLd)))}${websiteLd && renderTemplate(_c || (_c = __template(['<script type="application/ld+json">', "</script>"])), unescapeHTML(safeJsonLd(websiteLd)))}${jsonLd && (Array.isArray(jsonLd) ? jsonLd.map((entry) => renderTemplate(_d || (_d = __template(['<script type="application/ld+json">', "</script>"])), unescapeHTML(safeJsonLd(entry)))) : renderTemplate(_e || (_e = __template(['<script type="application/ld+json">', "</script>"])), unescapeHTML(safeJsonLd(jsonLd))))}${renderHead()}</head> <body> <!-- 🚀 PERSISTENT NAVIGATION (ZERO RELOAD) --> ${!isAdminRoute && renderTemplate`<div data-astro-transition-persist="global-nav" class="relative z-[999]"> ${renderComponent($$result, "GlobalNavigation", GlobalNavigation, { "client:load": true, "initialLang": initialLang, "initialTranslations": initialTranslations, "siteSettings": siteSettings, "navigationItems": navigationItems, "client:component-hydration": "load", "client:component-path": "@/components/GlobalNavigation", "client:component-export": "default" })} </div>`} ${renderSlot($$result, $$slots["default"])} ${footerCustomCodes && renderTemplate`${renderComponent($$result, "Fragment", Fragment, {}, { "default": async ($$result2) => renderTemplate`${unescapeHTML(footerCustomCodes)}` })}`} </body></html>`;
}, "/Users/pateez/Desktop/pateeznews/src/layouts/Layout.astro", "self");

export { $$Layout as $, LanguageProvider as L, ToastProvider as T, useToast as a, jsxRuntimeExports as j, loadLocaleData as l, navigate as n, prefetch as p, useLanguage as u };
