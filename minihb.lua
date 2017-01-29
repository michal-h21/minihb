local minihb = {}

local bidi = require "bidi"
local harfbuzz = require "harfbuzz"
local fontbase = require "fontbase"

local local_par_id = node.id "local_par"
local glyph_id = node.id "glyph"
local dir_id = node.id "dir"
local glue_id = node.id "glue"

local utfchar = unicode.utf8.char

local usedfonts = {}


local function shape(text, lang, script, direction)
  local function get_fontid (pos)
    if pos <= #text then
      local currfont = text[pos].font
      if currfont then 
        return currfont
      end
      return get_fontid(pos+1)
    end
    return nil
  end
  local new = {}
  local fontid = get_fontid(1)
  if not fontid then 
    return nil
  end
  local textdir = (direction == 1) and "rtl" or "ltr"
  for _, x in ipairs(text) do
    new[#new+1] = x.char
    -- just use last used font
    -- fontid = x.font or font
  end
  local buf = harfbuzz.Buffer.new()
  local hb_font = fontbase.face(fontid)
  local fontopt = fontbase.get_font(fontid)
  print("fontide+face", fontid, hb_font, fontopt.filename, lang, script)
  if hb_font then
    local reordered = bidi.get_visual_reordering(new, textdir)
    buf:set_cluster_level(harfbuzz.Buffer.HB_BUFFER_CLUSTER_LEVEL_CHARACTERS)
    buf:add_codepoints(reordered)
    buf:reverse()
    harfbuzz.shape(hb_font, buf, { direction =  textdir, script = script, language = lang})
    buf:reverse()

    -- Create nodelist
    local glyphs = buf:get_glyph_infos_and_positions()
    print("********************")
    for k,v in ipairs(glyphs) do
      for x,y in pairs(v) do
        -- print(x,y)
      end
    end
    return glyphs, fontopt
  end
  return nil
end

local function make_nodes(result, sourcetable,  fontoptions)
  local fontoptions = fontoptions or {}
  local result = result or {}
  local nodetable = {}
  for _, v in ipairs(result) do
    -- character from backmap is sometimes too big for unicode.utf8.char
    -- it is because it is often PUA
    -- print("hf",v.name) -- , utfchar(fontoptions.backmap[v.codepoint]))
    local n
    -- clusters are counted from 0, lua tables from 1
    local cluster = v.cluster + 1
    local nodeoptions = sourcetable[cluster] or {}
    local fontid = nodeoptions.font
    -- the font backmap needs utf8 character, not just codepoint
    -- local shapedglyph = utfchar(v.codepoint)
    local char =  fontbase.unimap(fontid, v.codepoint) --fontoptions.backmap[v.codepoint]
    -- local char =  fontoptions.backmap[v.codepoint]
    if char == 32 then
      local n = sourcetable[cluster].node
      table.insert(nodetable, node.copy(n))
    else
      n = node.new("glyph")
      --n.font = fontid
      --n.lang = language
      -- set node properties
      print("cluster", cluster, nodeoptions.lang, nodeoptions.font, nodeoptions.subtype, shapedglyph, char,v.codepoint, "@")
      for _,j in ipairs {"font", "lang", "subtype"} do
        n[j] = nodeoptions[j]
      end
      n.char = char
      local factor = 1
      if direction == "rtl" or direction == "RTL" then 
        factor = -1 
      end
      local function calc_dim(field)
        return math.floor(v[field] / fontoptions.units_per_em * fontoptions.size)
      end
      -- deal with kerning
      local x_advance = calc_dim "x_advance"
      -- width and height are set from font, we can't change them anyway
      -- n.height = calc_dim "y_advance"
      n.xoffset = (calc_dim "x_offset") * factor
      n.yoffset = calc_dim "y_offset"
      --node.write(n)
      nodetable[#nodetable+1] = node.copy(n)
      -- detect kerning
      -- we must rule out rounding errors first
      -- we skip this for top to bottom direction
      -- nodetable = get_kern(nodetable, n, calc_dim)
    end
  end--]]
  return nodetable
end

function minihb.process_nodes(nodelist, groupcode)
  local text = {}
  local all_nodes = {}
  local direction = 0
  local realdirection = tex.pagedir
  local i = 0
  local lastfontid 
  for n in node.traverse(nodelist) do
    i = i + 1
    if n.id == local_par_id then
      direction = (n.dir == "TRT") and 1 or 0
      realdirection = n.dir
    elseif n.id == glue_id then
      text[#text+1] = {char = 32, type="space", pos = i, node = n}
    elseif n.id == glyph_id then
      text[#text+1] = {char = n.char, type = "glyph", pos = i, font = n.font, lang = n.lang, subtype = 1, node = n}
      -- save the last font id in the node list. we use it for script and language info. of course it is not good
      lastfontid = n.font
    end
  end
  local fontinfo = fontbase.get_font(lastfontid) or {} 
  print("fontinfo", lastfontid, fontinfo)
  local lang = fontinfo.language or "dflt"
  local script = fontinfo.script or "dflt"
  local shaped, fontopt = shape(text, lang, script,  direction)
  local t= {}
  print("shaped", shaped, direction, realdir )
  local newnodes = make_nodes(shaped, text, fontopt)
  if #newnodes > 0 then
    local newpar = node.new("local_par")
    -- print("realdirection", realdirection)
    newpar.dir = realdirection
    node.write(newpar)
    for k,v in ipairs(newnodes) do 
      node.write(v) 
      -- print(v.id, v.char, v.font, v.lang)
    end
    local penalty = node.new("penalty", 0)
    penalty.penalty = 10000
    local parfillskip = node.new("glue", 14)
    parfillskip.stretch = 2^16
    parfillskip.stretch_order = 2
    node.write(penalty)
    node.write(parfillskip)
    return newpar
  else
    return nodelist
  end
end
return minihb
