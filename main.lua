local utils = require("mp.utils")
local msg = require("mp.msg")

local sep = package.config:sub(1, 1)
local sub_exts = mp.get_property_native("sub-auto-exts")

local config = {
    auto_select_first_matching_sub = true,  -- if false, auto select last
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
    for i, key in ipairs(array) do
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
    -- Try to find the earliest number that changes among files. With files =
    --     Non Non Biyori.S02E02.CC.ja.srt
    --     Non Non Biyori.S02E02.CC.ja_original.srt
    --     Non Non Biyori.S02E03.CC.ja.srt
    --     ...
    -- if file = the first, return 02. For second, 02 too. For third, 03.


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

local function load_subs()
    local path = mp.get_property("path")
    local dir = base_dir(path)
    local file = file_name(path)
    local ext = file_ext(path):lower()

    local files = utils.readdir(dir, "files")
    local videos = filter_array(files, function(file)
        return file_ext(file):lower() == ext
    end)
    local episode = episode_number(file, videos)
    if episode == nil then return end

    local subs = filter_array(files, function(file)
        return array_has(sub_exts, file_ext(file):lower())
    end)
    local ascending_subs = copy_array(subs)
    table.sort(ascending_subs)

    if config.auto_select_first_matching_sub then
        table.sort(subs, function(a, b) return a > b end)  -- reverse
    else
        table.sort(subs)
    end

    for _, sub in ipairs(subs) do
        if episode_number(sub, ascending_subs) == episode then
            mp.commandv("sub-add", dir .. sep .. sub)
            print("Added subtitle: " .. sub)
        end
    end
end

mp.add_hook('on_preloaded', 50, load_subs)
