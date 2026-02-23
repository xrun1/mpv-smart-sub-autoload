local utils = require("mp.utils")
local msg = require("mp.msg")

local function to_set(array)
    local set = {}
    for _, v in ipairs(array) do
        set[v] = true
    end
    return set
end

local SUB_EXT_SET = to_set(mp.get_property_native("sub-auto-exts") or {})
local VID_EXT_SET = to_set(mp.get_property_native("video-exts") or {})

local config = {
    auto_select_first_matching_sub = true,
    max_depth = 3,
}
require("mp.options").read_options(config)

local function base_dir(path)
    local dir, _ = utils.split_path(path)
    return dir
end

local function file_name(path)
    local _, name = utils.split_path(path)
    return name
end

local function file_ext(path)
    return path:match("%.([^%.]+)$") or ""
end

local numbers_cache = {}
local function extract_numbers(str)
    if numbers_cache[str] then return numbers_cache[str] end
    
    local numbers = {}
    str:gsub("%d+", function(num) table.insert(numbers, tonumber(num)) end)
    
    numbers_cache[str] = numbers
    return numbers
end

local function index_of(array, key)
    for i, v in ipairs(array) do
        if v == key then return i end
    end
    return nil
end

local function filter_array(array, predicate)
    local new = {}
    for _, v in ipairs(array) do
        if predicate(v) then
            table.insert(new, v)
        end
    end
    return new
end

local function sorted_copy(array)
    local copy = {unpack(array)}
    table.sort(copy)
    return copy
end

local function is_sub_file(filename)
    return SUB_EXT_SET[file_ext(filename):lower()]
end

local function is_video_file(filename)
    return VID_EXT_SET[file_ext(filename):lower()]
end

local function episode_number(file, sorted_files)
    local idx = index_of(sorted_files, file)
    if not idx then
        msg.warn("Couldn't determine episode number for " .. file)
        return nil
    end

    local numbers = extract_numbers(file)

    local function compare(i)
        local other_numbers = extract_numbers(sorted_files[i])
        for n = 1, #numbers do
            if numbers[n] ~= other_numbers[n] then
                return numbers[n]
            end
        end
        return numbers[1]
    end

    for i = idx + 1, #sorted_files do
        local ep = compare(i)
        if ep then return ep end
    end
    for i = idx - 1, 1, -1 do
        local ep = compare(i)
        if ep then return ep end
    end

    msg.warn("Couldn't determine episode number for " .. file)
    return nil
end

local function collect_subs(dir, prefix, depth)
    prefix = prefix or ""
    depth = depth or 0
    local results = {}

    local files = utils.readdir(dir, "files")
    if files then
        for _, f in ipairs(files) do
            if is_video_file(f) then
                if depth > 0 then return {} end
            elseif is_sub_file(f) then
                table.insert(results, {
                    path = utils.join_path(dir, f),
                    name = prefix .. f,
                })
            end
        end
    end

    if depth < config.max_depth then
        local subdirs = utils.readdir(dir, "dirs")
        if subdirs then
            table.sort(subdirs)
            for _, subdir in ipairs(subdirs) do
                local next_dir = utils.join_path(dir, subdir)
                local sub_results = collect_subs(next_dir, prefix .. subdir .. "/", depth + 1)
                for _, entry in ipairs(sub_results) do
                    table.insert(results, entry)
                end
            end
        end
    end

    return results
end

local function load_subs()
    local path = mp.get_property("path")
    
    if not path or path:find("://") then return end

    local dir = base_dir(path)
    local file = file_name(path)

    local all_files = utils.readdir(dir, "files")
    if not all_files then return end

    local sub_entries = collect_subs(dir)
    if not next(sub_entries) then return end

    local videos = filter_array(all_files, is_video_file)
    local sorted_videos = sorted_copy(videos)
    local episode = episode_number(file, sorted_videos)
    if not episode and #videos > 1 then return end

    local sub_names = {}
    for i, entry in ipairs(sub_entries) do
        sub_names[i] = entry.name
    end
    local sorted_sub_names = sorted_copy(sub_names)

    if config.auto_select_first_matching_sub then
        table.sort(sub_entries, function(a, b) return a.name > b.name end)
    else
        table.sort(sub_entries, function(a, b) return a.name < b.name end)
    end

    for _, entry in ipairs(sub_entries) do
        if not episode or
           episode_number(entry.name, sorted_sub_names) == episode then
            mp.commandv("sub-add", entry.path)
            msg.info("Added subtitle: " .. entry.name)
        end
    end
end

mp.add_hook('on_preloaded', 50, load_subs)
