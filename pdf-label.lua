-- Run citeproc ourselves so we can (1) turn the url field into a "PDF" link
-- and (2) split the bibliography into articles and reports.
local reports = { ["ref-Jacobson2017TM"]=true, ["ref-Jacobson2016"]=true, ["ref-Jacobson2013"]=true }

-- Bold "E. K. Jacobson" / "Jacobson, E. K." (trailing punctuation stays unbolded).
local function split_punct(str)
  local core, punct = str:match("^(.-)([,.;:]*)$")
  return core, punct
end

local function bold_name(inlines)
  local out, i, n = {}, 1, #inlines
  local function txt(k) return inlines[k] and inlines[k].t == "Str" and inlines[k].text or nil end
  local function sp(k) return inlines[k] and (inlines[k].t == "Space" or inlines[k].t == "SoftBreak") end
  while i <= n do
    local matched = false
    -- "E. K. Jacobson"
    if txt(i) == "E." and sp(i+1) and txt(i+2) == "K." and sp(i+3) then
      local core, punct = split_punct(txt(i+4) or "")
      if core == "Jacobson" then
        out[#out+1] = pandoc.Strong({ pandoc.Str("E."), pandoc.Space(), pandoc.Str("K."), pandoc.Space(), pandoc.Str("Jacobson") })
        if punct ~= "" then out[#out+1] = pandoc.Str(punct) end
        i, matched = i + 5, true
      end
    -- "Jacobson, E. K."
    elseif txt(i) == "Jacobson," and sp(i+1) and txt(i+2) == "E." and sp(i+3) then
      local rest = (txt(i+4) or ""):match("^K%.(.*)$")
      if rest then
        out[#out+1] = pandoc.Strong({ pandoc.Str("Jacobson,"), pandoc.Space(), pandoc.Str("E."), pandoc.Space(), pandoc.Str("K.") })
        if rest ~= "" then out[#out+1] = pandoc.Str(rest) end
        i, matched = i + 5, true
      end
    end
    if not matched then out[#out+1] = inlines[i]; i = i + 1 end
  end
  return out
end

local function fix_links(div)
  return div:walk {
    Inlines = bold_name,
    Link = function(el)
      if el.target:match("%.pdf$") then
        el.target = el.target:gsub("^https?:///?", "")
        el.content = pandoc.Str("PDF")
        return el
      end
    end
  }
end

function Pandoc(doc)
  doc = pandoc.utils.citeproc(doc)
  doc.meta.bibliography, doc.meta.nocite, doc.meta.csl = nil, nil, nil
  local out = {}
  for _, b in ipairs(doc.blocks) do
    if b.t == "Div" and b.identifier == "refs" then
      b = fix_links(b)
      local arts, reps = {}, {}
      for _, e in ipairs(b.content) do
        if reports[e.identifier] then reps[#reps+1] = e else arts[#arts+1] = e end
      end
      out[#out+1] = pandoc.Header(2, "Peer-reviewed articles", pandoc.Attr("articles"))
      out[#out+1] = pandoc.Div(arts, pandoc.Attr("refs", {"references", "csl-bib-body"}))
      out[#out+1] = pandoc.Header(2, "Reports", pandoc.Attr("reports"))
      out[#out+1] = pandoc.Div(reps, pandoc.Attr("refs-reports", {"references", "csl-bib-body"}))
    else
      out[#out+1] = b
    end
  end
  doc.blocks = out
  return doc
end
