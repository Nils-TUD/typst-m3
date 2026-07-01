#import "@preview/cetz:0.5.2"
#import "@local/proxim:0.1.0"

#let _def-stroke = 1pt + black
#let styles = (
  noc-stroke: .5pt + luma(70%),
  core-fill: rgb(220, 220, 220),
  core-stroke: _def-stroke,
  core-label: black,
  mem-fill: rgb(80, 80, 80),
  mem-stroke: _def-stroke,
  mem-label: white,
  tcu-fill: green.lighten(70%),
  tcu-stroke: _def-stroke,
  app-fill: rgb(250, 250, 250),
  app-stroke: _def-stroke,
  kernel-fill: red.lighten(70%),
  unimux-fill: yellow.lighten(70%),
  ep-fill: white,
  ep-stroke: _def-stroke,
  ep-label: black,
  ep-size: .45em,
  xfer-stroke: 2pt + black,
)

/// Return the generated node name for the tile at `(column, row)`.
///
/// The grid helpers use these names as stable CeTZ anchors for later placement.
#let coord(column, row) = "tile-" + str(column) + "-" + str(row)

/// Create a tiled-layout configuration object.
///
/// - `columns`, `rows` -- Number of tiles in the grid.
/// - `width`, `height` -- Outer size of each tile.
/// - `tcu-width`, `tcu-height` -- Default TCU block size inside a tile.
/// - `pad` -- Inner padding used by content helpers.
/// - `gap` -- Spacing between tile sub-elements and between tiles.
#let new(
  columns,
  rows,
  width,
  height,
  tcu-width: 1.5,
  tcu-height: 1,
  pad: .2,
  gap: .3,
) = (
  columns: columns,
  rows: rows,
  width: width,
  height: height,
  tcu-width: tcu-width,
  tcu-height: tcu-height,
  gap: gap,
  pad: pad,
)

/// Draw the tile grid and name every tile position.
///
/// `pos` is the anchor for the top-left tile. The helper creates one / `proxim.node` per grid cell
/// using the names from `coord(...)`, so later calls / such as `tile(...)` can place content into
/// the grid. Named arguments in / `..args` are forwarded to `proxim.node`.
#let grid(self, pos, stroke: none, ..args) = {
  assert(self.columns > 0, message: "Specify at least 1 column")
  assert(self.rows > 0, message: "Specify at least 1 row")

  let args = cetz.util.merge-dictionary((stroke: stroke), args.named())

  let tile(pos, name) = proxim.node(pos, [], width: self.width, height: self.height, name: name, ..args)

  tile(pos, coord(0, 0))
  for c in range(1, self.columns) {
    tile((east-of: (coord(c - 1, 0), self.gap)), coord(c, 0))
  }
  for r in range(1, self.rows) {
    tile((south-of: (coord(0, r - 1), self.gap)), coord(0, r))
    for c in range(1, self.columns) {
      tile((east-of: (coord(c - 1, r), self.gap)), coord(c, r))
    }
  }
}

/// Draw the NoC mesh around the current grid.
///
/// The mesh consists of three parallel horizontal and vertical lines per row and / column. The
/// generated line have names of the form "noc-x<pos>-<no>" and "noc-y<pos>-<no>", where / <pos> is
/// the x/y position in the grid ((0,0) being the top left) and <no> the number of the line / (0, 1,
/// or 2). These names can be used to draw communication channels on the NoC.
#let noc(
  self,
  stroke: styles.noc-stroke,
  gap: .12,
  overhang: .3,
) = {
  for i in (-1, 0, 1) {
    for r in range(0, self.rows) {
      cetz.draw.line(
        (rel: (-overhang, i * gap - self.gap / 2), to: coord(0, r) + ".south-west"),
        (rel: (2 * overhang, i * gap - self.gap / 2), to: coord(self.columns - 1, r) + ".south-east"),
        stroke: stroke,
        name: "noc-y" + str(r) + "-" + str(i + 1),
      )
    }
    for c in range(0, self.columns) {
      cetz.draw.line(
        (rel: (i * gap + self.gap / 2, overhang), to: coord(c, 0) + ".north-east"),
        (rel: (i * gap + self.gap / 2, -overhang * 2), to: coord(c, self.rows - 1) + ".south-east"),
        stroke: stroke,
        name: "noc-x" + str(c) + "-" + str(i + 1),
      )
    }
  }
}

