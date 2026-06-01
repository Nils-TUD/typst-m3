#import "@preview/cetz:0.5.2"
#import "@local/proxim:0.1.0"

#let defaults() = (
  noc_width: 8,
  noc_height: 8,
  noc_gap: .2,
  noc_stroke: black.lighten(80%),
  core_size: 3,
  core_stroke: black,
  core_fill: rgb(220, 220, 220),
  core_label: black,
  mem_stroke: black,
  mem_fill: rgb(80, 80, 80),
  mem_label: white,
  sw_fill: rgb(250, 250, 250),
  mux_fill: yellow.lighten(70%),
  tcu_connect: true,
  tcu_width: 2.5,
  tcu_height: 1.5,
  tcu_gap: .5,
  tcu_stroke: 1pt + black,
  tcu_fill: green.lighten(70%),
  tcu_xfer: 2pt + black,
  tcu_label_pos: "center",
  tcu_label_dist: 0pt,
  kernel_fill: red.lighten(70%),
  ep_fill: white,
  ep_stroke: .5pt + black,
  ep_label: black,
  ep_size: 6pt,
)

#let tiles(o, cols, cells) = {
  import cetz.draw: *
  let overhang = .6
  let x = 0
  let y = calc.trunc(cells.len() / cols) - 1
  for c in cells {
    set-origin((x * o.noc_width, y * o.noc_height))

    for i in (-1, 0, 1) {
      line(
        (o.noc_width / 2 + o.noc_gap * i, -o.noc_height / 2 - overhang),
        (o.noc_width / 2 + o.noc_gap * i, o.noc_height / 2 - overhang),
        stroke: o.noc_stroke,
        name: "noc-x" + str(x) + "-y" + str(y) + "-" + str(i + 1),
      )
      line(
        (-o.noc_width / 2 + overhang, -o.noc_height / 2 + o.noc_gap * i),
        (o.noc_width / 2 + overhang, -o.noc_height / 2 + o.noc_gap * i),
        stroke: o.noc_stroke,
        name: "noc-y" + str(y) + "-x" + str(x) + "-" + str(i + 1),
      )
    }

    if c != none {
      // content((0, 0), [#type(c)])
      assert(type(c) == array)
      assert(c.len() == 2)
      assert(type(c.at(0)) == str)

      let (c_name, c_body) = c
      if type(c_body) == dictionary {
        group(name: c_name, c_body.at("body"))
        if o.tcu_connect {
          line(c_name + ".tcu.south", (c_name + ".tcu.south", "|-", "noc-y" + str(y) + "-x0-1"))
          circle((c_name + ".tcu.south", "|-", "noc-y" + str(y) + "-x0-1"), radius: 2pt, fill: black)
        }
      } else {
        group(name: c_name, c_body)
      }
    }

    set-origin((-x * o.noc_width, -y * o.noc_height))

    x += 1
    if x >= cols {
      y -= 1
      x = 0
    }
  }
}

#let block(..args) = proxim.node(radius: 1pt, ..args)

#let tile(o, cu, tcu: [TCU]) = {
  import cetz.draw: *

  // use a dictionary here to distinguish normal tiles (with TCUs) from other content. we need that
  // in tiles above to attach each TCU to the NoC.
  (
    body: {
      group(name: "cu", cu)
      block(
        (south-of: ("cu", o.tcu_gap, "right")),
        text(size: .8em)[#tcu],
        body-pos: o.tcu_label_pos,
        body-dist: o.tcu_label_dist,
        width: o.tcu_width,
        height: o.tcu_height,
        stroke: o.tcu_stroke,
        fill: o.tcu_fill,
        name: "tcu",
      )
      if o.tcu_connect {
        line("tcu", ("tcu", "|-", "cu.south"))
      }
    },
  )
}

#let cu_core(o, label) = {
  block(
    (-o.core_size, -o.core_size + (o.tcu_height + o.tcu_gap)),
    text(fill: o.core_label)[#label],
    width: o.core_size * 2,
    height: o.core_size * 2 - (o.tcu_height + o.tcu_gap),
    name: "core",
    stroke: o.core_stroke,
    fill: o.core_fill,
  )
}

