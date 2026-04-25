(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) {
        return;
    }

    const settingKeys = [
        "app_name",
        "tax_percentage",
        "delivery_charge",
        "min_order_delivery",
        "operating_hours_open",
        "operating_hours_close"
    ];

    const state = {
        settings: {},
        maintenanceMap: {}
    };

    const settingsForm = document.getElementById("settings-form");
    const profileForm = document.getElementById("profile-form");
    const passwordForm = document.getElementById("password-form");
    const logoInput = document.getElementById("logo-file");
    const logoPreview = document.getElementById("logo-preview");
    const canteensContainer = document.getElementById("canteens-container");

    function showToast(message, isError) {
        const container = document.getElementById("message-container");
        if (!container) {
            return;
        }

        const node = document.createElement("div");
        node.className = "mb-2 px-4 py-3 rounded shadow text-white " + (isError ? "bg-red-600" : "bg-green-600");
        node.textContent = message;
        container.appendChild(node);

        setTimeout(function() {
            node.remove();
        }, 3200);
    }

    function escapeHtml(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;");
    }

    function setButtonBusy(button, busy) {
        if (!button) {
            return;
        }

        button.disabled = busy;
        button.classList.toggle("opacity-70", busy);
        button.classList.toggle("cursor-not-allowed", busy);
    }

    function setInputValue(id, value) {
        const el = document.getElementById(id);
        if (el) {
            el.value = value || "";
        }
    }

    function setLogoPreview(url) {
        if (!logoPreview || !url) {
            return;
        }

        logoPreview.src = url;
    }

    async function loadSettings() {
        const response = await AdminApi.request("/api/admin/settings");
        const values = response && response.data && response.data.values ? response.data.values : {};
        state.settings = Object.assign({}, values || {});

        settingKeys.forEach(function(key) {
            setInputValue("setting-" + key, state.settings[key] || "");
        });

        if (state.settings.logo_url) {
            setLogoPreview(state.settings.logo_url);
        }
    }

    async function saveSettings(event) {
        event.preventDefault();

        const saveButton = document.getElementById("save-settings-btn");
        setButtonBusy(saveButton, true);

        try {
            if (logoInput && logoInput.files && logoInput.files.length > 0) {
                const file = logoInput.files[0];
                const formData = new FormData();
                formData.append("logo", file);

                const uploadResult = await AdminApi.request("/api/admin/settings/logo-upload", {
                    method: "POST",
                    body: formData,
                    headers: {}
                });

                const uploadedLogoUrl = uploadResult && uploadResult.data ? uploadResult.data.logoUrl : "";
                if (uploadedLogoUrl) {
                    state.settings.logo_url = uploadedLogoUrl;
                    setLogoPreview(uploadedLogoUrl);
                }
            }

            for (let i = 0; i < settingKeys.length; i += 1) {
                const key = settingKeys[i];
                const input = document.getElementById("setting-" + key);
                const value = input ? String(input.value || "").trim() : "";

                const saveResult = await AdminApi.request("/api/admin/settings", {
                    method: "PUT",
                    body: JSON.stringify({
                        settingKey: key,
                        settingValue: value
                    })
                });

                const savedValue = saveResult && saveResult.data && typeof saveResult.data.settingValue === "string"
                    ? saveResult.data.settingValue
                    : value;
                state.settings[key] = savedValue;
            }

            const brandingValues = Object.assign({}, state.settings);
            if (typeof AdminApi.setBrandingValues === "function") {
                await AdminApi.setBrandingValues(brandingValues);
            } else {
                await AdminApi.applyDynamicBranding({ values: brandingValues, persist: true });
            }

            showToast("Application settings saved successfully.", false);
        } catch (error) {
            showToast(error.message || "Failed to save settings.", true);
        } finally {
            setButtonBusy(saveButton, false);
            if (logoInput) {
                logoInput.value = "";
            }
        }
    }

    async function loadProfile() {
        const result = await AdminApi.request("/api/admin/profile");
        const profile = result && result.data ? result.data : {};

        setInputValue("profile-name", profile.name || "");
        setInputValue("profile-email", profile.email || "");

        const nameHolder = document.getElementById("adminName") || document.getElementById("admin-name");
        if (nameHolder && profile.name) {
            nameHolder.textContent = profile.name;
        }

        try {
            const localUser = JSON.parse(localStorage.getItem("adminUser") || localStorage.getItem("admin") || "null");
            if (localUser && typeof localUser === "object") {
                localUser.name = profile.name || localUser.name || "Admin";
                localUser.email = profile.email || localUser.email || "";
                localUser.role = "admin";
                localStorage.setItem("adminUser", JSON.stringify(localUser));
                localStorage.setItem("admin", JSON.stringify(localUser));
            }
        } catch {
            // Ignore malformed local profile cache.
        }
    }

    async function saveProfile(event) {
        event.preventDefault();

        const button = document.getElementById("save-profile-btn");
        setButtonBusy(button, true);

        try {
            const name = String(document.getElementById("profile-name")?.value || "").trim();
            const email = String(document.getElementById("profile-email")?.value || "").trim();

            const result = await AdminApi.request("/api/admin/profile", {
                method: "PUT",
                body: JSON.stringify({ name, email })
            });

            const data = result && result.data ? result.data : {};
            showToast("Profile updated successfully.", false);

            if (data.requiresRelogin === true) {
                showToast("Email changed. Please log in again.", false);
                setTimeout(function() {
                    AdminApi.logout();
                }, 1000);
                return;
            }

            await loadProfile();
        } catch (error) {
            showToast(error.message || "Failed to update profile.", true);
        } finally {
            setButtonBusy(button, false);
        }
    }

    async function savePassword(event) {
        event.preventDefault();

        const button = document.getElementById("save-password-btn");
        setButtonBusy(button, true);

        try {
            const currentPassword = String(document.getElementById("current-password")?.value || "");
            const newPassword = String(document.getElementById("new-password")?.value || "");
            const confirmPassword = String(document.getElementById("confirm-password")?.value || "");

            await AdminApi.request("/api/admin/profile/password", {
                method: "PUT",
                body: JSON.stringify({
                    currentPassword,
                    newPassword,
                    confirmPassword
                })
            });

            showToast("Password changed successfully.", false);
            passwordForm.reset();
        } catch (error) {
            showToast(error.message || "Failed to change password.", true);
        } finally {
            setButtonBusy(button, false);
        }
    }

    function renderCanteens(canteens) {
        if (!canteensContainer) {
            return;
        }

        canteensContainer.innerHTML = canteens.map(function(item) {
            const maintenance = state.maintenanceMap[item.canteenId] || { isActive: false, reason: "" };
            const escapedName = escapeHtml(item.canteenName);
            const escapedReason = escapeHtml(maintenance.reason || "");
            return ""
                + "<div class='p-6'>"
                + "  <div class='flex items-center justify-between gap-3'>"
                + "    <div><h3 class='text-lg font-semibold text-gray-800'>" + escapedName + "</h3></div>"
                + "    <label class='relative inline-flex items-center cursor-pointer'>"
                + "      <input type='checkbox' class='sr-only peer' " + (maintenance.isActive ? "checked" : "") + " onchange='window.__toggleCanteenMaintenance(" + item.canteenId + ", this.checked)'>"
                + "      <div class='w-14 h-7 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[\"\"] after:absolute after:top-0.5 after:left-[4px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-blue-600'></div>"
                + "    </label>"
                + "  </div>"
                + "  <div class='mt-3'>"
                + "    <input id='reason-" + item.canteenId + "' class='w-full px-3 py-2 border border-gray-300 rounded' placeholder='Maintenance reason' value='" + escapedReason + "'>"
                + "    <button class='mt-2 bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 transition-colors' onclick='window.__saveCanteenMaintenance(" + item.canteenId + ")'>Save</button>"
                + "  </div>"
                + "</div>";
        }).join("");
    }

    async function loadMaintenance() {
        const result = await AdminApi.request("/api/admin/maintenance");
        const data = result && result.data ? result.data : {};
        const canteens = data.canteens || [];

        state.maintenanceMap = {};
        canteens.forEach(function(item) {
            state.maintenanceMap[item.canteenId] = {
                isActive: !!item.isActive,
                reason: item.reason || ""
            };
        });

        const systemToggle = document.getElementById("system-maintenance-toggle");
        const reason = document.getElementById("system-reason-text");
        if (systemToggle) {
            systemToggle.checked = !!data.isSystemMaintenanceActive;
        }
        if (reason) {
            reason.value = data.systemMaintenanceReason || "";
        }

        renderCanteens(canteens);
    }

    async function saveSystemMaintenance() {
        const button = document.getElementById("save-system-maintenance-btn");
        setButtonBusy(button, true);

        try {
            const isActive = !!document.getElementById("system-maintenance-toggle")?.checked;
            const reason = String(document.getElementById("system-reason-text")?.value || "").trim();

            await AdminApi.request("/api/admin/maintenance/system", {
                method: "PUT",
                body: JSON.stringify({ isActive, reason })
            });

            showToast("System maintenance updated.", false);
        } catch (error) {
            showToast(error.message || "Failed to update maintenance.", true);
        } finally {
            setButtonBusy(button, false);
        }
    }

    window.__toggleCanteenMaintenance = function(canteenId, checked) {
        if (!state.maintenanceMap[canteenId]) {
            state.maintenanceMap[canteenId] = { isActive: false, reason: "" };
        }

        state.maintenanceMap[canteenId].isActive = !!checked;
    };

    window.__saveCanteenMaintenance = async function(canteenId) {
        try {
            const reasonValue = String(document.getElementById("reason-" + canteenId)?.value || "").trim();
            const current = state.maintenanceMap[canteenId] || { isActive: false };

            await AdminApi.request("/api/admin/maintenance/canteen", {
                method: "PUT",
                body: JSON.stringify({
                    canteenId,
                    isActive: !!current.isActive,
                    reason: reasonValue
                })
            });

            state.maintenanceMap[canteenId] = {
                isActive: !!current.isActive,
                reason: reasonValue
            };

            showToast("Canteen maintenance updated.", false);
        } catch (error) {
            showToast(error.message || "Failed to update canteen maintenance.", true);
        }
    };

    async function initialize() {
        try {
            await Promise.all([
                loadSettings(),
                loadProfile(),
                loadMaintenance()
            ]);
        } catch (error) {
            showToast(error.message || "Failed to initialize settings page.", true);
        }
    }

    if (settingsForm) {
        settingsForm.addEventListener("submit", saveSettings);
    }

    if (profileForm) {
        profileForm.addEventListener("submit", saveProfile);
    }

    if (passwordForm) {
        passwordForm.addEventListener("submit", savePassword);
    }

    const saveMaintenanceButton = document.getElementById("save-system-maintenance-btn");
    if (saveMaintenanceButton) {
        saveMaintenanceButton.addEventListener("click", saveSystemMaintenance);
    }

    const reloadMaintenanceButton = document.getElementById("reload-maintenance-btn");
    if (reloadMaintenanceButton) {
        reloadMaintenanceButton.addEventListener("click", function() {
            loadMaintenance().catch(function() {
                showToast("Failed to reload maintenance status.", true);
            });
        });
    }

    initialize();
})();
