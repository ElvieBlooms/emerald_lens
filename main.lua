-- Emerald Lens
-- Gen 3 player sprites, using the same character folder format as
-- Crystal Lens. Mods are sandboxed to their own files, so each keeps its
-- own copy; one folder can carry Game Boy art and gen3/ art and be copied
-- into both. -Elvie
return function(mod)
  require("mods.emerald_lens.lens").init(mod)
end
