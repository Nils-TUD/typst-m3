#import "tiled.typ" as tiled

#let m3name(prefix, suffix) = {
  [#prefix#super(typographic: false, size: .75em, baseline: -.2em)[#text[3]]#suffix]
}

#let m3 = m3name(smallcaps[M], [])
#let m3fs = m3name(smallcaps[M], [FS])
#let teem3 = m3name(smallcaps[TEEM], [])
#let m3x = m3name(smallcaps[M], [x])
#let m3v = m3name(smallcaps[M], [v])
