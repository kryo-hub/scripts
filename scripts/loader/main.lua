-- ============================================================
-- KRYO HUB - MAIN LOADER
-- Stay Cool. Stay Precise.
-- ============================================================

local KryoHub = {
    Name = "Kryo Hub",
    Version = "1.0.0",
    BaseURL = "https://raw.githubusercontent.com/USERNAME/scripts/main/scripts/esp_core.lua"
}

-- Banner
print([[
    ╔══════════════════════════════════════╗
    ║        ❄  K R Y O   H U B  ❄         ║
    ║      Stay Cool. Stay Precise.        ║
    ╚══════════════════════════════════════╝
]])
print("[Kryo Hub] v" .. KryoHub.Version .. " loading...")

-- Download script utama
local ok, code = pcall(function()
    return game:HttpGet(KryoHub.BaseURL)
end)

if not ok or not code or #code < 100 then
    warn("[Kryo Hub] ❌ Gagal download script inti.")
    warn("            Cek URL: " .. KryoHub.BaseURL)
    return
end

-- Compile & jalankan
local fn, err = loadstring(code)
if not fn then
    warn("[Kryo Hub] ❌ Compile error: " .. tostring(err))
    return
end

local runOk, runErr = pcall(fn)
if runOk then
    print("[Kryo Hub] ✅ Loaded successfully!")
else
    warn("[Kryo Hub] ❌ Runtime error: " .. tostring(runErr))
end
