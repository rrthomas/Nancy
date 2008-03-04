#! /usr/bin/env lua
prog = {
  name = "nancy",
  banner = "nancy $Revision$ ($Date$)\n" ..
    "(c) 2002-2008 Reuben Thomas (rrt@sc3d.org; http://rrt.sc3d.org/)\n" ..
    "Distributed under the GNU General Public License",
  purpose = "The lazy web site maker",
  usage = "SOURCE DESTINATION TEMPLATE [BRANCH]",
  notes =
    "  SOURCE is the source directory tree\n" ..
    "  DESTINATION is the directory to which the output is written\n" ..
    "  TEMPLATE is the name of the template fragment\n" ..
    "  BRANCH is the sub-directory of SOURCE to process (the default\n" ..
    "    is to process the entire source tree)"
}


require "std"

-- Command-line options
options = {
  Option {{"list-files", "l"}, "list files read (on stderr)"},
}

suffix = ".html" -- suffix to make source directory into destination file

-- Get arguments
getopt.processArgs ()
if #arg < 3 or #arg > 4 then
  getopt.dieWithUsage ()
end

local sourceRoot = arg[1]
if lfs.attributes (sourceRoot, "mode") ~= "directory" then
  die ("`" .. sourceRoot .. "' not found or not a directory")
end
local destRoot = arg[2]
if lfs.attributes (destRoot) and lfs.attributes (destRoot, "mode") ~= "directory" then
  die ("`" .. destRoot .. "' is not a directory")
end
local fragment = arg[3]
local sourceTree = sourceRoot
if arg[4] then
  sourceTree = io.pathConcat (sourceRoot, arg[4])
end

-- Search the current path for a file; if found return its name,
-- if not, return nil and print a warning.
function findFile (path, fragment)
  local page = path
  repeat
    local name = io.pathConcat (path, fragment)
    if lfs.attributes (name) then
      if getopt.opt["list-files"] then
        io.stderr:write (" " .. name)
      end
      return name
    end
    if path == "." then
      warn ("Cannot find fragment `" .. fragment .. "' while building `" .. page .. "'")
      return
    end
    path = io.dirname (path)
  until nil
end


-- Expand commands in some text
function expand (text, root, page)
  macros = {
    page =
      function ()
        return page
      end,
    root =
      function ()
        return (io.pathConcat (unpack (list.rep (#io.pathSplit (page) - 1, {".."}))))
      end,
    include =
      function (fragment)
        local name = findFile (io.pathConcat (root, page), fragment)
        if name then
          local h = io.open (name)
          local contents = h:read ("*a")
          h:close ()
          return contents
        else
          return ""
        end
      end,
    run =
      function (...)
        return io.shell (string.join (" ", {...}))
      end,
  }
  local function doMacros (text)
    local function doMacro (macro, args)
      local arg = {}
      for i in rex.split (args or "", "(?<!\\\\),") do
        table.insert (arg, i)
      end
      if macros[macro] then
        return macros[macro] (unpack (arg))
      end
      local ret = "$" .. string.caps (macro)
      ret = ret .. "{" .. args .. "}"
      return ret
    end
    local reps
    repeat
      text, reps = rex.gsub (text, "\\$([[:lower:]]+){(((?:(?!(?<!\\\\)[{}])).)*?)(?<!\\\\)}", doMacro)
    until reps == 0
    return text
  end
  text = doMacros(text)
  -- Convert $Macro back to $macro
  return (rex.gsub (text, "(?!<\\\\)(?<=\\$)([[:upper:]])(?=[[:lower:]]*{)",
                    function (s)
                      return string.lower (s)
                    end))
end

-- @func find: Scan a file system object and process its elements
--   @param root: root path to scan
--   @param pred: function to apply to each element
--     @param root: as above
--     @param object: relative path from root to object
--   @returns
--     @param flag: true to descend if object is a directory
function find (root, pred)
  local function subfind (path)
    for object in lfs.dir (io.pathConcat (root, path)) do
      if object ~= "." and object ~= ".." and pred (root, io.pathConcat (path, object)) and
        lfs.attributes (io.pathConcat (root, path, object), "mode") == "directory" then
        subfind (io.pathConcat (path, object))
      end
    end
  end
  pred (root, "")
  subfind ("")
end

-- Get source directories and destination files
-- FIXME: Make exclusion easily extensible, and add patterns for
-- common VCSs (use find's --exclude-vcs patterns) and editor backup
-- files &c.
sources = {}
find (sourceTree,
      function (path, object)
        if lfs.attributes (io.pathConcat (path, object), "mode") == "directory" and
          io.basename (object) ~= ".svn" then
          table.insert (sources, object)
          return true
        end
      end)
sourceSet = set.new (sources)

-- Sort the sources for the "is leaf" check
table.sort (sources)

-- Process source directories
for i, dir in ipairs (sources) do
  local dest = io.pathConcat (destRoot, dir)
  -- Only leaf directories correspond to pages; the sources are sorted
  -- alphabetically, so a directory is not a leaf if and only if it is
  -- either the last directory, or it is not a prefix of the next one
  if dir ~= "" and (i == #sources or string.sub (sources[i + 1], 1, #dir + 1) ~= dir .. "/") then
    -- Process one file
    if getopt.opt["list-files"] then
      io.stderr:write (dir .. ":\n")
    end
    h = io.open (dest .. suffix, "w")
    if h then
      h:write (expand ("$include{" .. fragment .. "}", sourceTree, dir))
      h:close ()
    else
      die ("Could not write to `" .. dest .. "'")
    end
    if getopt.opt["list-files"] then
      io.stderr:write ("\n")
    end
  else -- non-leaf directory
    -- FIXME: If directory is called `index', complain
    -- Make directory
    lfs.mkdir (dest)

    -- Check we have an index subdirectory
    if not sourceSet[io.pathConcat (dir, "index")] then
      warn ("`" .. io.pathConcat (sourceTree, dir) .. "' has no `index' subdirectory")
    end
  end
end
