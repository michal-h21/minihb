# Luaotfload + LuaBidi + HarfBuzz example. 

Luaotfload is used for font loading,
HarfBuzz for text shaping, Bidi for text direction handling. It is really
primitive, even kerning doesn't work and only one font in each paragraph is
supported. See [LuaTeX-HardBuzz](https://github.com/tatzetwerk/luatex-harfbuzz)
for much more mature project. The only interesting thing about this is the bidi
and Luaotfload support.

