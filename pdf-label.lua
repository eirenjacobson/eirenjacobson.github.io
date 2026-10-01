-- Run citeproc ourselves so we can (1) turn the url field into a "PDF" link
-- and (2) split the bibliography into articles and reports.
local reports = { ["ref-Jacobson2017TM"]=true, ["ref-Jacobson2016"]=true, ["ref-Jacobson2013"]=true }

local function fix_links(div)
  return div:walk {
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
