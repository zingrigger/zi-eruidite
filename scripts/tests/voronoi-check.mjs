import assert from "node:assert/strict"
import {
  insetConvex,
  layoutVoronoiTreemap,
} from "../../src/lib/voronoi-treemap.ts"

const SIZE = { width: 1000, height: 625 }
const polygonArea = (pts) => {
  let a = 0
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i]
    const q = pts[(i + 1) % pts.length]
    a += p.x * q.y - q.x * p.y
  }
  return a / 2
}
const near = (a, b, eps) => Math.abs(a - b) <= eps

const equal = layoutVoronoiTreemap(
  Array.from({ length: 15 }, (_, i) => ({ key: `t${i}`, weight: 1 })),
  SIZE,
)
assert.equal(equal.length, 15)
assert.equal(new Set(equal.map((c) => c.key)).size, 15)
for (const cell of equal) {
  assert.ok(near(cell.share, 1 / 15, 0.01), `${cell.key} share ${cell.share}`)
  assert.ok(cell.points.length >= 3)
  assert.ok(polygonArea(cell.points) > 0)
  for (const p of cell.points) {
    assert.ok(p.x >= 0 && p.x <= SIZE.width, `${cell.key} x`)
    assert.ok(p.y >= 0 && p.y <= SIZE.height, `${cell.key} y`)
  }
  assert.ok(cell.label.x >= 0 && cell.label.x <= 100)
  assert.ok(cell.label.y >= 0 && cell.label.y <= 100)
  assert.ok(Number.isFinite(cell.inradius) && cell.inradius > 0)
}

const current = layoutVoronoiTreemap(
  [
    ["astro", 2],
    ["blog", 2],
    ["announcement", 1],
    ["design", 1],
    ["distributed-systems", 1],
    ["meetup", 1],
    ["reading", 1],
    ["rust", 1],
    ["site", 1],
    ["typography", 1],
    ["v1.0.0", 1],
    ["v1.3.0", 1],
    ["v1.5.0", 1],
    ["v1.6.0", 1],
    ["v2", 1],
  ].map(([key, weight]) => ({ key, weight })),
  SIZE,
)
const byKey = new Map(current.map((c) => [c.key, c]))
assert.ok(near(byKey.get("astro").share, 2 / 17, 0.01))
assert.ok(near(byKey.get("v2").share, 1 / 17, 0.01))
assert.ok(current.reduce((sum, c) => sum + c.share, 0) < 1.02)

const again = layoutVoronoiTreemap(
  current.map((c) => ({
    key: c.key,
    weight: c.key === "astro" || c.key === "blog" ? 2 : 1,
  })),
  SIZE,
)
assert.deepEqual(again, current)

assert.deepEqual(layoutVoronoiTreemap([], SIZE), [])
assert.deepEqual(layoutVoronoiTreemap([{ key: "z", weight: 0 }], SIZE), [])

const one = layoutVoronoiTreemap([{ key: "only", weight: 1 }], SIZE)
assert.equal(one.length, 1)
assert.ok(near(one[0].share, 1, 0.001))

const two = layoutVoronoiTreemap(
  [
    { key: "big", weight: 3 },
    { key: "small", weight: 1 },
  ],
  SIZE,
)
assert.equal(two.length, 2)
assert.ok(two.every((c) => c.points.length >= 3))
assert.ok(near(two[0].share, 0.75, 0.03))
assert.ok(near(two[1].share, 0.25, 0.03))

const skew = layoutVoronoiTreemap(
  [
    { key: "big", weight: 80 },
    { key: "small", weight: 1 },
  ],
  SIZE,
)
assert.equal(skew.length, 2)
assert.ok(skew.every((c) => polygonArea(c.points) > 0))
assert.ok(near(skew[1].share, 1 / 81, 0.02))

// inset of a too-narrow convex polygon must collapse to []
const narrow = [
  { x: 0, y: 0 },
  { x: 4, y: 0 },
  { x: 4, y: 4 },
  { x: 0, y: 4 },
]
assert.deepEqual(insetConvex(narrow, 3), [])
const wide = [
  { x: 0, y: 0 },
  { x: 40, y: 0 },
  { x: 40, y: 10 },
  { x: 0, y: 10 },
]
assert.equal(insetConvex(wide, 3).length, 4)

console.log("voronoi-check ok")
