(function() {
    const form = document.getElementById("admin-login-form");
    if (!form) return;

    function appendLocalBackendCandidates(candidates) {
        const protocol = String(window.location && window.location.protocol || "http:").toLowerCase();
        const hostname = String(window.location && window.location.hostname || "").toLowerCase();
        if (!hostname) {
            return;
        }

        const formattedHost = hostname.includes(":") && !hostname.startsWith("[")
            ? `[${hostname}]`
            : hostname;

        ["5000", "5266", "5299"].forEach((port) => {
            candidates.push(`${protocol}//${formattedHost}:${port}`);
        });

        const localHosts = ["localhost", "127.0.0.1", "::1"];
        if (localHosts.indexOf(hostname) === -1) {
            return;
        }

        ["5000", "5266", "5299"].forEach((port) => {
            if (hostname === "127.0.0.1") {
                candidates.push(`${protocol}//localhost:${port}`);
            }
            if (hostname === "localhost") {
                candidates.push(`${protocol}//127.0.0.1:${port}`);
            }
        });
    }

    function shouldDeferLocalUiOrigin(base) {
        const raw = String(base || "").trim();
        if (!raw) {
            return false;
        }

        try {
            const baseUrl = new URL(raw, window.location.origin);
            const uiUrl = new URL(window.location.origin);
            const localHosts = ["localhost", "127.0.0.1", "::1"];
            if (!localHosts.includes(baseUrl.hostname.toLowerCase())) {
                return false;
            }

            return baseUrl.origin === uiUrl.origin;
        } catch {
            return false;
        }
    }

    function getApiCandidates() {
        const candidates = [];

        const protocol = String(window.location && window.location.protocol || "http:").toLowerCase();
        const hostname = String(window.location && window.location.hostname || "").trim();
        if (hostname) {
            const formattedHost = hostname.includes(":") && !hostname.startsWith("[")
                ? `[${hostname}]`
                : hostname;
            candidates.push(`${protocol}//${formattedHost}:5000`);
        }

        const preferred = String(
            window.__API_BASE
            || localStorage.getItem("apiBaseUrl")
            || (window.AdminApi && window.AdminApi.API_BASE)
            || ""
        ).trim();
        const deferredUiBase = shouldDeferLocalUiOrigin(preferred) ? preferred : "";
        if (preferred && !deferredUiBase) {
            candidates.push(preferred);
        }

        if (Array.isArray(window.__API_BASE_CANDIDATES)) {
            window.__API_BASE_CANDIDATES.forEach((value) => {
                const normalized = String(value || "").trim();
                if (normalized) {
                    candidates.push(normalized);
                }
            });
        }

        String(localStorage.getItem("apiBaseCandidates") || "")
            .split(",")
            .map((value) => String(value || "").trim())
            .filter(Boolean)
            .forEach((value) => {
                candidates.push(value);
            });

        appendLocalBackendCandidates(candidates);
        if (deferredUiBase) {
            candidates.push(deferredUiBase);
        }

        candidates.push("");

        const unique = [];
        const seen = Object.create(null);
        candidates.forEach((value) => {
            const normalized = value.replace(/\/$/, "");
            if (seen[normalized]) {
                return;
            }

            seen[normalized] = true;
            unique.push(normalized);
        });

        return unique;
    }

    function resolveApiUrl(base, path) {
        const normalizedPath = String(path || "").replace(/^\//, "");
        const normalizedBase = String(base || "").trim().replace(/\/$/, "");
        return normalizedBase ? `${normalizedBase}/${normalizedPath}` : `/${normalizedPath}`;
    }

    function persistWorkingApiBase(base, allCandidates) {
        const normalized = String(base || "").trim().replace(/\/$/, "");
        if (normalized) {
            localStorage.setItem("apiBaseUrl", normalized);
        }

        const others = (allCandidates || [])
            .map((value) => String(value || "").trim().replace(/\/$/, ""))
            .filter((value) => value && value !== normalized);

        if (normalized) {
            others.unshift(normalized);
        }

        localStorage.setItem("apiBaseCandidates", others.join(","));
    }

    async function attemptAdminLogin(email, password) {
        const candidates = getApiCandidates();
        let lastError = "Invalid credentials.";
        const REQUEST_TIMEOUT_MS = 60000; // 60 second timeout for slow servers

        for (const candidate of candidates) {
            try {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

                try {
                    const response = await fetch(resolveApiUrl(candidate, "api/admin/login"), {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ email, password }),
                        signal: controller.signal
                    });

                    clearTimeout(timeoutId);

                    const body = await parseJsonSafe(response);
                    if (response.ok && body && body.success) {
                        persistWorkingApiBase(candidate, candidates);
                        return body;
                    }

                    if (body && body.message) {
                        lastError = body.message;
                    }

                    // Keep trying other candidates to recover from stale API base URLs.
                    continue;
                } finally {
                    clearTimeout(timeoutId);
                }
            } catch (error) {
                if (error.name === 'AbortError') {
                    lastError = "Server timeout. The server took too long to respond. Please try again.";
                } else if (error instanceof TypeError) {
                    lastError = "Cannot reach server. Please check your internet connection.";
                } else {
                    lastError = "Unable to reach server. Please try again.";
                }
            }
        }

        throw new Error(lastError);
    }

    async function parseJsonSafe(response) {
        try {
            return await response.json();
        } catch (error) {
            return null;
        }
    }

    form.addEventListener("submit", async function(evt) {
        evt.preventDefault();

        const email = document.getElementById("email")?.value?.trim() || "";
        const password = document.getElementById("password")?.value || "";
        const submitBtn = form.querySelector('button[type="submit"]');

        if (!email || !password) {
            const err = document.getElementById("error-message");
            const txt = document.getElementById("error-text");
            if (err && txt) {
                err.classList.remove("hidden");
                txt.textContent = "Email and password are required.";
            }
            return;
        }

        // Show loading state
        const originalBtnText = submitBtn?.innerHTML;
        if (submitBtn) {
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i> Logging in...';
        }

        try {
            const body = await attemptAdminLogin(email, password);

            const adminUser = body.data || {};
            adminUser.role = "admin";

            localStorage.setItem("authToken", body.token || "");
            localStorage.setItem("adminUser", JSON.stringify(adminUser));
            localStorage.setItem("admin", JSON.stringify(adminUser));
            localStorage.setItem("isAdminLoggedIn", "true");

            if (location.pathname.toLowerCase().includes("/home/")) {
                location.href = "/Home/AdminDashboard";
            } else {
                location.href = "admin_files/Home/AdminDashboard";
            }
        } catch (error) {
            // Restore button state
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.innerHTML = originalBtnText;
            }

            const err = document.getElementById("error-message");
            const txt = document.getElementById("error-text");
            if (err && txt) {
                err.classList.remove("hidden");
                txt.textContent = error.message || "Login failed.";
            }
        }
    });
})();
