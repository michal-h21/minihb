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
      currentfont.unimap   = realfont.resources.unicodes
      local filename       = realfont.filename
      currentfont.filename = filename
      currentfont.face     = loadface(filename)
      local features       = realfont.specification.features.normal
      currentfont.features = features
      currentfont.language = features.language
      currentfont.script   = features.script
      currentfont.units_per_em = realfont.units_per_em
      -- currentfont.resources = realfont.shared.rawdata.resources
      currentfont.size     = realfont.size
      local mag = currentfont.size / currentfont.units_per_em
      local parameters     = realfont.parameters
      currentfont.space = parameters.space
      currentfont.space_shrink = parameters.space_shrink
      currentfont.space_stretch = parameters.space_stretch
      currentfont.descriptions = realfont.shared.rawdata.descriptions
      -- luaotfload doesn't preserve backmap, at least I can't find it
      -- so we must load the font again
      -- yes, it is not really efficient. at all.
      local f = fontloader.open (filename)
      local fonttable = fontloader.to_table(f)
      fontloader.close(f)
      currentfont.backmap  = fonttable.map.backmap
      currentfont.map      = fonttable.map.map
      currentfont.glyphs   = fonttable.glyphs
      for k,v in pairs(currentfont) do
        print("loaded font", k,v)
      end
      for char,glyph in pairs(currentfont.map) do
        local desc = realfont.characters[char]
        if not desc then
          print("glyphs", char ,glyph)
          local glyph_table = currentfont.glyphs[glyph]
          realfont.characters[char] = {
            index = glyph,
            unicode = char,
            width = glyph_table.width * mag,
            name = glyph_table.name
          }     
          if glyph_table.boundingbox[4] then
            realfont.characters[char].height = glyph_table.boundingbox[4] * mag
          end  
          if glyph_table.boundingbox[2] then
            realfont.characters[char].depth = -glyph_table.boundingbox[2] * mag
          end    
        else
          -- print("glyph", k,v)
          -- for x,y in pairs(desc) do
          --   print(x,y)
          -- end
        end
        -- for x,y in pairs(v) do
        -- print(x,y)
        -- end
      end


    end
    font.setfont(fontid, realfont)
    usedfonts[fontid] = currentfont
  end
  return currentfont
end



function M.unimap(fontid, glyph)
  if not fontid then return nil end
  -- local unimap = getunimap(fontid)
  local currentfont = loadfont(fontid)
  local unimap = currentfont.backmap
  return unimap[glyph]
end

function M.face(fontid)
  if not fontid then return nil end
  local currentfont = loadfont(fontid)
  return currentfont.face
end

function M.features(fontid)
  local t= {}
  local currentfont = loadfont(fontid)
  local features = currentfont.features
  -- we are interested only features which 
  -- are explicitly true at the moment
  for feature,status in pairs(features) do
    if status== true then
      t[#t+1] = feature
    end
  end
  return table.concat(t, ",") .. ","
end


function M.get_font(fontid)
  if not fontid then return nil end
  return loadfont(fontid)
end

return M
