(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const tbody = document.getElementById("adminTableBody");
    const countEl = document.getElementById("adminCount");
    const form = document.getElementById("adminForm");
    const imageInput = document.getElementById("adminImageUrl");
    const imagePreview = document.getElementById("adminImagePreview");
    let canteensCache = [];

    function escapeHtml(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\"/g, "&quot;")
            .replace(/'/g, "&#39;");
    }

    function initials(name) {
        const words = String(name || "").trim().split(/\s+/).filter(Boolean);
        if (words.length === 0) return "CA";
        if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
        return (words[0].charAt(0) + words[1].charAt(0)).toUpperCase();
    }

    function buildPlaceholderImage(name) {
        const label = initials(name).replace(/[^A-Za-z0-9]/g, "").slice(0, 2) || "CA";
        const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240" role="img" aria-label="Canteen admin image placeholder">
  <rect width="240" height="240" fill="#1e3c72" />
  <circle cx="120" cy="120" r="72" fill="rgba(255,255,255,0.2)" />
  <text x="120" y="136" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="58" font-weight="700" fill="#ffffff">${label}</text>
</svg>`;
        return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
    }

    function toAbsoluteImageUrl(value) {
        const raw = String(value || "").trim();
        if (!raw) return "";
        if (/^https?:\/\//i.test(raw) || raw.startsWith("data:")) {
            return raw;
        }

        const base = String(AdminApi.API_BASE || "").trim().replace(/\/$/, "");
        if (!base) return raw;
        const normalized = raw.startsWith("/") ? raw : `/${raw.replace(/^\/+/, "")}`;
        return base + normalized;
    }

    function updateImagePreview(name) {
        if (!imagePreview) return;
        const resolved = toAbsoluteImageUrl(imageInput ? imageInput.value : "");
        const fallback = buildPlaceholderImage(name || document.getElementById("adminName")?.value || "Canteen Admin");
        imagePreview.onerror = function() {
            this.onerror = null;
            this.src = fallback;
        };
        imagePreview.src = resolved || fallback;
    }

    function fillCanteens() {
        const select = document.getElementById("adminCanteen");
        if (!select) return;
        select.innerHTML = '<option value="">Select Canteen</option>' + canteensCache.map(function(c) {
            return `<option value="${c.id}">${c.name}</option>`;
        }).join("");
    }

    function render(admins) {
        if (!tbody) return;
        tbody.innerHTML = admins.map(function(a) {
            const avatar = toAbsoluteImageUrl(a.imageUrl) || buildPlaceholderImage(a.name || a.username || "Canteen Admin");
            return `
                <tr>
                    <td class="px-6 py-4 text-sm text-gray-900">
                        <div class="flex items-center gap-3">
                            <img src="${escapeHtml(avatar)}" alt="${escapeHtml(a.name || a.username || "Canteen Admin")}" class="w-10 h-10 rounded-full object-cover border" onerror="this.onerror=null;this.src='${escapeHtml(buildPlaceholderImage(a.name || a.username || "Canteen Admin"))}'">
                            <div>
                                <div>${escapeHtml(a.name || "-")}</div>
                                <div class="text-xs text-gray-500">${escapeHtml(a.email || "")}</div>
                            </div>
                        </div>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-700">${escapeHtml(a.username || "-")}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${escapeHtml(a.canteenName || "-")}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${escapeHtml(a.contact || "-")}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${escapeHtml(a.status || "active")}</td>
                    <td class="px-6 py-4 text-sm">
                        <button class="text-blue-600 hover:text-blue-800" onclick="window.__editCanteenAdmin(${a.id})">Edit</button>
                        <button class="ml-3 text-red-600 hover:text-red-800" onclick="window.__deleteCanteenAdmin(${a.id})">Delete</button>
                    </td>
                </tr>`;
        }).join("");
    }

    window.openAddModal = function() {
        document.getElementById("modalTitle").textContent = "Add New Canteen Admin";
        document.getElementById("adminId").value = "";
        form.reset();
        document.getElementById("passwordRequired").textContent = "*";
        document.getElementById("passwordHint").classList.add("hidden");
        if (imageInput) imageInput.value = "";
        updateImagePreview("Canteen Admin");
        document.getElementById("adminModal").classList.remove("hidden");
    };

    window.closeModal = function() {
        document.getElementById("adminModal").classList.add("hidden");
    };

    window.__editCanteenAdmin = function(id) {
        const current = window.__admins.find(function(a) { return a.id === id; });
        if (!current) return;
        document.getElementById("modalTitle").textContent = "Edit Canteen Admin";
        document.getElementById("adminId").value = String(current.id);
        document.getElementById("adminName").value = current.name || "";
        document.getElementById("adminUsername").value = current.username || "";
        document.getElementById("adminCanteen").value = String(current.canteenId || "");
        document.getElementById("adminEmail").value = current.email || "";
        document.getElementById("adminContact").value = current.contact || "";
        if (imageInput) imageInput.value = current.imageUrl || "";
        document.getElementById("adminStatus").value = current.status || "active";
        document.getElementById("adminPassword").value = "";
        document.getElementById("passwordRequired").textContent = "";
        document.getElementById("passwordHint").classList.remove("hidden");
        updateImagePreview(current.name || current.username || "Canteen Admin");
        document.getElementById("adminModal").classList.remove("hidden");
    };

    window.__deleteCanteenAdmin = async function(id) {
        if (!confirm("Delete this canteen admin?")) return;
        try {
            await AdminApi.request(`/api/admin/canteen-admins/${id}`, { method: "DELETE" });
            await load();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    };

    async function load() {
        try {
            const [canteensResult, adminsResult] = await Promise.all([
                AdminApi.request("/api/admin/canteens"),
                AdminApi.request("/api/admin/canteen-admins")
            ]);

            canteensCache = (canteensResult.data && canteensResult.data.canteens) || [];
            fillCanteens();

            const admins = (adminsResult.data && adminsResult.data.admins) || [];
            window.__admins = admins;
            render(admins);
            if (countEl) countEl.textContent = String(admins.length);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    if (form) {
        form.addEventListener("submit", async function(e) {
            e.preventDefault();
            const id = document.getElementById("adminId").value;
            const payload = {
                canteenId: Number(document.getElementById("adminCanteen").value || 0),
                name: document.getElementById("adminName").value,
                username: document.getElementById("adminUsername").value,
                email: document.getElementById("adminEmail").value,
                contact: document.getElementById("adminContact").value,
                imageUrl: imageInput ? imageInput.value : "",
                status: document.getElementById("adminStatus").value,
                password: document.getElementById("adminPassword").value
            };

            try {
                if (id) {
                    await AdminApi.request(`/api/admin/canteen-admins/${id}`, { method: "PUT", body: JSON.stringify(payload) });
                } else {
                    await AdminApi.request("/api/admin/canteen-admins", { method: "POST", body: JSON.stringify(payload) });
                }
                closeModal();
                load();
            } catch (error) {
                AdminApi.showMessage(error.message, "error");
            }
        });
    }

    if (imageInput) {
        imageInput.addEventListener("input", function() {
            updateImagePreview(document.getElementById("adminName")?.value || "Canteen Admin");
        });
    }

    const adminNameInput = document.getElementById("adminName");
    if (adminNameInput) {
        adminNameInput.addEventListener("input", function() {
            updateImagePreview(adminNameInput.value || "Canteen Admin");
        });
    }

    updateImagePreview("Canteen Admin");

    load();
})();
