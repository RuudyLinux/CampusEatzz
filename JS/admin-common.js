(function(global) {
    const BRAND_CACHE_KEY = "appSettingsCache";
    const BRAND_SHARED_CACHE_KEY = "appSettingsSharedCache";
    const BRAND_VERSION_KEY = "appSettingsVersion";
    const BRAND_CACHE_TTL_MS = 5 * 60 * 1000;
    const BRAND_NAME_FALLBACK = "CampusEatzz";
    const BRAND_FETCH_TIMEOUT_MS = 3000;

    function appendLocalBackendCandidates(candidates) {
        const protocol = String(global.location && global.location.protocol || "http:").toLowerCase();
        const hostname = String(global.location && global.location.hostname || "").toLowerCase();
        if (!hostname) {
            return;
        }

        const formattedHost = hostname.indexOf(":") >= 0 && hostname.indexOf("[") !== 0
            ? "[" + hostname + "]"
            : hostname;

        ["5000", "5266", "5299"].forEach(function(port) {
            candidates.push(protocol + "//" + formattedHost + ":" + port);
        });

        const localHosts = ["localhost", "127.0.0.1", "::1"];
        if (localHosts.indexOf(hostname) === -1) {
            return;
        }

        ["5000", "5266", "5299"].forEach(function(port) {
            if (hostname === "127.0.0.1") {
                candidates.push(protocol + "//localhost:" + port);
            }

            if (hostname === "localhost") {
                candidates.push(protocol + "//127.0.0.1:" + port);
            }
        });
    }

    function shouldDeferLocalUiOrigin(base) {
        const raw = String(base || "").trim();
        if (!raw) {
            return false;
        }

        try {
            const baseUrl = new URL(raw, global.location.origin);
            const uiUrl = new URL(global.location.origin);
            const localHosts = ["localhost", "127.0.0.1", "::1"];
            if (localHosts.indexOf(baseUrl.hostname.toLowerCase()) === -1) {
                return false;
            }

            return baseUrl.origin === uiUrl.origin;
        } catch {
            return false;
        }
    }

    function getApiCandidates() {
        const candidates = [];

        const protocol = String(global.location && global.location.protocol || "http:").toLowerCase();
        const hostname = String(global.location && global.location.hostname || "").trim();
        if (hostname) {
            const formattedHost = hostname.indexOf(":") >= 0 && hostname.indexOf("[") !== 0
                ? "[" + hostname + "]"
                : hostname;
            candidates.push(protocol + "//" + formattedHost + ":5000");
        }

        const directBase = String(global.__API_BASE || localStorage.getItem("apiBaseUrl") || "").trim();
        const deferredUiBase = shouldDeferLocalUiOrigin(directBase) ? directBase : "";
        if (directBase && !deferredUiBase) {
            candidates.push(directBase);
        }

        if (Array.isArray(global.__API_BASE_CANDIDATES)) {
            global.__API_BASE_CANDIDATES.forEach(function(candidate) {
                const value = String(candidate || "").trim();
                if (value) {
                    candidates.push(value);
                }
            });
        }

        const storedCandidates = String(localStorage.getItem("apiBaseCandidates") || "")
            .split(",")
            .map(function(value) {
                return String(value || "").trim();
            })
            .filter(Boolean);

        storedCandidates.forEach(function(candidate) {
            candidates.push(candidate);
        });

        appendLocalBackendCandidates(candidates);
        if (deferredUiBase) {
            candidates.push(deferredUiBase);
        }
        candidates.push("");

        const unique = [];
        const seen = Object.create(null);
        candidates.forEach(function(candidate) {
            const normalized = candidate.replace(/\/$/, "");
            if (seen[normalized]) {
                return;
            }
            seen[normalized] = true;
            unique.push(normalized);
        });

        return unique;
    }

    const API_CANDIDATES = getApiCandidates();
    let activeApiBase = API_CANDIDATES.length > 0 ? API_CANDIDATES[0] : "";

    function getOrderedApiCandidates() {
        const ordered = [];

        if (activeApiBase || activeApiBase === "") {
            ordered.push(activeApiBase);
        }

        API_CANDIDATES.forEach(function(candidate) {
            ordered.push(candidate);
        });

        const unique = [];
        const seen = Object.create(null);
        ordered.forEach(function(candidate) {
            const normalized = String(candidate || "").trim().replace(/\/$/, "");
            if (seen[normalized]) {
                return;
            }

            seen[normalized] = true;
            unique.push(normalized);
        });

        return unique;
    }

    function persistWorkingApiBase(base, allCandidates) {
        const normalized = String(base || "").trim().replace(/\/$/, "");
        activeApiBase = normalized;

        if (normalized) {
            localStorage.setItem("apiBaseUrl", normalized);
        }

        const reordered = (allCandidates || [])
            .map(function(value) {
                return String(value || "").trim().replace(/\/$/, "");
            })
            .filter(function(value) {
                return value;
            })
            .filter(function(value, index, arr) {
                return arr.indexOf(value) === index;
            });

        if (normalized) {
            const filtered = reordered.filter(function(value) {
                return value !== normalized;
            });
            filtered.unshift(normalized);
            localStorage.setItem("apiBaseCandidates", filtered.join(","));
        }

        if (global.AdminApi) {
            global.AdminApi.API_BASE = normalized;
        }
    }

    function resolveApiUrl(path) {
        const normalizedPath = String(path || "").replace(/^\//, "");
        if (!activeApiBase) {
            return "/" + normalizedPath;
        }

        return activeApiBase + "/" + normalizedPath;
    }

    function safeJsonParse(raw) {
        if (!raw) {
            return null;
        }

        try {
            return JSON.parse(raw);
        } catch {
            return null;
        }
    }

    function readSession() {
        const parsed = safeJsonParse(localStorage.getItem("adminUser") || localStorage.getItem("admin"));
        if (!parsed || typeof parsed !== "object") {
            return null;
        }

        const role = String(parsed.role || "").trim().toLowerCase();
        if (role && role !== "admin") {
            return null;
        }

        return parsed;
    }

    function getAuthToken() {
        return String(localStorage.getItem("authToken") || "").trim();
    }

    function decodeJwtPayload(token) {
        try {
            const parts = token.split(".");
            if (parts.length < 2) {
                return null;
            }

            let value = parts[1].replace(/-/g, "+").replace(/_/g, "/");
            while (value.length % 4 !== 0) {
                value += "=";
            }

            return JSON.parse(atob(value));
        } catch {
            return null;
        }
    }

    function isTokenExpired(token) {
        if (!token) {
            return true;
        }

        const payload = decodeJwtPayload(token);
        if (!payload || typeof payload.exp !== "number") {
            return false;
        }

        const nowSeconds = Math.floor(Date.now() / 1000);
        return payload.exp <= nowSeconds;
    }

    function getHeaders(extra) {
        const headers = Object.assign({}, extra || {});
        const token = getAuthToken();
        const session = readSession();

        if (token) {
            headers.Authorization = "Bearer " + token;
        }

        if (session) {
            const email = String(session.email || "").trim();
            const role = String(session.role || "admin").trim().toLowerCase();
            if (email && !headers["X-Requester-Email"]) {
                headers["X-Requester-Email"] = email;
            }
            if (role && !headers["X-Requester-Role"]) {
                headers["X-Requester-Role"] = role;
            }
        }

        if (!headers["Content-Type"] && !(headers instanceof FormData)) {
            headers["Content-Type"] = "application/json";
        }

        return headers;
    }

    async function parseJsonSafe(response) {
        try {
            return await response.json();
        } catch {
            return null;
        }
    }

    async function fetchWithTimeout(url, options, timeoutMs) {
        const controller = new AbortController();
        const timer = setTimeout(function() {
            controller.abort();
        }, Number(timeoutMs) > 0 ? Number(timeoutMs) : BRAND_FETCH_TIMEOUT_MS);

        try {
            return await fetch(url, Object.assign({}, options || {}, { signal: controller.signal }));
        } finally {
            clearTimeout(timer);
        }
    }

    async function request(path, options) {
        if (path.startsWith("http")) {
            const directResponse = await fetch(path, options || {});
            const directBody = await parseJsonSafe(directResponse);
            if (!directResponse.ok) {
                const directMessage = directBody && directBody.message ? directBody.message : "Request failed.";
                throw new Error(directMessage);
            }

            return directBody;
        }

        const finalOptions = Object.assign({}, options || {});
        const isFormData = finalOptions.body instanceof FormData;
        const headerInput = Object.assign({}, finalOptions.headers || {});

        if (isFormData && headerInput["Content-Type"]) {
            delete headerInput["Content-Type"];
        }

        finalOptions.headers = getHeaders(headerInput);
        if (isFormData && finalOptions.headers["Content-Type"]) {
            delete finalOptions.headers["Content-Type"];
        }

        const candidates = getOrderedApiCandidates();
        let lastMessage = "Request failed.";
        let sawAuthFailure = false;

        for (const candidate of candidates) {
            const normalizedPath = String(path || "").replace(/^\//, "");
            const url = candidate ? (candidate + "/" + normalizedPath) : ("/" + normalizedPath);

            try {
                const response = await fetch(url, finalOptions);
                const body = await parseJsonSafe(response);

                if (response.ok) {
                    persistWorkingApiBase(candidate, candidates);
                    return body;
                }

                if (body && body.message) {
                    lastMessage = body.message;
                }

                if (response.status === 404 || response.status === 405 || response.status === 502 || response.status === 503) {
                    continue;
                }

                if (response.status === 401 || response.status === 403) {
                    sawAuthFailure = true;
                    continue;
                }

                throw new Error(lastMessage);
            } catch (error) {
                if (error && typeof error.message === "string") {
                    if (error.message.indexOf("session has expired") >= 0) {
                        throw error;
                    }
                }

                if (error && typeof error.message === "string" && error.message) {
                    lastMessage = error.message;
                }
            }
        }

        if (sawAuthFailure) {
            logout({ confirm: false });
            throw new Error(lastMessage || "Your session has expired. Please log in again.");
        }

        throw new Error(lastMessage);
    }

    function ensureAdminSession() {
        const session = readSession();
        const token = getAuthToken();
        const isLoggedIn = localStorage.getItem("isAdminLoggedIn") === "true";

        if (!session || !isLoggedIn || !token || isTokenExpired(token)) {
            logout({ confirm: false });
            return null;
        }

        const holder = document.getElementById("adminName") || document.getElementById("admin-name");
        if (holder && session.name) {
            holder.textContent = session.name;
        }

        return session;
    }

    function redirectToLogin() {
        location.href = "/Home/AdminLogin";
    }

    function logout(options) {
        const shouldConfirm = !(options && options.confirm === false);
        if (shouldConfirm && typeof global.confirm === "function") {
            const approved = global.confirm("Are you sure you want to logout?");
            if (!approved) {
                return;
            }
        }

        localStorage.removeItem("authToken");
        localStorage.removeItem("adminUser");
        localStorage.removeItem("admin");
        localStorage.removeItem("isAdminLoggedIn");
        redirectToLogin();
    }

    function showMessage(message, type) {
        const el = document.getElementById("message") || document.getElementById("error-message");

        if (el) {
            el.classList.remove("hidden");
            el.classList.remove("bg-green-100", "text-green-700", "bg-red-100", "text-red-700");

            if (type === "success") {
                el.classList.add("bg-green-100", "text-green-700");
            } else {
                el.classList.add("bg-red-100", "text-red-700");
            }

            if (el.id === "error-message") {
                const text = document.getElementById("error-text");
                if (text) {
                    text.textContent = message;
                }
            } else {
                el.textContent = message;
            }
            return;
        }

        // No inline message element — show a floating toast instead
        let container = document.getElementById("__adminToastContainer");
        if (!container) {
            container = document.createElement("div");
            container.id = "__adminToastContainer";
            container.style.cssText = "position:fixed;top:16px;right:16px;z-index:9999;display:flex;flex-direction:column;gap:8px;max-width:360px;";
            document.body.appendChild(container);
        }

        const toast = document.createElement("div");
        const isSuccess = type === "success";
        toast.style.cssText = "padding:12px 16px;border-radius:8px;font-size:14px;box-shadow:0 4px 12px rgba(0,0,0,0.15);color:#fff;word-break:break-word;";
        toast.style.backgroundColor = isSuccess ? "#16a34a" : "#dc2626";
        toast.textContent = message || (isSuccess ? "Done." : "An error occurred.");
        container.appendChild(toast);

        setTimeout(function() {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 4000);
    }

    function fmtMoney(value) {
        const amount = Number(value || 0);
        return "₹" + amount.toFixed(2);
    }

    function fmtDate(value) {
        if (!value) {
            return "-";
        }

        const d = new Date(value);
        if (Number.isNaN(d.getTime())) {
            return "-";
        }

        return d.toLocaleString();
    }

    function toAbsoluteLogoUrl(logoPath) {
        const raw = String(logoPath || "").trim();
        if (!raw) {
            return "";
        }

        if (/^https?:\/\//i.test(raw) || raw.startsWith("data:")) {
            return raw;
        }

        const base = String(activeApiBase || localStorage.getItem("apiBaseUrl") || "").trim().replace(/\/$/, "");

        if (raw.startsWith("/")) {
            return base ? base + raw : raw;
        }

        return base ? base + "/" + raw.replace(/^\//, "") : "/" + raw.replace(/^\//, "");
    }

    function applyBrandName(appName) {
        if (!appName) {
            return;
        }

        const knownNames = [
            "Food Order Admin",
            "Food Order Cafe",
            "CampusEatzz",
            "Campus Cafe"
        ];

        document.querySelectorAll(".app-name, [data-app-name], #app-name").forEach(function(el) {
            el.textContent = appName;
        });

        document.querySelectorAll("span.text-xl.font-bold, h1, .navbar-brand").forEach(function(el) {
            const text = String(el.textContent || "").trim();
            if (knownNames.indexOf(text) >= 0) {
                el.textContent = appName;
            }
        });

        const currentTitle = document.title || "";
        if (!currentTitle) {
            document.title = appName;
            return;
        }

        let updatedTitle = currentTitle;
        knownNames.forEach(function(name) {
            updatedTitle = updatedTitle.replace(new RegExp(name, "gi"), appName);
        });

        if (updatedTitle === currentTitle && currentTitle.indexOf(appName) === -1) {
            updatedTitle = appName + " - " + currentTitle;
        }

        document.title = updatedTitle;
    }

    function applyBrandLogo(logoUrl) {
        if (!logoUrl) {
            return;
        }

        document.querySelectorAll(".app-logo, [data-app-logo], img[alt*='Food Order' i], img[alt*='Uka Tarsadia' i]").forEach(function(el) {
            const currentSrc = String(el.getAttribute("src") || "").trim();
            if (
                !el.classList.contains("app-logo")
                && !el.hasAttribute("data-app-logo")
                && currentSrc
                && currentSrc.indexOf("logo") === -1
            ) {
                return;
            }

            el.setAttribute("src", logoUrl);
        });
    }

    function readBrandCacheFrom(storage, key) {
        if (!storage) {
            return null;
        }

        const cache = safeJsonParse(storage.getItem(key));
        if (!cache || typeof cache !== "object") {
            return null;
        }

        const expiresAt = Number(cache.expiresAt || 0);
        if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) {
            return null;
        }

        return cache.values || null;
    }

    function readCachedBranding() {
        return readBrandCacheFrom(sessionStorage, BRAND_CACHE_KEY)
            || readBrandCacheFrom(localStorage, BRAND_SHARED_CACHE_KEY);
    }

    function writeBrandCache(values) {
        const payload = JSON.stringify({
            values: values,
            expiresAt: Date.now() + BRAND_CACHE_TTL_MS
        });

        sessionStorage.setItem(BRAND_CACHE_KEY, payload);
        localStorage.setItem(BRAND_SHARED_CACHE_KEY, payload);
        localStorage.setItem(BRAND_VERSION_KEY, String(Date.now()));
    }

    function clearBrandCache() {
        sessionStorage.removeItem(BRAND_CACHE_KEY);
        localStorage.removeItem(BRAND_SHARED_CACHE_KEY);
        localStorage.setItem(BRAND_VERSION_KEY, String(Date.now()));
    }

    async function fetchBrandSettings(forceRefresh) {
        const shouldForceRefresh = !!forceRefresh;
        const cached = shouldForceRefresh ? null : readCachedBranding();
        if (cached && typeof cached === "object") {
            return cached;
        }

        const candidates = getOrderedApiCandidates();
        for (const candidate of candidates) {
            const url = candidate ? (candidate + "/api/public/settings") : "/api/public/settings";
            try {
                const response = await fetchWithTimeout(url, {
                    method: "GET",
                    headers: { "Content-Type": "application/json" }
                }, BRAND_FETCH_TIMEOUT_MS);
                if (!response.ok) {
                    continue;
                }
                const body = await parseJsonSafe(response);
                if (!body || body.success !== true || !body.data || typeof body.data !== "object") {
                    continue;
                }
                persistWorkingApiBase(candidate, candidates);
                writeBrandCache(body.data);
                return body.data;
            } catch {
                // try next candidate
            }
        }
        return null;
    }

    function applyBrandingValues(values, persist) {
        const source = values && typeof values === "object" ? values : {};
        let appName = String(source.app_name ? source.app_name : BRAND_NAME_FALLBACK).trim();
        const normalizedName = appName.toLowerCase();
        if (normalizedName === "food order cafe" || normalizedName === "campus cafe" || normalizedName === "food order admin") {
            appName = BRAND_NAME_FALLBACK;
        }
        const logoUrl = toAbsoluteLogoUrl(source.logo_url ? source.logo_url : "");
        const normalizedValues = {
            app_name: appName || BRAND_NAME_FALLBACK,
            logo_url: logoUrl,
            tax_percentage: source.tax_percentage || "",
            delivery_charge: source.delivery_charge || "",
            min_order_delivery: source.min_order_delivery || "",
            operating_hours_open: source.operating_hours_open || "",
            operating_hours_close: source.operating_hours_close || ""
        };

        if (persist !== false) {
            writeBrandCache(normalizedValues);
        }

        applyBrandName(appName || BRAND_NAME_FALLBACK);
        applyBrandLogo(logoUrl);

        global.__APP_SETTINGS = normalizedValues;
        return normalizedValues;
    }

    async function applyDynamicBranding(options) {
        const opts = options && typeof options === "object" ? options : {};
        const incomingValues = opts.values && typeof opts.values === "object" ? opts.values : null;
        const persist = opts.persist !== false;

        if (incomingValues) {
            return applyBrandingValues(incomingValues, persist);
        }

        const values = await fetchBrandSettings(!!opts.forceRefresh);
        return applyBrandingValues(values || {}, persist);
    }

    function setBrandingValues(values) {
        return applyDynamicBranding({ values: values, persist: true });
    }

    function refreshBranding() {
        return applyDynamicBranding({ forceRefresh: true });
    }

    global.AdminApi = {
        API_BASE: activeApiBase,
        request,
        ensureAdminSession,
        logout,
        showMessage,
        fmtMoney,
        fmtDate,
        resolveApiUrl,
        applyDynamicBranding,
        setBrandingValues,
        refreshBranding,
        clearBrandCache
    };

    global.logout = logout;
    global.logoutAdmin = logout;
    global.toggleMobileMenu = function() {
        const menu = document.getElementById("mobileMenu");
        if (menu) {
            menu.classList.toggle("hidden");
        }
    };

    global.addEventListener("storage", function(event) {
        if (!event || (event.key !== BRAND_SHARED_CACHE_KEY && event.key !== BRAND_VERSION_KEY)) {
            return;
        }

        const sharedValues = readBrandCacheFrom(localStorage, BRAND_SHARED_CACHE_KEY);
        if (!sharedValues) {
            return;
        }

        applyDynamicBranding({ values: sharedValues, persist: false });
    });

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", applyDynamicBranding);
    } else {
        applyDynamicBranding();
    }
})(window);