#let cu_dram(o, label: [DRAM]) = cu_core(
  o + (core_fill: o.mem_fill, core_stroke: o.mem_stroke, core_label: o.mem_label),
  label,
)

#let cu_rot(o, unimux: false) = {
  let gap = .1
  let width = o.core_size - gap
  let height = o.core_size * 2 - (o.tcu_height + o.tcu_gap)
  block(
    (gap, -o.core_size + (o.tcu_height + o.tcu_gap)),
    text(fill: o.core_label)[#label],
    width: width,
    height: height,
    name: "core",
    fill: o.core_fill,
  )

  let inner-gap = .2
  block(
    (in-center: ("core", inner-gap)),
    text(fill: o.core_label)[RoT],
    width: width - inner-gap * 2,
    height: height - inner-gap * 2,
    body-pos: if unimux { "north" } else { "center" },
    body-dist: if unimux { height / 6 } else { 0 },
    name: "rot",
    fill: o.sw_fill,
  )

  if unimux {
    block(
      (in-south: ("rot", .2)),
      text(size: .55em)[UniMux],
      fill: o.mux_fill,
      width: width - inner-gap * 4,
      height: 1,
    )
  }

  block(
    (west-of: ("core", inner-gap, "top")),
    text(fill: o.core_label)[SHA-3],
    inset: 0pt,
    width: width,
    height: (height - inner-gap) / 2,
    name: "sha",
    fill: o.core_fill,
  )

  block(
    (west-of: ("core", inner-gap, "bottom")),
    text(fill: o.mem_label)[SPM],
    width: width,
    height: (height - inner-gap) / 2,
    fill: o.mem_fill,
    radius: 1pt,
  )
}

#let cu_sw(o, label) = {
  cu_core(o, [])
  o.core_size -= .3
  o.core_fill = o.sw_fill
  cu_core(o, label)
}

#let cu_sw_tee(o, label: [TEE], lib: [UniMux]) = {
  cu_core(o, [])
  let gap = .3
  o.core_size -= gap
  block(
    (in-south: ("core", gap)),
    label,
    body-pos: "north",
    body-dist: gap,
    fill: o.sw_fill,
    width: o.core_size * 2,
    height: o.core_size + gap * 2,
    name: "tee",
  )

  o.core_size -= gap
  block(
    (in-south: ("tee", gap)),
    lib,
    width: o.core_size * 2,
    height: o.core_size / 2,
    fill: o.mux_fill,
  )
}

#let cu_sw_mux(o, apps: ([App],), mux: [TileMux]) = {
  cu_core(o, [])
  let gap = .3
  o.core_size -= gap
  block(
    (in-south: ("core", gap)),
    [TileMux],
    fill: o.mux_fill,
    width: o.core_size * 2,
    height: (o.core_size + gap * 2 - .1) / 2,
  )

  assert(apps.len() == 1 or apps.len() == 2)
  for (i, a) in apps.enumerate() {
    let (pos, width) = if apps.len() == 1 {
      ((in-north: ("core", gap)), o.core_size * 2)
    } else if i == 0 {
      ((in-north-west: ("core", gap)), o.core_size - gap / 2)
    } else {
      ((in-north-east: ("core", gap)), o.core_size - gap / 2)
    }
    block(
      pos,
      a,
      width: width,
      height: (o.core_size + gap * 2 - .1) / 2,
      fill: o.sw_fill,
    )
  }
}

#let ep(o, anchor, label, name) = {
  cetz.draw.circle(anchor, radius: o.ep_size, fill: o.ep_fill, stroke: o.ep_stroke, name: name)
  cetz.draw.content(anchor, text(size: .6em, fill: o.ep_label)[#label])
}

#let tcu-xfer(o, ..coords) = cetz.draw.line(
  ..coords,
  stroke: o.tcu_xfer,
)
