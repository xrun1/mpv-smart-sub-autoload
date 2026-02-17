local utils = require("mp.utils")
local msg = require("mp.msg")

local sub_exts = mp.get_property_native("sub-auto-exts")

local config = {
    auto_select_first_matching_sub = true,
}
require("mp.options").read_options(config)

local function base_dir(path)
    return path:match("^(.*[/\\])")
end

local function file_name(path)
    return path:match("([^/\\]+)$")
end

local function file_ext(name)
    return name:match(".*%.(.*)") or ""
end

local function extract_numbers(str)
    local numbers = {}
    str:gsub("%d+", function(num) numbers[#numbers + 1] = tonumber(num) end)
    return numbers
end

local function index_of(array, key)
    for i, v in ipairs(array) do
        if v == key then return i end
    end
    return nil
end

local function array_has(array, key)
    return index_of(array, key) ~= nil
end

local function filter_array(array, predicate)
    local new = {}
    for _, v in ipairs(array) do
        if predicate(v) then new[#new + 1] = v end
    end
    return new
end

local function is_sub_already_loaded(sub_name)
    local tracks = mp.get_property_native("track-list", {})
    for _, track in ipairs(tracks) do
        if track.type == "sub" and track["external-filename"] then
            if file_name(track["external-filename"]) == sub_name then
                return true
            end
        end
    end
    return false
end

local function episode_number(file, sorted_files)
    local idx = index_of(sorted_files, file)
    if not idx then
        msg.warn("File not found in list: " .. file)
        return nil
    end

    local numbers = extract_numbers(file)
    if #numbers == 0 then
        msg.warn("No numbers found in: " .. file)
        return nil
    end

    local function find_episode_vs(other_idx)
        local other_numbers = extract_numbers(sorted_files[other_idx])
        for n = 1, math.min(#numbers, #other_numbers) do
            if numbers[n] ~= other_numbers[n] then
                return numbers[n]
            end
        end
        return nil
    end

    for i = idx + 1, #sorted_files do
        local ep = find_episode_vs(i)
        if ep then return ep end
    end
    for i = idx - 1, 1, -1 do
        local ep = find_episode_vs(i)
        if ep then return ep end
    end

    return numbers[1]
end

local function load_subs()
    local path = mp.get_property("path")
    if not path then return end

    local dir  = base_dir(path)
    local file = file_name(path)
    if not dir or not file then return end

    local ext = file_ext(file):lower()

    local all_files = utils.readdir(dir, "files")
    if not all_files then return end

    local videos = filter_array(all_files, function(f)
        return file_ext(f):lower() == ext
    end)
    table.sort(videos)

    local episode = episode_number(file, videos)
    if not episode then return end

    local subs = filter_array(all_files, function(f)
        return array_has(sub_exts, file_ext(f):lower())
    end)
    if #subs == 0 then return end

    local sorted_subs = {}
    for i = 1, #subs do sorted_subs[i] = subs[i] end
    table.sort(sorted_subs)

    if config.auto_select_first_matching_sub then
        table.sort(subs, function(a, b) return a > b end)
    else
        table.sort(subs)
    end

    for _, sub in ipairs(subs) do
        if episode_number(sub, sorted_subs) == episode
           and not is_sub_already_loaded(sub) then
            mp.commandv("sub-add", dir .. sub)
            msg.info("Added subtitle: " .. sub)
        end
    end
end

mp.add_hook("on_preloaded", 50, load_subs)