/// Draw a generic compute-unit block.
///
/// By default the CU spans the tile width minus the configured horizontal pad. / `label-stroke`
/// controls the text color. Named arguments in `..args` are / forwarded to `proxim.node`.
#let cu(self, pos, label: [], width: auto, height: auto, label-stroke: black, ..args) = {
  let width = if width == auto { self.width - self.pad * 2 } else { width }
  let height = if height == auto { self.height } else { height }
  let args = cetz.util.merge-dictionary(
    (
      radius: 1pt,
      width: width,
      height: height,
    ),
    args.named(),
  )
  proxim.node(pos, text(fill: label-stroke, label), ..args)
}

/// Draw a default CPU-style compute unit labeled `Core`.
#let cu-core(self, pos, ..args) = {
  let args = cetz.util.merge-dictionary(
    (
      fill: styles.core-fill,
      stroke: styles.core-stroke,
      label-stroke: styles.core-label,
      label: [Core],
    ),
    args.named(),
  )
  cu(self, pos, ..args)
}

/// Draw a memory-style compute unit labeled `DRAM`.
#let cu-mem(self, pos, ..args) = {
  let args = cetz.util.merge-dictionary(
    (
      fill: styles.mem-fill,
      stroke: styles.mem-stroke,
      label-stroke: styles.mem-label,
      label: [DRAM],
    ),
    args.named(),
  )
  cu(self, pos, ..args)
}

/// Draw a RoT-based compute unit layout.
///
/// The block contains a right-hand core area with an inner `RoT` box plus a
/// left-hand `SHA-3` / `SPM` split. When `unimux` is `true`, an additional
/// `UniMux` block is inserted below the RoT label.
#let cu-rot(
  self,
  pos,
  name: none,
  width: auto,
  height: auto,
  fill: styles.core-fill,
  stroke: styles.core-stroke,
  label-stroke: styles.core-label,
  unimux: false,
) = {
  let width = if width == auto { self.width - self.pad * 2 } else { width }
  let height = if height == auto { self.height - self.tcu-height - self.gap * 2 } else { height }
  let side-gap = .15
  let left-width = (width - side-gap) / 2
  let right-width = width - left-width - side-gap
  let inner-gap = .2
  let half-height = (height - inner-gap) / 2

  let def-style = (radius: 1pt, fill: fill, stroke: stroke)
  let mem-style = (radius: 1pt, fill: styles.mem-fill, stroke: styles.mem-stroke)

  cetz.draw.group(name: name, {
    proxim.node(pos, [], width: width, height: height, stroke: none, name: "outer")
    proxim.node((in-east: "outer"), [], width: right-width, height: height, name: "core", ..def-style)
    proxim.node(
      (in-center: ("core", inner-gap)),
      text(fill: label-stroke)[RoT],
      radius: 1pt,
      fill: styles.app-fill,
      stroke: stroke,
      width: right-width - self.pad,
      height: height - self.pad,
      body-pos: if unimux { "north" } else { "center" },
      body-dist: if unimux { .4 } else { 0 },
      name: "rot",
    )
    if unimux {
      proxim.node(
        (in-south: ("rot", inner-gap / 2)),
        text(size: .6em)[UniMux],
        radius: 1pt,
        fill: unimux-fill,
        stroke: stroke,
        width: right-width - inner-gap * 2,
      )
    }
    proxim.node(
      (west-of: ("core", side-gap, "top")),
      text(fill: label-stroke)[SHA-3],
      width: left-width,
      height: half-height,
      name: "sha",
      ..def-style,
    )
    proxim.node(
      (west-of: ("core", side-gap, "bottom")),
      text(fill: styles.mem-label)[SPM],
      width: left-width,
      height: half-height,
      ..mem-style,
    )
  })
}

/// Draw a TCU block.
///
/// Named arguments in `..args` are forwarded to `proxim.node`.
#let tcu(self, pos, label: [TCU], ..args) = {
  let args = cetz.util.merge-dictionary(
    (
      radius: 1pt,
      fill: styles.tcu-fill,
      stroke: styles.tcu-stroke,
      width: self.tcu-width,
      height: self.tcu-height,
    ),
    args.named(),
  )
  proxim.node(pos, text(size: .9em, label), ..args)
}

