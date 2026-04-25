(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const grid = document.getElementById("canteenGrid");
    const countEl = document.getElementById("canteenCount");
    const loading = document.getElementById("loadingIndicator");
    const form = document.getElementById("canteenForm");
    const imageUrlInput = document.getElementById("canteenImageUrl");
    const imageFileInput = document.getElementById("canteenImageFile");
    const imageFileLabel = document.getElementById("canteenImageFileLabel");
    const NO_FILE_TEXT = "No file chosen.";
    let localPreviewObjectUrl = null;

    function escapeHtml(v) {
        return String(v || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;");
    }

    function sanitizeImageUrl(v) {
        const value = String(v || "").trim();
        return value;
    }

    function buildApiUrl(path) {
        const value = String(path || "").trim();
        if (!value) return value;
        if (/^https?:\/\//i.test(value)) return value;

        const base = String(AdminApi.API_BASE || "").trim();
        if (!base) return value;

        const normalizedBase = base.replace(/\/$/, "");
        const normalizedPath = value.startsWith("/") ? value : `/${value.replace(/^\/+/, "")}`;
        return normalizedBase + normalizedPath;
    }

    function withCacheBust(url) {
        const value = String(url || "").trim();
        if (!value || value.startsWith("data:")) {
            return value;
        }

        const separator = value.indexOf("?") >= 0 ? "&" : "?";
        return `${value}${separator}_v=${Date.now()}`;
    }

    function clearLocalPreview() {
        if (localPreviewObjectUrl) {
            URL.revokeObjectURL(localPreviewObjectUrl);
            localPreviewObjectUrl = null;
        }
    }

    function setFileLabel(text) {
        if (!imageFileLabel) return;
        imageFileLabel.textContent = text || NO_FILE_TEXT;
    }

    function resetImageSelection() {
        clearLocalPreview();
        if (imageFileInput) {
            imageFileInput.value = "";
        }
        setFileLabel(NO_FILE_TEXT);
    }

    function setPreviewFromSelectedFile(file) {
        const preview = document.getElementById("canteenImagePreview");
        if (!preview || !file) return;

        clearLocalPreview();
        localPreviewObjectUrl = URL.createObjectURL(file);
        preview.onerror = null;
        preview.src = localPreviewObjectUrl;
    }

    function getInitials(name) {
        const words = String(name || "").trim().split(/\s+/).filter(Boolean);
        if (words.length === 0) return "CT";
        if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
        return (words[0].charAt(0) + words[1].charAt(0)).toUpperCase();
    }

    function createPlaceholderImage(name) {
        const initials = getInitials(name);
        const safeInitials = initials.replace(/[^A-Za-z0-9]/g, "").slice(0, 2) || "CT";
        const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400" role="img" aria-label="Canteen image placeholder">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#1e3c72" />
      <stop offset="100%" stop-color="#2a5298" />
    </linearGradient>
  </defs>
  <rect width="600" height="400" fill="url(#g)" />
  <circle cx="300" cy="170" r="66" fill="rgba(255,255,255,0.18)" />
  <text x="300" y="188" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="52" font-weight="700" fill="#ffffff">${safeInitials}</text>
  <text x="300" y="308" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="24" fill="rgba(255,255,255,0.9)">Canteen Image</text>
</svg>`;

        return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
    }

    function getDisplayImageUrl(item) {
        const configured = sanitizeImageUrl(item && item.imageUrl);
        if (configured) {
            return configured;
        }

        return createPlaceholderImage(item && item.name);
    }

    function updateImagePreview() {
        const preview = document.getElementById("canteenImagePreview");
        const nameInput = document.getElementById("canteenName");
        if (!preview) return;

        if (imageFileInput && imageFileInput.files && imageFileInput.files.length > 0) {
            setPreviewFromSelectedFile(imageFileInput.files[0]);
            return;
        }

        const name = nameInput ? nameInput.value : "Canteen";
        const imageUrl = sanitizeImageUrl(imageUrlInput ? imageUrlInput.value : "");
        const fallback = createPlaceholderImage(name || "Canteen");

        preview.onerror = function() {
            this.onerror = null;
            this.src = fallback;
        };
        preview.src = imageUrl ? withCacheBust(imageUrl) : fallback;
    }

    window.openAddModal = function() {
        document.getElementById("modalTitle").textContent = "Add New Canteen";
        document.getElementById("canteenId").value = "";
        form.reset();
        document.getElementById("canteenActive").checked = true;
        resetImageSelection();
        updateImagePreview();
        document.getElementById("canteenModal").classList.remove("hidden");
    };

    window.closeModal = function() {
        resetImageSelection();
        document.getElementById("canteenModal").classList.add("hidden");
    };

    window.__editCanteen = function(item) {
        document.getElementById("modalTitle").textContent = "Edit Canteen";
        document.getElementById("canteenId").value = item.id;
        document.getElementById("canteenName").value = item.name || "";
        document.getElementById("canteenDescription").value = item.description || "";
        document.getElementById("canteenImageUrl").value = item.imageUrl || "";
        document.getElementById("canteenActive").checked = String(item.status || "active") === "active";
        resetImageSelection();
        updateImagePreview();
        document.getElementById("canteenModal").classList.remove("hidden");
    };

    window.__deleteCanteen = async function(id) {
        if (!confirm("Delete this canteen?")) return;
        try {
            await AdminApi.request(`/api/admin/canteens/${id}`, { method: "DELETE" });
            await load();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    };

    function render(canteens) {
        if (!grid) return;
        grid.innerHTML = canteens.map(function(c) {
            const isActive = String(c.status || "active") === "active";
            const displayImage = withCacheBust(getDisplayImageUrl(c));
            const fallbackImage = createPlaceholderImage(c && c.name);
            return `
                <div class="bg-white rounded-lg shadow overflow-hidden">
                    <div class="h-44 bg-gray-100">
                        <img src="${escapeHtml(displayImage)}" alt="${escapeHtml(c.name || "Canteen")}" class="w-full h-full object-cover" loading="lazy" onerror="this.onerror=null;this.src='${escapeHtml(fallbackImage)}'">
                    </div>
                    <div class="p-6">
                    <div class="flex items-start justify-between">
                        <div>
                            <h3 class="text-lg font-bold text-gray-800">${escapeHtml(c.name)}</h3>
                            <p class="text-sm text-gray-600 mt-1">${escapeHtml(c.description || "-")}</p>
                            <p class="text-xs mt-2 ${isActive ? "text-green-600" : "text-red-600"}">${isActive ? "Active" : "Inactive"}</p>
                        </div>
                    </div>
                    <div class="mt-4 flex gap-3">
                        <button class="px-3 py-2 text-sm bg-blue-100 text-blue-700 rounded" onclick='window.__editCanteen(${JSON.stringify(c).replace(/'/g, "\\'")})'>Edit</button>
                        <button class="px-3 py-2 text-sm bg-red-100 text-red-700 rounded" onclick="window.__deleteCanteen(${c.id})">Delete</button>
                    </div>
                    </div>
                </div>`;
        }).join("");
    }

    async function load() {
        try {
            if (loading) loading.classList.remove("hidden");
            const result = await AdminApi.request("/api/admin/canteens");
            const data = (result && result.data) || {};
            const canteens = data.canteens || [];
            render(canteens);
            if (countEl) countEl.textContent = String(data.total || canteens.length || 0);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        } finally {
            if (loading) loading.classList.add("hidden");
        }
    }

    async function uploadImageIfSelected() {
        if (!imageFileInput || !imageFileInput.files || imageFileInput.files.length === 0) {
            return null;
        }

        const file = imageFileInput.files[0];
        const maxBytes = 20 * 1024 * 1024;
        if (file.size > maxBytes) {
            throw new Error("Image must be smaller than 20 MB.");
        }

        const lowerName = String(file.name || "").toLowerCase();
        if (!/\.(jpg|jpeg|png|webp)$/.test(lowerName)) {
            throw new Error("Only JPG, PNG, or WebP images are allowed.");
        }

        const formData = new FormData();
        formData.append("image", file);

        const headers = {
            "X-Requester-Email": String((session && session.email) || "").trim(),
            "X-Requester-Role": "admin"
        };

        const token = String(localStorage.getItem("authToken") || "").trim();
        if (token) {
            headers.Authorization = `Bearer ${token}`;
        }

        const response = await fetch(buildApiUrl("/api/admin/canteens/upload-image"), {
            method: "POST",
            headers,
            body: formData
        });

        const body = await response.json().catch(() => null);
        if (!response.ok || !body || body.success !== true || !body.data || (!body.data.url && !body.data.relativePath)) {
            const message = body && body.message ? body.message : "Image upload failed.";
            throw new Error(message);
        }

        const relativePath = String(body.data.relativePath || "").trim();
        if (relativePath) {
            return relativePath;
        }

        return String(body.data.url || "").trim();
    }

    if (form) {
        form.addEventListener("submit", async function(e) {
            e.preventDefault();
            const id = document.getElementById("canteenId").value;
            const submitBtn = e.target.querySelector('button[type="submit"]');

            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.textContent = "Saving...";
            }

            try {
                const uploadedImageUrl = await uploadImageIfSelected();
                const payload = {
                    name: document.getElementById("canteenName").value,
                    description: document.getElementById("canteenDescription").value,
                    imageUrl: uploadedImageUrl || sanitizeImageUrl(document.getElementById("canteenImageUrl").value) || null,
                    isActive: document.getElementById("canteenActive").checked,
                    displayOrder: 0
                };

                let saveResult = null;

                if (id) {
                    saveResult = await AdminApi.request(`/api/admin/canteens/${id}`, {
                        method: "PUT",
                        body: JSON.stringify(payload)
                    });
                } else {
                    saveResult = await AdminApi.request("/api/admin/canteens", {
                        method: "POST",
                        body: JSON.stringify(payload)
                    });
                }

                try {
                    const syncAt = String(Date.now());
                    const savedId = Number(id || (saveResult && saveResult.data && saveResult.data.id) || 0);
                    const syncPayload = {
                        type: "canteen-updated",
                        at: syncAt,
                        canteen: {
                            id: savedId > 0 ? savedId : null,
                            name: String(payload.name || "").trim(),
                            description: String(payload.description || "").trim(),
                            imageUrl: payload.imageUrl ? buildApiUrl(String(payload.imageUrl)) : "",
                            status: payload.isActive ? "active" : "deactive"
                        }
                    };

                    localStorage.setItem("canteenImageSyncPayload", JSON.stringify(syncPayload));
                    localStorage.setItem("canteenImageSyncAt", syncAt);

                    if (window.BroadcastChannel) {
                        const syncChannel = new BroadcastChannel("campus-eatzz-canteen-sync");
                        syncChannel.postMessage(syncPayload);
                        syncChannel.close();
                    }
                } catch (syncError) {
                    // Ignore sync-signal errors; save operation has already succeeded.
                }

                closeModal();
                load();
            } catch (error) {
                AdminApi.showMessage(error.message, "error");
            } finally {
                if (submitBtn) {
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = '<i class="fas fa-save mr-2"></i>Save Canteen';
                }
            }
        });
    }

    if (imageUrlInput) {
        imageUrlInput.addEventListener("input", function() {
            if (imageFileInput && imageFileInput.files && imageFileInput.files.length > 0) {
                resetImageSelection();
            }
            updateImagePreview();
        });
    }

    const nameInput = document.getElementById("canteenName");
    if (nameInput) {
        nameInput.addEventListener("input", function() {
            const hasCustomImage = sanitizeImageUrl((imageUrlInput && imageUrlInput.value) || "");
            if (!hasCustomImage) {
                updateImagePreview();
            }
        });
    }

    if (imageFileInput) {
        imageFileInput.addEventListener("change", function() {
            const file = this.files && this.files.length > 0 ? this.files[0] : null;
            if (!file) {
                setFileLabel(NO_FILE_TEXT);
                updateImagePreview();
                return;
            }

            setFileLabel(file.name);
            setPreviewFromSelectedFile(file);
        });
    }

    window.addEventListener("beforeunload", clearLocalPreview);

    updateImagePreview();

    load();
})();
