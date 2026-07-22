LAZY_PLUGIN_SPEC = {}

-- Modulo-plugin in file singolo (`user/foo.lua`): direttiva `import` di lazy
-- (lazy fa il require al momento giusto).
function spec(item)
  table.insert(LAZY_PLUGIN_SPEC, { import = item })
end

-- Modulo-plugin in CARTELLA (`user/foo/init.lua`): con `import`, lazy scansionerebbe
-- l'intero namespace via lsmod tirando dentro anche i sottomoduli NON-spec
-- (es. `foo/health.lua`, che ritorna { check = fn }). Quindi requiriamo il solo
-- init.lua e ne inseriamo direttamente la spec restituita.
function spec_dir(item)
  table.insert(LAZY_PLUGIN_SPEC, require(item))
end
