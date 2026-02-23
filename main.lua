local utils = require("mp.utils")
local msg = require("mp.msg")

local sep = package.config:sub(1, 1)
local SUB_EXTS = mp.get_property_native("sub-auto-exts")
local VID_EXTS = mp.get_property_native("video-exts")

local config = {
    auto_select_first_matching_sub = true,
}
require "mp.options".read_options(config)

local function base_dir(path)
    return path:match("(.*" .. sep .. ")")
end

local function file_name(path)
    return path:match(".*" .. sep .. "(.*)")
end

local function file_ext(path)
    return path:match(".*%.(.*)") or ""
end

local function extract_numbers(str)
    local numbers = {}
    str:gsub("%d+", function(num) table.insert(numbers, tonumber(num)) end)
    return numbers
end

local function index_of(array, key)
    for i, key2 in ipairs(array) do
        if key2 == key then
            return i
        end
    end
    return nil
end

local function array_has(array, key)
    return index_of(array, key) ~= nil
end

local function filter_array(array, predicate)
    local new = {}
    for _, key in ipairs(array) do
        if predicate(key) then
            table.insert(new, key)
        end
    end
    return new
end

local function copy_array(array)
    return filter_array(array, function(_) return true end)
end

local function episode_number(file, files)
    files = copy_array(files)
    table.sort(files)
    local current_index = index_of(files, file)

    local episode_for_file_at = function(i)
        local other_file = files[i]
        local numbers = extract_numbers(file)
        local other_numbers = extract_numbers(other_file)
        for n = 1, #numbers do
            if numbers[n] ~= other_numbers[n] then
                return numbers[n]
            end
        end
        return numbers[1]
    end

    for i = current_index + 1, #files do
        local episode = episode_for_file_at(i)
        if episode ~= nil then return episode end
    end
    for i = current_index - 1, 1, -1 do
        local episode = episode_for_file_at(i)
        if episode ~= nil then return episode end
    end

    msg.warn("Couldn't determine episode number for " .. file)
    return nil
end

local function is_sub_file(filename)
    return array_has(SUB_EXTS, file_ext(filename):lower())
end

local function is_video_file(filename)
    return array_has(VID_EXTS, file_ext(filename):lower())
end

local function collect_subs(dir, prefix)
    prefix = prefix or ""
    local results = {}

    local files = utils.readdir(dir, "files")
    if files then
        if prefix ~= "" then
            for _, f in ipairs(files) do
                if is_video_file(f) then
                    return results
                end
            end
        end
        for _, f in ipairs(files) do
            if is_sub_file(f) then
                table.insert(results, {
                    path = dir .. sep .. f,
                    name = prefix .. f,
                })
            end
        end
    end

    local subdirs = utils.readdir(dir, "dirs")
    if subdirs then
        table.sort(subdirs)
        for _, subdir in ipairs(subdirs) do
            local sub_results = collect_subs(dir .. sep .. subdir, prefix .. subdir .. sep)
            for _, entry in ipairs(sub_results) do
                table.insert(results, entry)
            end
        end
    end

    return results
end

local function load_subs()
    local path = mp.get_property("path")
    local dir = base_dir(path)
    local file = file_name(path)

    local all_files = utils.readdir(dir, "files")
    if all_files == nil then return end

    local sub_entries = collect_subs(dir)
    if next(sub_entries) == nil then return end

    local videos = filter_array(all_files, function(f)
        return is_video_file(f)
    end)
    local episode = episode_number(file, videos)
    if episode == nil and #videos > 1 then return end

    local sub_names = {}
    for _, entry in ipairs(sub_entries) do
        table.insert(sub_names, entry.name)
    end
    local ascending_sub_names = copy_array(sub_names)
    table.sort(ascending_sub_names)

    if config.auto_select_first_matching_sub then
        table.sort(sub_entries, function(a, b) return a.name > b.name end)
    else
        table.sort(sub_entries, function(a, b) return a.name < b.name end)
    end

    for _, entry in ipairs(sub_entries) do
        if episode == nil or
           episode_number(entry.name, ascending_sub_names) == episode then
            mp.commandv("sub-add", entry.path)
            print("Added subtitle: " .. entry.name)
        end
    end
end

mp.add_hook('on_preloaded', 50, load_subs)
