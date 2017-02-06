# Luaotfload + LuaBidi + HarfBuzz example. 

Luaotfload is used for font loading,
HarfBuzz for text shaping, Bidi for text direction handling. It is really
primitive, only one used font in each paragraph is
supported. See [LuaTeX-HardBuzz](https://github.com/tatzetwerk/luatex-harfbuzz)
for much more advanced alternative. The only interesting thing about this is the bidi
and Luaotfload support.

## Example


    \documentclass{article}
    \usepackage{luaotfload}
    \usepackage{minihb}
    \usepackage[czech]{babel}
    
    % we must turn off some features automatically added by luaotfload
    \font\sample={Amiri:script=arab;language=ara;-init,-medi,-fina} at 18pt
    
    % but with Scheherazade these features doesn't matter
    \font\arab={Scheherazade:language=ara;script=arab;} at 18pt
    
    \font\libertine={Linux Libertine O:+onum;+frac} at 18pt
    \begin{document}
    
    \sample
    
    
    \pardir TRT
    % \textdir TRT
    
    
    براغ (بالتشيكية: Praha, Česká republika، براها) هي عاصمة 
    
    طالع أيضًا: إبراهيم بن يعقوب
    
    
    
    \arab
    
    طالع أيضًا: إبراهيم بن يعقوب
    
    \libertine
    
    Latin text in RTL paragraph. The region was settled grafika. VLTAVA
    
    
    
    \pardir TLT
    \arab
    طالع أيضًا: إبراهيم بن يعقوب
    
    
    
    \end{document}


    
![Resulting document](http://i.imgur.com/rMQnfb8.png)

As you can see, there are several issues:

- We must disable some features for Amiri, because they seem to break the shaping. These features are added by Luaotfload by default.
- Some glyphs in Scheherazade example have wrong position.
- LTR text in RTL paragraph and vice versa have some issues.
