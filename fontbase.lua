local M = {}
local harfbuzz = require "harfbuzz"


local usedfonts = {}


local function loadface(filename)
  -- local f = io.open(filename, "r")
  -- local contents = f:read("*all")
  -- print("loadfont", filename, string.len(contents))
  -- f:close()
  local face = harfbuzz.Face.new(filename)
  local hb_font = harfbuzz.Font.new(face)
  return hb_font
end

local function loadfont(fontid)
  local currentfont = usedfonts[fontid]
  if not currentfont then
    local realfont = font.getfont(fontid) or font.fonts[fontid] -- font.getfont is function provided by luaotfload
    currentfont = {}
    local format = realfont.format
    print("font format", format, realfont.name)
    currentfont.format = format
    if format == "truetype" or format == "opentype" then
      -- for k, v in pairs(realfont) do
        -- print("xxx", k,v)
      -- end
      currentfont.language = realfont.specification.language
      currentfont.script   = realfont.specification.script
      currentfont.unimap   = realfont.resources.unicodes
      local filename       = realfont.filename 
      currentfont.filename = filename
      currentfont.face     = loadface(filename) 
      currentfont.features = realfont.specification.features
      currentfont.units_per_em = realfont.units_per_em
      currentfont.size     = realfont.size
      currentfont.descriptions = realfont.shared.rawdata.descriptions
      -- luaotfload doesn't preserve backmap, at least I can't find it
      -- so we must load the font again
      -- yes, it is not really efficient. at all.
      local f = fontloader.open (filename)
      local fonttable = fontloader.to_table(f)
      fontloader.close(f)
      currentfont.backmap  = fonttable.map.backmap
      for k,v in pairs(currentfont) do
        print("loaded font", k,v)
      end

    end
    usedfonts[fontid] = currentfont
  end
  return currentfont
end

local function getunimap(fontid)
  -- 
  local currentfont = loadfont(fontid)
  local unimap = currentfont.unimap or {}
  return unimap
end
  

function M.unimap(fontid, glyph)
  if not fontid then return nil end
  -- local unimap = getunimap(fontid)
  local currentfont = loadfont(fontid)
  local unimap = currentfont.backmap
  local descriptions = currentfont.descriptions 
  local desc = descriptions[glyph] or {}
  print("unimap", fontid, glyph, unimap,  unimap[glyph], desc.name, desc.unicode, currentfont.backmap[glyph]  )
  return unimap[glyph]
end

function M.face(fontid)
  if not fontid then return nil end
  local currentfont = loadfont(fontid)
  return currentfont.face
end

function M.get_font(fontid)
  if not fontid then return nil end
  return loadfont(fontid)
end

return M
