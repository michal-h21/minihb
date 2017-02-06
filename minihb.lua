local minihb = {}

local bidi = require "bidi"
local harfbuzz = require "harfbuzz"
local fontbase = require "fontbase"

local local_par_id = node.id "local_par"
local glyph_id = node.id "glyph"
local dir_id = node.id "dir"
local glue_id = node.id "glue"

local utfchar = unicode.utf8.char
local function uchar(char)
  return (char < 0x10FFFF) and utfchar(char) or " "
end

local usedfonts = {}

local whitespace = {
  [0x0009] = true,
  [0x000A] = true,
  [0x000B] = true,
  [0x000C] = true,
  [0x000D] = true,
  [0x0020] = true,
  [0x0085] = true,
  [0x00A0] = true,
  [0x1680] = true,
  [0x2000] = true,
  [0x2001] = true,
  [0x2002] = true,
  [0x2003] = true,
  [0x2004] = true,
  [0x2005] = true,
  [0x2006] = true,
  [0x2007] = true,
  [0x2008] = true,
  [0x2009] = true,
  [0x200A] = true,
  [0x2028] = true,
  [0x2029] = true,
  [0x202F] = true,
  [0x205F] = true,
  [0x3000] = true
}


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
  local hb_font = fontbase.face(fontid)
  if hb_font then
    local buf = harfbuzz.Buffer.new()
    local fontopt = fontbase.get_font(fontid)
    local features = fontbase.features(fontid)
    print("fontide+face", fontid, hb_font, fontopt.filename, lang, script, textdir, features)
    local reordered = bidi.get_visual_reordering(new, textdir)
    local xxx= {}
    for _, c in ipairs(reordered) do xxx[#xxx+1] = utfchar(c) end
    print(table.concat(xxx))
    buf:set_cluster_level(harfbuzz.Buffer.HB_BUFFER_CLUSTER_LEVEL_CHARACTERS)
    buf:add_codepoints(reordered)
    if textdir == "rtl" then
      buf:reverse()
    end
    harfbuzz.shape(hb_font, buf, { direction =  textdir, script = script, language = lang, features = features})
    -- harfbuzz.shape(hb_font, buf, { direction =  textdir, script = script, language = lang, features="+liga"})
    if textdir == "rtl" then
      buf:reverse()
    end
    -- buf:reverse()

    -- Create nodelist
    local glyphs = buf:get_glyph_infos_and_positions()
    return glyphs, fontopt
  end
  return nil
end

local function make_nodes(result, sourcetable,  fontoptions)
  local fontoptions = fontoptions or {}
  local result = result or {}
  local nodetable = {}
  local lastfont
  for _, v in ipairs(result) do
    -- character from backmap is sometimes too big for unicode.utf8.char
    -- it is because it is often PUA
    -- print("hf",v.name) -- , utfchar(fontoptions.backmap[v.codepoint]))
    local n
    -- clusters are counted from 0, lua tables from 1
    local cluster = v.cluster + 1
    local nodeoptions =  sourcetable[cluster] or {}
    local fontid = nodeoptions.font or lastfont or font.current()
    -- the font backmap needs utf8 character, not just codepoint
    -- local shapedglyph = utfchar(v.codepoint)
    local char =  fontbase.unimap(fontid, v.codepoint) or 32 --fontoptions.backmap[v.codepoint]
    local fontdata = fontbase.get_font(fontid) or {}
    local resources = fontdata.descriptions or {}
    print("wtf",v.codepoint, char, uchar(char), (resources[char] or {}).name , whitespace[char])
    -- local char =  fontoptions.backmap[v.codepoint]
    if whitespace[char] then
      -- local n = sourcetable[cluster].node
      n = node.new("glue", 13)
      print("space",fontdata.space, fontdata.space_shrink, fontdata.space_stretch)
      node.setglue(n, fontdata.space, fontdata.space_shrink, fontdata.space_stretch)
      table.insert(nodetable, node.copy(n))
    else
      n = node.new("glyph")
      -- local n = sourcetable[cluster].node
      --n.font = fontid
      --n.lang = language
      -- set node properties
      -- print("cluster", cluster, nodeoptions.lang, nodeoptions.font, nodeoptions.subtype, shapedglyph, char,v.codepoint, "@")
      n.uchyph = 1
      n.left = tex.lefthyphenmin
      n.right = tex.righthyphenmin
      n.font = fontid
      n.lang = nodeoptions.lang or tex.language
      -- to enable the call to lang.hyphnate()
      n.subtype = 1
      -- for _,j in ipairs {"font", "lang", "subtype"} do
        -- n[j] = nodeoptions[j]
      -- end
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
      nodetable[#nodetable+1] = n-- node.copy(n)
      lastfont = nodeoptions.font
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
  local language = fontinfo.language or "dflt"
  local script = fontinfo.script or "dflt"
  local shaped, fontopt = shape(text, language, script,  direction)
  print("shaped", shaped, direction)
  local newnodes = make_nodes(shaped, text, fontopt)
  if #newnodes > 0 then
    local newpar = node.new("local_par")
    -- print("realdirection", realdirection)
    newpar.dir = realdirection
    -- node.write(newpar)
    local penalty = node.new("penalty", 0)
    penalty.penalty = 10000
    local parfillskip = node.new("glue", 14)
    parfillskip.stretch = 2^16
    parfillskip.stretch_order = 2
    local indent = node.new("hlist",3)
    indent.dir = "TRT"
    indent.width = tex.parindent
    table.insert(newnodes, penalty)
    table.insert(newnodes, parfillskip)
    table.insert(newnodes, indent)
    for k,v in ipairs(newnodes) do 
      -- node.write(v)
      -- last.next = v
      -- last = v
      node.insert_after(newpar, node.tail(newpar), v)
      -- print(v.id, v.char, v.font, v.lang)
    end
    -- node.write(penalty)
    -- node.write(parfillskip)
    -- last.next = penalty
    -- penalty.next = parfillskip
    -- node.slide(newpar)
    lang.hyphenate(newpar)
    for n in node.traverse(newpar) do
      print("nodetable",n.id, n.char, uchar(n.char or 32), n.font, n.lang)
    end
    return newpar
  else
    return nodelist
  end
end
return minihb
