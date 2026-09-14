module("luci.controller.campus_auth", package.seeall)

local function reply(data)
    local http = require "luci.http"
    http.prepare_content("application/json")
    http.write_json(data)
end

local function state_value(state_file, name)
    state_file = state_file or ""
    local newline = string.char(10)
    return state_file:match(name .. "=([^" .. newline .. "]+)") or ""
end

local function account_status_map()
    local fs = require "nixio.fs"
    local acct_file = fs.readfile("/var/run/campus_auth_acct.state") or ""
    local result = {}
    for line in acct_file:gmatch("[^\r\n]+") do
        local sec, flow, fee = line:match("^(%S+)%s+(%S+)%s+(%S+)%s*$")
        if sec then
            result[sec] = { flow = flow, fee = fee }
        end
    end
    return result
end

function index()
    entry({"admin", "network", "campus_auth"}, template("campus_auth/main"), _("校园网认证"), 45).dependent = false
    entry({"admin", "network", "campus_auth", "config"}, call("config")).leaf = true
    entry({"admin", "network", "campus_auth", "status"}, call("status")).leaf = true
    entry({"admin", "network", "campus_auth", "save"}, call("save")).leaf = true
    entry({"admin", "network", "campus_auth", "login"}, call("login")).leaf = true
    entry({"admin", "network", "campus_auth", "logout"}, call("logout")).leaf = true
end

function config()
    local uci = require("luci.model.uci").cursor()
    local accounts = {}
    local active_account = uci:get("campus_auth", "main", "active_account") or ""
    uci:foreach("campus_auth", "account", function(s)
        accounts[#accounts + 1] = {
            section = s[".name"],
            enabled = tonumber(s.enabled or 0),
            username = s.username or "",
            priority = tonumber(s.priority or 100),
            active = s[".name"] == active_account and 1 or 0,
            password_set = (s.password and s.password ~= "") and 1 or 0
        }
    end)
    table.sort(accounts, function(a, b)
        if a.priority == b.priority then
            return a.section < b.section
        end
        return a.priority < b.priority
    end)
    if #accounts > 0 and active_account == "main" then
        accounts[1].active = 1
    end
    reply({
        main = {
            enabled = uci:get_bool("campus_auth", "main", "enabled") and 1 or 0,
            portal_url = uci:get("campus_auth", "main", "portal_url") or "http://172.18.3.3/0.htm",
            status_url = uci:get("campus_auth", "main", "status_url") or "",
            logout_url = uci:get("campus_auth", "main", "logout_url") or "",
            interval = uci:get("campus_auth", "main", "interval") or "300",
            switch_balance = uci:get("campus_auth", "main", "switch_balance") or "0",
            switch_flow = uci:get("campus_auth", "main", "switch_flow") or "0",
            pid = uci:get("campus_auth", "main", "pid") or "2",
            calg = uci:get("campus_auth", "main", "calg") or "12345678"
        },
        accounts = accounts,
        account_status = account_status_map()
    })
end

function status()
    local uci = require("luci.model.uci").cursor()
    local fs = require "nixio.fs"
    local state_file = fs.readfile("/var/run/campus_auth.state") or ""
    local current_state = state_value(state_file, "state")
    reply({
        enabled = uci:get_bool("campus_auth", "main", "enabled") and 1 or 0,
        configured = (uci:get("campus_auth", "main", "portal_url") or "") ~= "" and 1 or 0,
        state = current_state ~= "" and current_state or "unknown",
        message = state_value(state_file, "message"),
        account = state_value(state_file, "account_user"),
        time = state_value(state_file, "time"),
        flow = state_value(state_file, "flow"),
        fee = state_value(state_file, "fee"),
        uid = state_value(state_file, "uid"),
        v4ip = state_value(state_file, "v4ip"),
        account_status = account_status_map()
    })
end

function save()
    local http = require "luci.http"
    local uci = require("luci.model.uci").cursor()
    local jsonc = require "luci.jsonc"
    local sys = require "luci.sys"
    local function form(name, default)
        local value = http.formvalue(name)
        return value ~= nil and value or default
    end

    local accounts = jsonc.parse(form("accounts", "[]")) or {}
    uci:set("campus_auth", "main", "enabled", form("enabled", "0"))
    uci:set("campus_auth", "main", "portal_url", form("portal_url", "http://172.18.3.3/0.htm"))
    uci:set("campus_auth", "main", "status_url", form("status_url", "http://172.18.3.3/"))
    uci:set("campus_auth", "main", "logout_url", form("logout_url", "http://172.18.3.3/F.htm"))
    uci:set("campus_auth", "main", "interval", form("interval", "300"))
    uci:set("campus_auth", "main", "switch_balance", form("switch_balance", "0"))
    uci:set("campus_auth", "main", "switch_flow", form("switch_flow", "0"))
    uci:set("campus_auth", "main", "pid", form("pid", "2"))
    uci:set("campus_auth", "main", "calg", form("calg", "12345678"))

    local old = {}
    local old_sections = {}
    uci:foreach("campus_auth", "account", function(s)
        old[s[".name"]] = s
        old_sections[#old_sections + 1] = s[".name"]
    end)
    for _, section in ipairs(old_sections) do
        uci:delete("campus_auth", section)
    end

    local active_section = ""
    for i, account in ipairs(accounts) do
        local section = "account" .. i
        local password = account.password or ""
        local previous = old[account.section]
        if password == "" and previous then
            password = previous.password or ""
        end
        uci:set("campus_auth", section, "account")
        uci:set("campus_auth", section, "enabled", tonumber(account.enabled or 0) == 1 and "1" or "0")
        uci:set("campus_auth", section, "username", account.username or "")
        uci:set("campus_auth", section, "password", password)
        uci:set("campus_auth", section, "priority", tostring(i * 10))
        if tonumber(account.active or 0) == 1 and tonumber(account.enabled or 0) == 1 then
            active_section = section
        end
    end
    if active_section == "" then
        for i, account in ipairs(accounts) do
            if tonumber(account.enabled or 0) == 1 then
                active_section = "account" .. i
                break
            end
        end
    end
    uci:set("campus_auth", "main", "active_account", active_section)
    uci:commit("campus_auth")

    if form("enabled", "0") == "1" then
        sys.call("/etc/init.d/campus_auth enable >/dev/null 2>&1; /etc/init.d/campus_auth restart >/dev/null 2>&1")
    else
        sys.call("/etc/init.d/campus_auth disable >/dev/null 2>&1; /etc/init.d/campus_auth stop >/dev/null 2>&1")
    end
    reply({success = 1})
end

function login()
    local sys = require "luci.sys"
    reply({success = sys.call("/usr/bin/campus-auth login >/dev/null 2>&1") == 0 and 1 or 0})
end

function logout()
    local sys = require "luci.sys"
    reply({success = sys.call("/usr/bin/campus-auth logout >/dev/null 2>&1") == 0 and 1 or 0})
end
