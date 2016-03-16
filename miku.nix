{ mkDerivation, base, bytestring, containers
, mtl, stdenv

, nemesis
, pretty-show
, stylish-haskell
, happy
, hasktags
, foreign-store
, lens

, moe
, wai
, wai-extra
, warp
, http-types

, pkgs

}:
mkDerivation {
  pname = "miku";
  version = "2016.3.16";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring containers
    mtl

    happy
    stylish-haskell
    happy

    nemesis
    pretty-show
    foreign-store
    lens

    moe
    wai
    wai-extra
    warp
    http-types
  ] ++
  (with pkgs;
    [
      entr
    ]
  );

  homepage = "https://github.com/nfjinjing/miku";
  description = "A minimum web dev DSL in Haskell";
  license = stdenv.lib.licenses.bsd3;
}