/// Populate one grid cell with a CU, an optional TCU, and an optional NoC link.
///
/// `pos` is a `(column, row)` pair into the grid created by `grid(...)`. The / resulting content is
/// wrapped in a CeTZ group named `name`, which exposes child / nodes such as `name + ".cu"` and
/// `name + ".tcu"`.
///
/// - `cu-func` -- Function used to draw the compute unit, or `none`.
/// - `tcu-func` -- Function used to draw the TCU, or `none`.
/// - `connect-to-noc` -- Whether to add the vertical CU/TCU link and the TCU's
///   connection to the generated NoC row.
#let tile(
  self,
  pos,
  name,
  cu-func: cu-core,
  tcu-func: tcu,
  connect-to-noc: true,
) = {
  let (column, row) = pos
  let c = coord(column, row)
  cetz.draw.group(name: name, {
    proxim.node(
      (in-center: c),
      [],
      width: self.width,
      height: self.height,
      stroke: none,
      name: "border",
    )
    if cu-func != none {
      cu-func(
        self,
        (in-north: (c, self.gap)),
        height: self.height - self.tcu-height - self.gap * 3,
        name: "cu",
      )
      if tcu-func != none {
        tcu-func(
          self,
          (south-of: ("cu", self.gap, "right")),
          height: self.tcu-height,
          name: "tcu",
        )
        if connect-to-noc {
          proxim.edge("tcu", "cu", routing: "vertical")
          cetz.draw.line("tcu.south", ("tcu.south", "|-", "noc-y" + str(row) + "-1"))
          cetz.draw.circle(("tcu.south", "|-", "noc-y" + str(row) + "-1"), radius: 2pt, fill: black)
        }
      }
    }
  })
}

/// Populate the grid from an array of tile definitions.
///
/// Each entry in `tiles` must be a dictionary with a `name` key and may override / `cu` and `tcu`
/// with drawing functions. Entries are placed row-major from the / top-left corner. Extra named
/// arguments are forwarded to `tile(...)`.
#let tiles(self, tiles, ..args) = {
  assert(type(tiles) == array)
  let (x, y) = (0, 0)
  for t in tiles {
    assert(type(t) == dictionary)
    let (name, cu-func, tcu-func) = (
      t.at("name"),
      t.at("cu", default: cu-core),
      t.at("tcu", default: tcu),
    )
    tile(self, (x, y), name, cu-func: cu-func, tcu-func: tcu-func, ..args)

    x += 1
    if x == self.columns {
      x = 0
      y += 1
    }
  }
}

/// Draw an application box inside `tile`'s CU area.
///
/// `tile` must be the name of a tile group created by `tile(...)` or / `tiles(...)`. Named
/// arguments in `..args` are forwarded to `proxim.node`.
#let app(self, tile, label, ..args) = {
  let c = tile + ".cu"
  let args = cetz.util.merge-dictionary(
    (
      radius: 1pt,
      fill: styles.app-fill,
      stroke: styles.app-stroke,
      width: self.width - self.pad * 4,
      height: self.height - self.tcu-height - self.gap * 3 - self.pad * 2,
    ),
    args.named(),
  )
  proxim.node((in-center: (c, self.pad)), label, ..args)
}

/// Draw a labeled endpoint marker.
///
/// The endpoint is rendered as a small circle at `anchor` with its label centered / on top. Named
/// arguments in `..args` are forwarded to `cetz.draw.circle`.
#let ep(self, anchor, label, name, label-stroke: styles.ep-label, ..args) = {
  let args = cetz.util.merge-dictionary(
    (radius: styles.ep-size, fill: styles.ep-fill, stroke: styles.ep-stroke),
    args.named(),
  )
  cetz.draw.circle(anchor, name: name, ..args)
  cetz.draw.content(anchor, text(size: .6em, fill: label-stroke)[#label])
}

/// Draw a transfer line using the package's default transfer stroke.
///
/// Positional arguments are forwarded as line coordinates; named arguments are / forwarded as
/// `cetz.draw.line` style options.
#let transfer(self, ..args) = {
  let args = arguments(
    ..args.pos(),
    ..cetz.util.merge-dictionary(
      (stroke: styles.xfer-stroke),
      args.named(),
    ),
  )
  cetz.draw.line(..args)
}
